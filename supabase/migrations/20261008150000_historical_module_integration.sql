alter table public.historical_source_records drop constraint historical_source_records_review_status_check;
alter table public.historical_source_records add constraint historical_source_records_review_status_check check(review_status in ('PENDING','REVIEWED','CANCELLED'));
alter table public.historical_source_records add column cash_treasury_id uuid,
 add column payroll_profile_id uuid,
 add foreign key(company_id,cash_treasury_id) references public.treasury_accounts(company_id,id),
 add foreign key(company_id,payroll_profile_id) references public.payroll_profiles(company_id,id);
create table public.historical_source_audit (
 id uuid primary key default gen_random_uuid(),company_id uuid not null,source_id uuid not null,
 actor_id uuid not null references auth.users(id),action text not null,before_state jsonb not null,after_state jsonb not null,
 created_at timestamptz not null default clock_timestamp(),
 foreign key(company_id,source_id) references public.historical_source_records(company_id,id) on delete restrict
);
alter table public.historical_source_audit enable row level security;
alter table public.historical_source_audit force row level security;
create policy historical_audit_read on public.historical_source_audit for select to authenticated using(public.has_company_role(company_id,'ACCOUNTING_ADMIN') or public.has_company_role(company_id,'ACCOUNTANT'));
revoke all on public.historical_source_audit from public,anon,authenticated,service_role;
grant select on public.historical_source_audit to authenticated;
create function private.audit_historical_source() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.historical_source_audit(company_id,source_id,actor_id,action,before_state,after_state)
 values(new.company_id,new.id,coalesce(new.updated_by,new.created_by),case when new.review_status='CANCELLED' then 'CANCEL' when new.expense_id is distinct from old.expense_id then 'POST_LINK' else 'COMPLETE' end,
 jsonb_build_object('completion',old.completion,'status',old.review_status,'expense_id',old.expense_id,'payroll_profile_id',old.payroll_profile_id,'cash_treasury_id',old.cash_treasury_id),
 jsonb_build_object('completion',new.completion,'status',new.review_status,'expense_id',new.expense_id,'payroll_profile_id',new.payroll_profile_id,'cash_treasury_id',new.cash_treasury_id));
 return new;
end $$;
revoke all on function private.audit_historical_source() from public,anon,authenticated,service_role;
create trigger historical_source_update_audit after update on public.historical_source_records for each row execute function private.audit_historical_source();
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
 select * into r from public.historical_source_records where company_id=target_company_id and id=target_id for update;
 if not found or r.updated_at is distinct from expected_updated_at then raise exception 'Stale source; reload' using errcode='40001';end if;
 if r.expense_id is not null or r.payroll_entitlement_id is not null then raise exception 'Use canonical reversal/correction' using errcode='23514';end if;
 update public.historical_source_records set completion=details,review_status=target_status,updated_by=auth.uid(),updated_at=clock_timestamp() where id=r.id;
end $$;
create function public.post_historical_expense(target_company_id uuid,target_source_id uuid,business_input jsonb)
returns table(expense_id uuid,expense_reference text,journal_entry_id uuid,replayed boolean)
language plpgsql security definer set search_path='' as $$
declare r public.historical_source_records; result record; v jsonb:=business_input; gross bigint; vat bigint;
begin
 if auth.uid() is null or not public.has_permission(target_company_id,'accounting.post') then raise exception 'Denied' using errcode='42501';end if;
 select * into r from public.historical_source_records where company_id=target_company_id and id=target_source_id for update;
 if not found or r.record_type<>'GENERAL' or r.review_status='CANCELLED' or r.cash_treasury_id is null or coalesce(r.outflow_minor,0)<=0
 or coalesce(r.completion->>'nature',r.classification->>'nature')<>'EXPENSE' then raise exception 'Complete recognized expense source first' using errcode='23514';end if;
 if (v->>'target_treasury_account_id')::uuid is distinct from r.cash_treasury_id or v->>'target_funding_mode'<>'TREASURY' or v->>'target_payment_method'<>'CASH' then raise exception 'Confirmed cash source mismatch' using errcode='23514';end if;
 vat:=case v->>'target_vat_mode' when 'ZERO' then 0 when 'AUTO_5' then round((v->>'target_net_amount_minor')::numeric*5/100)::bigint else (v->>'target_manual_vat_amount_minor')::bigint end;
 gross:=(v->>'target_net_amount_minor')::bigint+vat;
 if gross is distinct from coalesce((r.completion->>'amount_minor')::bigint,r.outflow_minor) then raise exception 'Gross must match completed source outflow' using errcode='23514';end if;
 select * into result from public.post_expense(target_company_id,(v->>'target_expense_date')::date,(v->>'target_project_id')::uuid,(v->>'target_expense_category_id')::uuid,v->>'target_description',(v->>'target_net_amount_minor')::bigint,(v->>'target_vat_mode')::public.expense_vat_mode,(v->>'target_manual_vat_amount_minor')::bigint,'TREASURY',r.cash_treasury_id,null,(v->>'target_supplier_id')::uuid,'CASH',(v->>'target_has_tax_invoice')::boolean,v->>'target_invoice_number',v->>'target_notes',r.id);
 if r.expense_id is not null and r.expense_id<>result.expense_id then raise exception 'Source already linked';end if;
 if r.expense_id is null then update public.historical_source_records set expense_id=result.expense_id,updated_by=auth.uid(),updated_at=clock_timestamp() where id=r.id;end if;
 return query select result.expense_id,result.expense_reference,result.journal_entry_id,result.replayed;
end $$;
revoke all on function public.post_historical_expense(uuid,uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.post_historical_expense(uuid,uuid,jsonb) to authenticated;
create function public.link_historical_payroll_profile(target_company_id uuid,target_source_id uuid,target_profile_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare r public.historical_source_records;p public.payroll_profiles;expected text;
begin
 if auth.uid() is null or not public.has_permission(target_company_id,'payroll.manage') then raise exception 'Denied' using errcode='42501';end if;
 select * into r from public.historical_source_records where company_id=target_company_id and id=target_source_id for update;
 if not found or r.record_type<>'PAYROLL' or r.review_status='CANCELLED' or r.payroll_entitlement_id is not null then raise exception 'Source unavailable' using errcode='23514';end if;
 select * into p from public.payroll_profiles where company_id=target_company_id and id=target_profile_id for share;
 expected:=coalesce(nullif(r.completion->>'employee_id',''),nullif(r.raw_source->>'Payroll ID',''));
 if not found or expected is null or p.payroll_id<>expected or (r.payroll_profile_id is not null and r.payroll_profile_id<>p.id) then raise exception 'Complete and verify source payroll identifier before linking' using errcode='23514';end if;
 if r.payroll_profile_id is null then update public.historical_source_records set payroll_profile_id=p.id,updated_by=auth.uid(),updated_at=clock_timestamp() where id=r.id;end if;
end $$;
revoke all on function public.link_historical_payroll_profile(uuid,uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.link_historical_payroll_profile(uuid,uuid,uuid) to authenticated;
