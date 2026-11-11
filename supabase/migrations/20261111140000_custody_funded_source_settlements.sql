-- 91: extend existing canonical settlements with real Custody funding. No backfill.
-- All amounts are BIGINT minor units; posted rows and existing Treasury clients retained.
alter table public.subcontractor_advances alter column treasury_account_id drop not null;
alter table public.subcontractor_advances add column custodian_id uuid, add column custody_account_id uuid,
 add foreign key(company_id,custodian_id) references public.parties(company_id,id),
 add foreign key(company_id,custody_account_id) references public.accounts(company_id,id),
 add constraint subcontractor_advances_funding_shape check(
 (treasury_account_id is not null and custodian_id is null and custody_account_id is null)or
 (treasury_account_id is null and custodian_id is not null and custody_account_id is not null));
alter table public.subcontractor_payments alter column treasury_account_id drop not null;
alter table public.subcontractor_payments add column custodian_id uuid, add column custody_account_id uuid,
 add foreign key(company_id,custodian_id) references public.parties(company_id,id),
 add foreign key(company_id,custody_account_id) references public.accounts(company_id,id),
 add constraint subcontractor_payments_funding_shape check(
 (treasury_account_id is not null and custodian_id is null and custody_account_id is null)or
 (treasury_account_id is null and custodian_id is not null and custody_account_id is not null));
alter table public.hr_advance_postings alter column treasury_id drop not null;
alter table public.hr_advance_postings add column custodian_id uuid, add column custody_account_id uuid,
 add foreign key(company_id,custodian_id) references public.parties(company_id,id),
 add foreign key(company_id,custody_account_id) references public.accounts(company_id,id),
 add constraint hr_advance_postings_funding_shape check(
 (treasury_id is not null and custodian_id is null and custody_account_id is null)or
 (treasury_id is null and custodian_id is not null and custody_account_id is not null));
create function private.guard_settlement_funding_history()returns trigger language plpgsql set search_path=''as $$begin
 if new.custodian_id is distinct from old.custodian_id or new.custody_account_id is distinct from old.custody_account_id then
 raise exception 'Original funding immutable; use canonical reversal'using errcode='23514';end if;return new;end$$;
revoke all on function private.guard_settlement_funding_history()from public,anon,authenticated,service_role;
create trigger advance_funding_immutable before update on public.subcontractor_advances for each row execute function private.guard_settlement_funding_history();
create trigger payment_funding_immutable before update on public.subcontractor_payments for each row execute function private.guard_settlement_funding_history();

-- A private business funding resolver, never a browser-selected GL primitive.
create function private.settlement_funding(cid uuid,treasury uuid,holder uuid,d date,n bigint,project uuid)returns jsonb
language plpgsql volatile security definer set search_path=''as $$
declare gl uuid;t public.treasury_accounts;available numeric;future_min numeric;begin
 perform private.operational_finance_actor(cid,'accounting.post');perform private.serialize_operational_finance(cid,'OPERATIONS');perform private.opening_period(cid,d);
 if (treasury is null)=(holder is null)or n is null or n not between 1 and 9000000000000000 then raise exception 'Choose one actual Treasury or Custody payer and positive amount'using errcode='23514';end if;
 if holder is null then
 select *into t from public.treasury_accounts where company_id=cid and id=treasury and status='ACTIVE'for share;
 if not found or(t.project_id is not null and t.project_id is distinct from project)then raise exception 'Actual same-Company scoped Treasury required'using errcode='23514';end if;
 select id into gl from public.accounts where company_id=cid and id=t.gl_account_id and status='ACTIVE'and account_type='ASSET';
 if gl is null then raise exception 'Active Treasury asset mapping required'using errcode='23514';end if;
 return jsonb_build_object('account_id',gl,'treasury_account_id',treasury,'project_id',project,'debit_minor','0','credit_minor',n::text);
 end if;
 perform 1 from public.parties where company_id=cid and id=holder and status='ACTIVE'and private.party_has_person_role(cid,id,'CUSTODIAN')for update;
 if not found then raise exception 'Active same-Company Custody holder required'using errcode='23514';end if;
 select id into gl from public.accounts where company_id=cid and system_key='CUSTODY_ADVANCE'and account_type='ASSET'and requires_party and status='ACTIVE'for share;
 if gl is null then raise exception 'Configure the canonical Custody control account'using errcode='23514';end if;
 select coalesce(sum(l.debit_minor::numeric-l.credit_minor),0)into available from public.journal_lines l join public.journal_entries j on j.company_id=l.company_id and j.id=l.journal_entry_id where l.company_id=cid and l.account_id=gl and l.party_id=holder and j.posting_date<=d;
 select min(b)into future_min from(select j.posting_date,sum(sum(l.debit_minor::numeric-l.credit_minor))over(order by j.posting_date)b from public.journal_lines l join public.journal_entries j on j.company_id=l.company_id and j.id=l.journal_entry_id where l.company_id=cid and l.account_id=gl and l.party_id=holder group by j.posting_date)x where posting_date>d;
 if least(available,coalesce(future_min,available))<n then raise exception 'Insufficient historical Custody balance; no invented funding'using errcode='23514';end if;
 return jsonb_build_object('account_id',gl,'party_id',holder,'project_id',project,'debit_minor','0','credit_minor',n::text);
end$$;
revoke all on function private.settlement_funding(uuid,uuid,uuid,date,bigint,uuid)from public,anon,authenticated,service_role;
create or replace function private.post_subcontractor_advance_funded(
  target_company_id uuid, target_advance_date date, target_subcontract_id uuid,
  target_treasury_account_id uuid, target_amount_minor bigint, target_payment_method public.payment_method,
  target_external_reference text, target_notes text, target_idempotency_key uuid, target_custodian_id uuid
)
returns table (subcontractor_advance_id uuid, advance_reference text, journal_entry_id uuid, replayed boolean)
language plpgsql security definer set search_path = '' as $$
declare
  actor_id uuid := auth.uid(); normalized_external_reference text := nullif(btrim(target_external_reference), '');
  normalized_notes text := nullif(btrim(target_notes), ''); subcontract_row public.subcontracts;
  project_row public.projects; treasury_row public.treasury_accounts; advance_account_id uuid;
  request_hash text; request_row private.financial_command_requests; new_advance_id uuid := gen_random_uuid();
  new_reference text; new_journal_id uuid; journal_lines jsonb; funding jsonb;
