-- 86: audited source routing and atomic specialized reversal/replacement. No backfill.
create table public.source_reclassification_events(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),source_id uuid not null,
 version integer not null check(version>0),request_id uuid not null,request_hash text not null,
 state text not null check(state in('ROUTED','DRAFT','REVIEWED','APPROVED','POSTED','CANCELLED')),
 snapshot jsonb not null,hr_sensitive boolean not null,origin jsonb,source_updated_at timestamptz not null,
 reversal_journal_id uuid,replacement jsonb,reason text not null,created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,source_id,version),unique(company_id,request_id),
 foreign key(company_id,source_id)references public.historical_source_records(company_id,id),
 foreign key(company_id,reversal_journal_id)references public.journal_entries(company_id,id),
 check((state='POSTED'and origin is not null and reversal_journal_id is not null and replacement is not null)or(state<>'POSTED'and reversal_journal_id is null and replacement is null))
);
create unique index reclassification_once_per_document on public.source_reclassification_events(company_id,(origin->>'kind'),(origin->>'id'))where state='POSTED';
alter table public.source_reclassification_events enable row level security;
alter table public.source_reclassification_events force row level security;
revoke all on public.source_reclassification_events from public,anon,authenticated,service_role;
grant select on public.source_reclassification_events to authenticated;
create policy reclassification_read on public.source_reclassification_events for select to authenticated using(
 public.has_permission(company_id,'accounting.post')and(not hr_sensitive or public.has_permission(company_id,'payroll.manage')));
create trigger reclassification_immutable before update or delete on public.source_reclassification_events for each row execute function private.financial_evidence_immutable();

create function private.reclassification_document(cid uuid,kind text,doc uuid)returns jsonb language plpgsql stable security definer set search_path=''as $$
declare r jsonb;begin
 if kind='EXPENSE'then
  select jsonb_build_object('kind',kind,'id',id,'journal',posted_journal_entry_id,'date',expense_date,'amount_minor',gross_amount_minor::text,'reference',expense_reference,'status',status,'funding_mode',funding_mode,'treasury_id',treasury_account_id,'custodian_id',paid_by_party_id,'project_id',project_id,'vat_minor',vat_amount_minor::text,'supplier_id',supplier_id,'allocation_plan',allocation_plan)into r from public.expenses where company_id=cid and id=doc;
 elsif kind in('CONTRACT_PAYMENT','CONTRACT_ADVANCE','EMPLOYEE_ADVANCE')then
  r:=private.source_settlement_document(cid,kind,doc);if r is not null then r:=r||jsonb_build_object('kind',kind,'funding_mode','TREASURY','status',case when(r->>'reversed')::boolean then 'REVERSED'else 'POSTED'end);end if;
 elsif kind='CUSTODY_ADVANCE'then
  select jsonb_build_object('kind',kind,'id',id,'journal',posted_journal_entry_id,'date',advance_date,'amount_minor',amount_minor::text,'reference',advance_reference,'status',status,'funding_mode','TREASURY','treasury_id',treasury_account_id,'custodian_id',custodian_id,'project_id',project_id)into r from public.custody_advances where company_id=cid and id=doc;
 elsif kind='SUPPLIER_PAYMENT'then
  select jsonb_build_object('kind',kind,'id',id,'journal',posted_journal_entry_id,'date',payment_date,'amount_minor',total_amount_minor::text,'reference',payment_reference,'status',status,'funding_mode','TREASURY','treasury_id',treasury_account_id,'supplier_id',supplier_id)into r from public.supplier_payments where company_id=cid and id=doc;
 end if;return r;end$$;
revoke all on function private.reclassification_document(uuid,text,uuid)from public,anon,authenticated,service_role;
create function private.reclassification_origin(cid uuid,sid uuid)returns jsonb language plpgsql stable security definer set search_path=''as $$
declare e public.source_reclassification_events;b public.source_settlement_events;s public.historical_source_records;receipt jsonb;begin
 select *into e from public.source_reclassification_events x where x.company_id=cid and x.source_id=sid and x.state='POSTED'order by x.version desc limit 1;
 if e.id is not null then return private.reclassification_document(cid,e.replacement->>'kind',(e.replacement->>'id')::uuid);end if;
 select *into s from public.historical_source_records where company_id=cid and id=sid;
 if s.expense_id is not null then return private.reclassification_document(cid,'EXPENSE',s.expense_id);end if;
 select *into b from public.source_settlement_events x where x.company_id=cid and x.source_id=sid and x.state='POSTED'order by x.version desc limit 1;
 if b.id is not null then return private.reclassification_document(cid,b.kind,b.document_id);end if;
 -- Personal evidence is not silently treated as Treasury or Custody.
 return null;
