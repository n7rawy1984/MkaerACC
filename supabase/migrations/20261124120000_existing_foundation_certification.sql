-- 106. Opt-in certification of existing books. No backfill or financial writes.
create table private.company_foundation_certifications (
 company_id uuid primary key references public.companies(id) on delete restrict,
 actor_id uuid not null references auth.users(id) on delete restrict,
 request_id uuid not null,reason text not null check(length(btrim(reason)) between 5 and 500),
 validation jsonb not null check(validation->>'eligible'='true'),
 created_at timestamptz not null default clock_timestamp()
);
alter table private.company_foundation_certifications enable row level security;
alter table private.company_foundation_certifications force row level security;
revoke all on private.company_foundation_certifications from public,anon,authenticated,service_role;
create trigger foundation_certification_immutable before update or delete on private.company_foundation_certifications
 for each row execute function private.reject_platform_audit_mutation();

-- STABLE: every check uses the same statement snapshot; certification is a bounded
-- structural GL check, not verification of historical invoices or economic facts.
create function private.existing_foundation_validation(cid uuid) returns jsonb
language sql stable security definer set search_path='' as $$
with recursive ancestry(id,parent_account_id,path,cycle) as (
 select id,parent_account_id,array[id],false from public.accounts where company_id=cid
 union all select a.id,a.parent_account_id,p.path||a.id,a.id=any(p.path) from ancestry p join public.accounts a on a.id=p.parent_account_id and a.company_id=cid where not p.cycle
),required(key,kind,party) as (values
 ('INPUT_VAT','ASSET',false),('CUSTODY_ADVANCE','ASSET',true),('SUBCONTRACTOR_ADVANCE','ASSET',true),
 ('SUPPLIER_PAYABLE','LIABILITY',true),('SUBCONTRACTOR_PAYABLE','LIABILITY',true),('SUBCONTRACTOR_RETENTION_PAYABLE','LIABILITY',true),
 ('SALARY_PAYABLE','LIABILITY',true),('PROJECT_COST','EXPENSE',false),('PROJECT_COST_SUBCONTRACTORS','EXPENSE',false),('COMPANY_EXPENSE','EXPENSE',false)),
 failures(code,reference) as (
 select 'COMPANY_ACTIVE',cid::text where not exists(select 1 from public.companies where id=cid and status='ACTIVE')
 union all select 'ENROLL_BUSINESS',cid::text where not exists(select 1 from private.platform_entities where company_id=cid and lifecycle='ACTIVE' and entity_kind='BUSINESS')
 union all select 'ACCOUNTING_ADMIN',cid::text where not exists(select 1 from public.company_memberships m join public.profiles p on p.user_id=m.user_id where m.company_id=cid and m.status='ACTIVE' and m.role='ACCOUNTING_ADMIN' and p.status='ACTIVE')
 union all select 'CONTROL_MAPPING',r.key from required r where not exists(select 1 from public.accounts a where a.company_id=cid and a.system_key::text=r.key and a.account_type::text=r.kind and a.status='ACTIVE' and a.requires_party=r.party)
 union all select 'TREASURY_REQUIRED',cid::text where not exists(select 1 from public.treasury_accounts where company_id=cid and status='ACTIVE')
 union all select 'TREASURY_MAPPING',t.code from public.treasury_accounts t left join public.accounts a on a.company_id=t.company_id and a.id=t.gl_account_id where t.company_id=cid and (a.id is null or a.account_type<>'ASSET' or a.system_key is not null or a.requires_party or (t.status='ACTIVE' and a.status<>'ACTIVE') or (t.type in('BANK','PROJECT_BANK') and nullif(btrim(t.bank_name),'')is null))
 union all select 'TREASURY_BALANCE',t.code from public.treasury_accounts t where t.company_id=cid and t.status='ACTIVE' and(select coalesce(sum(l.debit_minor::numeric-l.credit_minor),0)from public.journal_lines l where l.company_id=cid and l.account_id=t.gl_account_id)<0
 union all select 'ACCOUNT_PARENT',a.code from public.accounts a left join public.accounts p on p.company_id=a.company_id and p.id=a.parent_account_id where a.company_id=cid and a.parent_account_id is not null and (p.id is null or p.account_type<>a.account_type)
 union all select 'ACCOUNT_CYCLE',id::text from ancestry where cycle
 union all select 'JOURNAL_BALANCE',j.journal_reference from public.journal_entries j left join public.journal_lines l on l.company_id=j.company_id and l.journal_entry_id=j.id where j.company_id=cid group by j.id,j.journal_reference having count(l.id)<2 or coalesce(sum(l.debit_minor::numeric-l.credit_minor),0)<>0
 union all select 'LINE_DIMENSIONS',l.id::text from public.journal_lines l left join public.accounts a on a.company_id=l.company_id and a.id=l.account_id left join public.journal_entries j on j.company_id=l.company_id and j.id=l.journal_entry_id left join public.parties p on p.company_id=l.company_id and p.id=l.party_id left join public.projects pr on pr.company_id=l.company_id and pr.id=l.project_id left join public.treasury_accounts t on t.company_id=l.company_id and t.id=l.treasury_account_id left join public.subcontracts s on s.company_id=l.company_id and s.id=l.subcontract_id where l.company_id=cid and (a.id is null or j.id is null or(a.requires_party and l.party_id is null)or(l.party_id is not null and p.id is null)or(l.project_id is not null and pr.id is null)or(l.treasury_account_id is not null and(t.id is null or t.gl_account_id<>l.account_id))or(l.treasury_account_id is null and exists(select 1 from public.treasury_accounts gt where gt.company_id=cid and gt.gl_account_id=l.account_id))or(l.subcontract_id is not null and(s.id is null or s.project_id is distinct from l.project_id))or l.debit_minor<0 or l.credit_minor<0 or ((l.debit_minor>0)=(l.credit_minor>0)))
 union all select 'PERIOD_BOUNDS',p.label from public.accounting_fiscal_periods p join public.accounting_fiscal_years y on y.company_id=p.company_id and y.id=p.year_id where p.company_id=cid and (p.from_date<y.from_date or p.through_date>y.through_date)
 union all select 'PERIOD_OVERLAP',p.label from public.accounting_fiscal_periods p join public.accounting_fiscal_periods q on q.company_id=p.company_id and q.id<>p.id and q.from_date<=p.through_date and q.through_date>=p.from_date where p.company_id=cid
 union all select 'PERIOD_COVERAGE',j.journal_reference from public.journal_entries j where j.company_id=cid and exists(select 1 from public.accounting_fiscal_years where company_id=cid)and not exists(select 1 from public.accounting_fiscal_periods p where p.company_id=cid and j.posting_date between p.from_date and p.through_date)
 union all select 'OPENING_LINK',o.id::text from public.opening_balance_postings o left join public.journal_entries j on j.company_id=o.company_id and j.id=o.journal_id where o.company_id=cid and o.journal_id is not null and j.id is null
 union all select 'OPENING_POSITION',d.source_reference from public.opening_balance_postings o join public.opening_balance_drafts d on d.company_id=o.company_id and d.id=o.draft_id cross join lateral jsonb_array_elements(d.positions)x where o.company_id=cid and not exists(select 1 from public.opening_balance_reversals r where r.company_id=cid and r.posting_id=o.id)and(x->>'target_minor')::numeric is distinct from(select coalesce(sum(l.debit_minor::numeric-l.credit_minor),0)from public.journal_lines l join public.journal_entries j on j.company_id=l.company_id and j.id=l.journal_entry_id where l.company_id=cid and l.account_id=(x->>'account_id')::uuid and(x->>'party_id'is null or l.party_id=(x->>'party_id')::uuid)and j.posting_date<=d.opening_date)
 union all select 'IMMUTABILITY',v.t from(values('journal_entries'),('journal_lines'))v(t) where not exists(select 1 from pg_catalog.pg_trigger g where g.tgrelid=('public.'||v.t)::regclass and g.tgname=v.t||'_immutable' and g.tgenabled in('O','A') and g.tgfoid='private.reject_journal_mutation()'::regprocedure)
), summary as (select coalesce(jsonb_agg(jsonb_build_object('code',code,'reference',reference)order by code,reference),'[]')f from failures)
select jsonb_build_object('version','EXISTING_FOUNDATION_V1','checked_at',statement_timestamp(),'checks',jsonb_build_array('ACTIVE_BUSINESS_ADMIN','CONTROL_MAPPINGS','TREASURY_CONFIGURATION_AND_RECORDED_BALANCE','ACCOUNT_HIERARCHY','JOURNAL_BALANCE_AND_DIMENSIONS','OPENING_POSITION_RECONCILIATION','CONFIGURED_FISCAL_COVERAGE','JOURNAL_IMMUTABILITY_TRIGGERS'),'accounts_sha256',(select encode(sha256(convert_to(coalesce(string_agg(to_jsonb(a)::text,E'\n'order by a.id),''),'UTF8')),'hex')from public.accounts a where company_id=cid),'journals_sha256',(select encode(sha256(convert_to(coalesce(string_agg(to_jsonb(j)::text,E'\n'order by j.id),''),'UTF8')),'hex')from public.journal_entries j where company_id=cid),'lines_sha256',(select encode(sha256(convert_to(coalesce(string_agg(to_jsonb(l)::text,E'\n'order by l.id),''),'UTF8')),'hex')from public.journal_lines l where company_id=cid),'company_id',cid,'eligible',jsonb_array_length(f)=0,'failures',f,
 'scope','Structural controls, journal balance/dimensions, linked openings and configured fiscal coverage only; not historical economic evidence or physical cash verification.',
 'period_mode',case when exists(select 1 from public.accounting_fiscal_years where company_id=cid)then 'CONFIGURED'else 'EXISTING_UNCONFIGURED' end,
 'accounts',(select count(*)from public.accounts where company_id=cid),'journals',(select count(*)from public.journal_entries where company_id=cid),
 'debit_minor',(select coalesce(sum(debit_minor::numeric),0)::text from public.journal_lines where company_id=cid),
 'credit_minor',(select coalesce(sum(credit_minor::numeric),0)::text from public.journal_lines where company_id=cid))from summary
