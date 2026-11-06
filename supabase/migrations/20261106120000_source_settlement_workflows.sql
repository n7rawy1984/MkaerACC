-- 85: source-linked orchestration, not another financial ledger. No data backfill.
create table public.source_settlement_events (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id),
 source_id uuid not null, version integer not null check(version>0), request_id uuid not null, request_hash text not null,
 kind text not null check(kind in('CONTRACT_PAYMENT','CONTRACT_ADVANCE','EMPLOYEE_ADVANCE')),
 state text not null check(state in('DRAFT','REVIEWED','APPROVED','POSTED','CANCELLED')),
 snapshot jsonb not null, confirmations jsonb not null, source_updated_at timestamptz not null,
 document_id uuid, journal_id uuid, reason text not null, created_by uuid not null references auth.users(id), created_at timestamptz not null default clock_timestamp(),
 unique(company_id,source_id,version), unique(company_id,request_id),
 foreign key(company_id,source_id) references public.historical_source_records(company_id,id),
 foreign key(company_id,journal_id) references public.journal_entries(company_id,id),
 check((state='POSTED'and document_id is not null and journal_id is not null)or(state<>'POSTED'and document_id is null and journal_id is null))
);
create unique index source_settlement_one_document on public.source_settlement_events(company_id,kind,document_id) where state='POSTED';
create unique index source_settlement_one_journal on public.source_settlement_events(company_id,journal_id)where state='POSTED';
alter table public.source_settlement_events enable row level security;
alter table public.source_settlement_events force row level security;
revoke all on public.source_settlement_events from public,anon,authenticated,service_role;
grant select on public.source_settlement_events to authenticated;
create policy source_settlement_read on public.source_settlement_events for select to authenticated using(
 public.has_permission(company_id,'accounting.post') and (kind<>'EMPLOYEE_ADVANCE' or public.has_permission(company_id,'payroll.manage')));
create trigger source_settlement_immutable before update or delete on public.source_settlement_events for each row execute function private.financial_evidence_immutable();

-- Fence expense/legacy entry points and source edits against a second financial effect.
create function private.guard_source_settlement() returns trigger language plpgsql security definer set search_path='' as $$
declare e public.source_settlement_events;begin
 if tg_table_name='historical_expense_drafts' then
  if exists(select 1 from public.source_settlement_events x where x.company_id=new.company_id and x.source_id=new.source_id and x.version=(select max(y.version)from public.source_settlement_events y where y.company_id=x.company_id and y.source_id=x.source_id)and x.state<>'CANCELLED')then raise exception 'Source belongs to settlement workflow'using errcode='23514';end if;
 else
  select * into e from public.source_settlement_events where company_id=old.company_id and source_id=old.id order by version desc limit 1;
  if e.id is not null and e.state<>'CANCELLED' then
   if new.expense_id is distinct from old.expense_id or new.payroll_entitlement_id is distinct from old.payroll_entitlement_id or new.expense_allocation_id is distinct from old.expense_allocation_id then raise exception 'Source already claimed by canonical settlement'using errcode='23514';end if;
   if e.state='POSTED' and (to_jsonb(new)-array['updated_at','updated_by'])is distinct from(to_jsonb(old)-array['updated_at','updated_by'])then raise exception 'Posted source immutable; use original module reversal/correction'using errcode='23514';end if;
  end if;
 end if;return new;end$$;
revoke all on function private.guard_source_settlement() from public,anon,authenticated,service_role;
create trigger settlement_cost_claim_guard before insert on public.historical_expense_drafts for each row execute function private.guard_source_settlement();
create trigger settlement_source_guard before update on public.historical_source_records for each row execute function private.guard_source_settlement();