end$$;
revoke all on function private.reclassification_origin(uuid,uuid)from public,anon,authenticated,service_role;

create function private.validate_reclassification(cid uuid,o jsonb,v jsonb)returns void language plpgsql set search_path=''as $$
declare d date:=(v->>'date')::date;pid uuid:=nullif(v->>'project_id','')::uuid;target text:=v->>'target';tid uuid:=(o->>'treasury_id')::uuid;begin
 if o is null or o->>'status'<>'POSTED'then raise exception 'Live source-linked canonical payment required'using errcode='23514';end if;
 if target is null or target not in('OPERATING_EXPENSE','PROJECT_COST','CONTRACT_PAYMENT','CONTRACT_ADVANCE','EMPLOYEE_ADVANCE','CUSTODY_ADVANCE','SUPPLIER_PAYMENT')then raise exception 'Select supported destination'using errcode='23514';end if;
 if d is null or d<>(statement_timestamp()at time zone'UTC')::date or date_trunc('month',(o->>'date')::date)<>date_trunc('month',d)then raise exception 'DECISION REQUIRED: prior-period correction; this command supports current-period originals and today only'using errcode='23514';end if;
 perform private.opening_period(cid,d);
 if not exists(select 1 from public.project_correction_period_events where company_id=cid and month=date_trunc('month',d)::date and state='OPEN')then raise exception 'Explicitly open current correction period before review/posting'using errcode='23514';end if;
 if coalesce(v->>'unreconciled','')<>'true'or coalesce(length(btrim(v->>'evidence')),0)<1 then raise exception 'Verify unreconciled original payment, beneficiary, dependencies and correction evidence'using errcode='23514';end if;
 if v->'tax_neutral'is distinct from 'true'::jsonb then raise exception 'DECISION REQUIRED: explicitly verify no tax adjustment or recoverable VAT belongs in the replacement'using errcode='23514';end if;
 if o->>'kind'='EXPENSE'and(coalesce(o->>'vat_minor','0')<>'0'or o->'allocation_plan'is distinct from 'null'::jsonb and o->'allocation_plan'is not null)then raise exception 'DECISION REQUIRED: tax or split correction; use specialized reviewed workflow'using errcode='23514';end if;
 if o->>'funding_mode'not in('TREASURY','CUSTODIAN')then raise exception 'Use specialized liability/personal-funding correction; no invented cash'using errcode='23514';end if;
 if o->>'funding_mode'='CUSTODIAN'and target not in('OPERATING_EXPENSE','PROJECT_COST')then raise exception 'Unsupported Custody-funded destination; no fictional Treasury transfer'using errcode='23514';end if;
 if target in('OPERATING_EXPENSE','PROJECT_COST')then
  if (target='PROJECT_COST')<>(pid is not null)or not exists(select 1 from public.expense_categories where company_id=cid and id=(v->>'category_id')::uuid and status='ACTIVE')then raise exception 'Select destination category and Project/overhead explicitly'using errcode='23514';end if;
  if pid is not null and not exists(select 1 from public.projects where company_id=cid and id=pid and status='ACTIVE')then raise exception 'Active same-Company Project required'using errcode='23514';end if;
 elsif target in('CONTRACT_PAYMENT','CONTRACT_ADVANCE')then
  if not exists(select 1 from public.subcontracts where company_id=cid and id=(v->>'contract_id')::uuid and project_id=pid)then raise exception 'Select same-Company contract/Project'using errcode='23514';end if;
  if target='CONTRACT_PAYMENT'and not exists(select 1 from public.subcontractor_certificates where company_id=cid and id=(v->>'certificate_id')::uuid and subcontract_id=(v->>'contract_id')::uuid and status='POSTED')then raise exception 'Existing certified liability required; never invent work to settle'using errcode='23514';end if;
 elsif target='EMPLOYEE_ADVANCE'then
  if not public.has_permission(cid,'payroll.manage')then raise exception 'HR authority required'using errcode='42501';end if;
  if not exists(select 1 from public.parties where company_id=cid and id=(v->>'employee_id')::uuid and status='ACTIVE'and private.party_has_person_role(cid,id,'EMPLOYEE'))or coalesce((v->>'monthly_limit_minor')::bigint,0)not between 1 and(o->>'amount_minor')::bigint then raise exception 'Company employee and approved recovery cap required'using errcode='23514';end if;
 elsif target='CUSTODY_ADVANCE'then
  if not exists(select 1 from public.parties where company_id=cid and id=(v->>'custodian_id')::uuid and private.party_has_person_role(cid,id,'CUSTODIAN'))then raise exception 'Company Custodian required'using errcode='23514';end if;
 elsif target='SUPPLIER_PAYMENT'then
  if not exists(select 1 from public.expenses where company_id=cid and id=(v->>'supplier_expense_id')::uuid and supplier_id=(v->>'supplier_id')::uuid and funding_mode='SUPPLIER_CREDIT'and status='POSTED')then raise exception 'Existing same-Company Supplier liability required'using errcode='23514';end if;
 end if;
