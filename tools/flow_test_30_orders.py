#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.request
from collections import defaultdict
from dataclasses import dataclass
from datetime import date, datetime, timedelta, timezone
from decimal import Decimal
from pathlib import Path
from typing import Any

import psycopg
from psycopg.rows import dict_row
from psycopg.types.json import Jsonb


PROJECT_ROOT = Path(__file__).resolve().parents[1]


def load_env_file() -> None:
    env_file = PROJECT_ROOT / ".env"
    if not env_file.exists():
        return

    for raw_line in env_file.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue

        key, value = line.split("=", 1)
        key = key.strip()
        if not key or key in os.environ:
            continue
        os.environ[key] = value.strip().strip('"').strip("'")


load_env_file()

BASE_URL = os.environ.get("KTMS_API_BASE_URL")
SCHEMA = os.environ.get("KTMS_DB_SCHEMA", "ktms")
CHANNEL = "FLOW_TEST"
CLIENT = "codex-flow-test-30-orders"


@dataclass(frozen=True)
class Context:
    tenant_id: int
    company_id: int
    base_charge_code_id: int
    direct_carrier_id: int
    cj_carrier_id: int
    direct_vehicle_id: int
    direct_driver_id: int


def env_required(name: str) -> str:
    value = os.environ.get(name)
    if not value:
        raise RuntimeError(f"{name} is required")
    return value


if not BASE_URL:
    raise RuntimeError("KTMS_API_BASE_URL is required")


def connect() -> psycopg.Connection:
    return psycopg.connect(
        host=env_required("KTMS_DB_HOST"),
        port=int(os.environ.get("KTMS_DB_PORT", "5432")),
        dbname=env_required("KTMS_DB_NAME"),
        user=env_required("KTMS_DB_USER"),
        password=env_required("KTMS_DB_PASSWORD"),
        connect_timeout=20,
        row_factory=dict_row,
    )


def q(table: str) -> str:
    return f"{SCHEMA}.{table}"


def post_json(path: str, payload: dict[str, Any]) -> dict[str, Any]:
    data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    req = urllib.request.Request(
        BASE_URL.rstrip("/") + path,
        data=data,
        method="POST",
        headers={"Content-Type": "application/json; charset=utf-8"},
    )
    try:
        with urllib.request.urlopen(req, timeout=30) as response:
            body = response.read().decode("utf-8")
            return json.loads(body) if body else {}
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"POST {path} failed: {exc.code} {body}") from exc


def fetch_one(cur: psycopg.Cursor, query: str, params: tuple[Any, ...] = ()) -> dict[str, Any]:
    cur.execute(query, params)
    row = cur.fetchone()
    if not row:
        raise RuntimeError("Required row was not found")
    return row


def fetch_optional(cur: psycopg.Cursor, query: str, params: tuple[Any, ...] = ()) -> dict[str, Any] | None:
    cur.execute(query, params)
    return cur.fetchone()


def ensure_context(conn: psycopg.Connection) -> Context:
    with conn.cursor() as cur:
        company = fetch_one(
            cur,
            f"""
            select t.tenant_id, c.company_id
            from {q("tenants")} t
            join {q("companies")} c on c.tenant_id = t.tenant_id
            where t.deleted_at is null
              and c.deleted_at is null
              and t.is_active = true
              and c.is_active = true
            order by t.tenant_id, c.company_id
            limit 1
            """,
        )
        tenant_id = int(company["tenant_id"])
        company_id = int(company["company_id"])

        base_charge_code_id = ensure_charge_code(cur, tenant_id)
        direct_carrier_id = ensure_partner(
            cur,
            tenant_id,
            company_id,
            "CARR_KTMS_DIRECT",
            "KTMS 직영차량",
            "CARRIER",
            {"source": "codex_flow_test", "own_fleet": True},
        )
        cj_carrier = fetch_optional(
            cur,
            f"""
            select partner_id
            from {q("business_partners")}
            where tenant_id = %s
              and company_id = %s
              and deleted_at is null
              and partner_code = 'CARR_CJ'
            order by partner_id
            limit 1
            """,
            (tenant_id, company_id),
        )
        if cj_carrier is None:
            cj_carrier_id = ensure_partner(
                cur,
                tenant_id,
                company_id,
                "CARR_CJ",
                "CJ대한통운",
                "CARRIER",
                {"source": "codex_flow_test", "carrier_portal_enabled": True},
            )
        else:
            cj_carrier_id = int(cj_carrier["partner_id"])

        vehicle = fetch_one(
            cur,
            f"""
            select vehicle_id
            from {q("vehicles")}
            where tenant_id = %s
              and deleted_at is null
              and replace(plate_no, ' ', '') = '서울82바1724'
            order by vehicle_id
            limit 1
            """,
            (tenant_id,),
        )
        driver = fetch_one(
            cur,
            f"""
            select driver_id
            from {q("drivers")}
            where tenant_id = %s
              and deleted_at is null
              and driver_code = 'DRV-WB1724'
            order by driver_id
            limit 1
            """,
            (tenant_id,),
        )

    conn.commit()
    return Context(
        tenant_id=tenant_id,
        company_id=company_id,
        base_charge_code_id=base_charge_code_id,
        direct_carrier_id=direct_carrier_id,
        cj_carrier_id=cj_carrier_id,
        direct_vehicle_id=int(vehicle["vehicle_id"]),
        direct_driver_id=int(driver["driver_id"]),
    )


def ensure_charge_code(cur: psycopg.Cursor, tenant_id: int) -> int:
    row = fetch_optional(
        cur,
        f"""
        select charge_code_id
        from {q("charge_codes")}
        where tenant_id = %s
          and deleted_at is null
          and charge_code = 'BASE_FREIGHT'
        order by charge_code_id
        limit 1
        """,
        (tenant_id,),
    )
    if row:
        return int(row["charge_code_id"])

    cur.execute(
        f"""
        insert into {q("charge_codes")} (
            tenant_id, charge_code, charge_name, charge_category, taxable,
            is_active, metadata, created_channel_code, created_from_client,
            updated_channel_code, updated_from_client
        )
        values (%s, 'BASE_FREIGHT', '기본 운임', 'BASE', true, true,
                %s, %s, %s, %s, %s)
        returning charge_code_id
        """,
        (
            tenant_id,
            Jsonb({"source": "codex_flow_test"}),
            CHANNEL,
            CLIENT,
            CHANNEL,
            CLIENT,
        ),
    )
    return int(cur.fetchone()["charge_code_id"])


