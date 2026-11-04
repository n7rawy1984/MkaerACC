-- Evidence and review only. No funding, liability, cost, opening or adjustment is posted.
create table public.financial_operation_evidence (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null references public.companies(id),
 request_key uuid not null, request_hash text not null,
 kind text not null check(kind in ('PARTNER_FUNDING','PARTNER_WITHDRAWAL','PERSONAL_EXPENSE','PERSONAL_REIMBURSEMENT','CASH_COUNT')),
 event_date date not null, counterparty_id uuid not null,
 amount_minor bigint not null check(amount_minor between 0 and 9000000000000000),
 source_reference text not null check(length(source_reference) between 1 and 200),
 classification text not null, destination text not null,
 recipient_id uuid, treasury_id uuid, project_id uuid,
 description text not null check(length(description) between 1 and 1000),
 supporting_reference text not null check(length(supporting_reference) between 1 and 2000),
 recorded_gl_minor bigint,
 created_by uuid not null references auth.users(id), created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id), unique(company_id,request_key),
 foreign key(company_id,counterparty_id) references public.parties(company_id,id),
 foreign key(company_id,recipient_id) references public.parties(company_id,id),
 foreign key(company_id,treasury_id) references public.treasury_accounts(company_id,id),
 foreign key(company_id,project_id) references public.projects(company_id,id),
 check((kind='CASH_COUNT' and recorded_gl_minor is not null) or (kind<>'CASH_COUNT' and recorded_gl_minor is null)),
 check(kind='CASH_COUNT' or amount_minor>0)
);
create table public.financial_operation_evidence_reviews (
 id uuid primary key default gen_random_uuid(),company_id uuid not null,
 evidence_id uuid not null, request_key uuid not null,
 decision text not null check(decision in ('REVIEWED','NEEDS_INFORMATION')),
 reason text not null check(length(reason) between 1 and 2000),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id),unique(company_id,request_key),
 foreign key(company_id,evidence_id) references public.financial_operation_evidence(company_id,id)
);
alter table public.financial_operation_evidence enable row level security;
alter table public.financial_operation_evidence force row level security;
alter table public.financial_operation_evidence_reviews enable row level security;
alter table public.financial_operation_evidence_reviews force row level security;
revoke all on public.financial_operation_evidence,public.financial_operation_evidence_reviews from public,anon,authenticated,service_role;
grant select on public.financial_operation_evidence,public.financial_operation_evidence_reviews to authenticated;
create policy financial_evidence_read on public.financial_operation_evidence for select to authenticated using (
 (public.has_company_role(company_id,'ACCOUNTING_ADMIN') or public.has_company_role(company_id,'ACCOUNTANT') or public.has_company_role(company_id,'MANAGEMENT_VIEWER'))
 and (kind<>'CASH_COUNT' or public.has_permission(company_id,'payroll.manage'))
);
create policy financial_evidence_review_read on public.financial_operation_evidence_reviews for select to authenticated using(
 exists(select 1 from public.financial_operation_evidence e where e.company_id=financial_operation_evidence_reviews.company_id and e.id=financial_operation_evidence_reviews.evidence_id)
);
create function private.financial_evidence_immutable() returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Evidence and reviews are immutable; submit documented follow-up evidence' using errcode='23514'; end;$$;
revoke all on function private.financial_evidence_immutable() from public,anon,authenticated,service_role;
create trigger financial_evidence_immutable before update or delete on public.financial_operation_evidence for each row execute function private.financial_evidence_immutable();
create trigger financial_evidence_reviews_immutable before update or delete on public.financial_operation_evidence_reviews for each row execute function private.financial_evidence_immutable();
create function public.submit_financial_operation_evidence(target_company_id uuid,target_request_key uuid,business_input jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
declare
 actor uuid:=auth.uid();v jsonb:=business_input;k text; normalized jsonb;
 request_hash text;r public.financial_operation_evidence;
 kind text;pid uuid;recipient uuid;treasury uuid;project uuid;amount bigint;event_date date;
 funding_class text;destination text;ref text;description text;support text;gl uuid;gl_balance numeric;
begin
 if actor is null or not public.has_permission(target_company_id,'accounting.post') or not (public.has_company_role(target_company_id,'ACCOUNTING_ADMIN') or public.has_company_role(target_company_id,'ACCOUNTANT')) then raise exception 'Evidence entry denied' using errcode='42501'; end if;
 if target_request_key is null or v is null or jsonb_typeof(v)<>'object' then raise exception 'Invalid evidence' using errcode='22023'; end if;
 for k in select jsonb_object_keys(v) loop
  if k<>all(array['kind','event_date','counterparty_id','recipient_id','treasury_id','project_id','amount_minor','classification','destination','source_reference','description','supporting_reference']) or jsonb_typeof(v->k) not in ('string','null') then raise exception 'Unsupported evidence field' using errcode='22023'; end if;
 end loop;
 kind:=v->>'kind';pid:=(v->>'counterparty_id')::uuid;recipient:=nullif(v->>'recipient_id','')::uuid;treasury:=nullif(v->>'treasury_id','')::uuid;project:=nullif(v->>'project_id','')::uuid;
 if coalesce(v->>'amount_minor','')!~'^[0-9]+$' then raise exception 'Exact minor units required' using errcode='22023'; end if;
 if coalesce(v->>'event_date','')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then raise exception 'ISO document date required' using errcode='22023';end if;
 amount:=(v->>'amount_minor')::bigint;event_date:=(v->>'event_date')::date;funding_class:=btrim(v->>'classification');destination:=v->>'destination';ref:=btrim(v->>'source_reference');description:=btrim(v->>'description');support:=btrim(v->>'supporting_reference');
 if kind is null or kind not in ('PARTNER_FUNDING','PARTNER_WITHDRAWAL','PERSONAL_EXPENSE','PERSONAL_REIMBURSEMENT','CASH_COUNT') or pid is null or event_date is null or amount not between 0 and 9000000000000000 or (kind<>'CASH_COUNT' and amount=0) or coalesce(length(ref),0) not between 1 and 200 or coalesce(length(description),0) not between 1 and 1000 or coalesce(length(support),0) not between 1 and 2000 then raise exception 'Complete original evidence required' using errcode='22023'; end if;
 if kind in ('PARTNER_FUNDING','PARTNER_WITHDRAWAL') then
  if not exists(select 1 from public.parties p where p.company_id=target_company_id and p.id=pid and p.type='OWNER') then raise exception 'Same-Company Partner required' using errcode='23503'; end if;
  if funding_class is null or funding_class not in ('CAPITAL','ADDITIONAL_CAPITAL','CURRENT_ACCOUNT','PARTNER_LOAN','LOAN_REPAYMENT','DRAWING','DISTRIBUTION','UNCLASSIFIED') then raise exception 'Declared funding nature required' using errcode='23514'; end if;
  if (kind='PARTNER_FUNDING' and funding_class not in ('CAPITAL','ADDITIONAL_CAPITAL','CURRENT_ACCOUNT','PARTNER_LOAN','UNCLASSIFIED')) or (kind='PARTNER_WITHDRAWAL' and funding_class not in ('CURRENT_ACCOUNT','LOAN_REPAYMENT','DRAWING','DISTRIBUTION','UNCLASSIFIED')) then raise exception 'Classification does not describe this evidence type' using errcode='23514'; end if;
 else
  if not exists(select 1 from public.parties p where p.company_id=target_company_id and p.id=pid and (private.party_has_person_role(p.company_id,p.id,'EMPLOYEE') or private.party_has_person_role(p.company_id,p.id,'CUSTODIAN'))) then raise exception 'Same-Company accountable person required' using errcode='23503'; end if;
  if funding_class is distinct from (case when kind='CASH_COUNT' then 'PHYSICAL_COUNT' when kind='PERSONAL_REIMBURSEMENT' then 'REIMBURSEMENT' else 'PERSONAL_FUNDS' end) then raise exception 'Incorrect evidence classification' using errcode='23514'; end if;
 end if;
 if kind='PARTNER_FUNDING' then
  if destination is null or destination not in ('TREASURY','DIRECT_CUSTODY') or recipient is null then raise exception 'Actual recipient and destination required' using errcode='23514'; end if;
  if not exists(select 1 from public.parties p where p.company_id=target_company_id and p.id=recipient and p.type in ('OWNER','EMPLOYEE','CUSTODIAN')) then raise exception 'Same-Company recipient required' using errcode='23503'; end if;
  if destination='DIRECT_CUSTODY' then
   if treasury is not null or not private.party_has_person_role(target_company_id,recipient,'CUSTODIAN') then raise exception 'Direct handover requires Custodian and no fictional Treasury' using errcode='23514'; end if;
  elsif treasury is null then raise exception 'Actual Treasury required' using errcode='23514'; end if;
 elsif kind in ('PARTNER_WITHDRAWAL','PERSONAL_REIMBURSEMENT','CASH_COUNT') then
  if destination is distinct from 'TREASURY' or treasury is null or recipient is not null then raise exception 'Actual Treasury destination required' using errcode='23514'; end if;
 else
  if destination is distinct from 'PERSONAL_FUNDS' or treasury is not null or recipient is not null then raise exception 'Personal funds are distinct from Treasury/Custody' using errcode='23514'; end if;
 end if;
 if treasury is not null then
  select t.gl_account_id into gl from public.treasury_accounts t where t.company_id=target_company_id and t.id=treasury and (kind<>'CASH_COUNT' or t.type='CASH');
  if not found then raise exception 'Same-Company valid Treasury required' using errcode='23503'; end if;
 end if;
 if project is not null and not exists(select 1 from public.projects p where p.company_id=target_company_id and p.id=project) then raise exception 'Same-Company Project required' using errcode='23503'; end if;
 normalized:=jsonb_build_object('kind',kind,'event_date',event_date,'counterparty_id',pid,'recipient_id',recipient,'treasury_id',treasury,'project_id',project,'amount_minor',amount::text,'classification',funding_class,'destination',destination,'source_reference',ref,'description',description,'supporting_reference',support);
 request_hash:=encode(extensions.digest(convert_to(normalized::text,'UTF8'),'sha256'),'hex');
 -- One Company-scoped lock keeps same-key and same-document submissions deterministic.
 perform pg_advisory_xact_lock(hashtextextended('financial-evidence:'||target_company_id::text,0));
 select e.* into r from public.financial_operation_evidence e where e.company_id=target_company_id and e.request_key=target_request_key;
 if found then
  if r.request_hash<>request_hash or r.created_by<>actor then raise exception 'Changed evidence request' using errcode='22023'; end if;
  return jsonb_build_object('id',r.id,'accounting_status','UNPOSTED','replayed',true);
 end if;
 if exists(select 1 from public.financial_operation_evidence e where e.company_id=target_company_id and e.kind=kind and e.counterparty_id=pid and lower(e.source_reference)=lower(ref)) then raise exception 'Original evidence already recorded; review existing reference' using errcode='23505'; end if;
 if kind='CASH_COUNT' then
  if not public.has_permission(target_company_id,'payroll.manage') then raise exception 'Complete cash GL capture denied' using errcode='42501'; end if;
  select coalesce(sum(l.debit_minor::numeric-l.credit_minor::numeric),0) into gl_balance from public.journal_lines l join public.journal_entries j on j.company_id=l.company_id and j.id=l.journal_entry_id where l.company_id=target_company_id and l.account_id=gl and j.posting_date<=event_date;
 end if;
 insert into public.financial_operation_evidence(company_id,request_key,request_hash,kind,event_date,counterparty_id,amount_minor,source_reference,classification,destination,recipient_id,treasury_id,project_id,description,supporting_reference,recorded_gl_minor,created_by)
 values(target_company_id,target_request_key,request_hash,kind,event_date,pid,amount,ref,funding_class,destination,recipient,treasury,project,description,support,gl_balance::bigint,actor) returning * into r;
 return jsonb_build_object('id',r.id,'accounting_status','UNPOSTED','replayed',false);
end;$$;
create function public.review_financial_operation_evidence(target_company_id uuid,target_request_key uuid,target_evidence_id uuid,target_decision text,target_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();r public.financial_operation_evidence_reviews; e public.financial_operation_evidence;reason text:=btrim(target_reason);
begin
 if actor is null or not public.has_permission(target_company_id,'accounting.post') or not (public.has_company_role(target_company_id,'ACCOUNTING_ADMIN') or public.has_company_role(target_company_id,'ACCOUNTANT')) then raise exception 'Evidence review denied' using errcode='42501'; end if;
 if target_request_key is null or target_decision is null or target_decision not in ('REVIEWED','NEEDS_INFORMATION') or coalesce(length(reason),0) not between 1 and 2000 then raise exception 'Documented evidence review required' using errcode='22023'; end if;
 select * into e from public.financial_operation_evidence where company_id=target_company_id and id=target_evidence_id for update;
 if not found then raise exception 'Company evidence not found' using errcode='23503'; end if;
 if e.kind='CASH_COUNT' and not public.has_permission(target_company_id,'payroll.manage') then raise exception 'Cash count review denied' using errcode='42501'; end if;
 perform pg_advisory_xact_lock(hashtextextended('financial-evidence-review:'||target_company_id::text,0));
 select * into r from public.financial_operation_evidence_reviews where company_id=target_company_id and request_key=target_request_key;
 if found then
  if r.evidence_id<>e.id or r.decision<>target_decision or r.reason<>reason or r.created_by<>actor then raise exception 'Changed evidence review' using errcode='22023'; end if;
  return jsonb_build_object('id',r.id,'accounting_status','UNPOSTED','replayed',true);
 end if;
 insert into public.financial_operation_evidence_reviews(company_id,evidence_id,request_key,decision,reason,created_by) values(target_company_id,e.id,target_request_key,target_decision,reason,actor) returning * into r;
 return jsonb_build_object('id',r.id,'accounting_status','UNPOSTED','replayed',false);
end;$$;
revoke all on function public.submit_financial_operation_evidence(uuid,uuid,jsonb),public.review_financial_operation_evidence(uuid,uuid,uuid,text,text) from public,anon,authenticated,service_role;
grant execute on function public.submit_financial_operation_evidence(uuid,uuid,jsonb),public.review_financial_operation_evidence(uuid,uuid,uuid,text,text) to authenticated;
comment on table public.financial_operation_evidence is 'Unposted source evidence only. Declared categories are not approved accounting mappings. Cash count GL snapshots are not certified openings or adjustments.';
create function public.create_finance_partner(target_company_id uuid,target_code text,target_name text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();code_value text:=btrim(target_code);name_value text:=btrim(target_name);p public.parties;
begin
 if actor is null or not public.has_company_role(target_company_id,'ACCOUNTING_ADMIN') or not public.has_permission(target_company_id,'party.manage') then raise exception 'Partner master creation denied' using errcode='42501'; end if;
 if coalesce(length(code_value),0) not between 1 and 50 or coalesce(length(name_value),0) not between 1 and 200 then raise exception 'Partner code and legal/business name required' using errcode='22023'; end if;
 perform pg_advisory_xact_lock(hashtextextended('financial-partner:'||target_company_id::text,0));
 select * into p from public.parties where company_id=target_company_id and lower(btrim(code))=lower(code_value);
 if found then
  if p.type<>'OWNER' or p.name<>name_value then raise exception 'Partner code already belongs to another identity; review existing Party' using errcode='23505'; end if;
  return jsonb_build_object('id',p.id,'accounting_status','MASTER_ONLY','replayed',true);
 end if;
 insert into public.parties(company_id,type,code,name,status,created_by,updated_by) values(target_company_id,'OWNER',code_value,name_value,'ACTIVE',actor,actor) returning * into p;
 return jsonb_build_object('id',p.id,'accounting_status','MASTER_ONLY','replayed',false);
end;$$;
revoke all on function public.create_finance_partner(uuid,text,text) from public,anon,authenticated,service_role;
grant execute on function public.create_finance_partner(uuid,text,text) to authenticated;