end$$;
revoke all on function private.validate_reclassification(uuid,jsonb,jsonb)from public,anon,authenticated,service_role;

create function public.command_source_reclassification(cid uuid,source_id uuid,expected_version integer,request_id uuid,action text,input jsonb,reason text)
returns jsonb language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_variable
declare actor uuid;s public.historical_source_records;p public.source_reclassification_events;r public.source_reclassification_events;replay public.source_reclassification_events;
 cost public.expense_draft_events;bound public.historical_expense_drafts;settle public.source_settlement_events;
 v jsonb;o jsonb;h text;k text;nature text;d date;amount bigint;tid uuid;holder uuid;method public.payment_method;x record;result jsonb;rev uuid;doc uuid;kind text;j uuid;
begin
 actor:=private.operational_finance_actor(cid,'accounting.post');perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 if request_id is null or expected_version is null or expected_version<0 or action is null or action not in('ROUTE','SAVE','REVIEW','APPROVE','POST','CANCEL')or input is null or jsonb_typeof(input)<>'object'or octet_length(input::text)>12000 or coalesce(length(private.correction_text(reason)),0)not between 1 and 500 then raise exception 'Version, supported action and reason required'using errcode='22023';end if;
 for k in select jsonb_object_keys(input)loop
  if k<>all(array['target','date','project_id','category_id','contract_id','certificate_id','employee_id','monthly_limit_minor','custodian_id','supplier_id','supplier_expense_id','evidence','unreconciled','tax_neutral'])or jsonb_typeof(input->k)not in('string','boolean','null')or length(input->>k)>1000 then raise exception 'Unsupported correction input; no amount, funding location or journal lines accepted'using errcode='22023';end if;
  if k not in('unreconciled','tax_neutral')then input:=jsonb_set(input,array[k],coalesce(to_jsonb(nullif(btrim(input->>k),'')),'null'::jsonb));end if;
  if k='monthly_limit_minor'and input->>k ~ '^[0-9]{1,16}$'then input:=jsonb_set(input,array[k],to_jsonb((input->>k)::bigint::text));end if;
 end loop;
 h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'source',source_id,'version',expected_version,'action',action,'input',input,'reason',private.correction_text(reason))::text,'UTF8'),'sha256'),'hex');
 select *into replay from public.source_reclassification_events e where e.company_id=cid and e.request_id=command_source_reclassification.request_id;
 if replay.id is not null then
  if replay.request_hash<>h then raise exception 'Changed retry intent'using errcode='22023';end if;
  if replay.hr_sensitive and not public.has_permission(cid,'payroll.manage')then raise exception 'HR read denied'using errcode='42501';end if;return to_jsonb(replay);
 end if;
 select *into s from public.historical_source_records where company_id=cid and id=source_id for update;
 if not found or s.record_type<>'GENERAL'then raise exception 'Same-Company General source required'using errcode='42501';end if;
 select e.*into p from public.source_reclassification_events e where e.company_id=cid and e.source_id=s.id order by e.version desc limit 1;
 if coalesce(p.version,0)<>expected_version then raise exception 'Correction changed; refresh'using errcode='40001';end if;
 o:=private.reclassification_origin(cid,s.id);
 if(coalesce(p.hr_sensitive,false)or o->>'kind'='EMPLOYEE_ADVANCE')and not public.has_permission(cid,'payroll.manage')then raise exception 'HR authority required for this correction chain'using errcode='42501';end if;
 if action='ROUTE'then
  if o is not null or s.payroll_entitlement_id is not null or s.review_status='CANCELLED'or s.expense_allocation_id is not null then raise exception 'Posted/archived/split source requires its specialized correction workflow'using errcode='23514';end if;
  if input->>'target'is null or input->>'target'not in('OPERATING_EXPENSE','PROJECT_COST','CONTRACT_PAYMENT','CONTRACT_ADVANCE','EMPLOYEE_ADVANCE','CUSTODY_ADVANCE','CUSTODY_RETURN','CUSTODY_SETTLEMENT','TREASURY','SUPPLIER_PAYMENT','SUPPLIER_INVOICE','PAYROLL','FINANCIAL_EVIDENCE')then raise exception 'Select existing supported destination'using errcode='23514';end if;
  if nullif(input->>'project_id','')is not null and not exists(select 1 from public.projects where company_id=cid and id=(input->>'project_id')::uuid)then raise exception 'Same-Company Project required'using errcode='23514';end if;
  select *into bound from public.historical_expense_drafts b where b.company_id=cid and b.source_id=s.id and b.released_at is null;
  if bound.id is not null then
   select *into cost from public.expense_draft_events e where e.company_id=cid and e.draft_id=bound.draft_id order by version desc limit 1;
   if cost.state='POSTED'then raise exception 'Posted original-cost source cannot be routed again'using errcode='23514';end if;
   perform public.command_source_expense_draft(cid,s.id,bound.draft_id,cost.version,gen_random_uuid(),'CANCEL','{}',reason,'{}');
  end if;
  select e.*into settle from public.source_settlement_events e where e.company_id=cid and e.source_id=s.id order by version desc limit 1;
  if settle.id is not null and settle.state<>'CANCELLED'then
   if settle.state='POSTED'then raise exception 'Posted settlement cannot be routed again'using errcode='23514';end if;
   perform public.command_source_settlement(cid,s.id,settle.version,gen_random_uuid(),'CANCEL','{}','{}',reason);
  end if;
  nature:=case input->>'target'when 'OPERATING_EXPENSE'then 'EXPENSE'when 'PROJECT_COST'then 'EXPENSE'when 'CONTRACT_PAYMENT'then 'SUBCONTRACTOR_PAYMENT'when 'CONTRACT_ADVANCE'then 'SUBCONTRACTOR_ADVANCE'when 'TREASURY'then 'NEEDS_REVIEW'when 'SUPPLIER_INVOICE'then 'SUPPLIER_INVOICE_OR_COMMITMENT'when 'PAYROLL'then 'PAYROLL_OR_SALARY_PAYMENT'when 'FINANCIAL_EVIDENCE'then 'NEEDS_REVIEW'else input->>'target'end;
  -- Preserve raw evidence, source amount/date, attachments and all prior audit; invalidate review.
  perform public.complete_historical_source(cid,s.id,s.updated_at,s.completion||jsonb_build_object('nature',nature,'reclassification_destination',input->>'target','reason',reason),'PENDING');
  update public.historical_source_records set allocation_scope=case when input->>'target'='OPERATING_EXPENSE'then 'COMPANY'when nullif(input->>'project_id','')is not null then 'PROJECT'else null end,assigned_project_id=case when input->>'target'<>'OPERATING_EXPENSE'then nullif(input->>'project_id','')::uuid end where company_id=cid and id=s.id;
  v:=input||jsonb_build_object('previous_source',jsonb_build_object('completion',s.completion,'review_status',s.review_status,'allocation_scope',s.allocation_scope,'assigned_project_id',s.assigned_project_id,'expense_draft_id',bound.draft_id,'settlement_event_id',settle.id));
 elsif action='SAVE'then
  if o is null then raise exception 'Use unposted routing; no canonical posted origin found'using errcode='23514';end if;
  if o->>'kind'='EMPLOYEE_ADVANCE'and not public.has_permission(cid,'payroll.manage')then raise exception 'HR authority required'using errcode='42501';end if;
  v:=input;
 else
  if input<>'{}'::jsonb or p.id is null or p.state in('POSTED','ROUTED','CANCELLED')then raise exception 'Save a new correction plan first'using errcode='23514';end if;
  v:=p.snapshot;
  if o is distinct from p.origin or s.updated_at is distinct from p.source_updated_at then raise exception 'Original source/document changed; save/review again'using errcode='40001';end if;
 end if;
 if v->>'target'='EMPLOYEE_ADVANCE'and not public.has_permission(cid,'payroll.manage')then raise exception 'HR destination authority required'using errcode='42501';end if;
 if action in('REVIEW','APPROVE','POST')then
  perform private.validate_reclassification(cid,o,v);
  if action='APPROVE'and p.state<>'REVIEWED'or action='POST'and p.state<>'APPROVED'then raise exception 'Review then approve the exact saved plan'using errcode='23514';end if;
  if action in('APPROVE','POST')then perform private.correction_authority(cid);end if;
 end if;
 if action='POST'then
  if not public.has_permission(cid,'accounting.reverse')then raise exception 'Canonical reversal authority required'using errcode='42501';end if;
  d:=(v->>'date')::date;amount:=(o->>'amount_minor')::bigint;tid:=(o->>'treasury_id')::uuid;holder:=(o->>'custodian_id')::uuid;
  -- Assert funding neutrality by actual account/location/holder, not an overall total.
  if o->>'kind'='EXPENSE'then select *into x from public.reverse_expense(cid,(o->>'id')::uuid,d,reason,gen_random_uuid());rev:=x.reversal_journal_entry_id;
  elsif o->>'kind'='CONTRACT_PAYMENT'then select *into x from public.reverse_subcontractor_payment(cid,(o->>'id')::uuid,d,reason,gen_random_uuid());rev:=x.reversal_journal_entry_id;
  elsif o->>'kind'='CONTRACT_ADVANCE'then select *into x from public.reverse_subcontractor_advance(cid,(o->>'id')::uuid,d,reason,gen_random_uuid());rev:=x.reversal_journal_entry_id;
  elsif o->>'kind'='EMPLOYEE_ADVANCE'then result:=public.command_hr(cid,gen_random_uuid(),'REVERSE_ADVANCE',jsonb_build_object('advance_id',o->>'id','date',d,'evidence',reason));select journal_id into rev from public.hr_financial_reversals where company_id=cid and id=(result->>'id')::uuid;
  elsif o->>'kind'='CUSTODY_ADVANCE'then select *into x from public.reverse_custody_advance(cid,(o->>'id')::uuid,d,reason,gen_random_uuid());rev:=x.reversal_journal_entry_id;
  elsif o->>'kind'='SUPPLIER_PAYMENT'then select *into x from public.reverse_supplier_payment(cid,(o->>'id')::uuid,d,reason,gen_random_uuid());rev:=x.reversal_journal_entry_id;
  else raise exception 'Unsupported canonical reversal'using errcode='23514';end if;
  if tid is not null then select case when type in('BANK','PROJECT_BANK')then 'BANK'::public.payment_method else 'CASH'::public.payment_method end into method from public.treasury_accounts where company_id=cid and id=tid;else method:='CASH';end if;
  if v->>'target'in('OPERATING_EXPENSE','PROJECT_COST')then
   select *into x from public.post_expense(cid,d,nullif(v->>'project_id','')::uuid,(v->>'category_id')::uuid,'Accounting reclassification of '||(o->>'reference'),amount,'ZERO',null,(o->>'funding_mode')::public.expense_funding_mode,tid,case when o->>'funding_mode'='CUSTODIAN'then holder end,null,method,false,null,left('RECLASSIFICATION:'||source_id::text||' ORIGINAL PAYMENT '||(o->>'date')||' '||reason,2000),gen_random_uuid());kind:='EXPENSE';doc:=x.expense_id;j:=x.journal_entry_id;
  elsif v->>'target'='CONTRACT_PAYMENT'then
   select *into x from public.post_subcontractor_payment(cid,d,(v->>'contract_id')::uuid,tid,amount,method,'RECLASSIFICATION:'||source_id::text,reason,jsonb_build_array(jsonb_build_object('certificate_id',v->>'certificate_id','amount_minor',amount::text)),gen_random_uuid());kind:='CONTRACT_PAYMENT';doc:=x.subcontractor_payment_id;j:=x.journal_entry_id;
  elsif v->>'target'='CONTRACT_ADVANCE'then
   select *into x from public.post_subcontractor_advance(cid,d,(v->>'contract_id')::uuid,tid,amount,method,'RECLASSIFICATION:'||source_id::text,reason,gen_random_uuid());kind:='CONTRACT_ADVANCE';doc:=x.subcontractor_advance_id;j:=x.journal_entry_id;
  elsif v->>'target'='EMPLOYEE_ADVANCE'then
   result:=public.command_hr(cid,gen_random_uuid(),'ADVANCE',jsonb_build_object('employee_id',v->>'employee_id','treasury_id',tid,'date',d,'amount_minor',amount::text,'monthly_limit_minor',v->>'monthly_limit_minor','evidence',reason));kind:='EMPLOYEE_ADVANCE';doc:=(result->>'id')::uuid;select journal_id into j from public.hr_advance_postings where company_id=cid and id=doc;
  elsif v->>'target'='CUSTODY_ADVANCE'then
   select *into x from public.post_custody_advance(cid,d,(v->>'custodian_id')::uuid,tid,nullif(v->>'project_id','')::uuid,amount,method,'RECLASSIFICATION:'||source_id::text,reason,gen_random_uuid());kind:='CUSTODY_ADVANCE';doc:=x.custody_advance_id;j:=x.journal_entry_id;
  elsif v->>'target'='SUPPLIER_PAYMENT'then
   select *into x from public.post_supplier_payment(cid,d,(v->>'supplier_id')::uuid,tid,amount,method,'RECLASSIFICATION:'||source_id::text,reason,jsonb_build_array(jsonb_build_object('expense_id',v->>'supplier_expense_id','amount_minor',amount::text)),gen_random_uuid());kind:='SUPPLIER_PAYMENT';doc:=x.supplier_payment_id;j:=x.journal_entry_id;
  end if;
  if exists(select 1 from public.journal_lines l where l.company_id=cid and l.journal_entry_id in(rev,j)
   and(l.treasury_account_id is not null or(o->>'funding_mode'='CUSTODIAN'and l.account_id=(select id from public.accounts where company_id=cid and system_key='CUSTODY_ADVANCE')))
   group by l.account_id,l.treasury_account_id,l.party_id having sum(l.debit_minor::numeric-l.credit_minor::numeric)<>0)
  then raise exception 'Correction would change actual funding balances; entire reversal/replacement rolled back'using errcode='23514';end if;
  result:=jsonb_build_object('kind',kind,'id',doc,'journal',j,'original_payment_date',coalesce((select e.replacement->>'original_payment_date'from public.source_reclassification_events e where e.company_id=cid and e.source_id=s.id and e.state='POSTED'order by e.version limit 1),o->>'date'),'original_payment_journal',coalesce((select e.replacement->>'original_payment_journal'from public.source_reclassification_events e where e.company_id=cid and e.source_id=s.id and e.state='POSTED'order by e.version limit 1),o->>'journal'),'actual_new_payment',false,'funding_balance_delta_minor','0');
 end if;
 insert into public.source_reclassification_events(company_id,source_id,version,request_id,request_hash,state,snapshot,hr_sensitive,origin,source_updated_at,reversal_journal_id,replacement,reason,created_by)
 values(cid,s.id,expected_version+1,request_id,h,case action when 'ROUTE'then 'ROUTED'when 'SAVE'then 'DRAFT'when 'REVIEW'then 'REVIEWED'when 'APPROVE'then 'APPROVED'when 'POST'then 'POSTED'else 'CANCELLED'end,v,coalesce(p.hr_sensitive,false)or coalesce(v->>'target'='EMPLOYEE_ADVANCE',false)or coalesce(o->>'kind'='EMPLOYEE_ADVANCE',false),o,(select updated_at from public.historical_source_records where company_id=cid and id=s.id),rev,case when action='POST'then result end,reason,actor)returning *into r;
 return to_jsonb(r);
