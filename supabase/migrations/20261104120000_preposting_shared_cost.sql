-- Confirm nonposting source plans; recognize them once in the existing Expense engine.
create table public.source_expense_allocation_events (
 id uuid primary key default gen_random_uuid(),company_id uuid not null,source_id uuid not null,previous_event_id uuid,
 request_id uuid not null,actor_id uuid not null references auth.users(id) on delete restrict,
 source_amount_minor bigint not null check(source_amount_minor>0),source_date date not null,source_snapshot jsonb not null,
 plan jsonb not null,reason text not null check(length(reason) between 1 and 500),input_hash text not null,
 created_at timestamptz not null default clock_timestamp(),unique(company_id,id),unique(company_id,source_id,id),unique(company_id,request_id),unique(previous_event_id),
 foreign key(company_id,source_id) references public.historical_source_records(company_id,id) on delete restrict,
 foreign key(company_id,source_id,previous_event_id) references public.source_expense_allocation_events(company_id,source_id,id) on delete restrict
);
create unique index source_allocation_root on public.source_expense_allocation_events(company_id,source_id) where previous_event_id is null;
alter table public.source_expense_allocation_events enable row level security;
alter table public.source_expense_allocation_events force row level security;
revoke all on public.source_expense_allocation_events from public,anon,authenticated,service_role;
grant select on public.source_expense_allocation_events to authenticated;
create policy source_allocation_read on public.source_expense_allocation_events for select to authenticated using(public.has_company_role(company_id,'ACCOUNTING_ADMIN') or public.has_company_role(company_id,'ACCOUNTANT') or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create trigger source_allocation_immutable before update or delete on public.source_expense_allocation_events for each row execute function private.protect_project_cost_correction();
alter table public.historical_source_records add column expense_allocation_id uuid,
 add foreign key(company_id,id,expense_allocation_id) references public.source_expense_allocation_events(company_id,source_id,id) on delete restrict;
alter table public.expenses add column allocation_event_id uuid,add column allocation_plan jsonb,
 add foreign key(company_id,allocation_event_id) references public.source_expense_allocation_events(company_id,id) on delete restrict,
 add constraint expense_allocation_shape check((allocation_event_id is null and allocation_plan is null) or (allocation_event_id is not null and jsonb_typeof(allocation_plan)='object'));
create unique index expense_allocation_once on public.expenses(allocation_event_id) where allocation_event_id is not null;
create function private.protect_expense_allocation() returns trigger language plpgsql set search_path='' as $$
begin if new.allocation_event_id is distinct from old.allocation_event_id or new.allocation_plan is distinct from old.allocation_plan then raise exception 'Posted allocation is immutable' using errcode='23514';end if;return new;end;$$;
revoke all on function private.protect_expense_allocation() from public,anon,authenticated,service_role;
create trigger expense_allocation_immutable before update on public.expenses for each row execute function private.protect_expense_allocation();
create function private.source_allocation_snapshot(r public.historical_source_records) returns jsonb language sql immutable set search_path='' as $$
 select jsonb_build_object('completion',r.completion,'classification',r.classification,'date',r.source_date,'outflow',r.outflow_minor::text,'treasury',r.cash_treasury_id,'scope',r.allocation_scope,'project',r.assigned_project_id,'type',r.record_type)
$$;
revoke all on function private.source_allocation_snapshot(public.historical_source_records) from public,anon,authenticated,service_role;
create function private.require_source_allocation_period(d date) returns void language plpgsql set search_path='' as $$
declare today date:=(statement_timestamp() at time zone 'UTC')::date;begin
 if d is null or d<date_trunc('month',today)::date or d>today then raise exception 'Current-period source date required' using errcode='23514';end if;
end;$$;
revoke all on function private.require_source_allocation_period(date) from public,anon,authenticated,service_role;
create function private.check_source_allocation_period(cid uuid,d date) returns void language plpgsql set search_path='' as $$
begin perform private.require_source_allocation_period(d);
 if not exists(select 1 from public.project_correction_period_events p where p.company_id=cid and p.month=date_trunc('month',d)::date and p.state='OPEN') or exists(select 1 from public.project_correction_period_events p where p.company_id=cid and p.month=date_trunc('month',d)::date and p.state='CLOSED') then raise exception 'Explicit open allocation period required' using errcode='23514';end if;
end;$$;
revoke all on function private.check_source_allocation_period(uuid,date) from public,anon,authenticated,service_role;
create function public.confirm_source_expense_allocation(target_company_id uuid,target_source_id uuid,expected_updated_at timestamptz,expected_allocation_id uuid,request_id uuid,plan jsonb,reason text,basis_approved boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;r public.historical_source_records;a public.source_expense_allocation_events;normalized jsonb;digest text;pid uuid;why text:=private.correction_text(reason);amount bigint;d date;begin
 perform 1 from public.companies where id=target_company_id for share;actor:=private.correction_authority(target_company_id);
 if request_id is null or expected_updated_at is null or basis_approved is distinct from true or why is null or length(why)>500 then raise exception 'Approved basis and reason required' using errcode='22023';end if;
 select * into r from public.historical_source_records where company_id=target_company_id and id=target_source_id;
 if not found then raise exception 'Source unavailable' using errcode='42501';end if;
 perform pg_advisory_xact_lock(hashtextextended('source-allocation:'||target_company_id::text||':'||request_id::text,0));
 select * into a from public.source_expense_allocation_events e where e.company_id=target_company_id and e.request_id=confirm_source_expense_allocation.request_id;
 amount:=coalesce(a.source_amount_minor,(r.completion->>'amount_minor')::bigint,r.outflow_minor);normalized:=private.shared_cost_plan(amount,plan);
 digest:=encode(extensions.digest(jsonb_build_object('actor',actor,'source',r.id,'company',target_company_id,'epoch',extract(epoch from expected_updated_at),'previous',expected_allocation_id,'plan',normalized,'reason',why)::text,'sha256'),'hex');
 if a.id is not null then if a.input_hash<>digest then raise exception 'Request changed' using errcode='22023';end if;return (to_jsonb(a)-'input_hash'-'source_snapshot')||jsonb_build_object('source_amount_minor',a.source_amount_minor::text,'source_updated_at',a.created_at);end if;
 for pid in select (v->>'project_id')::uuid from jsonb_array_elements(normalized->'destinations') v where v->>'project_id' is not null order by 1 loop
  perform 1 from public.projects where company_id=target_company_id and id=pid and status='ACTIVE' for share;if not found then raise exception 'Active Company Project required' using errcode='42501';end if;
 end loop;
 select * into r from public.historical_source_records where company_id=target_company_id and id=target_source_id for update;
 if r.updated_at is distinct from expected_updated_at or r.expense_allocation_id is distinct from expected_allocation_id then raise exception 'Source changed' using errcode='40001';end if;
 if r.expense_id is not null or r.payroll_entitlement_id is not null or r.review_status='CANCELLED' or r.record_type<>'GENERAL' or coalesce(r.outflow_minor,0)<=0 or coalesce(r.completion->>'nature',r.classification->>'nature','')<>'EXPENSE' or exists(select 1 from private.financial_command_requests q where q.company_id=target_company_id and q.idempotency_key=r.id and q.command_type='POST_EXPENSE') then raise exception 'Only unposted Expense evidence may be allocated' using errcode='23514';end if;
 d:=coalesce(nullif(r.completion->>'date','')::date,r.source_date);perform private.check_source_allocation_period(target_company_id,d);
 perform 1 from public.treasury_accounts where company_id=target_company_id and id=r.cash_treasury_id and type='CASH' and project_id is null and status='ACTIVE' for share;
 if not found then raise exception 'Confirmed unscoped cash Treasury required' using errcode='23514';end if;
 -- Clear whole-document assignment; the new immutable plan now controls recognition.
 r.allocation_scope:=null;r.assigned_project_id:=null;
 insert into public.source_expense_allocation_events(company_id,source_id,previous_event_id,request_id,actor_id,source_amount_minor,source_date,source_snapshot,plan,reason,input_hash)
 values(target_company_id,r.id,r.expense_allocation_id,request_id,actor,amount,d,private.source_allocation_snapshot(r),normalized,why,digest) returning * into a;
 update public.historical_source_records set expense_allocation_id=a.id,allocation_scope=null,assigned_project_id=null,review_status='PENDING',updated_by=actor,updated_at=a.created_at where id=r.id;
 return (to_jsonb(a)-'input_hash'-'source_snapshot')||jsonb_build_object('source_amount_minor',a.source_amount_minor::text,'source_updated_at',a.created_at);
end;$$;
revoke all on function public.confirm_source_expense_allocation(uuid,uuid,timestamptz,uuid,uuid,jsonb,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.confirm_source_expense_allocation(uuid,uuid,timestamptz,uuid,uuid,jsonb,text,boolean) to authenticated;

-- Same ordering as source assignment: Company -> Projects -> source. Recheck pointer after locks.
create function private.prepare_source_allocation(cid uuid,sid uuid) returns public.source_expense_allocation_events language plpgsql security definer set search_path='' as $$
declare r public.historical_source_records;a public.source_expense_allocation_events;initial uuid;pid uuid;begin
 perform 1 from public.companies where id=cid for share;
 select * into r from public.historical_source_records where company_id=cid and id=sid;if not found then return null;end if;
 initial:=r.expense_allocation_id;
 if initial is not null then
  perform private.correction_authority(cid);select * into a from public.source_expense_allocation_events where company_id=cid and id=initial;
  for pid in select (v->>'project_id')::uuid from jsonb_array_elements(a.plan->'destinations') v where v->>'project_id' is not null order by 1 loop
   perform 1 from public.projects where company_id=cid and id=pid for share;
  end loop;
 end if;
 select * into r from public.historical_source_records where company_id=cid and id=sid for update;
 if r.expense_allocation_id is distinct from initial then raise exception 'Allocation changed; refresh' using errcode='40001';end if;
 if initial is null then return null;end if;
 if r.review_status<>'REVIEWED' or r.record_type<>'GENERAL' or r.payroll_entitlement_id is not null or a.source_snapshot is distinct from private.source_allocation_snapshot(r) then raise exception 'Fresh source review and reconfirmed allocation required' using errcode='23514';end if;
 if r.expense_id is null then
  perform private.check_source_allocation_period(cid,a.source_date);
  if exists(select 1 from jsonb_array_elements(a.plan->'destinations') v left join public.projects p on p.company_id=cid and p.id=(v->>'project_id')::uuid where v->>'project_id' is not null and (p.id is null or p.status<>'ACTIVE')) then raise exception 'Active allocation Projects required' using errcode='23514';end if;
 end if;return a;
end;$$;
revoke all on function private.prepare_source_allocation(uuid,uuid) from public,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION private.post_expense(target_company_id uuid, target_expense_date date, target_project_id uuid, target_expense_category_id uuid, target_description text, target_net_amount_minor bigint, target_vat_mode expense_vat_mode, target_manual_vat_amount_minor bigint, target_funding_mode expense_funding_mode, target_treasury_account_id uuid, target_paid_by_party_id uuid, target_supplier_id uuid, target_payment_method payment_method, target_has_tax_invoice boolean, target_invoice_number text, target_notes text, target_idempotency_key uuid)
 RETURNS TABLE(expense_id uuid, expense_reference text, journal_entry_id uuid, replayed boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  actor_id uuid := auth.uid();
  normalized_description text := btrim(target_description);
  normalized_invoice_number text := nullif(btrim(target_invoice_number), '');
  normalized_notes text := nullif(btrim(target_notes), '');
  request_hash text;
  request_row private.financial_command_requests;
  project_status public.project_status;
  category_status public.account_status;
  treasury_row public.treasury_accounts;
  funding_party public.parties;
  supplier_row public.parties;
  cost_account_id uuid;
  input_vat_account_id uuid;
  credit_account_id uuid;
  calculated_vat_minor bigint;
  calculated_gross numeric;
  new_expense_id uuid := gen_random_uuid();
  new_expense_reference text;
  new_journal_id uuid;
  journal_lines jsonb;
  source_plan public.source_expense_allocation_events;
  allocation_line jsonb; allocation_account uuid;
begin
  if actor_id is null or not public.has_permission(target_company_id, 'accounting.post') then
    raise exception 'Not authorized to post expenses' using errcode = '42501';
  end if;
  source_plan:=private.prepare_source_allocation(target_company_id,target_idempotency_key);
  if source_plan.id is not null then
    if target_project_id is not null or target_expense_date is distinct from source_plan.source_date or target_net_amount_minor is distinct from source_plan.source_amount_minor
    or target_vat_mode is distinct from 'ZERO'::public.expense_vat_mode or coalesce(target_manual_vat_amount_minor,0)<>0 or target_funding_mode is distinct from 'TREASURY'::public.expense_funding_mode
    or target_payment_method is distinct from 'CASH'::public.payment_method or target_paid_by_party_id is not null or target_supplier_id is not null then raise exception 'Confirmed source allocation economics mismatch' using errcode='23514';end if;
    perform 1 from public.historical_source_records r join public.treasury_accounts t on t.company_id=r.company_id and t.id=r.cash_treasury_id where r.company_id=target_company_id and r.id=target_idempotency_key and r.cash_treasury_id=target_treasury_account_id and t.type='CASH' and t.project_id is null and btrim(coalesce(r.completion->>'description',r.description))=normalized_description;
    if not found then raise exception 'Confirmed source allocation evidence mismatch' using errcode='23514';end if;
    perform 1 from public.accounts where company_id=target_company_id and system_key in ('PROJECT_COST','COMPANY_EXPENSE') order by id for share;
  end if;
  if target_company_id is null or target_expense_category_id is null or target_vat_mode is null
     or target_funding_mode is null or target_payment_method is null
     or target_has_tax_invoice is null or target_idempotency_key is null then
    raise exception 'Required Expense command input is missing' using errcode = '22023';
  end if;
  if target_expense_date is null or normalized_description is null or length(normalized_description) not between 1 and 1000 then
    raise exception 'Expense date and description are required' using errcode = '22023';
  end if;
  if target_net_amount_minor is null or target_net_amount_minor not between 1 and 9000000000000000 then
    raise exception 'Expense net amount is invalid' using errcode = '22023';
  end if;

  if target_project_id is not null then
    select p.status into project_status from public.projects p
    where p.company_id = target_company_id and p.id = target_project_id;
    if project_status is null then raise exception 'Project does not belong to company' using errcode = '23503'; end if;
    if project_status = 'CLOSED' then raise exception 'Closed project cannot receive a new expense' using errcode = '23514'; end if;
  end if;
  select c.status into category_status from public.expense_categories c
  where c.company_id = target_company_id and c.id = target_expense_category_id;
  if category_status is null then raise exception 'Expense category does not belong to company' using errcode = '23503'; end if;
  if category_status <> 'ACTIVE' then raise exception 'Expense category is inactive' using errcode = '23514'; end if;

  if target_vat_mode = 'ZERO' then
    if coalesce(target_manual_vat_amount_minor, 0) <> 0 then raise exception 'ZERO VAT cannot include VAT amount' using errcode = '22023'; end if;
    calculated_vat_minor := 0;
  elsif target_vat_mode = 'AUTO_5' then
    if target_manual_vat_amount_minor is not null then raise exception 'AUTO_5 does not accept manual VAT' using errcode = '22023'; end if;
    calculated_vat_minor := round(target_net_amount_minor::numeric * 5 / 100)::bigint;
  else
    if target_manual_vat_amount_minor is null or target_manual_vat_amount_minor <= 0
       or target_manual_vat_amount_minor > target_net_amount_minor then
      raise exception 'Manual VAT amount is invalid' using errcode = '22023';
    end if;
    calculated_vat_minor := target_manual_vat_amount_minor;
  end if;
  if calculated_vat_minor > 0 and (not target_has_tax_invoice or normalized_invoice_number is null) then
    raise exception 'Recoverable Input VAT requires a valid tax invoice reference' using errcode = '23514';
  end if;
  if not target_has_tax_invoice and normalized_invoice_number is not null then
    raise exception 'Invoice number requires invoice confirmation' using errcode = '23514';
  end if;
  calculated_gross := target_net_amount_minor::numeric + calculated_vat_minor::numeric;
  if calculated_gross > 9000000000000000 then raise exception 'Expense gross amount is too large' using errcode = '22003'; end if;

  if target_supplier_id is not null then
    select p.* into supplier_row from public.parties p
    where p.company_id = target_company_id and p.id = target_supplier_id;
    if supplier_row.id is null or supplier_row.type <> 'SUPPLIER' then raise exception 'Supplier is invalid' using errcode = '23514'; end if;
    if supplier_row.status <> 'ACTIVE' then raise exception 'Supplier is inactive' using errcode = '23514'; end if;
  end if;

  if target_funding_mode = 'TREASURY' then
    if target_treasury_account_id is null or target_paid_by_party_id is not null then raise exception 'TREASURY funding shape is invalid' using errcode = '23514'; end if;
    select t.* into treasury_row from public.treasury_accounts t
    where t.company_id = target_company_id and t.id = target_treasury_account_id;
    if treasury_row.id is null then raise exception 'Treasury does not belong to company' using errcode = '23503'; end if;
    if treasury_row.status <> 'ACTIVE' then raise exception 'Treasury is inactive' using errcode = '23514'; end if;
    if treasury_row.project_id is not null and treasury_row.project_id is distinct from target_project_id then
      raise exception 'Project treasury can be used only for its project' using errcode = '23514';
    end if;
    credit_account_id := treasury_row.gl_account_id;
  elsif target_funding_mode in ('CUSTODIAN', 'OWNER') then
    if target_treasury_account_id is not null or target_paid_by_party_id is null then raise exception 'Party funding shape is invalid' using errcode = '23514'; end if;
    select p.* into funding_party from public.parties p
    where p.company_id = target_company_id and p.id = target_paid_by_party_id;
    if funding_party.id is null or not (funding_party.type::text = target_funding_mode::text or (target_funding_mode = 'CUSTODIAN' and private.party_has_person_role(target_company_id,funding_party.id,'CUSTODIAN'))) then
      raise exception 'Funding party has the wrong type' using errcode = '23514';
    end if;
    if funding_party.status <> 'ACTIVE' then raise exception 'Funding party is inactive' using errcode = '23514'; end if;
  else
    if target_treasury_account_id is not null or target_paid_by_party_id is not null
       or target_supplier_id is null then raise exception 'SUPPLIER_CREDIT funding shape is invalid' using errcode = '23514'; end if;
  end if;

  select a.id into cost_account_id from public.accounts a
  where a.company_id = target_company_id
    and a.system_key = case when target_project_id is null then 'COMPANY_EXPENSE'::public.system_account_key
                          else 'PROJECT_COST'::public.system_account_key end
    and a.status = 'ACTIVE';
  if cost_account_id is null then raise exception 'Required cost system account is unavailable' using errcode = '23514'; end if;
  if calculated_vat_minor > 0 then
    select a.id into input_vat_account_id from public.accounts a
    where a.company_id = target_company_id and a.system_key = 'INPUT_VAT' and a.status = 'ACTIVE';
    if input_vat_account_id is null then raise exception 'Input VAT system account is unavailable' using errcode = '23514'; end if;
  end if;
  if target_funding_mode = 'CUSTODIAN' then
    select a.id into credit_account_id from public.accounts a
    where a.company_id = target_company_id and a.system_key = 'CUSTODY_ADVANCE' and a.status = 'ACTIVE';
  elsif target_funding_mode = 'OWNER' then
    select a.id into credit_account_id from public.accounts a
    where a.company_id = target_company_id and a.system_key = 'OWNER_CURRENT' and a.status = 'ACTIVE';
  elsif target_funding_mode = 'SUPPLIER_CREDIT' then
    select a.id into credit_account_id from public.accounts a
    where a.company_id = target_company_id and a.system_key = 'SUPPLIER_PAYABLE' and a.status = 'ACTIVE';
  end if;
  if credit_account_id is null then raise exception 'Required funding system account is unavailable' using errcode = '23514'; end if;

  request_hash := encode(extensions.digest(convert_to((jsonb_build_object(
    'company_id', target_company_id, 'expense_date', target_expense_date, 'project_id', target_project_id,
    'category_id', target_expense_category_id, 'description', normalized_description,
    'net_minor', target_net_amount_minor, 'vat_mode', target_vat_mode, 'manual_vat_minor', target_manual_vat_amount_minor,
    'funding_mode', target_funding_mode, 'treasury_id', target_treasury_account_id,
    'paid_by_party_id', target_paid_by_party_id, 'supplier_id', target_supplier_id,
    'payment_method', target_payment_method, 'has_tax_invoice', target_has_tax_invoice,
    'invoice_number', normalized_invoice_number, 'notes', normalized_notes
  ) || case when source_plan.id is null then '{}'::jsonb else jsonb_build_object('source_allocation_id',source_plan.id,'allocation_plan',source_plan.plan) end)::text, 'UTF8'), 'sha256'), 'hex');
  request_row := private.reserve_financial_command(
    target_company_id, 'POST_EXPENSE', target_idempotency_key, request_hash, actor_id
  );
  if request_row.status = 'COMPLETED' then
    return query select e.id, e.expense_reference, e.posted_journal_entry_id, true
    from public.expenses e where e.company_id = target_company_id
      and e.posted_journal_entry_id = request_row.resulting_journal_entry_id;
    return;
  end if;

  new_expense_reference := private.allocate_reference(
    target_company_id, 'EXP', extract(year from target_expense_date)::integer
  );
  insert into public.expenses (
    id, company_id, expense_reference, expense_date, project_id, expense_category_id,
    supplier_id, description, net_amount_minor, vat_mode, vat_amount_minor, gross_amount_minor,
    funding_mode, treasury_account_id, paid_by_party_id, payment_method, has_tax_invoice,
    invoice_number, notes, created_by, updated_by,allocation_event_id,allocation_plan
  ) values (
    new_expense_id, target_company_id, new_expense_reference, target_expense_date, target_project_id,
    target_expense_category_id, target_supplier_id, normalized_description, target_net_amount_minor,
    target_vat_mode, calculated_vat_minor, calculated_gross::bigint, target_funding_mode,
    target_treasury_account_id, target_paid_by_party_id, target_payment_method,
    target_has_tax_invoice, normalized_invoice_number, normalized_notes, actor_id, actor_id,source_plan.id,source_plan.plan
  );

  journal_lines := jsonb_build_array(jsonb_build_object(
    'account_id', cost_account_id, 'debit_minor', target_net_amount_minor, 'credit_minor', 0,
    'project_id', target_project_id
  ));
  if source_plan.id is not null then
    journal_lines:='[]';
    for allocation_line in select value from jsonb_array_elements(source_plan.plan->'destinations') loop
      select id into allocation_account from public.accounts where company_id=target_company_id and status='ACTIVE' and account_type='EXPENSE' and system_key=case when allocation_line->>'project_id' is null then 'COMPANY_EXPENSE'::public.system_account_key else 'PROJECT_COST'::public.system_account_key end;
      if allocation_account is null then raise exception 'Allocation cost mapping unavailable' using errcode='23514';end if;
      journal_lines:=journal_lines||jsonb_build_array(jsonb_build_object('account_id',allocation_account,'debit_minor',allocation_line->>'amount_minor','credit_minor','0','project_id',allocation_line->>'project_id'));
    end loop;
  end if;
  if calculated_vat_minor > 0 then
    journal_lines := journal_lines || jsonb_build_array(jsonb_build_object(
      'account_id', input_vat_account_id, 'debit_minor', calculated_vat_minor, 'credit_minor', 0,
      'project_id', target_project_id
    ));
  end if;
  journal_lines := journal_lines || jsonb_build_array(jsonb_build_object(
    'account_id', credit_account_id, 'debit_minor', 0, 'credit_minor', calculated_gross::bigint,
    'project_id', target_project_id,
    'party_id', case when target_funding_mode = 'SUPPLIER_CREDIT' then target_supplier_id else target_paid_by_party_id end,
    'treasury_account_id', case when target_funding_mode = 'TREASURY' then target_treasury_account_id else null end
  ));
  new_journal_id := private.create_journal(
    target_company_id, target_expense_date, normalized_description, 'EXPENSE', new_expense_id,
    'ORIGINAL', journal_lines, actor_id, null
  );
  update public.expenses set status = 'POSTED', posted_journal_entry_id = new_journal_id,
    posted_at = now(), posted_by = actor_id, updated_by = actor_id
  where id = new_expense_id;
  perform private.complete_financial_command(request_row.id, new_journal_id);
  return query select new_expense_id, new_expense_reference, new_journal_id, false;
end;
$function$;

create or replace function public.post_historical_expense(target_company_id uuid,target_source_id uuid,business_input jsonb)
returns table(expense_id uuid,expense_reference text,journal_entry_id uuid,replayed boolean)
language plpgsql security definer set search_path='' as $$
declare r public.historical_source_records; result record; v jsonb:=business_input; gross bigint; vat bigint;
begin
 if auth.uid() is null or not public.has_permission(target_company_id,'accounting.post') then raise exception 'Denied' using errcode='42501';end if;
 perform private.prepare_source_allocation(target_company_id,target_source_id);
 select * into r from public.historical_source_records where company_id=target_company_id and id=target_source_id for update;
 if not found or r.record_type<>'GENERAL' or r.review_status<>'REVIEWED' or r.cash_treasury_id is null or coalesce(r.outflow_minor,0)<=0
 or coalesce(r.completion->>'nature',r.classification->>'nature')<>'EXPENSE' then raise exception 'Complete recognized expense source first' using errcode='23514';end if;
 if r.expense_allocation_id is distinct from (v->>'target_source_allocation_id')::uuid then raise exception 'Allocation changed; refresh source review' using errcode='40001';end if;
 -- An explicit source assignment must survive the canonical posting boundary.
 if r.allocation_scope is not null and (v->>'target_project_id')::uuid is distinct from r.assigned_project_id then
  raise exception 'Posting Project differs from reviewed assignment' using errcode='23514';end if;
 if (v->>'target_expense_date')::date is distinct from coalesce(nullif(r.completion->>'date','')::date,r.source_date)
 or btrim(v->>'target_description') is distinct from btrim(coalesce(r.completion->>'description',r.description)) then
  raise exception 'Save confirmed source date and description before posting' using errcode='23514';end if;
 if (v->>'target_treasury_account_id')::uuid is distinct from r.cash_treasury_id or v->>'target_funding_mode'<>'TREASURY' or v->>'target_payment_method'<>'CASH' then raise exception 'Confirmed cash source mismatch' using errcode='23514';end if;
 vat:=case v->>'target_vat_mode' when 'ZERO' then 0 when 'AUTO_5' then round((v->>'target_net_amount_minor')::numeric*5/100)::bigint else (v->>'target_manual_vat_amount_minor')::bigint end;
 gross:=(v->>'target_net_amount_minor')::bigint+vat;
 if gross is distinct from coalesce((r.completion->>'amount_minor')::bigint,r.outflow_minor) then raise exception 'Gross must match completed source outflow' using errcode='23514';end if;
 select * into result from public.post_expense(target_company_id,(v->>'target_expense_date')::date,(v->>'target_project_id')::uuid,(v->>'target_expense_category_id')::uuid,v->>'target_description',(v->>'target_net_amount_minor')::bigint,(v->>'target_vat_mode')::public.expense_vat_mode,(v->>'target_manual_vat_amount_minor')::bigint,'TREASURY',r.cash_treasury_id,null,(v->>'target_supplier_id')::uuid,'CASH',(v->>'target_has_tax_invoice')::boolean,v->>'target_invoice_number',v->>'target_notes',r.id);
 if r.expense_id is not null and r.expense_id<>result.expense_id then raise exception 'Source already linked';end if;
 if r.expense_id is null then update public.historical_source_records set expense_id=result.expense_id,updated_by=auth.uid(),updated_at=clock_timestamp() where id=r.id;end if;
 return query select result.expense_id,result.expense_reference,result.journal_entry_id,result.replayed;
end $$;

-- Whole-source reassignment cannot silently supersede a confirmed split.
create function private.guard_source_allocation_mapping() returns trigger language plpgsql set search_path='' as $$
begin if old.expense_allocation_id is not null and new.expense_allocation_id is not distinct from old.expense_allocation_id and (new.allocation_scope is distinct from old.allocation_scope or new.assigned_project_id is distinct from old.assigned_project_id) then raise exception 'Reconfirm the shared allocation instead of whole-source reassignment' using errcode='23514';end if;return new;end;$$;
revoke all on function private.guard_source_allocation_mapping() from public,anon,authenticated,service_role;
create trigger source_allocation_mapping_guard before update on public.historical_source_records for each row execute function private.guard_source_allocation_mapping();
