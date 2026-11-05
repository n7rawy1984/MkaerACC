-- 83: evidence-to-existing Expense draft integration. No backfill or financial data mutation.
create table public.historical_expense_drafts(
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id),
 source_id uuid not null,draft_id uuid not null,initial_event_id uuid not null,created_by uuid not null references auth.users(id),
 created_at timestamptz not null default clock_timestamp(),released_at timestamptz,
 unique(company_id,draft_id),foreign key(company_id,source_id) references public.historical_source_records(company_id,id),
 foreign key(company_id,initial_event_id) references public.expense_draft_events(company_id,id)
);
create unique index historical_one_active_cost_draft on public.historical_expense_drafts(company_id,source_id) where released_at is null;
create table public.historical_expense_reviews(
 id uuid primary key default gen_random_uuid(),company_id uuid not null,source_id uuid not null,draft_event_id uuid not null,
 source_updated_at timestamptz not null,confirmations jsonb not null,reason text not null,created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 foreign key(company_id,source_id) references public.historical_source_records(company_id,id),foreign key(company_id,draft_event_id) references public.expense_draft_events(company_id,id),unique(company_id,draft_event_id)
);
do $$declare t text;begin foreach t in array array['historical_expense_drafts','historical_expense_reviews'] loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);execute format('grant select on public.%I to authenticated',t);
 execute format('create policy source_document_read on public.%I for select to authenticated using(public.has_company_role(company_id,''ACCOUNTING_ADMIN'') or public.has_company_role(company_id,''ACCOUNTANT'') or public.has_company_role(company_id,''MANAGEMENT_VIEWER''))',t);
 end loop;end$$;
create trigger historical_reviews_immutable before update or delete on public.historical_expense_reviews for each row execute function private.financial_evidence_immutable();
create function private.guard_historical_draft_binding() returns trigger language plpgsql set search_path='' as $$begin
 if tg_op='DELETE' then raise exception 'Source lineage is immutable' using errcode='23514';end if;
 if (to_jsonb(new)-'released_at') is distinct from (to_jsonb(old)-'released_at') or old.released_at is not null or new.released_at is null
 or not exists(select 1 from public.expense_draft_events e where e.company_id=old.company_id and e.draft_id=old.draft_id and e.state='CANCELLED') then raise exception 'Only canonical draft cancellation releases a source claim' using errcode='23514';end if;
 return new;end$$;
