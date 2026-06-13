alter table ktms.business_partners
    add column if not exists partner_short_name varchar(120);

comment on column ktms.business_partners.partner_short_name is
    'Business partner abbreviation or short display name, such as Samsung for Samsung Electronics Co., Ltd.';

create index if not exists idx_business_partners_short_name
    on ktms.business_partners (
        tenant_id,
        company_id,
        partner_short_name
    )
    where deleted_at is null
      and partner_short_name is not null;
