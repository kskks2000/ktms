from __future__ import annotations

from decimal import Decimal, InvalidOperation
import re
from typing import Any

import psycopg
from fastapi import APIRouter, HTTPException, Query, Request, status
from pydantic import BaseModel, ConfigDict, Field
from psycopg import sql
from psycopg.types.json import Jsonb

from app.core.database import (
    MasterContext,
    db_connection,
    default_master_context,
    table_identifier,
)


router = APIRouter(prefix="/masters", tags=["masters"])


class MasterPayload(BaseModel):
    model_config = ConfigDict(extra="ignore")

    tenant_id: int | None = None
    company_id: int | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class BusinessPartnerPayload(MasterPayload):
    partner_code: str
    partner_name: str
    partner_short_name: str | None = None
    partner_type: str = "CUSTOMER"
    tax_registration_no: str | None = None
    representative_name: str | None = None
    phone: str | None = None
    email: str | None = None
    payment_terms: str | None = None
    credit_limit: str | int | float | Decimal | None = None
    status: str = "ACTIVE"
    is_active: bool = True


class LocationPayload(MasterPayload):
    location_code: str
    location_name: str
    location_type: str | None = None
    country_code: str | None = "KR"
    postal_code: str | None = None
    state_province: str | None = None
    city: str | None = None
    district: str | None = None
    address_line1: str | None = None
    address_line2: str | None = None
    latitude: str | int | float | Decimal | None = None
    longitude: str | int | float | Decimal | None = None
    timezone_name: str = "Asia/Seoul"
    geofence_radius_m: int | None = None
    is_active: bool = True


class GeoZonePayload(MasterPayload):
    zone_code: str
    zone_name: str
    zone_type: str = "REGION"
    description: str | None = None
    is_active: bool = True


class TransportRoutePayload(MasterPayload):
    route_code: str
    route_name: str
    origin_name: str | None = None
    destination_name: str | None = None
    zone_name: str | None = None
    service_level: str | None = None
    distance_km: str | int | float | Decimal | None = None
    lead_time_hours: str | int | float | Decimal | None = None
    base_fare: str | int | float | Decimal | None = None
    vehicle_limit: str | None = None
    appointment_required: bool = False
    toll_included: bool = True
    temperature_controlled: bool = False
    status: str = "ACTIVE"
    is_active: bool = True


class VehiclePayload(MasterPayload):
    vehicle_code: str
    plate_no: str
    carrier_name: str | None = None
    vehicle_type: str | None = None
    driver_name: str | None = None
    tonnage: str | None = None
    fuel_type: str | None = None
    home_yard: str | None = None
    max_weight_kg: str | int | float | Decimal | None = None
    max_volume_cbm: str | int | float | Decimal | None = None
    temperature_controlled: bool = False
    gps_enabled: bool = False
    tail_lift: bool = False
    insurance_expiry: str | None = None
    inspection_expiry: str | None = None
    status: str = "AVAILABLE"
    is_active: bool = True


class DriverPayload(MasterPayload):
    driver_code: str
    driver_name: str
    carrier_name: str | None = None
    phone: str | None = None
    email: str | None = None
    license_no: str | None = None
    license_type: str | None = None
    license_expiry_date: str | None = None
    hire_date: str | None = None
    status: str = "ACTIVE"
    is_active: bool = True


class ItemPayload(MasterPayload):
    item_code: str
    item_name: str
    item_description: str | None = None
    category_code: str | None = None
    category_name: str | None = None
    base_uom_code: str | None = None
    base_uom_name: str | None = None
    sku: str | None = None
    barcode: str | None = None
    nmfc_code: str | None = None
    hs_code: str | None = None
    is_hazardous: bool = False
    hazardous_class: str | None = None
    temperature_controlled: bool = False
    min_temperature_c: str | int | float | Decimal | None = None
    max_temperature_c: str | int | float | Decimal | None = None
    unit_weight_kg: str | int | float | Decimal | None = None
    unit_volume_cbm: str | int | float | Decimal | None = None
    length_cm: str | int | float | Decimal | None = None
    width_cm: str | int | float | Decimal | None = None
    height_cm: str | int | float | Decimal | None = None
    status: str = "ACTIVE"
    is_active: bool = True


class RateAgreementPayload(MasterPayload):
    agreement_no: str
    agreement_name: str
    agreement_type: str = "SELL"
    partner_code: str | None = None
    partner_name: str
    partner_type: str | None = None
    currency_code: str = "KRW"
    effective_from: str
    effective_to: str | None = None
    status: str = "DRAFT"
    is_active: bool = True
    contract_owner: str | None = None
    payment_terms: str | None = None
    auto_rating: bool = True
    toll_included: bool = True
    tax_included: bool = True
    lane_code: str | None = None
    origin_name: str | None = None
    destination_name: str | None = None
    mode_code: str | None = None
    mode_name: str | None = None
    service_level_code: str | None = None
    service_level_name: str | None = None
    equipment_code: str | None = None
    equipment_name: str | None = None
    base_rate_amount: str | int | float | Decimal | None = None
    min_charge_amount: str | int | float | Decimal | None = None
    transit_hours: int | None = None
    charge_code: str | None = None
    charge_name: str | None = None
    charge_category: str = "BASE"
    calculation_method: str = "FLAT"
    unit_code: str | None = None
    rate_amount: str | int | float | Decimal | None = None
    minimum_amount: str | int | float | Decimal | None = None
    maximum_amount: str | int | float | Decimal | None = None
    fuel_surcharge_enabled: bool = False
    fuel_rule_code: str | None = None
    fuel_rule_name: str | None = None
    fuel_index_name: str | None = None
    baseline_price: str | int | float | Decimal | None = None
    surcharge_percent: str | int | float | Decimal | None = None
    surcharge_amount: str | int | float | Decimal | None = None
    memo: str | None = None


class UserAccessPayload(MasterPayload):
    login_id: str
    email: str | None = None
    full_name: str
    phone: str | None = None
    mobile: str | None = None
    department_name: str | None = None
    business_unit_name: str | None = None
    language_code: str = "ko"
    timezone_name: str = "Asia/Seoul"
    status: str = "ACTIVE"
    mfa_enabled: bool = False
    is_active: bool = True
    role_code: str
    role_name: str
    role_description: str | None = None
    role_profile: str | None = None
    data_scope: str | None = None
    permissions: list[str] = Field(default_factory=list)
    allow_web: bool = True
    allow_mobile: bool = True
    require_approval: bool = False
    expires_at: str | None = None
    memo: str | None = None


class CommonCodePayload(MasterPayload):
    group_code: str
    group_name: str
    group_description: str | None = None
    code: str
    code_name: str
    code_value: str | None = None
    sort_order: int = 0
    is_default: bool = False
    group_is_system: bool = False
    is_active: bool = True
    applies_to: str | None = None
    memo: str | None = None
    color_hex: str | None = None
    icon_name: str | None = None


def _clean_text(value: str | None, *, uppercase: bool = False) -> str | None:
    if value is None:
        return None
    cleaned = value.strip()
    if not cleaned:
        return None
    return cleaned.upper() if uppercase else cleaned


def _decimal_or_none(value: str | int | float | Decimal | None) -> Decimal | None:
    if value is None:
        return None
    if isinstance(value, Decimal):
        return value
    text = str(value).strip().replace(",", "")
    if not text:
        return None
    try:
        return Decimal(text)
    except InvalidOperation:
        return None


def _date_or_none(value: str | None) -> str | None:
    return _clean_text(value)


def _client_source(request: Request) -> dict[str, str | None]:
    client = _clean_text(request.headers.get("user-agent"))
    return {
        "channel": "WEB",
        "ip": request.client.host if request.client else None,
        "client": client[:200] if client else None,
    }


def _master_context(
    conn: psycopg.Connection,
    *,
    tenant_id: int | None,
    company_id: int | None = None,
) -> MasterContext:
    defaults = default_master_context(conn)
    return MasterContext(
        tenant_id=tenant_id or defaults.tenant_id,
        company_id=company_id if company_id is not None else defaults.company_id,
    )


def _metadata(payload: MasterPayload, **extra: Any) -> Jsonb:
    data = {"source": "ktms_flutter_master", **payload.metadata}
    data.update({key: value for key, value in extra.items() if value not in (None, "")})
    return Jsonb(data)


def _handle_db_error(exc: Exception) -> HTTPException:
    if isinstance(exc, psycopg.errors.UniqueViolation):
        return HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="이미 등록된 코드 또는 식별값입니다.",
        )
    if isinstance(exc, RuntimeError):
        return HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=str(exc),
        )
    if isinstance(exc, psycopg.Error):
        return HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="DB 저장 중 오류가 발생했습니다.",
        )
    return HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail="마스터 저장 중 오류가 발생했습니다.",
    )


def _run_db_save(callback):
    try:
        with db_connection() as conn:
            return callback(conn)
    except Exception as exc:
        raise _handle_db_error(exc) from exc


