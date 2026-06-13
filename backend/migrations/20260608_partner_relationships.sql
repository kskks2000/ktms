with partner_type_group as (
    select code_group_id, tenant_id
    from ktms.code_groups
    where group_code = 'PARTNER_TYPE'
),
partner_type_codes as (
    select *
    from (
        values
            ('CUSTOMER', '고객사', '운송 서비스를 의뢰하고 매출 청구 대상이 되는 거래처', 10),
            ('SHIPPER', '화주', '실제 화물의 소유자 또는 오더 주체가 되는 거래처', 20),
            ('CONSIGNEE', '수하인/납품처', '화물을 인수하거나 최종 납품받는 거래처', 30),
            ('CARRIER', '운송사', '실제 운송을 수행하고 매입 정산 대상이 되는 거래처', 40),
            ('BROKER', '주선사', '운송 중개 또는 주선 업무를 수행하는 거래처', 50),
            ('SUPPLIER', '공급사', '운송 외 용역, 자재, 서비스 등을 공급하는 거래처', 60),
            ('INTERNAL', '내부회사', 'tenant 내부 법인, 지사, 사업장 등 내부 거래 주체', 70)
    ) as value_table(code, code_name, code_value, sort_order)
)
update ktms.codes c
set metadata = jsonb_build_object('applies_to', array['business_partners.partner_type']),
    code_name = v.code_name,
    code_value = v.code_value,
    sort_order = v.sort_order,
    updated_at = now()
from partner_type_group g
cross join partner_type_codes v
where c.code_group_id = g.code_group_id
  and c.code = v.code;

with partner_role_group as (
    insert into ktms.code_groups (
        tenant_id,
        group_code,
        group_name,
        description,
        is_system,
        is_active,
        metadata,
        updated_at
    )
    select
        tenant_id,
        'PARTNER_ROLE',
        '거래처 역할',
        'business_partner_roles.role_code에서 사용하는 거래처 복수 역할 코드.',
        true,
        true,
        '{}'::jsonb,
        now()
    from ktms.tenants
    where deleted_at is null
    on conflict (tenant_id, group_code) do update set
        group_name = excluded.group_name,
        description = excluded.description,
        is_system = true,
        is_active = true,
        updated_at = now(),
        deleted_at = null
    returning code_group_id, tenant_id
),
partner_role_codes as (
    select *
    from (
        values
            ('CUSTOMER', '고객사', '운송 서비스를 의뢰하는 역할', 10),
            ('SHIPPER', '화주', '실제 화물의 소유자 또는 오더 주체 역할', 20),
            ('CONSIGNEE', '수하인/납품처', '화물을 인수하거나 최종 납품받는 역할', 30),
            ('CARRIER', '운송사', '실제 운송을 수행하는 역할', 40),
            ('BROKER', '주선사', '운송 중개 또는 주선 업무를 수행하는 역할', 50),
            ('SUPPLIER', '공급사', '운송 외 용역, 자재, 서비스 등을 공급하는 역할', 60),
            ('BILL_TO', '청구처', '매출 청구 대상 역할', 70),
            ('PAY_TO', '지급처', '매입 지급 대상 역할', 80)
    ) as value_table(code, code_name, code_value, sort_order)
)
insert into ktms.codes (
    tenant_id,
    code_group_id,
    code,
    code_name,
    code_value,
    sort_order,
    is_default,
    is_active,
    metadata,
    updated_at
)
select
    g.tenant_id,
    g.code_group_id,
    c.code,
    c.code_name,
    c.code_value,
    c.sort_order,
    false,
    true,
    jsonb_build_object('applies_to', array['business_partner_roles.role_code']),
    now()
from partner_role_group g
cross join partner_role_codes c
on conflict (code_group_id, code) do update set
    tenant_id = excluded.tenant_id,
    code_name = excluded.code_name,
    code_value = excluded.code_value,
    sort_order = excluded.sort_order,
    is_default = excluded.is_default,
    is_active = true,
    metadata = excluded.metadata,
    updated_at = now(),
    deleted_at = null;

