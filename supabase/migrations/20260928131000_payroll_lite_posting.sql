-- Payroll Lite Step 2. Company-scoped immutable accounting and explicit draft classification.
insert into public.permissions(key,description) values
 ('payroll.post','Approve and post reviewed payroll'),('payroll.pay','Settle posted employee payroll'),('payroll.reverse','Reverse payroll and salary payments');
insert into public.role_permissions(role,permission_key) values
 ('ACCOUNTING_ADMIN','payroll.post'),('ACCOUNTING_ADMIN','payroll.pay'),('ACCOUNTANT','payroll.pay'),('ACCOUNTING_ADMIN','payroll.reverse');

-- Existing tenants must provision the stable mapping deliberately; never guess an account by name.
alter table public.accounts add constraint salary_payable_liability check(system_key<>'SALARY_PAYABLE' or account_type='LIABILITY');
create table public.payroll_draft_accounting (
 id uuid primary key default gen_random_uuid(), company_id uuid not null, period_id uuid not null, version integer not null,
 allocations jsonb not null, classifications jsonb not null,
 created_by uuid not null references auth.users(id), created_at timestamptz not null default now(),
 unique(company_id,period_id,version), foreign key(company_id,period_id) references public.payroll_draft_periods(company_id,id)
);
create table public.payroll_postings (
 id uuid primary key, company_id uuid not null, period_id uuid not null, month date not null, posting_date date not null,
 draft_version integer not null, snapshot jsonb not null, journal_id uuid not null unique,
 replaces_id uuid, created_by uuid not null references auth.users(id), created_at timestamptz not null default now(),
 unique(company_id,id), foreign key(company_id,period_id) references public.payroll_draft_periods(company_id,id),
 foreign key(company_id,journal_id) references public.journal_entries(company_id,id),
 foreign key(company_id,replaces_id) references public.payroll_postings(company_id,id),
 check(extract(day from month)=1 and posting_date=(month+interval '1 month - 1 day')::date)
);
create table public.payroll_entitlements (
 id uuid primary key default gen_random_uuid(), company_id uuid not null, payroll_id uuid not null, employee_id uuid not null,
 project_id uuid, cost_account_id uuid not null, payable_account_id uuid not null, amount_minor bigint not null check(amount_minor between 0 and 9000000000000000),
 unique(company_id,id), unique(company_id,payroll_id,employee_id),
 foreign key(company_id,payroll_id) references public.payroll_postings(company_id,id),
 foreign key(company_id,employee_id) references public.parties(company_id,id), foreign key(company_id,project_id) references public.projects(company_id,id),
 foreign key(company_id,cost_account_id) references public.accounts(company_id,id), foreign key(company_id,payable_account_id) references public.accounts(company_id,id)
);
create table public.salary_payments (
 id uuid primary key, company_id uuid not null, entitlement_id uuid not null, treasury_id uuid not null, payment_date date not null,
 amount_minor bigint not null check(amount_minor between 1 and 9000000000000000), reference text not null check(length(reference) between 1 and 200),
 journal_id uuid not null unique, created_by uuid not null references auth.users(id), created_at timestamptz not null default now(),
 unique(company_id,id), foreign key(company_id,entitlement_id) references public.payroll_entitlements(company_id,id),
 foreign key(company_id,treasury_id) references public.treasury_accounts(company_id,id), foreign key(company_id,journal_id) references public.journal_entries(company_id,id)
);
create table public.salary_payment_reversals (
 id uuid primary key, company_id uuid not null, payment_id uuid not null unique, journal_id uuid not null unique,
 reversal_date date not null, reason text not null check(length(reason) between 1 and 1000),
 created_by uuid not null references auth.users(id), created_at timestamptz not null default now(),
 foreign key(company_id,payment_id) references public.salary_payments(company_id,id), foreign key(company_id,journal_id) references public.journal_entries(company_id,id)
);
create table public.payroll_reversals (
 id uuid primary key, company_id uuid not null, payroll_id uuid not null unique, journal_id uuid not null unique,
 reversal_date date not null, reason text not null check(length(reason) between 1 and 1000),
 created_by uuid not null references auth.users(id), created_at timestamptz not null default now(),
 foreign key(company_id,payroll_id) references public.payroll_postings(company_id,id), foreign key(company_id,journal_id) references public.journal_entries(company_id,id)
);
-- Private mutable lifecycle index; immutable business events above remain the audit truth.
create table private.live_payroll_periods (
 company_id uuid not null, month date not null, payroll_id uuid not null unique,
 primary key(company_id,month), foreign key(company_id,payroll_id) references public.payroll_postings(company_id,id)
);
revoke all on private.live_payroll_periods from public,anon,authenticated,service_role;
create index salary_payment_entitlement on public.salary_payments(company_id,entitlement_id);

