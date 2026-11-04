-- PRJ-01: administrative closure, never financial-period closing or recognition.
create table public.project_closure_events (
 id uuid primary key default gen_random_uuid(),company_id uuid not null,project_id uuid not null,
 request_id uuid not null,actor_id uuid not null references auth.users(id) on delete restrict,
 effective_date date not null,reason text not null check(length(reason) between 1 and 500),
 previous_status public.project_status not null check(previous_status='COMPLETED'),new_status public.project_status not null default 'CLOSED' check(new_status='CLOSED'),
 previous_updated_at timestamptz not null,project_updated_at timestamptz not null,
 input_hash text not null,review_hash text not null,readiness jsonb not null,resolutions jsonb not null,
 recorded_at timestamptz not null default clock_timestamp(),
 unique(company_id,request_id),unique(company_id,project_id),
 foreign key(company_id,project_id) references public.projects(company_id,id) on delete restrict
);
alter table public.project_closure_events enable row level security;
alter table public.project_closure_events force row level security;
revoke all on public.project_closure_events from public,anon,authenticated,service_role;
grant select on public.project_closure_events to authenticated;
create policy project_closure_read on public.project_closure_events for select to authenticated using(
 (public.has_company_role(company_id,'ACCOUNTING_ADMIN') or public.has_company_role(company_id,'ACCOUNTANT'))
 and public.has_permission(company_id,'payroll.manage') and public.can_access_project(company_id,project_id));
create trigger project_closure_immutable before update or delete on public.project_closure_events
 for each row execute function private.protect_project_cost_correction();

-- All dimensioned journal insertions serialize with closure, including settlement.
-- Existing specialized reversals remain authorized by their original commands.
create function private.guard_closed_project_journal() returns trigger language plpgsql set search_path='' as $$
declare s public.project_status;j public.journal_entries;a public.accounts;begin
 if new.project_id is null then return new;end if;
 select status into s from public.projects where company_id=new.company_id and id=new.project_id for share;
 if not found then raise exception 'Company Project unavailable' using errcode='23503';end if;
 if s<>'CLOSED' then return new;end if;
 select * into j from public.journal_entries where company_id=new.company_id and id=new.journal_entry_id;
 if j.source_type='JOURNAL_REVERSAL' and j.reversal_of_journal_entry_id is not null then return new;end if;
 select * into a from public.accounts where company_id=new.company_id and id=new.account_id;
 if j.source_type in ('SUPPLIER_PAYMENT','SUBCONTRACTOR_PAYMENT','SUBCONTRACTOR_RETENTION_RELEASE','SUBCONTRACTOR_RETENTION_PAYMENT','CUSTODY_CASH_RETURN','SALARY_PAYMENT')
 and a.account_type<>'EXPENSE' then return new;end if;
 raise exception 'Closed Project cannot receive new recognition or cost allocation' using errcode='23514';
end;$$;
revoke all on function private.guard_closed_project_journal() from public,anon,authenticated,service_role;
create trigger journal_lines_closed_project before insert on public.journal_lines for each row execute function private.guard_closed_project_journal();

create function private.guard_closed_project_document() returns trigger language plpgsql set search_path='' as $$
declare data jsonb:=to_jsonb(new);before_data jsonb;pid uuid;begin
 if tg_op='UPDATE' then before_data:=to_jsonb(old);end if;
 if tg_table_name='payroll_profiles' then
  if data->>'status'='INACTIVE' then return new;end if;
  if tg_op='UPDATE' and (data->'default_project_id',data->'status',data->'monthly_salary_minor') is not distinct from (before_data->'default_project_id',before_data->'status',before_data->'monthly_salary_minor') then return new;end if;
  pid:=(data->>'default_project_id')::uuid;

 elsif tg_table_name='subcontractor_certificates' then
  if data->>'status'<>'DRAFT' then return new;end if;pid:=(data->>'project_id')::uuid;
 else
  if tg_op='UPDATE' and (data->'project_id',data->'original_contract_value_minor',data->'approved_variations_minor',data->'subcontractor_id') is not distinct from (before_data->'project_id',before_data->'original_contract_value_minor',before_data->'approved_variations_minor',before_data->'subcontractor_id') then return new;end if;
  pid:=(data->>'project_id')::uuid;
 end if;
 if pid is null then return new;end if;
 perform 1 from public.projects where company_id=new.company_id and id=pid and status<>'CLOSED' for share;
 if not found then raise exception 'Closed or unavailable Project cannot receive new operational documents' using errcode='23514';end if;
 return new;