def ensure_partner(
    cur: psycopg.Cursor,
    tenant_id: int,
    company_id: int,
    partner_code: str,
    partner_name: str,
    partner_type: str,
    metadata: dict[str, Any],
) -> int:
    cur.execute(
        f"""
        insert into {q("business_partners")} (
            tenant_id, company_id, partner_code, partner_name,
            partner_short_name, partner_type, status, is_active, metadata,
            created_channel_code, created_from_client,
            updated_channel_code, updated_from_client
        )
        values (%s, %s, %s, %s, %s, %s, 'ACTIVE', true, %s, %s, %s, %s, %s)
        on conflict (tenant_id, company_id, partner_code)
        where deleted_at is null
        do update set
            partner_name = excluded.partner_name,
            partner_short_name = excluded.partner_short_name,
            partner_type = excluded.partner_type,
            status = 'ACTIVE',
            is_active = true,
            metadata = {q("business_partners")}.metadata || excluded.metadata,
            updated_at = now(),
            updated_channel_code = excluded.updated_channel_code,
            updated_from_client = excluded.updated_from_client
        returning partner_id
        """,
        (
            tenant_id,
            company_id,
            partner_code,
            partner_name,
            partner_name,
            partner_type,
            Jsonb(metadata),
            CHANNEL,
            CLIENT,
            CHANNEL,
            CLIENT,
        ),
    )
    return int(cur.fetchone()["partner_id"])


def make_order_payload(run_id: str, index: int) -> dict[str, Any]:
    customers = [
        ("F30-CUS-01", "삼성전자"),
        ("F30-CUS-02", "프레시온"),
        ("F30-CUS-03", "K패션"),
        ("F30-CUS-04", "신세계푸드"),
        ("F30-CUS-05", "이마트"),
    ]
    routes = [
        ("수원 CDC", "경기 수원시 영통구", "부산 RDC", "부산 강서구"),
        ("김포 콜드체인", "경기 김포시 고촌읍", "서울 동부센터", "서울 송파구"),
        ("인천 반품센터", "인천 서구", "이천 물류센터", "경기 이천시"),
        ("평택 콜드센터", "경기 평택시", "강남 점포권", "서울 강남구"),
        ("용인 냉동창고", "경기 용인시 처인구", "부산 냉동센터", "부산 사상구"),
    ]
    customer_code, customer_name = customers[(index - 1) % len(customers)]
    pickup_name, pickup_addr, delivery_name, delivery_addr = routes[(index - 1) % len(routes)]
    base_time = datetime(2026, 6, 16, 8, 0, tzinfo=timezone.utc) + timedelta(minutes=index * 11)
    weight = Decimal(840 + index * 37)
    volume = Decimal("4.2") + Decimal(index % 7) * Decimal("0.8")
    packages = 8 + (index % 12)
    charge_amount = 520_000 + (index % 9) * 85_000 + index * 3_000
    order_no = f"FT30-{run_id}-{index:03d}"
    return {
        "order_no": order_no,
        "external_order_no": f"EXT-{order_no}",
        "customer_code": customer_code,
        "customer_name": customer_name,
        "shipper_name": pickup_name,
        "bill_to_name": customer_name,
        "pickup_name": pickup_name,
        "pickup_address": pickup_addr,
        "pickup_contact_name": "출하담당",
        "pickup_contact_phone": f"010-7100-{index:04d}",
        "requested_pickup_start": base_time.isoformat(),
        "requested_pickup_end": (base_time + timedelta(hours=1)).isoformat(),
        "delivery_name": delivery_name,
        "delivery_address": delivery_addr,
        "delivery_contact_name": "입고담당",
        "delivery_contact_phone": f"010-7200-{index:04d}",
        "requested_delivery_start": (base_time + timedelta(hours=6)).isoformat(),
        "requested_delivery_end": (base_time + timedelta(hours=8)).isoformat(),
        "order_type": "STANDARD",
        "order_status": "CONFIRMED",
        "priority_code": "HIGH" if index % 10 == 0 else "NORMAL",
        "transport_mode_code": "TRUCK",
        "transport_mode_name": "화물차",
        "service_level_code": "STD",
        "service_level_name": "일반",
        "total_quantity": packages,
        "total_packages": packages,
        "total_weight_kg": str(weight),
        "total_volume_cbm": str(volume),
        "declared_value_amount": charge_amount * 4,
        "charge_amount": charge_amount,
        "currency_code": "KRW",
        "temperature_min_c": -18 if index % 5 == 0 else None,
        "temperature_max_c": -12 if index % 5 == 0 else None,
        "appointment_required": index % 3 == 0,
        "special_instructions": "30건 전체 흐름 테스트",
        "source_system": "KTMS_FLOW_TEST",
        "lines": [
            {
                "line_no": 1,
                "item_description": "전체 흐름 테스트 화물",
                "quantity": packages,
                "uom_code": "BOX",
                "package_count": packages,
                "gross_weight_kg": str(weight),
                "volume_cbm": str(volume),
                "temperature_min_c": -18 if index % 5 == 0 else None,
                "temperature_max_c": -12 if index % 5 == 0 else None,
                "metadata": {"flow_test_run_id": run_id},
            }
        ],
        "metadata": {
            "flow_test_run_id": run_id,
            "flow_test_index": index,
            "flow_test": "30_order_settlement",
        },
    }


def create_orders(run_id: str, count: int) -> list[dict[str, Any]]:
    results: list[dict[str, Any]] = []
    for index in range(1, count + 1):
        result = post_json("/api/orders/transport-orders", make_order_payload(run_id, index))
        if not result.get("saved"):
            raise RuntimeError(f"Order API did not save index={index}: {result}")
        results.append(result)
    return results