with relationship_type_group as (
    insert into ktms.code_groups (
        tenant_id,
        group_code,
        group_name,
        description,
        is_system,
        is_active,
        metadata,
        updated_at
    )
    select
        tenant_id,
        'PARTNER_RELATIONSHIP_TYPE',
        '거래처 관계 유형',
        'business_partner_relationships.relationship_type_code에서 사용하는 거래처 간 관계 코드.',
        true,
        true,
        '{}'::jsonb,
        now()
    from ktms.tenants
    where deleted_at is null
    on conflict (tenant_id, group_code) do update set
        group_name = excluded.group_name,
        description = excluded.description,
        is_system = true,
        is_active = true,
        updated_at = now(),
        deleted_at = null
    returning code_group_id, tenant_id
),
relationship_type_codes as (
    select *
    from (
        values
            ('CUSTOMER_SHIPPER', '고객사-화주', '고객사가 취급 가능한 화주 관계', 10),
            ('CUSTOMER_BILL_TO', '고객사-청구처', '고객사의 매출 청구처 관계', 20),
            ('CUSTOMER_CONSIGNEE', '고객사-수하인', '고객사가 납품 가능한 수하인/납품처 관계', 30),
            ('CUSTOMER_CARRIER', '고객사-운송사', '고객사 오더에 배정 가능한 운송사 관계', 40),
            ('CUSTOMER_BROKER', '고객사-주선사', '고객사 오더를 주선 가능한 주선사 관계', 50),
            ('SHIPPER_CONSIGNEE', '화주-수하인', '화주의 납품처 또는 수하인 관계', 60),
            ('SHIPPER_CARRIER', '화주-운송사', '화주 화물을 운송 가능한 운송사 관계', 70),
            ('CARRIER_PAY_TO', '운송사-지급처', '운송사 매입 정산 지급처 관계', 80),
            ('BROKER_CARRIER', '주선사-운송사', '주선사가 배정 가능한 운송사 관계', 90),
            ('INTERNAL_PARTNER', '내부회사-거래처', '내부 법인/지사와 외부 거래처의 관리 관계', 100)
    ) as value_table(code, code_name, code_value, sort_order)
)
insert into ktms.codes (
    tenant_id,
    code_group_id,
    code,
    code_name,
    code_value,
    sort_order,
    is_default,
    is_active,
    metadata,
    updated_at
)
select
    g.tenant_id,
    g.code_group_id,
    c.code,
    c.code_name,
    c.code_value,
    c.sort_order,
    c.code = 'CUSTOMER_SHIPPER',
    true,
    jsonb_build_object('applies_to', array['business_partner_relationships.relationship_type_code']),
    now()
from relationship_type_group g
cross join relationship_type_codes c
on conflict (code_group_id, code) do update set
    tenant_id = excluded.tenant_id,
    code_name = excluded.code_name,
    code_value = excluded.code_value,
    sort_order = excluded.sort_order,
    is_default = excluded.is_default,
    is_active = true,
    metadata = excluded.metadata,
    updated_at = now(),
    deleted_at = null;

do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where connamespace = 'ktms'::regnamespace
          and conrelid = 'ktms.business_partners'::regclass
          and conname = 'uq_business_partners_tenant_company_partner'
    ) then
        alter table ktms.business_partners
            add constraint uq_business_partners_tenant_company_partner
            unique (tenant_id, company_id, partner_id);
    end if;
end $$;

create table if not exists ktms.business_partner_relationships (
    relationship_id bigserial primary key,
    tenant_id bigint not null,
    company_id bigint not null,
    relationship_type_code varchar(40) not null,
    from_partner_id bigint not null,
    to_partner_id bigint not null,
    bill_to_partner_id bigint,
    pay_to_partner_id bigint,
    default_rate_agreement_id bigint,
    default_service_level_id bigint,
    effective_from date not null default current_date,
    effective_to date,
    status varchar(20) not null default 'ACTIVE',
    priority_order integer not null default 0,
    notes text,
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
    deleted_at timestamp with time zone,
    deleted_by bigint,
    deleted_channel_code varchar(30),
    deleted_from_ip varchar(45),
    deleted_from_location_id bigint,
    deleted_from_client varchar(120),
    deleted_reason text,
    constraint chk_business_partner_relationships_status
        check (status in ('ACTIVE', 'INACTIVE', 'SUSPENDED')),
    constraint chk_business_partner_relationships_dates
        check (effective_to is null or effective_to >= effective_from),
    constraint chk_business_partner_relationships_not_self
        check (from_partner_id <> to_partner_id)
);

