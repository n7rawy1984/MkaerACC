-- Commercial onboarding; local preparation only. Shared hosted DB requires separate approval.
-- Eligibility is data, not a tenant branch in financial code. One-time approved existing
-- Maker exemption; no automatic grandfathering of other or future Companies.
create table private.company_legacy_eligibility (
 company_id uuid primary key references public.companies(id) on delete restrict,
 reason text not null check(length(reason) between 1 and 500),
 recorded_at timestamptz not null default clock_timestamp()
);
alter table private.company_legacy_eligibility enable row level security;
alter table private.company_legacy_eligibility force row level security;
revoke all on private.company_legacy_eligibility from public,anon,authenticated,service_role;
insert into private.company_legacy_eligibility(company_id,reason)
 select c.id,'Explicitly approved existing internal legacy Company; commercial enrollment optional'
 from public.companies c where c.code='MAKER'
 and not exists(select 1 from private.platform_events e where e.target_id=c.id and e.action='create_entity');

-- Internal, transaction-only initialization scope. No browser table/function grant and
-- no caller-settable GUC. Only the existing protected provisioner writes this scope.
create table private.company_initialization_scope (
 company_id uuid primary key references public.companies(id) on delete restrict,
 transaction_id bigint not null, actor_id uuid not null
);
alter table private.company_initialization_scope enable row level security;
alter table private.company_initialization_scope force row level security;
revoke all on private.company_initialization_scope from public,anon,authenticated,service_role;

create function private.company_commercial_readiness(cid uuid) returns jsonb
language plpgsql volatile security definer set search_path='' as $$
declare c public.companies; e private.platform_entities; s private.company_subscriptions;
 legacy boolean; customer_ok boolean; admin_ok boolean; foundation_ok boolean; active_ok boolean; subscription_ok boolean; effective text;
begin
 select * into c from public.companies where id=cid;
 if c.id is null then raise exception 'Company unavailable' using errcode='22023';end if;
 select * into e from private.platform_entities where company_id=cid;
 select * into s from private.company_subscriptions where company_id=cid;
 select exists(select 1 from private.company_legacy_eligibility where company_id=cid) into legacy;
 customer_ok:=e.customer_id is not null and exists(select 1 from private.platform_customers where id=e.customer_id);
 active_ok:=c.status='ACTIVE' and (e.lifecycle='ACTIVE' or (legacy and e.company_id is null));
 select exists(select 1 from public.company_memberships m join public.profiles p on p.user_id=m.user_id
  where m.company_id=cid and m.role='ACCOUNTING_ADMIN' and m.status='ACTIVE' and p.status='ACTIVE') into admin_ok;
 foundation_ok:=coalesce(e.accounting_setup='COMPLETE',false) and exists(select 1 from private.company_accounting_provisions where company_id=cid);
 effective:=private.subscription_effective_state(s,(statement_timestamp() at time zone 'Asia/Dubai')::date);
 subscription_ok:=effective in ('TRIAL','ACTIVE');
 return jsonb_build_object('customer',customer_ok,'active',coalesce(active_ok,false),'administrator',admin_ok,'foundation',foundation_ok,
  'subscription',subscription_ok,'subscription_state',effective,'legacy_eligible',legacy,
  -- Enrollment is authoritative even for eligible legacy Companies: expiry still limits business.
  'legacy_access',legacy and s.company_id is null,
  'ready',coalesce(active_ok,false) and ((legacy and (s.company_id is null or subscription_ok)) or (customer_ok and admin_ok and foundation_ok and subscription_ok)));
end $$;
revoke all on function private.company_commercial_readiness(uuid) from public,anon,authenticated,service_role;

create or replace function private.guard_subscription_new_business() returns trigger
language plpgsql security definer set search_path='' as $$
declare cid uuid; readiness jsonb;
begin
 if tg_op='DELETE' then cid:=old.company_id;else cid:=new.company_id;end if;
 perform 1 from public.companies where id=cid for share;
 perform 1 from private.platform_entities where company_id=cid for share;
 perform 1 from private.company_subscriptions where company_id=cid for share;
 if tg_op='INSERT' and tg_table_schema='public' and tg_table_name in ('accounts','treasury_accounts')
  and exists(select 1 from private.company_initialization_scope x where x.company_id=cid
   and x.transaction_id=txid_current() and x.actor_id=auth.uid()) then return new;end if;
 readiness:=private.company_commercial_readiness(cid);
 if not (readiness->>'ready')::boolean then
  raise exception 'COMMERCIAL_SETUP_REQUIRED: reads and permitted existing settlements/reversals remain available' using errcode='42501';
 end if;
 if tg_op='DELETE' then return old;end if;return new;