def get_orders(conn: psycopg.Connection, run_id: str) -> list[dict[str, Any]]:
    with conn.cursor() as cur:
        cur.execute(
            f"""
            select
              o.order_id, o.order_no, o.customer_id, o.bill_to_partner_id,
              o.mode_id, o.service_level_id, o.total_packages, o.total_weight_kg,
              o.total_volume_cbm, o.requested_pickup_start, o.requested_delivery_end,
              o.metadata, oc.order_charge_id, oc.charge_amount
            from {q("transport_orders")} o
            left join {q("order_charges")} oc
              on oc.order_id = o.order_id
             and oc.deleted_at is null
            where o.deleted_at is null
              and o.metadata->>'flow_test_run_id' = %s
            order by o.order_no
            """,
            (run_id,),
        )
        rows = cur.fetchall()
    return list(rows)


def plan_shipments(conn: psycopg.Connection, context: Context, run_id: str) -> dict[str, Any]:
    orders = get_orders(conn, run_id)
    if len(orders) != 30:
        raise RuntimeError(f"Expected 30 orders, got {len(orders)}")

    planned: list[dict[str, Any]] = []
    with conn.cursor() as cur:
        for zero_index, order in enumerate(orders):
            index = zero_index + 1
            is_carrier = index % 2 == 0
            shipment_no = f"LP-F30-{run_id}-{index:03d}"
            pickup_at = order["requested_pickup_start"] or datetime.now(timezone.utc)
            delivery_at = order["requested_delivery_end"] or (pickup_at + timedelta(hours=8))
            revenue = Decimal(order["charge_amount"] or 0)
            cost = (revenue * (Decimal("0.72") if is_carrier else Decimal("0.58"))).quantize(Decimal("1"))
            carrier_id = context.cj_carrier_id if is_carrier else context.direct_carrier_id
            vehicle_id = None if is_carrier else context.direct_vehicle_id
            driver_id = None if is_carrier else context.direct_driver_id
            shipment_status = "TENDERED" if is_carrier else "DISPATCHED"
            tender_status = "TENDERED" if is_carrier else "NOT_TENDERED"

            cur.execute(
                f"""
                insert into {q("shipments")} (
                    tenant_id, company_id, shipment_no, carrier_id, mode_id,
                    service_level_id, vehicle_id, driver_id, shipment_status,
                    tender_status, planned_pickup_at, planned_delivery_at,
                    total_orders, total_stops, total_weight_kg, total_volume_cbm,
                    distance_km, currency_code, estimated_cost_amount,
                    estimated_revenue_amount, special_instructions, metadata,
                    created_channel_code, created_from_client,
                    updated_channel_code, updated_from_client
                )
                values (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s,
                    1, 2, %s, %s, %s, 'KRW', %s, %s, %s, %s,
                    %s, %s, %s, %s
                )
                on conflict (tenant_id, company_id, shipment_no)
                where deleted_at is null
                do update set
                    carrier_id = excluded.carrier_id,
                    mode_id = excluded.mode_id,
                    service_level_id = excluded.service_level_id,
                    vehicle_id = excluded.vehicle_id,
                    driver_id = excluded.driver_id,
                    shipment_status = excluded.shipment_status,
                    tender_status = excluded.tender_status,
                    planned_pickup_at = excluded.planned_pickup_at,
                    planned_delivery_at = excluded.planned_delivery_at,
                    total_weight_kg = excluded.total_weight_kg,
                    total_volume_cbm = excluded.total_volume_cbm,
                    distance_km = excluded.distance_km,
                    estimated_cost_amount = excluded.estimated_cost_amount,
                    estimated_revenue_amount = excluded.estimated_revenue_amount,
                    metadata = excluded.metadata,
                    version_no = {q("shipments")}.version_no + 1,
                    updated_at = now(),
                    updated_channel_code = excluded.updated_channel_code,
                    updated_from_client = excluded.updated_from_client
                returning shipment_id
                """,
                (
                    context.tenant_id,
                    context.company_id,
                    shipment_no,
                    carrier_id,
                    order["mode_id"],
                    order["service_level_id"],
                    vehicle_id,
                    driver_id,
                    shipment_status,
                    tender_status,
                    pickup_at,
                    delivery_at,
                    order["total_weight_kg"],
                    order["total_volume_cbm"],
                    Decimal(58 + (index % 8) * 31),
                    cost,
                    revenue,
                    "30건 전체 흐름 테스트",
                    Jsonb(
                        {
                            "source": "codex_flow_test",
                            "flow_test_run_id": run_id,
                            "flow_test_index": index,
                            "plan_no": shipment_no,
                            "assignment_type": "CARRIER" if is_carrier else "DIRECT",
                        }
                    ),
                    CHANNEL,
                    CLIENT,
                    CHANNEL,
                    CLIENT,
                ),
            )
            shipment_id = int(cur.fetchone()["shipment_id"])
            cur.execute(
                f"""
                insert into {q("shipment_orders")} (
                    shipment_id, order_id, allocated_weight_kg,
                    allocated_volume_cbm, created_channel_code, created_from_client,
                    updated_channel_code, updated_from_client
                )
                values (%s, %s, %s, %s, %s, %s, %s, %s)
                on conflict (shipment_id, order_id)
                do update set
                    allocated_weight_kg = excluded.allocated_weight_kg,
                    allocated_volume_cbm = excluded.allocated_volume_cbm,
                    updated_at = now(),
                    updated_channel_code = excluded.updated_channel_code,
                    updated_from_client = excluded.updated_from_client
                """,
                (
                    shipment_id,
                    order["order_id"],
                    order["total_weight_kg"],
                    order["total_volume_cbm"],
                    CHANNEL,
                    CLIENT,
                    CHANNEL,
                    CLIENT,
                ),
            )
            for stop_sequence, stop_type in ((1, "PICKUP"), (2, "DELIVERY")):
                cur.execute(
                    f"""
                    insert into {q("shipment_stops")} (
                        tenant_id, shipment_id, stop_sequence, stop_type,
                        planned_arrival_at, planned_departure_at, stop_status,
                        contact_name, contact_phone, instructions, metadata,
                        created_channel_code, created_from_client,
                        updated_channel_code, updated_from_client
                    )
                    values (%s, %s, %s, %s, %s, %s, 'SCHEDULED', %s, %s, %s, %s,
                            %s, %s, %s, %s)
                    on conflict (shipment_id, stop_sequence)
                    where deleted_at is null
                    do update set
                        stop_type = excluded.stop_type,
                        planned_arrival_at = excluded.planned_arrival_at,
                        planned_departure_at = excluded.planned_departure_at,
                        stop_status = excluded.stop_status,
                        metadata = excluded.metadata,
                        updated_at = now(),
                        updated_channel_code = excluded.updated_channel_code,
                        updated_from_client = excluded.updated_from_client
                    returning shipment_stop_id
                    """,
                    (
                        context.tenant_id,
                        shipment_id,
                        stop_sequence,
                        stop_type,
                        pickup_at if stop_type == "PICKUP" else delivery_at,
                        pickup_at + timedelta(minutes=30)
                        if stop_type == "PICKUP"
                        else delivery_at + timedelta(minutes=30),
                        "담당자",
                        "010-7000-0000",
                        "30건 전체 흐름 테스트",
                        Jsonb({"flow_test_run_id": run_id, "stop_name": stop_type}),
                        CHANNEL,
                        CLIENT,
                        CHANNEL,
                        CLIENT,
                    ),
                )

            if not is_carrier:
                cur.execute(
                    f"""
                    insert into {q("dispatches")} (
                        tenant_id, company_id, shipment_id, driver_id, vehicle_id,
                        dispatch_status, dispatched_at, accepted_at, instructions,
                        metadata, created_channel_code, created_from_client,
                        updated_channel_code, updated_from_client
                    )
                    values (%s, %s, %s, %s, %s, 'ACCEPTED', now(), now(), %s, %s,
                            %s, %s, %s, %s)
                    returning dispatch_id
                    """,
                    (
                        context.tenant_id,
                        context.company_id,
                        shipment_id,
                        context.direct_driver_id,
                        context.direct_vehicle_id,
                        "직접배차 전체 흐름 테스트",
                        Jsonb({"flow_test_run_id": run_id, "plan_no": shipment_no}),
                        CHANNEL,
                        CLIENT,
                        CHANNEL,
                        CLIENT,
                    ),
                )
            cur.execute(
                f"""
                update {q("transport_orders")}
                set order_status = 'PLANNED',
                    planned_pickup_at = %s,
                    planned_delivery_at = %s,
                    metadata = metadata || %s,
                    version_no = version_no + 1,
                    updated_at = now(),
                    updated_channel_code = %s,
                    updated_from_client = %s
                where order_id = %s
                """,
                (
                    pickup_at,
                    delivery_at,
                    Jsonb({"shipment_no": shipment_no}),
                    CHANNEL,
                    CLIENT,
                    order["order_id"],
                ),
            )
            planned.append(
                {
                    "index": index,
                    "order_id": int(order["order_id"]),
                    "order_no": order["order_no"],
                    "order_charge_id": int(order["order_charge_id"]),
                    "customer_id": int(order["customer_id"]),
                    "bill_to_partner_id": int(order["bill_to_partner_id"] or order["customer_id"]),
                    "shipment_id": shipment_id,
                    "shipment_no": shipment_no,
                    "carrier_id": carrier_id,
                    "is_carrier": is_carrier,
                    "revenue": revenue,
                    "cost": cost,
                    "pickup_at": pickup_at,
                    "delivery_at": delivery_at,
                }
            )
    conn.commit()
    return {"orders": planned}


