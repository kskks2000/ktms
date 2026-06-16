from __future__ import annotations

from decimal import Decimal, InvalidOperation
import re
from typing import Any

import psycopg
from fastapi import APIRouter, HTTPException, Request, status
from pydantic import BaseModel, ConfigDict, Field
from psycopg import sql
from psycopg.types.json import Jsonb

from app.core.database import (
    MasterContext,
    db_connection,
    default_master_context,
    table_identifier,
)


router = APIRouter(prefix="/orders", tags=["orders"])


class OrderLinePayload(BaseModel):
    model_config = ConfigDict(extra="ignore")

    line_no: int = 1
    item_description: str | None = None
    quantity: str | int | float | Decimal = 0
    uom_code: str | None = "EA"
    package_count: int = 0
    gross_weight_kg: str | int | float | Decimal = 0
    net_weight_kg: str | int | float | Decimal | None = None
    volume_cbm: str | int | float | Decimal = 0
    length_cm: str | int | float | Decimal | None = None
    width_cm: str | int | float | Decimal | None = None
    height_cm: str | int | float | Decimal | None = None
    lot_no: str | None = None
    serial_no: str | None = None
    expiry_date: str | None = None
    temperature_min_c: str | int | float | Decimal | None = None
    temperature_max_c: str | int | float | Decimal | None = None
    hazmat_class: str | None = None
    metadata: dict[str, Any] = Field(default_factory=dict)


class TransportOrderPayload(BaseModel):
    model_config = ConfigDict(extra="ignore")

    tenant_id: int | None = None
    company_id: int | None = None
    order_no: str
    external_order_no: str | None = None
    customer_code: str | None = None
    customer_name: str
    shipper_name: str | None = None
    bill_to_name: str | None = None
    pickup_name: str | None = None
    pickup_address: str | None = None
    pickup_contact_name: str | None = None
    pickup_contact_phone: str | None = None
    requested_pickup_start: str | None = None
    requested_pickup_end: str | None = None
    delivery_name: str | None = None
    delivery_address: str | None = None
    delivery_contact_name: str | None = None
    delivery_contact_phone: str | None = None
    requested_delivery_start: str | None = None
    requested_delivery_end: str | None = None
    order_type: str = "STANDARD"
    order_status: str = "DRAFT"
    priority_code: str = "NORMAL"
    transport_mode_code: str | None = None
    transport_mode_name: str | None = None
    service_level_code: str | None = None
    service_level_name: str | None = None
    total_quantity: str | int | float | Decimal = 0
    total_packages: int = 0
    total_weight_kg: str | int | float | Decimal = 0
    total_volume_cbm: str | int | float | Decimal = 0
    declared_value_amount: str | int | float | Decimal | None = None
    charge_amount: str | int | float | Decimal | None = None
    currency_code: str = "KRW"
    incoterm_code: str | None = None
    temperature_min_c: str | int | float | Decimal | None = None
    temperature_max_c: str | int | float | Decimal | None = None
    hazmat_required: bool = False
    appointment_required: bool = False
    special_instructions: str | None = None
    source_system: str | None = "KTMS_WEB"
    lines: list[OrderLinePayload] = Field(default_factory=list)
    metadata: dict[str, Any] = Field(default_factory=dict)


def _clean_text(value: str | None, *, uppercase: bool = False) -> str | None:
    if value is None:
        return None
    cleaned = str(value).strip()
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


def _decimal_or_zero(value: str | int | float | Decimal | None) -> Decimal:
    return _decimal_or_none(value) or Decimal("0")


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


def _jsonb(data: dict[str, Any]) -> Jsonb:
    return Jsonb({key: value for key, value in data.items() if value not in (None, "")})


def _metadata(payload: TransportOrderPayload, **extra: Any) -> Jsonb:
    data = {"source": "ktms_order_registration", **payload.metadata}
    data.update({key: value for key, value in extra.items() if value not in (None, "")})
    return Jsonb(data)