begin
  if actor_id is null or not public.has_permission(target_company_id, 'accounting.post') then
    raise exception 'Not authorized to post Subcontractor Advances' using errcode = '42501';
  end if;
  if target_company_id is null or target_advance_date is null or target_subcontract_id is null
     or (target_treasury_account_id is null and target_custodian_id is null) or target_amount_minor is null
     or target_payment_method is null or target_idempotency_key is null then
    raise exception 'Required Subcontractor Advance input is missing' using errcode = '22023';
  end if;
  if target_amount_minor not between 1 and 9000000000000000 then
    raise exception 'Subcontractor Advance amount is invalid' using errcode = '22023';
  end if;
  if normalized_external_reference is not null and length(normalized_external_reference) > 200 then
    raise exception 'External reference is too long' using errcode = '22023';
  end if;
  if normalized_notes is not null and length(normalized_notes) > 2000 then
    raise exception 'Subcontractor Advance notes are too long' using errcode = '22023';
  end if;
  perform private.serialize_operational_finance(target_company_id,'OPERATIONS');
  request_hash := encode(extensions.digest(convert_to((jsonb_build_object(
    'company_id', target_company_id, 'advance_date', target_advance_date, 'subcontract_id', target_subcontract_id,
    'treasury_id', target_treasury_account_id, 'amount_minor', target_amount_minor,
    'payment_method', target_payment_method, 'external_reference', normalized_external_reference,
    'notes', normalized_notes
  )||case when target_custodian_id is null then '{}'::jsonb else jsonb_build_object('custodian_id',target_custodian_id)end)::text, 'UTF8'), 'sha256'), 'hex');
  request_row := private.reserve_financial_command(target_company_id, 'POST_SUBCONTRACTOR_ADVANCE',
    target_idempotency_key, request_hash, actor_id);
  if request_row.status = 'COMPLETED' then
    return query select a.id, a.advance_reference, a.posted_journal_entry_id, true
    from public.subcontractor_advances a where a.company_id = target_company_id
      and a.posted_journal_entry_id = request_row.resulting_journal_entry_id;
    return;
  end if;
  select s.* into subcontract_row from public.subcontracts s
  where s.company_id = target_company_id and s.id = target_subcontract_id for update;
  if not found then raise exception 'Subcontract not found in company' using errcode = '23503'; end if;
  if subcontract_row.status is distinct from 'ACTIVE' then
    raise exception 'Only an ACTIVE Subcontract can receive a new Advance' using errcode = '23514';
  end if;
  select p.* into project_row from public.projects p
  where p.company_id = target_company_id and p.id = subcontract_row.project_id;
  if not found then raise exception 'Subcontract Project not found in company' using errcode = '23503'; end if;
  if project_row.status = 'CLOSED' then
    raise exception 'Closed Project cannot receive a new Subcontractor Advance' using errcode = '23514';
  end if;
  perform 1 from public.parties p where p.company_id = target_company_id
    and p.id = subcontract_row.subcontractor_id and p.type = 'SUBCONTRACTOR' and p.status = 'ACTIVE' for update;
  if not found then raise exception 'Active Subcontractor not found in company' using errcode = '23514'; end if;
  select a.id into advance_account_id from public.accounts a
  where a.company_id = target_company_id and a.system_key = 'SUBCONTRACTOR_ADVANCE'
    and a.status = 'ACTIVE' and a.account_type = 'ASSET';
  if advance_account_id is null then raise exception 'Subcontractor Advance system account is unavailable' using errcode = '23514'; end if;
  funding:=private.settlement_funding(target_company_id,target_treasury_account_id,target_custodian_id,target_advance_date,target_amount_minor,subcontract_row.project_id);
  new_reference := private.allocate_reference(target_company_id, 'SADV', extract(year from target_advance_date)::integer);
  insert into public.subcontractor_advances (id, company_id, advance_reference, advance_date, project_id,
    subcontractor_id, subcontract_id, treasury_account_id, custodian_id, custody_account_id, amount_minor, payment_method,
    external_reference, notes, created_by, updated_by)
  values (new_advance_id, target_company_id, new_reference, target_advance_date, subcontract_row.project_id,
    subcontract_row.subcontractor_id, subcontract_row.id, target_treasury_account_id, target_custodian_id, case when target_custodian_id is not null then (funding->>'account_id')::uuid end, target_amount_minor,
    target_payment_method, normalized_external_reference, normalized_notes, actor_id, actor_id);
  journal_lines := jsonb_build_array(
    jsonb_build_object('account_id', advance_account_id, 'debit_minor', target_amount_minor, 'credit_minor', 0,
      'project_id', subcontract_row.project_id, 'party_id', subcontract_row.subcontractor_id,
      'subcontract_id', subcontract_row.id, 'memo', 'Subcontractor Advance funded'),
    funding||case when target_custodian_id is null then jsonb_build_object('subcontract_id',subcontract_row.id)else '{}'::jsonb end||jsonb_build_object('memo','Subcontractor Advance actual funding'));
  new_journal_id := private.create_journal(target_company_id, target_advance_date,
    'Subcontractor Advance ' || new_reference, 'SUBCONTRACTOR_ADVANCE', new_advance_id,
    'ORIGINAL', journal_lines, actor_id, null);
  update public.subcontractor_advances set status = 'POSTED', posted_journal_entry_id = new_journal_id,
    posted_at = now(), posted_by = actor_id, updated_by = actor_id where id = new_advance_id;
  perform private.complete_financial_command(request_row.id, new_journal_id);
  return query select new_advance_id, new_reference, new_journal_id, false;