@router.get("/business-partners")
def list_business_partners(
    partner_type: str | None = Query(default=None),
    q: str | None = Query(default=None),
    limit: int = Query(default=80, ge=1, le=200),
    tenant_id: int | None = Query(default=None),
    company_id: int | None = Query(default=None),
):
    def load(conn: psycopg.Connection) -> dict[str, Any]:
        context = _master_context(
            conn,
            tenant_id=tenant_id,
            company_id=company_id,
        )
        filters = [
            sql.SQL("tenant_id = %s"),
            sql.SQL("company_id = %s"),
            sql.SQL("deleted_at is null"),
            sql.SQL("is_active = true"),
        ]
        params: list[Any] = [context.tenant_id, context.company_id]

        normalized_type = _clean_text(partner_type, uppercase=True)
        if normalized_type:
            filters.append(sql.SQL("partner_type = %s"))
            params.append(normalized_type)

        normalized_query = _clean_text(q)
        if normalized_query:
            filters.append(
                sql.SQL(
                    """
                    (
                        partner_code ilike %s
                        or partner_name ilike %s
                        or partner_short_name ilike %s
                        or coalesce(phone, '') ilike %s
                    )
                    """
                )
            )
            like_query = f"%{normalized_query}%"
            params.extend([like_query, like_query, like_query, like_query])

        params.append(limit)
        query = sql.SQL(
            """
            select
                partner_id,
                partner_code,
                partner_name,
                partner_short_name,
                partner_type,
                status,
                is_active,
                payment_terms,
                phone,
                email
            from {business_partners}
            where {filters}
            order by
                case partner_type
                    when 'CUSTOMER' then 1
                    when 'SHIPPER' then 2
                    when 'CARRIER' then 3
                    else 9
                end,
                partner_name
            limit %s
            """
        ).format(
            business_partners=table_identifier("business_partners"),
            filters=sql.SQL(" and ").join(filters),
        )

        with conn.cursor() as cur:
            cur.execute(query, params)
            rows = cur.fetchall()

        return {"items": rows}

    return _run_db_save(load)


@router.post("/business-partners")
def save_business_partner(payload: BusinessPartnerPayload, request: Request):
    def save(conn: psycopg.Connection) -> dict[str, Any]:
        context = _master_context(
            conn,
            tenant_id=payload.tenant_id,
            company_id=payload.company_id,
        )
        if context.company_id is None:
            raise RuntimeError("No company context was found for business partner.")

        source = _client_source(request)
        params = {
            "tenant_id": context.tenant_id,
            "company_id": context.company_id,
            "partner_code": _clean_text(payload.partner_code, uppercase=True),
            "partner_name": _clean_text(payload.partner_name),
            "partner_short_name": _clean_text(payload.partner_short_name)
            or _clean_text(payload.partner_name),
            "partner_type": _clean_text(payload.partner_type, uppercase=True)
            or "CUSTOMER",
            "tax_registration_no": _clean_text(payload.tax_registration_no),
            "representative_name": _clean_text(payload.representative_name),
            "phone": _clean_text(payload.phone),
            "email": _clean_text(payload.email),
            "payment_terms": _clean_text(payload.payment_terms),
            "credit_limit": _decimal_or_none(payload.credit_limit),
            "status": _clean_text(payload.status, uppercase=True) or "ACTIVE",
            "is_active": payload.is_active,
            "metadata": _metadata(payload),
            "channel": source["channel"],
            "ip": source["ip"],
            "client": source["client"],
        }

        query = sql.SQL(
            """
            insert into {business_partners} (
                tenant_id, company_id, partner_code, partner_name,
                partner_short_name, partner_type, tax_registration_no,
                representative_name, phone, email, payment_terms, credit_limit,
                status, is_active, metadata, created_channel_code,
                created_from_ip, created_from_client, updated_channel_code,
                updated_from_ip, updated_from_client
            )
            values (
                %(tenant_id)s, %(company_id)s, %(partner_code)s, %(partner_name)s,
                %(partner_short_name)s, %(partner_type)s, %(tax_registration_no)s,
                %(representative_name)s, %(phone)s, %(email)s, %(payment_terms)s,
                %(credit_limit)s, %(status)s, %(is_active)s, %(metadata)s,
                %(channel)s, %(ip)s, %(client)s, %(channel)s, %(ip)s, %(client)s
            )
            on conflict (tenant_id, company_id, partner_code)
            where deleted_at is null
            do update set
                partner_name = excluded.partner_name,
                partner_short_name = excluded.partner_short_name,
                partner_type = excluded.partner_type,
                tax_registration_no = excluded.tax_registration_no,
                representative_name = excluded.representative_name,
                phone = excluded.phone,
                email = excluded.email,
                payment_terms = excluded.payment_terms,
                credit_limit = excluded.credit_limit,
                status = excluded.status,
                is_active = excluded.is_active,
                metadata = excluded.metadata,
                updated_at = now(),
                updated_channel_code = excluded.updated_channel_code,
                updated_from_ip = excluded.updated_from_ip,
                updated_from_client = excluded.updated_from_client
            returning partner_id, partner_code
            """
        ).format(business_partners=table_identifier("business_partners"))

        with conn.cursor() as cur:
            cur.execute(query, params)
            row = cur.fetchone()

        return {
            "saved": True,
            "table": "business_partners",
            "id": row["partner_id"],
            "code": row["partner_code"],
        }

    return _run_db_save(save)


@router.post("/locations")
def save_location(payload: LocationPayload, request: Request):
    def save(conn: psycopg.Connection) -> dict[str, Any]:
        context = _master_context(conn, tenant_id=payload.tenant_id)
        source = _client_source(request)
        params = {
            "tenant_id": context.tenant_id,
            "location_code": _clean_text(payload.location_code, uppercase=True),
            "location_name": _clean_text(payload.location_name),
            "country_code": _clean_text(payload.country_code, uppercase=True) or "KR",
            "postal_code": _clean_text(payload.postal_code),
            "state_province": _clean_text(payload.state_province),
            "city": _clean_text(payload.city),
            "district": _clean_text(payload.district),
            "address_line1": _clean_text(payload.address_line1),
            "address_line2": _clean_text(payload.address_line2),
            "latitude": _decimal_or_none(payload.latitude),
            "longitude": _decimal_or_none(payload.longitude),
            "timezone_name": _clean_text(payload.timezone_name) or "Asia/Seoul",
            "geofence_radius_m": payload.geofence_radius_m,
            "is_active": payload.is_active,
            "metadata": _metadata(payload, location_type=payload.location_type),
            "channel": source["channel"],
            "ip": source["ip"],
            "client": source["client"],
        }

        query = sql.SQL(
            """
            insert into {locations} (
                tenant_id, location_code, location_name, country_code,
                postal_code, state_province, city, district, address_line1,
                address_line2, latitude, longitude, timezone_name,
                geofence_radius_m, is_active, metadata, created_channel_code,
                created_from_ip, created_from_client, updated_channel_code,
                updated_from_ip, updated_from_client
            )
            values (
                %(tenant_id)s, %(location_code)s, %(location_name)s,
                %(country_code)s, %(postal_code)s, %(state_province)s,
                %(city)s, %(district)s, %(address_line1)s, %(address_line2)s,
                %(latitude)s, %(longitude)s, %(timezone_name)s,
                %(geofence_radius_m)s, %(is_active)s, %(metadata)s,
                %(channel)s, %(ip)s, %(client)s, %(channel)s, %(ip)s, %(client)s
            )
            on conflict (tenant_id, location_code)
            where deleted_at is null
            do update set
                location_name = excluded.location_name,
                country_code = excluded.country_code,
                postal_code = excluded.postal_code,
                state_province = excluded.state_province,
                city = excluded.city,
                district = excluded.district,
                address_line1 = excluded.address_line1,
                address_line2 = excluded.address_line2,
                latitude = excluded.latitude,
                longitude = excluded.longitude,
                timezone_name = excluded.timezone_name,
                geofence_radius_m = excluded.geofence_radius_m,
                is_active = excluded.is_active,
                metadata = excluded.metadata,
                updated_at = now(),
                updated_channel_code = excluded.updated_channel_code,
                updated_from_ip = excluded.updated_from_ip,
                updated_from_client = excluded.updated_from_client
            returning location_id, location_code
            """
        ).format(locations=table_identifier("locations"))

        with conn.cursor() as cur:
            cur.execute(query, params)
            row = cur.fetchone()

        return {
            "saved": True,
            "table": "locations",
            "id": row["location_id"],
            "code": row["location_code"],
        }

    return _run_db_save(save)


@router.post("/geo-zones")
def save_geo_zone(payload: GeoZonePayload, request: Request):
    def save(conn: psycopg.Connection) -> dict[str, Any]:
        context = _master_context(conn, tenant_id=payload.tenant_id)
        source = _client_source(request)
        params = {
            "tenant_id": context.tenant_id,
            "zone_code": _clean_text(payload.zone_code, uppercase=True),
            "zone_name": _clean_text(payload.zone_name),
            "zone_type": _clean_text(payload.zone_type, uppercase=True) or "REGION",
            "description": _clean_text(payload.description),
            "is_active": payload.is_active,
            "metadata": _metadata(payload),
            "channel": source["channel"],
            "ip": source["ip"],
            "client": source["client"],
        }

        query = sql.SQL(
            """
            insert into {geo_zones} (
                tenant_id, zone_code, zone_name, zone_type, description,
                is_active, metadata, created_channel_code, created_from_ip,
                created_from_client, updated_channel_code, updated_from_ip,
                updated_from_client
            )
            values (
                %(tenant_id)s, %(zone_code)s, %(zone_name)s, %(zone_type)s,
                %(description)s, %(is_active)s, %(metadata)s, %(channel)s,
                %(ip)s, %(client)s, %(channel)s, %(ip)s, %(client)s
            )
            on conflict (tenant_id, zone_code)
            where deleted_at is null
            do update set
                zone_name = excluded.zone_name,
                zone_type = excluded.zone_type,
                description = excluded.description,
                is_active = excluded.is_active,
                metadata = excluded.metadata,
                updated_at = now(),
                updated_channel_code = excluded.updated_channel_code,
                updated_from_ip = excluded.updated_from_ip,
                updated_from_client = excluded.updated_from_client
            returning geo_zone_id, zone_code
            """
        ).format(geo_zones=table_identifier("geo_zones"))

        with conn.cursor() as cur:
            cur.execute(query, params)
            row = cur.fetchone()

        return {
            "saved": True,
            "table": "geo_zones",
            "id": row["geo_zone_id"],
            "code": row["zone_code"],
        }

    return _run_db_save(save)


