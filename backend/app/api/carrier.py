from __future__ import annotations

from decimal import Decimal, InvalidOperation
from typing import Any
import re

import psycopg
from fastapi import APIRouter, HTTPException, Request, status
from pydantic import BaseModel, ConfigDict, Field
from psycopg import sql
from psycopg.types.json import Jsonb

from app.core.database import db_connection, default_master_context, table_identifier


router = APIRouter(prefix="/carrier", tags=["carrier"])


class CarrierDispatchConfirmationPayload(BaseModel):
    model_config = ConfigDict(extra="ignore")

    tenant_id: int | None = None
    company_id: int | None = None
    shipment_id: int | None = None
    plan_no: str | None = None
    tender_no: str | None = None
    carrier_code: str | None = None
    carrier_name: str
    carrier_phone: str | None = None
    carrier_email: str | None = None
    manager_name: str | None = None
    manager_email: str | None = None
    vehicle_code: str | None = None
    vehicle_no: str
    vehicle_type: str | None = None
    fuel_type: str | None = "DIESEL"
    max_weight_kg: str | int | float | Decimal | None = None
    max_volume_cbm: str | int | float | Decimal | None = None
    temperature_controlled: bool = False
    driver_code: str | None = None
    driver_name: str
    driver_phone: str | None = None
    driver_email: str | None = None
    license_type: str | None = None
    license_expiry_date: str | None = None
    offered_amount: str | int | float | Decimal | None = None
    currency_code: str = "KRW"
    instructions: str | None = None
    latitude: str | int | float | Decimal | None = None
    longitude: str | int | float | Decimal | None = None
    location_text: str | None = None
    notes: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


def _clean_text(value: Any, *, uppercase: bool = False) -> str | None:
    if value is None:
        return None
    cleaned = str(value).strip()
    if not cleaned:
        return None
    return cleaned.upper() if uppercase else cleaned


def _decimal_or_none(value: Any) -> Decimal | None:
    if value is None:
        return None
    if isinstance(value, Decimal):
        return value
    text = str(value).replace(",", "").strip()
    if not text:
        return None
    try:
        return Decimal(text)
    except InvalidOperation:
        return None


def _slug_code(prefix: str, value: str | None, fallback: str, limit: int = 60) -> str:
    raw = _clean_text(value, uppercase=True) or _clean_text(fallback, uppercase=True) or prefix
    slug = re.sub(r"[^A-Z0-9]+", "_", raw).strip("_") or prefix
    if not slug.startswith(prefix):
        slug = f"{prefix}_{slug}"
    return slug[:limit]


def _source(request: Request) -> dict[str, str | None]:
    client = _clean_text(request.headers.get("user-agent"))
    return {
        "channel": "WEB",
        "ip": request.client.host if request.client else None,
        "client": client[:200] if client else None,
    }


def _metadata(payload: CarrierDispatchConfirmationPayload, **extra: Any) -> dict[str, Any]:
    metadata = dict(payload.metadata or {})
    metadata["source"] = "ktms_carrier_portal"
    for key, value in extra.items():
        if value not in (None, ""):
            metadata[key] = value
    return metadata


def _shipment_id_for_plan(
    conn: psycopg.Connection,
    tenant_id: int,
    company_id: int,
    payload: CarrierDispatchConfirmationPayload,
) -> int | None:
    if payload.shipment_id:
        return payload.shipment_id
    plan_no = _clean_text(payload.plan_no)
    if not plan_no:
        return None

    with conn.cursor() as cur:
        cur.execute(
            sql.SQL(
                """
                select shipment_id
                from {shipments}
                where tenant_id = %s
                  and company_id = %s
                  and deleted_at is null
                  and (
                    shipment_no = %s
                    or metadata->>'plan_no' = %s
                    or metadata->>'load_plan_no' = %s
                  )
                order by shipment_id
                limit 1
                """
            ).format(shipments=table_identifier("shipments")),
            (tenant_id, company_id, plan_no, plan_no, plan_no),
        )
        row = cur.fetchone()
    return int(row["shipment_id"]) if row else None