do $$
begin
    if not exists (
        select 1
        from pg_constraint
        where connamespace = 'ktms'::regnamespace
          and conrelid = 'ktms.business_partner_relationships'::regclass
          and conname = 'business_partner_relationships_tenant_company_fkey'
    ) then
        alter table ktms.business_partner_relationships
            add constraint business_partner_relationships_tenant_company_fkey
            foreign key (tenant_id, company_id)
            references ktms.companies (tenant_id, company_id);
    end if;

    if not exists (
        select 1
        from pg_constraint
        where connamespace = 'ktms'::regnamespace
          and conrelid = 'ktms.business_partner_relationships'::regclass
          and conname = 'business_partner_relationships_from_partner_fkey'
    ) then
        alter table ktms.business_partner_relationships
            add constraint business_partner_relationships_from_partner_fkey
            foreign key (tenant_id, company_id, from_partner_id)
            references ktms.business_partners (tenant_id, company_id, partner_id);
    end if;

    if not exists (
        select 1
        from pg_constraint
        where connamespace = 'ktms'::regnamespace
          and conrelid = 'ktms.business_partner_relationships'::regclass
          and conname = 'business_partner_relationships_to_partner_fkey'
    ) then
        alter table ktms.business_partner_relationships
            add constraint business_partner_relationships_to_partner_fkey
            foreign key (tenant_id, company_id, to_partner_id)
            references ktms.business_partners (tenant_id, company_id, partner_id);
    end if;

    if not exists (
        select 1
        from pg_constraint
        where connamespace = 'ktms'::regnamespace
          and conrelid = 'ktms.business_partner_relationships'::regclass
          and conname = 'business_partner_relationships_bill_to_partner_fkey'
    ) then
        alter table ktms.business_partner_relationships
            add constraint business_partner_relationships_bill_to_partner_fkey
            foreign key (tenant_id, company_id, bill_to_partner_id)
            references ktms.business_partners (tenant_id, company_id, partner_id);
    end if;

    if not exists (
        select 1
        from pg_constraint
        where connamespace = 'ktms'::regnamespace
          and conrelid = 'ktms.business_partner_relationships'::regclass
          and conname = 'business_partner_relationships_pay_to_partner_fkey'
    ) then
        alter table ktms.business_partner_relationships
            add constraint business_partner_relationships_pay_to_partner_fkey
            foreign key (tenant_id, company_id, pay_to_partner_id)
            references ktms.business_partners (tenant_id, company_id, partner_id);
    end if;

    if not exists (
        select 1
        from pg_constraint
        where connamespace = 'ktms'::regnamespace
          and conrelid = 'ktms.business_partner_relationships'::regclass
          and conname = 'business_partner_relationships_rate_agreement_fkey'
    ) then
        alter table ktms.business_partner_relationships
            add constraint business_partner_relationships_rate_agreement_fkey
            foreign key (default_rate_agreement_id)
            references ktms.rate_agreements (rate_agreement_id);
    end if;

    if not exists (
        select 1
        from pg_constraint
        where connamespace = 'ktms'::regnamespace
          and conrelid = 'ktms.business_partner_relationships'::regclass
          and conname = 'business_partner_relationships_service_level_fkey'
    ) then
        alter table ktms.business_partner_relationships
            add constraint business_partner_relationships_service_level_fkey
            foreign key (default_service_level_id)
            references ktms.service_levels (service_level_id);
    end if;
end $$;

create unique index if not exists uq_business_partner_relationships_period
    on ktms.business_partner_relationships (
        tenant_id,
        company_id,
        relationship_type_code,
        from_partner_id,
        to_partner_id,
        effective_from
    );