-- Authoritative document matching also handles already-posted payments without repeating cash.
create function private.source_settlement_document(cid uuid,kind text,doc uuid)returns jsonb language plpgsql stable security definer set search_path=''as $$
declare r jsonb;begin
 if kind='CONTRACT_PAYMENT'then
  select jsonb_build_object('id',id,'date',payment_date,'amount_minor',total_amount_minor::text,'contract_id',subcontract_id,'project_id',project_id,'treasury_id',treasury_account_id,'journal',posted_journal_entry_id,'reversed',status='REVERSED','reference',payment_reference)into r from public.subcontractor_payments where company_id=cid and id=doc and status in('POSTED','REVERSED');
 elsif kind='CONTRACT_ADVANCE'then
  select jsonb_build_object('id',id,'date',advance_date,'amount_minor',amount_minor::text,'contract_id',subcontract_id,'project_id',project_id,'treasury_id',treasury_account_id,'journal',posted_journal_entry_id,'reversed',status='REVERSED','reference',advance_reference)into r from public.subcontractor_advances where company_id=cid and id=doc and status in('POSTED','REVERSED');
 elsif kind='EMPLOYEE_ADVANCE'then
  select jsonb_build_object('id',a.id,'date',a.posting_date,'amount_minor',a.amount_minor::text,'employee_id',a.employee_id,'treasury_id',a.treasury_id,'journal',a.journal_id,'reversed',exists(select 1 from public.hr_financial_reversals v where v.company_id=cid and v.kind='ADVANCE'and v.source_id=a.id),'reference',a.evidence)into r from public.hr_advance_postings a where a.company_id=cid and a.id=doc;
 end if;return r;end$$;
revoke all on function private.source_settlement_document(uuid,text,uuid)from public,anon,authenticated,service_role;

create function public.command_source_settlement(cid uuid,source_id uuid,expected_version integer,request_id uuid,action text,input jsonb,confirmations jsonb,reason text)
returns jsonb language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_variable
declare actor uuid;s public.historical_source_records;p public.source_settlement_events;r public.source_settlement_events;replay public.source_settlement_events;
 v jsonb;h text;k text;kind text;nature text;d date;amount bigint;treasury public.treasury_accounts;contract public.subcontracts;emp uuid;doc uuid;j uuid;x record;matched jsonb;lim bigint;allocation jsonb;total numeric;balance numeric;
