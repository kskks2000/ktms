-- Enterprise hardening for company-scoped operations, status catalogs,
-- workflow status history, and optimistic locking.

alter table ktms.load_plans add column if not exists company_id bigint;
alter table ktms.shipments add column if not exists company_id bigint;
alter table ktms.dispatches add column if not exists company_id bigint;
alter table ktms.carrier_tenders add column if not exists company_id bigint;
alter table ktms.carrier_tender_responses add column if not exists company_id bigint;
alter table ktms.customer_invoices add column if not exists company_id bigint;
alter table ktms.carrier_settlements add column if not exists company_id bigint;
alter table ktms.settlement_batches add column if not exists company_id bigint;
alter table ktms.payments add column if not exists company_id bigint;
alter table ktms.claims add column if not exists company_id bigint;
alter table ktms.transport_exceptions add column if not exists company_id bigint;
alter table ktms.proof_of_deliveries add column if not exists company_id bigint;
alter table ktms.dock_appointments add column if not exists company_id bigint;
alter table ktms.tracking_events add column if not exists company_id bigint;
alter table ktms.order_charges add column if not exists company_id bigint;
alter table ktms.shipment_charges add column if not exists company_id bigint;

update ktms.shipments s
set company_id = lp.company_id
from ktms.load_plans lp
where s.company_id is null
  and s.load_plan_id = lp.load_plan_id
  and lp.company_id is not null;

update ktms.shipments s
set company_id = o.company_id
from ktms.shipment_orders so
join ktms.transport_orders o on o.order_id = so.order_id
where s.company_id is null
  and s.shipment_id = so.shipment_id;

update ktms.dispatches d
set company_id = s.company_id
from ktms.shipments s
where d.company_id is null
  and d.shipment_id = s.shipment_id
  and s.company_id is not null;

update ktms.carrier_tenders ct
set company_id = s.company_id
from ktms.shipments s
where ct.company_id is null
  and ct.shipment_id = s.shipment_id
  and s.company_id is not null;

update ktms.carrier_tender_responses ctr
set company_id = ct.company_id
from ktms.carrier_tenders ct
where ctr.company_id is null
  and ctr.tender_id = ct.tender_id
  and ct.company_id is not null;

update ktms.customer_invoices ci
set company_id = bp.company_id
from ktms.business_partners bp
where ci.company_id is null
  and ci.customer_id = bp.partner_id;

update ktms.settlement_batches sb
set company_id = bp.company_id
from ktms.business_partners bp
where sb.company_id is null
  and sb.carrier_id = bp.partner_id;

update ktms.carrier_settlements cs
set company_id = s.company_id
from ktms.shipments s
where cs.company_id is null
  and cs.shipment_id = s.shipment_id
  and s.company_id is not null;

update ktms.carrier_settlements cs
set company_id = sb.company_id
from ktms.settlement_batches sb
where cs.company_id is null
  and cs.settlement_batch_id = sb.settlement_batch_id
  and sb.company_id is not null;

update ktms.carrier_settlements cs
set company_id = bp.company_id
from ktms.business_partners bp
where cs.company_id is null
  and cs.carrier_id = bp.partner_id;

update ktms.payments p
set company_id = ci.company_id
from ktms.customer_invoices ci
where p.company_id is null
  and p.invoice_id = ci.invoice_id
  and ci.company_id is not null;

update ktms.claims c
set company_id = o.company_id
from ktms.transport_orders o
where c.company_id is null
  and c.order_id = o.order_id;

update ktms.claims c
set company_id = s.company_id
from ktms.shipments s
where c.company_id is null
  and c.shipment_id = s.shipment_id
  and s.company_id is not null;

update ktms.transport_exceptions e
set company_id = o.company_id
from ktms.transport_orders o
where e.company_id is null
  and e.order_id = o.order_id;

update ktms.transport_exceptions e
set company_id = s.company_id
from ktms.shipments s
where e.company_id is null
  and e.shipment_id = s.shipment_id
  and s.company_id is not null;

update ktms.proof_of_deliveries p
set company_id = s.company_id
from ktms.shipments s
where p.company_id is null
  and p.shipment_id = s.shipment_id
  and s.company_id is not null;

update ktms.proof_of_deliveries p
set company_id = o.company_id
from ktms.transport_orders o
where p.company_id is null
  and p.order_id = o.order_id;

update ktms.dock_appointments da
set company_id = o.company_id
from ktms.transport_orders o
where da.company_id is null
  and da.order_id = o.order_id;

update ktms.dock_appointments da
set company_id = s.company_id
from ktms.shipments s
where da.company_id is null
  and da.shipment_id = s.shipment_id
  and s.company_id is not null;

update ktms.tracking_events te
set company_id = o.company_id
from ktms.transport_orders o
where te.company_id is null
  and te.order_id = o.order_id;

update ktms.tracking_events te
set company_id = s.company_id
from ktms.shipments s
where te.company_id is null
  and te.shipment_id = s.shipment_id
  and s.company_id is not null;

update ktms.order_charges oc
set company_id = o.company_id
from ktms.transport_orders o
where oc.company_id is null
  and oc.order_id = o.order_id;

update ktms.shipment_charges sc
set company_id = s.company_id
from ktms.shipments s
where sc.company_id is null
  and sc.shipment_id = s.shipment_id
  and s.company_id is not null;

with default_companies as (
    select distinct on (c.tenant_id)
        c.tenant_id,
        c.company_id
    from ktms.companies c
    join ktms.tenants t on t.tenant_id = c.tenant_id
    where c.deleted_at is null
    order by
        c.tenant_id,
        case when c.company_code = t.tenant_code || '_HQ' then 0 else 1 end,
        c.company_id
)
update ktms.load_plans x set company_id = d.company_id from default_companies d where x.company_id is null and x.tenant_id = d.tenant_id;