def confirm_carrier_dispatches(run_id: str, planned: list[dict[str, Any]]) -> None:
    for item in planned:
        if not item["is_carrier"]:
            continue
        payload = {
            "carrier_name": "CJ대한통운",
            "manager_name": "박지훈",
            "manager_email": "carrier@cjlogistics.example",
            "plan_no": item["shipment_no"],
            "tender_no": item["shipment_no"].replace("LP-", "CT-"),
            "vehicle_code": "CJC-4402",
            "vehicle_no": "경기91사4402",
            "vehicle_type": "11톤 윙바디",
            "fuel_type": "DIESEL",
            "max_weight_kg": 11000,
            "max_volume_cbm": 48,
            "temperature_controlled": False,
            "driver_code": "CJD-001",
            "driver_name": "박민준",
            "driver_phone": "010-4402-1911",
            "driver_email": "minjun.park@cjlogistics.example",
            "license_type": "LARGE",
            "license_expiry_date": "2027-05-31",
            "offered_amount": int(item["cost"]),
            "currency_code": "KRW",
            "instructions": "30건 전체 흐름 테스트 운송사 배차확정",
            "latitude": 37.2411,
            "longitude": 127.1776,
            "location_text": "테스트 운송사 배차 위치",
            "metadata": {
                "flow_test_run_id": run_id,
                "flow_test_plan_no": item["shipment_no"],
                "flow_test": "30_order_settlement",
            },
        }
        result = post_json("/api/carrier/dispatch-confirmations", payload)
        if not result.get("saved") or int(result["shipment_id"]) != item["shipment_id"]:
            raise RuntimeError(f"Carrier dispatch mismatch for {item['shipment_no']}: {result}")


def send_tracking_positions(planned: list[dict[str, Any]]) -> None:
    for item in planned:
        vehicle_no = "경기91사4402" if item["is_carrier"] else "서울 82바 1724"
        driver_name = "박민준" if item["is_carrier"] else "김도윤"
        result = post_json(
            "/api/tracking/positions",
            {
                "plan_no": item["shipment_no"],
                "vehicle_no": vehicle_no,
                "driver_name": driver_name,
                "status_label": "배송완료 검증",
                "eta_label": "도착",
                "progress": "100%",
                "latitude": 36.2 + (item["index"] % 8) * 0.08,
                "longitude": 127.0 + (item["index"] % 7) * 0.11,
                "speed_kph": 0,
                "heading_degree": 0,
                "location_text": "전체 흐름 테스트 도착지",
                "notes": "30건 전체 흐름 테스트 GPS",
                "metadata": {"flow_test_run_id": item["shipment_no"], "flow_test": "30_order_settlement"},
            },
        )
        if not result.get("saved") or int(result["shipment_id"]) != item["shipment_id"]:
            raise RuntimeError(f"Tracking mismatch for {item['shipment_no']}: {result}")


