create table if not exists ktms.client_locations (
    client_location_id bigserial primary key,
    tenant_id bigint references ktms.tenants(tenant_id),
    captured_at timestamp with time zone not null default now(),
    channel_code varchar(30),
    client_ip varchar(45),
    client_name varchar(120),
    device_id varchar(120),
    user_agent text,
    geo_country_code char(2),
    geo_region varchar(100),
    geo_city varchar(100),
    latitude numeric(10,7),
    longitude numeric(10,7),
    location_accuracy_m integer,
    metadata jsonb not null default '{}'::jsonb,
    created_at timestamp with time zone not null default now(),
    created_by bigint,
    created_channel_code varchar(30),
    created_from_ip varchar(45),
    created_from_location_id bigint,
    created_from_client varchar(120),
    updated_at timestamp with time zone not null default now(),
    updated_by bigint,
    updated_channel_code varchar(30),
    updated_from_ip varchar(45),
    updated_from_location_id bigint,
    updated_from_client varchar(120),
    deleted_at timestamp with time zone
);

comment on table ktms.client_locations is
    'Client request location/source snapshots used by created_from_location_id and updated_from_location_id.';

do $$
declare
    target_table record;
begin
    for target_table in
        select table_schema, table_name
        from information_schema.tables
        where table_schema = 'ktms'
          and table_type = 'BASE TABLE'
          and table_name <> 'schema_migrations'
        order by table_name
    loop
        execute format('alter table %I.%I add column if not exists created_at timestamp with time zone not null default now()', target_table.table_schema, target_table.table_name);
        execute format('alter table %I.%I add column if not exists created_by bigint', target_table.table_schema, target_table.table_name);
        execute format('alter table %I.%I add column if not exists created_channel_code varchar(30)', target_table.table_schema, target_table.table_name);
        execute format('alter table %I.%I add column if not exists created_from_ip varchar(45)', target_table.table_schema, target_table.table_name);
        execute format('alter table %I.%I add column if not exists created_from_location_id bigint', target_table.table_schema, target_table.table_name);
        execute format('alter table %I.%I add column if not exists created_from_client varchar(120)', target_table.table_schema, target_table.table_name);
        execute format('alter table %I.%I add column if not exists updated_at timestamp with time zone not null default now()', target_table.table_schema, target_table.table_name);
        execute format('alter table %I.%I add column if not exists updated_by bigint', target_table.table_schema, target_table.table_name);
        execute format('alter table %I.%I add column if not exists updated_channel_code varchar(30)', target_table.table_schema, target_table.table_name);
        execute format('alter table %I.%I add column if not exists updated_from_ip varchar(45)', target_table.table_schema, target_table.table_name);
        execute format('alter table %I.%I add column if not exists updated_from_location_id bigint', target_table.table_schema, target_table.table_name);
        execute format('alter table %I.%I add column if not exists updated_from_client varchar(120)', target_table.table_schema, target_table.table_name);
    end loop;
end $$;