def _ensure_carrier_id(
    conn: psycopg.Connection,
    tenant_id: int,
    company_id: int,
    payload: CarrierDispatchConfirmationPayload,
    source: dict[str, str | None],
) -> int:
    carrier_code = _clean_text(payload.carrier_code, uppercase=True) or _slug_code(
        "CARR",
        payload.carrier_name,
        "CARRIER",
    )
    with conn.cursor() as cur:
        cur.execute(
            sql.SQL(
                """
                insert into {business_partners} (
                    tenant_id, company_id, partner_code, partner_name,
                    partner_short_name, partner_type, phone, email,
                    status, is_active, metadata, created_channel_code,
                    created_from_ip, created_from_client, updated_channel_code,
                    updated_from_ip, updated_from_client
                )
                values (
                    %(tenant_id)s, %(company_id)s, %(partner_code)s,
                    %(partner_name)s, %(partner_name)s, 'CARRIER',
                    %(phone)s, %(email)s, 'ACTIVE', true, %(metadata)s,
                    %(channel)s, %(ip)s, %(client)s, %(channel)s, %(ip)s,
                    %(client)s
                )
                on conflict (tenant_id, company_id, partner_code)
                where deleted_at is null
                do update set
                    partner_name = excluded.partner_name,
                    partner_short_name = excluded.partner_short_name,
                    partner_type = 'CARRIER',
                    phone = excluded.phone,
                    email = excluded.email,
                    status = 'ACTIVE',
                    is_active = true,
                    metadata = {business_partners}.metadata || excluded.metadata,
                    updated_at = now(),
                    updated_channel_code = excluded.updated_channel_code,
                    updated_from_ip = excluded.updated_from_ip,
                    updated_from_client = excluded.updated_from_client
                returning partner_id
                """
            ).format(business_partners=table_identifier("business_partners")),
            {
                "tenant_id": tenant_id,
                "company_id": company_id,
                "partner_code": carrier_code,
                "partner_name": payload.carrier_name,
                "phone": _clean_text(payload.carrier_phone),
                "email": _clean_text(payload.carrier_email) or _clean_text(payload.manager_email),
                "metadata": Jsonb(_metadata(payload, carrier_portal_enabled=True)),
                **source,
            },
        )
        return int(cur.fetchone()["partner_id"])