begin
 actor:=private.operational_finance_actor(cid,'accounting.post');
 -- Same order as HR/payroll: attendance first, then financial serialization/source row.
 perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 if request_id is null or expected_version is null or expected_version<0 or action is null or action not in('SAVE','REVIEW','APPROVE','POST','CANCEL')or input is null or jsonb_typeof(input)<>'object'or confirmations is null or jsonb_typeof(confirmations)<>'object'or octet_length(input::text)>24000 or octet_length(confirmations::text)>6000 or coalesce(length(private.correction_text(reason)),0)not between 1 and 1000 then raise exception 'Source command, version and reason required'using errcode='22023';end if;
 -- Trim text before hashing; numeric inputs use exact minor-unit strings; JSONB normalizes object order.
 for k in select jsonb_object_keys(input)loop
  if k<>all(array['kind','date','amount_minor','contract_id','employee_id','project_id','treasury_id','certificate_id','monthly_limit_minor','existing_document_id','evidence'])or jsonb_typeof(input->k)not in('string','null')or length(input->>k)>1000 then raise exception 'Unsupported settlement input'using errcode='22023';end if;
  input:=jsonb_set(input,array[k],coalesce(to_jsonb(nullif(btrim(input->>k),'')),'null'::jsonb));
  if k in('amount_minor','monthly_limit_minor')and input->>k ~ '^[0-9]{1,16}$'then input:=jsonb_set(input,array[k],to_jsonb((input->>k)::bigint::text));end if;
 end loop;
 for k in select jsonb_object_keys(confirmations)loop if k<>all(array['owner','payment','distinct','duplicate_clearance'])then raise exception 'Unsupported attestation'using errcode='22023';end if;end loop;
 h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'source',source_id,'version',expected_version,'action',action,'input',input,'confirmations',confirmations,'reason',private.correction_text(reason))::text,'UTF8'),'sha256'),'hex');
 select * into replay from public.source_settlement_events e where e.company_id=cid and e.request_id=command_source_settlement.request_id;
 if replay.id is not null then
  if replay.request_hash<>h then raise exception 'Changed retry intent'using errcode='22023';end if;
  if replay.kind='EMPLOYEE_ADVANCE'and not public.has_permission(cid,'payroll.manage')then raise exception 'HR read denied'using errcode='42501';end if;return to_jsonb(replay);
 end if;
 select * into s from public.historical_source_records where company_id=cid and id=source_id for update;
 if not found or s.record_type<>'GENERAL'then raise exception 'Same-Company General source required'using errcode='42501';end if;
 select * into p from public.source_settlement_events e where e.company_id=cid and e.source_id=s.id order by e.version desc limit 1;
 if coalesce(p.version,0)<>expected_version then raise exception 'Source document changed; refresh'using errcode='40001';end if;
 if p.state='POSTED'then raise exception 'Use canonical reversal; source remains permanently linked'using errcode='23514';end if;
 if (s.review_status='CANCELLED'and action<>'CANCEL')or s.expense_id is not null or s.payroll_entitlement_id is not null or s.expense_allocation_id is not null or exists(select 1 from public.historical_expense_drafts b where b.company_id=cid and b.source_id=s.id and b.released_at is null)then raise exception 'Source already linked, allocated or archived'using errcode='23514';end if;
 if action='SAVE'then v:=input;kind:=v->>'kind';else
  if input<>'{}'::jsonb or p.id is null or p.state='CANCELLED'then raise exception 'Save current inputs first'using errcode='23514';end if;
  v:=p.snapshot;kind:=p.kind;
 end if;
 if kind is null or kind not in('CONTRACT_PAYMENT','CONTRACT_ADVANCE','EMPLOYEE_ADVANCE')then raise exception 'Select the canonical document type'using errcode='23514';end if;
 if kind='EMPLOYEE_ADVANCE'and not public.has_permission(cid,'payroll.manage')then raise exception 'Payroll authority required'using errcode='42501';end if;
 if kind='EMPLOYEE_ADVANCE'and action in('APPROVE','POST')and not public.has_company_role(cid,'ACCOUNTING_ADMIN')then raise exception 'Accounting Admin approval required'using errcode='42501';end if;
 if action='APPROVE'and p.state<>'REVIEWED'then raise exception 'Review before approval'using errcode='23514';end if;
 if action='POST'and p.state<>'APPROVED'then raise exception 'Approve before posting'using errcode='23514';end if;
 if action in('REVIEW','APPROVE','POST')then
  if s.review_status<>'REVIEWED'or confirmations->'owner'is distinct from'true'::jsonb or confirmations->'payment'is distinct from'true'::jsonb or confirmations->'distinct'is distinct from'true'::jsonb then raise exception 'Review source ownership, payment and distinct event evidence first'using errcode='23514';end if;
  if (coalesce(s.classification->'potential_duplicate'='true'::jsonb,false)or s.raw_source?'existing_match_candidates_unverified'or s.classification?'duplicate_group'or exists(select 1 from public.historical_source_records other where other.company_id=cid and other.source_file=s.source_file and other.classification->>'duplicate_candidate_source_reference'=s.source_reference))and coalesce(length(btrim(confirmations->>'duplicate_clearance')),0)<10 then raise exception 'Document duplicate clearance; match existing payment when already posted'using errcode='23514';end if;
  if action in('APPROVE','POST')and(p.source_updated_at is distinct from s.updated_at or p.confirmations is distinct from confirmations)then raise exception 'Source/evidence changed; review again'using errcode='40001';end if;
  nature:=coalesce(s.completion->>'nature',s.classification->>'nature');
  if not((kind='CONTRACT_PAYMENT'and nature in('SUBCONTRACTOR_PAYMENT','CONTRACTOR_PAYMENT'))or(kind='CONTRACT_ADVANCE'and nature='SUBCONTRACTOR_ADVANCE')or(kind='EMPLOYEE_ADVANCE'and nature='EMPLOYEE_ADVANCE'))then raise exception 'Confirmed source classification must match document type'using errcode='23514';end if;
  d:=(v->>'date')::date;amount:=(v->>'amount_minor')::bigint;
  if d is null or amount is null or amount not between 1 and 9000000000000000 or d is distinct from coalesce(nullif(s.completion->>'date','')::date,s.source_date)or amount is distinct from coalesce((s.completion->>'amount_minor')::bigint,s.outflow_minor)or coalesce(s.outflow_minor,0)<=0 or coalesce(s.funding_minor,0)<>0 or coalesce(length(v->>'evidence'),0)<1 then raise exception 'Exact source outgoing amount/date and supporting evidence required'using errcode='23514';end if;
  select * into treasury from public.treasury_accounts where company_id=cid and id=(v->>'treasury_id')::uuid;
  if treasury.id is null or(s.cash_treasury_id is not null and s.cash_treasury_id<>treasury.id)then raise exception 'Match actual same-Company source Treasury'using errcode='23514';end if;
  if kind like 'CONTRACT_%'then
   select * into contract from public.subcontracts where company_id=cid and id=(v->>'contract_id')::uuid;
   if contract.id is null or contract.project_id is distinct from nullif(v->>'project_id','')::uuid or (s.assigned_project_id is not null and s.assigned_project_id<>contract.project_id)or(s.allocation_scope='COMPANY')or(treasury.project_id is not null and treasury.project_id<>contract.project_id)then raise exception 'Company/contract/Project/funding dimensions disagree'using errcode='23514';end if;
   if kind='CONTRACT_PAYMENT'then
    if not exists(select 1 from public.subcontractor_certificates c where c.company_id=cid and c.id=(v->>'certificate_id')::uuid and c.subcontract_id=contract.id and c.status='POSTED')then raise exception 'Posted same-contract certification required'using errcode='23514';end if;
   end if;
  else
   emp:=(v->>'employee_id')::uuid;
   if emp is null or not exists(select 1 from public.parties where company_id=cid and id=emp and private.party_has_person_role(cid,id,'EMPLOYEE'))or treasury.project_id is not null or(nullif(v->>'project_id','')is not null and not exists(select 1 from public.projects where company_id=cid and id=(v->>'project_id')::uuid))or(s.assigned_project_id is not null and s.assigned_project_id is distinct from nullif(v->>'project_id','')::uuid)or(s.allocation_scope='COMPANY'and nullif(v->>'project_id','')is not null) then raise exception 'Employee receivable uses general Treasury; Project cost is not recognized by an advance'using errcode='23514';end if;
   lim:=(v->>'monthly_limit_minor')::bigint;if lim is null or lim not between 1 and amount then raise exception 'Explicit recovery limit required'using errcode='23514';end if;
  end if;
  doc:=nullif(v->>'existing_document_id','')::uuid;
  if doc is null and coalesce(length(btrim(confirmations->>'duplicate_clearance')),0)<10 and (
   exists(select 1 from public.subcontractor_payments a where kind='CONTRACT_PAYMENT'and a.company_id=cid and a.subcontract_id=contract.id and a.treasury_account_id=treasury.id and a.payment_date=d and a.total_amount_minor=amount and a.status='POSTED')or
   exists(select 1 from public.subcontractor_advances a where kind='CONTRACT_ADVANCE'and a.company_id=cid and a.subcontract_id=contract.id and a.treasury_account_id=treasury.id and a.advance_date=d and a.amount_minor=amount and a.status='POSTED')or
   exists(select 1 from public.hr_advance_postings a where kind='EMPLOYEE_ADVANCE'and a.company_id=cid and a.employee_id=emp and a.treasury_id=treasury.id and a.posting_date=d and a.amount_minor=amount and not exists(select 1 from public.hr_financial_reversals rv where rv.company_id=cid and rv.kind='ADVANCE'and rv.source_id=a.id))
  )then raise exception 'Potential existing payment: link it or document distinct-payment evidence'using errcode='23514';end if;
  if doc is not null then
   matched:=private.source_settlement_document(cid,kind,doc);
   if matched is null or(matched->>'reversed')::boolean or matched->>'date'<>d::text or matched->>'amount_minor'<>amount::text or matched->>'treasury_id'<>treasury.id::text or (kind like 'CONTRACT_%'and matched->>'contract_id'<>contract.id::text)or(kind='EMPLOYEE_ADVANCE'and matched->>'employee_id'<>emp::text)then raise exception 'Existing document must match exact live source event and dimensions'using errcode='23514';end if;
   if kind='CONTRACT_PAYMENT'and not exists(select 1 from public.subcontractor_payment_allocations a where a.company_id=cid and a.subcontractor_payment_id=doc and a.subcontractor_certificate_id=(v->>'certificate_id')::uuid and a.allocated_amount_minor=amount)then raise exception 'Existing payment certificate allocation differs'using errcode='23514';end if;
   if exists(select 1 from public.source_settlement_events e where e.company_id=cid and e.kind=kind and e.document_id=doc and e.state='POSTED')then raise exception 'Document already linked to a source'using errcode='23505';end if;
  end if;
 end if;
 if action='APPROVE'and p.state<>'REVIEWED'then raise exception 'Review before approval'using errcode='23514';end if;
 if action='POST'then
  if p.state<>'APPROVED'then raise exception 'Approve before posting'using errcode='23514';end if;
  if doc is null then
   -- Source posting cannot create cash beyond evidenced funds; canonical commands retain their own guards.
   perform 1 from public.treasury_accounts where company_id=cid and id=treasury.id for update;
   select coalesce(sum(l.debit_minor::numeric-l.credit_minor::numeric),0)into balance from public.journal_lines l join public.journal_entries je on je.company_id=l.company_id and je.id=l.journal_entry_id where l.company_id=cid and l.account_id=treasury.gl_account_id and je.posting_date<=d;
   if treasury.status<>'ACTIVE'or balance<amount then raise exception 'Insufficient evidenced Treasury funds; no invented funding'using errcode='23514';end if;
   if kind='CONTRACT_PAYMENT'then
    select * into x from public.post_subcontractor_payment(cid,d,contract.id,treasury.id,amount,case when treasury.type in('BANK','PROJECT_BANK')then 'BANK'::public.payment_method else 'CASH'::public.payment_method end,'HISTORICAL:'||source_id::text,v->>'evidence',jsonb_build_array(jsonb_build_object('certificate_id',v->>'certificate_id','amount_minor',amount::text)),request_id);doc:=x.subcontractor_payment_id;j:=x.journal_entry_id;
   elsif kind='CONTRACT_ADVANCE'then
    select * into x from public.post_subcontractor_advance(cid,d,contract.id,treasury.id,amount,case when treasury.type in('BANK','PROJECT_BANK')then 'BANK'::public.payment_method else 'CASH'::public.payment_method end,'HISTORICAL:'||source_id::text,v->>'evidence',request_id);doc:=x.subcontractor_advance_id;j:=x.journal_entry_id;
   else
    matched:=public.command_hr(cid,request_id,'ADVANCE',jsonb_build_object('employee_id',emp,'treasury_id',treasury.id,'date',d,'amount_minor',amount::text,'monthly_limit_minor',lim::text,'evidence',left('HISTORICAL:'||source_id::text||' '||(v->>'evidence'),1000)));doc:=(matched->>'id')::uuid;
    select journal_id into j from public.hr_advance_postings where company_id=cid and id=doc;
   end if;
  else j:=(matched->>'journal')::uuid;end if;
 end if;
 insert into public.source_settlement_events(company_id,source_id,version,request_id,request_hash,kind,state,snapshot,confirmations,source_updated_at,document_id,journal_id,reason,created_by)
 values(cid,s.id,expected_version+1,request_id,h,kind,case action when 'SAVE'then 'DRAFT'when 'REVIEW'then 'REVIEWED'when 'APPROVE'then 'APPROVED'when 'POST'then 'POSTED'else 'CANCELLED'end,v,confirmations,s.updated_at,case when action='POST'then doc end,case when action='POST'then j end,private.correction_text(reason),actor)returning *into r;
 return to_jsonb(r);
