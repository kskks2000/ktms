begin;

create schema if not exists ktms;

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
        execute format('alter table %I.%I add column if not exists deleted_at timestamp with time zone', target_table.table_schema, target_table.table_name);
        execute format('alter table %I.%I add column if not exists deleted_by bigint', target_table.table_schema, target_table.table_name);
        execute format('alter table %I.%I add column if not exists deleted_channel_code varchar(30)', target_table.table_schema, target_table.table_name);
        execute format('alter table %I.%I add column if not exists deleted_from_ip varchar(45)', target_table.table_schema, target_table.table_name);
        execute format('alter table %I.%I add column if not exists deleted_from_location_id bigint', target_table.table_schema, target_table.table_name);
        execute format('alter table %I.%I add column if not exists deleted_from_client varchar(120)', target_table.table_schema, target_table.table_name);
        execute format('alter table %I.%I add column if not exists deleted_reason text', target_table.table_schema, target_table.table_name);
    end loop;
end $$;

do $$
begin
    if to_regclass('ktms.schema_migrations') is not null then
        insert into ktms.schema_migrations (version, description)
        values ('20260608_add_delete_audit_columns', 'Add delete audit/source columns to ktms tables')
        on conflict (version) do nothing;
    end if;
end $$;

commit;