end;
$$;
revoke all on function private.post_subcontractor_advance_funded(uuid,date,uuid,uuid,bigint,public.payment_method,text,text,uuid,uuid)from public,anon,authenticated,service_role;
create or replace function private.post_subcontractor_advance(target_company_id uuid,target_advance_date date,target_subcontract_id uuid,target_treasury_account_id uuid,target_amount_minor bigint,target_payment_method public.payment_method,target_external_reference text,target_notes text,target_idempotency_key uuid)returns table(subcontractor_advance_id uuid,advance_reference text,journal_entry_id uuid,replayed boolean) language sql security definer set search_path=''as $$select *from private.post_subcontractor_advance_funded(target_company_id,target_advance_date,target_subcontract_id,target_treasury_account_id,target_amount_minor,target_payment_method,target_external_reference,target_notes,target_idempotency_key,null)$$;
create or replace function public.post_subcontractor_advance(
  target_company_id uuid, target_advance_date date, target_subcontract_id uuid,
  target_treasury_account_id uuid, target_amount_minor bigint, target_payment_method public.payment_method,
  target_external_reference text, target_notes text, target_idempotency_key uuid
)
returns table (subcontractor_advance_id uuid, advance_reference text, journal_entry_id uuid, replayed boolean)
language sql security definer set search_path=''as $$select *from private.post_subcontractor_advance_funded(target_company_id,target_advance_date,target_subcontract_id,target_treasury_account_id,target_amount_minor,target_payment_method,target_external_reference,target_notes,target_idempotency_key,null)$$;
create function public.post_subcontractor_advance(
  target_company_id uuid, target_advance_date date, target_subcontract_id uuid,
  target_treasury_account_id uuid, target_amount_minor bigint, target_payment_method public.payment_method,
  target_external_reference text, target_notes text, target_idempotency_key uuid,target_custodian_id uuid
)
returns table (subcontractor_advance_id uuid, advance_reference text, journal_entry_id uuid, replayed boolean)
language sql security definer set search_path=''as $$select *from private.post_subcontractor_advance_funded(target_company_id,target_advance_date,target_subcontract_id,target_treasury_account_id,target_amount_minor,target_payment_method,target_external_reference,target_notes,target_idempotency_key,target_custodian_id)$$;
revoke all on function public.post_subcontractor_advance(uuid,date,uuid,uuid,bigint,public.payment_method,text,text,uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.post_subcontractor_advance(uuid,date,uuid,uuid,bigint,public.payment_method,text,text,uuid,uuid)to authenticated;
create function private.post_subcontractor_payment_funded(
  target_company_id uuid,target_payment_date date,target_subcontract_id uuid,
  target_treasury_account_id uuid,target_total_amount_minor bigint,target_payment_method public.payment_method,
  target_external_reference text,target_notes text,target_allocations jsonb,target_idempotency_key uuid,target_custodian_id uuid
)
returns table (subcontractor_payment_id uuid,payment_reference text,journal_entry_id uuid,replayed boolean)
language plpgsql security definer set search_path = '' as $$
declare actor_id uuid:=auth.uid(); normalized_external_reference text:=nullif(btrim(target_external_reference),'');
  normalized_notes text:=nullif(btrim(target_notes),''); normalized_allocations jsonb; allocation_total numeric;
  request_hash text; request_row private.financial_command_requests; subcontract_row public.subcontracts;
  treasury_row public.treasury_accounts; payable_account_id uuid; item jsonb;
  new_payment_id uuid:=gen_random_uuid(); new_reference text; new_journal_id uuid; lines jsonb;funding jsonb;
begin
  if actor_id is null or not public.has_permission(target_company_id,'accounting.post') then
    raise exception 'Not authorized to post Subcontractor Payments' using errcode='42501'; end if;
  if target_company_id is null or target_payment_date is null or target_subcontract_id is null
     or (target_treasury_account_id is null and target_custodian_id is null) or target_total_amount_minor is null
     or target_payment_method is null or target_idempotency_key is null then
    raise exception 'Required Subcontractor Payment input is missing' using errcode='22023'; end if;
  if target_total_amount_minor not between 1 and 9000000000000000 then
    raise exception 'Subcontractor Payment total is invalid' using errcode='22023'; end if;
  if normalized_external_reference is not null and length(normalized_external_reference)>200 then
    raise exception 'External payment reference is too long' using errcode='22023'; end if;
  if normalized_notes is not null and length(normalized_notes)>2000 then
    raise exception 'Subcontractor Payment notes are too long' using errcode='22023'; end if;
  if target_allocations is null or jsonb_typeof(target_allocations)<>'array'
     or jsonb_array_length(target_allocations) not between 1 and 999 then
    raise exception 'Subcontractor Payment requires 1 to 999 allocations' using errcode='22023'; end if;
  if exists(select 1 from jsonb_array_elements(target_allocations) x
    where not(x?'certificate_id') or not(x?'amount_minor')) then
    raise exception 'Each allocation requires certificate_id and amount_minor' using errcode='22023'; end if;
  begin
    select jsonb_agg(jsonb_build_object('certificate_id',(x->>'certificate_id')::uuid,
      'amount_minor',(x->>'amount_minor')::bigint) order by (x->>'certificate_id')::uuid),
      sum((x->>'amount_minor')::numeric) into normalized_allocations,allocation_total
    from jsonb_array_elements(target_allocations) x;
  exception when others then raise exception 'Valid Certificate allocation identifiers and amounts are required' using errcode='22023'; end;
  if allocation_total is distinct from target_total_amount_minor::numeric then
    raise exception 'Subcontractor Payment total must equal allocation total' using errcode='23514'; end if;
  if exists(select 1 from jsonb_array_elements(normalized_allocations) x
    where (x->>'amount_minor')::bigint<=0) then raise exception 'Allocation amounts must be positive' using errcode='22023'; end if;
  if exists(select 1 from jsonb_array_elements(normalized_allocations) x
    group by (x->>'certificate_id')::uuid having count(*)>1) then
    raise exception 'A Certificate may appear only once per Subcontractor Payment' using errcode='23505'; end if;

  perform private.serialize_operational_finance(target_company_id,'OPERATIONS');
  request_hash:=encode(extensions.digest(convert_to((jsonb_build_object('company_id',target_company_id,
    'payment_date',target_payment_date,'subcontract_id',target_subcontract_id,
    'treasury_id',target_treasury_account_id,'total_amount_minor',target_total_amount_minor,
    'payment_method',target_payment_method,'external_reference',normalized_external_reference,
    'notes',normalized_notes,'allocations',normalized_allocations)||case when target_custodian_id is null then '{}'::jsonb else jsonb_build_object('custodian_id',target_custodian_id)end)::text,'UTF8'),'sha256'),'hex');
  request_row:=private.reserve_financial_command(target_company_id,'POST_SUBCONTRACTOR_PAYMENT',
    target_idempotency_key,request_hash,actor_id);
  if request_row.status='COMPLETED' then
    return query select p.id,p.payment_reference,p.posted_journal_entry_id,true
    from public.subcontractor_payments p where p.company_id=target_company_id
      and p.posted_journal_entry_id=request_row.resulting_journal_entry_id; return;
  end if;
  select s.* into subcontract_row from public.subcontracts s
  where s.company_id=target_company_id and s.id=target_subcontract_id for update;
  if not found then raise exception 'Subcontract not found in company' using errcode='23503'; end if;
  -- Existing liabilities remain settleable for CLOSED/COMPLETED Projects or Subcontracts and inactive parties.
  perform 1 from public.parties p where p.company_id=target_company_id
    and p.id=subcontract_row.subcontractor_id and p.type='SUBCONTRACTOR';
  if not found then raise exception 'Subcontractor identity is invalid' using errcode='23514'; end if;
  select a.id into payable_account_id from public.accounts a where a.company_id=target_company_id
    and a.system_key='SUBCONTRACTOR_PAYABLE' and a.status='ACTIVE' and a.account_type='LIABILITY';
  if payable_account_id is null then raise exception 'Subcontractor Payable system account is unavailable' using errcode='23514'; end if;

  funding:=private.settlement_funding(target_company_id,target_treasury_account_id,target_custodian_id,target_payment_date,target_total_amount_minor,subcontract_row.project_id);
  new_reference:=private.allocate_reference(target_company_id,'SCPAY',extract(year from target_payment_date)::integer);
  insert into public.subcontractor_payments(id,company_id,payment_reference,payment_date,project_id,
    subcontractor_id,subcontract_id,treasury_account_id,custodian_id,custody_account_id,total_amount_minor,payment_method,
    external_reference,notes,created_by,updated_by)
  values(new_payment_id,target_company_id,new_reference,target_payment_date,subcontract_row.project_id,
    subcontract_row.subcontractor_id,subcontract_row.id,target_treasury_account_id,target_custodian_id,case when target_custodian_id is not null then (funding->>'account_id')::uuid end,target_total_amount_minor,
    target_payment_method,normalized_external_reference,normalized_notes,actor_id,actor_id);
  for item in select x from jsonb_array_elements(normalized_allocations) x order by (x->>'certificate_id')::uuid loop
    insert into public.subcontractor_payment_allocations(company_id,subcontractor_payment_id,
      subcontractor_certificate_id,allocated_amount_minor,created_by)
    values(target_company_id,new_payment_id,(item->>'certificate_id')::uuid,(item->>'amount_minor')::bigint,actor_id);
  end loop;
  lines:=jsonb_build_array(
    jsonb_build_object('account_id',payable_account_id,'debit_minor',target_total_amount_minor,'credit_minor',0,
      'project_id',subcontract_row.project_id,'party_id',subcontract_row.subcontractor_id,
      'subcontract_id',subcontract_row.id,'memo','Subcontractor payable settlement'),
    funding||case when target_custodian_id is null then jsonb_build_object('subcontract_id',subcontract_row.id)else '{}'::jsonb end||jsonb_build_object('memo','Subcontractor Payment actual funding'));
  new_journal_id:=private.create_journal(target_company_id,target_payment_date,
    'Subcontractor Payment '||new_reference,'SUBCONTRACTOR_PAYMENT',new_payment_id,'ORIGINAL',lines,actor_id,null);
  update public.subcontractor_payments set status='POSTED',posted_journal_entry_id=new_journal_id,
    posted_at=now(),posted_by=actor_id,updated_by=actor_id where id=new_payment_id;
  perform private.complete_financial_command(request_row.id,new_journal_id);
  return query select new_payment_id,new_reference,new_journal_id,false;
end;
$$;
revoke all on function private.post_subcontractor_payment_funded(uuid,date,uuid,uuid,bigint,public.payment_method,text,text,jsonb,uuid,uuid)from public,anon,authenticated,service_role;
create or replace function public.post_subcontractor_payment(target_company_id uuid,target_payment_date date,target_subcontract_id uuid,target_treasury_account_id uuid,target_total_amount_minor bigint,target_payment_method public.payment_method,target_external_reference text,target_notes text,target_allocations jsonb,target_idempotency_key uuid)returns table(subcontractor_payment_id uuid,payment_reference text,journal_entry_id uuid,replayed boolean) language sql security definer set search_path=''as $$select *from private.post_subcontractor_payment_funded(target_company_id,target_payment_date,target_subcontract_id,target_treasury_account_id,target_total_amount_minor,target_payment_method,target_external_reference,target_notes,target_allocations,target_idempotency_key,null)$$;
create or replace function public.post_subcontractor_payment(target_company_id uuid,target_payment_date date,target_subcontract_id uuid,target_treasury_account_id uuid,target_total_amount_minor bigint,target_payment_method public.payment_method,target_external_reference text,target_notes text,target_allocations jsonb,target_idempotency_key uuid,target_custodian_id uuid)returns table(subcontractor_payment_id uuid,payment_reference text,journal_entry_id uuid,replayed boolean) language sql security definer set search_path=''as $$select *from private.post_subcontractor_payment_funded(target_company_id,target_payment_date,target_subcontract_id,target_treasury_account_id,target_total_amount_minor,target_payment_method,target_external_reference,target_notes,target_allocations,target_idempotency_key,target_custodian_id)$$;
revoke all on function public.post_subcontractor_payment(uuid,date,uuid,uuid,bigint,public.payment_method,text,text,jsonb,uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.post_subcontractor_payment(uuid,date,uuid,uuid,bigint,public.payment_method,text,text,jsonb,uuid,uuid)to authenticated;
create or replace function public.command_hr(cid uuid,request_id uuid,action text,input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
declare actor uuid;h text;r jsonb;old private.hr_command_receipts;emp uuid;d date;m date;v integer;policy public.hr_policy_events;t public.hr_term_events;latest public.hr_term_events;
 aid uuid;k text;item jsonb;total numeric:=0;week integer[];st integer;en integer;br integer;worked integer;paid integer;ex integer;ot integer;otpay bigint;attendance_status text;pid uuid;rid uuid;account public.accounts;setup public.hr_payroll_setup_events;
 loan public.hr_advance_postings;amount bigint;limit_amount bigint;j uuid;req private.financial_command_requests;balance numeric;prior integer;holder uuid;funding jsonb;
begin
 actor:=private.operational_finance_actor(cid,'payroll.manage');perform private.attendance_company_lock(cid);
 if request_id is null or input is null or jsonb_typeof(input)<>'object' or octet_length(input::text)>40000 or action is null or action not in ('POLICY','TERMS','CALENDAR','ATTENDANCE','REVIEW','SETUP','ADVANCE','REVERSE_ADVANCE','RECOVERY') then raise exception 'Invalid HR command' using errcode='22023';end if;
 h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'action',action,'input',input)::text,'UTF8'),'sha256'),'hex');
 select * into old from private.hr_command_receipts where company_id=cid and hr_command_receipts.request_id=command_hr.request_id;
 if found then if old.hash<>h then raise exception 'Changed HR request' using errcode='22023';end if;return old.result;end if;
 if action='SETUP' and not public.has_permission(cid,'account.manage') then raise exception 'Account configuration denied' using errcode='42501';end if;
 if action in ('POLICY','TERMS','CALENDAR','SETUP','ADVANCE','REVERSE_ADVANCE','RECOVERY') and not public.has_company_role(cid,'ACCOUNTING_ADMIN') then raise exception 'Accounting Admin approval required' using errcode='42501';end if;
 if coalesce(length(btrim(input->>'evidence')),0) not between 1 and 1000 then raise exception 'Approval/correction evidence required' using errcode='23514';end if;
 v:=coalesce((input->>'version')::integer,0);
 if action='POLICY' then
  m:=(input->>'effective_month')::date;
  if m is null or extract(day from m)<>1 or input->>'method' is distinct from 'SCHEDULED_MINUTES' or input->>'timezone' is distinct from 'Asia/Dubai' or input->>'approved' is distinct from 'true' then raise exception 'Explicitly approve scheduled-minute salary basis and Dubai calendar policy' using errcode='23514';end if;
  select coalesce(max(version),0) into prior from public.hr_policy_events where company_id=cid;if prior<>v then raise exception 'Policy version changed' using errcode='40001';end if;
  if exists(select 1 from public.payroll_draft_periods where company_id=cid and month>=m) or exists(select 1 from public.attendance_periods where company_id=cid and month>=m and (reviewed_revision is not null or locked_at is not null)) or exists(select 1 from public.attendance_exceptions where company_id=cid and absence_date>=m) then raise exception 'Cutover cannot reinterpret existing payroll/reviewed Lite periods or exceptions' using errcode='23514';end if;
  insert into public.hr_policy_events(company_id,version,effective_month,timezone,method,approval,created_by) values(cid,v+1,m,'Asia/Dubai','SCHEDULED_MINUTES',input->>'evidence',actor) returning id into rid;
 elsif action='TERMS' then
  emp:=(input->>'employee_id')::uuid;d:=(input->>'effective_on')::date;
  if not exists(select 1 from public.parties where company_id=cid and id=emp and private.party_has_person_role(cid,id,'EMPLOYEE')) then raise exception 'Company Employee required' using errcode='23503';end if;
  select * into latest from public.hr_term_events where company_id=cid and employee_id=emp order by version desc limit 1;
  if coalesce(latest.version,0)<>v then raise exception 'Employment version changed' using errcode='40001';end if;
  if d is null or (latest.id is not null and d<=latest.effective_on) then raise exception 'Amendment must be later than previous effective terms' using errcode='23514';end if;
  if (input->>'status'='ENDED' and nullif(input->>'employed_until','')::date is distinct from d-1) or (input->>'status'='ACTIVE' and nullif(input->>'employed_until','')::date<d) then raise exception 'Ended terms must take effect the day after last employment; active terms cannot start after employment ends' using errcode='23514';end if;
  perform private.hr_open_terms(cid,d);
  if private.hr_policy(cid,date_trunc('month',d)::date) is null then raise exception 'Approve HR policy before employment terms' using errcode='23514';end if;
  if coalesce(input->>'basic_minor','')!~'^[0-9]+$' or jsonb_typeof(input->'allowances')<>'array' then raise exception 'Exact salary and allowance components required' using errcode='22023';end if;
  if exists(select 1 from jsonb_array_elements(input->'allowances') x where upper(btrim(x->>'name'))='BASIC') or (select count(*) from jsonb_array_elements(input->'allowances'))<>(select count(distinct lower(btrim(x->>'name'))) from jsonb_array_elements(input->'allowances') x) then raise exception 'Unique allowance names; BASIC is reserved' using errcode='23514';end if;
  total:=(input->>'basic_minor')::bigint;
  for item in select jsonb_array_elements(input->'allowances') loop
   if coalesce(length(btrim(item->>'name')),0) not between 1 and 100 or coalesce(item->>'amount_minor','')!~'^[0-9]+$' then raise exception 'Named exact allowance required' using errcode='23514';end if;
   total:=total+(item->>'amount_minor')::bigint;
  end loop;
  if total not between 1 and 9000000000000000 then raise exception 'Salary outside range' using errcode='23514';end if;
  select array_agg(x::integer) into week from jsonb_array_elements_text(input->'weekdays') x;
  if cardinality(week)<> (select count(distinct x) from unnest(week) x) or exists(select 1 from unnest(week) x where x not between 1 and 7) then raise exception 'Unique ISO weekdays required' using errcode='23514';end if;
  pid:=nullif(input->>'project_id','')::uuid;if pid is not null and not exists(select 1 from public.projects where company_id=cid and id=pid and status<>'CLOSED') then raise exception 'Eligible Company Project required' using errcode='23503';end if;
  insert into public.hr_term_events(company_id,employee_id,version,effective_on,employed_from,employed_until,basic_minor,allowances,weekdays,start_minute,end_minute,break_minutes,project_id,status,evidence,created_by)
  values(cid,emp,v+1,d,(input->>'employed_from')::date,nullif(input->>'employed_until','')::date,(input->>'basic_minor')::bigint,input->'allowances',week,(input->>'start_minute')::integer,(input->>'end_minute')::integer,(input->>'break_minutes')::integer,pid,input->>'status',input->>'evidence',actor) returning id into rid;
 elsif action='CALENDAR' then
  d:=(input->>'day')::date;perform private.hr_open_terms(cid,d);
  select coalesce(max(version),0) into prior from public.hr_calendar_events where company_id=cid and day=d;if prior<>v then raise exception 'Calendar changed' using errcode='40001';end if;
  if (input->>'kind' in ('REST','HOLIDAY') and (input->>'expected_minutes')::integer<>0) or (input->>'kind'='WORK' and (input->>'expected_minutes')::integer<=0) then raise exception 'Calendar kind and expected minutes disagree' using errcode='23514';end if;
  insert into public.hr_calendar_events(company_id,day,version,expected_minutes,kind,evidence,created_by) values(cid,d,v+1,(input->>'expected_minutes')::integer,input->>'kind',input->>'evidence',actor) returning id into rid;
 elsif action='ATTENDANCE' then
  emp:=(input->>'employee_id')::uuid;d:=(input->>'day')::date;m:=date_trunc('month',d)::date;
  if d is null or d>(clock_timestamp() at time zone 'Asia/Dubai')::date or private.hr_policy(cid,m) is null then raise exception 'Eligible nonfuture explicit attendance date required' using errcode='23514';end if;
  if not public.has_permission(cid,'attendance.record') then raise exception 'Attendance record permission required' using errcode='42501';end if;
  t:=private.hr_term(cid,emp,d);if t.id is null or t.status<>'ACTIVE' or d<t.employed_from or d>coalesce(t.employed_until,'infinity'::date) then raise exception 'Effective active employment required' using errcode='23514';end if;
  select coalesce(max(version),0) into prior from public.hr_attendance_events where company_id=cid and employee_id=emp and day=d;if prior<>v then raise exception 'Attendance changed; reload' using errcode='40001';end if;
  ex:=private.hr_expected(cid,t,d);st:=nullif(input->>'start_minute','')::integer;en:=nullif(input->>'end_minute','')::integer;br:=coalesce((input->>'break_minutes')::integer,0);paid:=coalesce((input->>'paid_leave_minutes')::integer,0);attendance_status:=input->>'status';pid:=nullif(input->>'project_id','')::uuid;
  if (st is null)<>(en is null) or br<0 or (st is not null and (st not between 0 and 1439 or en<=st or en>st+1440 or br>=en-st)) then raise exception 'Valid worked interval / overnight end / breaks required' using errcode='23514';end if;
  worked:=case when st is null then 0 else en-st-br end;ot:=greatest(worked-ex,0);otpay:=coalesce((input->>'overtime_earned_minor')::bigint,0);
  if paid<0 or least(worked,ex)+paid>ex or (ot=0 and otpay<>0) or (ot>0 and coalesce(length(btrim(input->>'overtime_approval')),0)=0) then raise exception 'Leave overlap or unapproved overtime; documented earned amount required' using errcode='23514';end if;
  if (attendance_status='PRESENT' and (worked<ex or paid<>0 or (ex=0 and worked=0))) or (attendance_status in ('ABSENT','UNPAID_LEAVE') and (worked<>0 or paid<>0 or ex=0)) or (attendance_status='PAID_LEAVE' and (worked<>0 or paid<>ex or ex=0)) or (attendance_status in ('REST','HOLIDAY') and (ex<>0 or worked<>0 or paid<>0)) or (attendance_status='PARTIAL' and (ex=0 or least(worked,ex)+paid>=ex and worked=ex)) then raise exception 'Attendance status conflicts with recorded/expected/leave minutes' using errcode='23514';end if;
  if pid is not null and not exists(select 1 from public.projects where company_id=cid and id=pid and status<>'CLOSED') then raise exception 'Eligible Company site required' using errcode='23503';end if;
  if st is not null and exists(select 1 from (select distinct on(day) * from public.hr_attendance_events where company_id=cid and employee_id=emp and day between d-1 and d+1 and day<>d order by day,version desc) prior_day where prior_day.start_minute is not null and d+make_interval(mins=>st)<prior_day.day+make_interval(mins=>prior_day.end_minute) and prior_day.day+make_interval(mins=>prior_day.start_minute)<d+make_interval(mins=>en)) then raise exception 'Actual shifts overlap across attendance dates' using errcode='23514';end if;
  perform private.hr_touch(cid,m);
  insert into public.hr_attendance_events(company_id,employee_id,day,version,status,project_id,start_minute,end_minute,break_minutes,worked_minutes,paid_leave_minutes,overtime_minutes,overtime_earned_minor,expected_minutes,term_id,reason,created_by)
  values(cid,emp,d,v+1,attendance_status,pid,st,en,br,worked,paid,ot,otpay,ex,t.id,(input->>'evidence')||coalesce(' / '||(input->>'overtime_approval'),''),actor) returning id into rid;
 elsif action='REVIEW' then
  m:=(input->>'month')::date;if extract(day from m)<>1 or private.hr_policy(cid,m) is null then raise exception 'Explicit month required' using errcode='23514';end if;
  perform private.hr_touch(cid,m);
  if exists(select 1 from jsonb_array_elements(private.hr_days(cid,m)) x where x->>'status'='UNRECORDED' or (x->>'stale')::boolean) or jsonb_array_length(private.hr_days(cid,m))=0 then raise exception 'Resolve all unrecorded/stale employment days before review' using errcode='23514';end if;
  select revision into prior from public.attendance_periods where company_id=cid and month=m;
  if prior<>v+1 then raise exception 'Review revision changed' using errcode='40001';end if;
  update public.attendance_periods set reviewed_revision=revision,reviewed_by=actor,reviewed_at=clock_timestamp() where company_id=cid and month=m;
  rid:=request_id;
 elsif action='SETUP' then
  select coalesce(max(version),0) into prior from public.hr_payroll_setup_events where company_id=cid;if prior<>v then raise exception 'Setup changed' using errcode='40001';end if;
  for k in select unnest(array['SALARY_PAYABLE','PROJECT_COST','COMPANY_EXPENSE']) loop
   if input->>k='NEW' then
    if exists(select 1 from public.accounts where company_id=cid and system_key=k::public.system_account_key) then raise exception 'Reuse the existing keyed account' using errcode='23514';end if;
    insert into public.accounts(company_id,code,name,account_type,requires_party) values(cid,btrim(input->>(k||'_code')),btrim(input->>(k||'_name')),case when k='SALARY_PAYABLE' then 'LIABILITY'::public.account_type else 'EXPENSE'::public.account_type end,k='SALARY_PAYABLE') returning id into aid;
   else aid:=nullif(input->>k,'')::uuid;end if;
   select * into account from public.accounts where company_id=cid and id=aid and status='ACTIVE' for update;
   if not found or account.account_type::text<>(case when k='SALARY_PAYABLE' then 'LIABILITY' else 'EXPENSE' end) or (account.system_key is not null and account.system_key::text<>k) then raise exception 'Approved active Company account/type required for %',k using errcode='23514';end if;
   if exists(select 1 from public.accounts where company_id=cid and system_key=k::public.system_account_key and id<>aid) then raise exception 'Existing keyed account must be reused; no remapping' using errcode='23514';end if;
   -- Existing used accounts cannot be repurposed by setup.
   if account.system_key is null and exists(select 1 from public.journal_lines where company_id=cid and account_id=aid) then raise exception 'Used unkeyed account requires separately reviewed adoption; choose unused approved account' using errcode='23514';end if;
   update public.accounts set system_key=k::public.system_account_key where company_id=cid and id=aid and system_key is null;
  end loop;
  if input->>'advance_account_id'='NEW' then
   insert into public.accounts(company_id,code,name,account_type,requires_party) values(cid,btrim(input->>'advance_code'),btrim(input->>'advance_name'),'ASSET',true) returning id into aid;
  else aid:=nullif(input->>'advance_account_id','')::uuid;end if;
  if aid is not null and not exists(select 1 from public.accounts where company_id=cid and id=aid and status='ACTIVE' and account_type='ASSET' and requires_party and system_key is null and not exists(select 1 from public.treasury_accounts where company_id=cid and gl_account_id=aid)) then raise exception 'Dedicated employee receivable ASSET requiring Party required' using errcode='23514';end if;
  if aid is not null and exists(select 1 from public.journal_lines l join public.journal_entries j on j.company_id=l.company_id and j.id=l.journal_entry_id where l.company_id=cid and l.account_id=aid and j.source_type not in ('HR_EMPLOYEE_ADVANCE','HR_PAYROLL_RECOVERY') and not exists(select 1 from public.journal_entries original where original.id=j.reversal_of_journal_entry_id and original.company_id=cid and original.source_type in ('HR_EMPLOYEE_ADVANCE','HR_PAYROLL_RECOVERY'))) then raise exception 'Used non-HR account cannot become the dedicated employee receivable' using errcode='23514';end if;
  insert into public.hr_payroll_setup_events(company_id,version,advance_account_id,evidence,created_by) values(cid,v+1,aid,input->>'evidence',actor) returning id into rid;
 elsif action='ADVANCE' then
  emp:=(input->>'employee_id')::uuid;d:=(input->>'date')::date;amount:=(input->>'amount_minor')::bigint;limit_amount:=(input->>'monthly_limit_minor')::bigint;aid:=(input->>'treasury_id')::uuid;perform private.opening_period(cid,d);
  if not exists(select 1 from public.parties where company_id=cid and id=emp and status='ACTIVE' and private.party_has_person_role(cid,id,'EMPLOYEE')) then raise exception 'Active Company employee required' using errcode='23503';end if;
  select * into setup from public.hr_payroll_setup_events where company_id=cid order by version desc limit 1;
  if setup.advance_account_id is null then raise exception 'Approve employee advance mapping before funding' using errcode='23514';end if;
  select * into account from public.accounts where company_id=cid and id=setup.advance_account_id and status='ACTIVE' for share;if not found then raise exception 'Advance account inactive' using errcode='23514';end if;
  if amount not between 1 and 9000000000000000 or limit_amount not between 1 and amount then raise exception 'Approved amount and recovery limit required' using errcode='23514';end if;
  holder:=nullif(input->>'custodian_id','')::uuid;
  funding:=private.settlement_funding(cid,aid,holder,d,amount,null);pid:=(funding->>'account_id')::uuid;
  rid:=gen_random_uuid();j:=private.create_journal(cid,d,'Approved employee advance','HR_EMPLOYEE_ADVANCE',rid,'POST',jsonb_build_array(jsonb_build_object('account_id',account.id,'party_id',emp,'debit_minor',amount::text,'credit_minor','0'),funding),actor);
  insert into public.hr_advance_postings(id,company_id,employee_id,account_id,treasury_id,custodian_id,custody_account_id,amount_minor,monthly_limit_minor,posting_date,evidence,journal_id,created_by) values(rid,cid,emp,account.id,aid,holder,case when holder is not null then pid end,amount,limit_amount,d,input->>'evidence',j,actor);
 elsif action='REVERSE_ADVANCE' then
  select * into loan from public.hr_advance_postings where company_id=cid and id=(input->>'advance_id')::uuid for update;
  if not found or exists(select 1 from public.hr_financial_reversals where company_id=cid and kind='ADVANCE' and source_id=loan.id) then raise exception 'Live Company advance required' using errcode='23514';end if;
  if exists(select 1 from public.hr_recovery_postings x where company_id=cid and advance_id=loan.id and not exists(select 1 from public.hr_financial_reversals y where y.company_id=cid and y.kind='RECOVERY' and y.source_id=x.id)) then raise exception 'Reverse dependent payroll recovery first' using errcode='23514';end if;
  d:=(input->>'date')::date;perform private.opening_period(cid,d);if d<loan.posting_date then raise exception 'Reversal before advance denied' using errcode='23514';end if;
  j:=private.reverse_journal(loan.journal_id,d,input->>'evidence',actor);insert into public.hr_financial_reversals(company_id,source_id,kind,journal_id,reason,created_by) values(cid,loan.id,'ADVANCE',j,input->>'evidence',actor) returning id into rid;
 elsif action='RECOVERY' then
  m:=(input->>'month')::date;if m is null or extract(day from m)<>1 or private.hr_policy(cid,m) is null then raise exception 'Explicit payroll month required' using errcode='23514';end if;perform private.hr_touch(cid,m);
  select * into loan from public.hr_advance_postings where company_id=cid and id=(input->>'advance_id')::uuid for update;
  if not found or m<date_trunc('month',loan.posting_date)::date or exists(select 1 from public.hr_financial_reversals where company_id=cid and source_id=loan.id and kind='ADVANCE') then raise exception 'Eligible advance required' using errcode='23514';end if;
  select coalesce(max(version),0) into prior from public.hr_recovery_plans where company_id=cid and month=m and advance_id=loan.id;if prior<>v then raise exception 'Recovery plan changed' using errcode='40001';end if;
  amount:=(input->>'amount_minor')::bigint;if amount<0 or amount>loan.monthly_limit_minor then raise exception 'Recovery exceeds explicitly approved monthly limit' using errcode='23514';end if;
  insert into public.hr_recovery_plans(company_id,month,advance_id,version,amount_minor,evidence,created_by) values(cid,m,loan.id,v+1,amount,input->>'evidence',actor) returning id into rid;
 end if;
 r:=jsonb_build_object('id',rid,'action',action);insert into private.hr_command_receipts values(cid,request_id,h,r);return r;
