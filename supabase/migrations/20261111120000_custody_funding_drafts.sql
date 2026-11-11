-- 90 (UNAPPLIED revision): durable Treasury transfers or direct owner-equity contributions to Custody.
-- Both financial routes delegate to existing canonical commands; no generic journal primitive.
create table public.custody_funding_draft_events(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),
 draft_id uuid not null,version integer not null check(version>0),request_id uuid not null,request_hash text not null,
 state text not null check(state in('DRAFT','REVIEWED','APPROVED','POSTED','CANCELLED')),
 snapshot jsonb not null check(jsonb_typeof(snapshot)='object'),receipt jsonb,
 reason text not null check(length(reason)between 1 and 2000),created_by uuid not null references auth.users(id),
 created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id),unique(company_id,draft_id,version),unique(company_id,request_id),
 check((state='POSTED')=(receipt is not null))
);
alter table public.custody_funding_draft_events enable row level security;
alter table public.custody_funding_draft_events force row level security;
revoke all on public.custody_funding_draft_events from public,anon,authenticated,service_role;
grant select on public.custody_funding_draft_events to authenticated;
create policy custody_funding_read on public.custody_funding_draft_events for select to authenticated using(
 public.has_company_role(company_id,'ACCOUNTING_ADMIN')or public.has_company_role(company_id,'ACCOUNTANT')or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create trigger custody_funding_immutable before update or delete on public.custody_funding_draft_events for each row execute function private.financial_evidence_immutable();
create function public.command_custody_funding_draft(cid uuid,draft uuid,expected_version integer,request_id uuid,action text,input jsonb,reason text)
returns jsonb language plpgsql security definer set search_path=''as $$
#variable_conflict use_variable
declare actor uuid;p public.custody_funding_draft_events;r public.custody_funding_draft_events;v jsonb;k text;h text;
 d date;holder uuid;treasury uuid;project uuid;owner uuid;mode text;evidence_id uuid;evidence_result jsonb;cfg public.operational_liability_configuration;n bigint;gl uuid;available numeric;future_min numeric;x record;result jsonb;next_state text;
begin
 actor:=private.operational_finance_actor(cid,'accounting.post');
 if draft is null or request_id is null or expected_version is null or expected_version<0 or action is null or action not in('SAVE','REVIEW','APPROVE','POST','CANCEL')or jsonb_typeof(input)is distinct from'object'or octet_length(input::text)>16000 or coalesce(length(btrim(reason)),0)not between 1 and 2000 then raise exception 'Draft, version, action and reason required'using errcode='22023';end if;
 for k in select jsonb_object_keys(input)loop
  if k<>all(array['funding_mode','owner_id','date','amount_minor','holder_id','treasury_id','project_id','payment_method','source_reference','evidence','route_verified','distinct_verified','receipt_verified','funding_verified'])or jsonb_typeof(input->k)not in('string','null')or length(input->>k)>2000 then raise exception 'Unsupported custody input'using errcode='22023';end if;
  input:=jsonb_set(input,array[k],coalesce(to_jsonb(nullif(btrim(input->>k),'')),'null'::jsonb));
 end loop;
 if input->>'amount_minor'~'^[0-9]{1,16}$'then input:=jsonb_set(input,'{amount_minor}',to_jsonb((input->>'amount_minor')::bigint::text));end if;
 h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'draft',draft,'version',expected_version,'action',action,'input',input,'reason',btrim(reason))::text,'UTF8'),'sha256'),'hex');
 perform private.serialize_operational_finance(cid,'OPERATIONS');
 select *into r from public.custody_funding_draft_events e where e.company_id=cid and e.request_id=request_id;
 if found then if r.request_hash<>h then raise exception 'Changed retry intent'using errcode='22023';end if;return to_jsonb(r);end if;
 select *into p from public.custody_funding_draft_events e where e.company_id=cid and e.draft_id=draft order by e.version desc limit 1;
 if coalesce(p.version,0)<>expected_version then raise exception 'Draft changed; refresh'using errcode='40001';end if;
 if p.state in('POSTED','CANCELLED')then raise exception 'Final document is immutable; use canonical reversal for posted funding'using errcode='23514';end if;
 if action='SAVE'then v:=input;next_state:='DRAFT';
 else if p.id is null or input<>'{}'::jsonb then raise exception 'Save current inputs first'using errcode='23514';end if;v:=p.snapshot;
  next_state:=case action when'REVIEW'then'REVIEWED'when'APPROVE'then'APPROVED'when'POST'then'POSTED'else'CANCELLED'end;
 end if;
 mode:=coalesce(v->>'funding_mode','TREASURY');owner:=nullif(v->>'owner_id','')::uuid;
 if mode not in('TREASURY','OWNER_CONTRIBUTION')then raise exception 'Select Treasury transfer or direct owner equity contribution'using errcode='23514';end if;
 holder:=nullif(v->>'holder_id','')::uuid;treasury:=nullif(v->>'treasury_id','')::uuid;project:=nullif(v->>'project_id','')::uuid;
 if holder is not null and not exists(select 1 from public.parties where company_id=cid and id=holder and private.party_has_person_role(cid,id,'CUSTODIAN'))then raise exception 'Same-Company Custodian required'using errcode='23503';end if;
 if treasury is not null and not exists(select 1 from public.treasury_accounts where company_id=cid and id=treasury)then raise exception 'Same-Company Treasury required'using errcode='23503';end if;
 if mode='OWNER_CONTRIBUTION'and(treasury is not null or nullif(v->>'payment_method','')is not null)or mode='TREASURY'and owner is not null then raise exception 'Direct owner contributions cannot include a Treasury or invented payment method; Treasury transfers cannot include an owner'using errcode='23514';end if;
 if owner is not null and not exists(select 1 from public.parties where company_id=cid and id=owner and type='OWNER')then raise exception 'Same-Company Owner required'using errcode='23503';end if;
 if project is not null and not exists(select 1 from public.projects where company_id=cid and id=project)then raise exception 'Same-Company Project required'using errcode='23503';end if;
 if coalesce(length(v->>'source_reference'),0)>200 then raise exception 'Source reference too long'using errcode='22023';end if;
 -- Reserve the documented event reference across all active drafts, never date+amount alone.
 if nullif(v->>'source_reference','')is not null and exists(select 1 from public.custody_funding_draft_events e where e.company_id=cid and e.draft_id<>draft and lower(e.snapshot->>'source_reference')=lower(v->>'source_reference')and e.state<>'CANCELLED'and e.version=(select max(q.version)from public.custody_funding_draft_events q where q.company_id=cid and q.draft_id=e.draft_id))then raise exception 'Existing source funding draft; open it instead'using errcode='23505';end if;
 if action in('REVIEW','APPROVE','POST')then
  if action='REVIEW'and p.state<>'DRAFT'or action='APPROVE'and p.state<>'REVIEWED'or action='POST'and p.state<>'APPROVED'then raise exception 'Draft -> Review -> Approval -> Posting required'using errcode='23514';end if;
  if action='APPROVE'and not public.has_company_role(cid,'ACCOUNTING_ADMIN')then raise exception 'Accounting Admin approval required'using errcode='42501';end if;
  if coalesce(v->>'date','')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'or coalesce(v->>'amount_minor','')!~'^[0-9]{1,16}$'then raise exception 'Verified calendar date and exact positive minor units required'using errcode='23514';end if;
  d:=(v->>'date')::date;n:=(v->>'amount_minor')::bigint;perform private.opening_period(cid,d);
  if n not between 1 and 9000000000000000 or holder is null or coalesce(length(v->>'source_reference'),0)<1 or coalesce(length(v->>'evidence'),0)<1 then raise exception 'Complete custody funding evidence required'using errcode='23514';end if;
  foreach k in array array['route_verified','distinct_verified','receipt_verified','funding_verified']loop if v->>k is distinct from'true'then raise exception 'Verify actual receipt, funding route, funding nature and distinct event before review'using errcode='23514';end if;end loop;
  perform 1 from public.parties where company_id=cid and id=holder and status='ACTIVE'for share;if not found then raise exception 'Active Custodian required'using errcode='23514';end if;
  if not exists(select 1 from public.accounts where company_id=cid and system_key='CUSTODY_ADVANCE'and status='ACTIVE'and account_type='ASSET'and requires_party)then raise exception 'Valid Custody control mapping required'using errcode='23514';end if;
  if mode='OWNER_CONTRIBUTION'then
   perform 1 from public.parties where company_id=cid and id=owner and type='OWNER'and status='ACTIVE'for share;
   if not found then raise exception 'Active confirmed Owner contributor required'using errcode='23514';end if;
   select c.*into cfg from public.operational_liability_configuration c join public.accounts a on a.company_id=c.company_id and a.id=c.account_id where c.company_id=cid and c.classification='PARTNER_ADDITIONAL_CAPITAL'and c.account_type='EQUITY'and not c.allow_withdrawals and a.account_type='EQUITY'and a.requires_party and a.status='ACTIVE'order by c.created_at desc,c.id desc limit 1;
   if cfg.id is null then raise exception 'Configure dedicated Owner Contributions equity; registered Share Capital, loans, current liabilities and revenue are not this route'using errcode='23514';end if;
   if exists(select 1 from public.financial_operation_evidence where company_id=cid and lower(source_reference)=lower(v->>'source_reference'))then raise exception 'Owner funding evidence already exists; reconcile its original document'using errcode='23505';end if;
  else
   if treasury is null or coalesce(v->>'payment_method','')not in('CASH','BANK','TRANSFER','CHEQUE','OTHER')then raise exception 'Actual Treasury and payment method required for a transfer'using errcode='23514';end if;
   select t.gl_account_id into gl from public.treasury_accounts t join public.accounts a on a.company_id=t.company_id and a.id=t.gl_account_id where t.company_id=cid and t.id=treasury and t.status='ACTIVE'and a.status='ACTIVE'and a.account_type='ASSET'and not a.requires_party and(t.project_id is null or t.project_id=project)for update of t;
   if gl is null then raise exception 'Valid actual Treasury mapping required'using errcode='23514';end if;
  end if;
  if project is not null and not exists(select 1 from public.projects where company_id=cid and id=project and status='ACTIVE')then raise exception 'Active Project required for new funding'using errcode='23514';end if;
  if exists(select 1 from public.custody_advances where company_id=cid and external_reference=v->>'source_reference')then raise exception 'Funding already recorded; reconcile the existing advance'using errcode='23505';end if;
  if mode='TREASURY'then
  perform private.serialize_operational_finance(cid,'TREASURY');
  select coalesce(sum(l.debit_minor::numeric-l.credit_minor::numeric),0)into available from public.journal_lines l join public.journal_entries j on j.company_id=l.company_id and j.id=l.journal_entry_id where l.company_id=cid and l.treasury_account_id=treasury and l.account_id=gl and j.posting_date<=d;
  select min(b)into future_min from(select j.posting_date,sum(sum(l.debit_minor::numeric-l.credit_minor::numeric))over(order by j.posting_date)b from public.journal_lines l join public.journal_entries j on j.company_id=l.company_id and j.id=l.journal_entry_id where l.company_id=cid and l.treasury_account_id=treasury and l.account_id=gl group by j.posting_date)s where posting_date>d;
  if least(available,coalesce(future_min,available))<n then raise exception 'Insufficient recorded historical Treasury funding; preserve draft and supply funding evidence'using errcode='23514';end if;
  end if;
 end if;
 if action='POST'then
  if mode='OWNER_CONTRIBUTION'then
   evidence_result:=public.submit_financial_operation_evidence(cid,draft,jsonb_build_object('kind','PARTNER_FUNDING','event_date',d::text,'counterparty_id',owner::text,'recipient_id',holder::text,'treasury_id',null,'project_id',project::text,'amount_minor',n::text,'classification','ADDITIONAL_CAPITAL','destination','DIRECT_CUSTODY','source_reference',v->>'source_reference','description','Permanent non-repayable owner equity contribution to Custody, pending capitalization','supporting_reference',v->>'evidence'));
   evidence_id:=(evidence_result->>'id')::uuid;
   perform public.review_financial_operation_evidence(cid,draft,evidence_id,'REVIEWED','Approved custody funding draft: '||left(p.reason,900));
   result:=public.post_reviewed_financial_operation(cid,draft,evidence_id,jsonb_build_object('approved_classification','PARTNER_ADDITIONAL_CAPITAL','approval_reference',left(p.reason,1000)));
   result:=result||jsonb_build_object('evidence_id',evidence_id,'funding_mode',mode);
  else
  select *into x from public.post_custody_advance(cid,d,holder,treasury,project,n,(v->>'payment_method')::public.payment_method,v->>'source_reference',v->>'evidence',draft);
  result:=jsonb_build_object('id',x.custody_advance_id,'journal',x.journal_entry_id,'reference',x.advance_reference,'funding_mode',mode);
  end if;
 end if;
 insert into public.custody_funding_draft_events(company_id,draft_id,version,request_id,request_hash,state,snapshot,receipt,reason,created_by)values(cid,draft,expected_version+1,request_id,h,next_state,v,result,btrim(reason),actor)returning *into r;
 return to_jsonb(r);
end;$$;
revoke all on function public.command_custody_funding_draft(uuid,uuid,integer,uuid,text,jsonb,text)from public,anon,authenticated,service_role;
grant execute on function public.command_custody_funding_draft(uuid,uuid,integer,uuid,text,jsonb,text)to authenticated;