def _slug_code(prefix: str, value: str | None, fallback: str | None = None) -> str:
    raw = _clean_text(value, uppercase=True) or _clean_text(fallback, uppercase=True) or prefix
    slug = re.sub(r"[^A-Z0-9]+", "_", raw).strip("_") or prefix
    if not slug.startswith(prefix):
        slug = f"{prefix}_{slug}"
    return slug[:80]


def _handle_db_error(exc: Exception) -> HTTPException:
    if isinstance(exc, psycopg.errors.UniqueViolation):
        return HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="이미 등록된 오더번호입니다.",
        )
    if isinstance(exc, RuntimeError):
        return HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail=str(exc))
    if isinstance(exc, psycopg.Error):
        return HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="DB 저장 중 오류가 발생했습니다.",
        )
    return HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail="오더 저장 중 오류가 발생했습니다.",
    )


def _run_db_save(callback):
    try:
        with db_connection() as conn:
            return callback(conn)
    except Exception as exc:
        raise _handle_db_error(exc) from exc


def _ensure_partner_id(
    conn: psycopg.Connection,
    context: MasterContext,
    partner_name: str | None,
    partner_type: str,
    source: dict[str, str | None],
    *,
    partner_code: str | None = None,
) -> int:
    if context.company_id is None:
        raise RuntimeError("No company context was found for transport order.")

    name = _clean_text(partner_name) or "미지정 거래처"
    code = _clean_text(partner_code, uppercase=True) or _slug_code(
        "CUS" if partner_type == "CUSTOMER" else partner_type[:3],
        name,
    )
    params = {
        "tenant_id": context.tenant_id,
        "company_id": context.company_id,
        "partner_code": code,
        "partner_name": name,
        "partner_type": partner_type,
        "metadata": Jsonb({"source": "ktms_order_registration"}),
        "channel": source["channel"],
        "ip": source["ip"],
        "client": source["client"],
    }
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
            %(partner_name)s, %(partner_type)s, 'ACTIVE', true, %(metadata)s,
            %(channel)s, %(ip)s, %(client)s, %(channel)s, %(ip)s, %(client)s
        )
        on conflict (tenant_id, company_id, partner_code)
        where deleted_at is null
        do update set
            partner_name = excluded.partner_name,
            partner_short_name = excluded.partner_short_name,
            partner_type = excluded.partner_type,
            status = 'ACTIVE',
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
        cur.execute(query, params)
        row = cur.fetchone()
    return int(row["partner_id"])


def _ensure_mode_id(
    conn: psycopg.Connection,
    tenant_id: int,
    code: str | None,
    name: str | None,
    source: dict[str, str | None],
) -> int | None:
    mode_code = _clean_text(code, uppercase=True)
    mode_name = _clean_text(name) or mode_code
    if not mode_code:
        return None
    with conn.cursor() as cur:
        cur.execute(
            sql.SQL(
                """
                select mode_id
                from {transport_modes}
                where tenant_id = %s
                  and deleted_at is null
                  and mode_code = %s
                order by mode_id
                limit 1
                """
            ).format(transport_modes=table_identifier("transport_modes")),
            (tenant_id, mode_code),
        )
        row = cur.fetchone()
        if row:
            return int(row["mode_id"])
        cur.execute(
            sql.SQL(
                """
                insert into {transport_modes} (
                    tenant_id, mode_code, mode_name, is_active, metadata,
                    created_channel_code, created_from_ip, created_from_client,
                    updated_channel_code, updated_from_ip, updated_from_client
                )
                values (%s, %s, %s, true, %s, %s, %s, %s, %s, %s, %s)
                returning mode_id
                """
            ).format(transport_modes=table_identifier("transport_modes")),
            (
                tenant_id,
                mode_code,
                mode_name,
                Jsonb({"source": "ktms_order_registration"}),
                source["channel"],
                source["ip"],
                source["client"],
                source["channel"],
                source["ip"],
                source["client"],
            ),
        )
        row = cur.fetchone()
    return int(row["mode_id"])