end;$$;
create or replace function private.source_settlement_document(cid uuid,kind text,doc uuid)returns jsonb language plpgsql stable security definer set search_path=''as $$
declare r jsonb;begin
 if kind='CONTRACT_PAYMENT'then
  select jsonb_build_object('id',id,'date',payment_date,'amount_minor',total_amount_minor::text,'contract_id',subcontract_id,'project_id',project_id,'treasury_id',treasury_account_id,'custodian_id',custodian_id,'custody_account_id',custody_account_id,'funding_mode',case when custodian_id is null then 'TREASURY'else 'CUSTODIAN'end,'journal',posted_journal_entry_id,'reversed',status='REVERSED','reference',payment_reference)into r from public.subcontractor_payments where company_id=cid and id=doc and status in('POSTED','REVERSED');
 elsif kind='CONTRACT_ADVANCE'then
  select jsonb_build_object('id',id,'date',advance_date,'amount_minor',amount_minor::text,'contract_id',subcontract_id,'project_id',project_id,'treasury_id',treasury_account_id,'custodian_id',custodian_id,'custody_account_id',custody_account_id,'funding_mode',case when custodian_id is null then 'TREASURY'else 'CUSTODIAN'end,'journal',posted_journal_entry_id,'reversed',status='REVERSED','reference',advance_reference)into r from public.subcontractor_advances where company_id=cid and id=doc and status in('POSTED','REVERSED');
 elsif kind='EMPLOYEE_ADVANCE'then
  select jsonb_build_object('id',a.id,'date',a.posting_date,'amount_minor',a.amount_minor::text,'employee_id',a.employee_id,'treasury_id',a.treasury_id,'custodian_id',a.custodian_id,'custody_account_id',a.custody_account_id,'funding_mode',case when a.custodian_id is null then 'TREASURY'else 'CUSTODIAN'end,'journal',a.journal_id,'reversed',exists(select 1 from public.hr_financial_reversals v where v.company_id=cid and v.kind='ADVANCE'and v.source_id=a.id),'reference',a.evidence)into r from public.hr_advance_postings a where a.company_id=cid and a.id=doc;
 end if;return r;end$$;