with default_companies as (
    select distinct on (c.tenant_id) c.tenant_id, c.company_id
    from ktms.companies c join ktms.tenants t on t.tenant_id = c.tenant_id
    where c.deleted_at is null
    order by c.tenant_id, case when c.company_code = t.tenant_code || '_HQ' then 0 else 1 end, c.company_id
)
update ktms.shipments x set company_id = d.company_id from default_companies d where x.company_id is null and x.tenant_id = d.tenant_id;

with default_companies as (
    select distinct on (c.tenant_id) c.tenant_id, c.company_id
    from ktms.companies c join ktms.tenants t on t.tenant_id = c.tenant_id
    where c.deleted_at is null
    order by c.tenant_id, case when c.company_code = t.tenant_code || '_HQ' then 0 else 1 end, c.company_id
)
update ktms.dispatches x set company_id = d.company_id from default_companies d where x.company_id is null and x.tenant_id = d.tenant_id;

with default_companies as (
    select distinct on (c.tenant_id) c.tenant_id, c.company_id
    from ktms.companies c join ktms.tenants t on t.tenant_id = c.tenant_id
    where c.deleted_at is null
    order by c.tenant_id, case when c.company_code = t.tenant_code || '_HQ' then 0 else 1 end, c.company_id
)
update ktms.carrier_tenders x set company_id = d.company_id from default_companies d where x.company_id is null and x.tenant_id = d.tenant_id;

with default_companies as (
    select distinct on (c.tenant_id) c.tenant_id, c.company_id
    from ktms.companies c join ktms.tenants t on t.tenant_id = c.tenant_id
    where c.deleted_at is null
    order by c.tenant_id, case when c.company_code = t.tenant_code || '_HQ' then 0 else 1 end, c.company_id
)
update ktms.carrier_tender_responses x set company_id = d.company_id from default_companies d where x.company_id is null and x.tenant_id = d.tenant_id;

with default_companies as (
    select distinct on (c.tenant_id) c.tenant_id, c.company_id
    from ktms.companies c join ktms.tenants t on t.tenant_id = c.tenant_id
    where c.deleted_at is null
    order by c.tenant_id, case when c.company_code = t.tenant_code || '_HQ' then 0 else 1 end, c.company_id
)
update ktms.customer_invoices x set company_id = d.company_id from default_companies d where x.company_id is null and x.tenant_id = d.tenant_id;

with default_companies as (
    select distinct on (c.tenant_id) c.tenant_id, c.company_id
    from ktms.companies c join ktms.tenants t on t.tenant_id = c.tenant_id
    where c.deleted_at is null
    order by c.tenant_id, case when c.company_code = t.tenant_code || '_HQ' then 0 else 1 end, c.company_id
)
update ktms.carrier_settlements x set company_id = d.company_id from default_companies d where x.company_id is null and x.tenant_id = d.tenant_id;

with default_companies as (
    select distinct on (c.tenant_id) c.tenant_id, c.company_id
    from ktms.companies c join ktms.tenants t on t.tenant_id = c.tenant_id
    where c.deleted_at is null
    order by c.tenant_id, case when c.company_code = t.tenant_code || '_HQ' then 0 else 1 end, c.company_id
)
update ktms.settlement_batches x set company_id = d.company_id from default_companies d where x.company_id is null and x.tenant_id = d.tenant_id;

with default_companies as (
    select distinct on (c.tenant_id) c.tenant_id, c.company_id
    from ktms.companies c join ktms.tenants t on t.tenant_id = c.tenant_id
    where c.deleted_at is null
    order by c.tenant_id, case when c.company_code = t.tenant_code || '_HQ' then 0 else 1 end, c.company_id
)
update ktms.payments x set company_id = d.company_id from default_companies d where x.company_id is null and x.tenant_id = d.tenant_id;

with default_companies as (
    select distinct on (c.tenant_id) c.tenant_id, c.company_id
    from ktms.companies c join ktms.tenants t on t.tenant_id = c.tenant_id
    where c.deleted_at is null
    order by c.tenant_id, case when c.company_code = t.tenant_code || '_HQ' then 0 else 1 end, c.company_id
)
update ktms.claims x set company_id = d.company_id from default_companies d where x.company_id is null and x.tenant_id = d.tenant_id;

with default_companies as (
    select distinct on (c.tenant_id) c.tenant_id, c.company_id
    from ktms.companies c join ktms.tenants t on t.tenant_id = c.tenant_id
    where c.deleted_at is null
    order by c.tenant_id, case when c.company_code = t.tenant_code || '_HQ' then 0 else 1 end, c.company_id
)
update ktms.transport_exceptions x set company_id = d.company_id from default_companies d where x.company_id is null and x.tenant_id = d.tenant_id;

with default_companies as (
    select distinct on (c.tenant_id) c.tenant_id, c.company_id
    from ktms.companies c join ktms.tenants t on t.tenant_id = c.tenant_id
    where c.deleted_at is null
    order by c.tenant_id, case when c.company_code = t.tenant_code || '_HQ' then 0 else 1 end, c.company_id
)
update ktms.proof_of_deliveries x set company_id = d.company_id from default_companies d where x.company_id is null and x.tenant_id = d.tenant_id;

with default_companies as (
    select distinct on (c.tenant_id) c.tenant_id, c.company_id
    from ktms.companies c join ktms.tenants t on t.tenant_id = c.tenant_id
    where c.deleted_at is null
    order by c.tenant_id, case when c.company_code = t.tenant_code || '_HQ' then 0 else 1 end, c.company_id
)
update ktms.dock_appointments x set company_id = d.company_id from default_companies d where x.company_id is null and x.tenant_id = d.tenant_id;

with default_companies as (
    select distinct on (c.tenant_id) c.tenant_id, c.company_id
    from ktms.companies c join ktms.tenants t on t.tenant_id = c.tenant_id
    where c.deleted_at is null
    order by c.tenant_id, case when c.company_code = t.tenant_code || '_HQ' then 0 else 1 end, c.company_id
)
update ktms.tracking_events x set company_id = d.company_id from default_companies d where x.company_id is null and x.tenant_id = d.tenant_id;

with default_companies as (
    select distinct on (c.tenant_id) c.tenant_id, c.company_id
    from ktms.companies c join ktms.tenants t on t.tenant_id = c.tenant_id
    where c.deleted_at is null
    order by c.tenant_id, case when c.company_code = t.tenant_code || '_HQ' then 0 else 1 end, c.company_id
)
update ktms.order_charges x set company_id = d.company_id from default_companies d where x.company_id is null and x.tenant_id = d.tenant_id;

with default_companies as (
    select distinct on (c.tenant_id) c.tenant_id, c.company_id
    from ktms.companies c join ktms.tenants t on t.tenant_id = c.tenant_id
    where c.deleted_at is null
    order by c.tenant_id, case when c.company_code = t.tenant_code || '_HQ' then 0 else 1 end, c.company_id
)
update ktms.shipment_charges x set company_id = d.company_id from default_companies d where x.company_id is null and x.tenant_id = d.tenant_id;

do $$
declare
    table_name text;
begin
    foreach table_name in array array[
        'load_plans',
        'shipments',
        'dispatches',
        'carrier_tenders',
        'carrier_tender_responses',
        'customer_invoices',
        'carrier_settlements',
        'settlement_batches',
        'payments',
        'claims',
        'transport_exceptions',
        'proof_of_deliveries',
        'dock_appointments',
        'tracking_events',
        'order_charges',
        'shipment_charges'
    ] loop
        execute format('alter table ktms.%I alter column company_id set not null', table_name);
    end loop;
end $$;

do $$
declare
    rec record;
begin
    for rec in
        select *
        from (
            values
                ('load_plans', 'load_plans_tenant_company_fkey'),
                ('shipments', 'shipments_tenant_company_fkey'),
                ('dispatches', 'dispatches_tenant_company_fkey'),
                ('carrier_tenders', 'carrier_tenders_tenant_company_fkey'),
                ('carrier_tender_responses', 'carrier_tender_responses_tenant_company_fkey'),
                ('customer_invoices', 'customer_invoices_tenant_company_fkey'),
                ('carrier_settlements', 'carrier_settlements_tenant_company_fkey'),
                ('settlement_batches', 'settlement_batches_tenant_company_fkey'),
                ('payments', 'payments_tenant_company_fkey'),
                ('claims', 'claims_tenant_company_fkey'),
                ('transport_exceptions', 'transport_exceptions_tenant_company_fkey'),
                ('proof_of_deliveries', 'proof_of_deliveries_tenant_company_fkey'),
                ('dock_appointments', 'dock_appointments_tenant_company_fkey'),
                ('tracking_events', 'tracking_events_tenant_company_fkey'),
                ('order_charges', 'order_charges_tenant_company_fkey'),
                ('shipment_charges', 'shipment_charges_tenant_company_fkey')
        ) as v(table_name, constraint_name)
    loop
        if not exists (
            select 1
            from pg_constraint
            where connamespace = 'ktms'::regnamespace
              and conname = rec.constraint_name
        ) then
            execute format(
                'alter table ktms.%I add constraint %I foreign key (tenant_id, company_id) references ktms.companies (tenant_id, company_id)',
                rec.table_name,
                rec.constraint_name
            );
        end if;
    end loop;
end $$;

drop index if exists ktms.uq_load_plans_tenant_no_active;
drop index if exists ktms.uq_shipments_tenant_no_active;
drop index if exists ktms.uq_customer_invoices_tenant_no_active;
drop index if exists ktms.uq_carrier_settlements_tenant_no_active;
drop index if exists ktms.uq_settlement_batches_tenant_no_active;
drop index if exists ktms.uq_payments_tenant_no_active;
drop index if exists ktms.uq_claims_tenant_no_active;
drop index if exists ktms.uq_transport_exceptions_tenant_no_active;
drop index if exists ktms.uq_proof_of_deliveries_tenant_no_active;
drop index if exists ktms.uq_dock_appointments_tenant_no_active;

create unique index if not exists uq_load_plans_company_no_active
    on ktms.load_plans (tenant_id, company_id, load_plan_no)
    where deleted_at is null;

create unique index if not exists uq_shipments_company_no_active
    on ktms.shipments (tenant_id, company_id, shipment_no)
    where deleted_at is null;

create unique index if not exists uq_customer_invoices_company_no_active
    on ktms.customer_invoices (tenant_id, company_id, invoice_no)
    where deleted_at is null;

create unique index if not exists uq_carrier_settlements_company_no_active
    on ktms.carrier_settlements (tenant_id, company_id, settlement_no)
    where deleted_at is null;

create unique index if not exists uq_settlement_batches_company_no_active
    on ktms.settlement_batches (tenant_id, company_id, batch_no)
    where deleted_at is null;

create unique index if not exists uq_payments_company_no_active
    on ktms.payments (tenant_id, company_id, payment_no)
    where deleted_at is null;

create unique index if not exists uq_claims_company_no_active
    on ktms.claims (tenant_id, company_id, claim_no)
    where deleted_at is null;

create unique index if not exists uq_transport_exceptions_company_no_active
    on ktms.transport_exceptions (tenant_id, company_id, exception_no)
    where deleted_at is null;

create unique index if not exists uq_proof_of_deliveries_company_no_active
    on ktms.proof_of_deliveries (tenant_id, company_id, pod_no)
    where deleted_at is null;

create unique index if not exists uq_dock_appointments_company_no_active
    on ktms.dock_appointments (tenant_id, company_id, appointment_no)
    where deleted_at is null;

create index if not exists idx_load_plans_company_status on ktms.load_plans (tenant_id, company_id, plan_status);
create index if not exists idx_shipments_company_status on ktms.shipments (tenant_id, company_id, shipment_status);
create index if not exists idx_dispatches_company_status on ktms.dispatches (tenant_id, company_id, dispatch_status);
create index if not exists idx_carrier_tenders_company_status on ktms.carrier_tenders (tenant_id, company_id, tender_status, expires_at);
create index if not exists idx_customer_invoices_company_status on ktms.customer_invoices (tenant_id, company_id, invoice_status);
create index if not exists idx_carrier_settlements_company_status on ktms.carrier_settlements (tenant_id, company_id, settlement_status);
create index if not exists idx_settlement_batches_company_status on ktms.settlement_batches (tenant_id, company_id, settlement_status);
create index if not exists idx_payments_company_status on ktms.payments (tenant_id, company_id, payment_status);
create index if not exists idx_claims_company_status on ktms.claims (tenant_id, company_id, claim_status);
create index if not exists idx_transport_exceptions_company_status on ktms.transport_exceptions (tenant_id, company_id, exception_status, severity);
create index if not exists idx_proof_of_deliveries_company_status on ktms.proof_of_deliveries (tenant_id, company_id, delivery_status);
create index if not exists idx_dock_appointments_company_schedule on ktms.dock_appointments (tenant_id, company_id, scheduled_start_at, scheduled_end_at);
create index if not exists idx_tracking_events_company_time on ktms.tracking_events (tenant_id, company_id, event_time);
create index if not exists idx_order_charges_company_status on ktms.order_charges (tenant_id, company_id, charge_status);
create index if not exists idx_shipment_charges_company_status on ktms.shipment_charges (tenant_id, company_id, charge_status);

alter table ktms.transport_orders add column if not exists version_no integer not null default 1;
alter table ktms.load_plans add column if not exists version_no integer not null default 1;
alter table ktms.shipments add column if not exists version_no integer not null default 1;
alter table ktms.dispatches add column if not exists version_no integer not null default 1;
alter table ktms.carrier_tenders add column if not exists version_no integer not null default 1;
alter table ktms.customer_invoices add column if not exists version_no integer not null default 1;
alter table ktms.carrier_settlements add column if not exists version_no integer not null default 1;
alter table ktms.settlement_batches add column if not exists version_no integer not null default 1;
alter table ktms.payments add column if not exists version_no integer not null default 1;
alter table ktms.claims add column if not exists version_no integer not null default 1;
alter table ktms.transport_exceptions add column if not exists version_no integer not null default 1;
alter table ktms.proof_of_deliveries add column if not exists version_no integer not null default 1;
alter table ktms.dock_appointments add column if not exists version_no integer not null default 1;
alter table ktms.order_charges add column if not exists version_no integer not null default 1;
alter table ktms.shipment_charges add column if not exists version_no integer not null default 1;

create or replace function ktms.set_updated_at_and_version()
returns trigger
language plpgsql
as $function$
begin
    new.updated_at = now();
    new.version_no = coalesce(old.version_no, 0) + 1;
    return new;
end;
$function$;

do $$
declare
    table_name text;
begin
    foreach table_name in array array[
        'transport_orders',
        'load_plans',
        'shipments',
        'dispatches',
        'carrier_tenders',
        'customer_invoices',
        'carrier_settlements',
        'settlement_batches',
        'payments',
        'claims',
        'transport_exceptions',
        'proof_of_deliveries',
        'dock_appointments',
        'order_charges',
        'shipment_charges'
    ] loop
        execute format('drop trigger if exists trg_%I_set_updated_at on ktms.%I', table_name, table_name);
        execute format(
            'create trigger %I before update on ktms.%I for each row execute procedure ktms.set_updated_at_and_version()',
            'trg_' || table_name || '_set_updated_at',
            table_name
        );
    end loop;
end $$;

create table if not exists ktms.workflow_status_history (
    status_history_id bigserial primary key,
    tenant_id bigint not null,
    company_id bigint not null,
    entity_type varchar(50) not null,
    entity_id bigint not null,
    entity_no varchar(120),
    status_field varchar(50) not null,
    from_status_code varchar(50),
    to_status_code varchar(50) not null,
    reason_code varchar(50),
    reason_text text,
    changed_at timestamp with time zone not null default now(),
    changed_by bigint,
    changed_channel_code varchar(30),
    changed_from_ip varchar(45),
    changed_from_location_id bigint,
    changed_from_client varchar(120),
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
    deleted_reason text
);

do $$
begin
    if not exists (
        select 1 from pg_constraint
        where connamespace = 'ktms'::regnamespace
          and conname = 'workflow_status_history_tenant_company_fkey'
    ) then
        alter table ktms.workflow_status_history
            add constraint workflow_status_history_tenant_company_fkey
            foreign key (tenant_id, company_id)
            references ktms.companies (tenant_id, company_id);
    end if;

    if not exists (
        select 1 from pg_constraint
        where connamespace = 'ktms'::regnamespace
          and conname = 'workflow_status_history_changed_by_fkey'
    ) then
        alter table ktms.workflow_status_history
            add constraint workflow_status_history_changed_by_fkey
            foreign key (changed_by)
            references ktms.app_users (user_id);
    end if;

    if not exists (
        select 1 from pg_constraint
        where connamespace = 'ktms'::regnamespace
          and conname = 'workflow_status_history_changed_location_fkey'
    ) then
        alter table ktms.workflow_status_history
            add constraint workflow_status_history_changed_location_fkey
            foreign key (changed_from_location_id)
            references ktms.client_locations (client_location_id);
    end if;
end $$;

create index if not exists idx_workflow_status_history_entity
    on ktms.workflow_status_history (tenant_id, company_id, entity_type, entity_id, changed_at desc);

create index if not exists idx_workflow_status_history_status
    on ktms.workflow_status_history (tenant_id, company_id, entity_type, to_status_code, changed_at desc);

drop trigger if exists trg_workflow_status_history_set_updated_at on ktms.workflow_status_history;

create trigger trg_workflow_status_history_set_updated_at
before update on ktms.workflow_status_history
for each row execute procedure ktms.set_updated_at();