def _ensure_service_level_id(
    conn: psycopg.Connection,
    tenant_id: int,
    code: str | None,
    name: str | None,
    source: dict[str, str | None],
) -> int | None:
    service_code = _clean_text(code, uppercase=True)
    service_name = _clean_text(name) or service_code
    if not service_code:
        return None
    with conn.cursor() as cur:
        cur.execute(
            sql.SQL(
                """
                select service_level_id
                from {service_levels}
                where tenant_id = %s
                  and deleted_at is null
                  and service_code = %s
                order by service_level_id
                limit 1
                """
            ).format(service_levels=table_identifier("service_levels")),
            (tenant_id, service_code),
        )
        row = cur.fetchone()
        if row:
            return int(row["service_level_id"])
        cur.execute(
            sql.SQL(
                """
                insert into {service_levels} (
                    tenant_id, service_code, service_name, promised_transit_hours,
                    priority_rank, is_active, metadata, created_channel_code,
                    created_from_ip, created_from_client, updated_channel_code,
                    updated_from_ip, updated_from_client
                )
                values (%s, %s, %s, null, 100, true, %s, %s, %s, %s, %s, %s, %s)
                returning service_level_id
                """
            ).format(service_levels=table_identifier("service_levels")),
            (
                tenant_id,
                service_code,
                service_name,
                Jsonb({"source": "ktms_order_registration"}),
                source["channel"],
                source["ip"],
                source["client"],
                source["channel"],
                source["ip"],
                source["client"],
            ),
        )
        row = cur.fetchone()
    return int(row["service_level_id"])


def _ensure_uom_id(
    conn: psycopg.Connection,
    tenant_id: int,
    uom_code: str | None,
    source: dict[str, str | None],
) -> int | None:
    code = _clean_text(uom_code, uppercase=True)
    if not code:
        return None
    with conn.cursor() as cur:
        cur.execute(
            sql.SQL(
                """
                select uom_id
                from {item_uoms}
                where tenant_id = %s
                  and deleted_at is null
                  and uom_code = %s
                order by uom_id
                limit 1
                """
            ).format(item_uoms=table_identifier("item_uoms")),
            (tenant_id, code),
        )
        row = cur.fetchone()
        if row:
            return int(row["uom_id"])
        cur.execute(
            sql.SQL(
                """
                insert into {item_uoms} (
                    tenant_id, uom_code, uom_name, uom_type, decimal_places,
                    is_active, created_channel_code, created_from_ip,
                    created_from_client, updated_channel_code, updated_from_ip,
                    updated_from_client
                )
                values (%s, %s, %s, 'QUANTITY', 0, true, %s, %s, %s, %s, %s, %s)
                returning uom_id
                """
            ).format(item_uoms=table_identifier("item_uoms")),
            (
                tenant_id,
                code,
                code,
                source["channel"],
                source["ip"],
                source["client"],
                source["channel"],
                source["ip"],
                source["client"],
            ),
        )
        row = cur.fetchone()
    return int(row["uom_id"])


def _ensure_charge_code_id(
    conn: psycopg.Connection,
    tenant_id: int,
    source: dict[str, str | None],
) -> int:
    with conn.cursor() as cur:
        cur.execute(
            sql.SQL(
                """
                select charge_code_id
                from {charge_codes}
                where tenant_id = %s
                  and deleted_at is null
                  and charge_code = 'BASE_FREIGHT'
                order by charge_code_id
                limit 1
                """
            ).format(charge_codes=table_identifier("charge_codes")),
            (tenant_id,),
        )
        row = cur.fetchone()
        if row:
            return int(row["charge_code_id"])
        cur.execute(
            sql.SQL(
                """
                insert into {charge_codes} (
                    tenant_id, charge_code, charge_name, charge_category,
                    taxable, is_active, metadata, created_channel_code,
                    created_from_ip, created_from_client, updated_channel_code,
                    updated_from_ip, updated_from_client
                )
                values (
                    %s, 'BASE_FREIGHT', '기본 운임', 'BASE', true, true,
                    %s, %s, %s, %s, %s, %s, %s
                )
                returning charge_code_id
                """
            ).format(charge_codes=table_identifier("charge_codes")),
            (
                tenant_id,
                Jsonb({"source": "ktms_order_registration"}),
                source["channel"],
                source["ip"],
                source["client"],
                source["channel"],
                source["ip"],
                source["client"],
            ),
        )
        row = cur.fetchone()
    return int(row["charge_code_id"])