create or replace function public.command_source_settlement(cid uuid,source_id uuid,expected_version integer,request_id uuid,action text,input jsonb,confirmations jsonb,reason text)
returns jsonb language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_variable
declare actor uuid;s public.historical_source_records;p public.source_settlement_events;r public.source_settlement_events;replay public.source_settlement_events;
 v jsonb;h text;k text;kind text;nature text;d date;amount bigint;treasury public.treasury_accounts;contract public.subcontracts;emp uuid;doc uuid;j uuid;x record;matched jsonb;lim bigint;allocation jsonb;total numeric;balance numeric;funding_mode text;holder uuid;custody_gl uuid;
begin
 actor:=private.operational_finance_actor(cid,'accounting.post');
 -- Same order as HR/payroll: attendance first, then financial serialization/source row.
 perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 if request_id is null or expected_version is null or expected_version<0 or action is null or action not in('SAVE','REVIEW','APPROVE','POST','CANCEL')or input is null or jsonb_typeof(input)<>'object'or confirmations is null or jsonb_typeof(confirmations)<>'object'or octet_length(input::text)>24000 or octet_length(confirmations::text)>6000 or coalesce(length(private.correction_text(reason)),0)not between 1 and 1000 then raise exception 'Source command, version and reason required'using errcode='22023';end if;
 -- Trim text before hashing; numeric inputs use exact minor-unit strings; JSONB normalizes object order.
 for k in select jsonb_object_keys(input)loop
  if k<>all(array['kind','date','amount_minor','contract_id','employee_id','project_id','treasury_id','certificate_id','monthly_limit_minor','existing_document_id','evidence','funding_mode','custodian_id','custody_account_id'])or jsonb_typeof(input->k)not in('string','null')or length(input->>k)>1000 then raise exception 'Unsupported settlement input'using errcode='22023';end if;
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
  funding_mode:=coalesce(v->>'funding_mode','TREASURY');holder:=nullif(v->>'custodian_id','')::uuid;
  if funding_mode='CUSTODIAN'then
   if holder is null or nullif(v->>'treasury_id','')is not null or s.completion->>'funding_contradiction'='true'then raise exception 'Confirm actual Custody payer without mixed or contradictory funding'using errcode='23514';end if;
   select id into custody_gl from public.accounts where company_id=cid and system_key='CUSTODY_ADVANCE'and status='ACTIVE'and account_type='ASSET'and requires_party;
   if custody_gl is null or custody_gl is distinct from nullif(v->>'custody_account_id','')::uuid or not exists(select 1 from public.parties where company_id=cid and id=holder and status='ACTIVE'and private.party_has_person_role(cid,id,'CUSTODIAN'))then raise exception 'Select active same-Company Custody holder and mapped control account'using errcode='23514';end if;
  elsif funding_mode='TREASURY'then
   if holder is not null or nullif(v->>'custody_account_id','')is not null then raise exception 'Treasury funding cannot contain Custody inputs'using errcode='23514';end if;
   select * into treasury from public.treasury_accounts where company_id=cid and id=(v->>'treasury_id')::uuid;
   if treasury.id is null or(s.cash_treasury_id is not null and s.cash_treasury_id<>treasury.id)then raise exception 'Match actual same-Company source Treasury'using errcode='23514';end if;
  else raise exception 'Supported Treasury or Custody funding required'using errcode='23514';end if;
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
   exists(select 1 from public.subcontractor_payments a where kind='CONTRACT_PAYMENT'and a.company_id=cid and a.subcontract_id=contract.id and ((funding_mode='TREASURY'and a.treasury_account_id=treasury.id)or(funding_mode='CUSTODIAN'and a.custodian_id=holder)) and a.payment_date=d and a.total_amount_minor=amount and a.status='POSTED')or
   exists(select 1 from public.subcontractor_advances a where kind='CONTRACT_ADVANCE'and a.company_id=cid and a.subcontract_id=contract.id and ((funding_mode='TREASURY'and a.treasury_account_id=treasury.id)or(funding_mode='CUSTODIAN'and a.custodian_id=holder)) and a.advance_date=d and a.amount_minor=amount and a.status='POSTED')or
   exists(select 1 from public.hr_advance_postings a where kind='EMPLOYEE_ADVANCE'and a.company_id=cid and a.employee_id=emp and ((funding_mode='TREASURY'and a.treasury_id=treasury.id)or(funding_mode='CUSTODIAN'and a.custodian_id=holder)) and a.posting_date=d and a.amount_minor=amount and not exists(select 1 from public.hr_financial_reversals rv where rv.company_id=cid and rv.kind='ADVANCE'and rv.source_id=a.id))
  )then raise exception 'Potential existing payment: link it or document distinct-payment evidence'using errcode='23514';end if;
  if doc is not null then
   matched:=private.source_settlement_document(cid,kind,doc);
   if matched is null or(matched->>'reversed')::boolean or matched->>'date'<>d::text or matched->>'amount_minor'<>amount::text or coalesce(matched->>'funding_mode','TREASURY')<>funding_mode or(funding_mode='TREASURY'and matched->>'treasury_id' is distinct from treasury.id::text)or(funding_mode='CUSTODIAN'and(matched->>'custodian_id'is distinct from holder::text or matched->>'custody_account_id'is distinct from custody_gl::text)) or (kind like 'CONTRACT_%'and matched->>'contract_id'<>contract.id::text)or(kind='EMPLOYEE_ADVANCE'and matched->>'employee_id'<>emp::text)then raise exception 'Existing document must match exact live source event and dimensions'using errcode='23514';end if;
   if kind='CONTRACT_PAYMENT'and not exists(select 1 from public.subcontractor_payment_allocations a where a.company_id=cid and a.subcontractor_payment_id=doc and a.subcontractor_certificate_id=(v->>'certificate_id')::uuid and a.allocated_amount_minor=amount)then raise exception 'Existing payment certificate allocation differs'using errcode='23514';end if;
   if exists(select 1 from public.source_settlement_events e where e.company_id=cid and e.kind=kind and e.document_id=doc and e.state='POSTED')then raise exception 'Document already linked to a source'using errcode='23505';end if;
  end if;
 end if;
 if action='APPROVE'and p.state<>'REVIEWED'then raise exception 'Review before approval'using errcode='23514';end if;
 if action='POST'then
  if p.state<>'APPROVED'then raise exception 'Approve before posting'using errcode='23514';end if;
  if doc is null then
   -- Source posting cannot create cash beyond evidenced funds; canonical commands retain their own guards.
   if funding_mode='TREASURY'then
   perform 1 from public.treasury_accounts where company_id=cid and id=treasury.id for update;
   select coalesce(sum(l.debit_minor::numeric-l.credit_minor::numeric),0)into balance from public.journal_lines l join public.journal_entries je on je.company_id=l.company_id and je.id=l.journal_entry_id where l.company_id=cid and l.account_id=treasury.gl_account_id and je.posting_date<=d;
   if treasury.status<>'ACTIVE'or balance<amount then raise exception 'Insufficient evidenced Treasury funds; no invented funding'using errcode='23514';end if;
   end if;
   if kind='CONTRACT_PAYMENT'then
    select * into x from public.post_subcontractor_payment(cid,d,contract.id,treasury.id,amount,case when treasury.type in('BANK','PROJECT_BANK')then 'BANK'::public.payment_method else 'CASH'::public.payment_method end,'HISTORICAL:'||source_id::text,v->>'evidence',jsonb_build_array(jsonb_build_object('certificate_id',v->>'certificate_id','amount_minor',amount::text)),request_id,holder);doc:=x.subcontractor_payment_id;j:=x.journal_entry_id;
   elsif kind='CONTRACT_ADVANCE'then
    select * into x from public.post_subcontractor_advance(cid,d,contract.id,treasury.id,amount,case when treasury.type in('BANK','PROJECT_BANK')then 'BANK'::public.payment_method else 'CASH'::public.payment_method end,'HISTORICAL:'||source_id::text,v->>'evidence',request_id,holder);doc:=x.subcontractor_advance_id;j:=x.journal_entry_id;
   else
    matched:=public.command_hr(cid,request_id,'ADVANCE',jsonb_build_object('employee_id',emp,'treasury_id',treasury.id,'custodian_id',holder,'date',d,'amount_minor',amount::text,'monthly_limit_minor',lim::text,'evidence',left('HISTORICAL:'||source_id::text||' '||(v->>'evidence'),1000)));doc:=(matched->>'id')::uuid;
    select journal_id into j from public.hr_advance_postings where company_id=cid and id=doc;
   end if;
  else j:=(matched->>'journal')::uuid;end if;
 end if;
 insert into public.source_settlement_events(company_id,source_id,version,request_id,request_hash,kind,state,snapshot,confirmations,source_updated_at,document_id,journal_id,reason,created_by)
 values(cid,s.id,expected_version+1,request_id,h,kind,case action when 'SAVE'then 'DRAFT'when 'REVIEW'then 'REVIEWED'when 'APPROVE'then 'APPROVED'when 'POST'then 'POSTED'else 'CANCELLED'end,v,confirmations,s.updated_at,case when action='POST'then doc end,case when action='POST'then j end,private.correction_text(reason),actor)returning *into r;
 return to_jsonb(r);