$$;
revoke all on function private.existing_foundation_validation(uuid) from public,anon,authenticated,service_role;

create function public.review_existing_company_foundation(target_company_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 perform private.platform_read_actor();
 if not exists(select 1 from public.companies where id=target_company_id)then raise exception 'Company unavailable' using errcode='22023';end if;
 return private.existing_foundation_validation(target_company_id);
end $$;
revoke all on function public.review_existing_company_foundation(uuid) from public,anon,authenticated,service_role;
grant execute on function public.review_existing_company_foundation(uuid) to authenticated;

create function public.certify_existing_company_foundation(request_id uuid,business_input jsonb)returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid;cid uuid;expected integer;p jsonb;digest bytea;prior private.platform_requests;report jsonb;result jsonb;entity private.platform_entities;
begin
 perform private.lock_platform_authorization();actor:=private.platform_actor();
 if request_id is null or jsonb_typeof(business_input)is distinct from 'object' or octet_length(business_input::text)>2000 or exists(select 1 from jsonb_each(business_input)where key<>all(array['id','version','reason'])or jsonb_typeof(value)<>'string')then raise exception 'Invalid certification request' using errcode='22023';end if;
 cid:=(business_input->>'id')::uuid;expected:=(business_input->>'version')::integer;
 if cid is null or expected is null or expected<1 or coalesce(length(btrim(business_input->>'reason')),0)not between 5 and 500 then raise exception 'Company, version and audited reason required' using errcode='22023';end if;
 p:=jsonb_build_object('id',cid::text,'version',expected::text,'reason',btrim(business_input->>'reason'));
 digest:=sha256(convert_to('certify_foundation:'||p::text,'UTF8'));
 insert into private.platform_requests(actor_id,request_id,command_name,request_hash)values(actor,request_id,'certify_foundation',digest)on conflict do nothing;
 select *into prior from private.platform_requests r where r.actor_id=actor and r.request_id=certify_existing_company_foundation.request_id for update;
 if prior.command_name<>'certify_foundation'or prior.request_hash<>digest then raise exception 'Idempotency mismatch' using errcode='22023';end if;
 perform private.serialize_operational_finance(cid,'OPERATIONS');
 perform 1 from public.companies where id=cid and status='ACTIVE'for update;
 if not found then raise exception 'Active Company required' using errcode='23514';end if;
 select *into entity from private.platform_entities where company_id=cid for update;
 if not found or entity.lifecycle<>'ACTIVE'or entity.entity_kind<>'BUSINESS'then raise exception 'Enroll existing Company as active Business first' using errcode='23514';end if;
 if prior.receipt is not null then return prior.receipt;end if;
 if exists(select 1 from private.company_foundation_certifications where company_id=cid)then
  result:=jsonb_build_object('id',cid,'request_id',request_id,'command','certify_foundation','status','CONFIRMED');
 else
  if entity.version<>expected then raise exception 'Stale entity' using errcode='40001';end if;
  if exists(select 1 from private.company_accounting_provisions where company_id=cid)then raise exception 'Already provisioned; use existing onboarding' using errcode='23514';end if;
  report:=private.existing_foundation_validation(cid);
  -- Return exact safe validation codes without provider errors or financial mutation.
  if not(report->>'eligible')::boolean then raise exception 'Foundation validation failed; review validation results' using errcode='23514';end if;
  insert into private.company_foundation_certifications(company_id,actor_id,request_id,reason,validation)values(cid,actor,request_id,p->>'reason',report);
  update private.platform_entities set accounting_setup='COMPLETE',version=version+1 where company_id=cid;
  insert into private.platform_events(actor_id,action,target_id,request_id,metadata)values(actor,'certify_foundation',cid,request_id,jsonb_build_object('reason',p->>'reason','validation',report));
  result:=jsonb_build_object('id',cid,'request_id',request_id,'command','certify_foundation','status','CONFIRMED');
 end if;
 update private.platform_requests r set receipt=result where r.actor_id=actor and r.request_id=certify_existing_company_foundation.request_id;
 return result;
end $$;
revoke all on function public.certify_existing_company_foundation(uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.certify_existing_company_foundation(uuid,jsonb) to authenticated;

create or replace function private.company_commercial_readiness(cid uuid) returns jsonb
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
 foundation_ok:=coalesce(e.accounting_setup='COMPLETE',false) and (exists(select 1 from private.company_accounting_provisions where company_id=cid) or exists(select 1 from private.company_foundation_certifications where company_id=cid));
 effective:=private.subscription_effective_state(s,(statement_timestamp() at time zone 'Asia/Dubai')::date);
 subscription_ok:=effective in ('TRIAL','ACTIVE');
 return jsonb_build_object('customer',customer_ok,'active',coalesce(active_ok,false),'administrator',admin_ok,'foundation',foundation_ok,
  'subscription',subscription_ok,'subscription_state',effective,'legacy_eligible',legacy,
  -- Enrollment is authoritative even for eligible legacy Companies: expiry still limits business.
  'legacy_access',legacy and s.company_id is null,
  'ready',coalesce(active_ok,false) and ((legacy and (s.company_id is null or subscription_ok)) or (customer_ok and admin_ok and foundation_ok and subscription_ok)));
end $$;