def _order_type(value: str | None) -> str:
    order_type = _clean_text(value, uppercase=True) or "STANDARD"
    return order_type if order_type in {"STANDARD", "RETURN", "TRANSFER", "EXPEDITED", "CONSOLIDATION"} else "STANDARD"


def _order_status(value: str | None) -> str:
    status_code = _clean_text(value, uppercase=True) or "DRAFT"
    allowed = {
        "DRAFT",
        "CONFIRMED",
        "PLANNED",
        "TENDERED",
        "DISPATCHED",
        "IN_TRANSIT",
        "DELIVERED",
        "CLOSED",
        "CANCELLED",
    }
    return status_code if status_code in allowed else "DRAFT"


def _insert_order_line(
    conn: psycopg.Connection,
    tenant_id: int,
    order_id: int,
    line: OrderLinePayload,
    source: dict[str, str | None],
) -> None:
    params = {
        "tenant_id": tenant_id,
        "order_id": order_id,
        "line_no": line.line_no,
        "item_description": _clean_text(line.item_description),
        "quantity": _decimal_or_zero(line.quantity),
        "uom_id": _ensure_uom_id(conn, tenant_id, line.uom_code, source),
        "package_count": line.package_count,
        "gross_weight_kg": _decimal_or_zero(line.gross_weight_kg),
        "net_weight_kg": _decimal_or_none(line.net_weight_kg),
        "volume_cbm": _decimal_or_zero(line.volume_cbm),
        "length_cm": _decimal_or_none(line.length_cm),
        "width_cm": _decimal_or_none(line.width_cm),
        "height_cm": _decimal_or_none(line.height_cm),
        "lot_no": _clean_text(line.lot_no),
        "serial_no": _clean_text(line.serial_no),
        "expiry_date": _clean_text(line.expiry_date),
        "temperature_min_c": _decimal_or_none(line.temperature_min_c),
        "temperature_max_c": _decimal_or_none(line.temperature_max_c),
        "hazmat_class": _clean_text(line.hazmat_class),
        "metadata": Jsonb({"source": "ktms_order_registration", **line.metadata}),
        "channel": source["channel"],
        "ip": source["ip"],
        "client": source["client"],
    }
    query = sql.SQL(
        """
        insert into {transport_order_lines} (
            tenant_id, order_id, line_no, item_description, quantity, uom_id,
            package_count, gross_weight_kg, net_weight_kg, volume_cbm,
            length_cm, width_cm, height_cm, lot_no, serial_no, expiry_date,
            temperature_min_c, temperature_max_c, hazmat_class, metadata,
            created_channel_code, created_from_ip, created_from_client,
            updated_channel_code, updated_from_ip, updated_from_client
        )
        values (
            %(tenant_id)s, %(order_id)s, %(line_no)s, %(item_description)s,
            %(quantity)s, %(uom_id)s, %(package_count)s, %(gross_weight_kg)s,
            %(net_weight_kg)s, %(volume_cbm)s, %(length_cm)s, %(width_cm)s,
            %(height_cm)s, %(lot_no)s, %(serial_no)s, %(expiry_date)s::date,
            %(temperature_min_c)s, %(temperature_max_c)s, %(hazmat_class)s,
            %(metadata)s, %(channel)s, %(ip)s, %(client)s,
            %(channel)s, %(ip)s, %(client)s
        )
        """
    ).format(transport_order_lines=table_identifier("transport_order_lines"))
    with conn.cursor() as cur:
        cur.execute(query, params)