def _find_geo_zone_id(
    conn: psycopg.Connection,
    tenant_id: int,
    zone_name: str | None,
) -> int | None:
    zone = _clean_text(zone_name)
    if not zone:
        return None

    query = sql.SQL(
        """
        select geo_zone_id
        from {geo_zones}
        where tenant_id = %s
          and deleted_at is null
          and (zone_code = %s or zone_name = %s)
        order by geo_zone_id
        limit 1
        """
    ).format(geo_zones=table_identifier("geo_zones"))

    with conn.cursor() as cur:
        cur.execute(query, (tenant_id, zone.upper(), zone))
        row = cur.fetchone()

    return int(row["geo_zone_id"]) if row else None


@router.post("/transport-routes")
def save_transport_route(payload: TransportRoutePayload, request: Request):
    def save(conn: psycopg.Connection) -> dict[str, Any]:
        context = _master_context(conn, tenant_id=payload.tenant_id)
        source = _client_source(request)
        params = {
            "tenant_id": context.tenant_id,
            "route_code": _clean_text(payload.route_code, uppercase=True),
            "route_name": _clean_text(payload.route_name),
            "origin_name": _clean_text(payload.origin_name),
            "destination_name": _clean_text(payload.destination_name),
            "geo_zone_id": _find_geo_zone_id(
                conn,
                context.tenant_id,
                payload.zone_name,
            ),
            "zone_name": _clean_text(payload.zone_name),
            "service_level": _clean_text(payload.service_level),
            "distance_km": _decimal_or_none(payload.distance_km),
            "lead_time_hours": _decimal_or_none(payload.lead_time_hours),
            "base_fare": _decimal_or_none(payload.base_fare),
            "vehicle_limit": _clean_text(payload.vehicle_limit),
            "appointment_required": payload.appointment_required,
            "toll_included": payload.toll_included,
            "temperature_controlled": payload.temperature_controlled,
            "status": _clean_text(payload.status, uppercase=True) or "ACTIVE",
            "is_active": payload.is_active,
            "metadata": _metadata(payload),
            "channel": source["channel"],
            "ip": source["ip"],
            "client": source["client"],
        }

        query = sql.SQL(
            """
            insert into {transport_routes} (
                tenant_id, route_code, route_name, origin_name,
                destination_name, geo_zone_id, zone_name, service_level,
                distance_km, lead_time_hours, base_fare, vehicle_limit,
                appointment_required, toll_included, temperature_controlled,
                status, is_active, metadata, created_channel_code,
                created_from_ip, created_from_client, updated_channel_code,
                updated_from_ip, updated_from_client
            )
            values (
                %(tenant_id)s, %(route_code)s, %(route_name)s,
                %(origin_name)s, %(destination_name)s, %(geo_zone_id)s,
                %(zone_name)s, %(service_level)s, %(distance_km)s,
                %(lead_time_hours)s, %(base_fare)s, %(vehicle_limit)s,
                %(appointment_required)s, %(toll_included)s,
                %(temperature_controlled)s, %(status)s, %(is_active)s,
                %(metadata)s, %(channel)s, %(ip)s, %(client)s,
                %(channel)s, %(ip)s, %(client)s
            )
            on conflict (tenant_id, route_code)
            where deleted_at is null
            do update set
                route_name = excluded.route_name,
                origin_name = excluded.origin_name,
                destination_name = excluded.destination_name,
                geo_zone_id = excluded.geo_zone_id,
                zone_name = excluded.zone_name,
                service_level = excluded.service_level,
                distance_km = excluded.distance_km,
                lead_time_hours = excluded.lead_time_hours,
                base_fare = excluded.base_fare,
                vehicle_limit = excluded.vehicle_limit,
                appointment_required = excluded.appointment_required,
                toll_included = excluded.toll_included,
                temperature_controlled = excluded.temperature_controlled,
                status = excluded.status,
                is_active = excluded.is_active,
                metadata = excluded.metadata,
                updated_at = now(),
                updated_channel_code = excluded.updated_channel_code,
                updated_from_ip = excluded.updated_from_ip,
                updated_from_client = excluded.updated_from_client
            returning transport_route_id, route_code
            """
        ).format(transport_routes=table_identifier("transport_routes"))

        with conn.cursor() as cur:
            cur.execute(query, params)
            row = cur.fetchone()

        return {
            "saved": True,
            "table": "transport_routes",
            "id": row["transport_route_id"],
            "code": row["route_code"],
        }

    return _run_db_save(save)


def _find_carrier_id(
    conn: psycopg.Connection,
    tenant_id: int,
    company_id: int | None,
    carrier_name: str | None,
) -> int | None:
    carrier = _clean_text(carrier_name)
    if not carrier or company_id is None:
        return None

    query = sql.SQL(
        """
        select partner_id
        from {business_partners}
        where tenant_id = %s
          and company_id = %s
          and partner_type = 'CARRIER'
          and deleted_at is null
          and (partner_code = %s or partner_name = %s or partner_short_name = %s)
        order by partner_id
        limit 1
        """
    ).format(business_partners=table_identifier("business_partners"))

    with conn.cursor() as cur:
        cur.execute(query, (tenant_id, company_id, carrier.upper(), carrier, carrier))
        row = cur.fetchone()

    return int(row["partner_id"]) if row else None


def _vehicle_status(status_code: str | None, is_active: bool) -> str:
    if not is_active:
        return "INACTIVE"
    status_value = _clean_text(status_code, uppercase=True) or "AVAILABLE"
    if status_value == "DISPATCHED":
        return "ASSIGNED"
    if status_value not in {"AVAILABLE", "ASSIGNED", "MAINTENANCE", "INACTIVE"}:
        return "AVAILABLE"
    return status_value


def _driver_status(status_code: str | None, is_active: bool) -> str:
    if not is_active:
        return "INACTIVE"
    status_value = _clean_text(status_code, uppercase=True) or "ACTIVE"
    if status_value not in {"ACTIVE", "OFF_DUTY", "ON_LEAVE", "INACTIVE"}:
        return "ACTIVE"
    return status_value


@router.post("/vehicles")
def save_vehicle(payload: VehiclePayload, request: Request):
    def save(conn: psycopg.Connection) -> dict[str, Any]:
        context = _master_context(
            conn,
            tenant_id=payload.tenant_id,
            company_id=payload.company_id,
        )
        source = _client_source(request)
        params = {
            "tenant_id": context.tenant_id,
            "carrier_id": _find_carrier_id(
                conn,
                context.tenant_id,
                context.company_id,
                payload.carrier_name,
            ),
            "vehicle_code": _clean_text(payload.vehicle_code, uppercase=True),
            "plate_no": _clean_text(payload.plate_no),
            "fuel_type": _clean_text(payload.fuel_type),
            "max_weight_kg": _decimal_or_none(payload.max_weight_kg),
            "max_volume_cbm": _decimal_or_none(payload.max_volume_cbm),
            "temperature_controlled": payload.temperature_controlled,
            "status": _vehicle_status(payload.status, payload.is_active),
            "is_active": payload.is_active,
            "metadata": _metadata(
                payload,
                vehicle_type=payload.vehicle_type,
                carrier_name=payload.carrier_name,
                driver_name=payload.driver_name,
                tonnage=payload.tonnage,
                home_yard=payload.home_yard,
                gps_enabled=payload.gps_enabled,
                tail_lift=payload.tail_lift,
                insurance_expiry=payload.insurance_expiry,
                inspection_expiry=payload.inspection_expiry,
            ),
            "channel": source["channel"],
            "ip": source["ip"],
            "client": source["client"],
        }

        query = sql.SQL(
            """
            insert into {vehicles} (
                tenant_id, carrier_id, vehicle_code, plate_no, fuel_type,
                max_weight_kg, max_volume_cbm, temperature_controlled,
                status, is_active, metadata, created_channel_code,
                created_from_ip, created_from_client, updated_channel_code,
                updated_from_ip, updated_from_client
            )
            values (
                %(tenant_id)s, %(carrier_id)s, %(vehicle_code)s, %(plate_no)s,
                %(fuel_type)s, %(max_weight_kg)s, %(max_volume_cbm)s,
                %(temperature_controlled)s, %(status)s, %(is_active)s,
                %(metadata)s, %(channel)s, %(ip)s, %(client)s,
                %(channel)s, %(ip)s, %(client)s
            )
            on conflict (tenant_id, vehicle_code)
            where deleted_at is null
            do update set
                carrier_id = excluded.carrier_id,
                plate_no = excluded.plate_no,
                fuel_type = excluded.fuel_type,
                max_weight_kg = excluded.max_weight_kg,
                max_volume_cbm = excluded.max_volume_cbm,
                temperature_controlled = excluded.temperature_controlled,
                status = excluded.status,
                is_active = excluded.is_active,
                metadata = excluded.metadata,
                updated_at = now(),
                updated_channel_code = excluded.updated_channel_code,
                updated_from_ip = excluded.updated_from_ip,
                updated_from_client = excluded.updated_from_client
            returning vehicle_id, vehicle_code
            """
        ).format(vehicles=table_identifier("vehicles"))

        with conn.cursor() as cur:
            cur.execute(query, params)
            row = cur.fetchone()

        return {
            "saved": True,
            "table": "vehicles",
            "id": row["vehicle_id"],
            "code": row["vehicle_code"],
        }

    return _run_db_save(save)