def complete_and_settle(conn: psycopg.Connection, context: Context, run_id: str, planned: list[dict[str, Any]]) -> dict[str, Any]:
    today = date(2026, 6, 16)
    customer_groups: dict[int, list[dict[str, Any]]] = defaultdict(list)
    carrier_groups: dict[int, list[dict[str, Any]]] = defaultdict(list)

    with conn.cursor() as cur:
        for item in planned:
            actual_pickup = item["pickup_at"] + timedelta(minutes=7)
            actual_delivery = item["delivery_at"] - timedelta(minutes=11)
            customer_groups[item["customer_id"]].append(item)
            carrier_groups[item["carrier_id"]].append(item)

            cur.execute(
                f"""
                update {q("shipment_stops")}
                set stop_status = 'COMPLETED',
                    actual_arrival_at = case when stop_type = 'PICKUP' then %s else %s end,
                    actual_departure_at = case when stop_type = 'PICKUP' then %s else %s end,
                    updated_at = now(),
                    updated_channel_code = %s,
                    updated_from_client = %s
                where shipment_id = %s
                  and deleted_at is null
                """,
                (
                    actual_pickup,
                    actual_delivery,
                    actual_pickup + timedelta(minutes=20),
                    actual_delivery + timedelta(minutes=25),
                    CHANNEL,
                    CLIENT,
                    item["shipment_id"],
                ),
            )
            cur.execute(
                f"""
                update {q("dispatches")}
                set dispatch_status = 'COMPLETED',
                    started_at = coalesce(started_at, %s),
                    completed_at = %s,
                    updated_at = now(),
                    updated_channel_code = %s,
                    updated_from_client = %s
                where shipment_id = %s
                  and deleted_at is null
                  and dispatch_status <> 'CANCELLED'
                """,
                (actual_pickup, actual_delivery, CHANNEL, CLIENT, item["shipment_id"]),
            )
            cur.execute(
                f"""
                update {q("shipments")}
                set shipment_status = 'DELIVERED',
                    actual_pickup_at = %s,
                    actual_delivery_at = %s,
                    version_no = version_no + 1,
                    updated_at = now(),
                    updated_channel_code = %s,
                    updated_from_client = %s
                where shipment_id = %s
                """,
                (actual_pickup, actual_delivery, CHANNEL, CLIENT, item["shipment_id"]),
            )
            cur.execute(
                f"""
                update {q("transport_orders")}
                set order_status = 'DELIVERED',
                    version_no = version_no + 1,
                    updated_at = now(),
                    updated_channel_code = %s,
                    updated_from_client = %s
                where order_id = %s
                """,
                (CHANNEL, CLIENT, item["order_id"]),
            )
            for event_type, event_time in (
                ("PICKUP_COMPLETED", actual_pickup),
                ("DELIVERY_COMPLETED", actual_delivery),
            ):
                cur.execute(
                    f"""
                    insert into {q("tracking_events")} (
                        tenant_id, company_id, order_id, shipment_id,
                        event_type, event_status, event_time, source_type,
                        source_system, location_text, notes, payload,
                        created_channel_code, created_from_client,
                        updated_channel_code, updated_from_client
                    )
                    values (%s, %s, %s, %s, %s, 'RECORDED', %s, 'API',
                            'KTMS_FLOW_TEST', %s, %s, %s, %s, %s, %s, %s)
                    """,
                    (
                        context.tenant_id,
                        context.company_id,
                        item["order_id"],
                        item["shipment_id"],
                        event_type,
                        event_time,
                        "전체 흐름 테스트",
                        event_type,
                        Jsonb({"flow_test_run_id": run_id, "shipment_no": item["shipment_no"]}),
                        CHANNEL,
                        CLIENT,
                        CHANNEL,
                        CLIENT,
                    ),
                )
            cur.execute(
                f"""
                insert into {q("proof_of_deliveries")} (
                    tenant_id, company_id, shipment_id, order_id, pod_no,
                    delivered_at, received_by, receiver_phone, delivery_status,
                    remarks, metadata, created_channel_code, created_from_client,
                    updated_channel_code, updated_from_client
                )
                values (%s, %s, %s, %s, %s, %s, %s, %s, 'DELIVERED', %s, %s,
                        %s, %s, %s, %s)
                on conflict (tenant_id, company_id, pod_no)
                where deleted_at is null
                do update set
                    delivered_at = excluded.delivered_at,
                    delivery_status = excluded.delivery_status,
                    metadata = excluded.metadata,
                    version_no = {q("proof_of_deliveries")}.version_no + 1,
                    updated_at = now(),
                    updated_channel_code = excluded.updated_channel_code,
                    updated_from_client = excluded.updated_from_client
                returning pod_id
                """,
                (
                    context.tenant_id,
                    context.company_id,
                    item["shipment_id"],
                    item["order_id"],
                    f"POD-F30-{run_id}-{item['index']:03d}",
                    actual_delivery,
                    "입고담당",
                    "010-7200-0000",
                    "30건 전체 흐름 테스트 POD",
                    Jsonb({"flow_test_run_id": run_id, "shipment_no": item["shipment_no"]}),
                    CHANNEL,
                    CLIENT,
                    CHANNEL,
                    CLIENT,
                ),
            )
            cur.execute(
                f"""
                insert into {q("shipment_charges")} (
                    tenant_id, company_id, shipment_id, charge_code_id,
                    payer_partner_id, payee_partner_id, calculation_basis,
                    quantity, unit_rate, charge_amount, tax_amount,
                    currency_code, charge_status, source_type, metadata,
                    created_channel_code, created_from_client,
                    updated_channel_code, updated_from_client
                )
                values (%s, %s, %s, %s, %s, %s, 'MANUAL', 1, %s, %s, 0,
                        'KRW', 'APPROVED', 'MANUAL', %s, %s, %s, %s, %s)
                returning shipment_charge_id
                """,
                (
                    context.tenant_id,
                    context.company_id,
                    item["shipment_id"],
                    context.base_charge_code_id,
                    item["customer_id"],
                    item["carrier_id"],
                    item["cost"],
                    item["cost"],
                    Jsonb({"flow_test_run_id": run_id, "shipment_no": item["shipment_no"], "cost": True}),
                    CHANNEL,
                    CLIENT,
                    CHANNEL,
                    CLIENT,
                ),
            )
            item["shipment_charge_id"] = int(cur.fetchone()["shipment_charge_id"])

        invoice_ids: list[int] = []
        for customer_index, (customer_id, items) in enumerate(sorted(customer_groups.items()), start=1):
            subtotal = sum((item["revenue"] for item in items), Decimal("0"))
            tax = (subtotal * Decimal("0.1")).quantize(Decimal("1"))
            total = subtotal + tax
            invoice_no = f"AR-F30-{run_id}-{customer_index:02d}"
            cur.execute(
                f"""
                insert into {q("customer_invoices")} (
                    tenant_id, company_id, invoice_no, customer_id, bill_to_partner_id,
                    invoice_status, issue_date, due_date, currency_code,
                    subtotal_amount, tax_amount, total_amount, paid_amount,
                    approved_at, metadata, created_channel_code, created_from_client,
                    updated_channel_code, updated_from_client
                )
                values (%s, %s, %s, %s, %s, 'ISSUED', %s, %s, 'KRW',
                        %s, %s, %s, 0, now(), %s, %s, %s, %s, %s)
                on conflict (tenant_id, company_id, invoice_no)
                where deleted_at is null
                do update set
                    invoice_status = excluded.invoice_status,
                    subtotal_amount = excluded.subtotal_amount,
                    tax_amount = excluded.tax_amount,
                    total_amount = excluded.total_amount,
                    metadata = excluded.metadata,
                    version_no = {q("customer_invoices")}.version_no + 1,
                    updated_at = now(),
                    updated_channel_code = excluded.updated_channel_code,
                    updated_from_client = excluded.updated_from_client
                returning invoice_id
                """,
                (
                    context.tenant_id,
                    context.company_id,
                    invoice_no,
                    customer_id,
                    items[0]["bill_to_partner_id"],
                    today,
                    today + timedelta(days=30),
                    subtotal,
                    tax,
                    total,
                    Jsonb({"flow_test_run_id": run_id, "order_count": len(items)}),
                    CHANNEL,
                    CLIENT,
                    CHANNEL,
                    CLIENT,
                ),
            )
            invoice_id = int(cur.fetchone()["invoice_id"])
            invoice_ids.append(invoice_id)
            cur.execute(
                f"delete from {q('customer_invoice_lines')} where invoice_id = %s and deleted_at is null",
                (invoice_id,),
            )
            for line_no, item in enumerate(items, start=1):
                line_tax = (item["revenue"] * Decimal("0.1")).quantize(Decimal("1"))
                cur.execute(
                    f"""
                    insert into {q("customer_invoice_lines")} (
                        tenant_id, invoice_id, order_id, shipment_id, order_charge_id,
                        line_no, charge_code_id, description, quantity, unit_rate,
                        line_amount, tax_amount, created_channel_code,
                        created_from_client, updated_channel_code, updated_from_client
                    )
                    values (%s, %s, %s, %s, %s, %s, %s, %s, 1, %s, %s, %s,
                            %s, %s, %s, %s)
                    """,
                    (
                        context.tenant_id,
                        invoice_id,
                        item["order_id"],
                        item["shipment_id"],
                        item["order_charge_id"],
                        line_no,
                        context.base_charge_code_id,
                        f"{item['shipment_no']} 매출 운임",
                        item["revenue"],
                        item["revenue"],
                        line_tax,
                        CHANNEL,
                        CLIENT,
                        CHANNEL,
                        CLIENT,
                    ),
                )
                cur.execute(
                    f"""
                    update {q("order_charges")}
                    set charge_status = 'INVOICED',
                        version_no = version_no + 1,
                        updated_at = now(),
                        updated_channel_code = %s,
                        updated_from_client = %s
                    where order_charge_id = %s
                    """,
                    (CHANNEL, CLIENT, item["order_charge_id"]),
                )

        settlement_ids: list[int] = []
        batch_ids: list[int] = []
        for carrier_index, (carrier_id, items) in enumerate(sorted(carrier_groups.items()), start=1):
            subtotal = sum((item["cost"] for item in items), Decimal("0"))
            tax = (subtotal * Decimal("0.1")).quantize(Decimal("1"))
            total = subtotal + tax
            cur.execute(
                f"""
                insert into {q("settlement_batches")} (
                    tenant_id, company_id, batch_no, carrier_id, period_start,
                    period_end, settlement_status, currency_code, total_amount,
                    approved_at, metadata, created_channel_code, created_from_client,
                    updated_channel_code, updated_from_client
                )
                values (%s, %s, %s, %s, %s, %s, 'APPROVED', 'KRW', %s,
                        now(), %s, %s, %s, %s, %s)
                on conflict (tenant_id, company_id, batch_no)
                where deleted_at is null
                do update set
                    settlement_status = excluded.settlement_status,
                    total_amount = excluded.total_amount,
                    metadata = excluded.metadata,
                    version_no = {q("settlement_batches")}.version_no + 1,
                    updated_at = now(),
                    updated_channel_code = excluded.updated_channel_code,
                    updated_from_client = excluded.updated_from_client
                returning settlement_batch_id
                """,
                (
                    context.tenant_id,
                    context.company_id,
                    f"BAT-F30-{run_id}-{carrier_index:02d}",
                    carrier_id,
                    today,
                    today,
                    total,
                    Jsonb({"flow_test_run_id": run_id, "shipment_count": len(items)}),
                    CHANNEL,
                    CLIENT,
                    CHANNEL,
                    CLIENT,
                ),
            )
            batch_id = int(cur.fetchone()["settlement_batch_id"])
            batch_ids.append(batch_id)
            settlement_no = f"AP-F30-{run_id}-{carrier_index:02d}"
            cur.execute(
                f"""
                insert into {q("carrier_settlements")} (
                    tenant_id, company_id, settlement_batch_id, settlement_no,
                    carrier_id, settlement_status, currency_code, subtotal_amount,
                    tax_amount, total_amount, due_date, metadata,
                    created_channel_code, created_from_client,
                    updated_channel_code, updated_from_client
                )
                values (%s, %s, %s, %s, %s, 'APPROVED', 'KRW', %s, %s, %s,
                        %s, %s, %s, %s, %s, %s)
                on conflict (tenant_id, company_id, settlement_no)
                where deleted_at is null
                do update set
                    settlement_status = excluded.settlement_status,
                    subtotal_amount = excluded.subtotal_amount,
                    tax_amount = excluded.tax_amount,
                    total_amount = excluded.total_amount,
                    metadata = excluded.metadata,
                    version_no = {q("carrier_settlements")}.version_no + 1,
                    updated_at = now(),
                    updated_channel_code = excluded.updated_channel_code,
                    updated_from_client = excluded.updated_from_client
                returning settlement_id
                """,
                (
                    context.tenant_id,
                    context.company_id,
                    batch_id,
                    settlement_no,
                    carrier_id,
                    subtotal,
                    tax,
                    total,
                    today + timedelta(days=15),
                    Jsonb({"flow_test_run_id": run_id, "shipment_count": len(items)}),
                    CHANNEL,
                    CLIENT,
                    CHANNEL,
                    CLIENT,
                ),
            )
            settlement_id = int(cur.fetchone()["settlement_id"])
            settlement_ids.append(settlement_id)
            cur.execute(
                f"delete from {q('carrier_settlement_lines')} where settlement_id = %s and deleted_at is null",
                (settlement_id,),
            )
            for line_no, item in enumerate(items, start=1):
                line_tax = (item["cost"] * Decimal("0.1")).quantize(Decimal("1"))
                cur.execute(
                    f"""
                    insert into {q("carrier_settlement_lines")} (
                        tenant_id, settlement_id, shipment_charge_id, charge_code_id,
                        line_no, description, quantity, unit_rate, line_amount,
                        tax_amount, created_channel_code, created_from_client,
                        updated_channel_code, updated_from_client
                    )
                    values (%s, %s, %s, %s, %s, %s, 1, %s, %s, %s, %s, %s, %s, %s)
                    """,
                    (
                        context.tenant_id,
                        settlement_id,
                        item["shipment_charge_id"],
                        context.base_charge_code_id,
                        line_no,
                        f"{item['shipment_no']} 매입 운임",
                        item["cost"],
                        item["cost"],
                        line_tax,
                        CHANNEL,
                        CLIENT,
                        CHANNEL,
                        CLIENT,
                    ),
                )
                cur.execute(
                    f"""
                    update {q("shipment_charges")}
                    set charge_status = 'SETTLED',
                        version_no = version_no + 1,
                        updated_at = now(),
                        updated_channel_code = %s,
                        updated_from_client = %s
                    where shipment_charge_id = %s
                    """,
                    (CHANNEL, CLIENT, item["shipment_charge_id"]),
                )

        for item in planned:
            cur.execute(
                f"""
                update {q("shipments")}
                set shipment_status = 'CLOSED',
                    version_no = version_no + 1,
                    updated_at = now(),
                    updated_channel_code = %s,
                    updated_from_client = %s
                where shipment_id = %s
                """,
                (CHANNEL, CLIENT, item["shipment_id"]),
            )
            cur.execute(
                f"""
                update {q("transport_orders")}
                set order_status = 'CLOSED',
                    version_no = version_no + 1,
                    updated_at = now(),
                    updated_channel_code = %s,
                    updated_from_client = %s
                where order_id = %s
                """,
                (CHANNEL, CLIENT, item["order_id"]),
            )
    conn.commit()
    return {"invoice_ids": invoice_ids, "settlement_ids": settlement_ids, "batch_ids": batch_ids}