end$$;
revoke all on function public.command_source_reclassification(uuid,uuid,integer,uuid,text,jsonb,text)from public,anon,authenticated,service_role;
grant execute on function public.command_source_reclassification(uuid,uuid,integer,uuid,text,jsonb,text)to authenticated;

create function public.read_source_reclassification(cid uuid,source_id uuid)returns jsonb language plpgsql stable security definer set search_path=''as $$
declare e public.source_reclassification_events;o jsonb;begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT'))then raise exception 'Correction read denied'using errcode='42501';end if;
 if not exists(select 1 from public.historical_source_records where company_id=cid and id=source_id)then raise exception 'Company source required'using errcode='42501';end if;
 select x.*into e from public.source_reclassification_events x where x.company_id=cid and x.source_id=read_source_reclassification.source_id order by x.version desc limit 1;
 o:=private.reclassification_origin(cid,source_id);
 if(coalesce(e.hr_sensitive,false)or o->>'kind'='EMPLOYEE_ADVANCE')and not public.has_permission(cid,'payroll.manage')then raise exception 'HR read authority required'using errcode='42501';end if;
 return jsonb_build_object('company_id',cid,'source_id',source_id,'origin',o,'payment_history',coalesce((select x.origin from public.source_reclassification_events x where x.company_id=cid and x.source_id=read_source_reclassification.source_id and x.state='POSTED'order by version limit 1),o),'event',case when e.id is not null then to_jsonb(e)end,'today',(statement_timestamp()at time zone'UTC')::date,
 'period_open',exists(select 1 from public.project_correction_period_events where company_id=cid and month=date_trunc('month',statement_timestamp()at time zone'UTC')::date and state='OPEN')and not exists(select 1 from public.project_correction_period_events where company_id=cid and month=date_trunc('month',statement_timestamp()at time zone'UTC')::date and state='CLOSED'),
 'history',(select coalesce(jsonb_agg(to_jsonb(x)order by version),'[]')from public.source_reclassification_events x where x.company_id=cid and x.source_id=read_source_reclassification.source_id and (public.has_permission(cid,'payroll.manage')or not x.hr_sensitive)),
 'certificates',(select coalesce(jsonb_agg(jsonb_build_object('id',c.id,'contract_id',c.subcontract_id,'reference',c.certificate_reference)),'[]')from public.subcontractor_certificates c where c.company_id=cid and c.status='POSTED'),
 'supplier_bills',(select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'supplier_id',x.supplier_id,'reference',x.expense_reference)),'[]')from public.expenses x where x.company_id=cid and x.funding_mode='SUPPLIER_CREDIT'and x.status='POSTED'));