def _insert_order_stop(
    conn: psycopg.Connection,
    tenant_id: int,
    order_id: int,
    payload: TransportOrderPayload,
    source: dict[str, str | None],
    *,
    sequence: int,
    stop_type: str,
) -> None:
    pickup = stop_type == "PICKUP"
    params = {
        "tenant_id": tenant_id,
        "order_id": order_id,
        "stop_sequence": sequence,
        "stop_type": stop_type,
        "appointment_required": payload.appointment_required if pickup else False,
        "requested_start_at": _clean_text(
            payload.requested_pickup_start if pickup else payload.requested_delivery_start,
        ),
        "requested_end_at": _clean_text(
            payload.requested_pickup_end if pickup else payload.requested_delivery_end,
        ),
        "contact_name": _clean_text(payload.pickup_contact_name if pickup else payload.delivery_contact_name),
        "contact_phone": _clean_text(payload.pickup_contact_phone if pickup else payload.delivery_contact_phone),
        "instructions": _clean_text(payload.special_instructions),
        "metadata": _jsonb(
            {
                "source": "ktms_order_registration",
                "stop_name": payload.pickup_name if pickup else payload.delivery_name,
                "address": payload.pickup_address if pickup else payload.delivery_address,
            }
        ),
        "channel": source["channel"],
        "ip": source["ip"],
        "client": source["client"],
    }
    query = sql.SQL(
        """
        insert into {transport_order_stops} (
            tenant_id, order_id, stop_sequence, stop_type, appointment_required,
            requested_start_at, requested_end_at, stop_status, contact_name,
            contact_phone, instructions, metadata, created_channel_code,
            created_from_ip, created_from_client, updated_channel_code,
            updated_from_ip, updated_from_client
        )
        values (
            %(tenant_id)s, %(order_id)s, %(stop_sequence)s, %(stop_type)s,
            %(appointment_required)s, %(requested_start_at)s::timestamptz,
            %(requested_end_at)s::timestamptz, 'PENDING', %(contact_name)s,
            %(contact_phone)s, %(instructions)s, %(metadata)s,
            %(channel)s, %(ip)s, %(client)s, %(channel)s, %(ip)s, %(client)s
        )
        """
    ).format(transport_order_stops=table_identifier("transport_order_stops"))
    with conn.cursor() as cur:
        cur.execute(query, params)


def _insert_order_charge(
    conn: psycopg.Connection,
    context: MasterContext,
    order_id: int,
    customer_id: int,
    charge_amount: Decimal,
    currency_code: str,
    source: dict[str, str | None],
) -> int | None:
    if charge_amount <= 0 or context.company_id is None:
        return None
    charge_code_id = _ensure_charge_code_id(conn, context.tenant_id, source)
    params = {
        "tenant_id": context.tenant_id,
        "company_id": context.company_id,
        "order_id": order_id,
        "charge_code_id": charge_code_id,
        "payer_partner_id": customer_id,
        "quantity": Decimal("1"),
        "unit_rate": charge_amount,
        "charge_amount": charge_amount,
        "currency_code": currency_code[:3],
        "metadata": Jsonb({"source": "ktms_order_registration"}),
        "channel": source["channel"],
        "ip": source["ip"],
        "client": source["client"],
    }
    query = sql.SQL(
        """
        insert into {order_charges} (
            tenant_id, company_id, order_id, charge_code_id, payer_partner_id,
            calculation_basis, quantity, unit_rate, charge_amount, tax_amount,
            currency_code, charge_status, source_type, metadata,
            created_channel_code, created_from_ip, created_from_client,
            updated_channel_code, updated_from_ip, updated_from_client
        )
        values (
            %(tenant_id)s, %(company_id)s, %(order_id)s, %(charge_code_id)s,
            %(payer_partner_id)s, 'MANUAL', %(quantity)s, %(unit_rate)s,
            %(charge_amount)s, 0, %(currency_code)s, 'ESTIMATED', 'MANUAL',
            %(metadata)s, %(channel)s, %(ip)s, %(client)s,
            %(channel)s, %(ip)s, %(client)s
        )
        returning order_charge_id
        """
    ).format(order_charges=table_identifier("order_charges"))
    with conn.cursor() as cur:
        cur.execute(query, params)
        row = cur.fetchone()
    return int(row["order_charge_id"])