create function private.payroll_open_draft_guard() returns trigger language plpgsql set search_path='' as $$
begin
 perform private.attendance_company_lock(new.company_id);
 if exists(select 1 from private.live_payroll_periods where company_id=new.company_id and month=new.month) then
  raise exception 'Posted payroll requires controlled reversal' using errcode='23514'; end if;
 return new;
end $$;
create trigger payroll_posted_draft_guard before update on public.payroll_draft_periods for each row execute function private.payroll_open_draft_guard();

create function public.prepare_payroll_accounting(target_company_id uuid,target_period_id uuid,target_version integer,target_allocations jsonb,target_classifications jsonb)
returns void language plpgsql security definer set search_path='' as $$
declare p public.payroll_draft_periods; r record; a jsonb; category text;
begin
 if not public.has_permission(target_company_id,'payroll.manage') then raise exception 'Payroll denied' using errcode='42501'; end if;
 perform private.attendance_company_lock(target_company_id);
 select * into p from public.payroll_draft_periods where company_id=target_company_id and id=target_period_id for update;
 if not found or target_version is distinct from p.version then raise exception 'Draft changed; reload' using errcode='40001'; end if;
 if p.source_hash<>md5(private.payroll_draft_source(target_company_id,p.month)::text) or p.adjustments_revision<>p.calculated_adjustments_revision then
  raise exception 'Refresh current draft first' using errcode='40001'; end if;
 if jsonb_typeof(target_allocations) is distinct from 'object' or jsonb_typeof(target_classifications) is distinct from 'object' then raise exception 'Explicit allocation/classification required' using errcode='23514'; end if;
 if (select count(*) from jsonb_object_keys(target_allocations))<>(select count(*) from public.payroll_draft_rows where period_id=p.id and included) then raise exception 'Allocate every included employee exactly once' using errcode='23514'; end if;
 for r in select * from public.payroll_draft_rows where period_id=p.id and included loop
  a:=target_allocations->r.id::text;
  if a is null or (a<>'null'::jsonb and (jsonb_typeof(a)<>'string' or not exists(select 1 from public.projects where company_id=target_company_id and id=(a#>>'{}')::uuid and status<>'CLOSED'))) then
   raise exception 'Explicit Company overhead or eligible same-Company Project required' using errcode='23514'; end if;
 end loop;
 if (select count(*) from jsonb_object_keys(target_classifications))<>(select count(*) from public.payroll_draft_adjustments a join public.payroll_draft_rows r on r.id=a.row_id where r.period_id=p.id and not a.voided) then raise exception 'Classify every live adjustment' using errcode='23514'; end if;
 for r in select a.* from public.payroll_draft_adjustments a join public.payroll_draft_rows r on r.id=a.row_id where r.period_id=p.id and not a.voided loop
  category:=target_classifications->>r.id::text;
  if category is distinct from (case r.kind when 'ADDITION' then 'EARNED_SALARY_ADDITION' else 'CURRENT_SALARY_REDUCTION' end) then
   raise exception 'Unsupported adjustment accounting category' using errcode='23514'; end if;
 end loop;
 update public.payroll_draft_periods set version=version+1,reviewed_version=null,reviewed_by=null,reviewed_at=null where id=p.id;
 insert into public.payroll_draft_accounting(company_id,period_id,version,allocations,classifications,created_by)
 values(target_company_id,p.id,p.version+1,target_allocations,target_classifications,auth.uid());
end $$;

create function private.payroll_reserve(c uuid,kind text,k uuid,payload jsonb) returns private.financial_command_requests
language sql set search_path='' as $$
 select private.reserve_financial_command(c,kind,k,encode(extensions.digest(convert_to(payload::text,'UTF8'),'sha256'),'hex'),auth.uid());
$$;
create function public.post_payroll(target_company_id uuid,target_period_id uuid,target_version integer,target_idempotency_key uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare p public.payroll_draft_periods; plan public.payroll_draft_accounting; req private.financial_command_requests; r record;
 result_id uuid:=gen_random_uuid(); j uuid; payable uuid; cost uuid; project uuid; lines jsonb:='[]'; snap jsonb; previous uuid;
begin
 if not public.has_permission(target_company_id,'payroll.post') then raise exception 'Payroll POST denied' using errcode='42501'; end if;
 perform private.attendance_company_lock(target_company_id);
 req:=private.payroll_reserve(target_company_id,'POST_PAYROLL',target_idempotency_key,jsonb_build_object('period',target_period_id,'version',target_version));
 if req.status='COMPLETED' then return (select id from public.payroll_postings where company_id=target_company_id and journal_id=req.resulting_journal_entry_id); end if;
 select * into p from public.payroll_draft_periods where company_id=target_company_id and id=target_period_id for update;
 if not found or target_version is distinct from p.version or p.reviewed_version is distinct from p.version then raise exception 'Fresh reviewed draft required' using errcode='40001'; end if;
 if (p.month+interval '1 month')::date>(current_timestamp at time zone 'Asia/Dubai')::date then raise exception 'Payroll month must be complete' using errcode='23514'; end if;
 -- Stabilize employee metadata/status while validating the exact reviewed source.
 perform 1 from public.parties e join public.payroll_profiles f on f.company_id=e.company_id and f.employee_id=e.id where f.company_id=target_company_id order by e.id for share of e;
 snap:=public.read_payroll_draft(target_company_id,p.month);
 if (snap->>'stale')::boolean or not (snap->>'review_valid')::boolean then raise exception 'Draft stale; refresh and review' using errcode='40001'; end if;
 select * into plan from public.payroll_draft_accounting where company_id=target_company_id and period_id=p.id and version=p.version;
 if not found then raise exception 'Explicit allocation and adjustment classification required' using errcode='23514'; end if;
 select id into payable from public.accounts where company_id=target_company_id and system_key='SALARY_PAYABLE' and account_type='LIABILITY' and status='ACTIVE' for share;
 if payable is null then raise exception 'Active SALARY_PAYABLE LIABILITY mapping required' using errcode='23514'; end if;
 for r in select * from public.payroll_draft_rows where period_id=p.id and included order by employee_id loop
  project:=(plan.allocations->>r.id::text)::uuid;
  if project is not null then
   perform 1 from public.projects where company_id=target_company_id and id=project and status<>'CLOSED' for share;
   if not found then raise exception 'Allocated Project unavailable' using errcode='23514'; end if;
  end if;
  select id into cost from public.accounts where company_id=target_company_id and system_key=case when project is null then 'COMPANY_EXPENSE'::public.system_account_key else 'PROJECT_COST'::public.system_account_key end and account_type='EXPENSE' and status='ACTIVE' for share;
  if cost is null then raise exception 'Active cost EXPENSE mapping required' using errcode='23514'; end if;
  if r.net_salary_minor>0 then lines:=lines||jsonb_build_array(
   jsonb_build_object('account_id',cost,'debit_minor',r.net_salary_minor::text,'credit_minor','0','project_id',project,'party_id',r.employee_id),
   jsonb_build_object('account_id',payable,'debit_minor','0','credit_minor',r.net_salary_minor::text,'project_id',project,'party_id',r.employee_id)); end if;
 end loop;
 if jsonb_array_length(lines)=0 then raise exception 'All-zero payroll cannot post' using errcode='23514'; end if;
 perform private.lock_attendance_month(target_company_id,p.month,p.attendance_revision);
 j:=private.create_journal(target_company_id,(p.month+interval '1 month - 1 day')::date,'Payroll recognition','PAYROLL',result_id,'POST',lines,auth.uid());
 select x.id into previous from public.payroll_postings x join public.payroll_reversals v on v.payroll_id=x.id where x.company_id=target_company_id and x.month=p.month order by x.created_at desc,x.id desc limit 1;
 insert into public.payroll_postings(id,company_id,period_id,month,posting_date,draft_version,snapshot,journal_id,replaces_id,created_by)
 values(result_id,target_company_id,p.id,p.month,(p.month+interval '1 month - 1 day')::date,p.version,snap||jsonb_build_object('accounting',to_jsonb(plan)),j,previous,auth.uid());
 insert into public.payroll_entitlements(company_id,payroll_id,employee_id,project_id,cost_account_id,payable_account_id,amount_minor)
 select target_company_id,result_id,r.employee_id,(plan.allocations->>r.id::text)::uuid,a.id,payable,r.net_salary_minor
 from public.payroll_draft_rows r join public.accounts a on a.company_id=r.company_id and a.system_key=case when plan.allocations->>r.id::text is null then 'COMPANY_EXPENSE'::public.system_account_key else 'PROJECT_COST'::public.system_account_key end
 where r.period_id=p.id and r.included;
 insert into private.live_payroll_periods values(target_company_id,p.month,result_id);
 perform private.complete_financial_command(req.id,j); return result_id;
end $$;

create function private.payroll_unpaid(e uuid) returns numeric language sql stable set search_path='' as $$
 select x.amount_minor::numeric-coalesce((select sum(p.amount_minor::numeric) from public.salary_payments p where p.entitlement_id=x.id and not exists(select 1 from public.salary_payment_reversals v where v.payment_id=p.id)),0)
 from public.payroll_entitlements x where x.id=e;
$$;
create function public.pay_salary(target_company_id uuid,target_entitlement_id uuid,target_treasury_id uuid,target_date date,target_amount_minor bigint,target_reference text,target_idempotency_key uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare e public.payroll_entitlements; t public.treasury_accounts; p public.payroll_postings; req private.financial_command_requests; result_id uuid:=gen_random_uuid(); j uuid;
begin
 if not public.has_permission(target_company_id,'payroll.pay') then raise exception 'Salary payment denied' using errcode='42501'; end if;
 perform private.attendance_company_lock(target_company_id);
 req:=private.payroll_reserve(target_company_id,'PAY_SALARY',target_idempotency_key,jsonb_build_object('entitlement',target_entitlement_id,'treasury',target_treasury_id,'date',target_date,'amount',target_amount_minor::text,'reference',btrim(target_reference)));
 if req.status='COMPLETED' then return (select id from public.salary_payments where company_id=target_company_id and journal_id=req.resulting_journal_entry_id); end if;
 select * into e from public.payroll_entitlements where company_id=target_company_id and id=target_entitlement_id for update;
 if not found then raise exception 'Entitlement unavailable' using errcode='42501'; end if;
 select * into p from public.payroll_postings where id=e.payroll_id;
 if not exists(select 1 from private.live_payroll_periods where payroll_id=p.id) then raise exception 'Payroll reversed' using errcode='23514'; end if;
 if target_date is null or target_date<p.posting_date or target_date>(current_timestamp at time zone 'Asia/Dubai')::date or target_amount_minor is null or target_amount_minor<=0 or target_amount_minor>private.payroll_unpaid(e.id) or nullif(btrim(target_reference),'') is null then raise exception 'Invalid payment date, amount or reference' using errcode='23514'; end if;
 select * into t from public.treasury_accounts where company_id=target_company_id and id=target_treasury_id and status='ACTIVE' for share;
 if not found or (t.project_id is not null and t.project_id is distinct from e.project_id) then raise exception 'Compatible active Treasury required' using errcode='23514'; end if;
 perform 1 from public.accounts where company_id=target_company_id and id=t.gl_account_id and account_type='ASSET' and status='ACTIVE' for share;
 if not found then raise exception 'Active Treasury ASSET account required' using errcode='23514'; end if;
 j:=private.create_journal(target_company_id,target_date,'Salary payment','SALARY_PAYMENT',result_id,'POST',jsonb_build_array(
  jsonb_build_object('account_id',e.payable_account_id,'debit_minor',target_amount_minor::text,'credit_minor','0','project_id',e.project_id,'party_id',e.employee_id),
  jsonb_build_object('account_id',t.gl_account_id,'debit_minor','0','credit_minor',target_amount_minor::text,'project_id',e.project_id,'party_id',e.employee_id,'treasury_account_id',t.id)),auth.uid());
 insert into public.salary_payments(id,company_id,entitlement_id,treasury_id,payment_date,amount_minor,reference,journal_id,created_by)
 values(result_id,target_company_id,e.id,t.id,target_date,target_amount_minor,btrim(target_reference),j,auth.uid());
 perform private.complete_financial_command(req.id,j); return result_id;
end $$;

create function public.reverse_salary_payment(target_company_id uuid,target_payment_id uuid,target_date date,target_reason text,target_idempotency_key uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare p public.salary_payments; req private.financial_command_requests; result_id uuid:=gen_random_uuid(); j uuid;
begin
 if not public.has_permission(target_company_id,'payroll.reverse') then raise exception 'Payroll reversal denied' using errcode='42501'; end if;
 perform private.attendance_company_lock(target_company_id);
 req:=private.payroll_reserve(target_company_id,'REVERSE_SALARY_PAYMENT',target_idempotency_key,jsonb_build_object('payment',target_payment_id,'date',target_date,'reason',btrim(target_reason)));
 if req.status='COMPLETED' then return (select id from public.salary_payment_reversals where company_id=target_company_id and journal_id=req.resulting_journal_entry_id); end if;
 select * into p from public.salary_payments where company_id=target_company_id and id=target_payment_id for update;
 if not found then raise exception 'Payment unavailable' using errcode='42501'; end if;
 if target_date is null or target_date<p.payment_date or target_date>(current_timestamp at time zone 'Asia/Dubai')::date or nullif(btrim(target_reason),'') is null then raise exception 'Valid reversal date and reason required' using errcode='23514'; end if;
 j:=private.reverse_journal(p.journal_id,target_date,btrim(target_reason),auth.uid());
 insert into public.salary_payment_reversals(id,company_id,payment_id,journal_id,reversal_date,reason,created_by) values(result_id,target_company_id,p.id,j,target_date,btrim(target_reason),auth.uid());
 perform private.complete_financial_command(req.id,j); return result_id;
end $$;
create function public.reverse_payroll(target_company_id uuid,target_payroll_id uuid,target_date date,target_reason text,target_idempotency_key uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare p public.payroll_postings; req private.financial_command_requests; result_id uuid:=gen_random_uuid(); j uuid;
begin
 if not public.has_permission(target_company_id,'payroll.reverse') then raise exception 'Payroll reversal denied' using errcode='42501'; end if;
 perform private.attendance_company_lock(target_company_id);
 req:=private.payroll_reserve(target_company_id,'REVERSE_PAYROLL',target_idempotency_key,jsonb_build_object('payroll',target_payroll_id,'date',target_date,'reason',btrim(target_reason)));
 if req.status='COMPLETED' then return (select id from public.payroll_reversals where company_id=target_company_id and journal_id=req.resulting_journal_entry_id); end if;
 select * into p from public.payroll_postings where company_id=target_company_id and id=target_payroll_id for update;
 if not found then raise exception 'Payroll unavailable' using errcode='42501'; end if;
 if target_date is null or target_date<p.posting_date or target_date>(current_timestamp at time zone 'Asia/Dubai')::date or nullif(btrim(target_reason),'') is null then raise exception 'Valid reversal date and reason required' using errcode='23514'; end if;
 if exists(select 1 from public.salary_payments s join public.payroll_entitlements e on e.id=s.entitlement_id where e.payroll_id=p.id and not exists(select 1 from public.salary_payment_reversals v where v.payment_id=s.id)) then raise exception 'Reverse all live salary payments first' using errcode='23514'; end if;
 if exists(select 1 from public.salary_payment_reversals v join public.salary_payments s on s.id=v.payment_id join public.payroll_entitlements e on e.id=s.entitlement_id where e.payroll_id=p.id and v.reversal_date>target_date) then raise exception 'Payroll reversal cannot predate payment reversal' using errcode='23514'; end if;
 j:=private.reverse_journal(p.journal_id,target_date,btrim(target_reason),auth.uid());
 insert into public.payroll_reversals(id,company_id,payroll_id,journal_id,reversal_date,reason,created_by) values(result_id,target_company_id,p.id,j,target_date,btrim(target_reason),auth.uid());
 delete from private.live_payroll_periods where company_id=target_company_id and payroll_id=p.id;
 update public.attendance_periods set locked_at=null,revision=revision+1,reviewed_revision=null,reviewed_at=null,reviewed_by=null where company_id=target_company_id and month=p.month;
 update public.payroll_draft_periods set version=version+1,reviewed_version=null,reviewed_by=null,reviewed_at=null where id=p.period_id;
 perform private.complete_financial_command(req.id,j); return result_id;
end $$;

-- A fixed predicate is used by restrictive policies, so existing permissive policies cannot bypass privacy.
-- SECURITY DEFINER avoids self-recursive journal RLS. Only returns an actor-authorized boolean.
create function public.payroll_journal_visible(target_company_id uuid,target_journal_id uuid) returns boolean
language sql stable security definer set search_path='' as $$
 select public.is_company_member(target_company_id) and (
 public.has_permission(target_company_id,'payroll.manage') or not exists(
  select 1 from public.journal_entries j left join public.journal_entries original on original.id=j.reversal_of_journal_entry_id
  where j.id=target_journal_id and j.company_id=target_company_id
  and (j.source_type in ('PAYROLL','SALARY_PAYMENT') or original.source_type in ('PAYROLL','SALARY_PAYMENT'))));
$$;
create policy payroll_journal_privacy on public.journal_entries as restrictive for select to authenticated
 using(public.payroll_journal_visible(company_id,id));
create policy payroll_journal_line_privacy on public.journal_lines as restrictive for select to authenticated
 using(public.payroll_journal_visible(company_id,journal_entry_id));

create function public.read_payroll_postings(target_company_id uuid,target_month date) returns jsonb
language plpgsql stable security definer set search_path='' as $$
begin
 if not public.has_permission(target_company_id,'payroll.manage') then raise exception 'Payroll denied' using errcode='42501'; end if;
 return jsonb_build_object(
 'accounting', (select to_jsonb(a) from public.payroll_draft_accounting a join public.payroll_draft_periods p on p.id=a.period_id and p.version=a.version where a.company_id=target_company_id and p.month=target_month),
 'postings',coalesce((select jsonb_agg(to_jsonb(p)||jsonb_build_object('reversed',exists(select 1 from public.payroll_reversals v where v.payroll_id=p.id)) order by p.created_at,p.id) from public.payroll_postings p where p.company_id=target_company_id and p.month=target_month),'[]'::jsonb),
 'entitlements',coalesce((select jsonb_agg((to_jsonb(e)-'amount_minor')||jsonb_build_object('amount_minor',e.amount_minor::text,'unpaid_minor',private.payroll_unpaid(e.id)::text,'employee_name',
  (select r->>'employee_name' from jsonb_array_elements(p.snapshot->'rows') r where r->>'employee_id'=e.employee_id::text))) from public.payroll_entitlements e join public.payroll_postings p on p.id=e.payroll_id where e.company_id=target_company_id and p.month=target_month),'[]'::jsonb),
 'payments',coalesce((select jsonb_agg((to_jsonb(s)-'amount_minor')||jsonb_build_object('amount_minor',s.amount_minor::text,'reversed',exists(select 1 from public.salary_payment_reversals v where v.payment_id=s.id)) order by s.created_at,s.id) from public.salary_payments s join public.payroll_entitlements e on e.id=s.entitlement_id join public.payroll_postings p on p.id=e.payroll_id where s.company_id=target_company_id and p.month=target_month),'[]'::jsonb),
 'reversals',coalesce((select jsonb_agg(to_jsonb(v)) from public.payroll_reversals v join public.payroll_postings p on p.id=v.payroll_id where v.company_id=target_company_id and p.month=target_month),'[]'::jsonb),
 'payment_reversals',coalesce((select jsonb_agg(to_jsonb(v)) from public.salary_payment_reversals v join public.salary_payments s on s.id=v.payment_id join public.payroll_entitlements e on e.id=s.entitlement_id join public.payroll_postings p on p.id=e.payroll_id where v.company_id=target_company_id and p.month=target_month),'[]'::jsonb),
 'treasuries',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'project_id',project_id)) from public.treasury_accounts where company_id=target_company_id and status='ACTIVE'),'[]'::jsonb));
end $$;

-- All events are append-only and browser SELECT-only; private commands own all mutation.
do $$ declare t text; f regprocedure; begin
 foreach t in array array['payroll_draft_accounting','payroll_postings','payroll_entitlements','salary_payments','salary_payment_reversals','payroll_reversals'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('alter table public.%I force row level security',t);
  execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
  execute format('grant select on public.%I to authenticated,service_role',t);
  execute format('create policy payroll_staff_read on public.%I for select to authenticated using(public.has_permission(company_id,''payroll.manage''))',t);
  execute format('create trigger payroll_immutable before update or delete on public.%I for each row execute function private.payroll_draft_no_delete()',t);
 end loop;
 for f in select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid=p.pronamespace where
  (n.nspname='public' and p.proname in ('prepare_payroll_accounting','post_payroll','pay_salary','reverse_salary_payment','reverse_payroll','read_payroll_postings','payroll_journal_visible')) or
  (n.nspname='private' and p.proname in ('payroll_open_draft_guard','payroll_reserve','payroll_unpaid')) loop
  execute format('revoke all on function %s from public,anon,authenticated,service_role',f);
  if f::text like 'prepare_payroll_accounting(%' or f::text like 'post_payroll(%' or f::text like 'pay_salary(%' or f::text like 'reverse_salary_payment(%' or f::text like 'reverse_payroll(%' or f::text like 'read_payroll_postings(%' or f::text like 'payroll_journal_visible(%' then execute format('grant execute on function %s to authenticated',f); end if;
 end loop;
end $$;
