from __future__ import annotations

from datetime import datetime, timezone
from decimal import Decimal, InvalidOperation
from typing import Any

import psycopg
from fastapi import APIRouter, HTTPException, Request, status
from pydantic import BaseModel, ConfigDict, Field
from psycopg import sql
from psycopg.types.json import Jsonb

from app.core.database import db_connection, default_master_context, table_identifier


router = APIRouter(prefix="/tracking", tags=["tracking"])


class TrackingPositionPayload(BaseModel):
    model_config = ConfigDict(extra="ignore")

    tenant_id: int | None = None
    company_id: int | None = None
    shipment_id: int | None = None
    vehicle_id: int | None = None
    vehicle_no: str | None = None
    driver_name: str | None = None
    plan_no: str | None = None
    status_label: str | None = None
    eta_label: str | None = None
    progress: str | int | float | Decimal | None = None
    latitude: str | int | float | Decimal
    longitude: str | int | float | Decimal
    speed_kph: str | int | float | Decimal | None = None
    heading_degree: str | int | float | Decimal | None = None
    captured_at: datetime | None = None
    location_text: str | None = None
    notes: str | None = None
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


def _required_decimal(
    value: str | int | float | Decimal,
    field_name: str,
) -> Decimal:
    decimal_value = _decimal_or_none(value)
    if decimal_value is None:
        raise HTTPException(
            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
            detail=f"{field_name} 값이 올바르지 않습니다.",
        )
    return decimal_value


def _client_source(request: Request) -> dict[str, str | None]:
    client = _clean_text(request.headers.get("user-agent"))
    return {
        "channel": "WEB",
        "ip": request.client.host if request.client else None,
        "client": client[:200] if client else None,
    }


def _vehicle_id_for_plate(
    conn: psycopg.Connection,
    tenant_id: int,
    vehicle_id: int | None,
    vehicle_no: str | None,
) -> int | None:
    if vehicle_id:
        return vehicle_id

    normalized = _clean_text(vehicle_no)
    if not normalized:
        return None
    normalized = normalized.replace(" ", "")

    with conn.cursor() as cur:
        cur.execute(
            sql.SQL(
                """
                select vehicle_id
                from {vehicles}
                where tenant_id = %s
                  and deleted_at is null
                  and replace(coalesce(plate_no, vehicle_code), ' ', '') = %s
                order by vehicle_id
                limit 1
                """
            ).format(vehicles=table_identifier("vehicles")),
            (tenant_id, normalized),
        )
        row = cur.fetchone()

    return int(row["vehicle_id"]) if row else None


def _shipment_id_for_plan(
    conn: psycopg.Connection,
    tenant_id: int,
    company_id: int,
    shipment_id: int | None,
    plan_no: str | None,
) -> int | None:
    if shipment_id:
        return shipment_id

    normalized = _clean_text(plan_no)
    if not normalized:
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
            (tenant_id, company_id, normalized, normalized, normalized),
        )
        row = cur.fetchone()

    return int(row["shipment_id"]) if row else None


def _handle_db_error(exc: Exception) -> HTTPException:
    if isinstance(exc, HTTPException):
        return exc
    if isinstance(exc, psycopg.Error):
        return HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="트래킹 저장 중 DB 오류가 발생했습니다.",
        )
    return HTTPException(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        detail="트래킹 저장 중 오류가 발생했습니다.",
    )