def _ensure_vehicle_id(
    conn: psycopg.Connection,
    tenant_id: int,
    carrier_id: int,
    payload: CarrierDispatchConfirmationPayload,
    source: dict[str, str | None],
) -> int:
    vehicle_code = _clean_text(payload.vehicle_code, uppercase=True) or _slug_code(
        "VEH",
        payload.vehicle_no.replace(" ", ""),
        "CARRIER_VEHICLE",
        50,
    )
    normalized_plate = payload.vehicle_no.replace(" ", "")
    metadata = Jsonb(
        _metadata(
            payload,
            vehicle_type=payload.vehicle_type,
            carrier_name=payload.carrier_name,
            driver_name=payload.driver_name,
            gps_enabled=True,
            tracking_plan_no=payload.plan_no,
        )
    )

    with conn.cursor() as cur:
        cur.execute(
            sql.SQL(
                """
                select vehicle_id
                from {vehicles}
                where tenant_id = %s
                  and deleted_at is null
                  and (
                    vehicle_code = %s
                    or replace(plate_no, ' ', '') = %s
                  )
                order by vehicle_id
                limit 1
                """
            ).format(vehicles=table_identifier("vehicles")),
            (tenant_id, vehicle_code, normalized_plate),
        )
        existing = cur.fetchone()
        if existing:
            cur.execute(
                sql.SQL(
                    """
                    update {vehicles}
                    set carrier_id = %(carrier_id)s,
                        vehicle_code = %(vehicle_code)s,
                        plate_no = %(vehicle_no)s,
                        fuel_type = %(fuel_type)s,
                        max_weight_kg = %(max_weight_kg)s,
                        max_volume_cbm = %(max_volume_cbm)s,
                        temperature_controlled = %(temperature_controlled)s,
                        status = 'ASSIGNED',
                        is_active = true,
                        metadata = metadata || %(metadata)s,
                        updated_at = now(),
                        updated_channel_code = %(channel)s,
                        updated_from_ip = %(ip)s,
                        updated_from_client = %(client)s
                    where vehicle_id = %(vehicle_id)s
                    returning vehicle_id
                    """
                ).format(vehicles=table_identifier("vehicles")),
                {
                    "vehicle_id": existing["vehicle_id"],
                    "carrier_id": carrier_id,
                    "vehicle_code": vehicle_code,
                    "vehicle_no": payload.vehicle_no,
                    "fuel_type": _clean_text(payload.fuel_type, uppercase=True),
                    "max_weight_kg": _decimal_or_none(payload.max_weight_kg),
                    "max_volume_cbm": _decimal_or_none(payload.max_volume_cbm),
                    "temperature_controlled": payload.temperature_controlled,
                    "metadata": metadata,
                    **source,
                },
            )
            return int(cur.fetchone()["vehicle_id"])

        cur.execute(
            sql.SQL(
                """
                insert into {vehicles} (
                    tenant_id, carrier_id, vehicle_code, plate_no, fuel_type,
                    max_weight_kg, max_volume_cbm, temperature_controlled,
                    status, is_active, metadata, created_channel_code,
                    created_from_ip, created_from_client, updated_channel_code,
                    updated_from_ip, updated_from_client
                )
                values (
                    %(tenant_id)s, %(carrier_id)s, %(vehicle_code)s,
                    %(vehicle_no)s, %(fuel_type)s, %(max_weight_kg)s,
                    %(max_volume_cbm)s, %(temperature_controlled)s,
                    'ASSIGNED', true, %(metadata)s, %(channel)s, %(ip)s,
                    %(client)s, %(channel)s, %(ip)s, %(client)s
                )
                returning vehicle_id
                """
            ).format(vehicles=table_identifier("vehicles")),
            {
                "tenant_id": tenant_id,
                "carrier_id": carrier_id,
                "vehicle_code": vehicle_code,
                "vehicle_no": payload.vehicle_no,
                "fuel_type": _clean_text(payload.fuel_type, uppercase=True),
                "max_weight_kg": _decimal_or_none(payload.max_weight_kg),
                "max_volume_cbm": _decimal_or_none(payload.max_volume_cbm),
                "temperature_controlled": payload.temperature_controlled,
                "metadata": metadata,
                **source,
            },
        )
        return int(cur.fetchone()["vehicle_id"])