create unique index if not exists uq_bp_relationships_tenant_company_id
    on ktms.business_partner_relationships (
        tenant_id,
        company_id,
        relationship_id
    );

create index if not exists idx_bp_relationships_from_type
    on ktms.business_partner_relationships (
        tenant_id,
        company_id,
        from_partner_id,
        relationship_type_code,
        status
    );

create index if not exists idx_bp_relationships_to_type
    on ktms.business_partner_relationships (
        tenant_id,
        company_id,
        to_partner_id,
        relationship_type_code,
        status
    );

alter table ktms.transport_orders
    add column if not exists company_id bigint,
    add column if not exists customer_shipper_relationship_id bigint;

update ktms.transport_orders o
set company_id = bp.company_id,
    updated_at = now(),
    updated_channel_code = coalesce(o.updated_channel_code, 'SYSTEM')
from ktms.business_partners bp
where o.company_id is null
  and o.customer_id = bp.partner_id;

update ktms.transport_orders o
set company_id = c.company_id,
    updated_at = now(),
    updated_channel_code = coalesce(o.updated_channel_code, 'SYSTEM')
from ktms.companies c
where o.company_id is null
  and o.tenant_id = c.tenant_id
  and c.company_code = (
      select t.tenant_code || '_HQ'
      from ktms.tenants t
      where t.tenant_id = o.tenant_id
  );

do $$
begin
    if not exists (
        select 1
        from ktms.transport_orders
        where company_id is null
    ) then
        alter table ktms.transport_orders
            alter column company_id set not null;
    end if;

    if not exists (
        select 1
        from pg_constraint
        where connamespace = 'ktms'::regnamespace
          and conrelid = 'ktms.transport_orders'::regclass
          and conname = 'transport_orders_tenant_company_fkey'
    ) then
        alter table ktms.transport_orders
            add constraint transport_orders_tenant_company_fkey
            foreign key (tenant_id, company_id)
            references ktms.companies (tenant_id, company_id);
    end if;

    if not exists (
        select 1
        from pg_constraint
        where connamespace = 'ktms'::regnamespace
          and conrelid = 'ktms.transport_orders'::regclass
          and conname = 'transport_orders_customer_shipper_relationship_fkey'
    ) then
        alter table ktms.transport_orders
            add constraint transport_orders_customer_shipper_relationship_fkey
            foreign key (tenant_id, company_id, customer_shipper_relationship_id)
            references ktms.business_partner_relationships (
                tenant_id,
                company_id,
                relationship_id
            );
    end if;

    if exists (
        select 1
        from pg_constraint
        where connamespace = 'ktms'::regnamespace
          and conrelid = 'ktms.transport_orders'::regclass
          and conname = 'uq_transport_orders_tenant_no'
    ) then
        alter table ktms.transport_orders
            drop constraint uq_transport_orders_tenant_no;
    end if;

    if not exists (
        select 1
        from pg_constraint
        where connamespace = 'ktms'::regnamespace
          and conrelid = 'ktms.transport_orders'::regclass
          and conname = 'uq_transport_orders_company_no'
    ) then
        alter table ktms.transport_orders
            add constraint uq_transport_orders_company_no
            unique (tenant_id, company_id, order_no);
    end if;
end $$;

create index if not exists idx_transport_orders_company_status
    on ktms.transport_orders (tenant_id, company_id, order_status);

create index if not exists idx_transport_orders_customer_shipper_relationship
    on ktms.transport_orders (customer_shipper_relationship_id);

comment on table ktms.business_partner_relationships is
    'Business partner relationship master, such as customer-shipper, customer-bill-to, customer-carrier, and carrier-pay-to.';

comment on column ktms.business_partner_relationships.from_partner_id is
    'Relationship source partner. For CUSTOMER_SHIPPER this is the customer.';

comment on column ktms.business_partner_relationships.to_partner_id is
    'Relationship target partner. For CUSTOMER_SHIPPER this is the shipper.';

comment on column ktms.transport_orders.customer_shipper_relationship_id is
    'Customer-shipper relationship master used when this order was created.';