@router.post("/positions")
def save_tracking_position(payload: TrackingPositionPayload, request: Request):
    try:
        with db_connection() as conn:
            defaults = default_master_context(conn)
            tenant_id = payload.tenant_id or defaults.tenant_id
            company_id = payload.company_id or defaults.company_id
            captured_at = payload.captured_at or datetime.now(timezone.utc)
            latitude = _required_decimal(payload.latitude, "latitude")
            longitude = _required_decimal(payload.longitude, "longitude")
            speed_kph = _decimal_or_none(payload.speed_kph)
            heading_degree = _decimal_or_none(payload.heading_degree)
            source = _client_source(request)
            shipment_id = _shipment_id_for_plan(
                conn,
                tenant_id,
                company_id,
                payload.shipment_id,
                payload.plan_no,
            )
            vehicle_id = _vehicle_id_for_plate(
                conn,
                tenant_id,
                payload.vehicle_id,
                payload.vehicle_no,
            )
            event_payload = {
                "source": "ktms_execution_tracking",
                "vehicle_no": payload.vehicle_no,
                "driver_name": payload.driver_name,
                "plan_no": payload.plan_no,
                "status_label": payload.status_label,
                "eta_label": payload.eta_label,
                "progress": str(payload.progress) if payload.progress is not None else None,
                "metadata": payload.metadata,
            }
            event_payload = {
                key: value
                for key, value in event_payload.items()
                if value not in (None, "")
            }

            with conn.cursor() as cur:
                cur.execute(
                    sql.SQL(
                        """
                        insert into {gps_positions} (
                            tenant_id, shipment_id, vehicle_id, captured_at,
                            latitude, longitude, speed_kph, heading_degree,
                            ignition_on, source_system, raw_payload,
                            created_channel_code, created_from_ip,
                            created_from_client, updated_channel_code,
                            updated_from_ip, updated_from_client
                        )
                        values (
                            %(tenant_id)s, %(shipment_id)s, %(vehicle_id)s,
                            %(captured_at)s, %(latitude)s, %(longitude)s,
                            %(speed_kph)s, %(heading_degree)s, true,
                            'KTMS_WEB', %(raw_payload)s, %(channel)s,
                            %(ip)s, %(client)s, %(channel)s, %(ip)s, %(client)s
                        )
                        returning gps_position_id
                        """
                    ).format(gps_positions=table_identifier("gps_positions")),
                    {
                        "tenant_id": tenant_id,
                        "shipment_id": shipment_id,
                        "vehicle_id": vehicle_id,
                        "captured_at": captured_at,
                        "latitude": latitude,
                        "longitude": longitude,
                        "speed_kph": speed_kph,
                        "heading_degree": heading_degree,
                        "raw_payload": Jsonb(event_payload),
                        "channel": source["channel"],
                        "ip": source["ip"],
                        "client": source["client"],
                    },
                )
                gps_position_id = cur.fetchone()["gps_position_id"]

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
                            'GPS_POSITION', 'RECORDED', %(captured_at)s,
                            'GPS', 'KTMS_WEB', %(latitude)s, %(longitude)s,
                            %(location_text)s, %(notes)s, %(payload)s,
                            %(channel)s, %(ip)s, %(client)s, %(channel)s,
                            %(ip)s, %(client)s
                        )
                        returning tracking_event_id
                        """
                    ).format(tracking_events=table_identifier("tracking_events")),
                    {
                        "tenant_id": tenant_id,
                        "company_id": company_id,
                        "shipment_id": shipment_id,
                        "captured_at": captured_at,
                        "latitude": latitude,
                        "longitude": longitude,
                        "location_text": _clean_text(payload.location_text),
                        "notes": _clean_text(payload.notes),
                        "payload": Jsonb(
                            {
                                **event_payload,
                                "gps_position_id": gps_position_id,
                                "shipment_id": shipment_id,
                                "vehicle_id": vehicle_id,
                            }
                        ),
                        "channel": source["channel"],
                        "ip": source["ip"],
                        "client": source["client"],
                    },
                )
                tracking_event_id = cur.fetchone()["tracking_event_id"]

            return {
                "saved": True,
                "gps_position_id": gps_position_id,
                "tracking_event_id": tracking_event_id,
                "shipment_id": shipment_id,
                "vehicle_id": vehicle_id,
            }
    except Exception as exc:
        raise _handle_db_error(exc) from exc
