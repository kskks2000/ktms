with partner_type_group as (
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
        'PARTNER_TYPE',
        '거래처 유형',
        'business_partners.partner_type 및 business_partner_roles.role_code에서 사용하는 거래처 대표 유형/역할 코드.',
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
    jsonb_build_object('applies_to', array['business_partners.partner_type', 'business_partner_roles.role_code']),
    now()
from partner_type_group g
cross join partner_type_codes c
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
