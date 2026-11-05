-- Additive opt-in setup for existing Companies. No backfill, balance or journal.
create table public.company_accounting_setup_events (
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),
 request_id uuid not null,request_hash text not null,action text not null check(action in ('CONTROL','TREASURY')),
 account_id uuid not null,treasury_id uuid,system_key public.system_account_key,
 approval_reference text not null check(length(approval_reference) between 1 and 1000),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 result jsonb not null,unique(company_id,request_id),
 foreign key(company_id,account_id) references public.accounts(company_id,id),
 foreign key(company_id,treasury_id) references public.treasury_accounts(company_id,id)
);
alter table public.company_accounting_setup_events enable row level security;
alter table public.company_accounting_setup_events force row level security;
revoke all on public.company_accounting_setup_events from public,anon,authenticated,service_role;
grant select on public.company_accounting_setup_events to authenticated;
create policy accounting_setup_read on public.company_accounting_setup_events for select to authenticated
 using(public.has_company_role(company_id,'ACCOUNTING_ADMIN') or public.has_company_role(company_id,'ACCOUNTANT') or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create trigger accounting_setup_immutable before update or delete on public.company_accounting_setup_events
 for each row execute function private.financial_evidence_immutable();

create function public.configure_company_accounting(target_company_id uuid,target_request_id uuid,target_action text,business_input jsonb)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare actor uuid;v jsonb:='{}';k text;value jsonb;h text;prior public.company_accounting_setup_events;
 a public.accounts;key_name public.system_account_key;kind public.account_type;party_required boolean;
 aid uuid;tid uuid;eid uuid:=gen_random_uuid();result jsonb;approval text;mode_new boolean;
begin
 actor:=private.operational_finance_actor(target_company_id,'account.manage');
 if not public.has_company_role(target_company_id,'ACCOUNTING_ADMIN') then raise exception 'Accounting Admin approval required' using errcode='42501';end if;
 if target_action='TREASURY' and not public.has_permission(target_company_id,'treasury.manage') then raise exception 'Treasury management denied' using errcode='42501';end if;
 if target_request_id is null or target_action is null or target_action not in ('CONTROL','TREASURY') or jsonb_typeof(business_input) is distinct from 'object' or octet_length(business_input::text)>8000 then raise exception 'Invalid setup request' using errcode='22023';end if;
 for k,value in select * from jsonb_each(business_input) loop
  if k<>all(case target_action when 'CONTROL' then array['key','account_id','code','name','approval'] else array['gl_account_id','gl_code','gl_name','code','name','type','bank_name','account_reference','project_id','approval'] end)
   or jsonb_typeof(value) not in ('string','null') then raise exception 'Unsupported setup field' using errcode='22023';end if;
  if value<>'null'::jsonb and nullif(btrim(value#>>'{}'),'') is not null then v:=v||jsonb_build_object(k,btrim(value#>>'{}'));end if;
 end loop;
 foreach k in array array['code','gl_code'] loop
  if v ? k then v:=jsonb_set(v,array[k],to_jsonb(upper(v->>k)));end if;
 end loop;
 approval:=v->>'approval';
 if coalesce(length(approval),0) not between 1 and 1000 then raise exception 'Approved setup evidence required' using errcode='23514';end if;
 h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'action',target_action,'input',v)::text,'UTF8'),'sha256'),'hex');
 perform private.serialize_operational_finance(target_company_id,'OPERATIONS');
 select * into prior from public.company_accounting_setup_events where company_id=target_company_id and request_id=target_request_id;
 if found then
  if prior.request_hash<>h then raise exception 'Setup request intent changed' using errcode='22023';end if;
  return prior.result;
 end if;
 if target_action='CONTROL' then
  -- Stable keys/types reuse the existing contracting foundation, never OWNER_CURRENT policy.
  select t.account_type::public.account_type,t.requires_party into kind,party_required from (values
   ('INPUT_VAT','ASSET',false),('CUSTODY_ADVANCE','ASSET',true),('SUBCONTRACTOR_ADVANCE','ASSET',true),
   ('SUPPLIER_PAYABLE','LIABILITY',true),('SUBCONTRACTOR_PAYABLE','LIABILITY',true),('SUBCONTRACTOR_RETENTION_PAYABLE','LIABILITY',true),
   ('SALARY_PAYABLE','LIABILITY',true),('PROJECT_COST','EXPENSE',false),('PROJECT_COST_SUBCONTRACTORS','EXPENSE',false),('COMPANY_EXPENSE','EXPENSE',false)
  ) t(key,account_type,requires_party) where t.key=v->>'key';
  if not found then raise exception 'Unsupported control key; use classified partner or payroll configuration where appropriate' using errcode='22023';end if;
  key_name:=(v->>'key')::public.system_account_key;
  select * into a from public.accounts where company_id=target_company_id and system_key=key_name for update;
  if found then
   -- Never silently repair/adopt a conflicting keyed mapping, even if unused.
   if a.status<>'ACTIVE' or a.account_type<>kind or a.requires_party<>party_required then raise exception 'Existing mapping is invalid; controlled review required' using errcode='23514';end if;
   if v->>'account_id' is distinct from a.id::text or v ? 'code' or v ? 'name' then raise exception 'Existing keyed account must be reused; no replacement' using errcode='23514';end if;
   aid:=a.id;
  elsif v ? 'account_id' then
   if v ? 'code' or v ? 'name' then raise exception 'Select existing account or new details' using errcode='22023';end if;
   aid:=(v->>'account_id')::uuid;
   select * into a from public.accounts where company_id=target_company_id and id=aid for update;
   if not found or a.status<>'ACTIVE' or a.account_type<>kind or a.requires_party<>party_required or a.system_key is not null then raise exception 'Approved same-company active account/type/Party relationship required' using errcode='23514';end if;
   if exists(select 1 from public.journal_lines where company_id=target_company_id and account_id=aid)
    or exists(select 1 from public.treasury_accounts where company_id=target_company_id and gl_account_id=aid)
    or exists(select 1 from public.operational_liability_configuration where company_id=target_company_id and account_id=aid)
    or exists(select 1 from public.hr_payroll_setup_events where company_id=target_company_id and advance_account_id=aid)
    or exists(select 1 from public.accounts where company_id=target_company_id and parent_account_id=aid) then
    raise exception 'Used or reserved account cannot be repurposed' using errcode='23514';end if;
   update public.accounts set system_key=key_name,updated_by=actor where id=aid and company_id=target_company_id;
  else
   if coalesce(length(v->>'code'),0) not between 1 and 50 or coalesce(length(v->>'name'),0) not between 1 and 200 then raise exception 'Explicit account code/name required' using errcode='23514';end if;
   if exists(select 1 from public.accounts where company_id=target_company_id and upper(btrim(code))=v->>'code') then raise exception 'Account code already exists' using errcode='23505';end if;
   insert into public.accounts(company_id,code,name,account_type,requires_party,system_key,created_by,updated_by)
    values(target_company_id,v->>'code',v->>'name',kind,party_required,key_name,actor,actor) returning id into aid;
  end if;
 else
  if v->>'type' is null or v->>'type' not in ('CASH','BANK') then raise exception 'Actual Cash or Bank location required' using errcode='23514';end if;
  if v->>'type'='BANK' and (v->>'bank_name' is null or v->>'account_reference' is null) then raise exception 'Bank name and identifiable bank account reference required' using errcode='23514';end if;
  if v->>'type'='CASH' and (v ? 'bank_name' or v ? 'account_reference') then raise exception 'Cash location cannot carry bank details' using errcode='23514';end if;
  if v->>'type'='BANK' and exists(select 1 from public.treasury_accounts where company_id=target_company_id and type in ('BANK','PROJECT_BANK') and lower(btrim(bank_name))=lower(v->>'bank_name') and lower(btrim(account_reference))=lower(v->>'account_reference')) then raise exception 'Bank account already has a Treasury; review existing location' using errcode='23505';end if;
  mode_new:=not(v ? 'gl_account_id');
  if mode_new then
   if coalesce(length(v->>'gl_code'),0) not between 1 and 50 or coalesce(length(v->>'gl_name'),0) not between 1 and 200 then raise exception 'Explicit Treasury GL code/name required' using errcode='23514';end if;
   if exists(select 1 from public.accounts where company_id=target_company_id and upper(btrim(code))=v->>'gl_code') then raise exception 'Account code already exists' using errcode='23505';end if;
   insert into public.accounts(company_id,code,name,account_type,requires_party,created_by,updated_by)
    values(target_company_id,v->>'gl_code',v->>'gl_name','ASSET',false,actor,actor) returning id into aid;
  else
   if v ? 'gl_code' or v ? 'gl_name' then raise exception 'Select existing GL or new details' using errcode='22023';end if;
   aid:=(v->>'gl_account_id')::uuid;
   -- The existing Treasury command performs authoritative type/Company/Party/key validation and locking.
   if exists(select 1 from public.journal_lines where company_id=target_company_id and account_id=aid)
    or exists(select 1 from public.accounts where company_id=target_company_id and parent_account_id=aid) then raise exception 'Used or parent GL cannot become a new money location' using errcode='23514';end if;
  end if;
  tid:=public.create_treasury_master(target_company_id,(v-array['gl_account_id','gl_code','gl_name','approval'])||jsonb_build_object('gl_account_id',aid));
 end if;
 result:=jsonb_build_object('id',eid,'account_id',aid,'treasury_id',tid,'configured',true);
 insert into public.company_accounting_setup_events(id,company_id,request_id,request_hash,action,account_id,treasury_id,system_key,approval_reference,created_by,result)
  values(eid,target_company_id,target_request_id,h,target_action,aid,tid,key_name,approval,actor,result);
 return result;
end;$$;
revoke all on function public.configure_company_accounting(uuid,uuid,text,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.configure_company_accounting(uuid,uuid,text,jsonb) to authenticated;
