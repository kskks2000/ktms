insert into ktms.companies (
    tenant_id,
    company_code,
    company_name,
    company_type,
    status,
    created_channel_code,
    updated_channel_code
)
select
    tenant_id,
    tenant_code || '_HQ',
    tenant_name || ' 본사',
    'INTERNAL',
    'ACTIVE',
    'SYSTEM',
    'SYSTEM'
from ktms.tenants
where deleted_at is null
on conflict (tenant_id, company_code) do update set
    company_name = excluded.company_name,
    company_type = excluded.company_type,
    status = excluded.status,
    updated_at = now(),
    updated_channel_code = 'SYSTEM',
    deleted_at = null;

alter table ktms.business_partners
    add column if not exists company_id bigint;

update ktms.business_partners bp
set company_id = c.company_id,
    updated_at = now(),
    updated_channel_code = coalesce(bp.updated_channel_code, 'SYSTEM')
from ktms.companies c
where bp.company_id is null
  and bp.tenant_id = c.tenant_id
  and c.company_code = (
      select t.tenant_code || '_HQ'
      from ktms.tenants t
      where t.tenant_id = bp.tenant_id
  );

alter table ktms.business_partners
    alter column company_id set not null;

do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where connamespace = 'ktms'::regnamespace
          and conrelid = 'ktms.companies'::regclass
          and conname = 'uq_companies_tenant_company'
    ) then
        alter table ktms.companies
            add constraint uq_companies_tenant_company
            unique (tenant_id, company_id);
    end if;
end $$;

do $$
begin
    if exists (
        select 1
        from pg_constraint
        where connamespace = 'ktms'::regnamespace
          and conrelid = 'ktms.business_partners'::regclass
          and conname = 'uq_business_partners_tenant_code'
    ) then
        alter table ktms.business_partners
            drop constraint uq_business_partners_tenant_code;
    end if;

    if not exists (
        select 1
        from pg_constraint
        where connamespace = 'ktms'::regnamespace
          and conrelid = 'ktms.business_partners'::regclass
          and conname = 'uq_business_partners_company_code'
    ) then
        alter table ktms.business_partners
            add constraint uq_business_partners_company_code
            unique (tenant_id, company_id, partner_code);
    end if;

    if not exists (
        select 1
        from pg_constraint
        where connamespace = 'ktms'::regnamespace
          and conrelid = 'ktms.business_partners'::regclass
          and conname = 'business_partners_tenant_company_fkey'
    ) then
        alter table ktms.business_partners
            add constraint business_partners_tenant_company_fkey
            foreign key (tenant_id, company_id)
            references ktms.companies (tenant_id, company_id);
    end if;
end $$;

create index if not exists idx_business_partners_company_type
    on ktms.business_partners (tenant_id, company_id, partner_type);

comment on column ktms.business_partners.company_id is
    'Company/legal entity that owns or manages this business partner master record within the tenant.';