def validate(conn: psycopg.Connection, run_id: str) -> dict[str, Any]:
    with conn.cursor() as cur:
        checks = {}
        queries = {
            "orders_closed": f"""
                select count(*)::int as count
                from {q("transport_orders")}
                where deleted_at is null
                  and metadata->>'flow_test_run_id' = %s
                  and order_status = 'CLOSED'
            """,
            "shipments_closed": f"""
                select count(*)::int as count
                from {q("shipments")}
                where deleted_at is null
                  and metadata->>'flow_test_run_id' = %s
                  and shipment_status = 'CLOSED'
            """,
            "dispatches_completed": f"""
                select count(*)::int as count
                from {q("dispatches")} d
                join {q("shipments")} s on s.shipment_id = d.shipment_id
                where d.deleted_at is null
                  and s.metadata->>'flow_test_run_id' = %s
                  and d.dispatch_status = 'COMPLETED'
            """,
            "stops_completed": f"""
                select count(*)::int as count
                from {q("shipment_stops")} st
                join {q("shipments")} s on s.shipment_id = st.shipment_id
                where st.deleted_at is null
                  and s.metadata->>'flow_test_run_id' = %s
                  and st.stop_status = 'COMPLETED'
            """,
            "pods": f"""
                select count(*)::int as count
                from {q("proof_of_deliveries")}
                where deleted_at is null
                  and metadata->>'flow_test_run_id' = %s
                  and delivery_status = 'DELIVERED'
            """,
            "invoice_lines": f"""
                select count(*)::int as count
                from {q("customer_invoice_lines")} il
                join {q("customer_invoices")} i on i.invoice_id = il.invoice_id
                where il.deleted_at is null
                  and i.deleted_at is null
                  and i.metadata->>'flow_test_run_id' = %s
            """,
            "settlement_lines": f"""
                select count(*)::int as count
                from {q("carrier_settlement_lines")} sl
                join {q("carrier_settlements")} s on s.settlement_id = sl.settlement_id
                where sl.deleted_at is null
                  and s.deleted_at is null
                  and s.metadata->>'flow_test_run_id' = %s
            """,
            "carrier_tenders": f"""
                select count(*)::int as count
                from {q("carrier_tenders")} ct
                join {q("shipments")} s on s.shipment_id = ct.shipment_id
                where ct.deleted_at is null
                  and s.metadata->>'flow_test_run_id' = %s
                  and ct.tender_status = 'ACCEPTED'
            """,
            "carrier_responses": f"""
                select count(*)::int as count
                from {q("carrier_tender_responses")} cr
                join {q("carrier_tenders")} ct on ct.tender_id = cr.tender_id
                join {q("shipments")} s on s.shipment_id = ct.shipment_id
                where cr.deleted_at is null
                  and ct.deleted_at is null
                  and s.metadata->>'flow_test_run_id' = %s
                  and cr.response_status = 'ACCEPTED'
            """,
            "gps_events": f"""
                select count(*)::int as count
                from {q("tracking_events")} te
                join {q("shipments")} s on s.shipment_id = te.shipment_id
                where te.deleted_at is null
                  and s.metadata->>'flow_test_run_id' = %s
                  and te.event_type = 'GPS_POSITION'
            """,
        }
        for name, sql in queries.items():
            cur.execute(sql, (run_id,))
            checks[name] = int(cur.fetchone()["count"])

        cur.execute(
            f"""
            select
              coalesce(sum(oc.charge_amount), 0)::numeric as order_charge_sum,
              coalesce((
                select sum(il.line_amount)
                from {q("customer_invoice_lines")} il
                join {q("customer_invoices")} i on i.invoice_id = il.invoice_id
                where il.deleted_at is null
                  and i.deleted_at is null
                  and i.metadata->>'flow_test_run_id' = %s
              ), 0)::numeric as invoice_line_sum,
              coalesce((
                select sum(sc.charge_amount)
                from {q("shipment_charges")} sc
                join {q("shipments")} s on s.shipment_id = sc.shipment_id
                where sc.deleted_at is null
                  and s.metadata->>'flow_test_run_id' = %s
              ), 0)::numeric as shipment_charge_sum,
              coalesce((
                select sum(sl.line_amount)
                from {q("carrier_settlement_lines")} sl
                join {q("carrier_settlements")} cs on cs.settlement_id = sl.settlement_id
                where sl.deleted_at is null
                  and cs.deleted_at is null
                  and cs.metadata->>'flow_test_run_id' = %s
              ), 0)::numeric as settlement_line_sum
            from {q("transport_orders")} o
            join {q("order_charges")} oc on oc.order_id = o.order_id and oc.deleted_at is null
            where o.deleted_at is null
              and o.metadata->>'flow_test_run_id' = %s
            """,
            (run_id, run_id, run_id, run_id),
        )
        sums = cur.fetchone()

        cur.execute(
            f"""
            select s.shipment_no, count(cr.tender_response_id)::int as active_response_count
            from {q("shipments")} s
            join {q("carrier_tenders")} ct on ct.shipment_id = s.shipment_id and ct.deleted_at is null
            left join {q("carrier_tender_responses")} cr on cr.tender_id = ct.tender_id and cr.deleted_at is null
            where s.deleted_at is null
              and s.metadata->>'flow_test_run_id' = %s
            group by s.shipment_no
            having count(cr.tender_response_id) <> 1
            order by s.shipment_no
            """,
            (run_id,),
        )
        duplicate_responses = cur.fetchall()

        cur.execute(
            f"""
            select count(*)::int as count
            from {q("shipments")} s
            left join {q("proof_of_deliveries")} pod
              on pod.shipment_id = s.shipment_id
             and pod.deleted_at is null
            where s.deleted_at is null
              and s.metadata->>'flow_test_run_id' = %s
              and pod.pod_id is null
            """,
            (run_id,),
        )
        missing_pod = int(cur.fetchone()["count"])

    expected = {
        "orders_closed": 30,
        "shipments_closed": 30,
        "dispatches_completed": 30,
        "stops_completed": 60,
        "pods": 30,
        "invoice_lines": 30,
        "settlement_lines": 30,
        "carrier_tenders": 15,
        "carrier_responses": 15,
        "gps_events": 30,
    }
    failures = []
    for name, expected_value in expected.items():
        if checks.get(name) != expected_value:
            failures.append(f"{name}: expected {expected_value}, got {checks.get(name)}")
    if Decimal(sums["order_charge_sum"]) != Decimal(sums["invoice_line_sum"]):
        failures.append(
            f"AR amount mismatch: order={sums['order_charge_sum']} invoice={sums['invoice_line_sum']}"
        )
    if Decimal(sums["shipment_charge_sum"]) != Decimal(sums["settlement_line_sum"]):
        failures.append(
            "AP amount mismatch: "
            f"shipment_charge={sums['shipment_charge_sum']} settlement={sums['settlement_line_sum']}"
        )
    if duplicate_responses:
        failures.append(f"carrier response duplicate/missing rows: {duplicate_responses}")
    if missing_pod:
        failures.append(f"shipments missing POD: {missing_pod}")

    return {
        "run_id": run_id,
        "checks": checks,
        "sums": {key: str(value) for key, value in sums.items()},
        "duplicate_responses": duplicate_responses,
        "missing_pod": missing_pod,
        "failures": failures,
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-id", default=datetime.now().strftime("%Y%m%d%H%M%S"))
    parser.add_argument("--count", type=int, default=30)
    args = parser.parse_args()

    if args.count != 30:
        raise RuntimeError("This smoke test is intentionally fixed to 30 orders.")

    print(f"run_id={args.run_id}")
    health = urllib.request.urlopen(BASE_URL.rstrip() + "/api/health", timeout=15)
    print(f"health={health.status}")
    create_orders(args.run_id, args.count)
    with connect() as conn:
        context = ensure_context(conn)
        planned_result = plan_shipments(conn, context, args.run_id)
        planned = planned_result["orders"]
    confirm_carrier_dispatches(args.run_id, planned)
    send_tracking_positions(planned)
    with connect() as conn:
        context = ensure_context(conn)
        complete_and_settle(conn, context, args.run_id, planned)
        validation = validate(conn, args.run_id)

    print(json.dumps(validation, ensure_ascii=False, indent=2, default=str))
    if validation["failures"]:
        return 1
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise
