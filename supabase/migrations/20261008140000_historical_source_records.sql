-- Source evidence is separate from financial documents and never enters GL totals.
create table public.historical_source_records (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.companies(id) on delete restrict,
 source_file text not null check(length(source_file) between 1 and 200),
 source_hash text not null check(source_hash ~ '^[0-9a-f]{64}$'),
 source_reference text not null check(length(source_reference) between 1 and 100),
 record_type text not null check(record_type in ('GENERAL','PAYROLL')),
 source_month text not null check(source_month ~ '^[0-9]{4}-(0[1-9]|1[0-2])$'),
 source_date date,
 description text not null,
 outflow_minor bigint check(outflow_minor >= 0),
 funding_minor bigint check(funding_minor >= 0),
 payroll_net_minor bigint check(payroll_net_minor >= 0),
 raw_source jsonb not null check(jsonb_typeof(raw_source)='object'),
 classification jsonb not null check(jsonb_typeof(classification)='object'),
 completion jsonb not null default '{}'::jsonb check(jsonb_typeof(completion)='object'),
 review_status text not null default 'PENDING' check(review_status in ('PENDING','REVIEWED')),
 expense_id uuid,
 payroll_entitlement_id uuid,
 created_by uuid not null references auth.users(id),
 created_at timestamptz not null default now(),
 updated_by uuid references auth.users(id),
 updated_at timestamptz not null default now(),
 unique(company_id,source_file,source_reference),
 unique(company_id,id),
 foreign key(company_id,expense_id) references public.expenses(company_id,id) on delete restrict,
 foreign key(company_id,payroll_entitlement_id) references public.payroll_entitlements(company_id,id) on delete restrict,
 check((record_type='GENERAL' and payroll_net_minor is null and payroll_entitlement_id is null)
  or (record_type='PAYROLL' and outflow_minor is null and funding_minor is null and expense_id is null))
);
alter table public.historical_source_records enable row level security;
alter table public.historical_source_records force row level security;
create policy historical_source_read on public.historical_source_records for select to authenticated
 using(public.has_company_role(company_id,'ACCOUNTING_ADMIN') or public.has_company_role(company_id,'ACCOUNTANT'));
revoke all on public.historical_source_records from public,anon,authenticated,service_role;
grant select on public.historical_source_records to authenticated;

create function public.complete_historical_source(target_company_id uuid,target_id uuid,
 expected_updated_at timestamptz, details jsonb,target_status text)
returns void language plpgsql security definer set search_path='' as $$
begin
 if auth.uid() is null or not (public.has_company_role(target_company_id,'ACCOUNTING_ADMIN')
  or public.has_company_role(target_company_id,'ACCOUNTANT')) then
  raise exception 'Source completion denied' using errcode='42501';
 end if;
 if details is null or jsonb_typeof(details)<>'object' or octet_length(details::text)>20000
  or target_status is null or target_status not in ('PENDING','REVIEWED') then
  raise exception 'Invalid completion' using errcode='22023';
 end if;
 -- These are review annotations, never journal inputs or accounting recognition.
 update public.historical_source_records set completion=details,review_status=target_status,
  updated_by=auth.uid(),updated_at=clock_timestamp()
 where company_id=target_company_id and id=target_id and updated_at=expected_updated_at;
 if not found then raise exception 'Source unavailable or changed; reload' using errcode='40001'; end if;
end; $$;
revoke all on function public.complete_historical_source(uuid,uuid,timestamptz,jsonb,text) from public,anon,authenticated,service_role;
grant execute on function public.complete_historical_source(uuid,uuid,timestamptz,jsonb,text) to authenticated;
comment on table public.historical_source_records is 'Immutable imported source evidence with editable review annotations; not recognized accounting or payroll. Trusted protected import only; browser has no source-write grants.';