comment on table ktms.workflow_status_history is
    'Status transition history for operational documents such as orders, load plans, shipments, dispatches, invoices, settlements, claims, and exceptions.';

comment on column ktms.workflow_status_history.entity_type is
    'Workflow entity type code. Use WORKFLOW_ENTITY_TYPE common codes.';

comment on column ktms.workflow_status_history.status_field is
    'Name of the status column changed, such as order_status, shipment_status, invoice_status, or settlement_status.';

with seed_groups(group_code, group_name, description, applies_to) as (
    values
        ('TRANSPORT_ORDER_STATUS', '운송오더 상태', 'transport_orders.order_status 공통코드', array['transport_orders.order_status']),
        ('TRANSPORT_ORDER_TYPE', '운송오더 유형', 'transport_orders.order_type 공통코드', array['transport_orders.order_type']),
        ('ORDER_PRIORITY', '오더 우선순위', 'transport_orders.priority_code 공통코드', array['transport_orders.priority_code']),
        ('LOAD_PLAN_STATUS', '편성계획 상태', 'load_plans.plan_status 공통코드', array['load_plans.plan_status']),
        ('SHIPMENT_STATUS', '운송실행 상태', 'shipments.shipment_status 공통코드', array['shipments.shipment_status']),
        ('SHIPMENT_TENDER_STATUS', '운송 입찰 상태', 'shipments.tender_status 공통코드', array['shipments.tender_status']),
        ('CARRIER_TENDER_STATUS', '운송사 제안 상태', 'carrier_tenders.tender_status 공통코드', array['carrier_tenders.tender_status']),
        ('CARRIER_TENDER_RESPONSE_STATUS', '운송사 응답 상태', 'carrier_tender_responses.response_status 공통코드', array['carrier_tender_responses.response_status']),
        ('DISPATCH_STATUS', '배차 상태', 'dispatches.dispatch_status 공통코드', array['dispatches.dispatch_status']),
        ('STOP_STATUS', '경유지 상태', 'transport_order_stops.stop_status 및 shipment_stops.stop_status 공통코드', array['transport_order_stops.stop_status','shipment_stops.stop_status']),
        ('STOP_TYPE', '경유지 유형', 'transport_order_stops.stop_type 및 shipment_stops.stop_type 공통코드', array['transport_order_stops.stop_type','shipment_stops.stop_type']),
        ('CHARGE_STATUS', '운임 상태', 'order_charges.charge_status 및 shipment_charges.charge_status 공통코드', array['order_charges.charge_status','shipment_charges.charge_status']),
        ('INVOICE_STATUS', '매출 청구 상태', 'customer_invoices.invoice_status 공통코드', array['customer_invoices.invoice_status']),
        ('SETTLEMENT_STATUS', '매입 정산 상태', 'settlement_batches.settlement_status 및 carrier_settlements.settlement_status 공통코드', array['settlement_batches.settlement_status','carrier_settlements.settlement_status']),
        ('PAYMENT_STATUS', '수금 상태', 'payments.payment_status 공통코드', array['payments.payment_status']),
        ('POD_STATUS', '인수증 상태', 'proof_of_deliveries.delivery_status 공통코드', array['proof_of_deliveries.delivery_status']),
        ('CLAIM_STATUS', '클레임 상태', 'claims.claim_status 공통코드', array['claims.claim_status']),
        ('EXCEPTION_STATUS', '예외 상태', 'transport_exceptions.exception_status 공통코드', array['transport_exceptions.exception_status']),
        ('EXCEPTION_SEVERITY', '예외 심각도', 'transport_exceptions.severity 공통코드', array['transport_exceptions.severity']),
        ('DOCK_APPOINTMENT_STATUS', '도크 예약 상태', 'dock_appointments.appointment_status 공통코드', array['dock_appointments.appointment_status']),
        ('DOCK_APPOINTMENT_TYPE', '도크 예약 유형', 'dock_appointments.appointment_type 공통코드', array['dock_appointments.appointment_type']),
        ('TRACKING_EVENT_STATUS', '트래킹 이벤트 상태', 'tracking_events.event_status 공통코드', array['tracking_events.event_status']),
        ('TRACKING_EVENT_SOURCE', '트래킹 이벤트 출처', 'tracking_events.source_type 공통코드', array['tracking_events.source_type']),
        ('WORKFLOW_ENTITY_TYPE', '워크플로우 엔티티 유형', 'workflow_status_history.entity_type 공통코드', array['workflow_status_history.entity_type'])
)
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
    t.tenant_id,
    sg.group_code,
    sg.group_name,
    sg.description,
    true,
    true,
    jsonb_build_object('applies_to', sg.applies_to),
    now()
from ktms.tenants t
cross join seed_groups sg
where t.deleted_at is null
on conflict (tenant_id, group_code) where deleted_at is null do update set
    group_name = excluded.group_name,
    description = excluded.description,
    is_system = true,
    is_active = true,
    metadata = excluded.metadata,
    updated_at = now(),
    deleted_at = null;

