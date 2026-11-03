-- M3 / PRJ-02: explicit whole-source assignment of unposted expense evidence.
-- No cost recognition, splitting, posted correction, or historical backfill.
alter table public.historical_source_records
 add column allocation_scope text,
 add column assigned_project_id uuid,
 add constraint historical_assignment_scope check (
  (allocation_scope is null and assigned_project_id is null) or
  (allocation_scope is not null and allocation_scope='PROJECT' and assigned_project_id is not null) or
  (allocation_scope is not null and allocation_scope='COMPANY' and assigned_project_id is null)),
 add constraint historical_assignment_project_fk foreign key(company_id,assigned_project_id)
 references public.projects(company_id,id) on delete restrict;

create table public.source_project_assignment_events (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.companies(id) on delete restrict,
 request_id uuid not null,
 actor_id uuid not null references auth.users(id) on delete restrict,
 reason text not null check(length(reason) between 1 and 500),
 input_hash text not null,
 changes jsonb not null check(jsonb_typeof(changes)='array' and jsonb_array_length(changes) between 1 and 100),
 created_at timestamptz not null default clock_timestamp(),
 unique(company_id,request_id)
);
alter table public.source_project_assignment_events enable row level security;
alter table public.source_project_assignment_events force row level security;
revoke all on public.source_project_assignment_events from public,anon,authenticated,service_role;
grant select on public.source_project_assignment_events to authenticated;
create policy source_project_assignment_read on public.source_project_assignment_events for select to authenticated
 using(public.has_company_role(company_id,'ACCOUNTING_ADMIN') or public.has_company_role(company_id,'ACCOUNTANT')
 or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create function private.prevent_source_assignment_event_change() returns trigger
language plpgsql set search_path='' as $$begin
 raise exception 'Source assignment history is immutable' using errcode='23514';end;$$;
revoke all on function private.prevent_source_assignment_event_change() from public,anon,authenticated,service_role;
create trigger source_assignment_history_immutable before update or delete on public.source_project_assignment_events
 for each row execute function private.prevent_source_assignment_event_change();

create function public.assign_source_projects(target_company_id uuid,request_id uuid,items jsonb,reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); normalized jsonb; item jsonb; original public.historical_source_records;
 prior public.source_project_assignment_events; digest text; event_id uuid; changes jsonb:='[]';
 target_project uuid; project_status public.project_status; normalized_reason text;
 trim_chars text := E' \t\n\r\f' || chr(11) || chr(160) || chr(5760)
  || chr(8192) || chr(8193) || chr(8194) || chr(8195) || chr(8196) || chr(8197)
  || chr(8198) || chr(8199) || chr(8200) || chr(8201) || chr(8202)
  || chr(8232) || chr(8233) || chr(8239) || chr(8287) || chr(12288) || chr(65279);
begin
 normalized_reason:=nullif(btrim(reason,trim_chars),'');
 if actor is null then raise exception 'Denied' using errcode='42501';end if;
 perform 1 from public.companies where id=target_company_id for share;
 perform 1 from public.profiles where user_id=actor for share;
 perform 1 from public.company_memberships where company_id=target_company_id and user_id=actor for share;
 if not (public.has_company_role(target_company_id,'ACCOUNTING_ADMIN') or public.has_company_role(target_company_id,'ACCOUNTANT')) then
  raise exception 'Assignment denied' using errcode='42501';end if;
 if request_id is null or normalized_reason is null or length(normalized_reason)>500
 or items is null or jsonb_typeof(items)<>'array' then raise exception 'Invalid assignment' using errcode='22023';end if;
 if jsonb_array_length(items) not between 1 and 100 then raise exception 'Select 1 to 100 sources' using errcode='22023';end if;
 for item in select value from jsonb_array_elements(items) loop
  if jsonb_typeof(item)<>'object' or (item-array['source_id','expected_updated_at','scope','project_id'])<>'{}'::jsonb
   or nullif(item->>'source_id','') is null or nullif(item->>'expected_updated_at','') is null
   or item->>'scope' is null or item->>'scope' not in ('PROJECT','COMPANY')
   or ((item->>'scope'='PROJECT')<>(nullif(item->>'project_id','') is not null)) then
   raise exception 'Invalid assignment item' using errcode='22023';end if;
 end loop;
 -- Canonical UUID and timestamp representations, deterministic item ordering.
 select jsonb_agg(jsonb_build_object('source_id',(v->>'source_id')::uuid,
  'epoch',extract(epoch from (v->>'expected_updated_at')::timestamptz),
  'scope',v->>'scope','project_id',nullif(v->>'project_id','')::uuid) order by (v->>'source_id')::uuid)
 into normalized from jsonb_array_elements(items) v;
 if (select count(distinct v->>'source_id') from jsonb_array_elements(normalized) v)<>jsonb_array_length(normalized) then
  raise exception 'Duplicate source' using errcode='22023';end if;
 digest:=encode(extensions.digest(jsonb_build_object('actor',actor,'company',target_company_id,'items',normalized,'reason',normalized_reason)::text,'sha256'),'hex');
 perform pg_advisory_xact_lock(hashtextextended('source-assignment:'||target_company_id::text||':'||request_id::text,0));
 select * into prior from public.source_project_assignment_events e
 where e.company_id=target_company_id and e.request_id=assign_source_projects.request_id;
 if found then
  if prior.input_hash<>digest or prior.actor_id<>actor then raise exception 'Request changed' using errcode='22023';end if;
  return jsonb_build_object('id',prior.id,'company_id',prior.company_id,'request_id',prior.request_id,'count',jsonb_array_length(prior.changes));
 end if;
 -- Project locks precede all source locks, matching project-aware posting order.
 for target_project in select distinct (v->>'project_id')::uuid from jsonb_array_elements(normalized) v
 where v->>'project_id' is not null order by 1 loop
  select status into project_status from public.projects where company_id=target_company_id and id=target_project for share;
  if not found then raise exception 'Project unavailable' using errcode='42501';end if;
  if project_status='CLOSED' then raise exception 'Closed project' using errcode='23514';end if;
 end loop;
 for item in select value from jsonb_array_elements(normalized) loop
  select * into original from public.historical_source_records where company_id=target_company_id and id=(item->>'source_id')::uuid for update;
  if not found then raise exception 'Source unavailable' using errcode='42501';end if;
  if extract(epoch from original.updated_at)<>(item->>'epoch')::numeric then raise exception 'Source changed; refresh' using errcode='40001';end if;
  if original.record_type<>'GENERAL' or original.review_status='CANCELLED' or original.expense_id is not null or original.payroll_entitlement_id is not null
   or coalesce(original.outflow_minor,0)<=0 or coalesce(original.completion->>'nature',original.classification->>'nature','')<>'EXPENSE' then
   raise exception 'Only active unposted expense sources may be assigned' using errcode='23514';end if;
  if original.allocation_scope is not distinct from item->>'scope' and original.assigned_project_id is not distinct from (item->>'project_id')::uuid then
   raise exception 'Assignment unchanged' using errcode='22023';end if;
  changes:=changes||jsonb_build_array(jsonb_build_object('source_id',original.id,'source_reference',original.source_reference,
   'previous_scope',original.allocation_scope,'previous_project_id',original.assigned_project_id,
   'scope',item->>'scope','project_id',item->>'project_id','previous_updated_at',original.updated_at,
   'previous_review_status',original.review_status));
  update public.historical_source_records set allocation_scope=item->>'scope',assigned_project_id=(item->>'project_id')::uuid,
   review_status='PENDING',updated_by=actor,updated_at=clock_timestamp() where id=original.id;
 end loop;
 insert into public.source_project_assignment_events(company_id,request_id,actor_id,reason,input_hash,changes)
 values(target_company_id,request_id,actor,normalized_reason,digest,changes) returning id into event_id;
 return jsonb_build_object('id',event_id,'company_id',target_company_id,'request_id',request_id,'count',jsonb_array_length(changes));
end;$$;
revoke all on function public.assign_source_projects(uuid,uuid,jsonb,text) from public,anon,authenticated,service_role;
grant execute on function public.assign_source_projects(uuid,uuid,jsonb,text) to authenticated;

-- Require explicit source completion review before new Expense recognition.
create or replace function public.post_historical_expense(target_company_id uuid,target_source_id uuid,business_input jsonb)
returns table(expense_id uuid,expense_reference text,journal_entry_id uuid,replayed boolean)
language plpgsql security definer set search_path='' as $$
declare r public.historical_source_records; result record; v jsonb:=business_input; gross bigint; vat bigint;
begin
 if auth.uid() is null or not public.has_permission(target_company_id,'accounting.post') then raise exception 'Denied' using errcode='42501';end if;
 select * into r from public.historical_source_records where company_id=target_company_id and id=target_source_id for update;
 if not found or r.record_type<>'GENERAL' or r.review_status<>'REVIEWED' or r.cash_treasury_id is null or coalesce(r.outflow_minor,0)<=0
 or coalesce(r.completion->>'nature',r.classification->>'nature')<>'EXPENSE' then raise exception 'Complete recognized expense source first' using errcode='23514';end if;
 -- An explicit source assignment must survive the canonical posting boundary.
 if r.allocation_scope is not null and (v->>'target_project_id')::uuid is distinct from r.assigned_project_id then
  raise exception 'Posting Project differs from reviewed assignment' using errcode='23514';end if;
 if (v->>'target_expense_date')::date is distinct from coalesce(nullif(r.completion->>'date','')::date,r.source_date)
 or btrim(v->>'target_description') is distinct from btrim(coalesce(r.completion->>'description',r.description)) then
  raise exception 'Save confirmed source date and description before posting' using errcode='23514';end if;
 if (v->>'target_treasury_account_id')::uuid is distinct from r.cash_treasury_id or v->>'target_funding_mode'<>'TREASURY' or v->>'target_payment_method'<>'CASH' then raise exception 'Confirmed cash source mismatch' using errcode='23514';end if;
 vat:=case v->>'target_vat_mode' when 'ZERO' then 0 when 'AUTO_5' then round((v->>'target_net_amount_minor')::numeric*5/100)::bigint else (v->>'target_manual_vat_amount_minor')::bigint end;
 gross:=(v->>'target_net_amount_minor')::bigint+vat;
 if gross is distinct from coalesce((r.completion->>'amount_minor')::bigint,r.outflow_minor) then raise exception 'Gross must match completed source outflow' using errcode='23514';end if;
 select * into result from public.post_expense(target_company_id,(v->>'target_expense_date')::date,(v->>'target_project_id')::uuid,(v->>'target_expense_category_id')::uuid,v->>'target_description',(v->>'target_net_amount_minor')::bigint,(v->>'target_vat_mode')::public.expense_vat_mode,(v->>'target_manual_vat_amount_minor')::bigint,'TREASURY',r.cash_treasury_id,null,(v->>'target_supplier_id')::uuid,'CASH',(v->>'target_has_tax_invoice')::boolean,v->>'target_invoice_number',v->>'target_notes',r.id);
 if r.expense_id is not null and r.expense_id<>result.expense_id then raise exception 'Source already linked';end if;
 if r.expense_id is null then update public.historical_source_records set expense_id=result.expense_id,updated_by=auth.uid(),updated_at=clock_timestamp() where id=r.id;end if;
 return query select result.expense_id,result.expense_reference,result.journal_entry_id,result.replayed;
end $$;

