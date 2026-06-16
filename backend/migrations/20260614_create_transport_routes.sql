create table if not exists ktms.transport_routes (
    transport_route_id bigserial primary key,
    tenant_id bigint not null references ktms.tenants(tenant_id),
    route_code varchar(50) not null,
    route_name varchar(200) not null,
    origin_name varchar(200),
    destination_name varchar(200),
    geo_zone_id bigint references ktms.geo_zones(geo_zone_id),
    zone_name varchar(120),
    service_level varchar(50),
    distance_km numeric(12,2),
    lead_time_hours numeric(12,2),
    base_fare numeric(18,2),
    vehicle_limit varchar(100),
    appointment_required boolean not null default false,
    toll_included boolean not null default true,
    temperature_controlled boolean not null default false,
    status varchar(30) not null default 'ACTIVE',
    is_active boolean not null default true,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamptz not null default now(),
    updated_at timestamptz not null default now(),
    created_by bigint,
    updated_by bigint,
    deleted_at timestamptz,
    created_channel_code varchar(50),
    created_from_ip varchar(100),
    created_from_location_id bigint,
    created_from_client varchar(200),
    updated_channel_code varchar(50),
    updated_from_ip varchar(100),
    updated_from_location_id bigint,
    updated_from_client varchar(200),
    deleted_by bigint,
    deleted_channel_code varchar(50),
    deleted_from_ip varchar(100),
    deleted_from_location_id bigint,
    deleted_from_client varchar(200),
    deleted_reason text,
    constraint chk_transport_routes_status
        check (status in ('ACTIVE', 'INACTIVE'))
);

create unique index if not exists uq_transport_routes_tenant_code_active
    on ktms.transport_routes(tenant_id, route_code)
    where deleted_at is null;

create index if not exists idx_transport_routes_tenant_zone
    on ktms.transport_routes(tenant_id, geo_zone_id);