end$$;
revoke all on function public.read_source_reclassification(uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.read_source_reclassification(uuid,uuid)to authenticated;

-- Existing source/report readers can distinguish the original payment from its correction.
alter function public.read_source_document_links(uuid,uuid[])set schema private;
alter function private.read_source_document_links(uuid,uuid[])rename to read_source_document_links_v85;
revoke all on function private.read_source_document_links_v85(uuid,uuid[])from public,anon,authenticated,service_role;
create function public.read_source_document_links(cid uuid,source_ids uuid[])returns jsonb language plpgsql stable security definer set search_path=''as $$
declare base jsonb;r jsonb:='[]';item jsonb;e public.source_reclassification_events;current_doc jsonb;sid uuid;begin
 base:=private.read_source_document_links_v85(cid,source_ids);
 foreach sid in array source_ids loop
  select x.*into e from public.source_reclassification_events x where x.company_id=cid and x.source_id=sid and x.state='POSTED'order by x.version desc limit 1;
  select x into item from jsonb_array_elements(base)x where x->>'source_id'=sid::text;
  if e.id is not null then
   current_doc:=private.reclassification_document(cid,e.replacement->>'kind',(e.replacement->>'id')::uuid);
   item:=coalesce(item,jsonb_build_object('source_id',sid,'draft_id',sid,'kind','CORRECTION','event',jsonb_build_object('company_id',cid,'state','POSTED')));
   item:=item||jsonb_build_object('correction',jsonb_build_object('id',e.id,'state','POSTED','target',e.snapshot->>'target','reversed',current_doc->>'status'='REVERSED',
    'receipt',case when not e.hr_sensitive or public.has_permission(cid,'payroll.manage')then e.replacement end));
  end if;
  if item is not null then r:=r||jsonb_build_array(item);end if;
 end loop;return r;
end$$;
revoke all on function public.read_source_document_links(uuid,uuid[])from public,anon,authenticated,service_role;
grant execute on function public.read_source_document_links(uuid,uuid[])to authenticated;