end $$;
revoke all on function private.guard_subscription_new_business() from public,anon,authenticated,service_role;

-- Activation remains a setup step; do not add a circular readiness prerequisite.
create or replace function public.provision_company_accounting(request_id uuid,business_input jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare
 actor uuid; p jsonb:='{}'; k text; v jsonb; cid uuid; expected integer;
 request_digest bytea; intent_digest bytea; prior private.platform_requests;
 entity private.platform_entities; provision private.company_accounting_provisions;
 result jsonb; account_ids uuid[]:='{}'; account_id uuid; treasury_id uuid; template record; owned_table record;
 has_rows boolean; expected_code text; reason text; treasury_name text; treasury_type text; bank_name text;
begin
 perform private.lock_platform_authorization();
 actor:=private.platform_actor(); -- genuine registered owner, live session and fresh MFA
 if request_id is null or jsonb_typeof(business_input) is distinct from 'object'
   or octet_length(business_input::text)>4000 then raise exception 'Invalid request' using errcode='22023'; end if;
 for k,v in select * from jsonb_each(business_input) loop
  if k<>all(array['id','version','code','treasury_name','treasury_type','bank_name','reason'])
    or jsonb_typeof(v) not in ('string','null') then raise exception 'Unsupported field' using errcode='22023'; end if;
  if v<>'null'::jsonb and nullif(btrim(v#>>'{}'),'') is not null then p:=p||jsonb_build_object(k,btrim(v#>>'{}')); end if;
 end loop;
 cid:=(p->>'id')::uuid; expected:=(p->>'version')::integer;
 if cid is null or expected is null or expected<1 then raise exception 'Company/version required' using errcode='22023'; end if;
 expected_code:=private.platform_text(p,'code',50);
 reason:=private.platform_text(p,'reason',500);
 treasury_name:=private.platform_text(p,'treasury_name',200);
 treasury_type:=private.platform_text(p,'treasury_type',20);
 bank_name:=private.platform_text(p,'bank_name',200,false);
 if treasury_type not in ('CASH','BANK') or (treasury_type='CASH' and bank_name is not null)
  or (treasury_type='BANK' and bank_name is null) then raise exception 'Verified Treasury type/name required' using errcode='22023'; end if;
 p:=p||jsonb_build_object('id',cid::text,'version',expected::text);
 request_digest:=sha256(convert_to('provision_accounting:'||p::text,'UTF8'));
 intent_digest:=sha256(convert_to('CONTRACTING_BASELINE_V1:'||(p-array['version','reason'])::text,'UTF8'));
 insert into private.platform_requests(actor_id,request_id,command_name,request_hash)
  values(actor,request_id,'provision_accounting',request_digest) on conflict do nothing;
 select * into prior from private.platform_requests r where r.actor_id=actor and r.request_id=provision_company_accounting.request_id for update;
 if prior.command_name<>'provision_accounting' or prior.request_hash<>request_digest then raise exception 'Idempotency mismatch' using errcode='22023'; end if;
 -- Always recheck Company lifecycle, even for receipt recovery after suspension.
 perform 1 from public.companies c where c.id=cid and c.code=expected_code and c.status='ACTIVE' for update;
 if not found then raise exception 'Expected ACTIVE Company required' using errcode='42501'; end if;
 select * into entity from private.platform_entities where company_id=cid for update;
 if not found or entity.lifecycle<>'ACTIVE' then raise exception 'Activated platform Company required' using errcode='42501'; end if;
 if not exists(select 1 from public.company_memberships m join public.profiles f on f.user_id=m.user_id
   where m.company_id=cid and m.status='ACTIVE' and m.role='ACCOUNTING_ADMIN' and f.status='ACTIVE') then
  raise exception 'Active Accounting Admin required' using errcode='23514'; end if;
 select * into provision from private.company_accounting_provisions where company_id=cid;
 if found then
  if provision.intent_hash<>intent_digest then raise exception 'Provisioning intent differs; no repair or takeover' using errcode='22023'; end if;
  if entity.accounting_setup<>'COMPLETE'
    or (select count(*) from public.accounts a where a.company_id=cid and a.id=any(provision.account_ids))<>11
    or not exists(select 1 from public.treasury_accounts t where t.id=provision.treasury_id and t.company_id=cid) then
   raise exception 'Provisioned foundation requires review; no automatic repair' using errcode='23514'; end if;
  -- Same intent, including a new request UUID, never inserts accounts or Treasury again.
 else
  if prior.receipt is not null then raise exception 'Provisioning evidence missing' using errcode='23514'; end if;
  if entity.version<>expected then raise exception 'Stale entity' using errcode='40001'; end if;
  if entity.accounting_setup<>'INCOMPLETE' or not exists(select 1 from private.platform_events e where e.target_id=cid and e.action='create_entity') then
   raise exception 'Only a new platform-created empty Company may be provisioned' using errcode='23514'; end if;
  -- Reject legacy/partial/business-bearing books instead of adopting or overwriting.
  for owned_table in select c.relname from pg_catalog.pg_class c join pg_catalog.pg_namespace n on n.oid=c.relnamespace
   where n.nspname='public' and c.relkind in ('r','p') and c.relname not in ('company_settings','company_memberships')
    and exists(select 1 from pg_catalog.pg_attribute a where a.attrelid=c.oid and a.attname='company_id' and not a.attisdropped) loop
   execute format('select exists(select 1 from public.%I where company_id=$1)',owned_table.relname) into has_rows using cid;
   if has_rows then raise exception 'Company is not empty; reviewed migration/setup required' using errcode='23514'; end if;
  end loop;
  if exists(select 1 from private.reference_counters where company_id=cid) then raise exception 'Existing accounting references' using errcode='23514'; end if;
  -- Existing canonical keys/types. OWNER_CURRENT deliberately excluded: its type policy is unresolved.
  insert into private.company_initialization_scope(company_id,transaction_id,actor_id) values(cid,txid_current(),actor);
  -- Treasury Asset is an empty GL location; no cash balance, capital or journal is invented.
  for template in select * from (values
   ('100000','Primary Treasury','ASSET',null,false),
   ('120000','Input VAT','ASSET','INPUT_VAT',false),
   ('130000','Custody advances','ASSET','CUSTODY_ADVANCE',true),
   ('140000','Subcontractor advances','ASSET','SUBCONTRACTOR_ADVANCE',true),
   ('210000','Supplier payable','LIABILITY','SUPPLIER_PAYABLE',true),
   ('220000','Subcontractor payable','LIABILITY','SUBCONTRACTOR_PAYABLE',true),
   ('230000','Subcontractor retention payable','LIABILITY','SUBCONTRACTOR_RETENTION_PAYABLE',true),
   ('240000','Salary payable','LIABILITY','SALARY_PAYABLE',true),
   ('510000','Project cost','EXPENSE','PROJECT_COST',false),
   ('520000','Subcontractor project cost','EXPENSE','PROJECT_COST_SUBCONTRACTORS',false),
   ('530000','Company expense','EXPENSE','COMPANY_EXPENSE',false)
  ) as t(code,name,account_type,system_key,requires_party) loop
   insert into public.accounts(company_id,code,name,account_type,system_key,requires_party,created_by,updated_by)
    values(cid,template.code,template.name,template.account_type::public.account_type,
      template.system_key::public.system_account_key,template.requires_party,actor,actor) returning id into account_id;
   account_ids:=array_append(account_ids,account_id);
  end loop;
  insert into public.treasury_accounts(company_id,code,name,type,gl_account_id,bank_name,created_by,updated_by)
   values(cid,'PRIMARY',treasury_name,treasury_type::public.treasury_account_type,account_ids[1],bank_name,actor,actor) returning id into treasury_id;
  delete from private.company_initialization_scope where company_id=cid and transaction_id=txid_current();
  insert into private.company_accounting_provisions(company_id,template_key,intent_hash,account_ids,treasury_id,actor_id,request_id)
   values(cid,'CONTRACTING_BASELINE_V1',intent_digest,account_ids,treasury_id,actor,request_id);
  update private.platform_entities set accounting_setup='COMPLETE',version=version+1 where company_id=cid;
  insert into private.platform_events(actor_id,action,target_id,request_id,metadata)
   values(actor,'provision_accounting',cid,request_id,jsonb_build_object('template','CONTRACTING_BASELINE_V1','accounts',11,'treasury_id',treasury_id,'reason',reason));
 end if;
 result:=coalesce(prior.receipt,jsonb_build_object('id',cid,'request_id',request_id,'command','provision_accounting','status','CONFIRMED'));
 update private.platform_requests r set receipt=result where r.actor_id=actor and r.request_id=provision_company_accounting.request_id;
 return result;
end $$;
revoke all on function public.provision_company_accounting(uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.provision_company_accounting(uuid,jsonb) to authenticated;

-- Read-only Company-scoped workspace status; platform authority grants no financial access.

-- Keep the existing member contract, but FULL now means authoritative business readiness.
create or replace function public.get_my_company_subscription(target_company_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s private.company_subscriptions; r jsonb;today date:=(statement_timestamp() at time zone 'Asia/Dubai')::date;
begin
 if not public.is_company_member(target_company_id) then raise exception 'Denied' using errcode='42501';end if;
 select * into s from private.company_subscriptions where company_id=target_company_id;
 r:=private.company_commercial_readiness(target_company_id);
 return jsonb_build_object('company_id',target_company_id,'plan_key',coalesce(s.plan_key,'UNASSIGNED'),'state',r->>'subscription_state',
 'starts_on',s.starts_on,'ends_on',s.ends_on,'renewal_due_on',s.ends_on+1,'payment_status',s.payment_status,
 'access',case when (r->>'ready')::boolean then 'FULL' else 'LIMITED' end,'commercial_readiness',r);
end $$;
revoke all on function public.get_my_company_subscription(uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_my_company_subscription(uuid) to authenticated;

create function public.get_platform_onboarding(target_customer_id uuid default null,target_company_id uuid default null,
 page_offset integer default 0,page_size integer default 25,search text default '') returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 perform private.platform_read_actor();
 if page_offset is null or page_size is null or search is null or page_offset<0 or page_offset>100000 or page_size not between 1 and 100 or length(search)>100 then
 raise exception 'Invalid page' using errcode='22023';end if;
 select coalesce(jsonb_agg(to_jsonb(q)),'[]') into result from (
  select c.id,c.code,c.name,c.legal_name,c.trn,c.address,e.region,e.entity_kind,coalesce(e.version,0) version,e.customer_id,cu.name customer_name,
  coalesce(e.lifecycle,case when c.status='ACTIVE' then 'ACTIVE' else 'SUSPENDED' end) lifecycle,
  coalesce(e.accounting_setup,'UNASSESSED') accounting_setup,
  coalesce(s.version,0) subscription_version,s.plan_key,s.state subscription_state,s.starts_on,s.ends_on,s.billing_method,s.payment_status,
  private.company_commercial_readiness(c.id) readiness,
  (select count(*) from private.platform_invitations i where i.company_id=c.id and i.state='PENDING' and i.expires_at>now() and i.role='ACCOUNTING_ADMIN') pending_admin_invitations
  from public.companies c left join private.platform_entities e on e.company_id=c.id
  left join private.platform_customers cu on cu.id=e.customer_id left join private.company_subscriptions s on s.company_id=c.id
  where (target_customer_id is null or e.customer_id=target_customer_id) and (target_company_id is null or c.id=target_company_id)
  and (c.name ilike '%'||search||'%' or c.code ilike '%'||search||'%') order by c.id limit page_size offset page_offset
 )q;
 return jsonb_build_object('items',result,'has_more',exists(select 1 from public.companies c left join private.platform_entities e on e.company_id=c.id
 where (target_customer_id is null or e.customer_id=target_customer_id) and (target_company_id is null or c.id=target_company_id)
 and (c.name ilike '%'||search||'%' or c.code ilike '%'||search||'%') order by c.id offset page_offset+page_size));
end $$;
revoke all on function public.get_platform_onboarding(uuid,uuid,integer,integer,text) from public,anon,authenticated,service_role;
grant execute on function public.get_platform_onboarding(uuid,uuid,integer,integer,text) to authenticated;
create or replace function public.list_company_subscriptions(page_offset integer default 0,page_size integer default 25,search text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;today date:=(statement_timestamp() at time zone 'Asia/Dubai')::date;
begin
 perform private.platform_read_actor();
 if page_offset is null or page_size is null or search is null or page_offset<0 or page_offset>100000 or page_size not between 1 and 100 or length(search)>100 then raise exception 'Invalid page' using errcode='22023';end if;
 select coalesce(jsonb_agg(to_jsonb(q)),'[]') into result from (
 select c.id,c.code,c.name,c.status company_status,coalesce(s.plan_key,'UNASSIGNED') plan_key,
 coalesce(s.state,'UNMANAGED') subscription_state,private.subscription_effective_state(s,today) effective_state,
 s.starts_on,s.ends_on,case when s.company_id is not null then s.ends_on+1 end renewal_due_on,
 s.billing_method,s.payment_status,s.payment_reference,coalesce(s.version,0) version,
 case when (private.company_commercial_readiness(c.id)->>'ready')::boolean then 'FULL' else 'LIMITED' end subscription_access
 from public.companies c left join private.company_subscriptions s on s.company_id=c.id
 where c.name ilike '%'||search||'%' or c.code ilike '%'||search||'%' or c.id::text=search order by c.id limit page_size offset page_offset
 )q;
 return jsonb_build_object('items',result,'has_more',exists(select 1 from public.companies c where c.name ilike '%'||search||'%' or c.code ilike '%'||search||'%' or c.id::text=search offset page_offset+page_size));
end $$;
revoke all on function public.list_company_subscriptions(integer,integer,text) from public,anon,authenticated,service_role;
grant execute on function public.list_company_subscriptions(integer,integer,text) to authenticated;