revoke all on function private.guard_historical_draft_binding() from public,anon,authenticated,service_role;
create trigger historical_binding_guard before update or delete on public.historical_expense_drafts for each row execute function private.guard_historical_draft_binding();
-- Keep the existing implementation private; both public entry points share source locks.
alter function public.command_expense_draft(uuid,uuid,integer,uuid,text,jsonb,text) set schema private;
alter function private.command_expense_draft(uuid,uuid,integer,uuid,text,jsonb,text) rename to command_expense_draft_v80;
revoke all on function private.command_expense_draft_v80(uuid,uuid,integer,uuid,text,jsonb,text) from public,anon,authenticated,service_role;
-- Forward compatibility correction: a Project Bank uses BANK payment metadata, not CASH.
create or replace function private.command_expense_draft_v80(cid uuid,draft uuid,expected_version integer,request_id uuid,action text,input jsonb,reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
declare actor uuid; prev public.expense_draft_events; replay public.expense_draft_events; r public.expense_draft_events;
 v jsonb;h text;k text;summary jsonb;result jsonb; e jsonb;x record;new_state text; eid uuid;
begin
 actor:=private.operational_finance_actor(cid,'accounting.post');
 if draft is null or expected_version is null or expected_version<0 or request_id is null or action is null or action not in ('SAVE','REVIEW','CANCEL','POST') or input is null or jsonb_typeof(input)<>'object' or coalesce(length(btrim(reason)),0) not between 1 and 2000 then raise exception 'Draft command inputs required' using errcode='22023';end if;
 h:=encode(extensions.digest(convert_to(jsonb_build_object('draft',draft,'version',expected_version,'action',action,'input',input,'reason',btrim(reason),'actor',actor)::text,'UTF8'),'sha256'),'hex');
 perform private.serialize_operational_finance(cid,'OPERATIONS');
 select * into replay from public.expense_draft_events t where t.company_id=cid and t.request_id=request_id;
 if found then
  if replay.request_hash<>h then raise exception 'Request key reused with changed intent' using errcode='22023';end if;
  return to_jsonb(replay);
 end if;
 select * into prev from public.expense_draft_events t where t.company_id=cid and t.draft_id=draft order by t.version desc limit 1;
 if coalesce(prev.version,0)<>expected_version then raise exception 'Draft changed; reload latest version' using errcode='40001';end if;
 if prev.state in ('POSTED','CANCELLED') then raise exception 'Final draft cannot be changed; use canonical reversal for posted financial documents' using errcode='23514';end if;
 if action='SAVE' then
  v:=input;
  if pg_column_size(v)>24000 then raise exception 'Draft too large' using errcode='22023';end if;
  for k in select jsonb_object_keys(v) loop
   if k<>all(array['date','period_month','description','project_id','category_id','supplier_id','funding_mode','treasury_id','paid_by_id','has_invoice','invoice_number','supporting_reference','source_reference','notes','nature','net_aed','vat_mode','vat_aed','original_cost_not_posted']) or jsonb_typeof(v->k) not in ('string','boolean','null') or length(v->>k)>2000 then raise exception 'Unsupported draft input' using errcode='22023';end if;
  end loop;
  new_state:='DRAFT';
 else
  if prev.id is null or input<>'{}'::jsonb then raise exception 'Save the draft first; actions accept no replacement financial inputs' using errcode='23514';end if;
  v:=prev.snapshot;new_state:=case action when 'CANCEL' then 'CANCELLED' when 'REVIEW' then 'REVIEWED' else 'POSTED' end;
  if action in ('REVIEW','POST') then summary:=private.validate_expense_draft(cid,v);end if;
  if action='POST' then
   if prev.state<>'REVIEWED' then raise exception 'Review the current draft version before posting' using errcode='23514';end if;
   -- Reuse canonical original evidence uniqueness across expense drafts, including no-invoice sources.
   perform pg_advisory_xact_lock(hashtextextended('expense-source:'||cid::text||':'||lower(btrim(v->>'source_reference')),0));
   if exists(select 1 from public.expense_draft_events t where t.company_id=cid and t.state='POSTED' and lower(btrim(t.snapshot->>'source_reference'))=lower(btrim(v->>'source_reference'))) then raise exception 'Original expense source already posted; inspect existing document' using errcode='23505';end if;
   if v->>'funding_mode'='PERSONAL' then
    e:=public.submit_financial_operation_evidence(cid,request_id,jsonb_build_object('kind','PERSONAL_EXPENSE','event_date',v->>'date','counterparty_id',v->>'paid_by_id','project_id',nullif(v->>'project_id',''),'amount_minor',summary->>'gross_minor','classification','PERSONAL_FUNDS','destination','PERSONAL_FUNDS','source_reference',v->>'source_reference','description',v->>'description','supporting_reference',v->>'supporting_reference'));
    eid:=(e->>'id')::uuid;
    perform public.review_financial_operation_evidence(cid,request_id,eid,'REVIEWED',reason);
    result:=public.post_reviewed_financial_operation(cid,request_id,eid,jsonb_build_object('net_minor',summary->>'net_minor','vat_mode',v->>'vat_mode','manual_vat_minor',case when v->>'vat_mode'='MANUAL' then summary->>'vat_minor' end,'expense_category_id',v->>'category_id','supplier_id',nullif(v->>'supplier_id',''),'invoice_number',nullif(btrim(v->>'invoice_number'),''),'has_tax_invoice',coalesce((v->>'has_invoice')::boolean,false),'original_cost_not_posted',true,'cost_classification',v->>'nature','approval_reference',reason));
   else
    select * into x from public.post_expense(cid,(v->>'date')::date,nullif(v->>'project_id','')::uuid,(v->>'category_id')::uuid,btrim(v->>'description'),(summary->>'net_minor')::bigint,(v->>'vat_mode')::public.expense_vat_mode,case when v->>'vat_mode'='MANUAL' then (summary->>'vat_minor')::bigint end,(v->>'funding_mode')::public.expense_funding_mode,nullif(v->>'treasury_id','')::uuid,nullif(v->>'paid_by_id','')::uuid,nullif(v->>'supplier_id','')::uuid,case when v->>'funding_mode'='TREASURY' and exists(select 1 from public.treasury_accounts where company_id=cid and id=(v->>'treasury_id')::uuid and type in ('BANK','PROJECT_BANK')) then 'BANK'::public.payment_method else 'CASH'::public.payment_method end,coalesce((v->>'has_invoice')::boolean,false),nullif(btrim(v->>'invoice_number'),''),left(concat_ws(E'\n',v->>'source_reference',v->>'supporting_reference',v->>'notes'),2000),request_id);
    result:=jsonb_build_object('id',x.expense_id,'reference',x.expense_reference,'journal',x.journal_entry_id,'replayed',x.replayed);
   end if;
  end if;
 end if;
 insert into public.expense_draft_events(company_id,draft_id,version,request_id,request_hash,state,snapshot,preview,receipt,reason,created_by)
 values(cid,draft,expected_version+1,request_id,h,new_state,v,summary,result,btrim(reason),actor) returning * into r;
 return to_jsonb(r);
end;$$;

create function public.command_expense_draft(cid uuid,draft uuid,expected_version integer,request_id uuid,action text,input jsonb,reason text)
returns jsonb language plpgsql volatile security definer set search_path='' as $$begin
 perform private.operational_finance_actor(cid,'accounting.post');perform private.serialize_operational_finance(cid,'OPERATIONS');
 if exists(select 1 from public.historical_expense_drafts b where b.company_id=cid and b.draft_id=draft) or upper(btrim(coalesce(input->>'source_reference',''))) like 'HISTORICAL:%' or exists(select 1 from public.expense_draft_events e where e.company_id=cid and e.draft_id=draft and upper(btrim(e.snapshot->>'source_reference')) like 'HISTORICAL:%') then raise exception 'Use the linked imported-source workflow for this draft' using errcode='23514';end if;
 return private.command_expense_draft_v80(cid,draft,expected_version,request_id,action,input,reason);end$$;
revoke all on function public.command_expense_draft(uuid,uuid,integer,uuid,text,jsonb,text) from public,anon,authenticated,service_role;
grant execute on function public.command_expense_draft(uuid,uuid,integer,uuid,text,jsonb,text) to authenticated;

create function public.command_source_expense_draft(cid uuid,source_id uuid,draft uuid,expected_version integer,request_id uuid,action text,input jsonb,reason text,confirmations jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
#variable_conflict use_variable
declare actor uuid;s public.historical_source_records;b public.historical_expense_drafts;p public.expense_draft_events;replay public.expense_draft_events;
 r jsonb;v jsonb;attaching boolean:=action='ATTACH';attach_snapshot jsonb;review public.historical_expense_reviews;summary jsonb;duplicate_group boolean;key text;
begin
 actor:=private.operational_finance_actor(cid,'accounting.post');perform private.serialize_operational_finance(cid,'OPERATIONS');
 select * into s from public.historical_source_records h where h.company_id=cid and h.id=source_id for update;
 if not found or s.record_type<>'GENERAL' then raise exception 'Same-Company General source required' using errcode='42501';end if;
 if source_id is null or draft is null or confirmations is null or jsonb_typeof(confirmations)<>'object' or octet_length(confirmations::text)>6000 then raise exception 'Invalid source confirmation' using errcode='22023';end if;
 for key in select jsonb_object_keys(confirmations) loop
 if key<>all(array['owner','payment','distinct','duplicate_clearance']) then raise exception 'Unsupported confirmation' using errcode='22023';end if;end loop;
 if attaching then
  if input<>'{}'::jsonb or expected_version<1 then raise exception 'Attach accepts an existing unposted draft version, not replacement business inputs' using errcode='23514';end if;
  select snapshot into attach_snapshot from public.expense_draft_events e where e.company_id=cid and e.draft_id=draft and e.version=expected_version and e.state in ('DRAFT','REVIEWED');
  if attach_snapshot is null or upper(btrim(attach_snapshot->>'source_reference')) like 'HISTORICAL:%' then raise exception 'Select an unbound same-Company unposted draft' using errcode='23514';end if;
  input:=attach_snapshot;action:='SAVE';
 end if;
 select * into b from public.historical_expense_drafts h where h.company_id=cid and h.draft_id=draft;
 if found and b.source_id<>source_id then raise exception 'Draft belongs to another source' using errcode='23514';end if;
 -- A replay must reproduce the same source, immutable draft intent AND confirmations.
 select * into replay from public.expense_draft_events e where e.company_id=cid and e.request_id=request_id;
 v:=case when action='SAVE' then input||jsonb_build_object('source_reference','HISTORICAL:'||source_id::text) else input end;
 if replay.id is not null then
  if b.id is null or b.source_id<>source_id then raise exception 'Request belongs to another workflow' using errcode='23514';end if;
  r:=private.command_expense_draft_v80(cid,draft,expected_version,request_id,action,v,reason);
  if action='REVIEW' and not exists(select 1 from public.historical_expense_reviews x where x.company_id=cid and x.draft_event_id=replay.id and x.confirmations=confirmations) then raise exception 'Review confirmation changed on retry' using errcode='22023';end if;
  return r;
 end if;
 if s.review_status='CANCELLED' or s.expense_id is not null or s.payroll_entitlement_id is not null then raise exception 'Archived or financially linked source cannot create another cost' using errcode='23514';end if;
 if s.expense_allocation_id is not null then raise exception 'Use the existing confirmed split-source posting workflow; conversion does not discard allocations' using errcode='23514';end if;
 if b.id is null then
  if coalesce(s.completion->>'nature',s.classification->>'nature','NEEDS_REVIEW') not in ('EXPENSE','NEEDS_REVIEW') then raise exception 'Use the source classification destination; this is not an original Expense conversion' using errcode='23514';end if;
  if action<>'SAVE' or not attaching and (expected_version<>0 or exists(select 1 from public.expense_draft_events e where e.company_id=cid and e.draft_id=draft)) or exists(select 1 from public.historical_expense_drafts h where h.company_id=cid and h.source_id=source_id and h.released_at is null) then raise exception 'Open the existing source draft; do not create a second cost' using errcode='23514';end if;
 elsif b.released_at is not null then raise exception 'Cancelled source draft is retained; create a new reviewed claim through its source' using errcode='23514';end if;
 select * into p from public.expense_draft_events e where e.company_id=cid and e.draft_id=draft order by version desc limit 1;
 if action in ('REVIEW','POST') then
  if coalesce(s.completion->>'nature',s.classification->>'nature','NEEDS_REVIEW') not in ('EXPENSE','NEEDS_REVIEW') then raise exception 'Source classification requires its existing non-Expense workflow' using errcode='23514';end if;
  if s.review_status<>'REVIEWED' or s.classification->>'source_ownership'='PROVISIONAL_MAKER_REVIEW_ONLY' and confirmations->'owner' is distinct from 'true'::jsonb and action='REVIEW' then raise exception 'Confirm accounting owner and complete the source review first' using errcode='23514';end if;
  if action='REVIEW' then
   if confirmations->'owner' is distinct from 'true'::jsonb or confirmations->'payment' is distinct from 'true'::jsonb or confirmations->'distinct' is distinct from 'true'::jsonb then raise exception 'Confirm legal Company, actual payment evidence and distinct original cost' using errcode='23514';end if;
   duplicate_group:=coalesce((s.classification->>'potential_duplicate')::boolean,false) or case when jsonb_typeof(s.raw_source->'existing_match_candidates_unverified')='array' then jsonb_array_length(s.raw_source->'existing_match_candidates_unverified')>0 else false end or exists(select 1 from public.historical_source_records h where h.company_id=cid and h.source_file=s.source_file and h.classification->>'duplicate_candidate_source_reference'=s.source_reference);
   if duplicate_group and coalesce(length(btrim(confirmations->>'duplicate_clearance')),0)<5 then raise exception 'Document distinct-payment evidence for this duplicate group; no second financial effect from a repeated source' using errcode='23514';end if;
  else
   select * into review from public.historical_expense_reviews x where x.company_id=cid and x.draft_event_id=p.id;
   if review.id is null or review.source_updated_at<>s.updated_at then raise exception 'Source changed or source review missing; review the draft again' using errcode='40001';end if;
  end if;
  summary:=private.validate_expense_draft(cid,p.snapshot);
  if nullif(p.snapshot->>'source_reference','') is distinct from 'HISTORICAL:'||source_id::text
   or nullif(p.snapshot->>'date','')::date is distinct from coalesce(nullif(s.completion->>'date','')::date,s.source_date)
   or (summary->>'gross_minor')::bigint is distinct from coalesce(nullif(s.completion->>'amount_minor','')::bigint,s.outflow_minor)
   or btrim(p.snapshot->>'description') is distinct from btrim(coalesce(s.completion->>'description',s.description)) then raise exception 'Confirm matching source date, description and gross amount in source review; original evidence stays unchanged' using errcode='23514';end if;
  if s.allocation_scope is not null and nullif(p.snapshot->>'project_id','')::uuid is distinct from s.assigned_project_id then raise exception 'Project differs from reviewed source assignment' using errcode='23514';end if;
  if p.snapshot->>'funding_mode'='SUPPLIER_CREDIT' then raise exception 'An outgoing source is not an unpaid invoice; use Supplier credit only for an actual unpaid source workflow' using errcode='23514';end if;
 end if;
 r:=private.command_expense_draft_v80(cid,draft,expected_version,request_id,action,v,reason);
 if b.id is null then insert into public.historical_expense_drafts(company_id,source_id,draft_id,initial_event_id,created_by) values(cid,source_id,draft,(r->>'id')::uuid,actor);end if;
 if action='REVIEW' then insert into public.historical_expense_reviews(company_id,source_id,draft_event_id,source_updated_at,confirmations,reason,created_by) values(cid,source_id,(r->>'id')::uuid,s.updated_at,confirmations,reason,actor);end if;
 if action='CANCEL' then update public.historical_expense_drafts h set released_at=clock_timestamp() where h.company_id=cid and h.draft_id=draft;end if;
 if action='POST' and p.snapshot->>'funding_mode'<>'PERSONAL' then update public.historical_source_records h set expense_id=(r->'receipt'->>'id')::uuid,updated_by=actor,updated_at=clock_timestamp() where h.company_id=cid and h.id=source_id;end if;
 return r;
end$$;
revoke all on function public.command_source_expense_draft(uuid,uuid,uuid,integer,uuid,text,jsonb,text,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.command_source_expense_draft(uuid,uuid,uuid,integer,uuid,text,jsonb,text,jsonb) to authenticated;

alter function public.post_historical_expense(uuid,uuid,jsonb) set schema private;
alter function private.post_historical_expense(uuid,uuid,jsonb) rename to post_historical_expense_v71;
revoke all on function private.post_historical_expense_v71(uuid,uuid,jsonb) from public,anon,authenticated,service_role;
create function public.post_historical_expense(target_company_id uuid,target_source_id uuid,business_input jsonb)
returns table(expense_id uuid,expense_reference text,journal_entry_id uuid,replayed boolean)
language plpgsql volatile security definer set search_path='' as $$begin
 perform private.operational_finance_actor(target_company_id,'accounting.post');perform private.serialize_operational_finance(target_company_id,'OPERATIONS');
 perform 1 from public.historical_source_records where company_id=target_company_id and id=target_source_id for update;
 if exists(select 1 from public.historical_expense_drafts b where b.company_id=target_company_id and b.source_id=target_source_id and b.released_at is null) then raise exception 'Use the existing canonical source-linked draft; a second recognition is prohibited' using errcode='23514';end if;
 return query select * from private.post_historical_expense_v71(target_company_id,target_source_id,business_input);end$$;
revoke all on function public.post_historical_expense(uuid,uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.post_historical_expense(uuid,uuid,jsonb) to authenticated;
create function public.read_source_document_links(cid uuid,source_ids uuid[]) returns jsonb
language plpgsql stable security definer set search_path='' as $$declare r jsonb;begin
 if auth.uid() is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN') or public.has_company_role(cid,'ACCOUNTANT') or public.has_company_role(cid,'MANAGEMENT_VIEWER')) then raise exception 'Source document read denied' using errcode='42501';end if;
 if coalesce(cardinality(source_ids),0)>500 then raise exception 'Too many sources' using errcode='22023';end if;
 select coalesce(jsonb_agg(jsonb_build_object('source_id',b.source_id,'draft_id',b.draft_id,'event',to_jsonb(e),'reversed',coalesce(x.status='REVERSED',false) or exists(select 1 from public.operational_liability_reversals rv where rv.company_id=cid and rv.posting_id=(e.receipt->>'id')::uuid))), '[]') into r
 from public.historical_expense_drafts b join public.historical_source_records s on s.company_id=b.company_id and s.id=b.source_id
 cross join lateral(select * from public.expense_draft_events e where e.company_id=b.company_id and e.draft_id=b.draft_id order by version desc limit 1)e
 left join public.expenses x on x.company_id=cid and x.id=(e.receipt->>'id')::uuid
 where b.company_id=cid and b.source_id=any(source_ids) and b.released_at is null and s.record_type='GENERAL';
 return r;end$$;
revoke all on function public.read_source_document_links(uuid,uuid[]) from public,anon,authenticated,service_role;
grant execute on function public.read_source_document_links(uuid,uuid[]) to authenticated;
-- A posted linked cost cannot be reassigned through administrative source edits.
create function private.guard_posted_source_document() returns trigger language plpgsql set search_path='' as $$begin
 if exists(select 1 from public.historical_expense_drafts b join lateral(select state from public.expense_draft_events e where e.company_id=b.company_id and e.draft_id=b.draft_id order by version desc limit 1)e on true where b.company_id=old.company_id and b.source_id=old.id and b.released_at is null and e.state='POSTED')
 and (new.assigned_project_id is distinct from old.assigned_project_id or new.allocation_scope is distinct from old.allocation_scope or new.expense_allocation_id is distinct from old.expense_allocation_id or (new.completion-array['notes','reason']) is distinct from (old.completion-array['notes','reason'])) then raise exception 'Posted source cost is immutable; use canonical reversal/correction' using errcode='23514';end if;
 return new;end$$;
revoke all on function private.guard_posted_source_document() from public,anon,authenticated,service_role;
create trigger source_posted_document_guard before update on public.historical_source_records for each row execute function private.guard_posted_source_document();