end;$$;
revoke all on function private.guard_closed_project_document() from public,anon,authenticated,service_role;
create trigger subcontracts_closed_project before insert or update on public.subcontracts for each row execute function private.guard_closed_project_document();
create trigger certificates_closed_project before insert or update on public.subcontractor_certificates for each row execute function private.guard_closed_project_document();
create trigger payroll_profiles_closed_project before insert or update on public.payroll_profiles for each row execute function private.guard_closed_project_document();

-- Payroll draft default hints remain source evidence; only explicit financial allocations are assigned.
create function private.guard_closed_project_payroll_plan() returns trigger language plpgsql set search_path='' as $$
declare pid uuid;begin
 for pid in select distinct value::uuid from jsonb_each_text(new.allocations) where value is not null order by value::uuid loop
  perform 1 from public.projects where company_id=new.company_id and id=pid and status<>'CLOSED' for share;
  if not found then raise exception 'Closed or unavailable payroll allocation Project' using errcode='23514';end if;
 end loop;return new;
end;$$;
revoke all on function private.guard_closed_project_payroll_plan() from public,anon,authenticated,service_role;
create trigger payroll_plan_closed_project before insert on public.payroll_draft_accounting for each row execute function private.guard_closed_project_payroll_plan();

create function private.guard_closed_project_source() returns trigger language plpgsql set search_path='' as $$
declare pid uuid;a public.source_expense_allocation_events;before_data jsonb;data jsonb:=to_jsonb(new);begin
 if new.record_type<>'GENERAL' or new.review_status='CANCELLED' or new.expense_id is not null then return new;end if;
 if tg_op='UPDATE' then before_data:=to_jsonb(old);
  if (data->'assigned_project_id',data->'allocation_scope',data->'expense_allocation_id',data->'completion'->'project_id',data->'review_status',data->'completion'->'nature') is not distinct from
   (before_data->'assigned_project_id',before_data->'allocation_scope',before_data->'expense_allocation_id',before_data->'completion'->'project_id',before_data->'review_status',before_data->'completion'->'nature') then return new;end if;
 end if;
 if new.expense_allocation_id is not null then select * into a from public.source_expense_allocation_events where company_id=new.company_id and id=new.expense_allocation_id;end if;
 for pid in select distinct v from (
  select new.assigned_project_id v where new.allocation_scope='PROJECT'
  union all select (new.completion->>'project_id')::uuid where new.allocation_scope is null and new.expense_allocation_id is null and new.completion->>'project_id' is not null
  union all select (d->>'project_id')::uuid from jsonb_array_elements(coalesce(a.plan->'destinations','[]'::jsonb)) d where d->>'project_id' is not null
 ) p where v is not null order by v loop
  perform 1 from public.projects where company_id=new.company_id and id=pid and status<>'CLOSED' for share;
  if not found then raise exception 'Closed or unavailable Project cannot receive source assignments' using errcode='23514';end if;
 end loop;return new;
end;$$;
revoke all on function private.guard_closed_project_source() from public,anon,authenticated,service_role;
create trigger sources_closed_project before insert or update on public.historical_source_records for each row execute function private.guard_closed_project_source();