end$$;
revoke all on function public.command_source_settlement(uuid,uuid,integer,uuid,text,jsonb,jsonb,text)from public,anon,authenticated,service_role;
grant execute on function public.command_source_settlement(uuid,uuid,integer,uuid,text,jsonb,jsonb,text)to authenticated;

create function public.read_source_settlement(cid uuid,source_id uuid)returns jsonb language plpgsql stable security definer set search_path=''as $$
declare s public.historical_source_records;e public.source_settlement_events;hr boolean;k text;docs jsonb;recovery jsonb;begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT'))then raise exception 'Source workflow read denied'using errcode='42501';end if;
 select *into s from public.historical_source_records where company_id=cid and id=source_id;if not found then raise exception 'Company source required'using errcode='42501';end if;
 hr:=public.has_permission(cid,'payroll.manage');
 select x.*into e from public.source_settlement_events x where x.company_id=cid and x.source_id=s.id order by x.version desc limit 1;
 k:=coalesce(e.kind,case coalesce(s.completion->>'nature',s.classification->>'nature')when 'EMPLOYEE_ADVANCE'then 'EMPLOYEE_ADVANCE'when 'SUBCONTRACTOR_ADVANCE'then 'CONTRACT_ADVANCE'else 'CONTRACT_PAYMENT'end);
 if k='EMPLOYEE_ADVANCE'and not hr then raise exception 'Payroll read authority required'using errcode='42501';end if;
 select coalesce(jsonb_agg(d),'[]')into docs from(
 select private.source_settlement_document(cid,k,id)d from(
 select id from public.subcontractor_payments where company_id=cid and k='CONTRACT_PAYMENT'and payment_date=coalesce(nullif(s.completion->>'date','')::date,s.source_date)and total_amount_minor=coalesce((s.completion->>'amount_minor')::bigint,s.outflow_minor)and status='POSTED'
 union all select id from public.subcontractor_advances where company_id=cid and k='CONTRACT_ADVANCE'and advance_date=coalesce(nullif(s.completion->>'date','')::date,s.source_date)and amount_minor=coalesce((s.completion->>'amount_minor')::bigint,s.outflow_minor)and status='POSTED'
 union all select id from public.hr_advance_postings where company_id=cid and k='EMPLOYEE_ADVANCE'and hr and posting_date=coalesce(nullif(s.completion->>'date','')::date,s.source_date)and amount_minor=coalesce((s.completion->>'amount_minor')::bigint,s.outflow_minor)
 )ids order by id limit 100)x;
 if k='EMPLOYEE_ADVANCE'and e.document_id is not null then
  select jsonb_build_object('remaining_minor',private.hr_recovery_balance(cid,e.document_id)::text,
   'plans',(select coalesce(jsonb_agg(jsonb_build_object('advance_id',p.advance_id,'month',p.month,'version',p.version,'amount_minor',p.amount_minor::text)),'[]')from public.hr_recovery_plans p where p.company_id=cid and p.advance_id=e.document_id),
   'postings',(select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'payroll_id',p.payroll_id,'amount_minor',p.amount_minor::text,'journal_id',p.journal_id,'reversed',exists(select 1 from public.hr_financial_reversals r where r.company_id=cid and r.kind='RECOVERY'and r.source_id=p.id))),'[]')from public.hr_recovery_postings p where p.company_id=cid and p.advance_id=e.document_id))into recovery;
 end if;
 return jsonb_build_object('company_id',cid,'source_id',s.id,'event',case when e.id is not null then to_jsonb(e)end,'document',private.source_settlement_document(cid,k,e.document_id),'candidates',docs,'recoveries',recovery,
 'certificates',(select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'contract_id',c.subcontract_id,'reference',c.certificate_reference,'remaining_minor',(c.payable_amount_minor-coalesce((select sum(a.allocated_amount_minor)from public.subcontractor_payment_allocations a join public.subcontractor_payments p on p.company_id=a.company_id and p.id=a.subcontractor_payment_id where a.company_id=cid and a.subcontractor_certificate_id=c.id and p.status='POSTED'),0))::text)),'[]')from public.subcontractor_certificates c where c.company_id=cid and c.status='POSTED'));