@router.post("/drivers")
def save_driver(payload: DriverPayload, request: Request):
    def save(conn: psycopg.Connection) -> dict[str, Any]:
        context = _master_context(
            conn,
            tenant_id=payload.tenant_id,
            company_id=payload.company_id,
        )
        source = _client_source(request)
        params = {
            "tenant_id": context.tenant_id,
            "carrier_id": _find_carrier_id(
                conn,
                context.tenant_id,
                context.company_id,
                payload.carrier_name,
            ),
            "driver_code": _clean_text(payload.driver_code, uppercase=True),
            "driver_name": _clean_text(payload.driver_name),
            "phone": _clean_text(payload.phone),
            "email": _clean_text(payload.email),
            "license_no": _clean_text(payload.license_no),
            "license_type": _clean_text(payload.license_type, uppercase=True),
            "license_expiry_date": _date_or_none(payload.license_expiry_date),
            "hire_date": _date_or_none(payload.hire_date),
            "status": _driver_status(payload.status, payload.is_active),
            "is_active": payload.is_active,
            "metadata": _metadata(payload, carrier_name=payload.carrier_name),
            "channel": source["channel"],
            "ip": source["ip"],
            "client": source["client"],
        }

        query = sql.SQL(
            """
            insert into {drivers} (
                tenant_id, carrier_id, driver_code, driver_name, phone, email,
                license_no, license_type, license_expiry_date, hire_date,
                status, is_active, metadata, created_channel_code,
                created_from_ip, created_from_client, updated_channel_code,
                updated_from_ip, updated_from_client
            )
            values (
                %(tenant_id)s, %(carrier_id)s, %(driver_code)s,
                %(driver_name)s, %(phone)s, %(email)s, %(license_no)s,
                %(license_type)s, %(license_expiry_date)s::date,
                %(hire_date)s::date, %(status)s, %(is_active)s, %(metadata)s,
                %(channel)s, %(ip)s, %(client)s, %(channel)s, %(ip)s, %(client)s
            )
            on conflict (tenant_id, driver_code)
            where deleted_at is null
            do update set
                carrier_id = excluded.carrier_id,
                driver_name = excluded.driver_name,
                phone = excluded.phone,
                email = excluded.email,
                license_no = excluded.license_no,
                license_type = excluded.license_type,
                license_expiry_date = excluded.license_expiry_date,
                hire_date = excluded.hire_date,
                status = excluded.status,
                is_active = excluded.is_active,
                metadata = excluded.metadata,
                updated_at = now(),
                updated_channel_code = excluded.updated_channel_code,
                updated_from_ip = excluded.updated_from_ip,
                updated_from_client = excluded.updated_from_client
            returning driver_id, driver_code
            """
        ).format(drivers=table_identifier("drivers"))

        with conn.cursor() as cur:
            cur.execute(query, params)
            row = cur.fetchone()

        return {
            "saved": True,
            "table": "drivers",
            "id": row["driver_id"],
            "code": row["driver_code"],
        }

    return _run_db_save(save)


def _find_item_category_id(
    conn: psycopg.Connection,
    tenant_id: int,
    category_code: str | None,
    category_name: str | None,
) -> int | None:
    code = _clean_text(category_code, uppercase=True)
    name = _clean_text(category_name)
    if not code and not name:
        return None

    query = sql.SQL(
        """
        select item_category_id
        from {item_categories}
        where tenant_id = %s
          and deleted_at is null
          and (
              (%s::text is not null and category_code = %s)
              or (%s::text is not null and category_name = %s)
          )
        order by item_category_id
        limit 1
        """
    ).format(item_categories=table_identifier("item_categories"))

    with conn.cursor() as cur:
        cur.execute(query, (tenant_id, code, code, name, name))
        row = cur.fetchone()

    return int(row["item_category_id"]) if row else None


def _find_item_uom_id(
    conn: psycopg.Connection,
    tenant_id: int,
    uom_code: str | None,
    uom_name: str | None,
) -> int | None:
    code = _clean_text(uom_code, uppercase=True)
    name = _clean_text(uom_name)
    if not code and not name:
        return None

    query = sql.SQL(
        """
        select uom_id
        from {item_uoms}
        where tenant_id = %s
          and deleted_at is null
          and (
              (%s::text is not null and uom_code = %s)
              or (%s::text is not null and uom_name = %s)
          )
        order by uom_id
        limit 1
        """
    ).format(item_uoms=table_identifier("item_uoms"))

    with conn.cursor() as cur:
        cur.execute(query, (tenant_id, code, code, name, name))
        row = cur.fetchone()

    return int(row["uom_id"]) if row else None


def _item_status(status_code: str | None, is_active: bool) -> str:
    if not is_active:
        return "INACTIVE"
    status_value = _clean_text(status_code, uppercase=True) or "ACTIVE"
    if status_value not in {"ACTIVE", "INACTIVE"}:
        return "ACTIVE"
    return status_value


@router.post("/items")
def save_item(payload: ItemPayload, request: Request):
    def save(conn: psycopg.Connection) -> dict[str, Any]:
        context = _master_context(conn, tenant_id=payload.tenant_id)
        source = _client_source(request)
        params = {
            "tenant_id": context.tenant_id,
            "item_category_id": _find_item_category_id(
                conn,
                context.tenant_id,
                payload.category_code,
                payload.category_name,
            ),
            "base_uom_id": _find_item_uom_id(
                conn,
                context.tenant_id,
                payload.base_uom_code,
                payload.base_uom_name,
            ),
            "item_code": _clean_text(payload.item_code, uppercase=True),
            "item_name": _clean_text(payload.item_name),
            "item_description": _clean_text(payload.item_description),
            "sku": _clean_text(payload.sku),
            "barcode": _clean_text(payload.barcode),
            "nmfc_code": _clean_text(payload.nmfc_code),
            "hs_code": _clean_text(payload.hs_code),
            "is_hazardous": payload.is_hazardous,
            "hazardous_class": _clean_text(payload.hazardous_class),
            "temperature_controlled": payload.temperature_controlled,
            "min_temperature_c": _decimal_or_none(payload.min_temperature_c),
            "max_temperature_c": _decimal_or_none(payload.max_temperature_c),
            "unit_weight_kg": _decimal_or_none(payload.unit_weight_kg),
            "unit_volume_cbm": _decimal_or_none(payload.unit_volume_cbm),
            "length_cm": _decimal_or_none(payload.length_cm),
            "width_cm": _decimal_or_none(payload.width_cm),
            "height_cm": _decimal_or_none(payload.height_cm),
            "status": _item_status(payload.status, payload.is_active),
            "is_active": payload.is_active,
            "metadata": _metadata(
                payload,
                category_code=payload.category_code,
                category_name=payload.category_name,
                base_uom_code=payload.base_uom_code,
                base_uom_name=payload.base_uom_name,
            ),
            "channel": source["channel"],
            "ip": source["ip"],
            "client": source["client"],
        }

        query = sql.SQL(
            """
            insert into {items} (
                tenant_id, item_category_id, base_uom_id, item_code, item_name,
                item_description, sku, barcode, nmfc_code, hs_code,
                is_hazardous, hazardous_class, temperature_controlled,
                min_temperature_c, max_temperature_c, unit_weight_kg,
                unit_volume_cbm, length_cm, width_cm, height_cm,
                status, is_active, metadata, created_channel_code,
                created_from_ip, created_from_client, updated_channel_code,
                updated_from_ip, updated_from_client
            )
            values (
                %(tenant_id)s, %(item_category_id)s, %(base_uom_id)s,
                %(item_code)s, %(item_name)s, %(item_description)s, %(sku)s,
                %(barcode)s, %(nmfc_code)s, %(hs_code)s, %(is_hazardous)s,
                %(hazardous_class)s, %(temperature_controlled)s,
                %(min_temperature_c)s, %(max_temperature_c)s,
                %(unit_weight_kg)s, %(unit_volume_cbm)s, %(length_cm)s,
                %(width_cm)s, %(height_cm)s, %(status)s, %(is_active)s,
                %(metadata)s, %(channel)s, %(ip)s, %(client)s,
                %(channel)s, %(ip)s, %(client)s
            )
            on conflict (tenant_id, item_code)
            where deleted_at is null
            do update set
                item_category_id = excluded.item_category_id,
                base_uom_id = excluded.base_uom_id,
                item_name = excluded.item_name,
                item_description = excluded.item_description,
                sku = excluded.sku,
                barcode = excluded.barcode,
                nmfc_code = excluded.nmfc_code,
                hs_code = excluded.hs_code,
                is_hazardous = excluded.is_hazardous,
                hazardous_class = excluded.hazardous_class,
                temperature_controlled = excluded.temperature_controlled,
                min_temperature_c = excluded.min_temperature_c,
                max_temperature_c = excluded.max_temperature_c,
                unit_weight_kg = excluded.unit_weight_kg,
                unit_volume_cbm = excluded.unit_volume_cbm,
                length_cm = excluded.length_cm,
                width_cm = excluded.width_cm,
                height_cm = excluded.height_cm,
                status = excluded.status,
                is_active = excluded.is_active,
                metadata = excluded.metadata,
                updated_at = now(),
                updated_channel_code = excluded.updated_channel_code,
                updated_from_ip = excluded.updated_from_ip,
                updated_from_client = excluded.updated_from_client
            returning item_id, item_code
            """
        ).format(items=table_identifier("items"))

        with conn.cursor() as cur:
            cur.execute(query, params)
            row = cur.fetchone()

        return {
            "saved": True,
            "table": "items",
            "id": row["item_id"],
            "code": row["item_code"],
        }

    return _run_db_save(save)


def _slug_code(prefix: str, value: str | None, fallback: str | None = None) -> str:
    raw = _clean_text(value, uppercase=True) or _clean_text(fallback, uppercase=True) or prefix
    slug = re.sub(r"[^A-Z0-9]+", "_", raw).strip("_")
    if not slug:
        slug = prefix
    if not slug.startswith(prefix):
        slug = f"{prefix}_{slug}"
    return slug[:80]


def _rate_agreement_type(value: str | None) -> str:
    agreement_type = _clean_text(value, uppercase=True) or "SELL"
    return agreement_type if agreement_type in {"BUY", "SELL"} else "SELL"


def _rate_partner_type(payload: RateAgreementPayload) -> str:
    partner_type = _clean_text(payload.partner_type, uppercase=True)
    if partner_type:
        return partner_type
    return "CARRIER" if _rate_agreement_type(payload.agreement_type) == "BUY" else "CUSTOMER"


def _rate_agreement_status(status_code: str | None, is_active: bool) -> str:
    status_value = _clean_text(status_code, uppercase=True) or "DRAFT"
    if not is_active and status_value == "ACTIVE":
        return "EXPIRED"
    if status_value not in {"DRAFT", "ACTIVE", "EXPIRED", "CANCELLED"}:
        return "DRAFT"
    return status_value


def _rate_lane_status(is_active: bool) -> str:
    return "ACTIVE" if is_active else "INACTIVE"


def _charge_category(value: str | None) -> str:
    category = _clean_text(value, uppercase=True) or "BASE"
    if category not in {"BASE", "FUEL", "ACCESSORIAL", "TAX", "DISCOUNT", "PENALTY"}:
        return "BASE"
    return category


def _calculation_method(value: str | None) -> str:
    method = _clean_text(value, uppercase=True) or "FLAT"
    allowed = {"FLAT", "PER_KM", "PER_KG", "PER_CBM", "PER_PALLET", "PER_STOP", "PERCENT"}
    return method if method in allowed else "FLAT"


def _ensure_rate_partner_id(
    conn: psycopg.Connection,
    context: MasterContext,
    payload: RateAgreementPayload,
    source: dict[str, str | None],
) -> int:
    if context.company_id is None:
        raise RuntimeError("No company context was found for rate agreement.")

    agreement_no = _clean_text(payload.agreement_no, uppercase=True)
    partner_type = _rate_partner_type(payload)
    prefix = "CAR" if partner_type == "CARRIER" else "CUS"
    partner_code = _clean_text(payload.partner_code, uppercase=True) or _slug_code(
        prefix,
        payload.partner_name,
        agreement_no,
    )
    partner_name = _clean_text(payload.partner_name) or partner_code

    query = sql.SQL(
        """
        insert into {business_partners} (
            tenant_id, company_id, partner_code, partner_name,
            partner_short_name, partner_type, status, is_active, metadata,
            created_channel_code, created_from_ip, created_from_client,
            updated_channel_code, updated_from_ip, updated_from_client
        )
        values (
            %(tenant_id)s, %(company_id)s, %(partner_code)s, %(partner_name)s,
            %(partner_short_name)s, %(partner_type)s, 'ACTIVE', true,
            %(metadata)s, %(channel)s, %(ip)s, %(client)s,
            %(channel)s, %(ip)s, %(client)s
        )
        on conflict (tenant_id, company_id, partner_code)
        where deleted_at is null
        do update set
            partner_name = excluded.partner_name,
            partner_short_name = excluded.partner_short_name,
            partner_type = excluded.partner_type,
            is_active = true,
            metadata = {business_partners}.metadata || excluded.metadata,
            updated_at = now(),
            updated_channel_code = excluded.updated_channel_code,
            updated_from_ip = excluded.updated_from_ip,
            updated_from_client = excluded.updated_from_client
        returning partner_id
        """
    ).format(business_partners=table_identifier("business_partners"))

    with conn.cursor() as cur:
        cur.execute(
            query,
            {
                "tenant_id": context.tenant_id,
                "company_id": context.company_id,
                "partner_code": partner_code,
                "partner_name": partner_name,
                "partner_short_name": partner_name,
                "partner_type": partner_type,
                "metadata": Jsonb(
                    {
                        "source": "ktms_rate_master",
                        "created_for_agreement_no": agreement_no,
                    }
                ),
                "channel": source["channel"],
                "ip": source["ip"],
                "client": source["client"],
            },
        )
        row = cur.fetchone()

    return int(row["partner_id"])


def _ensure_charge_code_id(
    conn: psycopg.Connection,
    tenant_id: int,
    payload: RateAgreementPayload,
    source: dict[str, str | None],
) -> int:
    charge_code = _clean_text(payload.charge_code, uppercase=True) or "BASE_FREIGHT"
    charge_name = _clean_text(payload.charge_name) or "기본 운임"
    category = _charge_category(payload.charge_category)

    query = sql.SQL(
        """
        insert into {charge_codes} (
            tenant_id, charge_code, charge_name, charge_category, taxable,
            is_active, metadata, created_channel_code, created_from_ip,
            created_from_client, updated_channel_code, updated_from_ip,
            updated_from_client
        )
        values (
            %(tenant_id)s, %(charge_code)s, %(charge_name)s,
            %(charge_category)s, %(taxable)s, true, %(metadata)s,
            %(channel)s, %(ip)s, %(client)s, %(channel)s, %(ip)s, %(client)s
        )
        on conflict (tenant_id, charge_code)
        where deleted_at is null
        do update set
            charge_name = excluded.charge_name,
            charge_category = excluded.charge_category,
            taxable = excluded.taxable,
            is_active = true,
            metadata = {charge_codes}.metadata || excluded.metadata,
            updated_at = now(),
            updated_channel_code = excluded.updated_channel_code,
            updated_from_ip = excluded.updated_from_ip,
            updated_from_client = excluded.updated_from_client
        returning charge_code_id
        """
    ).format(charge_codes=table_identifier("charge_codes"))

    with conn.cursor() as cur:
        cur.execute(
            query,
            {
                "tenant_id": tenant_id,
                "charge_code": charge_code,
                "charge_name": charge_name,
                "charge_category": category,
                "taxable": payload.tax_included,
                "metadata": Jsonb({"source": "ktms_rate_master"}),
                "channel": source["channel"],
                "ip": source["ip"],
                "client": source["client"],
            },
        )
        row = cur.fetchone()

    return int(row["charge_code_id"])


def _find_rate_agreement_lane_id(
    conn: psycopg.Connection,
    rate_agreement_id: int,
    lane_code: str | None,
) -> int | None:
    code = _clean_text(lane_code, uppercase=True)
    if not code:
        return None

    query = sql.SQL(
        """
        select rate_agreement_lane_id
        from {rate_agreement_lanes}
        where rate_agreement_id = %s
          and deleted_at is null
          and metadata->>'lane_code' = %s
        order by rate_agreement_lane_id
        limit 1
        """
    ).format(rate_agreement_lanes=table_identifier("rate_agreement_lanes"))

    with conn.cursor() as cur:
        cur.execute(query, (rate_agreement_id, code))
        row = cur.fetchone()

    return int(row["rate_agreement_lane_id"]) if row else None


def _save_rate_lane(
    conn: psycopg.Connection,
    tenant_id: int,
    rate_agreement_id: int,
    payload: RateAgreementPayload,
    source: dict[str, str | None],
) -> int:
    lane_code = _clean_text(payload.lane_code, uppercase=True) or "DEFAULT"
    existing_id = _find_rate_agreement_lane_id(conn, rate_agreement_id, lane_code)
    params = {
        "tenant_id": tenant_id,
        "rate_agreement_id": rate_agreement_id,
        "rate_agreement_lane_id": existing_id,
        "min_charge_amount": _decimal_or_none(payload.min_charge_amount),
        "base_rate_amount": _decimal_or_none(payload.base_rate_amount),
        "transit_hours": payload.transit_hours,
        "effective_from": _date_or_none(payload.effective_from),
        "effective_to": _date_or_none(payload.effective_to),
        "status": _rate_lane_status(payload.is_active),
        "is_active": payload.is_active,
        "metadata": Jsonb(
            {
                "source": "ktms_rate_master",
                "lane_code": lane_code,
                "origin_name": _clean_text(payload.origin_name),
                "destination_name": _clean_text(payload.destination_name),
                "mode_code": _clean_text(payload.mode_code, uppercase=True),
                "mode_name": _clean_text(payload.mode_name),
                "service_level_code": _clean_text(payload.service_level_code, uppercase=True),
                "service_level_name": _clean_text(payload.service_level_name),
                "equipment_code": _clean_text(payload.equipment_code, uppercase=True),
                "equipment_name": _clean_text(payload.equipment_name),
                "toll_included": payload.toll_included,
            }
        ),
        "channel": source["channel"],
        "ip": source["ip"],
        "client": source["client"],
    }

    if existing_id:
        query = sql.SQL(
            """
            update {rate_agreement_lanes}
            set min_charge_amount = %(min_charge_amount)s,
                base_rate_amount = %(base_rate_amount)s,
                transit_hours = %(transit_hours)s,
                effective_from = %(effective_from)s::date,
                effective_to = %(effective_to)s::date,
                status = %(status)s,
                is_active = %(is_active)s,
                metadata = %(metadata)s,
                updated_at = now(),
                updated_channel_code = %(channel)s,
                updated_from_ip = %(ip)s,
                updated_from_client = %(client)s
            where rate_agreement_lane_id = %(rate_agreement_lane_id)s
            returning rate_agreement_lane_id
            """
        ).format(rate_agreement_lanes=table_identifier("rate_agreement_lanes"))
    else:
        query = sql.SQL(
            """
            insert into {rate_agreement_lanes} (
                tenant_id, rate_agreement_id, min_charge_amount,
                base_rate_amount, transit_hours, effective_from, effective_to,
                status, is_active, metadata, created_channel_code,
                created_from_ip, created_from_client, updated_channel_code,
                updated_from_ip, updated_from_client
            )
            values (
                %(tenant_id)s, %(rate_agreement_id)s, %(min_charge_amount)s,
                %(base_rate_amount)s, %(transit_hours)s,
                %(effective_from)s::date, %(effective_to)s::date, %(status)s,
                %(is_active)s, %(metadata)s, %(channel)s, %(ip)s, %(client)s,
                %(channel)s, %(ip)s, %(client)s
            )
            returning rate_agreement_lane_id
            """
        ).format(rate_agreement_lanes=table_identifier("rate_agreement_lanes"))

    with conn.cursor() as cur:
        cur.execute(query, params)
        row = cur.fetchone()

    return int(row["rate_agreement_lane_id"])


def _save_rate_charge_rule(
    conn: psycopg.Connection,
    tenant_id: int,
    rate_agreement_lane_id: int,
    charge_code_id: int,
    payload: RateAgreementPayload,
    source: dict[str, str | None],
) -> int:
    method = _calculation_method(payload.calculation_method)
    rate_amount = _decimal_or_none(payload.rate_amount)
    if rate_amount is None:
        rate_amount = _decimal_or_none(payload.base_rate_amount) or Decimal("0")

    lookup_query = sql.SQL(
        """
        select rate_charge_rule_id
        from {rate_charge_rules}
        where tenant_id = %s
          and rate_agreement_lane_id = %s
          and charge_code_id = %s
          and calculation_method = %s
          and deleted_at is null
        order by rate_charge_rule_id
        limit 1
        """
    ).format(rate_charge_rules=table_identifier("rate_charge_rules"))

    with conn.cursor() as cur:
        cur.execute(lookup_query, (tenant_id, rate_agreement_lane_id, charge_code_id, method))
        row = cur.fetchone()
        existing_id = int(row["rate_charge_rule_id"]) if row else None

    params = {
        "tenant_id": tenant_id,
        "rate_agreement_lane_id": rate_agreement_lane_id,
        "rate_charge_rule_id": existing_id,
        "charge_code_id": charge_code_id,
        "calculation_method": method,
        "unit_code": _clean_text(payload.unit_code, uppercase=True),
        "rate_amount": rate_amount,
        "minimum_amount": _decimal_or_none(payload.minimum_amount),
        "maximum_amount": _decimal_or_none(payload.maximum_amount),
        "is_active": payload.is_active,
        "metadata": Jsonb(
            {
                "source": "ktms_rate_master",
                "charge_code": _clean_text(payload.charge_code, uppercase=True),
                "charge_name": _clean_text(payload.charge_name),
                "tax_included": payload.tax_included,
            }
        ),
        "channel": source["channel"],
        "ip": source["ip"],
        "client": source["client"],
    }

    if existing_id:
        query = sql.SQL(
            """
            update {rate_charge_rules}
            set unit_code = %(unit_code)s,
                rate_amount = %(rate_amount)s,
                minimum_amount = %(minimum_amount)s,
                maximum_amount = %(maximum_amount)s,
                is_active = %(is_active)s,
                metadata = %(metadata)s,
                updated_at = now(),
                updated_channel_code = %(channel)s,
                updated_from_ip = %(ip)s,
                updated_from_client = %(client)s
            where rate_charge_rule_id = %(rate_charge_rule_id)s
            returning rate_charge_rule_id
            """
        ).format(rate_charge_rules=table_identifier("rate_charge_rules"))
    else:
        query = sql.SQL(
            """
            insert into {rate_charge_rules} (
                tenant_id, rate_agreement_lane_id, charge_code_id,
                calculation_method, unit_code, rate_amount, minimum_amount,
                maximum_amount, is_active, metadata, created_channel_code,
                created_from_ip, created_from_client, updated_channel_code,
                updated_from_ip, updated_from_client
            )
            values (
                %(tenant_id)s, %(rate_agreement_lane_id)s,
                %(charge_code_id)s, %(calculation_method)s, %(unit_code)s,
                %(rate_amount)s, %(minimum_amount)s, %(maximum_amount)s,
                %(is_active)s, %(metadata)s, %(channel)s, %(ip)s, %(client)s,
                %(channel)s, %(ip)s, %(client)s
            )
            returning rate_charge_rule_id
            """
        ).format(rate_charge_rules=table_identifier("rate_charge_rules"))

    with conn.cursor() as cur:
        cur.execute(query, params)
        row = cur.fetchone()

    return int(row["rate_charge_rule_id"])


def _save_fuel_surcharge_rule(
    conn: psycopg.Connection,
    tenant_id: int,
    rate_agreement_id: int,
    payload: RateAgreementPayload,
    source: dict[str, str | None],
) -> int | None:
    has_rule = (
        payload.fuel_surcharge_enabled
        or _clean_text(payload.fuel_index_name) is not None
        or _decimal_or_none(payload.surcharge_percent) is not None
        or _decimal_or_none(payload.surcharge_amount) is not None
    )
    if not has_rule:
        return None

    agreement_no = _clean_text(payload.agreement_no, uppercase=True) or "RATE"
    rule_code = _clean_text(payload.fuel_rule_code, uppercase=True) or _slug_code(
        "FUEL",
        f"{agreement_no}_FUEL",
    )[:80]
    rule_name = _clean_text(payload.fuel_rule_name) or f"{payload.agreement_name} 유류할증"

    query = sql.SQL(
        """
        insert into {fuel_surcharge_rules} (
            tenant_id, rate_agreement_id, rule_code, rule_name,
            fuel_index_name, baseline_price, surcharge_percent,
            surcharge_amount, effective_from, effective_to, is_active,
            metadata, created_channel_code, created_from_ip,
            created_from_client, updated_channel_code, updated_from_ip,
            updated_from_client
        )
        values (
            %(tenant_id)s, %(rate_agreement_id)s, %(rule_code)s,
            %(rule_name)s, %(fuel_index_name)s, %(baseline_price)s,
            %(surcharge_percent)s, %(surcharge_amount)s,
            %(effective_from)s::date, %(effective_to)s::date, %(is_active)s,
            %(metadata)s, %(channel)s, %(ip)s, %(client)s,
            %(channel)s, %(ip)s, %(client)s
        )
        on conflict (tenant_id, rule_code)
        where deleted_at is null
        do update set
            rate_agreement_id = excluded.rate_agreement_id,
            rule_name = excluded.rule_name,
            fuel_index_name = excluded.fuel_index_name,
            baseline_price = excluded.baseline_price,
            surcharge_percent = excluded.surcharge_percent,
            surcharge_amount = excluded.surcharge_amount,
            effective_from = excluded.effective_from,
            effective_to = excluded.effective_to,
            is_active = excluded.is_active,
            metadata = excluded.metadata,
            updated_at = now(),
            updated_channel_code = excluded.updated_channel_code,
            updated_from_ip = excluded.updated_from_ip,
            updated_from_client = excluded.updated_from_client
        returning fuel_surcharge_rule_id
        """
    ).format(fuel_surcharge_rules=table_identifier("fuel_surcharge_rules"))

    with conn.cursor() as cur:
        cur.execute(
            query,
            {
                "tenant_id": tenant_id,
                "rate_agreement_id": rate_agreement_id,
                "rule_code": rule_code,
                "rule_name": rule_name,
                "fuel_index_name": _clean_text(payload.fuel_index_name),
                "baseline_price": _decimal_or_none(payload.baseline_price),
                "surcharge_percent": _decimal_or_none(payload.surcharge_percent),
                "surcharge_amount": _decimal_or_none(payload.surcharge_amount),
                "effective_from": _date_or_none(payload.effective_from),
                "effective_to": _date_or_none(payload.effective_to),
                "is_active": payload.is_active,
                "metadata": Jsonb({"source": "ktms_rate_master"}),
                "channel": source["channel"],
                "ip": source["ip"],
                "client": source["client"],
            },
        )
        row = cur.fetchone()

    return int(row["fuel_surcharge_rule_id"])


@router.post("/rate-agreements")
def save_rate_agreement(payload: RateAgreementPayload, request: Request):
    def save(conn: psycopg.Connection) -> dict[str, Any]:
        context = _master_context(
            conn,
            tenant_id=payload.tenant_id,
            company_id=payload.company_id,
        )
        source = _client_source(request)
        partner_id = _ensure_rate_partner_id(conn, context, payload, source)

        params = {
            "tenant_id": context.tenant_id,
            "agreement_no": _clean_text(payload.agreement_no, uppercase=True),
            "agreement_name": _clean_text(payload.agreement_name),
            "agreement_type": _rate_agreement_type(payload.agreement_type),
            "partner_id": partner_id,
            "currency_code": (_clean_text(payload.currency_code, uppercase=True) or "KRW")[:3],
            "effective_from": _date_or_none(payload.effective_from),
            "effective_to": _date_or_none(payload.effective_to),
            "status": _rate_agreement_status(payload.status, payload.is_active),
            "is_active": payload.is_active,
            "metadata": _metadata(
                payload,
                partner_code=payload.partner_code,
                partner_name=payload.partner_name,
                partner_type=_rate_partner_type(payload),
                contract_owner=payload.contract_owner,
                payment_terms=payload.payment_terms,
                auto_rating=payload.auto_rating,
                toll_included=payload.toll_included,
                tax_included=payload.tax_included,
                memo=payload.memo,
            ),
            "channel": source["channel"],
            "ip": source["ip"],
            "client": source["client"],
        }

        query = sql.SQL(
            """
            insert into {rate_agreements} (
                tenant_id, agreement_no, agreement_name, agreement_type,
                partner_id, currency_code, effective_from, effective_to,
                status, is_active, metadata, created_channel_code,
                created_from_ip, created_from_client, updated_channel_code,
                updated_from_ip, updated_from_client
            )
            values (
                %(tenant_id)s, %(agreement_no)s, %(agreement_name)s,
                %(agreement_type)s, %(partner_id)s, %(currency_code)s,
                %(effective_from)s::date, %(effective_to)s::date, %(status)s,
                %(is_active)s, %(metadata)s, %(channel)s, %(ip)s, %(client)s,
                %(channel)s, %(ip)s, %(client)s
            )
            on conflict (tenant_id, agreement_no)
            where deleted_at is null
            do update set
                agreement_name = excluded.agreement_name,
                agreement_type = excluded.agreement_type,
                partner_id = excluded.partner_id,
                currency_code = excluded.currency_code,
                effective_from = excluded.effective_from,
                effective_to = excluded.effective_to,
                status = excluded.status,
                is_active = excluded.is_active,
                metadata = excluded.metadata,
                updated_at = now(),
                updated_channel_code = excluded.updated_channel_code,
                updated_from_ip = excluded.updated_from_ip,
                updated_from_client = excluded.updated_from_client
            returning rate_agreement_id, agreement_no
            """
        ).format(rate_agreements=table_identifier("rate_agreements"))

        with conn.cursor() as cur:
            cur.execute(query, params)
            agreement = cur.fetchone()

        rate_agreement_id = int(agreement["rate_agreement_id"])
        lane_id = _save_rate_lane(conn, context.tenant_id, rate_agreement_id, payload, source)
        charge_code_id = _ensure_charge_code_id(conn, context.tenant_id, payload, source)
        charge_rule_id = _save_rate_charge_rule(
            conn,
            context.tenant_id,
            lane_id,
            charge_code_id,
            payload,
            source,
        )
        fuel_rule_id = _save_fuel_surcharge_rule(
            conn,
            context.tenant_id,
            rate_agreement_id,
            payload,
            source,
        )

        return {
            "saved": True,
            "table": "rate_agreements",
            "id": rate_agreement_id,
            "code": agreement["agreement_no"],
            "lane_id": lane_id,
            "charge_rule_id": charge_rule_id,
            "fuel_rule_id": fuel_rule_id,
        }

    return _run_db_save(save)


def _user_status(status_code: str | None, is_active: bool) -> str:
    if not is_active:
        return "INACTIVE"
    status_value = _clean_text(status_code, uppercase=True) or "ACTIVE"
    if status_value not in {"ACTIVE", "LOCKED", "INACTIVE", "INVITED"}:
        return "ACTIVE"
    return status_value


def _login_id(value: str | None) -> str | None:
    login_id = _clean_text(value)
    return login_id.lower() if login_id else None


def _permission_parts(permission_code: str) -> tuple[str, str]:
    code = _clean_text(permission_code, uppercase=True) or "SYSTEM.READ"
    if "." in code:
        module_code, action_code = code.split(".", 1)
    else:
        module_code, action_code = code, "ACCESS"
    return module_code[:60], action_code[:60]


def _permission_name(permission_code: str) -> str:
    names = {
        "DASHBOARD.READ": "관제 대시보드 조회",
        "ORDER.READ": "오더 조회",
        "ORDER.WRITE": "오더 등록/수정",
        "PLANNING.WRITE": "편성/상차조합",
        "DISPATCH.WRITE": "배정/배차",
        "TRACKING.READ": "실행 트래킹 조회",
        "SETTLEMENT.APPROVE": "실적/정산 확정",
        "INVOICE.WRITE": "거래명세서 생성",
        "MASTER.WRITE": "마스터 등록/수정",
        "USER_ADMIN.WRITE": "사용자/권한 관리",
        "REPORT.READ": "리포트 조회",
        "SYSTEM.CONFIG": "시스템 설정",
    }
    return names.get(permission_code, permission_code)


def _ensure_permission_id(
    conn: psycopg.Connection,
    permission_code: str,
    source: dict[str, str | None],
) -> int:
    code = _clean_text(permission_code, uppercase=True) or "SYSTEM.READ"
    module_code, action_code = _permission_parts(code)
    query = sql.SQL(
        """
        insert into {permissions} (
            permission_code, module_code, action_code, permission_name,
            description, is_active, created_channel_code, created_from_ip,
            created_from_client, updated_channel_code, updated_from_ip,
            updated_from_client
        )
        values (
            %(permission_code)s, %(module_code)s, %(action_code)s,
            %(permission_name)s, %(description)s, true, %(channel)s,
            %(ip)s, %(client)s, %(channel)s, %(ip)s, %(client)s
        )
        on conflict (permission_code)
        where deleted_at is null
        do update set
            module_code = excluded.module_code,
            action_code = excluded.action_code,
            permission_name = excluded.permission_name,
            description = excluded.description,
            is_active = true,
            updated_at = now(),
            updated_channel_code = excluded.updated_channel_code,
            updated_from_ip = excluded.updated_from_ip,
            updated_from_client = excluded.updated_from_client
        returning permission_id
        """
    ).format(permissions=table_identifier("permissions"))

    with conn.cursor() as cur:
        cur.execute(
            query,
            {
                "permission_code": code,
                "module_code": module_code,
                "action_code": action_code,
                "permission_name": _permission_name(code),
                "description": f"KTMS {module_code} {action_code} permission",
                "channel": source["channel"],
                "ip": source["ip"],
                "client": source["client"],
            },
        )
        row = cur.fetchone()

    return int(row["permission_id"])


def _ensure_user_role_id(
    conn: psycopg.Connection,
    tenant_id: int,
    payload: UserAccessPayload,
    source: dict[str, str | None],
) -> int:
    role_code = _clean_text(payload.role_code, uppercase=True) or _slug_code(
        "ROLE",
        payload.role_name,
        payload.login_id,
    )
    role_name = _clean_text(payload.role_name) or role_code
    query = sql.SQL(
        """
        insert into {roles} (
            tenant_id, role_code, role_name, description, is_system,
            is_active, metadata, created_channel_code, created_from_ip,
            created_from_client, updated_channel_code, updated_from_ip,
            updated_from_client
        )
        values (
            %(tenant_id)s, %(role_code)s, %(role_name)s, %(description)s,
            false, true, %(metadata)s, %(channel)s, %(ip)s, %(client)s,
            %(channel)s, %(ip)s, %(client)s
        )
        on conflict (tenant_id, role_code)
        where deleted_at is null
        do update set
            role_name = excluded.role_name,
            description = excluded.description,
            is_active = true,
            metadata = excluded.metadata,
            updated_at = now(),
            updated_channel_code = excluded.updated_channel_code,
            updated_from_ip = excluded.updated_from_ip,
            updated_from_client = excluded.updated_from_client
        returning role_id
        """
    ).format(roles=table_identifier("roles"))

    with conn.cursor() as cur:
        cur.execute(
            query,
            {
                "tenant_id": tenant_id,
                "role_code": role_code,
                "role_name": role_name,
                "description": _clean_text(payload.role_description),
                "metadata": _metadata(
                    payload,
                    role_profile=payload.role_profile,
                    data_scope=payload.data_scope,
                    permissions_count=len(payload.permissions),
                ),
                "channel": source["channel"],
                "ip": source["ip"],
                "client": source["client"],
            },
        )
        row = cur.fetchone()

    return int(row["role_id"])


def _sync_role_permissions(
    conn: psycopg.Connection,
    role_id: int,
    permission_codes: list[str],
    source: dict[str, str | None],
) -> list[int]:
    cleaned_codes = sorted(
        {
            code
            for code in (
                _clean_text(permission_code, uppercase=True)
                for permission_code in permission_codes
            )
            if code
        }
    )
    permission_ids = [
        _ensure_permission_id(conn, permission_code, source)
        for permission_code in cleaned_codes
    ]

    with conn.cursor() as cur:
        if permission_ids:
            cur.execute(
                sql.SQL(
                    """
                    update {role_permissions}
                    set is_active = false,
                        updated_at = now(),
                        updated_channel_code = %s,
                        updated_from_ip = %s,
                        updated_from_client = %s
                    where role_id = %s
                      and permission_id <> all(%s)
                    """
                ).format(role_permissions=table_identifier("role_permissions")),
                (source["channel"], source["ip"], source["client"], role_id, permission_ids),
            )
        cur.execute(
            sql.SQL(
                """
                update {role_permissions}
                set is_active = false,
                    updated_at = now(),
                    updated_channel_code = %s,
                    updated_from_ip = %s,
                    updated_from_client = %s
                where role_id = %s
                """
            ).format(role_permissions=table_identifier("role_permissions")),
            (source["channel"], source["ip"], source["client"], role_id),
        ) if not permission_ids else None

        for permission_id in permission_ids:
            cur.execute(
                sql.SQL(
                    """
                    insert into {role_permissions} (
                        role_id, permission_id, created_channel_code,
                        created_from_ip, created_from_client, updated_channel_code,
                        updated_from_ip, updated_from_client, is_active
                    )
                    values (%s, %s, %s, %s, %s, %s, %s, %s, true)
                    on conflict (role_id, permission_id)
                    do update set
                        is_active = true,
                        updated_at = now(),
                        updated_channel_code = excluded.updated_channel_code,
                        updated_from_ip = excluded.updated_from_ip,
                        updated_from_client = excluded.updated_from_client
                    """
                ).format(role_permissions=table_identifier("role_permissions")),
                (
                    role_id,
                    permission_id,
                    source["channel"],
                    source["ip"],
                    source["client"],
                    source["channel"],
                    source["ip"],
                    source["client"],
                ),
            )

    return permission_ids


def _assign_user_role(
    conn: psycopg.Connection,
    user_id: int,
    role_id: int,
    expires_at: str | None,
    source: dict[str, str | None],
) -> None:
    query = sql.SQL(
        """
        insert into {user_roles} (
            user_id, role_id, expires_at, created_channel_code,
            created_from_ip, created_from_client, updated_channel_code,
            updated_from_ip, updated_from_client, is_active
        )
        values (
            %(user_id)s, %(role_id)s, %(expires_at)s::timestamptz,
            %(channel)s, %(ip)s, %(client)s, %(channel)s, %(ip)s, %(client)s,
            true
        )
        on conflict (user_id, role_id)
        do update set
            expires_at = excluded.expires_at,
            is_active = true,
            updated_at = now(),
            updated_channel_code = excluded.updated_channel_code,
            updated_from_ip = excluded.updated_from_ip,
            updated_from_client = excluded.updated_from_client
        """
    ).format(user_roles=table_identifier("user_roles"))

    with conn.cursor() as cur:
        cur.execute(
            sql.SQL(
                """
                update {user_roles}
                set is_active = false,
                    updated_at = now(),
                    updated_channel_code = %s,
                    updated_from_ip = %s,
                    updated_from_client = %s
                where user_id = %s
                  and role_id <> %s
                """
            ).format(user_roles=table_identifier("user_roles")),
            (source["channel"], source["ip"], source["client"], user_id, role_id),
        )
        cur.execute(
            query,
            {
                "user_id": user_id,
                "role_id": role_id,
                "expires_at": _clean_text(expires_at),
                "channel": source["channel"],
                "ip": source["ip"],
                "client": source["client"],
            },
        )


@router.post("/user-access")
def save_user_access(payload: UserAccessPayload, request: Request):
    def save(conn: psycopg.Connection) -> dict[str, Any]:
        context = _master_context(
            conn,
            tenant_id=payload.tenant_id,
            company_id=payload.company_id,
        )
        source = _client_source(request)
        role_id = _ensure_user_role_id(conn, context.tenant_id, payload, source)
        permission_ids = _sync_role_permissions(
            conn,
            role_id,
            payload.permissions,
            source,
        )

        params = {
            "tenant_id": context.tenant_id,
            "company_id": context.company_id,
            "login_id": _login_id(payload.login_id),
            "email": _login_id(payload.email),
            "full_name": _clean_text(payload.full_name),
            "phone": _clean_text(payload.phone),
            "mobile": _clean_text(payload.mobile),
            "language_code": _clean_text(payload.language_code) or "ko",
            "timezone_name": _clean_text(payload.timezone_name) or "Asia/Seoul",
            "status": _user_status(payload.status, payload.is_active),
            "mfa_enabled": payload.mfa_enabled,
            "is_active": payload.is_active,
            "metadata": _metadata(
                payload,
                auth_provider="FIREBASE",
                department_name=payload.department_name,
                business_unit_name=payload.business_unit_name,
                role_code=payload.role_code,
                role_name=payload.role_name,
                role_profile=payload.role_profile,
                data_scope=payload.data_scope,
                allow_web=payload.allow_web,
                allow_mobile=payload.allow_mobile,
                require_approval=payload.require_approval,
                memo=payload.memo,
            ),
            "channel": source["channel"],
            "ip": source["ip"],
            "client": source["client"],
        }

        query = sql.SQL(
            """
            insert into {app_users} (
                tenant_id, company_id, login_id, email, full_name, phone,
                mobile, language_code, timezone_name, status, mfa_enabled,
                is_active, metadata, created_channel_code, created_from_ip,
                created_from_client, updated_channel_code, updated_from_ip,
                updated_from_client
            )
            values (
                %(tenant_id)s, %(company_id)s, %(login_id)s, %(email)s,
                %(full_name)s, %(phone)s, %(mobile)s, %(language_code)s,
                %(timezone_name)s, %(status)s, %(mfa_enabled)s, %(is_active)s,
                %(metadata)s, %(channel)s, %(ip)s, %(client)s,
                %(channel)s, %(ip)s, %(client)s
            )
            on conflict (tenant_id, login_id)
            where deleted_at is null
            do update set
                company_id = excluded.company_id,
                email = excluded.email,
                full_name = excluded.full_name,
                phone = excluded.phone,
                mobile = excluded.mobile,
                language_code = excluded.language_code,
                timezone_name = excluded.timezone_name,
                status = excluded.status,
                mfa_enabled = excluded.mfa_enabled,
                is_active = excluded.is_active,
                metadata = excluded.metadata,
                updated_at = now(),
                updated_channel_code = excluded.updated_channel_code,
                updated_from_ip = excluded.updated_from_ip,
                updated_from_client = excluded.updated_from_client
            returning user_id, login_id
            """
        ).format(app_users=table_identifier("app_users"))

        with conn.cursor() as cur:
            cur.execute(query, params)
            user = cur.fetchone()

        user_id = int(user["user_id"])
        _assign_user_role(conn, user_id, role_id, payload.expires_at, source)

        return {
            "saved": True,
            "table": "app_users",
            "id": user_id,
            "code": user["login_id"],
            "role_id": role_id,
            "permission_count": len(permission_ids),
        }

    return _run_db_save(save)


@router.post("/common-codes")
def save_common_code(payload: CommonCodePayload, request: Request):
    def save(conn: psycopg.Connection) -> dict[str, Any]:
        context = _master_context(conn, tenant_id=payload.tenant_id)
        source = _client_source(request)
        group_code = _clean_text(payload.group_code, uppercase=True)
        code = _clean_text(payload.code, uppercase=True)
        params = {
            "tenant_id": context.tenant_id,
            "group_code": group_code,
            "group_name": _clean_text(payload.group_name),
            "group_description": _clean_text(payload.group_description),
            "group_is_system": payload.group_is_system,
            "is_active": payload.is_active,
            "group_metadata": _metadata(
                payload,
                applies_to=payload.applies_to,
                memo=payload.memo,
            ),
            "code": code,
            "code_name": _clean_text(payload.code_name),
            "code_value": _clean_text(payload.code_value),
            "sort_order": payload.sort_order,
            "is_default": payload.is_default,
            "code_metadata": _metadata(
                payload,
                group_code=group_code,
                applies_to=payload.applies_to,
                memo=payload.memo,
                color_hex=payload.color_hex,
                icon_name=payload.icon_name,
            ),
            "channel": source["channel"],
            "ip": source["ip"],
            "client": source["client"],
        }

        group_query = sql.SQL(
            """
            insert into {code_groups} (
                tenant_id, group_code, group_name, description, is_system,
                is_active, metadata, created_channel_code, created_from_ip,
                created_from_client, updated_channel_code, updated_from_ip,
                updated_from_client
            )
            values (
                %(tenant_id)s, %(group_code)s, %(group_name)s,
                %(group_description)s, %(group_is_system)s, %(is_active)s,
                %(group_metadata)s, %(channel)s, %(ip)s, %(client)s,
                %(channel)s, %(ip)s, %(client)s
            )
            on conflict (tenant_id, group_code)
            where deleted_at is null
            do update set
                group_name = excluded.group_name,
                description = excluded.description,
                is_system = excluded.is_system,
                is_active = excluded.is_active,
                metadata = excluded.metadata,
                updated_at = now(),
                updated_channel_code = excluded.updated_channel_code,
                updated_from_ip = excluded.updated_from_ip,
                updated_from_client = excluded.updated_from_client
            returning code_group_id, group_code
            """
        ).format(code_groups=table_identifier("code_groups"))

        code_query = sql.SQL(
            """
            insert into {codes} (
                tenant_id, code_group_id, code, code_name, code_value,
                sort_order, is_default, is_active, metadata,
                created_channel_code, created_from_ip, created_from_client,
                updated_channel_code, updated_from_ip, updated_from_client
            )
            values (
                %(tenant_id)s, %(code_group_id)s, %(code)s, %(code_name)s,
                %(code_value)s, %(sort_order)s, %(is_default)s, %(is_active)s,
                %(code_metadata)s, %(channel)s, %(ip)s, %(client)s,
                %(channel)s, %(ip)s, %(client)s
            )
            on conflict (code_group_id, code)
            where deleted_at is null
            do update set
                code_name = excluded.code_name,
                code_value = excluded.code_value,
                sort_order = excluded.sort_order,
                is_default = excluded.is_default,
                is_active = excluded.is_active,
                metadata = excluded.metadata,
                updated_at = now(),
                updated_channel_code = excluded.updated_channel_code,
                updated_from_ip = excluded.updated_from_ip,
                updated_from_client = excluded.updated_from_client
            returning code_id, code
            """
        ).format(codes=table_identifier("codes"))

        with conn.cursor() as cur:
            cur.execute(group_query, params)
            group = cur.fetchone()
            params["code_group_id"] = group["code_group_id"]
            cur.execute(code_query, params)
            row = cur.fetchone()

            if payload.is_default:
                cur.execute(
                    sql.SQL(
                        """
                        update {codes}
                        set is_default = false,
                            updated_at = now(),
                            updated_channel_code = %s,
                            updated_from_ip = %s,
                            updated_from_client = %s
                        where code_group_id = %s
                          and code_id <> %s
                          and deleted_at is null
                        """
                    ).format(codes=table_identifier("codes")),
                    (
                        source["channel"],
                        source["ip"],
                        source["client"],
                        group["code_group_id"],
                        row["code_id"],
                    ),
                )

        return {
            "saved": True,
            "table": "codes",
            "id": row["code_id"],
            "code": row["code"],
            "group_id": group["code_group_id"],
            "group_code": group["group_code"],
        }

    return _run_db_save(save)
