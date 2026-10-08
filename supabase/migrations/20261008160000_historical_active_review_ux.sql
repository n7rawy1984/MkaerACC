-- Source reporting is available to active Company management, with no mutation grants.
alter policy historical_source_read on public.historical_source_records using(
 public.has_company_role(company_id,'ACCOUNTING_ADMIN') or public.has_company_role(company_id,'ACCOUNTANT') or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
alter policy historical_audit_read on public.historical_source_audit using(
 public.has_company_role(company_id,'ACCOUNTING_ADMIN') or public.has_company_role(company_id,'ACCOUNTANT') or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));

create or replace function public.complete_historical_source(target_company_id uuid,target_id uuid,expected_updated_at timestamptz,details jsonb,target_status text)
returns void language plpgsql security definer set search_path='' as $$
declare r public.historical_source_records; k text;
begin
 if auth.uid() is null or not(public.has_company_role(target_company_id,'ACCOUNTING_ADMIN') or public.has_company_role(target_company_id,'ACCOUNTANT')) then raise exception 'Denied' using errcode='42501';end if;
 if details is null or jsonb_typeof(details)<>'object' or octet_length(details::text)>20000 or target_status is null or target_status not in ('PENDING','REVIEWED','CANCELLED') then raise exception 'Invalid completion' using errcode='22023';end if;
 for k in select jsonb_object_keys(details) loop
  if jsonb_typeof(details->k) not in ('string','null') then raise exception 'Text completion required' using errcode='22023';end if;
 end loop;
 if details->>'amount_minor' is not null and (details->>'amount_minor' !~ '^[0-9]{1,16}$' or (details->>'amount_minor')::numeric>9000000000000000) then raise exception 'Invalid amount' using errcode='22023';end if;
 if nullif(details->>'date','') is not null then perform (details->>'date')::date;end if;
 if target_status='CANCELLED' and nullif(btrim(details->>'reason'),'') is null then raise exception 'Cancellation reason required' using errcode='22023';end if;
 if nullif(details->>'salary_month','') is not null then
  if details->>'salary_month' !~ '^[0-9]{4}-(0[1-9]|1[0-2])$' then raise exception 'Invalid salary month' using errcode='22023';end if;
  perform ((details->>'salary_month')||'-01')::date;
 end if;
 foreach k in array array['basic_salary','additions','deductions'] loop
  if nullif(details->>k,'') is not null and (details->>k !~ '^[0-9]+([.][0-9]{1,2})?$' or (details->>k)::numeric>90000000000000) then raise exception 'Invalid salary amount' using errcode='22023';end if;
 end loop;
 foreach k in array array['working_days','absence_days'] loop
  if nullif(details->>k,'') is not null and (details->>k !~ '^[0-9]+([.][0-9]{1,2})?$' or (details->>k)::numeric>31) then raise exception 'Invalid source attendance summary' using errcode='22023';end if;
 end loop;
 -- Canonical Payroll takes the Company lock before linking source rows.
 if exists(select 1 from public.historical_source_records where company_id=target_company_id and id=target_id and record_type='PAYROLL') then perform private.attendance_company_lock(target_company_id);end if;
 select * into r from public.historical_source_records where company_id=target_company_id and id=target_id for update;
 if not found or r.updated_at is distinct from expected_updated_at then raise exception 'Stale source; reload' using errcode='40001';end if;
 if r.expense_id is not null or r.payroll_entitlement_id is not null then raise exception 'Use canonical reversal/correction' using errcode='23514';end if;
 update public.historical_source_records set completion=details,review_status=target_status,
 payroll_profile_id=case when r.record_type='PAYROLL' and r.completion is distinct from details then null else r.payroll_profile_id end,updated_by=auth.uid(),updated_at=clock_timestamp() where id=r.id;
end $$;

-- A source correction must be reverified in the existing Payroll profile flow.
create or replace function private.link_historical_payroll_entitlement() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 update public.historical_source_records s set payroll_entitlement_id=new.id,
  updated_by=auth.uid(),updated_at=clock_timestamp()
 from public.payroll_profiles profile,public.payroll_postings posting,public.payroll_draft_periods period
 where s.company_id=new.company_id and s.record_type='PAYROLL' and s.review_status<>'CANCELLED'
  and s.payroll_entitlement_id is null and s.payroll_profile_id=profile.id
  and profile.company_id=new.company_id and profile.employee_id=new.employee_id
  and posting.company_id=new.company_id and posting.id=new.payroll_id
  and period.company_id=new.company_id and period.id=posting.period_id
  and coalesce(nullif(s.completion->>'salary_month',''),s.source_month)=to_char(period.month,'YYYY-MM');
 return new;
end $$;

create or replace function private.audit_historical_source() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.historical_source_audit(company_id,source_id,actor_id,action,before_state,after_state)
 values(new.company_id,new.id,coalesce(new.updated_by,new.created_by),
 case when old.review_status='CANCELLED' and new.review_status<>'CANCELLED' then 'RESTORE' when new.review_status='CANCELLED' then 'CANCEL'
  when new.expense_id is distinct from old.expense_id or new.payroll_entitlement_id is distinct from old.payroll_entitlement_id then 'POST_LINK'
  when new.payroll_profile_id is distinct from old.payroll_profile_id then case when new.payroll_profile_id is null then 'PROFILE_UNLINK' else 'PROFILE_LINK' end
  when new.cash_treasury_id is distinct from old.cash_treasury_id then 'CASH_CONFIRM' else 'COMPLETE' end,
 jsonb_build_object('completion',old.completion,'status',old.review_status,'expense_id',old.expense_id,'payroll_entitlement_id',old.payroll_entitlement_id,'payroll_profile_id',old.payroll_profile_id,'cash_treasury_id',old.cash_treasury_id),
 jsonb_build_object('completion',new.completion,'status',new.review_status,'expense_id',new.expense_id,'payroll_entitlement_id',new.payroll_entitlement_id,'payroll_profile_id',new.payroll_profile_id,'cash_treasury_id',new.cash_treasury_id));
 return new;
end $$;