def _ensure_driver_id(
    conn: psycopg.Connection,
    tenant_id: int,
    carrier_id: int,
    payload: CarrierDispatchConfirmationPayload,
    source: dict[str, str | None],
) -> int:
    driver_code = _clean_text(payload.driver_code, uppercase=True) or _slug_code(
        "DRV",
        payload.driver_email or payload.driver_name,
        "CARRIER_DRIVER",
        50,
    )
    metadata = Jsonb(
        _metadata(
            payload,
            carrier_name=payload.carrier_name,
            assigned_vehicle_no=payload.vehicle_no,
        )
    )
    with conn.cursor() as cur:
        cur.execute(
            sql.SQL(
                """
                select driver_id
                from {drivers}
                where tenant_id = %s
                  and deleted_at is null
                  and (
                    driver_code = %s
                    or (%s::text is not null and lower(email) = lower(%s))
                  )
                order by driver_id
                limit 1
                """
            ).format(drivers=table_identifier("drivers")),
            (tenant_id, driver_code, payload.driver_email, payload.driver_email),
        )
        existing = cur.fetchone()
        if existing:
            cur.execute(
                sql.SQL(
                    """
                    update {drivers}
                    set carrier_id = %(carrier_id)s,
                        driver_code = %(driver_code)s,
                        driver_name = %(driver_name)s,
                        phone = %(phone)s,
                        email = %(email)s,
                        license_type = %(license_type)s,
                        license_expiry_date = %(license_expiry_date)s::text::date,
                        status = 'ACTIVE',
                        is_active = true,
                        metadata = metadata || %(metadata)s,
                        updated_at = now(),
                        updated_channel_code = %(channel)s,
                        updated_from_ip = %(ip)s,
                        updated_from_client = %(client)s
                    where driver_id = %(driver_id)s
                    returning driver_id
                    """
                ).format(drivers=table_identifier("drivers")),
                {
                    "driver_id": existing["driver_id"],
                    "carrier_id": carrier_id,
                    "driver_code": driver_code,
                    "driver_name": payload.driver_name,
                    "phone": _clean_text(payload.driver_phone),
                    "email": _clean_text(payload.driver_email),
                    "license_type": _clean_text(payload.license_type, uppercase=True),
                    "license_expiry_date": _clean_text(payload.license_expiry_date),
                    "metadata": metadata,
                    **source,
                },
            )
            return int(cur.fetchone()["driver_id"])

        cur.execute(
            sql.SQL(
                """
                insert into {drivers} (
                    tenant_id, carrier_id, driver_code, driver_name, phone,
                    email, license_type, license_expiry_date, status,
                    is_active, metadata, created_channel_code,
                    created_from_ip, created_from_client, updated_channel_code,
                    updated_from_ip, updated_from_client
                )
                values (
                    %(tenant_id)s, %(carrier_id)s, %(driver_code)s,
                    %(driver_name)s, %(phone)s, %(email)s, %(license_type)s,
                    %(license_expiry_date)s::text::date, 'ACTIVE', true,
                    %(metadata)s, %(channel)s, %(ip)s, %(client)s,
                    %(channel)s, %(ip)s, %(client)s
                )
                returning driver_id
                """
            ).format(drivers=table_identifier("drivers")),
            {
                "tenant_id": tenant_id,
                "carrier_id": carrier_id,
                "driver_code": driver_code,
                "driver_name": payload.driver_name,
                "phone": _clean_text(payload.driver_phone),
                "email": _clean_text(payload.driver_email),
                "license_type": _clean_text(payload.license_type, uppercase=True),
                "license_expiry_date": _clean_text(payload.license_expiry_date),
                "metadata": metadata,
                **source,
            },
        )
        return int(cur.fetchone()["driver_id"])


def _user_id_for_manager(
    conn: psycopg.Connection,
    tenant_id: int,
    manager_email: str | None,
) -> int | None:
    login_id = _clean_text(manager_email)
    if not login_id:
        return None
    login_id = login_id.lower()
    with conn.cursor() as cur:
        cur.execute(
            sql.SQL(
                """
                select user_id
                from {app_users}
                where tenant_id = %s
                  and deleted_at is null
                  and (login_id = %s or email = %s)
                order by user_id
                limit 1
                """
            ).format(app_users=table_identifier("app_users")),
            (tenant_id, login_id, login_id),
        )
        row = cur.fetchone()
    return int(row["user_id"]) if row else None


@router.post("/dispatch-confirmations")
def confirm_carrier_dispatch(
    payload: CarrierDispatchConfirmationPayload,
    request: Request,
):
    try:
        with db_connection() as conn:
            defaults = default_master_context(conn)
            tenant_id = payload.tenant_id or defaults.tenant_id
            company_id = payload.company_id or defaults.company_id
            shipment_id = _shipment_id_for_plan(conn, tenant_id, company_id, payload)
            if shipment_id is None:
                raise HTTPException(
                    status_code=status.HTTP_404_NOT_FOUND,
                    detail="plan_no에 해당하는 운송 실행을 찾지 못했습니다.",
                )

            source = _source(request)
            carrier_id = _ensure_carrier_id(conn, tenant_id, company_id, payload, source)
            vehicle_id = _ensure_vehicle_id(conn, tenant_id, carrier_id, payload, source)
            driver_id = _ensure_driver_id(conn, tenant_id, carrier_id, payload, source)
            dispatcher_user_id = _user_id_for_manager(
                conn,
                tenant_id,
                payload.manager_email,
            )
            amount = _decimal_or_none(payload.offered_amount)
            currency_code = (_clean_text(payload.currency_code, uppercase=True) or "KRW")[:3]
            dispatch_metadata = Jsonb(
                _metadata(
                    payload,
                    carrier_name=payload.carrier_name,
                    manager_name=payload.manager_name,
                    manager_email=payload.manager_email,
                    vehicle_no=payload.vehicle_no,
                    vehicle_type=payload.vehicle_type,
                    driver_name=payload.driver_name,
                    tender_no=payload.tender_no,
                )
            )

            with conn.cursor() as cur:
                cur.execute(
                    sql.SQL(
                        """
                        insert into {carrier_tenders} (
                            tenant_id, company_id, shipment_id, carrier_id,
                            tender_round, tender_status, offered_amount,
                            currency_code, sent_at, accepted_at, notes,
                            metadata, created_channel_code, created_from_ip,
                            created_from_client, updated_channel_code,
                            updated_from_ip, updated_from_client
                        )
                        values (
                            %(tenant_id)s, %(company_id)s, %(shipment_id)s,
                            %(carrier_id)s, 1, 'ACCEPTED', %(amount)s,
                            %(currency_code)s, now(), now(), %(notes)s,
                            %(metadata)s, %(channel)s, %(ip)s, %(client)s,
                            %(channel)s, %(ip)s, %(client)s
                        )
                        on conflict (shipment_id, carrier_id, tender_round)
                        where deleted_at is null
                        do update set
                            company_id = excluded.company_id,
                            tender_status = 'ACCEPTED',
                            offered_amount = excluded.offered_amount,
                            currency_code = excluded.currency_code,
                            accepted_at = now(),
                            rejected_at = null,
                            cancelled_at = null,
                            notes = excluded.notes,
                            metadata = {carrier_tenders}.metadata || excluded.metadata,
                            version_no = {carrier_tenders}.version_no + 1,
                            updated_at = now(),
                            updated_channel_code = excluded.updated_channel_code,
                            updated_from_ip = excluded.updated_from_ip,
                            updated_from_client = excluded.updated_from_client
                        returning tender_id
                        """
                    ).format(carrier_tenders=table_identifier("carrier_tenders")),
                    {
                        "tenant_id": tenant_id,
                        "company_id": company_id,
                        "shipment_id": shipment_id,
                        "carrier_id": carrier_id,
                        "amount": amount,
                        "currency_code": currency_code,
                        "notes": _clean_text(payload.notes),
                        "metadata": dispatch_metadata,
                        **source,
                    },
                )
                tender_id = int(cur.fetchone()["tender_id"])

                cur.execute(
                    sql.SQL(
                        """
                        select tender_response_id
                        from {carrier_tender_responses}
                        where tender_id = %s
                          and deleted_at is null
                        order by tender_response_id desc
                        limit 1
                        """
                    ).format(
                        carrier_tender_responses=table_identifier(
                            "carrier_tender_responses"
                        )
                    ),
                    (tender_id,),
                )
                existing_response = cur.fetchone()
                response_params = {
                    "tenant_id": tenant_id,
                    "company_id": company_id,
                    "tender_id": tender_id,
                    "amount": amount,
                    "currency_code": currency_code,
                    "responded_by": _clean_text(payload.manager_name)
                    or _clean_text(payload.manager_email),
                    "metadata": dispatch_metadata,
                    **source,
                }
                if existing_response:
                    cur.execute(
                        sql.SQL(
                            """
                            update {carrier_tender_responses}
                            set tenant_id = %(tenant_id)s,
                                company_id = %(company_id)s,
                                response_status = 'ACCEPTED',
                                response_amount = %(amount)s,
                                currency_code = %(currency_code)s,
                                rejection_reason = null,
                                responded_by = %(responded_by)s,
                                responded_at = now(),
                                metadata = metadata || %(metadata)s,
                                updated_at = now(),
                                updated_channel_code = %(channel)s,
                                updated_from_ip = %(ip)s,
                                updated_from_client = %(client)s
                            where tender_response_id = %(tender_response_id)s
                            returning tender_response_id
                            """
                        ).format(
                            carrier_tender_responses=table_identifier(
                                "carrier_tender_responses"
                            )
                        ),
                        {
                            **response_params,
                            "tender_response_id": existing_response[
                                "tender_response_id"
                            ],
                        },
                    )
                else:
                    cur.execute(
                        sql.SQL(
                            """
                            insert into {carrier_tender_responses} (
                                tenant_id, company_id, tender_id,
                                response_status, response_amount,
                                currency_code, responded_by, responded_at,
                                metadata, created_channel_code,
                                created_from_ip, created_from_client,
                                updated_channel_code, updated_from_ip,
                                updated_from_client
                            )
                            values (
                                %(tenant_id)s, %(company_id)s, %(tender_id)s,
                                'ACCEPTED', %(amount)s, %(currency_code)s,
                                %(responded_by)s, now(), %(metadata)s,
                                %(channel)s, %(ip)s, %(client)s, %(channel)s,
                                %(ip)s, %(client)s
                            )
                            returning tender_response_id
                            """
                        ).format(
                            carrier_tender_responses=table_identifier(
                                "carrier_tender_responses"
                            )
                        ),
                        response_params,
                    )

                tender_response_id = int(cur.fetchone()["tender_response_id"])
                cur.execute(
                    sql.SQL(
                        """
                        update {carrier_tender_responses}
                        set deleted_at = now(),
                            deleted_reason = 'superseded by latest carrier dispatch confirmation',
                            deleted_channel_code = %(channel)s,
                            deleted_from_ip = %(ip)s,
                            deleted_from_client = %(client)s
                        where tender_id = %(tender_id)s
                          and deleted_at is null
                          and tender_response_id <> %(tender_response_id)s
                        """
                    ).format(
                        carrier_tender_responses=table_identifier(
                            "carrier_tender_responses"
                        )
                    ),
                    {
                        "tender_id": tender_id,
                        "tender_response_id": tender_response_id,
                        **source,
                    },
                )

                dispatch_params = {
                    "shipment_id": shipment_id,
                    "tenant_id": tenant_id,
                    "company_id": company_id,
                    "dispatcher_user_id": dispatcher_user_id,
                    "driver_id": driver_id,
                    "vehicle_id": vehicle_id,
                    "instructions": _clean_text(payload.instructions),
                    "metadata": dispatch_metadata,
                    **source,
                }
                cur.execute(
                    sql.SQL(
                        """
                        update {dispatches}
                        set company_id = %(company_id)s,
                            dispatcher_user_id = %(dispatcher_user_id)s,
                            driver_id = %(driver_id)s,
                            vehicle_id = %(vehicle_id)s,
                            dispatch_status = 'ACCEPTED',
                            dispatched_at = coalesce(dispatched_at, now()),
                            accepted_at = now(),
                            instructions = %(instructions)s,
                            metadata = metadata || %(metadata)s,
                            version_no = version_no + 1,
                            updated_at = now(),
                            updated_channel_code = %(channel)s,
                            updated_from_ip = %(ip)s,
                            updated_from_client = %(client)s
                        where shipment_id = %(shipment_id)s
                          and deleted_at is null
                          and dispatch_status <> 'CANCELLED'
                        returning dispatch_id
                        """
                    ).format(dispatches=table_identifier("dispatches")),
                    dispatch_params,
                )
                row = cur.fetchone()
                if row:
                    dispatch_id = int(row["dispatch_id"])
                else:
                    cur.execute(
                        sql.SQL(
                            """
                            insert into {dispatches} (
                                tenant_id, company_id, shipment_id,
                                dispatcher_user_id, driver_id, vehicle_id,
                                dispatch_status, dispatched_at, accepted_at,
                                instructions, metadata, created_channel_code,
                                created_from_ip, created_from_client,
                                updated_channel_code, updated_from_ip,
                                updated_from_client
                            )
                            values (
                                %(tenant_id)s, %(company_id)s, %(shipment_id)s,
                                %(dispatcher_user_id)s, %(driver_id)s,
                                %(vehicle_id)s, 'ACCEPTED', now(), now(),
                                %(instructions)s, %(metadata)s, %(channel)s,
                                %(ip)s, %(client)s, %(channel)s, %(ip)s,
                                %(client)s
                            )
                            returning dispatch_id
                            """
                        ).format(dispatches=table_identifier("dispatches")),
                        dispatch_params,
                    )
                    dispatch_id = int(cur.fetchone()["dispatch_id"])

                cur.execute(
                    sql.SQL(
                        """
                        update {shipments}
                        set carrier_id = %(carrier_id)s,
                            vehicle_id = %(vehicle_id)s,
                            driver_id = %(driver_id)s,
                            shipment_status = 'DISPATCHED',
                            tender_status = 'ACCEPTED',
                            metadata = metadata || %(metadata)s,
                            version_no = version_no + 1,
                            updated_at = now(),
                            updated_channel_code = %(channel)s,
                            updated_from_ip = %(ip)s,
                            updated_from_client = %(client)s
                        where shipment_id = %(shipment_id)s
                        """
                    ).format(shipments=table_identifier("shipments")),
                    {
                        "shipment_id": shipment_id,
                        "carrier_id": carrier_id,
                        "vehicle_id": vehicle_id,
                        "driver_id": driver_id,
                        "metadata": dispatch_metadata,
                        **source,
                    },
                )

                event_payload = {
                    "source": "ktms_carrier_portal",
                    "plan_no": payload.plan_no,
                    "carrier_name": payload.carrier_name,
                    "manager_name": payload.manager_name,
                    "manager_email": payload.manager_email,
                    "vehicle_no": payload.vehicle_no,
                    "driver_name": payload.driver_name,
                    "dispatch_id": dispatch_id,
                    "tender_id": tender_id,
                    "tender_response_id": tender_response_id,
                }
                cur.execute(
                    sql.SQL(
                        """
                        insert into {tracking_events} (
                            tenant_id, company_id, shipment_id, event_type,
                            event_status, event_time, source_type,
                            source_system, latitude, longitude, location_text,
                            notes, payload, created_channel_code,
                            created_from_ip, created_from_client,
                            updated_channel_code, updated_from_ip,
                            updated_from_client
                        )
                        values (
                            %(tenant_id)s, %(company_id)s, %(shipment_id)s,
                            'CARRIER_DISPATCH_CONFIRMED', 'RECORDED', now(),
                            'MOBILE', 'KTMS_CARRIER', %(latitude)s,
                            %(longitude)s, %(location_text)s, %(notes)s,
                            %(payload)s, %(channel)s, %(ip)s, %(client)s,
                            %(channel)s, %(ip)s, %(client)s
                        )
                        returning tracking_event_id
                        """
                    ).format(tracking_events=table_identifier("tracking_events")),
                    {
                        "tenant_id": tenant_id,
                        "company_id": company_id,
                        "shipment_id": shipment_id,
                        "latitude": _decimal_or_none(payload.latitude),
                        "longitude": _decimal_or_none(payload.longitude),
                        "location_text": _clean_text(payload.location_text),
                        "notes": "운송사 담당자 배차 확정",
                        "payload": Jsonb(event_payload),
                        **source,
                    },
                )
                tracking_event_id = int(cur.fetchone()["tracking_event_id"])

            return {
                "saved": True,
                "shipment_id": shipment_id,
                "carrier_id": carrier_id,
                "vehicle_id": vehicle_id,
                "driver_id": driver_id,
                "dispatch_id": dispatch_id,
                "tender_id": tender_id,
                "tender_response_id": tender_response_id,
                "tracking_event_id": tracking_event_id,
            }
    except HTTPException:
        raise
    except psycopg.Error as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="운송사 배차 확정 저장 중 DB 오류가 발생했습니다.",
        ) from exc
    except Exception as exc:
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="운송사 배차 확정 저장 중 오류가 발생했습니다.",
        ) from exc
