from __future__ import annotations

import json
import mimetypes
import os
import posixpath
import re
from decimal import Decimal, InvalidOperation
from pathlib import Path
from urllib.parse import parse_qs, unquote

import asyncpg


mimetypes.add_type("application/javascript", ".js")
mimetypes.add_type("application/wasm", ".wasm")
mimetypes.add_type("application/json", ".json")
mimetypes.add_type("image/png", ".png")

STATIC_ROOT = Path(os.environ.get("KTMS_STATIC_ROOT", "/web/frontend")).resolve()
INDEX_FILE = STATIC_ROOT / "index.html"
ENV_FILES = (
    Path(os.environ.get("KTMS_ENV_FILE", "/web/app/.env")),
    Path("/web/.env"),
)
BLOCKED_SEGMENTS = {
    "__pycache__",
    "app",
    "backend",
    ".cache",
    ".local",
    ".redis",
    ".vim",
}
ALLOWED_SCHEMAS = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


class KtmsApp:
    async def __call__(self, scope, receive, send):
        if scope["type"] != "http":
            await self._send_text(send, 404, "Not found")
            return

        path = scope.get("path", "/")
        if path.startswith("/api/"):
            await self._handle_api(scope, receive, send)
            return

        await self._handle_static(scope, send)

    async def _handle_api(self, scope, receive, send):
        method = scope.get("method", "GET").upper()
        path = scope.get("path", "/")

        if method == "OPTIONS":
            await self._send_json(send, 204, None)
            return

        try:
            if method == "GET" and path == "/api/health":
                await self._send_json(
                    send,
                    200,
                    {
                        "status": "ok",
                        "service": "ktms-api",
                        "runtime": "gabia-asgi",
                    },
                )
                return

            if method == "GET" and path == "/api/masters/business-partners":
                result = await self._list_business_partners(scope)
                await self._send_json(send, 200, result)
                return

            if method != "POST":
                await self._send_json(send, 405, {"detail": "Method not allowed"})
                return

            body = await self._read_body(receive)
            payload = json.loads(body.decode("utf-8") if body else "{}")
            routes = {
                "/api/masters/business-partners": self._save_business_partner,
                "/api/masters/locations": self._save_location,
                "/api/masters/geo-zones": self._save_geo_zone,
                "/api/masters/transport-routes": self._save_transport_route,
                "/api/masters/vehicles": self._save_vehicle,
                "/api/masters/drivers": self._save_driver,
                "/api/masters/items": self._save_item,
                "/api/masters/rate-agreements": self._save_rate_agreement,
                "/api/masters/user-access": self._save_user_access,
                "/api/masters/common-codes": self._save_common_code,
                "/api/orders/transport-orders": self._save_transport_order,
                "/api/tracking/positions": self._save_tracking_position,
                "/api/carrier/dispatch-confirmations": self._confirm_carrier_dispatch,
            }
            handler = routes.get(path)
            if handler is None:
                await self._send_json(send, 404, {"detail": "API endpoint not found"})
                return

            result = await handler(payload, scope)
            await self._send_json(send, 200, result)
        except json.JSONDecodeError:
            await self._send_json(send, 400, {"detail": "Invalid JSON body"})
        except asyncpg.UniqueViolationError:
            await self._send_json(
                send,
                409,
                {"detail": "이미 등록된 코드 또는 식별값입니다."},
            )
        except Exception as exc:
            await self._send_json(
                send,
                500,
                {"detail": "DB 저장 중 오류가 발생했습니다.", "error": str(exc)[:180]},
            )

    async def _handle_static(self, scope, send):
        method = scope.get("method", "GET").upper()
        if method not in {"GET", "HEAD"}:
            await self._send_text(send, 405, "Method not allowed")
            return

        try:
            target = self._resolve_path(scope.get("path", "/"))
            if target is None or not target.exists() or not target.is_file():
                await self._send_text(send, 404, "Not found")
                return

            content_type = mimetypes.guess_type(str(target))[0] or "application/octet-stream"
            body = b"" if method == "HEAD" else target.read_bytes()
            headers = [
                (b"content-type", content_type.encode("ascii")),
                (b"cache-control", self._cache_control(target).encode("ascii")),
            ]
            if method == "HEAD":
                headers.append((b"content-length", str(target.stat().st_size).encode("ascii")))
            else:
                headers.append((b"content-length", str(len(body)).encode("ascii")))

            await send({"type": "http.response.start", "status": 200, "headers": headers})
            await send({"type": "http.response.body", "body": body})
        except Exception:
            await self._send_text(send, 500, "Internal server error")

    def _resolve_path(self, raw_path: str):
        decoded_path = unquote(raw_path.split("?", 1)[0])
        normalized = posixpath.normpath(decoded_path).lstrip("/")

        if normalized in {"", "."}:
            return INDEX_FILE

        segments = [segment for segment in normalized.split("/") if segment]
        if segments and segments[0] == "frontend":
            normalized = "/".join(segments[1:])
            segments = [segment for segment in normalized.split("/") if segment]
            if not normalized:
                return INDEX_FILE

        if any(segment.startswith(".") or segment in BLOCKED_SEGMENTS for segment in segments):
            return None

        target = (STATIC_ROOT / normalized).resolve()
        if STATIC_ROOT not in target.parents and target != STATIC_ROOT:
            return None

        if target.is_dir():
            return target / "index.html"

        if target.exists():
            return target

        if Path(normalized).suffix:
            return None

        return INDEX_FILE

    def _cache_control(self, target: Path) -> str:
        if target.name in {"index.html", "flutter_service_worker.js"}:
            return "no-cache"
        return "public, max-age=3600"

    async def _read_body(self, receive):
        chunks = []
        more_body = True
        while more_body:
            message = await receive()
            chunks.append(message.get("body", b""))
            more_body = message.get("more_body", False)
        return b"".join(chunks)

    async def _connect(self):
        env = self._settings()
        return await asyncpg.connect(
            host=env["KTMS_DB_HOST"],
            port=int(env.get("KTMS_DB_PORT", "5432")),
            database=env["KTMS_DB_NAME"],
            user=env["KTMS_DB_USER"],
            password=env["KTMS_DB_PASSWORD"],
        )

    def _settings(self):
        values = {}
        for env_file in ENV_FILES:
            if not env_file.exists():
                continue
            for line in env_file.read_text().splitlines():
                line = line.strip()
                if not line or line.startswith("#") or "=" not in line:
                    continue
                key, value = line.split("=", 1)
                values[key.strip()] = value.strip().strip("\"").strip("'")

        values.update({key: value for key, value in os.environ.items() if key.startswith("KTMS_DB_")})
        required = ("KTMS_DB_HOST", "KTMS_DB_NAME", "KTMS_DB_USER", "KTMS_DB_PASSWORD")
        missing = [key for key in required if not values.get(key)]
        if missing:
            raise RuntimeError("Missing DB settings: " + ", ".join(missing))

        schema = values.get("KTMS_DB_SCHEMA", "ktms")
        if not ALLOWED_SCHEMAS.match(schema):
            raise RuntimeError("Invalid schema name")
        values["KTMS_DB_SCHEMA"] = schema
        return values

    def _table(self, table_name: str):
        schema = self._settings()["KTMS_DB_SCHEMA"]
        return f"{schema}.{table_name}"

    async def _context(self, conn, payload):
        tenant_id = payload.get("tenant_id")
        company_id = payload.get("company_id")
        if tenant_id and company_id:
            return int(tenant_id), int(company_id)

        row = await conn.fetchrow(
            f"""
            select t.tenant_id, c.company_id
            from {self._table("tenants")} t
            join {self._table("companies")} c on c.tenant_id = t.tenant_id
            where t.deleted_at is null
              and c.deleted_at is null
              and t.is_active = true
              and c.is_active = true
            order by t.tenant_id, c.company_id
            limit 1
            """
        )
        if row is None:
            raise RuntimeError("No active tenant/company context was found.")
        return int(tenant_id or row["tenant_id"]), int(company_id or row["company_id"])

    async def _tenant_context(self, conn, payload):
        tenant_id = payload.get("tenant_id")
        if tenant_id:
            return int(tenant_id)
        tenant_id, _ = await self._context(conn, payload)
        return tenant_id

    def _source(self, scope):
        headers = dict(scope.get("headers") or [])
        client = scope.get("client") or [None]
        user_agent = headers.get(b"user-agent", b"").decode("utf-8", "ignore")[:200] or None
        return "WEB", client[0], user_agent

    def _text(self, payload, key, default=None, upper=False):
        value = payload.get(key, default)
        if value is None:
            return None
        value = str(value).strip()
        if not value:
            return None
        return value.upper() if upper else value

    def _decimal(self, payload, key):
        value = payload.get(key)
        if value is None:
            return None
        text = str(value).replace(",", "").strip()
        if not text:
            return None
        try:
            return Decimal(text)
        except InvalidOperation:
            return None

    def _jsonb(self, payload, **extra):
        metadata = dict(payload.get("metadata") or {})
        metadata["source"] = "ktms_flutter_master"
        for key, value in extra.items():
            if value not in (None, ""):
                metadata[key] = value
        return json.dumps(metadata, ensure_ascii=False)

    def _query_params(self, scope):
        raw = scope.get("query_string", b"").decode("utf-8", "ignore")
        parsed = parse_qs(raw, keep_blank_values=False)
        return {key: values[-1] for key, values in parsed.items() if values}

    async def _list_business_partners(self, scope):
        params = self._query_params(scope)
        payload = {}
        if params.get("tenant_id"):
            payload["tenant_id"] = params["tenant_id"]
        if params.get("company_id"):
            payload["company_id"] = params["company_id"]

        conn = await self._connect()
        try:
            tenant_id, company_id = await self._context(conn, payload)
            args = [tenant_id, company_id]
            filters = [
                "tenant_id = $1",
                "company_id = $2",
                "deleted_at is null",
                "is_active = true",
            ]

            partner_type = (params.get("partner_type") or "").strip().upper()
            if partner_type:
                args.append(partner_type)
                filters.append(f"partner_type = ${len(args)}")

            query_text = (params.get("q") or "").strip()
            if query_text:
                like_query = f"%{query_text}%"
                args.extend([like_query, like_query, like_query, like_query])
                start = len(args) - 3
                filters.append(
                    "("
                    f"partner_code ilike ${start} "
                    f"or partner_name ilike ${start + 1} "
                    f"or partner_short_name ilike ${start + 2} "
                    f"or coalesce(phone, '') ilike ${start + 3}"
                    ")"
                )

            try:
                limit = int(params.get("limit", "80"))
            except ValueError:
                limit = 80
            limit = max(1, min(limit, 200))
            args.append(limit)

            rows = await conn.fetch(
                f"""
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
                from {self._table("business_partners")}
                where {" and ".join(filters)}
                order by
                    case partner_type
                        when 'CUSTOMER' then 1
                        when 'SHIPPER' then 2
                        when 'CARRIER' then 3
                        else 9
                    end,
                    partner_name
                limit ${len(args)}
                """,
                *args,
            )

            return {"items": [dict(row) for row in rows]}
        finally:
            await conn.close()

    async def _save_business_partner(self, payload, scope):
        conn = await self._connect()
        try:
            tenant_id, company_id = await self._context(conn, payload)
            channel, ip, client = self._source(scope)
            row = await conn.fetchrow(
                f"""
                insert into {self._table("business_partners")} (
                    tenant_id, company_id, partner_code, partner_name,
                    partner_short_name, partner_type, tax_registration_no,
                    representative_name, phone, email, payment_terms,
                    credit_limit, status, is_active, metadata,
                    created_channel_code, created_from_ip, created_from_client,
                    updated_channel_code, updated_from_ip, updated_from_client
                )
                values (
                    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11,
                    $12::numeric, $13, $14, $15::jsonb, $16, $17, $18,
                    $16, $17, $18
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
                """,
                tenant_id,
                company_id,
                self._text(payload, "partner_code", upper=True),
                self._text(payload, "partner_name"),
                self._text(payload, "partner_short_name") or self._text(payload, "partner_name"),
                self._text(payload, "partner_type", "CUSTOMER", upper=True),
                self._text(payload, "tax_registration_no"),
                self._text(payload, "representative_name"),
                self._text(payload, "phone"),
                self._text(payload, "email"),
                self._text(payload, "payment_terms"),
                self._decimal(payload, "credit_limit"),
                self._text(payload, "status", "ACTIVE", upper=True),
                bool(payload.get("is_active", True)),
                self._jsonb(payload),
                channel,
                ip,
                client,
            )
            return {"saved": True, "table": "business_partners", "id": row["partner_id"], "code": row["partner_code"]}
        finally:
            await conn.close()

    async def _save_location(self, payload, scope):
        conn = await self._connect()
        try:
            tenant_id = await self._tenant_context(conn, payload)
            channel, ip, client = self._source(scope)
            row = await conn.fetchrow(
                f"""
                insert into {self._table("locations")} (
                    tenant_id, location_code, location_name, country_code,
                    postal_code, state_province, city, district, address_line1,
                    address_line2, latitude, longitude, timezone_name,
                    geofence_radius_m, is_active, metadata,
                    created_channel_code, created_from_ip, created_from_client,
                    updated_channel_code, updated_from_ip, updated_from_client
                )
                values (
                    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
                    $11::numeric, $12::numeric, $13, $14, $15, $16::jsonb,
                    $17, $18, $19, $17, $18, $19
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
                """,
                tenant_id,
                self._text(payload, "location_code", upper=True),
                self._text(payload, "location_name"),
                self._text(payload, "country_code", "KR", upper=True),
                self._text(payload, "postal_code"),
                self._text(payload, "state_province"),
                self._text(payload, "city"),
                self._text(payload, "district"),
                self._text(payload, "address_line1"),
                self._text(payload, "address_line2"),
                self._decimal(payload, "latitude"),
                self._decimal(payload, "longitude"),
                self._text(payload, "timezone_name", "Asia/Seoul"),
                payload.get("geofence_radius_m"),
                bool(payload.get("is_active", True)),
                self._jsonb(payload, location_type=payload.get("location_type")),
                channel,
                ip,
                client,
            )
            return {"saved": True, "table": "locations", "id": row["location_id"], "code": row["location_code"]}
        finally:
            await conn.close()

    async def _save_geo_zone(self, payload, scope):
        conn = await self._connect()
        try:
            tenant_id = await self._tenant_context(conn, payload)
            channel, ip, client = self._source(scope)
            row = await conn.fetchrow(
                f"""
                insert into {self._table("geo_zones")} (
                    tenant_id, zone_code, zone_name, zone_type, description,
                    is_active, metadata, created_channel_code, created_from_ip,
                    created_from_client, updated_channel_code, updated_from_ip,
                    updated_from_client
                )
                values ($1, $2, $3, $4, $5, $6, $7::jsonb, $8, $9, $10, $8, $9, $10)
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
                """,
                tenant_id,
                self._text(payload, "zone_code", upper=True),
                self._text(payload, "zone_name"),
                self._text(payload, "zone_type", "REGION", upper=True),
                self._text(payload, "description"),
                bool(payload.get("is_active", True)),
                self._jsonb(payload),
                channel,
                ip,
                client,
            )
            return {"saved": True, "table": "geo_zones", "id": row["geo_zone_id"], "code": row["zone_code"]}
        finally:
            await conn.close()

    async def _find_geo_zone_id(self, conn, tenant_id, zone_name):
        zone = (zone_name or "").strip()
        if not zone:
            return None
        row = await conn.fetchrow(
            f"""
            select geo_zone_id
            from {self._table("geo_zones")}
            where tenant_id = $1
              and deleted_at is null
              and (zone_code = $2 or zone_name = $3)
            order by geo_zone_id
            limit 1
            """,
            tenant_id,
            zone.upper(),
            zone,
        )
        return row["geo_zone_id"] if row else None

    async def _save_transport_route(self, payload, scope):
        conn = await self._connect()
        try:
            tenant_id = await self._tenant_context(conn, payload)
            channel, ip, client = self._source(scope)
            row = await conn.fetchrow(
                f"""
                insert into {self._table("transport_routes")} (
                    tenant_id, route_code, route_name, origin_name,
                    destination_name, geo_zone_id, zone_name, service_level,
                    distance_km, lead_time_hours, base_fare, vehicle_limit,
                    appointment_required, toll_included, temperature_controlled,
                    status, is_active, metadata, created_channel_code,
                    created_from_ip, created_from_client, updated_channel_code,
                    updated_from_ip, updated_from_client
                )
                values (
                    $1, $2, $3, $4, $5, $6, $7, $8,
                    $9::numeric, $10::numeric, $11::numeric, $12,
                    $13, $14, $15, $16, $17, $18::jsonb,
                    $19, $20, $21, $19, $20, $21
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
                """,
                tenant_id,
                self._text(payload, "route_code", upper=True),
                self._text(payload, "route_name"),
                self._text(payload, "origin_name"),
                self._text(payload, "destination_name"),
                await self._find_geo_zone_id(conn, tenant_id, payload.get("zone_name")),
                self._text(payload, "zone_name"),
                self._text(payload, "service_level"),
                self._decimal(payload, "distance_km"),
                self._decimal(payload, "lead_time_hours"),
                self._decimal(payload, "base_fare"),
                self._text(payload, "vehicle_limit"),
                bool(payload.get("appointment_required", False)),
                bool(payload.get("toll_included", True)),
                bool(payload.get("temperature_controlled", False)),
                self._text(payload, "status", "ACTIVE", upper=True),
                bool(payload.get("is_active", True)),
                self._jsonb(payload),
                channel,
                ip,
                client,
            )
            return {"saved": True, "table": "transport_routes", "id": row["transport_route_id"], "code": row["route_code"]}
        finally:
            await conn.close()

    async def _find_carrier_id(self, conn, tenant_id, company_id, carrier_name):
        carrier = (carrier_name or "").strip()
        if not carrier:
            return None
        row = await conn.fetchrow(
            f"""
            select partner_id
            from {self._table("business_partners")}
            where tenant_id = $1
              and company_id = $2
              and partner_type = 'CARRIER'
              and deleted_at is null
              and (partner_code = $3 or partner_name = $4 or partner_short_name = $4)
            order by partner_id
            limit 1
            """,
            tenant_id,
            company_id,
            carrier.upper(),
            carrier,
        )
        return row["partner_id"] if row else None

    def _vehicle_status(self, payload):
        if not bool(payload.get("is_active", True)):
            return "INACTIVE"
        status = self._text(payload, "status", "AVAILABLE", upper=True)
        if status == "DISPATCHED":
            return "ASSIGNED"
        if status not in {"AVAILABLE", "ASSIGNED", "MAINTENANCE", "INACTIVE"}:
            return "AVAILABLE"
        return status

    def _driver_status(self, payload):
        if not bool(payload.get("is_active", True)):
            return "INACTIVE"
        status = self._text(payload, "status", "ACTIVE", upper=True)
        if status not in {"ACTIVE", "OFF_DUTY", "ON_LEAVE", "INACTIVE"}:
            return "ACTIVE"
        return status

    async def _save_vehicle(self, payload, scope):
        conn = await self._connect()
        try:
            tenant_id, company_id = await self._context(conn, payload)
            channel, ip, client = self._source(scope)
            row = await conn.fetchrow(
                f"""
                insert into {self._table("vehicles")} (
                    tenant_id, carrier_id, vehicle_code, plate_no, fuel_type,
                    max_weight_kg, max_volume_cbm, temperature_controlled,
                    status, is_active, metadata, created_channel_code,
                    created_from_ip, created_from_client, updated_channel_code,
                    updated_from_ip, updated_from_client
                )
                values (
                    $1, $2, $3, $4, $5, $6::numeric, $7::numeric, $8,
                    $9, $10, $11::jsonb, $12, $13, $14, $12, $13, $14
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
                """,
                tenant_id,
                await self._find_carrier_id(conn, tenant_id, company_id, payload.get("carrier_name")),
                self._text(payload, "vehicle_code", upper=True),
                self._text(payload, "plate_no"),
                self._text(payload, "fuel_type"),
                self._decimal(payload, "max_weight_kg"),
                self._decimal(payload, "max_volume_cbm"),
                bool(payload.get("temperature_controlled", False)),
                self._vehicle_status(payload),
                bool(payload.get("is_active", True)),
                self._jsonb(
                    payload,
                    vehicle_type=payload.get("vehicle_type"),
                    carrier_name=payload.get("carrier_name"),
                    driver_name=payload.get("driver_name"),
                    tonnage=payload.get("tonnage"),
                    home_yard=payload.get("home_yard"),
                    gps_enabled=payload.get("gps_enabled"),
                    tail_lift=payload.get("tail_lift"),
                    insurance_expiry=payload.get("insurance_expiry"),
                    inspection_expiry=payload.get("inspection_expiry"),
                ),
                channel,
                ip,
                client,
            )
            return {"saved": True, "table": "vehicles", "id": row["vehicle_id"], "code": row["vehicle_code"]}
        finally:
            await conn.close()

    async def _find_vehicle_id_for_tracking(self, conn, tenant_id, payload):
        vehicle_id = payload.get("vehicle_id")
        if vehicle_id:
            return int(vehicle_id)

        vehicle_no = self._text(payload, "vehicle_no")
        if not vehicle_no:
            return None

        row = await conn.fetchrow(
            f"""
            select vehicle_id
            from {self._table("vehicles")}
            where tenant_id = $1
              and deleted_at is null
              and replace(coalesce(plate_no, vehicle_code), ' ', '') = $2
            order by vehicle_id
            limit 1
            """,
            tenant_id,
            vehicle_no.replace(" ", ""),
        )
        return row["vehicle_id"] if row else None

    async def _find_shipment_id_for_tracking(self, conn, tenant_id, company_id, payload):
        shipment_id = payload.get("shipment_id")
        if shipment_id:
            return int(shipment_id)

        plan_no = self._text(payload, "plan_no")
        if not plan_no:
            return None

        row = await conn.fetchrow(
            f"""
            select shipment_id
            from {self._table("shipments")}
            where tenant_id = $1
              and company_id = $2
              and deleted_at is null
              and (
                shipment_no = $3
                or metadata->>'plan_no' = $3
                or metadata->>'load_plan_no' = $3
              )
            order by shipment_id
            limit 1
            """,
            tenant_id,
            company_id,
            plan_no,
        )
        return row["shipment_id"] if row else None

    async def _save_tracking_position(self, payload, scope):
        latitude = self._decimal(payload, "latitude")
        longitude = self._decimal(payload, "longitude")
        if latitude is None or longitude is None:
            raise ValueError("latitude and longitude are required.")

        conn = await self._connect()
        try:
            tenant_id, company_id = await self._context(conn, payload)
            channel, ip, client = self._source(scope)
            shipment_id = await self._find_shipment_id_for_tracking(
                conn, tenant_id, company_id, payload
            )
            vehicle_id = await self._find_vehicle_id_for_tracking(conn, tenant_id, payload)
            raw_payload = {
                "source": "ktms_execution_tracking",
                "vehicle_no": self._text(payload, "vehicle_no"),
                "driver_name": self._text(payload, "driver_name"),
                "plan_no": self._text(payload, "plan_no"),
                "status_label": self._text(payload, "status_label"),
                "eta_label": self._text(payload, "eta_label"),
                "progress": self._text(payload, "progress"),
                "metadata": payload.get("metadata") or {},
            }
            raw_payload = {
                key: value for key, value in raw_payload.items() if value not in (None, "")
            }

            async with conn.transaction():
                gps_row = await conn.fetchrow(
                    f"""
                    insert into {self._table("gps_positions")} (
                        tenant_id, shipment_id, vehicle_id, captured_at,
                        latitude, longitude, speed_kph, heading_degree,
                        ignition_on, source_system, raw_payload,
                        created_channel_code, created_from_ip,
                        created_from_client, updated_channel_code,
                        updated_from_ip, updated_from_client
                    )
                    values (
                        $1, $2, $3, coalesce($4::text::timestamptz, now()),
                        $5::numeric, $6::numeric, $7::numeric, $8::numeric,
                        true, 'KTMS_WEB', $9::jsonb, $10, $11, $12,
                        $10, $11, $12
                    )
                    returning gps_position_id, captured_at
                    """,
                    tenant_id,
                    shipment_id,
                    vehicle_id,
                    self._text(payload, "captured_at"),
                    latitude,
                    longitude,
                    self._decimal(payload, "speed_kph"),
                    self._decimal(payload, "heading_degree"),
                    json.dumps(raw_payload, ensure_ascii=False),
                    channel,
                    ip,
                    client,
                )
                event_payload = dict(raw_payload)
                event_payload["gps_position_id"] = gps_row["gps_position_id"]
                event_payload["shipment_id"] = shipment_id
                event_payload["vehicle_id"] = vehicle_id

                event_row = await conn.fetchrow(
                    f"""
                    insert into {self._table("tracking_events")} (
                        tenant_id, company_id, shipment_id, event_type,
                        event_status, event_time, source_type, source_system,
                        latitude, longitude, location_text, notes, payload,
                        created_channel_code, created_from_ip,
                        created_from_client, updated_channel_code,
                        updated_from_ip, updated_from_client
                    )
                    values (
                        $1, $2, $3, 'GPS_POSITION', 'RECORDED', $4,
                        'GPS', 'KTMS_WEB', $5::numeric, $6::numeric,
                        $7, $8, $9::jsonb, $10, $11, $12, $10, $11, $12
                    )
                    returning tracking_event_id
                    """,
                    tenant_id,
                    company_id,
                    shipment_id,
                    gps_row["captured_at"],
                    latitude,
                    longitude,
                    self._text(payload, "location_text"),
                    self._text(payload, "notes"),
                    json.dumps(event_payload, ensure_ascii=False),
                    channel,
                    ip,
                    client,
                )

            return {
                "saved": True,
                "gps_position_id": gps_row["gps_position_id"],
                "tracking_event_id": event_row["tracking_event_id"],
                "shipment_id": shipment_id,
                "vehicle_id": vehicle_id,
            }
        finally:
            await conn.close()

    def _carrier_partner_code(self, payload):
        return self._text(payload, "carrier_code", upper=True) or self._slug_code(
            "CARR",
            payload.get("carrier_name"),
            "CARRIER",
            60,
        )

    async def _ensure_carrier_id_for_dispatch(self, conn, tenant_id, company_id, payload, channel, ip, client):
        carrier_name = self._text(payload, "carrier_name") or "운송사"
        partner_code = self._carrier_partner_code(payload)
        row = await conn.fetchrow(
            f"""
            insert into {self._table("business_partners")} (
                tenant_id, company_id, partner_code, partner_name,
                partner_short_name, partner_type, phone, email,
                payment_terms, status, is_active, metadata,
                created_channel_code, created_from_ip, created_from_client,
                updated_channel_code, updated_from_ip, updated_from_client
            )
            values (
                $1, $2, $3, $4, $4, 'CARRIER', $5, $6, $7,
                'ACTIVE', true, $8::jsonb, $9, $10, $11, $9, $10, $11
            )
            on conflict (tenant_id, company_id, partner_code)
            where deleted_at is null
            do update set
                partner_name = excluded.partner_name,
                partner_short_name = excluded.partner_short_name,
                partner_type = 'CARRIER',
                phone = excluded.phone,
                email = excluded.email,
                payment_terms = excluded.payment_terms,
                status = 'ACTIVE',
                is_active = true,
                metadata = {self._table("business_partners")}.metadata || excluded.metadata,
                updated_at = now(),
                updated_channel_code = excluded.updated_channel_code,
                updated_from_ip = excluded.updated_from_ip,
                updated_from_client = excluded.updated_from_client
            returning partner_id
            """,
            tenant_id,
            company_id,
            partner_code,
            carrier_name,
            self._text(payload, "carrier_phone"),
            self._text(payload, "carrier_email") or self._text(payload, "manager_email"),
            self._text(payload, "payment_terms"),
            self._jsonb(payload, carrier_portal_enabled=True),
            channel,
            ip,
            client,
        )
        return row["partner_id"]

    async def _ensure_vehicle_id_for_dispatch(self, conn, tenant_id, carrier_id, payload, channel, ip, client):
        vehicle_no = self._text(payload, "vehicle_no")
        if not vehicle_no:
            raise ValueError("vehicle_no is required.")
        vehicle_code = self._text(payload, "vehicle_code", upper=True) or self._slug_code(
            "VEH",
            vehicle_no.replace(" ", ""),
            "CARRIER_VEHICLE",
            50,
        )
        normalized_plate = vehicle_no.replace(" ", "")
        metadata = self._jsonb(
            payload,
            source="ktms_carrier_portal",
            vehicle_type=payload.get("vehicle_type"),
            carrier_name=payload.get("carrier_name"),
            driver_name=payload.get("driver_name"),
            gps_enabled=True,
            tracking_plan_no=payload.get("plan_no"),
        )
        row = await conn.fetchrow(
            f"""
            select vehicle_id
            from {self._table("vehicles")}
            where tenant_id = $1
              and deleted_at is null
              and (
                vehicle_code = $2
                or replace(plate_no, ' ', '') = $3
              )
            order by vehicle_id
            limit 1
            """,
            tenant_id,
            vehicle_code,
            normalized_plate,
        )
        if row:
            updated = await conn.fetchrow(
                f"""
                update {self._table("vehicles")}
                set carrier_id = $2,
                    vehicle_code = $3,
                    plate_no = $4,
                    fuel_type = $5,
                    max_weight_kg = $6::numeric,
                    max_volume_cbm = $7::numeric,
                    temperature_controlled = $8,
                    status = 'ASSIGNED',
                    is_active = true,
                    metadata = metadata || $9::jsonb,
                    updated_at = now(),
                    updated_channel_code = $10,
                    updated_from_ip = $11,
                    updated_from_client = $12
                where vehicle_id = $1
                returning vehicle_id
                """,
                row["vehicle_id"],
                carrier_id,
                vehicle_code,
                vehicle_no,
                self._text(payload, "fuel_type", "DIESEL", upper=True),
                self._decimal(payload, "max_weight_kg"),
                self._decimal(payload, "max_volume_cbm"),
                bool(payload.get("temperature_controlled", False)),
                metadata,
                channel,
                ip,
                client,
            )
            return updated["vehicle_id"]

        inserted = await conn.fetchrow(
            f"""
            insert into {self._table("vehicles")} (
                tenant_id, carrier_id, vehicle_code, plate_no, fuel_type,
                max_weight_kg, max_volume_cbm, temperature_controlled,
                status, is_active, metadata, created_channel_code,
                created_from_ip, created_from_client, updated_channel_code,
                updated_from_ip, updated_from_client
            )
            values (
                $1, $2, $3, $4, $5, $6::numeric, $7::numeric, $8,
                'ASSIGNED', true, $9::jsonb, $10, $11, $12, $10, $11, $12
            )
            returning vehicle_id
            """,
            tenant_id,
            carrier_id,
            vehicle_code,
            vehicle_no,
            self._text(payload, "fuel_type", "DIESEL", upper=True),
            self._decimal(payload, "max_weight_kg"),
            self._decimal(payload, "max_volume_cbm"),
            bool(payload.get("temperature_controlled", False)),
            metadata,
            channel,
            ip,
            client,
        )
        return inserted["vehicle_id"]

    async def _ensure_driver_id_for_dispatch(self, conn, tenant_id, carrier_id, payload, channel, ip, client):
        driver_name = self._text(payload, "driver_name")
        if not driver_name:
            raise ValueError("driver_name is required.")
        driver_email = self._text(payload, "driver_email")
        driver_code = self._text(payload, "driver_code", upper=True) or self._slug_code(
            "DRV",
            driver_email or driver_name,
            "CARRIER_DRIVER",
            50,
        )
        metadata = self._jsonb(
            payload,
            source="ktms_carrier_portal",
            carrier_name=payload.get("carrier_name"),
            assigned_vehicle_no=payload.get("vehicle_no"),
        )
        row = await conn.fetchrow(
            f"""
            select driver_id
            from {self._table("drivers")}
            where tenant_id = $1
              and deleted_at is null
              and (
                driver_code = $2
                or ($3::text is not null and lower(email) = lower($3))
              )
            order by driver_id
            limit 1
            """,
            tenant_id,
            driver_code,
            driver_email,
        )
        if row:
            updated = await conn.fetchrow(
                f"""
                update {self._table("drivers")}
                set carrier_id = $2,
                    driver_code = $3,
                    driver_name = $4,
                    phone = $5,
                    email = $6,
                    license_type = $7,
                    license_expiry_date = $8::text::date,
                    status = 'ACTIVE',
                    is_active = true,
                    metadata = metadata || $9::jsonb,
                    updated_at = now(),
                    updated_channel_code = $10,
                    updated_from_ip = $11,
                    updated_from_client = $12
                where driver_id = $1
                returning driver_id
                """,
                row["driver_id"],
                carrier_id,
                driver_code,
                driver_name,
                self._text(payload, "driver_phone"),
                driver_email,
                self._text(payload, "license_type", upper=True),
                self._text(payload, "license_expiry_date"),
                metadata,
                channel,
                ip,
                client,
            )
            return updated["driver_id"]

        inserted = await conn.fetchrow(
            f"""
            insert into {self._table("drivers")} (
                tenant_id, carrier_id, driver_code, driver_name, phone, email,
                license_type, license_expiry_date, status, is_active,
                metadata, created_channel_code, created_from_ip,
                created_from_client, updated_channel_code, updated_from_ip,
                updated_from_client
            )
            values (
                $1, $2, $3, $4, $5, $6, $7, $8::text::date,
                'ACTIVE', true, $9::jsonb, $10, $11, $12, $10, $11, $12
            )
            returning driver_id
            """,
            tenant_id,
            carrier_id,
            driver_code,
            driver_name,
            self._text(payload, "driver_phone"),
            driver_email,
            self._text(payload, "license_type", upper=True),
            self._text(payload, "license_expiry_date"),
            metadata,
            channel,
            ip,
            client,
        )
        return inserted["driver_id"]

    async def _user_id_for_login(self, conn, tenant_id, payload):
        login_id = self._login_id(payload, "manager_email")
        if not login_id:
            return None
        row = await conn.fetchrow(
            f"""
            select user_id
            from {self._table("app_users")}
            where tenant_id = $1
              and deleted_at is null
              and (login_id = $2 or email = $2)
            order by user_id
            limit 1
            """,
            tenant_id,
            login_id,
        )
        return row["user_id"] if row else None

    async def _confirm_carrier_dispatch(self, payload, scope):
        conn = await self._connect()
        try:
            tenant_id, company_id = await self._context(conn, payload)
            channel, ip, client = self._source(scope)
            shipment_id = await self._find_shipment_id_for_tracking(
                conn, tenant_id, company_id, payload
            )
            if shipment_id is None:
                raise ValueError("shipment was not found for plan_no.")

            latitude = self._decimal(payload, "latitude")
            longitude = self._decimal(payload, "longitude")
            dispatch_metadata = self._jsonb(
                payload,
                source="ktms_carrier_portal",
                carrier_name=payload.get("carrier_name"),
                manager_name=payload.get("manager_name"),
                manager_email=payload.get("manager_email"),
                vehicle_no=payload.get("vehicle_no"),
                vehicle_type=payload.get("vehicle_type"),
                driver_name=payload.get("driver_name"),
                tender_no=payload.get("tender_no"),
            )

            async with conn.transaction():
                carrier_id = await self._ensure_carrier_id_for_dispatch(
                    conn, tenant_id, company_id, payload, channel, ip, client
                )
                vehicle_id = await self._ensure_vehicle_id_for_dispatch(
                    conn, tenant_id, carrier_id, payload, channel, ip, client
                )
                driver_id = await self._ensure_driver_id_for_dispatch(
                    conn, tenant_id, carrier_id, payload, channel, ip, client
                )
                dispatcher_user_id = await self._user_id_for_login(conn, tenant_id, payload)
                offered_amount = self._decimal(payload, "offered_amount")
                currency_code = (self._text(payload, "currency_code", "KRW", upper=True) or "KRW")[:3]

                tender_row = await conn.fetchrow(
                    f"""
                    insert into {self._table("carrier_tenders")} (
                        tenant_id, company_id, shipment_id, carrier_id,
                        tender_round, tender_status, offered_amount,
                        currency_code, sent_at, accepted_at, notes, metadata,
                        created_channel_code, created_from_ip,
                        created_from_client, updated_channel_code,
                        updated_from_ip, updated_from_client
                    )
                    values (
                        $1, $2, $3, $4, 1, 'ACCEPTED', $5::numeric,
                        $6, now(), now(), $7, $8::jsonb, $9, $10, $11,
                        $9, $10, $11
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
                        metadata = {self._table("carrier_tenders")}.metadata || excluded.metadata,
                        version_no = {self._table("carrier_tenders")}.version_no + 1,
                        updated_at = now(),
                        updated_channel_code = excluded.updated_channel_code,
                        updated_from_ip = excluded.updated_from_ip,
                        updated_from_client = excluded.updated_from_client
                    returning tender_id
                    """,
                    tenant_id,
                    company_id,
                    shipment_id,
                    carrier_id,
                    offered_amount,
                    currency_code,
                    self._text(payload, "notes"),
                    dispatch_metadata,
                    channel,
                    ip,
                    client,
                )

                existing_response = await conn.fetchrow(
                    f"""
                    select tender_response_id
                    from {self._table("carrier_tender_responses")}
                    where tender_id = $1
                      and deleted_at is null
                    order by tender_response_id desc
                    limit 1
                    """,
                    tender_row["tender_id"],
                )
                if existing_response:
                    response_row = await conn.fetchrow(
                        f"""
                        update {self._table("carrier_tender_responses")}
                        set tenant_id = $2,
                            company_id = $3,
                            response_status = 'ACCEPTED',
                            response_amount = $4::numeric,
                            currency_code = $5,
                            rejection_reason = null,
                            responded_by = $6,
                            responded_at = now(),
                            metadata = metadata || $7::jsonb,
                            updated_at = now(),
                            updated_channel_code = $8,
                            updated_from_ip = $9,
                            updated_from_client = $10
                        where tender_response_id = $1
                        returning tender_response_id
                        """,
                        existing_response["tender_response_id"],
                        tenant_id,
                        company_id,
                        offered_amount,
                        currency_code,
                        self._text(payload, "manager_name") or self._text(payload, "manager_email"),
                        dispatch_metadata,
                        channel,
                        ip,
                        client,
                    )
                else:
                    response_row = await conn.fetchrow(
                        f"""
                        insert into {self._table("carrier_tender_responses")} (
                            tenant_id, company_id, tender_id, response_status,
                            response_amount, currency_code, responded_by,
                            responded_at, metadata, created_channel_code,
                            created_from_ip, created_from_client,
                            updated_channel_code, updated_from_ip,
                            updated_from_client
                        )
                        values (
                            $1, $2, $3, 'ACCEPTED', $4::numeric, $5, $6,
                            now(), $7::jsonb, $8, $9, $10, $8, $9, $10
                        )
                        returning tender_response_id
                        """,
                        tenant_id,
                        company_id,
                        tender_row["tender_id"],
                        offered_amount,
                        currency_code,
                        self._text(payload, "manager_name") or self._text(payload, "manager_email"),
                        dispatch_metadata,
                        channel,
                        ip,
                        client,
                    )

                await conn.execute(
                    f"""
                    update {self._table("carrier_tender_responses")}
                    set deleted_at = now(),
                        deleted_reason = 'superseded by latest carrier dispatch confirmation',
                        deleted_channel_code = $3,
                        deleted_from_ip = $4,
                        deleted_from_client = $5
                    where tender_id = $1
                      and deleted_at is null
                      and tender_response_id <> $2
                    """,
                    tender_row["tender_id"],
                    response_row["tender_response_id"],
                    channel,
                    ip,
                    client,
                )

                dispatch_row = await conn.fetchrow(
                    f"""
                    update {self._table("dispatches")}
                    set company_id = $2,
                        dispatcher_user_id = $3,
                        driver_id = $4,
                        vehicle_id = $5,
                        dispatch_status = 'ACCEPTED',
                        dispatched_at = coalesce(dispatched_at, now()),
                        accepted_at = now(),
                        instructions = $6,
                        metadata = metadata || $7::jsonb,
                        version_no = version_no + 1,
                        updated_at = now(),
                        updated_channel_code = $8,
                        updated_from_ip = $9,
                        updated_from_client = $10
                    where shipment_id = $1
                      and deleted_at is null
                      and dispatch_status <> 'CANCELLED'
                    returning dispatch_id
                    """,
                    shipment_id,
                    company_id,
                    dispatcher_user_id,
                    driver_id,
                    vehicle_id,
                    self._text(payload, "instructions"),
                    dispatch_metadata,
                    channel,
                    ip,
                    client,
                )
                if dispatch_row is None:
                    dispatch_row = await conn.fetchrow(
                        f"""
                        insert into {self._table("dispatches")} (
                            tenant_id, company_id, shipment_id,
                            dispatcher_user_id, driver_id, vehicle_id,
                            dispatch_status, dispatched_at, accepted_at,
                            instructions, metadata, created_channel_code,
                            created_from_ip, created_from_client,
                            updated_channel_code, updated_from_ip,
                            updated_from_client
                        )
                        values (
                            $1, $2, $3, $4, $5, $6, 'ACCEPTED',
                            now(), now(), $7, $8::jsonb, $9, $10, $11,
                            $9, $10, $11
                        )
                        returning dispatch_id
                        """,
                        tenant_id,
                        company_id,
                        shipment_id,
                        dispatcher_user_id,
                        driver_id,
                        vehicle_id,
                        self._text(payload, "instructions"),
                        dispatch_metadata,
                        channel,
                        ip,
                        client,
                    )

                await conn.execute(
                    f"""
                    update {self._table("shipments")}
                    set carrier_id = $2,
                        vehicle_id = $3,
                        driver_id = $4,
                        shipment_status = 'DISPATCHED',
                        tender_status = 'ACCEPTED',
                        metadata = metadata || $5::jsonb,
                        version_no = version_no + 1,
                        updated_at = now(),
                        updated_channel_code = $6,
                        updated_from_ip = $7,
                        updated_from_client = $8
                    where shipment_id = $1
                    """,
                    shipment_id,
                    carrier_id,
                    vehicle_id,
                    driver_id,
                    dispatch_metadata,
                    channel,
                    ip,
                    client,
                )

                event_payload = {
                    "source": "ktms_carrier_portal",
                    "plan_no": self._text(payload, "plan_no"),
                    "carrier_name": self._text(payload, "carrier_name"),
                    "manager_name": self._text(payload, "manager_name"),
                    "manager_email": self._text(payload, "manager_email"),
                    "vehicle_no": self._text(payload, "vehicle_no"),
                    "driver_name": self._text(payload, "driver_name"),
                    "dispatch_id": dispatch_row["dispatch_id"],
                    "tender_id": tender_row["tender_id"],
                    "tender_response_id": response_row["tender_response_id"],
                }
                tracking_row = await conn.fetchrow(
                    f"""
                    insert into {self._table("tracking_events")} (
                        tenant_id, company_id, shipment_id, event_type,
                        event_status, event_time, source_type, source_system,
                        latitude, longitude, location_text, notes, payload,
                        created_channel_code, created_from_ip,
                        created_from_client, updated_channel_code,
                        updated_from_ip, updated_from_client
                    )
                    values (
                        $1, $2, $3, 'CARRIER_DISPATCH_CONFIRMED',
                        'RECORDED', now(), 'MOBILE', 'KTMS_CARRIER',
                        $4::numeric, $5::numeric, $6, $7, $8::jsonb,
                        $9, $10, $11, $9, $10, $11
                    )
                    returning tracking_event_id
                    """,
                    tenant_id,
                    company_id,
                    shipment_id,
                    latitude,
                    longitude,
                    self._text(payload, "location_text"),
                    "운송사 담당자 배차 확정",
                    json.dumps(event_payload, ensure_ascii=False),
                    channel,
                    ip,
                    client,
                )

            return {
                "saved": True,
                "shipment_id": shipment_id,
                "carrier_id": carrier_id,
                "vehicle_id": vehicle_id,
                "driver_id": driver_id,
                "dispatch_id": dispatch_row["dispatch_id"],
                "tender_id": tender_row["tender_id"],
                "tender_response_id": response_row["tender_response_id"],
                "tracking_event_id": tracking_row["tracking_event_id"],
            }
        finally:
            await conn.close()

    async def _save_driver(self, payload, scope):
        conn = await self._connect()
        try:
            tenant_id, company_id = await self._context(conn, payload)
            channel, ip, client = self._source(scope)
            row = await conn.fetchrow(
                f"""
                insert into {self._table("drivers")} (
                    tenant_id, carrier_id, driver_code, driver_name, phone, email,
                    license_no, license_type, license_expiry_date, hire_date,
                    status, is_active, metadata, created_channel_code,
                    created_from_ip, created_from_client, updated_channel_code,
                    updated_from_ip, updated_from_client
                )
                values (
                    $1, $2, $3, $4, $5, $6, $7, $8, $9::text::date,
                    $10::text::date,
                    $11, $12, $13::jsonb, $14, $15, $16, $14, $15, $16
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
                """,
                tenant_id,
                await self._find_carrier_id(conn, tenant_id, company_id, payload.get("carrier_name")),
                self._text(payload, "driver_code", upper=True),
                self._text(payload, "driver_name"),
                self._text(payload, "phone"),
                self._text(payload, "email"),
                self._text(payload, "license_no"),
                self._text(payload, "license_type", upper=True),
                self._text(payload, "license_expiry_date"),
                self._text(payload, "hire_date"),
                self._driver_status(payload),
                bool(payload.get("is_active", True)),
                self._jsonb(payload, carrier_name=payload.get("carrier_name")),
                channel,
                ip,
                client,
            )
            return {"saved": True, "table": "drivers", "id": row["driver_id"], "code": row["driver_code"]}
        finally:
            await conn.close()

    async def _find_item_category_id(self, conn, tenant_id, category_code, category_name):
        code = self._text({"value": category_code}, "value", upper=True)
        name = self._text({"value": category_name}, "value")
        if not code and not name:
            return None
        row = await conn.fetchrow(
            f"""
            select item_category_id
            from {self._table("item_categories")}
            where tenant_id = $1
              and deleted_at is null
              and (
                  ($2::text is not null and category_code = $2)
                  or ($3::text is not null and category_name = $3)
              )
            order by item_category_id
            limit 1
            """,
            tenant_id,
            code,
            name,
        )
        return row["item_category_id"] if row else None

    async def _find_item_uom_id(self, conn, tenant_id, uom_code, uom_name):
        code = self._text({"value": uom_code}, "value", upper=True)
        name = self._text({"value": uom_name}, "value")
        if not code and not name:
            return None
        row = await conn.fetchrow(
            f"""
            select uom_id
            from {self._table("item_uoms")}
            where tenant_id = $1
              and deleted_at is null
              and (
                  ($2::text is not null and uom_code = $2)
                  or ($3::text is not null and uom_name = $3)
              )
            order by uom_id
            limit 1
            """,
            tenant_id,
            code,
            name,
        )
        return row["uom_id"] if row else None

    def _item_status(self, payload):
        if not bool(payload.get("is_active", True)):
            return "INACTIVE"
        status = self._text(payload, "status", "ACTIVE", upper=True)
        if status not in {"ACTIVE", "INACTIVE"}:
            return "ACTIVE"
        return status

    async def _save_item(self, payload, scope):
        conn = await self._connect()
        try:
            tenant_id = await self._tenant_context(conn, payload)
            channel, ip, client = self._source(scope)
            row = await conn.fetchrow(
                f"""
                insert into {self._table("items")} (
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
                    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
                    $11, $12, $13, $14::numeric, $15::numeric, $16::numeric,
                    $17::numeric, $18::numeric, $19::numeric, $20::numeric,
                    $21, $22, $23::jsonb, $24, $25, $26, $24, $25, $26
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
                """,
                tenant_id,
                await self._find_item_category_id(
                    conn,
                    tenant_id,
                    payload.get("category_code"),
                    payload.get("category_name"),
                ),
                await self._find_item_uom_id(
                    conn,
                    tenant_id,
                    payload.get("base_uom_code"),
                    payload.get("base_uom_name"),
                ),
                self._text(payload, "item_code", upper=True),
                self._text(payload, "item_name"),
                self._text(payload, "item_description"),
                self._text(payload, "sku"),
                self._text(payload, "barcode"),
                self._text(payload, "nmfc_code"),
                self._text(payload, "hs_code"),
                bool(payload.get("is_hazardous", False)),
                self._text(payload, "hazardous_class"),
                bool(payload.get("temperature_controlled", False)),
                self._decimal(payload, "min_temperature_c"),
                self._decimal(payload, "max_temperature_c"),
                self._decimal(payload, "unit_weight_kg"),
                self._decimal(payload, "unit_volume_cbm"),
                self._decimal(payload, "length_cm"),
                self._decimal(payload, "width_cm"),
                self._decimal(payload, "height_cm"),
                self._item_status(payload),
                bool(payload.get("is_active", True)),
                self._jsonb(
                    payload,
                    category_code=payload.get("category_code"),
                    category_name=payload.get("category_name"),
                    base_uom_code=payload.get("base_uom_code"),
                    base_uom_name=payload.get("base_uom_name"),
                ),
                channel,
                ip,
                client,
            )
            return {"saved": True, "table": "items", "id": row["item_id"], "code": row["item_code"]}
        finally:
            await conn.close()

    def _slug_code(self, prefix, value, fallback=None, limit=80):
        raw = self._text({"value": value}, "value", upper=True) or self._text(
            {"value": fallback},
            "value",
            upper=True,
        ) or prefix
        slug = re.sub(r"[^A-Z0-9]+", "_", raw).strip("_") or prefix
        if not slug.startswith(prefix):
            slug = f"{prefix}_{slug}"
        return slug[:limit]

    def _rate_agreement_type(self, payload):
        agreement_type = self._text(payload, "agreement_type", "SELL", upper=True)
        return agreement_type if agreement_type in {"BUY", "SELL"} else "SELL"

    def _rate_partner_type(self, payload):
        partner_type = self._text(payload, "partner_type", upper=True)
        if partner_type:
            return partner_type
        return "CARRIER" if self._rate_agreement_type(payload) == "BUY" else "CUSTOMER"

    def _rate_status(self, payload):
        status = self._text(payload, "status", "DRAFT", upper=True)
        if not bool(payload.get("is_active", True)) and status == "ACTIVE":
            return "EXPIRED"
        if status not in {"DRAFT", "ACTIVE", "EXPIRED", "CANCELLED"}:
            return "DRAFT"
        return status

    def _charge_category(self, payload):
        category = self._text(payload, "charge_category", "BASE", upper=True)
        if category not in {"BASE", "FUEL", "ACCESSORIAL", "TAX", "DISCOUNT", "PENALTY"}:
            return "BASE"
        return category

    def _calculation_method(self, payload):
        method = self._text(payload, "calculation_method", "FLAT", upper=True)
        allowed = {"FLAT", "PER_KM", "PER_KG", "PER_CBM", "PER_PALLET", "PER_STOP", "PERCENT"}
        return method if method in allowed else "FLAT"

    async def _ensure_rate_partner_id(self, conn, tenant_id, company_id, payload, channel, ip, client):
        partner_type = self._rate_partner_type(payload)
        prefix = "CAR" if partner_type == "CARRIER" else "CUS"
        partner_code = self._text(payload, "partner_code", upper=True) or self._slug_code(
            prefix,
            payload.get("partner_name"),
            payload.get("agreement_no"),
            80,
        )
        partner_name = self._text(payload, "partner_name") or partner_code
        row = await conn.fetchrow(
            f"""
            insert into {self._table("business_partners")} (
                tenant_id, company_id, partner_code, partner_name,
                partner_short_name, partner_type, status, is_active, metadata,
                created_channel_code, created_from_ip, created_from_client,
                updated_channel_code, updated_from_ip, updated_from_client
            )
            values (
                $1, $2, $3, $4, $4, $5, 'ACTIVE', true, $6::jsonb,
                $7, $8, $9, $7, $8, $9
            )
            on conflict (tenant_id, company_id, partner_code)
            where deleted_at is null
            do update set
                partner_name = excluded.partner_name,
                partner_short_name = excluded.partner_short_name,
                partner_type = excluded.partner_type,
                is_active = true,
                metadata = {self._table("business_partners")}.metadata || excluded.metadata,
                updated_at = now(),
                updated_channel_code = excluded.updated_channel_code,
                updated_from_ip = excluded.updated_from_ip,
                updated_from_client = excluded.updated_from_client
            returning partner_id
            """,
            tenant_id,
            company_id,
            partner_code,
            partner_name,
            partner_type,
            json.dumps(
                {
                    "source": "ktms_rate_master",
                    "created_for_agreement_no": self._text(payload, "agreement_no", upper=True),
                },
                ensure_ascii=False,
            ),
            channel,
            ip,
            client,
        )
        return row["partner_id"]

    async def _ensure_charge_code_id(self, conn, tenant_id, payload, channel, ip, client):
        charge_code = self._text(payload, "charge_code", "BASE_FREIGHT", upper=True)
        charge_name = self._text(payload, "charge_name", "기본 운임")
        row = await conn.fetchrow(
            f"""
            insert into {self._table("charge_codes")} (
                tenant_id, charge_code, charge_name, charge_category, taxable,
                is_active, metadata, created_channel_code, created_from_ip,
                created_from_client, updated_channel_code, updated_from_ip,
                updated_from_client
            )
            values (
                $1, $2, $3, $4, $5, true, $6::jsonb,
                $7, $8, $9, $7, $8, $9
            )
            on conflict (tenant_id, charge_code)
            where deleted_at is null
            do update set
                charge_name = excluded.charge_name,
                charge_category = excluded.charge_category,
                taxable = excluded.taxable,
                is_active = true,
                metadata = {self._table("charge_codes")}.metadata || excluded.metadata,
                updated_at = now(),
                updated_channel_code = excluded.updated_channel_code,
                updated_from_ip = excluded.updated_from_ip,
                updated_from_client = excluded.updated_from_client
            returning charge_code_id
            """,
            tenant_id,
            charge_code,
            charge_name,
            self._charge_category(payload),
            bool(payload.get("tax_included", True)),
            json.dumps({"source": "ktms_rate_master"}, ensure_ascii=False),
            channel,
            ip,
            client,
        )
        return row["charge_code_id"]

    async def _find_rate_lane_id(self, conn, rate_agreement_id, lane_code):
        code = self._text({"value": lane_code}, "value", upper=True)
        if not code:
            return None
        row = await conn.fetchrow(
            f"""
            select rate_agreement_lane_id
            from {self._table("rate_agreement_lanes")}
            where rate_agreement_id = $1
              and deleted_at is null
              and metadata->>'lane_code' = $2
            order by rate_agreement_lane_id
            limit 1
            """,
            rate_agreement_id,
            code,
        )
        return row["rate_agreement_lane_id"] if row else None

    async def _save_rate_lane(self, conn, tenant_id, rate_agreement_id, payload, channel, ip, client):
        lane_code = self._text(payload, "lane_code", "DEFAULT", upper=True)
        lane_id = await self._find_rate_lane_id(conn, rate_agreement_id, lane_code)
        metadata = json.dumps(
            {
                "source": "ktms_rate_master",
                "lane_code": lane_code,
                "origin_name": self._text(payload, "origin_name"),
                "destination_name": self._text(payload, "destination_name"),
                "mode_code": self._text(payload, "mode_code", upper=True),
                "mode_name": self._text(payload, "mode_name"),
                "service_level_code": self._text(payload, "service_level_code", upper=True),
                "service_level_name": self._text(payload, "service_level_name"),
                "equipment_code": self._text(payload, "equipment_code", upper=True),
                "equipment_name": self._text(payload, "equipment_name"),
                "toll_included": bool(payload.get("toll_included", True)),
            },
            ensure_ascii=False,
        )
        values = (
            tenant_id,
            rate_agreement_id,
            self._decimal(payload, "min_charge_amount"),
            self._decimal(payload, "base_rate_amount"),
            payload.get("transit_hours"),
            self._text(payload, "effective_from"),
            self._text(payload, "effective_to"),
            "ACTIVE" if bool(payload.get("is_active", True)) else "INACTIVE",
            bool(payload.get("is_active", True)),
            metadata,
            channel,
            ip,
            client,
        )
        if lane_id:
            row = await conn.fetchrow(
                f"""
                update {self._table("rate_agreement_lanes")}
                set min_charge_amount = $3,
                    base_rate_amount = $4,
                    transit_hours = $5,
                    effective_from = $6::text::date,
                    effective_to = $7::text::date,
                    status = $8,
                    is_active = $9,
                    metadata = $10::jsonb,
                    updated_at = now(),
                    updated_channel_code = $11,
                    updated_from_ip = $12,
                    updated_from_client = $13
                where rate_agreement_lane_id = $14
                returning rate_agreement_lane_id
                """,
                *values,
                lane_id,
            )
        else:
            row = await conn.fetchrow(
                f"""
                insert into {self._table("rate_agreement_lanes")} (
                    tenant_id, rate_agreement_id, min_charge_amount,
                    base_rate_amount, transit_hours, effective_from, effective_to,
                    status, is_active, metadata, created_channel_code,
                    created_from_ip, created_from_client, updated_channel_code,
                    updated_from_ip, updated_from_client
                )
                values (
                    $1, $2, $3, $4, $5, $6::text::date, $7::text::date, $8, $9,
                    $10::jsonb, $11, $12, $13, $11, $12, $13
                )
                returning rate_agreement_lane_id
                """,
                *values,
            )
        return row["rate_agreement_lane_id"]

    async def _save_rate_charge_rule(
        self,
        conn,
        tenant_id,
        rate_agreement_lane_id,
        charge_code_id,
        payload,
        channel,
        ip,
        client,
    ):
        method = self._calculation_method(payload)
        existing = await conn.fetchrow(
            f"""
            select rate_charge_rule_id
            from {self._table("rate_charge_rules")}
            where tenant_id = $1
              and rate_agreement_lane_id = $2
              and charge_code_id = $3
              and calculation_method = $4
              and deleted_at is null
            order by rate_charge_rule_id
            limit 1
            """,
            tenant_id,
            rate_agreement_lane_id,
            charge_code_id,
            method,
        )
        rate_amount = self._decimal(payload, "rate_amount") or self._decimal(payload, "base_rate_amount") or Decimal("0")
        metadata = json.dumps(
            {
                "source": "ktms_rate_master",
                "charge_code": self._text(payload, "charge_code", upper=True),
                "charge_name": self._text(payload, "charge_name"),
                "tax_included": bool(payload.get("tax_included", True)),
            },
            ensure_ascii=False,
        )
        values = (
            tenant_id,
            rate_agreement_lane_id,
            charge_code_id,
            method,
            self._text(payload, "unit_code", upper=True),
            rate_amount,
            self._decimal(payload, "minimum_amount"),
            self._decimal(payload, "maximum_amount"),
            bool(payload.get("is_active", True)),
            metadata,
            channel,
            ip,
            client,
        )
        if existing:
            row = await conn.fetchrow(
                f"""
                update {self._table("rate_charge_rules")}
                set unit_code = $5,
                    rate_amount = $6,
                    minimum_amount = $7,
                    maximum_amount = $8,
                    is_active = $9,
                    metadata = $10::jsonb,
                    updated_at = now(),
                    updated_channel_code = $11,
                    updated_from_ip = $12,
                    updated_from_client = $13
                where rate_charge_rule_id = $14
                returning rate_charge_rule_id
                """,
                *values,
                existing["rate_charge_rule_id"],
            )
        else:
            row = await conn.fetchrow(
                f"""
                insert into {self._table("rate_charge_rules")} (
                    tenant_id, rate_agreement_lane_id, charge_code_id,
                    calculation_method, unit_code, rate_amount, minimum_amount,
                    maximum_amount, is_active, metadata, created_channel_code,
                    created_from_ip, created_from_client, updated_channel_code,
                    updated_from_ip, updated_from_client
                )
                values (
                    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10::jsonb,
                    $11, $12, $13, $11, $12, $13
                )
                returning rate_charge_rule_id
                """,
                *values,
            )
        return row["rate_charge_rule_id"]

    async def _save_fuel_rule(self, conn, tenant_id, rate_agreement_id, payload, channel, ip, client):
        has_rule = (
            bool(payload.get("fuel_surcharge_enabled", False))
            or self._text(payload, "fuel_index_name") is not None
            or self._decimal(payload, "surcharge_percent") is not None
            or self._decimal(payload, "surcharge_amount") is not None
        )
        if not has_rule:
            return None
        agreement_no = self._text(payload, "agreement_no", "RATE", upper=True)
        rule_code = self._text(payload, "fuel_rule_code", upper=True) or self._slug_code(
            "FUEL",
            f"{agreement_no}_FUEL",
            limit=80,
        )
        rule_name = self._text(payload, "fuel_rule_name") or f"{self._text(payload, 'agreement_name')} 유류할증"
        row = await conn.fetchrow(
            f"""
            insert into {self._table("fuel_surcharge_rules")} (
                tenant_id, rate_agreement_id, rule_code, rule_name,
                fuel_index_name, baseline_price, surcharge_percent,
                surcharge_amount, effective_from, effective_to, is_active,
                metadata, created_channel_code, created_from_ip,
                created_from_client, updated_channel_code, updated_from_ip,
                updated_from_client
            )
            values (
                $1, $2, $3, $4, $5, $6, $7, $8, $9::text::date, $10::text::date,
                $11, $12::jsonb, $13, $14, $15, $13, $14, $15
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
            """,
            tenant_id,
            rate_agreement_id,
            rule_code,
            rule_name,
            self._text(payload, "fuel_index_name"),
            self._decimal(payload, "baseline_price"),
            self._decimal(payload, "surcharge_percent"),
            self._decimal(payload, "surcharge_amount"),
            self._text(payload, "effective_from"),
            self._text(payload, "effective_to"),
            bool(payload.get("is_active", True)),
            json.dumps({"source": "ktms_rate_master"}, ensure_ascii=False),
            channel,
            ip,
            client,
        )
        return row["fuel_surcharge_rule_id"]

    async def _save_rate_agreement(self, payload, scope):
        conn = await self._connect()
        try:
            tenant_id, company_id = await self._context(conn, payload)
            channel, ip, client = self._source(scope)
            partner_id = await self._ensure_rate_partner_id(
                conn,
                tenant_id,
                company_id,
                payload,
                channel,
                ip,
                client,
            )
            row = await conn.fetchrow(
                f"""
                insert into {self._table("rate_agreements")} (
                    tenant_id, agreement_no, agreement_name, agreement_type,
                    partner_id, currency_code, effective_from, effective_to,
                    status, is_active, metadata, created_channel_code,
                    created_from_ip, created_from_client, updated_channel_code,
                    updated_from_ip, updated_from_client
                )
                values (
                    $1, $2, $3, $4, $5, $6, $7::text::date, $8::text::date, $9, $10,
                    $11::jsonb, $12, $13, $14, $12, $13, $14
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
                """,
                tenant_id,
                self._text(payload, "agreement_no", upper=True),
                self._text(payload, "agreement_name"),
                self._rate_agreement_type(payload),
                partner_id,
                (self._text(payload, "currency_code", "KRW", upper=True) or "KRW")[:3],
                self._text(payload, "effective_from"),
                self._text(payload, "effective_to"),
                self._rate_status(payload),
                bool(payload.get("is_active", True)),
                self._jsonb(
                    payload,
                    partner_name=payload.get("partner_name"),
                    partner_type=self._rate_partner_type(payload),
                    contract_owner=payload.get("contract_owner"),
                    payment_terms=payload.get("payment_terms"),
                    auto_rating=payload.get("auto_rating"),
                    toll_included=payload.get("toll_included"),
                    tax_included=payload.get("tax_included"),
                    memo=payload.get("memo"),
                ),
                channel,
                ip,
                client,
            )
            rate_agreement_id = row["rate_agreement_id"]
            lane_id = await self._save_rate_lane(
                conn,
                tenant_id,
                rate_agreement_id,
                payload,
                channel,
                ip,
                client,
            )
            charge_code_id = await self._ensure_charge_code_id(
                conn,
                tenant_id,
                payload,
                channel,
                ip,
                client,
            )
            charge_rule_id = await self._save_rate_charge_rule(
                conn,
                tenant_id,
                lane_id,
                charge_code_id,
                payload,
                channel,
                ip,
                client,
            )
            fuel_rule_id = await self._save_fuel_rule(
                conn,
                tenant_id,
                rate_agreement_id,
                payload,
                channel,
                ip,
                client,
            )
            return {
                "saved": True,
                "table": "rate_agreements",
                "id": rate_agreement_id,
                "code": row["agreement_no"],
                "lane_id": lane_id,
                "charge_rule_id": charge_rule_id,
                "fuel_rule_id": fuel_rule_id,
            }
        finally:
            await conn.close()

    def _user_status(self, payload):
        if not bool(payload.get("is_active", True)):
            return "INACTIVE"
        status = self._text(payload, "status", "ACTIVE", upper=True)
        if status not in {"ACTIVE", "LOCKED", "INACTIVE", "INVITED"}:
            return "ACTIVE"
        return status

    def _login_id(self, payload, key):
        value = self._text(payload, key)
        return value.lower() if value else None

    def _permission_parts(self, permission_code):
        code = self._text({"value": permission_code}, "value", "SYSTEM.READ", upper=True)
        if "." in code:
            module_code, action_code = code.split(".", 1)
        else:
            module_code, action_code = code, "ACCESS"
        return module_code[:60], action_code[:60]

    def _permission_name(self, permission_code):
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

    async def _ensure_permission_id(self, conn, permission_code, channel, ip, client):
        code = self._text({"value": permission_code}, "value", "SYSTEM.READ", upper=True)
        module_code, action_code = self._permission_parts(code)
        row = await conn.fetchrow(
            f"""
            insert into {self._table("permissions")} (
                permission_code, module_code, action_code, permission_name,
                description, is_active, created_channel_code, created_from_ip,
                created_from_client, updated_channel_code, updated_from_ip,
                updated_from_client
            )
            values ($1, $2, $3, $4, $5, true, $6, $7, $8, $6, $7, $8)
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
            """,
            code,
            module_code,
            action_code,
            self._permission_name(code),
            f"KTMS {module_code} {action_code} permission",
            channel,
            ip,
            client,
        )
        return row["permission_id"]

    async def _ensure_user_role_id(self, conn, tenant_id, payload, channel, ip, client):
        role_code = self._text(payload, "role_code", upper=True) or self._slug_code(
            "ROLE",
            payload.get("role_name"),
            payload.get("login_id"),
            80,
        )
        role_name = self._text(payload, "role_name") or role_code
        metadata = self._jsonb(
            payload,
            role_profile=payload.get("role_profile"),
            data_scope=payload.get("data_scope"),
            permissions_count=len(payload.get("permissions") or []),
        )
        row = await conn.fetchrow(
            f"""
            insert into {self._table("roles")} (
                tenant_id, role_code, role_name, description, is_system,
                is_active, metadata, created_channel_code, created_from_ip,
                created_from_client, updated_channel_code, updated_from_ip,
                updated_from_client
            )
            values ($1, $2, $3, $4, false, true, $5::jsonb, $6, $7, $8, $6, $7, $8)
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
            """,
            tenant_id,
            role_code,
            role_name,
            self._text(payload, "role_description"),
            metadata,
            channel,
            ip,
            client,
        )
        return row["role_id"]

    async def _sync_role_permissions(self, conn, role_id, permission_codes, channel, ip, client):
        cleaned_codes = sorted(
            {
                code
                for code in (
                    self._text({"value": permission_code}, "value", upper=True)
                    for permission_code in (permission_codes or [])
                )
                if code
            }
        )
        permission_ids = []
        for permission_code in cleaned_codes:
            permission_ids.append(
                await self._ensure_permission_id(
                    conn,
                    permission_code,
                    channel,
                    ip,
                    client,
                )
            )

        if permission_ids:
            await conn.execute(
                f"""
                update {self._table("role_permissions")}
                set is_active = false,
                    updated_at = now(),
                    updated_channel_code = $1,
                    updated_from_ip = $2,
                    updated_from_client = $3
                where role_id = $4
                  and not (permission_id = any($5::bigint[]))
                """,
                channel,
                ip,
                client,
                role_id,
                permission_ids,
            )
        else:
            await conn.execute(
                f"""
                update {self._table("role_permissions")}
                set is_active = false,
                    updated_at = now(),
                    updated_channel_code = $1,
                    updated_from_ip = $2,
                    updated_from_client = $3
                where role_id = $4
                """,
                channel,
                ip,
                client,
                role_id,
            )

        for permission_id in permission_ids:
            await conn.execute(
                f"""
                insert into {self._table("role_permissions")} (
                    role_id, permission_id, created_channel_code,
                    created_from_ip, created_from_client, updated_channel_code,
                    updated_from_ip, updated_from_client, is_active
                )
                values ($1, $2, $3, $4, $5, $3, $4, $5, true)
                on conflict (role_id, permission_id)
                do update set
                    is_active = true,
                    updated_at = now(),
                    updated_channel_code = excluded.updated_channel_code,
                    updated_from_ip = excluded.updated_from_ip,
                    updated_from_client = excluded.updated_from_client
                """,
                role_id,
                permission_id,
                channel,
                ip,
                client,
            )
        return permission_ids

    async def _assign_user_role(self, conn, user_id, role_id, expires_at, channel, ip, client):
        await conn.execute(
            f"""
            update {self._table("user_roles")}
            set is_active = false,
                updated_at = now(),
                updated_channel_code = $1,
                updated_from_ip = $2,
                updated_from_client = $3
            where user_id = $4
              and role_id <> $5
            """,
            channel,
            ip,
            client,
            user_id,
            role_id,
        )
        await conn.execute(
            f"""
            insert into {self._table("user_roles")} (
                user_id, role_id, expires_at, created_channel_code,
                created_from_ip, created_from_client, updated_channel_code,
                updated_from_ip, updated_from_client, is_active
            )
            values ($1, $2, $3::text::timestamptz, $4, $5, $6, $4, $5, $6, true)
            on conflict (user_id, role_id)
            do update set
                expires_at = excluded.expires_at,
                is_active = true,
                updated_at = now(),
                updated_channel_code = excluded.updated_channel_code,
                updated_from_ip = excluded.updated_from_ip,
                updated_from_client = excluded.updated_from_client
            """,
            user_id,
            role_id,
            self._text({"value": expires_at}, "value"),
            channel,
            ip,
            client,
        )

    async def _save_user_access(self, payload, scope):
        conn = await self._connect()
        try:
            tenant_id, company_id = await self._context(conn, payload)
            channel, ip, client = self._source(scope)
            role_id = await self._ensure_user_role_id(
                conn,
                tenant_id,
                payload,
                channel,
                ip,
                client,
            )
            permission_ids = await self._sync_role_permissions(
                conn,
                role_id,
                payload.get("permissions") or [],
                channel,
                ip,
                client,
            )
            row = await conn.fetchrow(
                f"""
                insert into {self._table("app_users")} (
                    tenant_id, company_id, login_id, email, full_name, phone,
                    mobile, language_code, timezone_name, status, mfa_enabled,
                    is_active, metadata, created_channel_code, created_from_ip,
                    created_from_client, updated_channel_code, updated_from_ip,
                    updated_from_client
                )
                values (
                    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12,
                    $13::jsonb, $14, $15, $16, $14, $15, $16
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
                """,
                tenant_id,
                company_id,
                self._login_id(payload, "login_id"),
                self._login_id(payload, "email"),
                self._text(payload, "full_name"),
                self._text(payload, "phone"),
                self._text(payload, "mobile"),
                self._text(payload, "language_code", "ko"),
                self._text(payload, "timezone_name", "Asia/Seoul"),
                self._user_status(payload),
                bool(payload.get("mfa_enabled", False)),
                bool(payload.get("is_active", True)),
                self._jsonb(
                    payload,
                    auth_provider="FIREBASE",
                    department_name=payload.get("department_name"),
                    business_unit_name=payload.get("business_unit_name"),
                    role_code=payload.get("role_code"),
                    role_name=payload.get("role_name"),
                    role_profile=payload.get("role_profile"),
                    data_scope=payload.get("data_scope"),
                    allow_web=payload.get("allow_web"),
                    allow_mobile=payload.get("allow_mobile"),
                    require_approval=payload.get("require_approval"),
                    memo=payload.get("memo"),
                ),
                channel,
                ip,
                client,
            )
            await self._assign_user_role(
                conn,
                row["user_id"],
                role_id,
                payload.get("expires_at"),
                channel,
                ip,
                client,
            )
            return {
                "saved": True,
                "table": "app_users",
                "id": row["user_id"],
                "code": row["login_id"],
                "role_id": role_id,
                "permission_count": len(permission_ids),
            }
        finally:
            await conn.close()

    async def _save_common_code(self, payload, scope):
        conn = await self._connect()
        try:
            tenant_id = await self._tenant_context(conn, payload)
            channel, ip, client = self._source(scope)
            group = await conn.fetchrow(
                f"""
                insert into {self._table("code_groups")} (
                    tenant_id, group_code, group_name, description, is_system,
                    is_active, metadata, created_channel_code, created_from_ip,
                    created_from_client, updated_channel_code, updated_from_ip,
                    updated_from_client
                )
                values (
                    $1, $2, $3, $4, $5, $6, $7::jsonb,
                    $8, $9, $10, $8, $9, $10
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
                """,
                tenant_id,
                self._text(payload, "group_code", upper=True),
                self._text(payload, "group_name"),
                self._text(payload, "group_description"),
                bool(payload.get("group_is_system", False)),
                bool(payload.get("is_active", True)),
                self._jsonb(
                    payload,
                    applies_to=payload.get("applies_to"),
                    memo=payload.get("memo"),
                ),
                channel,
                ip,
                client,
            )
            row = await conn.fetchrow(
                f"""
                insert into {self._table("codes")} (
                    tenant_id, code_group_id, code, code_name, code_value,
                    sort_order, is_default, is_active, metadata,
                    created_channel_code, created_from_ip, created_from_client,
                    updated_channel_code, updated_from_ip, updated_from_client
                )
                values (
                    $1, $2, $3, $4, $5, $6, $7, $8, $9::jsonb,
                    $10, $11, $12, $10, $11, $12
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
                """,
                tenant_id,
                group["code_group_id"],
                self._text(payload, "code", upper=True),
                self._text(payload, "code_name"),
                self._text(payload, "code_value"),
                int(payload.get("sort_order") or 0),
                bool(payload.get("is_default", False)),
                bool(payload.get("is_active", True)),
                self._jsonb(
                    payload,
                    group_code=self._text(payload, "group_code", upper=True),
                    applies_to=payload.get("applies_to"),
                    memo=payload.get("memo"),
                    color_hex=payload.get("color_hex"),
                    icon_name=payload.get("icon_name"),
                ),
                channel,
                ip,
                client,
            )
            if bool(payload.get("is_default", False)):
                await conn.execute(
                    f"""
                    update {self._table("codes")}
                    set is_default = false,
                        updated_at = now(),
                        updated_channel_code = $1,
                        updated_from_ip = $2,
                        updated_from_client = $3
                    where code_group_id = $4
                      and code_id <> $5
                      and deleted_at is null
                    """,
                    channel,
                    ip,
                    client,
                    group["code_group_id"],
                    row["code_id"],
                )
            return {
                "saved": True,
                "table": "codes",
                "id": row["code_id"],
                "code": row["code"],
                "group_id": group["code_group_id"],
                "group_code": group["group_code"],
            }
        finally:
            await conn.close()

    def _order_slug_code(self, prefix, value, fallback=None):
        raw = self._text({"value": value}, "value", upper=True) or self._text(
            {"value": fallback},
            "value",
            upper=True,
        ) or prefix
        slug = re.sub(r"[^A-Z0-9]+", "_", raw).strip("_") or prefix
        if not slug.startswith(prefix):
            slug = f"{prefix}_{slug}"
        return slug[:80]

    def _order_type(self, payload):
        order_type = self._text(payload, "order_type", "STANDARD", upper=True)
        allowed = {"STANDARD", "RETURN", "TRANSFER", "EXPEDITED", "CONSOLIDATION"}
        return order_type if order_type in allowed else "STANDARD"

    def _order_status(self, payload):
        status = self._text(payload, "order_status", "DRAFT", upper=True)
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
        return status if status in allowed else "DRAFT"

    async def _ensure_order_partner_id(
        self,
        conn,
        tenant_id,
        company_id,
        partner_name,
        partner_type,
        channel,
        ip,
        client,
        partner_code=None,
    ):
        name = self._text({"value": partner_name}, "value") or "미지정 거래처"
        code = self._text({"value": partner_code}, "value", upper=True) or self._order_slug_code(
            "CUS" if partner_type == "CUSTOMER" else partner_type[:3],
            name,
        )
        row = await conn.fetchrow(
            f"""
            insert into {self._table("business_partners")} (
                tenant_id, company_id, partner_code, partner_name,
                partner_short_name, partner_type, status, is_active, metadata,
                created_channel_code, created_from_ip, created_from_client,
                updated_channel_code, updated_from_ip, updated_from_client
            )
            values (
                $1, $2, $3, $4, $4, $5, 'ACTIVE', true, $6::jsonb,
                $7, $8, $9, $7, $8, $9
            )
            on conflict (tenant_id, company_id, partner_code)
            where deleted_at is null
            do update set
                partner_name = excluded.partner_name,
                partner_short_name = excluded.partner_short_name,
                partner_type = excluded.partner_type,
                status = 'ACTIVE',
                is_active = true,
                metadata = {self._table("business_partners")}.metadata || excluded.metadata,
                updated_at = now(),
                updated_channel_code = excluded.updated_channel_code,
                updated_from_ip = excluded.updated_from_ip,
                updated_from_client = excluded.updated_from_client
            returning partner_id
            """,
            tenant_id,
            company_id,
            code,
            name,
            partner_type,
            json.dumps({"source": "ktms_order_registration"}, ensure_ascii=False),
            channel,
            ip,
            client,
        )
        return row["partner_id"]

    async def _ensure_order_mode_id(self, conn, tenant_id, code, name, channel, ip, client):
        mode_code = self._text({"value": code}, "value", upper=True)
        mode_name = self._text({"value": name}, "value") or mode_code
        if not mode_code:
            return None
        row = await conn.fetchrow(
            f"""
            select mode_id
            from {self._table("transport_modes")}
            where tenant_id = $1 and deleted_at is null and mode_code = $2
            order by mode_id
            limit 1
            """,
            tenant_id,
            mode_code,
        )
        if row:
            return row["mode_id"]
        row = await conn.fetchrow(
            f"""
            insert into {self._table("transport_modes")} (
                tenant_id, mode_code, mode_name, is_active, metadata,
                created_channel_code, created_from_ip, created_from_client,
                updated_channel_code, updated_from_ip, updated_from_client
            )
            values ($1, $2, $3, true, $4::jsonb, $5, $6, $7, $5, $6, $7)
            returning mode_id
            """,
            tenant_id,
            mode_code,
            mode_name,
            json.dumps({"source": "ktms_order_registration"}, ensure_ascii=False),
            channel,
            ip,
            client,
        )
        return row["mode_id"]

    async def _ensure_order_service_level_id(self, conn, tenant_id, code, name, channel, ip, client):
        service_code = self._text({"value": code}, "value", upper=True)
        service_name = self._text({"value": name}, "value") or service_code
        if not service_code:
            return None
        row = await conn.fetchrow(
            f"""
            select service_level_id
            from {self._table("service_levels")}
            where tenant_id = $1 and deleted_at is null and service_code = $2
            order by service_level_id
            limit 1
            """,
            tenant_id,
            service_code,
        )
        if row:
            return row["service_level_id"]
        row = await conn.fetchrow(
            f"""
            insert into {self._table("service_levels")} (
                tenant_id, service_code, service_name, promised_transit_hours,
                priority_rank, is_active, metadata, created_channel_code,
                created_from_ip, created_from_client, updated_channel_code,
                updated_from_ip, updated_from_client
            )
            values ($1, $2, $3, null, 100, true, $4::jsonb, $5, $6, $7, $5, $6, $7)
            returning service_level_id
            """,
            tenant_id,
            service_code,
            service_name,
            json.dumps({"source": "ktms_order_registration"}, ensure_ascii=False),
            channel,
            ip,
            client,
        )
        return row["service_level_id"]

    async def _ensure_order_uom_id(self, conn, tenant_id, uom_code, channel, ip, client):
        code = self._text({"value": uom_code}, "value", "EA", upper=True)
        row = await conn.fetchrow(
            f"""
            select uom_id
            from {self._table("item_uoms")}
            where tenant_id = $1 and deleted_at is null and uom_code = $2
            order by uom_id
            limit 1
            """,
            tenant_id,
            code,
        )
        if row:
            return row["uom_id"]
        row = await conn.fetchrow(
            f"""
            insert into {self._table("item_uoms")} (
                tenant_id, uom_code, uom_name, uom_type, decimal_places,
                is_active, created_channel_code, created_from_ip,
                created_from_client, updated_channel_code, updated_from_ip,
                updated_from_client
            )
            values ($1, $2, $2, 'QUANTITY', 0, true, $3, $4, $5, $3, $4, $5)
            returning uom_id
            """,
            tenant_id,
            code,
            channel,
            ip,
            client,
        )
        return row["uom_id"]

    async def _ensure_order_charge_code_id(self, conn, tenant_id, channel, ip, client):
        row = await conn.fetchrow(
            f"""
            select charge_code_id
            from {self._table("charge_codes")}
            where tenant_id = $1 and deleted_at is null and charge_code = 'BASE_FREIGHT'
            order by charge_code_id
            limit 1
            """,
            tenant_id,
        )
        if row:
            return row["charge_code_id"]
        row = await conn.fetchrow(
            f"""
            insert into {self._table("charge_codes")} (
                tenant_id, charge_code, charge_name, charge_category, taxable,
                is_active, metadata, created_channel_code, created_from_ip,
                created_from_client, updated_channel_code, updated_from_ip,
                updated_from_client
            )
            values (
                $1, 'BASE_FREIGHT', '기본 운임', 'BASE', true, true,
                $2::jsonb, $3, $4, $5, $3, $4, $5
            )
            returning charge_code_id
            """,
            tenant_id,
            json.dumps({"source": "ktms_order_registration"}, ensure_ascii=False),
            channel,
            ip,
            client,
        )
        return row["charge_code_id"]

    async def _save_transport_order(self, payload, scope):
        conn = await self._connect()
        try:
            tenant_id, company_id = await self._context(conn, payload)
            channel, ip, client = self._source(scope)
            customer_id = await self._ensure_order_partner_id(
                conn,
                tenant_id,
                company_id,
                payload.get("customer_name"),
                "CUSTOMER",
                channel,
                ip,
                client,
                partner_code=payload.get("customer_code"),
            )
            bill_to_id = await self._ensure_order_partner_id(
                conn,
                tenant_id,
                company_id,
                payload.get("bill_to_name") or payload.get("customer_name"),
                "CUSTOMER",
                channel,
                ip,
                client,
            )
            mode_id = await self._ensure_order_mode_id(
                conn,
                tenant_id,
                payload.get("transport_mode_code"),
                payload.get("transport_mode_name"),
                channel,
                ip,
                client,
            )
            service_level_id = await self._ensure_order_service_level_id(
                conn,
                tenant_id,
                payload.get("service_level_code"),
                payload.get("service_level_name"),
                channel,
                ip,
                client,
            )
            currency_code = (self._text(payload, "currency_code", "KRW", upper=True) or "KRW")[:3]
            metadata = self._jsonb(
                payload,
                shipper_name=payload.get("shipper_name"),
                bill_to_name=payload.get("bill_to_name"),
                pickup_name=payload.get("pickup_name"),
                pickup_address=payload.get("pickup_address"),
                delivery_name=payload.get("delivery_name"),
                delivery_address=payload.get("delivery_address"),
                transport_mode_code=payload.get("transport_mode_code"),
                transport_mode_name=payload.get("transport_mode_name"),
                service_level_code=payload.get("service_level_code"),
                service_level_name=payload.get("service_level_name"),
                appointment_required=payload.get("appointment_required"),
                charge_amount=str(self._decimal(payload, "charge_amount") or Decimal("0")),
            )
            row = await conn.fetchrow(
                f"""
                insert into {self._table("transport_orders")} (
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
                    $1, $2, $3, $4, $5, $6, $7, $8, $9, $10,
                    $11::text::timestamptz, $12::text::timestamptz,
                    $13::text::timestamptz, $14::text::timestamptz,
                    $15::numeric, $16, $17::numeric, $18::numeric,
                    $19::numeric, $20, $21, $22::numeric, $23::numeric,
                    $24, $25, $26, $27, $28::jsonb, $29, $30, $31, $29, $30, $31
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
                    version_no = {self._table("transport_orders")}.version_no + 1,
                    updated_at = now(),
                    updated_channel_code = excluded.updated_channel_code,
                    updated_from_ip = excluded.updated_from_ip,
                    updated_from_client = excluded.updated_from_client
                returning order_id, order_no
                """,
                tenant_id,
                company_id,
                self._text(payload, "order_no", upper=True),
                customer_id,
                bill_to_id,
                mode_id,
                service_level_id,
                self._order_type(payload),
                self._order_status(payload),
                self._text(payload, "priority_code", "NORMAL", upper=True),
                self._text(payload, "requested_pickup_start"),
                self._text(payload, "requested_pickup_end"),
                self._text(payload, "requested_delivery_start"),
                self._text(payload, "requested_delivery_end"),
                self._decimal(payload, "total_quantity") or Decimal("0"),
                int(payload.get("total_packages") or 0),
                self._decimal(payload, "total_weight_kg") or Decimal("0"),
                self._decimal(payload, "total_volume_cbm") or Decimal("0"),
                self._decimal(payload, "declared_value_amount"),
                currency_code,
                self._text(payload, "incoterm_code", upper=True),
                self._decimal(payload, "temperature_min_c"),
                self._decimal(payload, "temperature_max_c"),
                bool(payload.get("hazmat_required", False)),
                self._text(payload, "special_instructions"),
                self._text(payload, "source_system", "KTMS_WEB", upper=True),
                self._text(payload, "external_order_no"),
                metadata,
                channel,
                ip,
                client,
            )
            order_id = row["order_id"]
            for child_table in ("transport_order_lines", "transport_order_stops", "order_charges"):
                await conn.execute(f"delete from {self._table(child_table)} where order_id = $1", order_id)

            lines = payload.get("lines") or [
                {
                    "line_no": 1,
                    "item_description": "운송 품목",
                    "quantity": payload.get("total_quantity"),
                    "package_count": payload.get("total_packages"),
                    "gross_weight_kg": payload.get("total_weight_kg"),
                    "volume_cbm": payload.get("total_volume_cbm"),
                    "uom_code": "EA",
                }
            ]
            for index, line in enumerate(lines, start=1):
                uom_id = await self._ensure_order_uom_id(
                    conn,
                    tenant_id,
                    line.get("uom_code") or "EA",
                    channel,
                    ip,
                    client,
                )
                await conn.execute(
                    f"""
                    insert into {self._table("transport_order_lines")} (
                        tenant_id, order_id, line_no, item_description, quantity,
                        uom_id, package_count, gross_weight_kg, net_weight_kg,
                        volume_cbm, length_cm, width_cm, height_cm, lot_no,
                        serial_no, expiry_date, temperature_min_c,
                        temperature_max_c, hazmat_class, metadata,
                        created_channel_code, created_from_ip,
                        created_from_client, updated_channel_code,
                        updated_from_ip, updated_from_client
                    )
                    values (
                        $1, $2, $3, $4, $5::numeric, $6, $7, $8::numeric,
                        $9::numeric, $10::numeric, $11::numeric, $12::numeric,
                        $13::numeric, $14, $15, $16::text::date, $17::numeric,
                        $18::numeric, $19, $20::jsonb, $21, $22, $23, $21, $22, $23
                    )
                    """,
                    tenant_id,
                    order_id,
                    int(line.get("line_no") or index),
                    self._text({"value": line.get("item_description")}, "value"),
                    self._decimal({"v": line.get("quantity")}, "v") or Decimal("0"),
                    uom_id,
                    int(line.get("package_count") or 0),
                    self._decimal({"v": line.get("gross_weight_kg")}, "v") or Decimal("0"),
                    self._decimal({"v": line.get("net_weight_kg")}, "v"),
                    self._decimal({"v": line.get("volume_cbm")}, "v") or Decimal("0"),
                    self._decimal({"v": line.get("length_cm")}, "v"),
                    self._decimal({"v": line.get("width_cm")}, "v"),
                    self._decimal({"v": line.get("height_cm")}, "v"),
                    self._text({"value": line.get("lot_no")}, "value"),
                    self._text({"value": line.get("serial_no")}, "value"),
                    self._text({"value": line.get("expiry_date")}, "value"),
                    self._decimal({"v": line.get("temperature_min_c")}, "v"),
                    self._decimal({"v": line.get("temperature_max_c")}, "v"),
                    self._text({"value": line.get("hazmat_class")}, "value"),
                    json.dumps({"source": "ktms_order_registration", **(line.get("metadata") or {})}, ensure_ascii=False),
                    channel,
                    ip,
                    client,
                )

            for sequence, stop_type, start_key, end_key, name_key, address_key, contact_key, phone_key in (
                (1, "PICKUP", "requested_pickup_start", "requested_pickup_end", "pickup_name", "pickup_address", "pickup_contact_name", "pickup_contact_phone"),
                (2, "DELIVERY", "requested_delivery_start", "requested_delivery_end", "delivery_name", "delivery_address", "delivery_contact_name", "delivery_contact_phone"),
            ):
                await conn.execute(
                    f"""
                    insert into {self._table("transport_order_stops")} (
                        tenant_id, order_id, stop_sequence, stop_type,
                        appointment_required, requested_start_at,
                        requested_end_at, stop_status, contact_name,
                        contact_phone, instructions, metadata,
                        created_channel_code, created_from_ip,
                        created_from_client, updated_channel_code,
                        updated_from_ip, updated_from_client
                    )
                    values (
                        $1, $2, $3, $4, $5, $6::text::timestamptz,
                        $7::text::timestamptz, 'PENDING', $8, $9, $10,
                        $11::jsonb, $12, $13, $14, $12, $13, $14
                    )
                    """,
                    tenant_id,
                    order_id,
                    sequence,
                    stop_type,
                    bool(payload.get("appointment_required", False)) if stop_type == "PICKUP" else False,
                    self._text(payload, start_key),
                    self._text(payload, end_key),
                    self._text(payload, contact_key),
                    self._text(payload, phone_key),
                    self._text(payload, "special_instructions"),
                    json.dumps(
                        {
                            "source": "ktms_order_registration",
                            "stop_name": payload.get(name_key),
                            "address": payload.get(address_key),
                        },
                        ensure_ascii=False,
                    ),
                    channel,
                    ip,
                    client,
                )

            charge_amount = self._decimal(payload, "charge_amount") or Decimal("0")
            charge_id = None
            if charge_amount > 0:
                charge_code_id = await self._ensure_order_charge_code_id(conn, tenant_id, channel, ip, client)
                charge = await conn.fetchrow(
                    f"""
                    insert into {self._table("order_charges")} (
                        tenant_id, company_id, order_id, charge_code_id,
                        payer_partner_id, calculation_basis, quantity, unit_rate,
                        charge_amount, tax_amount, currency_code, charge_status,
                        source_type, metadata, created_channel_code,
                        created_from_ip, created_from_client,
                        updated_channel_code, updated_from_ip,
                        updated_from_client
                    )
                    values (
                        $1, $2, $3, $4, $5, 'MANUAL', 1, $6::numeric,
                        $6::numeric, 0, $7, 'ESTIMATED', 'MANUAL', $8::jsonb,
                        $9, $10, $11, $9, $10, $11
                    )
                    returning order_charge_id
                    """,
                    tenant_id,
                    company_id,
                    order_id,
                    charge_code_id,
                    customer_id,
                    charge_amount,
                    currency_code,
                    json.dumps({"source": "ktms_order_registration"}, ensure_ascii=False),
                    channel,
                    ip,
                    client,
                )
                charge_id = charge["order_charge_id"]

            return {
                "saved": True,
                "table": "transport_orders",
                "id": order_id,
                "code": row["order_no"],
                "line_count": len(lines),
                "charge_id": charge_id,
            }
        finally:
            await conn.close()

    async def _send_json(self, send, status, payload):
        body = b"" if payload is None else json.dumps(payload, ensure_ascii=False).encode("utf-8")
        headers = [
            (b"content-type", b"application/json; charset=utf-8"),
            (b"access-control-allow-origin", b"*"),
            (b"access-control-allow-methods", b"GET, POST, OPTIONS"),
            (b"access-control-allow-headers", b"content-type, authorization"),
            (b"cache-control", b"no-cache"),
            (b"content-length", str(len(body)).encode("ascii")),
        ]
        await send({"type": "http.response.start", "status": status, "headers": headers})
        await send({"type": "http.response.body", "body": body})

    async def _send_text(self, send, status: int, text: str):
        body = text.encode("utf-8")
        await send(
            {
                "type": "http.response.start",
                "status": status,
                "headers": [
                    (b"content-type", b"text/plain; charset=utf-8"),
                    (b"content-length", str(len(body)).encode("ascii")),
                ],
            }
        )
        await send({"type": "http.response.body", "body": body})


app = KtmsApp()