@router.post("/transport-orders")
def save_transport_order(payload: TransportOrderPayload, request: Request):
    def save(conn: psycopg.Connection) -> dict[str, Any]:
        context = _master_context(
            conn,
            tenant_id=payload.tenant_id,
            company_id=payload.company_id,
        )
        if context.company_id is None:
            raise RuntimeError("No company context was found for transport order.")

        source = _client_source(request)
        customer_id = _ensure_partner_id(
            conn,
            context,
            payload.customer_name,
            "CUSTOMER",
            source,
            partner_code=payload.customer_code,
        )
        bill_to_id = _ensure_partner_id(
            conn,
            context,
            payload.bill_to_name or payload.customer_name,
            "CUSTOMER",
            source,
        )
        mode_id = _ensure_mode_id(
            conn,
            context.tenant_id,
            payload.transport_mode_code,
            payload.transport_mode_name,
            source,
        )
        service_level_id = _ensure_service_level_id(
            conn,
            context.tenant_id,
            payload.service_level_code,
            payload.service_level_name,
            source,
        )
        currency_code = (_clean_text(payload.currency_code, uppercase=True) or "KRW")[:3]
        lines = payload.lines or [
            OrderLinePayload(
                line_no=1,
                item_description="운송 품목",
                quantity=payload.total_quantity,
                package_count=payload.total_packages,
                gross_weight_kg=payload.total_weight_kg,
                volume_cbm=payload.total_volume_cbm,
            )
        ]

        params = {
            "tenant_id": context.tenant_id,
            "company_id": context.company_id,
            "order_no": _clean_text(payload.order_no, uppercase=True),
            "customer_id": customer_id,
            "bill_to_partner_id": bill_to_id,
            "mode_id": mode_id,
            "service_level_id": service_level_id,
            "order_type": _order_type(payload.order_type),
            "order_status": _order_status(payload.order_status),
            "priority_code": _clean_text(payload.priority_code, uppercase=True) or "NORMAL",
            "requested_pickup_start": _clean_text(payload.requested_pickup_start),
            "requested_pickup_end": _clean_text(payload.requested_pickup_end),
            "requested_delivery_start": _clean_text(payload.requested_delivery_start),
            "requested_delivery_end": _clean_text(payload.requested_delivery_end),
            "total_quantity": _decimal_or_zero(payload.total_quantity),
            "total_packages": payload.total_packages,
            "total_weight_kg": _decimal_or_zero(payload.total_weight_kg),
            "total_volume_cbm": _decimal_or_zero(payload.total_volume_cbm),
            "declared_value_amount": _decimal_or_none(payload.declared_value_amount),
            "currency_code": currency_code,
            "incoterm_code": _clean_text(payload.incoterm_code, uppercase=True),
            "temperature_min_c": _decimal_or_none(payload.temperature_min_c),
            "temperature_max_c": _decimal_or_none(payload.temperature_max_c),
            "hazmat_required": payload.hazmat_required,
            "special_instructions": _clean_text(payload.special_instructions),
            "source_system": _clean_text(payload.source_system, uppercase=True) or "KTMS_WEB",
            "external_order_no": _clean_text(payload.external_order_no),
            "metadata": _metadata(
                payload,
                shipper_name=payload.shipper_name,
                bill_to_name=payload.bill_to_name,
                pickup_name=payload.pickup_name,
                pickup_address=payload.pickup_address,
                delivery_name=payload.delivery_name,
                delivery_address=payload.delivery_address,
                transport_mode_code=payload.transport_mode_code,
                transport_mode_name=payload.transport_mode_name,
                service_level_code=payload.service_level_code,
                service_level_name=payload.service_level_name,
                appointment_required=payload.appointment_required,
                charge_amount=str(_decimal_or_zero(payload.charge_amount)),
            ),
            "channel": source["channel"],
            "ip": source["ip"],
            "client": source["client"],
        }

        order_query = sql.SQL(
            """
            insert into {transport_orders} (
                tenant_id, company_id, order_no, customer_id,
                bill_to_partner_id, mode_id, service_level_id, order_type,
                order_status, priority_code, requested_pickup_start,
                requested_pickup_end, requested_delivery_start,
                requested_delivery_end, total_quantity, total_packages,
                total_weight_kg, total_volume_cbm, declared_value_amount,
                currency_code, incoterm_code, temperature_min_c,
                temperature_max_c, hazmat_required, special_instructions,
                source_system, external_order_no, metadata,
                created_channel_code, created_from_ip, created_from_client,
                updated_channel_code, updated_from_ip, updated_from_client
            )
            values (
                %(tenant_id)s, %(company_id)s, %(order_no)s, %(customer_id)s,
                %(bill_to_partner_id)s, %(mode_id)s, %(service_level_id)s,
                %(order_type)s, %(order_status)s, %(priority_code)s,
                %(requested_pickup_start)s::timestamptz,
                %(requested_pickup_end)s::timestamptz,
                %(requested_delivery_start)s::timestamptz,
                %(requested_delivery_end)s::timestamptz,
                %(total_quantity)s, %(total_packages)s, %(total_weight_kg)s,
                %(total_volume_cbm)s, %(declared_value_amount)s,
                %(currency_code)s, %(incoterm_code)s, %(temperature_min_c)s,
                %(temperature_max_c)s, %(hazmat_required)s,
                %(special_instructions)s, %(source_system)s,
                %(external_order_no)s, %(metadata)s,
                %(channel)s, %(ip)s, %(client)s, %(channel)s, %(ip)s, %(client)s
            )
            on conflict (tenant_id, company_id, order_no)
            where deleted_at is null
            do update set
                customer_id = excluded.customer_id,
                bill_to_partner_id = excluded.bill_to_partner_id,
                mode_id = excluded.mode_id,
                service_level_id = excluded.service_level_id,
                order_type = excluded.order_type,
                order_status = excluded.order_status,
                priority_code = excluded.priority_code,
                requested_pickup_start = excluded.requested_pickup_start,
                requested_pickup_end = excluded.requested_pickup_end,
                requested_delivery_start = excluded.requested_delivery_start,
                requested_delivery_end = excluded.requested_delivery_end,
                total_quantity = excluded.total_quantity,
                total_packages = excluded.total_packages,
                total_weight_kg = excluded.total_weight_kg,
                total_volume_cbm = excluded.total_volume_cbm,
                declared_value_amount = excluded.declared_value_amount,
                currency_code = excluded.currency_code,
                incoterm_code = excluded.incoterm_code,
                temperature_min_c = excluded.temperature_min_c,
                temperature_max_c = excluded.temperature_max_c,
                hazmat_required = excluded.hazmat_required,
                special_instructions = excluded.special_instructions,
                source_system = excluded.source_system,
                external_order_no = excluded.external_order_no,
                metadata = excluded.metadata,
                version_no = {transport_orders}.version_no + 1,
                updated_at = now(),
                updated_channel_code = excluded.updated_channel_code,
                updated_from_ip = excluded.updated_from_ip,
                updated_from_client = excluded.updated_from_client
            returning order_id, order_no
            """
        ).format(transport_orders=table_identifier("transport_orders"))

        with conn.cursor() as cur:
            cur.execute(order_query, params)
            order = cur.fetchone()
            order_id = int(order["order_id"])
            for child_table in ("transport_order_lines", "transport_order_stops", "order_charges"):
                cur.execute(
                    sql.SQL("delete from {table} where order_id = %s").format(
                        table=table_identifier(child_table),
                    ),
                    (order_id,),
                )

        for line in lines:
            _insert_order_line(conn, context.tenant_id, order_id, line, source)

        _insert_order_stop(
            conn,
            context.tenant_id,
            order_id,
            payload,
            source,
            sequence=1,
            stop_type="PICKUP",
        )
        _insert_order_stop(
            conn,
            context.tenant_id,
            order_id,
            payload,
            source,
            sequence=2,
            stop_type="DELIVERY",
        )
        charge_id = _insert_order_charge(
            conn,
            context,
            order_id,
            customer_id,
            _decimal_or_zero(payload.charge_amount),
            currency_code,
            source,
        )

        return {
            "saved": True,
            "table": "transport_orders",
            "id": order_id,
            "code": order["order_no"],
            "line_count": len(lines),
            "charge_id": charge_id,
        }

    return _run_db_save(save)