with seed_codes(group_code, code, sort_order, is_default) as (
    values
        ('TRANSPORT_ORDER_STATUS', 'DRAFT', 10, true),
        ('TRANSPORT_ORDER_STATUS', 'CONFIRMED', 20, false),
        ('TRANSPORT_ORDER_STATUS', 'PLANNED', 30, false),
        ('TRANSPORT_ORDER_STATUS', 'TENDERED', 40, false),
        ('TRANSPORT_ORDER_STATUS', 'DISPATCHED', 50, false),
        ('TRANSPORT_ORDER_STATUS', 'IN_TRANSIT', 60, false),
        ('TRANSPORT_ORDER_STATUS', 'DELIVERED', 70, false),
        ('TRANSPORT_ORDER_STATUS', 'CLOSED', 80, false),
        ('TRANSPORT_ORDER_STATUS', 'CANCELLED', 90, false),
        ('TRANSPORT_ORDER_TYPE', 'STANDARD', 10, true),
        ('TRANSPORT_ORDER_TYPE', 'RETURN', 20, false),
        ('TRANSPORT_ORDER_TYPE', 'TRANSFER', 30, false),
        ('TRANSPORT_ORDER_TYPE', 'EXPEDITED', 40, false),
        ('TRANSPORT_ORDER_TYPE', 'CONSOLIDATION', 50, false),
        ('ORDER_PRIORITY', 'LOW', 10, false),
        ('ORDER_PRIORITY', 'NORMAL', 20, true),
        ('ORDER_PRIORITY', 'HIGH', 30, false),
        ('ORDER_PRIORITY', 'URGENT', 40, false),
        ('LOAD_PLAN_STATUS', 'DRAFT', 10, true),
        ('LOAD_PLAN_STATUS', 'OPTIMIZED', 20, false),
        ('LOAD_PLAN_STATUS', 'APPROVED', 30, false),
        ('LOAD_PLAN_STATUS', 'RELEASED', 40, false),
        ('LOAD_PLAN_STATUS', 'CANCELLED', 50, false),
        ('SHIPMENT_STATUS', 'PLANNED', 10, true),
        ('SHIPMENT_STATUS', 'TENDERED', 20, false),
        ('SHIPMENT_STATUS', 'ACCEPTED', 30, false),
        ('SHIPMENT_STATUS', 'DISPATCHED', 40, false),
        ('SHIPMENT_STATUS', 'IN_TRANSIT', 50, false),
        ('SHIPMENT_STATUS', 'DELIVERED', 60, false),
        ('SHIPMENT_STATUS', 'CLOSED', 70, false),
        ('SHIPMENT_STATUS', 'CANCELLED', 80, false),
        ('SHIPMENT_TENDER_STATUS', 'NOT_TENDERED', 10, true),
        ('SHIPMENT_TENDER_STATUS', 'TENDERED', 20, false),
        ('SHIPMENT_TENDER_STATUS', 'ACCEPTED', 30, false),
        ('SHIPMENT_TENDER_STATUS', 'REJECTED', 40, false),
        ('SHIPMENT_TENDER_STATUS', 'EXPIRED', 50, false),
        ('SHIPMENT_TENDER_STATUS', 'CANCELLED', 60, false),
        ('CARRIER_TENDER_STATUS', 'SENT', 10, true),
        ('CARRIER_TENDER_STATUS', 'VIEWED', 20, false),
        ('CARRIER_TENDER_STATUS', 'ACCEPTED', 30, false),
        ('CARRIER_TENDER_STATUS', 'REJECTED', 40, false),
        ('CARRIER_TENDER_STATUS', 'EXPIRED', 50, false),
        ('CARRIER_TENDER_STATUS', 'CANCELLED', 60, false),
        ('CARRIER_TENDER_RESPONSE_STATUS', 'ACCEPTED', 10, false),
        ('CARRIER_TENDER_RESPONSE_STATUS', 'REJECTED', 20, false),
        ('CARRIER_TENDER_RESPONSE_STATUS', 'COUNTERED', 30, false),
        ('DISPATCH_STATUS', 'CREATED', 10, true),
        ('DISPATCH_STATUS', 'SENT', 20, false),
        ('DISPATCH_STATUS', 'ACCEPTED', 30, false),
        ('DISPATCH_STATUS', 'STARTED', 40, false),
        ('DISPATCH_STATUS', 'COMPLETED', 50, false),
        ('DISPATCH_STATUS', 'CANCELLED', 60, false),
        ('STOP_STATUS', 'PENDING', 10, true),
        ('STOP_STATUS', 'SCHEDULED', 20, false),
        ('STOP_STATUS', 'ARRIVED', 30, false),
        ('STOP_STATUS', 'LOADING', 40, false),
        ('STOP_STATUS', 'UNLOADING', 50, false),
        ('STOP_STATUS', 'COMPLETED', 60, false),
        ('STOP_STATUS', 'SKIPPED', 70, false),
        ('STOP_STATUS', 'CANCELLED', 80, false),
        ('STOP_TYPE', 'PICKUP', 10, false),
        ('STOP_TYPE', 'DELIVERY', 20, false),
        ('STOP_TYPE', 'STOP_OFF', 30, false),
        ('STOP_TYPE', 'RETURN', 40, false),
        ('STOP_TYPE', 'CROSS_DOCK', 50, false),
        ('CHARGE_STATUS', 'ESTIMATED', 10, true),
        ('CHARGE_STATUS', 'APPROVED', 20, false),
        ('CHARGE_STATUS', 'SETTLED', 30, false),
        ('CHARGE_STATUS', 'INVOICED', 40, false),
        ('CHARGE_STATUS', 'CANCELLED', 50, false),
        ('INVOICE_STATUS', 'DRAFT', 10, true),
        ('INVOICE_STATUS', 'APPROVED', 20, false),
        ('INVOICE_STATUS', 'ISSUED', 30, false),
        ('INVOICE_STATUS', 'PARTIALLY_PAID', 40, false),
        ('INVOICE_STATUS', 'PAID', 50, false),
        ('INVOICE_STATUS', 'VOID', 60, false),
        ('INVOICE_STATUS', 'CANCELLED', 70, false),
        ('SETTLEMENT_STATUS', 'DRAFT', 10, true),
        ('SETTLEMENT_STATUS', 'APPROVED', 20, false),
        ('SETTLEMENT_STATUS', 'PAID', 30, false),
        ('SETTLEMENT_STATUS', 'CLOSED', 40, false),
        ('SETTLEMENT_STATUS', 'CANCELLED', 50, false),
        ('PAYMENT_STATUS', 'RECEIVED', 10, true),
        ('PAYMENT_STATUS', 'APPLIED', 20, false),
        ('PAYMENT_STATUS', 'REVERSED', 30, false),
        ('PAYMENT_STATUS', 'CANCELLED', 40, false),
        ('POD_STATUS', 'DELIVERED', 10, true),
        ('POD_STATUS', 'PARTIAL', 20, false),
        ('POD_STATUS', 'DAMAGED', 30, false),
        ('POD_STATUS', 'REFUSED', 40, false),
        ('CLAIM_STATUS', 'OPEN', 10, true),
        ('CLAIM_STATUS', 'UNDER_REVIEW', 20, false),
        ('CLAIM_STATUS', 'APPROVED', 30, false),
        ('CLAIM_STATUS', 'REJECTED', 40, false),
        ('CLAIM_STATUS', 'SETTLED', 50, false),
        ('CLAIM_STATUS', 'CLOSED', 60, false),
        ('EXCEPTION_STATUS', 'OPEN', 10, true),
        ('EXCEPTION_STATUS', 'IN_PROGRESS', 20, false),
        ('EXCEPTION_STATUS', 'RESOLVED', 30, false),
        ('EXCEPTION_STATUS', 'CLOSED', 40, false),
        ('EXCEPTION_STATUS', 'CANCELLED', 50, false),
        ('EXCEPTION_SEVERITY', 'LOW', 10, false),
        ('EXCEPTION_SEVERITY', 'MEDIUM', 20, true),
        ('EXCEPTION_SEVERITY', 'HIGH', 30, false),
        ('EXCEPTION_SEVERITY', 'CRITICAL', 40, false),
        ('DOCK_APPOINTMENT_STATUS', 'REQUESTED', 10, true),
        ('DOCK_APPOINTMENT_STATUS', 'CONFIRMED', 20, false),
        ('DOCK_APPOINTMENT_STATUS', 'CHECKED_IN', 30, false),
        ('DOCK_APPOINTMENT_STATUS', 'IN_PROGRESS', 40, false),
        ('DOCK_APPOINTMENT_STATUS', 'COMPLETED', 50, false),
        ('DOCK_APPOINTMENT_STATUS', 'NO_SHOW', 60, false),
        ('DOCK_APPOINTMENT_STATUS', 'CANCELLED', 70, false),
        ('DOCK_APPOINTMENT_TYPE', 'INBOUND', 10, false),
        ('DOCK_APPOINTMENT_TYPE', 'OUTBOUND', 20, true),
        ('DOCK_APPOINTMENT_TYPE', 'TRANSFER', 30, false),
        ('TRACKING_EVENT_STATUS', 'RECORDED', 10, true),
        ('TRACKING_EVENT_STATUS', 'VOIDED', 20, false),
        ('TRACKING_EVENT_SOURCE', 'MANUAL', 10, false),
        ('TRACKING_EVENT_SOURCE', 'MOBILE', 20, false),
        ('TRACKING_EVENT_SOURCE', 'GPS', 30, false),
        ('TRACKING_EVENT_SOURCE', 'EDI', 40, false),
        ('TRACKING_EVENT_SOURCE', 'API', 50, false),
        ('TRACKING_EVENT_SOURCE', 'IOT', 60, false),
        ('WORKFLOW_ENTITY_TYPE', 'TRANSPORT_ORDER', 10, false),
        ('WORKFLOW_ENTITY_TYPE', 'LOAD_PLAN', 20, false),
        ('WORKFLOW_ENTITY_TYPE', 'SHIPMENT', 30, false),
        ('WORKFLOW_ENTITY_TYPE', 'DISPATCH', 40, false),
        ('WORKFLOW_ENTITY_TYPE', 'CUSTOMER_INVOICE', 50, false),
        ('WORKFLOW_ENTITY_TYPE', 'CARRIER_SETTLEMENT', 60, false),
        ('WORKFLOW_ENTITY_TYPE', 'PAYMENT', 70, false),
        ('WORKFLOW_ENTITY_TYPE', 'CLAIM', 80, false),
        ('WORKFLOW_ENTITY_TYPE', 'TRANSPORT_EXCEPTION', 90, false),
        ('WORKFLOW_ENTITY_TYPE', 'DOCK_APPOINTMENT', 100, false),
        ('WORKFLOW_ENTITY_TYPE', 'PROOF_OF_DELIVERY', 110, false)
),
code_labels(code, code_name) as (
    values
        ('ACTIVE', '활성'),
        ('INACTIVE', '비활성'),
        ('DRAFT', '초안'),
        ('CONFIRMED', '확정'),
        ('PLANNED', '계획'),
        ('TENDERED', '입찰중'),
        ('DISPATCHED', '배차완료'),
        ('IN_TRANSIT', '운송중'),
        ('DELIVERED', '도착'),
        ('CLOSED', '마감'),
        ('CANCELLED', '취소'),
        ('STANDARD', '일반'),
        ('RETURN', '반품'),
        ('TRANSFER', '이동'),
        ('EXPEDITED', '긴급운송'),
        ('CONSOLIDATION', '혼적'),
        ('LOW', '낮음'),
        ('NORMAL', '보통'),
        ('HIGH', '높음'),
        ('URGENT', '긴급'),
        ('OPTIMIZED', '최적화'),
        ('APPROVED', '승인'),
        ('RELEASED', '릴리즈'),
        ('ACCEPTED', '수락'),
        ('REJECTED', '거절'),
        ('EXPIRED', '만료'),
        ('NOT_TENDERED', '미입찰'),
        ('SENT', '전송'),
        ('VIEWED', '열람'),
        ('COUNTERED', '역제안'),
        ('CREATED', '생성'),
        ('STARTED', '시작'),
        ('COMPLETED', '완료'),
        ('PENDING', '대기'),
        ('SCHEDULED', '예약'),
        ('ARRIVED', '도착'),
        ('LOADING', '상차중'),
        ('UNLOADING', '하차중'),
        ('SKIPPED', '건너뜀'),
        ('PICKUP', '상차'),
        ('DELIVERY', '하차'),
        ('STOP_OFF', '경유'),
        ('CROSS_DOCK', '크로스도크'),
        ('ESTIMATED', '예상'),
        ('SETTLED', '정산완료'),
        ('INVOICED', '청구완료'),
        ('ISSUED', '발행'),
        ('PARTIALLY_PAID', '부분수금'),
        ('PAID', '지급완료'),
        ('VOID', '무효'),
        ('RECEIVED', '수령'),
        ('APPLIED', '반영'),
        ('REVERSED', '역분개'),
        ('PARTIAL', '부분인수'),
        ('DAMAGED', '파손'),
        ('REFUSED', '인수거부'),
        ('OPEN', '오픈'),
        ('UNDER_REVIEW', '검토중'),
        ('IN_PROGRESS', '진행중'),
        ('RESOLVED', '해결'),
        ('MEDIUM', '중간'),
        ('CRITICAL', '심각'),
        ('REQUESTED', '요청'),
        ('CHECKED_IN', '체크인'),
        ('NO_SHOW', '노쇼'),
        ('INBOUND', '입고'),
        ('OUTBOUND', '출고'),
        ('RECORDED', '기록'),
        ('VOIDED', '무효'),
        ('MANUAL', '수동'),
        ('MOBILE', '모바일'),
        ('GPS', 'GPS'),
        ('EDI', 'EDI'),
        ('API', 'API'),
        ('IOT', 'IoT'),
        ('TRANSPORT_ORDER', '운송오더'),
        ('LOAD_PLAN', '편성계획'),
        ('SHIPMENT', '운송실행'),
        ('DISPATCH', '배차'),
        ('CUSTOMER_INVOICE', '매출 청구'),
        ('CARRIER_SETTLEMENT', '매입 정산'),
        ('PAYMENT', '수금'),
        ('CLAIM', '클레임'),
        ('TRANSPORT_EXCEPTION', '운송 예외'),
        ('DOCK_APPOINTMENT', '도크 예약'),
        ('PROOF_OF_DELIVERY', '인수증')
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
    sc.code,
    coalesce(cl.code_name, initcap(replace(lower(sc.code), '_', ' '))),
    sc.code,
    sc.sort_order,
    sc.is_default,
    true,
    jsonb_build_object('group_code', sc.group_code),
    now()
from seed_codes sc
join ktms.code_groups g
  on g.group_code = sc.group_code
 and g.deleted_at is null
left join code_labels cl on cl.code = sc.code
on conflict (code_group_id, code) where deleted_at is null do update set
    tenant_id = excluded.tenant_id,
    code_name = excluded.code_name,
    code_value = excluded.code_value,
    sort_order = excluded.sort_order,
    is_default = excluded.is_default,
    is_active = true,
    metadata = excluded.metadata,
    updated_at = now(),
    deleted_at = null;

comment on column ktms.load_plans.company_id is 'Company/legal entity that owns this load plan.';
comment on column ktms.shipments.company_id is 'Company/legal entity that owns this shipment.';
comment on column ktms.dispatches.company_id is 'Company/legal entity that owns this dispatch.';
comment on column ktms.carrier_tenders.company_id is 'Company/legal entity that owns this carrier tender.';
comment on column ktms.carrier_tender_responses.company_id is 'Company/legal entity that owns this carrier tender response.';
comment on column ktms.customer_invoices.company_id is 'Company/legal entity that owns this customer invoice.';
comment on column ktms.carrier_settlements.company_id is 'Company/legal entity that owns this carrier settlement.';
comment on column ktms.settlement_batches.company_id is 'Company/legal entity that owns this settlement batch.';
comment on column ktms.payments.company_id is 'Company/legal entity that owns this payment.';
comment on column ktms.claims.company_id is 'Company/legal entity that owns this claim.';
comment on column ktms.transport_exceptions.company_id is 'Company/legal entity that owns this transport exception.';
comment on column ktms.proof_of_deliveries.company_id is 'Company/legal entity that owns this proof of delivery.';
comment on column ktms.dock_appointments.company_id is 'Company/legal entity that owns this dock appointment.';
comment on column ktms.tracking_events.company_id is 'Company/legal entity that owns this tracking event.';
comment on column ktms.order_charges.company_id is 'Company/legal entity that owns this order charge.';
comment on column ktms.shipment_charges.company_id is 'Company/legal entity that owns this shipment charge.';

comment on column ktms.transport_orders.version_no is 'Optimistic locking version. API updates should check and increment this value.';
comment on column ktms.load_plans.version_no is 'Optimistic locking version. API updates should check and increment this value.';
comment on column ktms.shipments.version_no is 'Optimistic locking version. API updates should check and increment this value.';
comment on column ktms.dispatches.version_no is 'Optimistic locking version. API updates should check and increment this value.';
comment on column ktms.carrier_tenders.version_no is 'Optimistic locking version. API updates should check and increment this value.';
comment on column ktms.customer_invoices.version_no is 'Optimistic locking version. API updates should check and increment this value.';
comment on column ktms.carrier_settlements.version_no is 'Optimistic locking version. API updates should check and increment this value.';
comment on column ktms.settlement_batches.version_no is 'Optimistic locking version. API updates should check and increment this value.';
comment on column ktms.payments.version_no is 'Optimistic locking version. API updates should check and increment this value.';
comment on column ktms.claims.version_no is 'Optimistic locking version. API updates should check and increment this value.';
comment on column ktms.transport_exceptions.version_no is 'Optimistic locking version. API updates should check and increment this value.';
comment on column ktms.proof_of_deliveries.version_no is 'Optimistic locking version. API updates should check and increment this value.';
comment on column ktms.dock_appointments.version_no is 'Optimistic locking version. API updates should check and increment this value.';
comment on column ktms.order_charges.version_no is 'Optimistic locking version. API updates should check and increment this value.';
comment on column ktms.shipment_charges.version_no is 'Optimistic locking version. API updates should check and increment this value.';