create function private.project_closure_readiness(cid uuid,pid uuid) returns jsonb language plpgsql stable set search_path='' as $$
declare p public.projects;deps jsonb;findings jsonb:='[]';contracts jsonb:='[]';item jsonb;s record;gross numeric;work numeric;revised numeric;n bigint;lines jsonb;begin
 select * into p from public.projects where company_id=cid and id=pid;
 if not found then raise exception 'Project unavailable' using errcode='42501';end if;
 deps:=private.project_lifecycle_dependencies(cid,pid)||jsonb_build_object('closure','ADMINISTRATIVE_REVIEW_ONLY');
 if p.status not in ('COMPLETED','CLOSED') then findings:=findings||jsonb_build_array(jsonb_build_object('key','STATUS','class','BLOCKING','count',1));end if;
 for item in select jsonb_build_object('key',k,'class','BLOCKING','count',v) from (values
 ('UNPOSTED_SOURCES',(deps->>'pending_sources')::bigint),('DRAFT_CERTIFICATES',(deps->>'draft_certificates')::bigint),('PENDING_CORRECTIONS',(deps->>'pending_corrections')::bigint)) t(k,v) where v>0 loop findings:=findings||jsonb_build_array(item);end loop;
 select count(*) into n from public.payroll_profiles where company_id=cid and default_project_id=pid and status='ACTIVE';
 if n>0 then findings:=findings||jsonb_build_array(jsonb_build_object('key','ACTIVE_PAYROLL_ASSIGNMENTS','class','BLOCKING','count',n));end if;
 select count(*) into n from public.payroll_draft_rows r where r.company_id=cid and (r.default_project_id=pid or exists(select 1 from public.payroll_draft_accounting a where a.company_id=cid and a.period_id=r.period_id and a.version=(select max(v.version) from public.payroll_draft_accounting v where v.company_id=cid and v.period_id=r.period_id) and a.allocations->>r.id::text=pid::text)) and r.included and not exists(select 1 from private.live_payroll_periods l where l.company_id=cid and l.payroll_id in (select id from public.payroll_postings where company_id=cid and period_id=r.period_id));
 if n>0 then findings:=findings||jsonb_build_array(jsonb_build_object('key','UNPOSTED_PAYROLL','class','BLOCKING','count',n));end if;
 -- No generic unposted journal table or purchase-order module exists in this model.
 -- Unknown posted sources and bank reconciliation gaps block only affected Projects.
 select count(distinct j.id) into n from public.journal_entries j join public.journal_lines l on l.company_id=j.company_id and l.journal_entry_id=j.id
 left join public.journal_entries o on o.company_id=j.company_id and o.id=j.reversal_of_journal_entry_id
 where l.company_id=cid and l.project_id=pid and coalesce(o.source_type,j.source_type) not in
 ('EXPENSE','SUPPLIER_PAYMENT','SUBCONTRACTOR_CERTIFICATE','SUBCONTRACTOR_ADVANCE','SUBCONTRACTOR_PAYMENT','SUBCONTRACTOR_RETENTION_RELEASE','SUBCONTRACTOR_RETENTION_PAYMENT','CUSTODY_ADVANCE','CUSTODY_CASH_RETURN','PAYROLL','SALARY_PAYMENT','PROJECT_COST_CORRECTION');
 if n>0 then findings:=findings||jsonb_build_array(jsonb_build_object('key','UNSUPPORTED_POSTED_SOURCE','class','BLOCKING','count',n));end if;
 select count(*) into n from public.journal_entries o where o.company_id=cid and exists(select 1 from public.journal_lines l join public.journal_entries j on j.company_id=l.company_id and j.id=l.journal_entry_id where l.company_id=cid and l.project_id=pid and coalesce(j.reversal_of_journal_entry_id,j.id)=o.id) and not case o.source_type
 when 'EXPENSE' then exists(select 1 from public.expenses d where d.company_id=cid and d.id=o.source_id and d.posted_journal_entry_id=o.id)
 when 'SUPPLIER_PAYMENT' then exists(select 1 from public.supplier_payments d where d.company_id=cid and d.id=o.source_id and d.posted_journal_entry_id=o.id)
 when 'SUBCONTRACTOR_CERTIFICATE' then exists(select 1 from public.subcontractor_certificates d where d.company_id=cid and d.id=o.source_id and d.posted_journal_entry_id=o.id)
 when 'SUBCONTRACTOR_ADVANCE' then exists(select 1 from public.subcontractor_advances d where d.company_id=cid and d.id=o.source_id and d.posted_journal_entry_id=o.id)
 when 'SUBCONTRACTOR_PAYMENT' then exists(select 1 from public.subcontractor_payments d where d.company_id=cid and d.id=o.source_id and d.posted_journal_entry_id=o.id)
 when 'SUBCONTRACTOR_RETENTION_RELEASE' then exists(select 1 from public.subcontractor_retention_releases d where d.company_id=cid and d.id=o.source_id and d.posted_journal_entry_id=o.id)
 when 'SUBCONTRACTOR_RETENTION_PAYMENT' then exists(select 1 from public.subcontractor_retention_payments d where d.company_id=cid and d.id=o.source_id and d.posted_journal_entry_id=o.id)
 when 'CUSTODY_ADVANCE' then exists(select 1 from public.custody_advances d where d.company_id=cid and d.id=o.source_id and d.posted_journal_entry_id=o.id)
 when 'CUSTODY_CASH_RETURN' then exists(select 1 from public.custody_cash_returns d where d.company_id=cid and d.id=o.source_id and d.posted_journal_entry_id=o.id)
 when 'PAYROLL' then exists(select 1 from public.payroll_postings d where d.company_id=cid and d.id=o.source_id and d.journal_id=o.id)
 when 'SALARY_PAYMENT' then exists(select 1 from public.salary_payments d where d.company_id=cid and d.id=o.source_id and d.journal_id=o.id)
 when 'PROJECT_COST_CORRECTION' then exists(select 1 from public.project_cost_corrections d where d.company_id=cid and d.id=o.source_id and d.journal_entry_id=o.id)
 else false end;
 if n>0 then findings:=findings||jsonb_build_array(jsonb_build_object('key','SOURCE_TRACEABILITY_UNVERIFIED','class','BLOCKING','count',n));end if;
 select count(distinct j.id) into n from public.journal_entries j join public.journal_lines cost on cost.company_id=j.company_id and cost.journal_entry_id=j.id
 join public.journal_lines cash on cash.company_id=j.company_id and cash.journal_entry_id=j.id join public.treasury_accounts t on t.company_id=cash.company_id and t.id=cash.treasury_account_id
 where cost.company_id=cid and cost.project_id=pid and t.type='BANK';
 if n>0 then findings:=findings||jsonb_build_array(jsonb_build_object('key','BANK_RECONCILIATION_UNSUPPORTED','class','BLOCKING','count',n));end if;
 -- Reject partial/corrupt capture instead of pretending operational records are GL truth.
 select count(*) into n from public.journal_entries j where j.company_id=cid and exists(select 1 from public.journal_lines l where l.company_id=cid and l.journal_entry_id=j.id and l.project_id=pid)
 and ((select count(*) from public.journal_lines l where l.company_id=cid and l.journal_entry_id=j.id)<2 or
 (select coalesce(sum(l.debit_minor::numeric-l.credit_minor::numeric),0) from public.journal_lines l where l.company_id=cid and l.journal_entry_id=j.id)<>0);
 if n>0 then findings:=findings||jsonb_build_array(jsonb_build_object('key','JOURNAL_INTEGRITY','class','BLOCKING','count',n));end if;
 for s in select * from public.subcontracts where company_id=cid and project_id=pid order by id loop
  select coalesce(sum(gross_certified_minor),0),coalesce(max(work_value_to_date_minor),0) into gross,work from public.subcontractor_certificates where company_id=cid and subcontract_id=s.id and status='POSTED';
  revised:=s.original_contract_value_minor::numeric+s.approved_variations_minor::numeric;
  contracts:=contracts||jsonb_build_array(jsonb_build_object('id',s.id,'reference',s.contract_number,'status',s.status,'revised_minor',revised::text,'certified_minor',gross::text,'work_to_date_minor',work::text));
  if revised>0 and gross=revised and work=revised then
   if s.status<>'CLOSED' then findings:=findings||jsonb_build_array(jsonb_build_object('key','CONTRACT:'||s.id,'class','REQUIRES_RESOLUTION','count',1,'reference',s.contract_number));end if;
  else findings:=findings||jsonb_build_array(jsonb_build_object('key','CONTRACT_WORK_UNVERIFIED:'||s.id,'class','BLOCKING','count',1,'reference',s.contract_number));end if;
 end loop;
 -- Missing Project dimensions on the same Subcontracts cannot be guessed away.
 select count(*) into n from public.journal_lines l join public.subcontracts sc on sc.company_id=l.company_id and sc.id=l.subcontract_id where sc.company_id=cid and sc.project_id=pid and l.project_id is distinct from pid;
 if n>0 then findings:=findings||jsonb_build_array(jsonb_build_object('key','SUBCONTRACT_DIMENSION_MISMATCH','class','BLOCKING','count',n));end if;
 for item in select value from jsonb_array_elements(deps->'obligations') loop
  if item->>'category' in ('SUPPLIER_PAYABLE','SUBCONTRACTOR_PAYABLE','SUBCONTRACTOR_RETENTION_PAYABLE','SALARY_PAYABLE') and (item->>'balance_minor')::numeric<0 then
   findings:=findings||jsonb_build_array(jsonb_build_object('key','OBLIGATION:'||(item->>'account_code')||':'||coalesce(item->>'subcontract_id','-')||':'||coalesce(item->>'party_id','-'),'class','PERMITTED_OUTSTANDING','count',1,'obligation',item));
  else findings:=findings||jsonb_build_array(jsonb_build_object('key','UNRESOLVED_BALANCE:'||(item->>'account_code')||':'||coalesce(item->>'subcontract_id','-')||':'||coalesce(item->>'party_id','-'),'class','BLOCKING','count',1,'obligation',item));end if;
 end loop;
 select count(distinct journal_entry_id) into n from public.journal_lines where company_id=cid and project_id=pid;
 if n>0 then findings:=findings||jsonb_build_array(jsonb_build_object('key','FINANCIAL_REVIEW','class','REQUIRES_RESOLUTION','count',n));end if;
 return jsonb_build_object('project_id',pid,'status',p.status,'dependencies',deps,'contracts',contracts,'findings',findings,
 'coverage',jsonb_build_object('journals','POSTED_ONLY_NO_GENERIC_DRAFT_JOURNALS','purchase_orders','NOT_IMPLEMENTED_NOT_CERTIFIED','bank_reconciliation','UNSUPPORTED_CASES_BLOCKED','periods','EXISTING_PERIOD_RULES_UNCHANGED_NO_FISCAL_CLOSE','source_mapping','EXPLICIT_STORED_DIMENSIONS_ONLY'),
 'blocking_count',(select count(*) from jsonb_array_elements(findings) f where f->>'class'='BLOCKING'));
end;$$;
revoke all on function private.project_closure_readiness(uuid,uuid) from public,anon,authenticated,service_role;

create function private.normalize_closure_resolutions(value jsonb,readiness jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
declare item jsonb;result jsonb:='[]';k text;ref text;why text;begin
 if value is null or jsonb_typeof(value)<>'array' or jsonb_array_length(value)>200 then raise exception 'Invalid closure resolutions' using errcode='22023';end if;
 for item in select v from jsonb_array_elements(value) v order by v->>'key' loop
  k:=item->>'key';ref:=private.correction_text(item->>'reference');why:=private.correction_text(item->>'reason');
  if jsonb_typeof(item)<>'object' or item-array['key','reference','reason']<>'{}'::jsonb or jsonb_typeof(item->'key') is distinct from 'string' or jsonb_typeof(item->'reference') is distinct from 'string' or jsonb_typeof(item->'reason') is distinct from 'string' or k is null or ref is null or why is null or length(ref)>500 or length(why)>500
  or not exists(select 1 from jsonb_array_elements(readiness->'findings') f where f->>'key'=k and f->>'class'='REQUIRES_RESOLUTION')
  or exists(select 1 from jsonb_array_elements(result) r where r->>'key'=k) then raise exception 'Resolution must document a supported finding; blockers cannot be waived' using errcode='22023';end if;
  result:=result||jsonb_build_array(jsonb_build_object('key',k,'reference',ref,'reason',why));
 end loop;return result;
end;$$;
revoke all on function private.normalize_closure_resolutions(jsonb,jsonb) from public,anon,authenticated,service_role;

create function public.preview_project_closure(target_company_id uuid,target_project_id uuid,expected_updated_at timestamptz)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.projects;r jsonb;begin
 perform private.project_lifecycle_actor(target_company_id);
 select * into p from public.projects where company_id=target_company_id and id=target_project_id for share;
 if not found then raise exception 'Project unavailable' using errcode='42501';end if;
 if expected_updated_at is null or p.updated_at<>expected_updated_at then raise exception 'Project changed' using errcode='40001';end if;
 r:=private.project_closure_readiness(target_company_id,target_project_id);
 return jsonb_build_object('company_id',p.company_id,'project_id',p.id,'project_code',p.code,'project_name',p.name,'updated_at',p.updated_at,'status',p.status,
 'effective_date',(current_timestamp at time zone 'Asia/Dubai')::date,'captured_at',clock_timestamp(),'readiness',r,'review_hash',encode(extensions.digest(r::text,'sha256'),'hex'));
end;$$;
revoke all on function public.preview_project_closure(uuid,uuid,timestamptz) from public,anon,authenticated,service_role;
grant execute on function public.preview_project_closure(uuid,uuid,timestamptz) to authenticated;

create function public.close_project(target_company_id uuid,target_project_id uuid,expected_updated_at timestamptz,request_id uuid,
 effective_date date,reason text,review_hash text,resolutions jsonb,outstanding_acknowledged boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;p public.projects;changed public.projects;prior public.project_closure_events;r jsonb;resolved jsonb;digest text;why text:=private.correction_text(reason);begin
 actor:=private.project_lifecycle_actor(target_company_id);
 if target_project_id is null or expected_updated_at is null or request_id is null or effective_date is null or why is null or length(why)>500 or review_hash is null or review_hash!~'^[0-9a-f]{64}$' or outstanding_acknowledged is distinct from true then raise exception 'Explicit closure confirmation required' using errcode='22023';end if;
 -- Normalize a replay using its immutable reviewed facts, not today's changed balances.
 perform pg_advisory_xact_lock(hashtextextended('project-closure:'||target_company_id::text||':'||request_id::text,0));
 select * into prior from public.project_closure_events e where e.company_id=target_company_id and e.request_id=close_project.request_id;
 if found then r:=prior.readiness;else r:=private.project_closure_readiness(target_company_id,target_project_id);end if;
 resolved:=private.normalize_closure_resolutions(resolutions,r);
 digest:=encode(extensions.digest(jsonb_build_object('company',target_company_id,'project',target_project_id,'actor',actor,'version',extract(epoch from expected_updated_at),'date',effective_date,'reason',why,'review',review_hash,'resolutions',resolved,'acknowledged',true)::text,'sha256'),'hex');
 if prior.id is not null then
  if prior.input_hash<>digest or prior.actor_id<>actor then raise exception 'Closure request does not match' using errcode='22023';end if;
  return jsonb_build_object('id',prior.id,'company_id',prior.company_id,'project_id',prior.project_id,'request_id',prior.request_id,'status','CLOSED','updated_at',prior.project_updated_at);
 end if;
 select * into p from public.projects where company_id=target_company_id and id=target_project_id for update;
 if not found then raise exception 'Project unavailable' using errcode='42501';end if;
 if p.updated_at<>expected_updated_at then raise exception 'Project changed' using errcode='40001';end if;
 r:=private.project_closure_readiness(target_company_id,target_project_id);
 if encode(extensions.digest(r::text,'sha256'),'hex')<>review_hash then raise exception 'Closure dependencies changed; review again' using errcode='40001';end if;
 if p.status<>'COMPLETED' or (r->>'blocking_count')::bigint>0 then raise exception 'Unresolved closure blockers' using errcode='23514';end if;
 resolved:=private.normalize_closure_resolutions(resolutions,r);
 if exists(select 1 from jsonb_array_elements(r->'findings') f where f->>'class'='REQUIRES_RESOLUTION' and not exists(select 1 from jsonb_array_elements(resolved) d where d->>'key'=f->>'key')) then raise exception 'Document every required closure resolution' using errcode='23514';end if;
 if effective_date<>(current_timestamp at time zone 'Asia/Dubai')::date then raise exception 'Closure takes effect today; no retrospective financial lock' using errcode='22023';end if;
 update public.projects set status='CLOSED',updated_by=actor where company_id=target_company_id and id=target_project_id returning * into changed;
 if (to_jsonb(p)-array['status','updated_at','updated_by']) is distinct from (to_jsonb(changed)-array['status','updated_at','updated_by']) then raise exception 'Review Project metadata before closure' using errcode='23514';end if;
 insert into public.project_closure_events(company_id,project_id,request_id,actor_id,effective_date,reason,previous_status,previous_updated_at,project_updated_at,input_hash,review_hash,readiness,resolutions)
 values(target_company_id,target_project_id,request_id,actor,effective_date,why,p.status,p.updated_at,changed.updated_at,digest,review_hash,r,resolved) returning * into prior;
 return jsonb_build_object('id',prior.id,'company_id',prior.company_id,'project_id',prior.project_id,'request_id',prior.request_id,'status','CLOSED','updated_at',prior.project_updated_at);
end;$$;
revoke all on function public.close_project(uuid,uuid,timestamptz,uuid,date,text,text,jsonb,boolean) from public,anon,authenticated,service_role;
grant execute on function public.close_project(uuid,uuid,timestamptz,uuid,date,text,text,jsonb,boolean) to authenticated;