end$$;

-- Keep HR journal RLS unchanged. An incomplete filtered Custody balance must not
-- masquerade as complete when confidential employee advances are hidden.
create function public.custody_reporting_complete(cid uuid,holder uuid)returns boolean
language plpgsql stable security definer set search_path=''as $$begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'MANAGEMENT_VIEWER'))or not exists(select 1 from public.parties where company_id=cid and id=holder)then raise exception 'Company Custody reporting access required'using errcode='42501';end if;
 return public.has_permission(cid,'payroll.manage')or not exists(select 1 from public.hr_advance_postings where company_id=cid and custodian_id=holder);
end$$;
revoke all on function public.custody_reporting_complete(uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.custody_reporting_complete(uuid,uuid)to authenticated;

-- Keep existing dependency-specific reversal; add period control for the new Custody route.
alter function public.reverse_subcontractor_advance(uuid,uuid,date,text,uuid)set schema private;
alter function private.reverse_subcontractor_advance(uuid,uuid,date,text,uuid)rename to reverse_subcontractor_advance_v90;
revoke all on function private.reverse_subcontractor_advance_v90(uuid,uuid,date,text,uuid)from public,anon,authenticated,service_role;
create function public.reverse_subcontractor_advance(target_company_id uuid,target_subcontractor_advance_id uuid,target_reversal_date date,target_reason text,target_idempotency_key uuid)
returns table(subcontractor_advance_id uuid,advance_reference text,reversal_journal_entry_id uuid,replayed boolean)language plpgsql security definer set search_path=''as $$begin
 perform private.operational_finance_actor(target_company_id,'accounting.reverse');perform private.serialize_operational_finance(target_company_id,'OPERATIONS');
 if exists(select 1 from public.subcontractor_advances where company_id=target_company_id and id=target_subcontractor_advance_id and custodian_id is not null and status='POSTED')then perform private.opening_period(target_company_id,target_reversal_date);end if;
 return query select *from private.reverse_subcontractor_advance_v90(target_company_id,target_subcontractor_advance_id,target_reversal_date,target_reason,target_idempotency_key);
end$$;
revoke all on function public.reverse_subcontractor_advance(uuid,uuid,date,text,uuid)from public,anon,authenticated,service_role;
grant execute on function public.reverse_subcontractor_advance(uuid,uuid,date,text,uuid)to authenticated;

-- Keep existing dependency-specific reversal; add period control for the new Custody route.
alter function public.reverse_subcontractor_payment(uuid,uuid,date,text,uuid)set schema private;
alter function private.reverse_subcontractor_payment(uuid,uuid,date,text,uuid)rename to reverse_subcontractor_payment_v90;
revoke all on function private.reverse_subcontractor_payment_v90(uuid,uuid,date,text,uuid)from public,anon,authenticated,service_role;
create function public.reverse_subcontractor_payment(target_company_id uuid,target_subcontractor_payment_id uuid,target_reversal_date date,target_reason text,target_idempotency_key uuid)
returns table(subcontractor_payment_id uuid,payment_reference text,reversal_journal_entry_id uuid,replayed boolean)language plpgsql security definer set search_path=''as $$begin
 perform private.operational_finance_actor(target_company_id,'accounting.reverse');perform private.serialize_operational_finance(target_company_id,'OPERATIONS');
 if exists(select 1 from public.subcontractor_payments where company_id=target_company_id and id=target_subcontractor_payment_id and custodian_id is not null and status='POSTED')then perform private.opening_period(target_company_id,target_reversal_date);end if;
 return query select *from private.reverse_subcontractor_payment_v90(target_company_id,target_subcontractor_payment_id,target_reversal_date,target_reason,target_idempotency_key);
end$$;
revoke all on function public.reverse_subcontractor_payment(uuid,uuid,date,text,uuid)from public,anon,authenticated,service_role;
grant execute on function public.reverse_subcontractor_payment(uuid,uuid,date,text,uuid)to authenticated;
create index subcontractor_advances_custody_lookup on public.subcontractor_advances(company_id,custodian_id)where custodian_id is not null;
create index subcontractor_payments_custody_lookup on public.subcontractor_payments(company_id,custodian_id)where custodian_id is not null;
create index hr_advance_postings_custody_lookup on public.hr_advance_postings(company_id,custodian_id)where custodian_id is not null;
notify pgrst,'reload schema';

-- Existing source/unbound Expense drafts use the same dated Custody balance
-- guard as settlements. This is validation only; existing post_expense posts.
alter function private.validate_expense_draft(uuid,jsonb)rename to validate_expense_draft_v90;
revoke all on function private.validate_expense_draft_v90(uuid,jsonb)from public,anon,authenticated,service_role;
create function private.validate_expense_draft(cid uuid,v jsonb)returns jsonb
language plpgsql volatile security definer set search_path=''as $$declare result jsonb;begin
 result:=private.validate_expense_draft_v90(cid,v);
 if v->>'funding_mode'='CUSTODIAN'then perform private.settlement_funding(cid,null,nullif(v->>'paid_by_id','')::uuid,(v->>'date')::date,(result->>'gross_minor')::bigint,nullif(v->>'project_id','')::uuid);end if;
 return result;
end$$;
revoke all on function private.validate_expense_draft(uuid,jsonb)from public,anon,authenticated,service_role;

-- Corrections must retain the real funding route; existing correction scope and approval remain unchanged.
create or replace function private.reclassification_document(cid uuid,kind text,doc uuid)returns jsonb language plpgsql stable security definer set search_path=''as $$
declare r jsonb;begin
 if kind='EXPENSE'then
  select jsonb_build_object('kind',kind,'id',id,'journal',posted_journal_entry_id,'date',expense_date,'amount_minor',gross_amount_minor::text,'reference',expense_reference,'status',status,'funding_mode',funding_mode,'treasury_id',treasury_account_id,'custodian_id',paid_by_party_id,'project_id',project_id,'vat_minor',vat_amount_minor::text,'supplier_id',supplier_id,'allocation_plan',allocation_plan)into r from public.expenses where company_id=cid and id=doc;
 elsif kind in('CONTRACT_PAYMENT','CONTRACT_ADVANCE','EMPLOYEE_ADVANCE')then
  r:=private.source_settlement_document(cid,kind,doc);if r is not null then r:=r||jsonb_build_object('kind',kind,'funding_mode',coalesce(r->>'funding_mode','TREASURY'),'status',case when(r->>'reversed')::boolean then 'REVERSED'else 'POSTED'end);end if;
 elsif kind='CUSTODY_ADVANCE'then
  select jsonb_build_object('kind',kind,'id',id,'journal',posted_journal_entry_id,'date',advance_date,'amount_minor',amount_minor::text,'reference',advance_reference,'status',status,'funding_mode','TREASURY','treasury_id',treasury_account_id,'custodian_id',custodian_id,'project_id',project_id)into r from public.custody_advances where company_id=cid and id=doc;
 elsif kind='SUPPLIER_PAYMENT'then
  select jsonb_build_object('kind',kind,'id',id,'journal',posted_journal_entry_id,'date',payment_date,'amount_minor',total_amount_minor::text,'reference',payment_reference,'status',status,'funding_mode','TREASURY','treasury_id',treasury_account_id,'supplier_id',supplier_id)into r from public.supplier_payments where company_id=cid and id=doc;
 end if;return r;end$$;