end$$;
revoke all on function public.read_source_settlement(uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.read_source_settlement(uuid,uuid)to authenticated;

-- Extend existing source/report lineage; confidential HR details never go to Viewer.
alter function public.read_source_document_links(uuid,uuid[])set schema private;
alter function private.read_source_document_links(uuid,uuid[])rename to read_source_document_links_v83;
revoke all on function private.read_source_document_links_v83(uuid,uuid[])from public,anon,authenticated,service_role;
create function public.read_source_document_links(cid uuid,source_ids uuid[])returns jsonb language plpgsql stable security definer set search_path=''as $$
declare base jsonb;extra jsonb;begin
 base:=private.read_source_document_links_v83(cid,source_ids);
 select coalesce(jsonb_agg(jsonb_build_object('source_id',e.source_id,'draft_id',e.source_id,'kind',e.kind,
 'event',jsonb_build_object('company_id',cid,'state',e.state,'receipt',case when e.kind<>'EMPLOYEE_ADVANCE'or public.has_permission(cid,'payroll.manage')then jsonb_build_object('id',e.document_id,'journal',e.journal_id,'reference',d->>'reference')end),
 'reversed',coalesce((d->>'reversed')::boolean,false))),'[]')into extra from public.source_settlement_events e
 cross join lateral(select private.source_settlement_document(cid,e.kind,e.document_id)d)x
 where e.company_id=cid and e.source_id=any(source_ids)and e.version=(select max(p.version)from public.source_settlement_events p where p.company_id=cid and p.source_id=e.source_id)and e.state<>'CANCELLED';
 return base||extra;end$$;
revoke all on function public.read_source_document_links(uuid,uuid[])from public,anon,authenticated,service_role;
grant execute on function public.read_source_document_links(uuid,uuid[])to authenticated;
