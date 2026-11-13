-- ACW-01 / 94. Additive Supplier AP integration. No seed, backfill or hosted data correction.
-- Existing Expense / Inventory / Supplier Payment documents remain the recognition and settlement authorities.
alter table public.supplier_payments alter column treasury_account_id drop not null;
alter table public.supplier_payments add column custodian_id uuid, add column custody_account_id uuid,
 add foreign key(company_id,custodian_id) references public.parties(company_id,id) on delete restrict,
 add foreign key(company_id,custody_account_id) references public.accounts(company_id,id) on delete restrict,
 add constraint supplier_payment_funding_shape check((treasury_account_id is not null and custodian_id is null and custody_account_id is null)or(treasury_account_id is null and custodian_id is not null and custody_account_id is not null));
create trigger supplier_payment_funding_immutable before update on public.supplier_payments for each row execute function private.guard_settlement_funding_history();

create table public.supplier_advance_configuration(
 company_id uuid primary key references public.companies(id) on delete restrict,account_id uuid not null,
 evidence text not null check(length(btrim(evidence)) between 1 and 1000),created_by uuid not null references auth.users(id),created_at timestamptz not null default now(),
 foreign key(company_id,account_id) references public.accounts(company_id,id) on delete restrict);
create table public.supplier_invoice_terms(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),expense_id uuid not null,supplier_id uuid not null,
 invoice_number text not null check(length(btrim(invoice_number)) between 1 and 100),due_date date not null,due_date_confirmed boolean not null,
 created_by uuid not null references auth.users(id),created_at timestamptz not null default now(),
 unique(company_id,expense_id),foreign key(company_id,expense_id) references public.expenses(company_id,id) on delete restrict,
 foreign key(company_id,supplier_id) references public.parties(company_id,id) on delete restrict);
create index supplier_invoice_terms_number on public.supplier_invoice_terms(company_id,supplier_id,lower(btrim(invoice_number)));
create table public.supplier_ap_documents(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),kind text not null check(kind in('ADVANCE','CREDIT_NOTE','ADVANCE_ALLOCATION','CREDIT_ALLOCATION')),
 reference text not null,external_reference text,supplier_id uuid not null,project_id uuid,expense_id uuid,advance_id uuid,credit_note_id uuid,custodian_id uuid,treasury_account_id uuid,posting_date date not null,
 net_minor bigint not null check(net_minor between 1 and 9000000000000000),vat_minor bigint not null check(vat_minor between 0 and 9000000000000000),
 amount_minor bigint not null check(amount_minor=net_minor+vat_minor and amount_minor between 1 and 9000000000000000),
 evidence text not null check(length(btrim(evidence)) between 1 and 2000),status public.expense_status not null default 'POSTED' check(status in('POSTED','REVERSED')),
 posted_journal_entry_id uuid not null,reversal_journal_entry_id uuid,created_by uuid not null references auth.users(id),created_at timestamptz not null default now(),
 unique(company_id,id),unique(company_id,reference),unique(posted_journal_entry_id),unique(reversal_journal_entry_id),
 foreign key(company_id,supplier_id) references public.parties(company_id,id),foreign key(company_id,project_id) references public.projects(company_id,id),
 foreign key(company_id,custodian_id) references public.parties(company_id,id),foreign key(company_id,treasury_account_id) references public.treasury_accounts(company_id,id),
 foreign key(company_id,expense_id) references public.expenses(company_id,id),foreign key(company_id,advance_id) references public.supplier_ap_documents(company_id,id),foreign key(company_id,credit_note_id) references public.supplier_ap_documents(company_id,id),
 foreign key(company_id,posted_journal_entry_id) references public.journal_entries(company_id,id),foreign key(company_id,reversal_journal_entry_id) references public.journal_entries(company_id,id),
 check((kind='ADVANCE'and((custodian_id is null)<>(treasury_account_id is null)))or(kind<>'ADVANCE'and custodian_id is null and treasury_account_id is null)),
 check((kind='ADVANCE'and expense_id is null and advance_id is null and credit_note_id is null and vat_minor=0)or(kind='CREDIT_NOTE'and expense_id is not null and advance_id is null and credit_note_id is null)or(kind='ADVANCE_ALLOCATION'and expense_id is not null and advance_id is not null and credit_note_id is null and vat_minor=0)or(kind='CREDIT_ALLOCATION'and expense_id is not null and advance_id is null and credit_note_id is not null and vat_minor=0)),
 check((status='POSTED'and reversal_journal_entry_id is null)or(status='REVERSED'and reversal_journal_entry_id is not null)));
create unique index supplier_credit_note_number on public.supplier_ap_documents(company_id,supplier_id,lower(btrim(external_reference)))where kind='CREDIT_NOTE'and status='POSTED';
create unique index supplier_advance_payment_reference on public.supplier_ap_documents(company_id,supplier_id,lower(btrim(external_reference)))where kind='ADVANCE'and status='POSTED';
create index supplier_ap_invoice on public.supplier_ap_documents(company_id,expense_id);
create index supplier_ap_advance on public.supplier_ap_documents(company_id,advance_id);
create function private.protect_supplier_ap_history()returns trigger language plpgsql set search_path=''as $$begin
 if tg_op='DELETE' then raise exception 'Supplier AP history is immutable'using errcode='23514';end if;
 if tg_table_name<>'supplier_ap_documents'then raise exception 'Supplier setup/invoice terms immutable'using errcode='23514';end if;
 if(to_jsonb(new)-array['status','reversal_journal_entry_id'])is distinct from(to_jsonb(old)-array['status','reversal_journal_entry_id'])or old.status<>'POSTED'or new.status<>'REVERSED'or new.reversal_journal_entry_id is null then raise exception 'Supplier AP history is immutable; use controlled reversal'using errcode='23514';end if;return new;end$$;
revoke all on function private.protect_supplier_ap_history()from public,anon,authenticated,service_role;
create trigger supplier_ap_immutable before update or delete on public.supplier_ap_documents for each row execute function private.protect_supplier_ap_history();
create trigger supplier_terms_immutable before update or delete on public.supplier_invoice_terms for each row execute function private.protect_supplier_ap_history();
create trigger supplier_configuration_immutable before update or delete on public.supplier_advance_configuration for each row execute function private.protect_supplier_ap_history();
alter table public.supplier_ap_documents enable row level security;alter table public.supplier_ap_documents force row level security;
alter table public.supplier_invoice_terms enable row level security;alter table public.supplier_invoice_terms force row level security;
alter table public.supplier_advance_configuration enable row level security;alter table public.supplier_advance_configuration force row level security;
create policy supplier_ap_read on public.supplier_ap_documents for select to authenticated using(public.has_company_role(company_id,'ACCOUNTING_ADMIN')or public.has_company_role(company_id,'ACCOUNTANT')or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create policy supplier_terms_read on public.supplier_invoice_terms for select to authenticated using(public.has_company_role(company_id,'ACCOUNTING_ADMIN')or public.has_company_role(company_id,'ACCOUNTANT')or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create policy supplier_advance_setup_read on public.supplier_advance_configuration for select to authenticated using(public.has_company_role(company_id,'ACCOUNTING_ADMIN')or public.has_company_role(company_id,'ACCOUNTANT')or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
revoke all on public.supplier_ap_documents,public.supplier_invoice_terms,public.supplier_advance_configuration from public,anon,authenticated,service_role;
grant select on public.supplier_ap_documents,public.supplier_invoice_terms,public.supplier_advance_configuration to authenticated,service_role;

create function private.supplier_ap_used(cid uuid,eid uuid,cutoff date default 'infinity')returns numeric language sql stable set search_path=''as $$
 select coalesce((select sum(a.allocated_amount_minor::numeric)from public.supplier_payment_allocations a join public.supplier_payments p on p.company_id=a.company_id and p.id=a.supplier_payment_id left join public.journal_entries j on j.company_id=p.company_id and j.id=p.reversal_journal_entry_id where a.company_id=cid and a.expense_id=eid and p.payment_date<=cutoff and(p.status='POSTED'or p.status='REVERSED'and j.posting_date>cutoff)),0)+
 coalesce((select sum(d.amount_minor::numeric)from public.supplier_ap_documents d left join public.journal_entries j on j.company_id=d.company_id and j.id=d.reversal_journal_entry_id where d.company_id=cid and d.expense_id=eid and d.posting_date<=cutoff and(d.status='POSTED'or d.status='REVERSED'and j.posting_date>cutoff)),0)+
 coalesce((select e.gross_amount_minor::numeric from public.expenses e left join public.journal_entries r on r.company_id=e.company_id and r.id=e.reversal_journal_entry_id where e.company_id=cid and e.id=eid and e.expense_date<=cutoff and e.funding_mode in('TREASURY','CUSTODIAN')and(e.status='POSTED'or e.status='REVERSED'and r.posting_date>cutoff)),0)-
 coalesce((select sum(d.amount_minor::numeric)from public.supplier_ap_documents d join public.supplier_ap_documents c on c.company_id=d.company_id and c.id=d.credit_note_id left join public.journal_entries r on r.company_id=d.company_id and r.id=d.reversal_journal_entry_id where d.company_id=cid and c.expense_id=eid and d.kind='CREDIT_ALLOCATION'and d.posting_date<=cutoff and(d.status='POSTED'or d.status='REVERSED'and r.posting_date>cutoff)),0)$$;
revoke all on function private.supplier_ap_used(uuid,uuid,date)from public,anon,authenticated,service_role;
create or replace function private.validate_supplier_payment_allocation()returns trigger language plpgsql security definer set search_path=''as $$
declare p public.supplier_payments;e public.expenses;begin
 if tg_op<>'INSERT'then raise exception 'Payment allocations immutable'using errcode='23514';end if;
 select *into p from public.supplier_payments where company_id=new.company_id and id=new.supplier_payment_id for share;
 if p.id is null or p.status<>'DRAFT'then raise exception 'Atomic Supplier Payment required'using errcode='23514';end if;
 select *into e from public.expenses where company_id=new.company_id and id=new.expense_id for update;
 if e.id is null or e.status<>'POSTED'or e.funding_mode<>'SUPPLIER_CREDIT'or e.supplier_id<>p.supplier_id or p.payment_date<e.expense_date then raise exception 'Live same-Supplier payable and payment date on/after invoice required; earlier payments are advances'using errcode='23514';end if;
 if private.supplier_ap_used(new.company_id,e.id)+new.allocated_amount_minor>e.gross_amount_minor then raise exception 'Payment exceeds remaining payable after payments, credit notes and advances'using errcode='23514';end if;return new;end$$;
create function private.protect_supplier_adjusted_invoice()returns trigger language plpgsql security definer set search_path=''as $$begin
 if old.status='POSTED'and new.status='REVERSED'and exists(select 1 from public.supplier_ap_documents where company_id=old.company_id and expense_id=old.id and status='POSTED')then raise exception 'Reverse dependent Supplier credit notes/advance allocations before reversing invoice'using errcode='23514';end if;return new;end$$;
revoke all on function private.protect_supplier_adjusted_invoice()from public,anon,authenticated,service_role;
create trigger supplier_invoice_adjustment_dependencies before update on public.expenses for each row execute function private.protect_supplier_adjusted_invoice();
create function private.guard_supplier_invoice_number()returns trigger language plpgsql security definer set search_path=''as $$begin
 if new.status='POSTED'and new.supplier_id is not null and nullif(btrim(new.invoice_number),'')is not null then
 perform pg_advisory_xact_lock(hashtextextended('supplier-invoice:'||new.company_id::text||new.supplier_id::text||lower(btrim(new.invoice_number)),0));
 if exists(select 1 from public.expenses e where e.company_id=new.company_id and e.supplier_id=new.supplier_id and e.id<>new.id and e.status='POSTED'and lower(btrim(e.invoice_number))=lower(btrim(new.invoice_number)))or exists(select 1 from public.supplier_invoice_terms t join public.expenses e on e.company_id=t.company_id and e.id=t.expense_id where t.company_id=new.company_id and t.supplier_id=new.supplier_id and t.expense_id<>new.id and lower(btrim(t.invoice_number))=lower(btrim(new.invoice_number))and e.status='POSTED')then raise exception 'Supplier invoice number already posted'using errcode='23505';end if;end if;return new;end$$;
revoke all on function private.guard_supplier_invoice_number()from public,anon,authenticated,service_role;
create trigger supplier_invoice_number_guard before insert or update on public.expenses for each row execute function private.guard_supplier_invoice_number();
create function private.post_supplier_payment_funded(
  target_company_id uuid,
  target_payment_date date,
  target_supplier_id uuid,
  target_treasury_account_id uuid,
  target_payment_method public.payment_method,
  target_external_reference text,
  target_notes text,
  target_allocations jsonb,
  target_idempotency_key uuid, target_custodian_id uuid
)
returns table (supplier_payment_id uuid, payment_reference text, journal_entry_id uuid, replayed boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  normalized_external_reference text := nullif(btrim(target_external_reference), '');
  normalized_notes text := nullif(btrim(target_notes), '');
  normalized_allocations jsonb;
  allocation_total numeric;
  request_hash text;
  request_row private.financial_command_requests;
  supplier_row public.parties;
  treasury_row public.treasury_accounts;
  payable_account_id uuid;
  allocation_item jsonb;
  expense_row public.expenses;
  new_payment_id uuid := gen_random_uuid();
  new_payment_reference text;
  new_journal_id uuid;
  journal_lines jsonb; funding jsonb;
begin
  if actor_id is null or not public.has_permission(target_company_id, 'accounting.post') then
    raise exception 'Not authorized to post Supplier Payments' using errcode = '42501';
  end if;
  if target_company_id is null or target_payment_date is null or target_supplier_id is null
     or (target_treasury_account_id is null)=(target_custodian_id is null) or target_payment_method is null
     or target_idempotency_key is null then
    raise exception 'Required Supplier Payment input is missing' using errcode = '22023';
  end if;
  if normalized_external_reference is not null and length(normalized_external_reference) > 200 then
    raise exception 'External payment reference is too long' using errcode = '22023';
  end if;
  if normalized_notes is not null and length(normalized_notes) > 2000 then
    raise exception 'Supplier Payment notes are too long' using errcode = '22023';
  end if;
  if target_allocations is null or jsonb_typeof(target_allocations) <> 'array'
     or jsonb_array_length(target_allocations) not between 1 and 999 then
    raise exception 'Supplier Payment requires 1 to 999 allocations' using errcode = '22023';
  end if;
  if exists (select 1 from jsonb_array_elements(target_allocations) x
    where not (x ? 'expense_id') or not (x ? 'amount_minor')) then
    raise exception 'Each allocation requires expense_id and amount_minor' using errcode = '22023';
  end if;
  select jsonb_agg(jsonb_build_object(
      'expense_id', (x ->> 'expense_id')::uuid,
      'amount_minor', (x ->> 'amount_minor')::bigint
    ) order by (x ->> 'expense_id')::uuid),
    sum((x ->> 'amount_minor')::numeric)
  into normalized_allocations, allocation_total
  from jsonb_array_elements(target_allocations) x;
  if allocation_total is null or allocation_total not between 1 and 9000000000000000 then
    raise exception 'Supplier Payment total is invalid' using errcode = '22023';
  end if;
  if exists (
    select 1 from jsonb_array_elements(normalized_allocations) x
    group by (x ->> 'expense_id')::uuid having count(*) > 1
  ) then raise exception 'An Expense may appear only once per Supplier Payment' using errcode = '23505'; end if;
  if exists (select 1 from jsonb_array_elements(normalized_allocations) x
    where (x ->> 'amount_minor')::bigint <= 0) then
    raise exception 'Allocation amounts must be positive' using errcode = '22023';
  end if;

  perform private.operational_finance_actor(target_company_id,'accounting.post');perform private.attendance_company_lock(target_company_id);perform private.serialize_operational_finance(target_company_id,'OPERATIONS');
  select p.* into supplier_row from public.parties p
  where p.company_id = target_company_id and p.id = target_supplier_id and p.type = 'SUPPLIER';
  if not found then raise exception 'Supplier not found in company' using errcode = '23503'; end if;
  -- Inactive is intentionally allowed: this command settles an existing liability.
  if target_custodian_id is null then
  select t.* into treasury_row from public.treasury_accounts t
  join public.accounts a on a.company_id = t.company_id and a.id = t.gl_account_id
  where t.company_id = target_company_id and t.id = target_treasury_account_id
    and t.status = 'ACTIVE' and a.status = 'ACTIVE' and a.account_type = 'ASSET';
  if not found then raise exception 'An active same-company Treasury with an active Asset GL is required' using errcode = '23514'; end if;
  end if;
  select a.id into payable_account_id from public.accounts a
  where a.company_id = target_company_id and a.system_key = 'SUPPLIER_PAYABLE' and a.status = 'ACTIVE';
  if payable_account_id is null then raise exception 'Supplier Payable system account is unavailable' using errcode = '23514'; end if;

  request_hash := encode(extensions.digest(convert_to((jsonb_build_object(
    'company_id', target_company_id, 'payment_date', target_payment_date,
    'supplier_id', target_supplier_id, 'treasury_id', target_treasury_account_id,
    'payment_method', target_payment_method, 'external_reference', normalized_external_reference,
    'notes', normalized_notes, 'allocations', normalized_allocations
  )||case when target_custodian_id is null then '{}'::jsonb else jsonb_build_object('custodian_id',target_custodian_id)end)::text, 'UTF8'), 'sha256'), 'hex');
  request_row := private.reserve_financial_command(
    target_company_id, 'POST_SUPPLIER_PAYMENT', target_idempotency_key, request_hash, actor_id
  );
  if request_row.status = 'COMPLETED' then
    return query select p.id, p.payment_reference, p.posted_journal_entry_id, true
    from public.supplier_payments p where p.company_id = target_company_id
      and p.posted_journal_entry_id = request_row.resulting_journal_entry_id;
    return;
  end if;

  new_payment_reference := private.allocate_reference(
    target_company_id, 'SPAY', extract(year from target_payment_date)::integer
  );
  insert into public.supplier_payments (
    id, company_id, payment_reference, payment_date, supplier_id, treasury_account_id,
    total_amount_minor, payment_method, external_reference, notes, created_by, updated_by,custodian_id,custody_account_id
  ) values (
    new_payment_id, target_company_id, new_payment_reference, target_payment_date,
    target_supplier_id, target_treasury_account_id, allocation_total::bigint,
    target_payment_method, normalized_external_reference, normalized_notes, actor_id, actor_id,target_custodian_id,case when target_custodian_id is not null then(select id from public.accounts where company_id=target_company_id and system_key='CUSTODY_ADVANCE')end
  );

  for allocation_item in
    select x from jsonb_array_elements(normalized_allocations) x order by (x ->> 'expense_id')::uuid
  loop
    select e.* into expense_row from public.expenses e
    where e.company_id = target_company_id and e.id = (allocation_item ->> 'expense_id')::uuid
    for update;
    if not found then raise exception 'Allocated Expense not found in company' using errcode = '23503'; end if;
    insert into public.supplier_payment_allocations (
      company_id, supplier_payment_id, expense_id, allocated_amount_minor, created_by
    ) values (
      target_company_id, new_payment_id, expense_row.id,
      (allocation_item ->> 'amount_minor')::bigint, actor_id
    );
  end loop;

  if treasury_row.project_id is not null and exists (
    select 1 from public.supplier_payment_allocations a
    join public.expenses e on e.id = a.expense_id
    where a.supplier_payment_id = new_payment_id
      and e.project_id is distinct from treasury_row.project_id
  ) then
    raise exception 'Project Treasury may settle only liabilities from its own Project'
      using errcode = '23514';
  end if;

  select jsonb_agg(jsonb_build_object(
    'account_id', payable_account_id,
    'debit_minor', grouped.amount_minor,
    'credit_minor', 0,
    'project_id', grouped.project_id,
    'party_id', target_supplier_id,
    'memo', 'Supplier payable allocation'
  ) order by grouped.project_id nulls first)
  into journal_lines
  from (
    select e.project_id, sum(a.allocated_amount_minor::numeric)::bigint as amount_minor
    from public.supplier_payment_allocations a
    join public.expenses e on e.id = a.expense_id
    where a.supplier_payment_id = new_payment_id
    group by e.project_id
  ) grouped;
  funding:=private.settlement_funding(target_company_id,target_treasury_account_id,target_custodian_id,target_payment_date,allocation_total::bigint,treasury_row.project_id);
  journal_lines:=journal_lines||jsonb_build_array(funding);
  new_journal_id := private.create_journal(
    target_company_id, target_payment_date,
    'Supplier Payment ' || new_payment_reference,
    'SUPPLIER_PAYMENT', new_payment_id, 'ORIGINAL', journal_lines, actor_id, null
  );
  update public.supplier_payments set status = 'POSTED', posted_journal_entry_id = new_journal_id,
    posted_at = now(), posted_by = actor_id, updated_by = actor_id
  where id = new_payment_id;
  perform private.complete_financial_command(request_row.id, new_journal_id);
  return query select new_payment_id, new_payment_reference, new_journal_id, false;
end;
$$;

revoke all on function private.post_supplier_payment_funded(uuid,date,uuid,uuid,public.payment_method,text,text,jsonb,uuid,uuid)from public,anon,authenticated,service_role;
create or replace function private.post_supplier_payment(target_company_id uuid,target_payment_date date,target_supplier_id uuid,target_treasury_account_id uuid,target_payment_method public.payment_method,target_external_reference text,target_notes text,target_allocations jsonb,target_idempotency_key uuid)
returns table(supplier_payment_id uuid,payment_reference text,journal_entry_id uuid,replayed boolean)language sql security definer set search_path=''as $$select *from private.post_supplier_payment_funded(target_company_id,target_payment_date,target_supplier_id,target_treasury_account_id,target_payment_method,target_external_reference,target_notes,target_allocations,target_idempotency_key,null)$$;
create function public.post_supplier_payment(target_company_id uuid,target_payment_date date,target_supplier_id uuid,target_treasury_account_id uuid,target_total_amount_minor bigint,target_payment_method public.payment_method,target_external_reference text,target_notes text,target_allocations jsonb,target_idempotency_key uuid,target_custodian_id uuid)
returns table(supplier_payment_id uuid,payment_reference text,journal_entry_id uuid,replayed boolean)language plpgsql security definer set search_path=''as $$begin
 if target_allocations is null or jsonb_typeof(target_allocations)<>'array'or target_total_amount_minor is null or target_total_amount_minor<1 or(select sum((x->>'amount_minor')::numeric)from jsonb_array_elements(target_allocations)x)is distinct from target_total_amount_minor::numeric then raise exception 'Payment total must equal positive allocations'using errcode='23514';end if;
 return query select *from private.post_supplier_payment_funded(target_company_id,target_payment_date,target_supplier_id,target_treasury_account_id,target_payment_method,target_external_reference,target_notes,target_allocations,target_idempotency_key,target_custodian_id);end$$;
revoke all on function public.post_supplier_payment(uuid,date,uuid,uuid,bigint,public.payment_method,text,text,jsonb,uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.post_supplier_payment(uuid,date,uuid,uuid,bigint,public.payment_method,text,text,jsonb,uuid,uuid)to authenticated;

create function public.configure_supplier_advance_account(cid uuid,account_id uuid,code text,name text,evidence text)returns uuid language plpgsql security definer set search_path=''as $$
#variable_conflict use_variable
declare actor uuid;existing public.supplier_advance_configuration;aid uuid;begin
 actor:=private.operational_finance_actor(cid,'account.manage');if not public.has_company_role(cid,'ACCOUNTING_ADMIN')or coalesce(length(btrim(evidence)),0)not between 1 and 1000 then raise exception 'Accounting Admin and account-mapping evidence required'using errcode='42501';end if;
 perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');select *into existing from public.supplier_advance_configuration c where c.company_id=cid;
 if found then if account_id=existing.account_id or account_id is null and exists(select 1 from public.accounts a where a.company_id=cid and a.id=existing.account_id and a.code=btrim(code)and a.name=btrim(name))then return existing.account_id;end if;raise exception 'Supplier advance mapping already configured; historical mapping cannot be replaced'using errcode='23514';end if;
 aid:=account_id;
 if aid is null then
 if coalesce(length(btrim(code)),0)not between 1 and 50 or coalesce(length(btrim(name)),0)not between 1 and 200 then raise exception 'Unused account code/name required'using errcode='22023';end if;
 insert into public.accounts(company_id,code,name,account_type,requires_party)values(cid,btrim(code),btrim(name),'ASSET',true)returning id into aid;
 end if;
 perform 1 from public.accounts a where a.company_id=cid and a.id=aid and a.status='ACTIVE'and a.account_type='ASSET'and a.requires_party and a.system_key is null and not exists(select 1 from public.journal_lines l where l.company_id=cid and l.account_id=aid)and not exists(select 1 from public.treasury_accounts t where t.company_id=cid and t.gl_account_id=aid)and not exists(select 1 from public.operational_liability_configuration c where c.company_id=cid and c.account_id=aid)and not exists(select 1 from public.hr_payroll_setup_events h where h.company_id=cid and h.advance_account_id=aid)and not exists(select 1 from public.inventory_configuration i where i.company_id=cid and aid in(i.inventory_account_id,i.grni_account_id,i.variance_account_id,i.opening_account_id));
 if not found then raise exception 'Unused same-Company active Party Asset control required; existing balances cannot be remapped'using errcode='23514';end if;
 insert into public.supplier_advance_configuration(company_id,account_id,evidence,created_by,created_at)values(cid,aid,btrim(evidence),actor,now());return aid;end$$;
revoke all on function public.configure_supplier_advance_account(uuid,uuid,text,text,text)from public,anon,authenticated,service_role;
grant execute on function public.configure_supplier_advance_account(uuid,uuid,text,text,text)to authenticated;


create function private.normalize_supplier_ap_input(v jsonb)returns jsonb language plpgsql immutable set search_path=''as $$
declare k text;value jsonb;x text;out jsonb:='{}';begin
 if v is null or jsonb_typeof(v)<>'object'or octet_length(v::text)>16000 then raise exception 'Bounded Supplier business input required'using errcode='22023';end if;
 for k,value in select *from jsonb_each(v)loop
 if jsonb_typeof(value)not in('string','boolean','null')then raise exception 'Business text/boolean values required; money is exact text'using errcode='22023';end if;
 if jsonb_typeof(value)='boolean'and k<>'has_tax_invoice'then raise exception 'Text business fields required'using errcode='22023';end if;
 if jsonb_typeof(value)='string'then x:=nullif(btrim(value#>>'{}'),'');
 if x is not null and k in('net_minor','vat_minor')then if x!~'^[0-9]{1,16}$'then raise exception 'Exact minor units required'using errcode='22023';end if;x:=(x::bigint)::text;end if;
 if x is not null and(k like '%_id'or k='id')then x:=(x::uuid)::text;end if;
 if x is not null and k in('date','due_date')then if x!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'then raise exception 'Unambiguous ISO calendar date required'using errcode='22023';end if;x:=(x::date)::text;end if;
 if x is not null then out:=jsonb_set(out,array[k],to_jsonb(x));end if;
 elsif jsonb_typeof(value)<>'null'then out:=jsonb_set(out,array[k],value);end if;end loop;return out;end$$;
revoke all on function private.normalize_supplier_ap_input(jsonb)from public,anon,authenticated,service_role;
create function private.supplier_adjustment_plan(cid uuid,kind text,v jsonb)returns jsonb language plpgsql security definer set search_path=''as $$
#variable_conflict use_variable
declare actor uuid;d date;sid uuid;pid uuid;n bigint;tax bigint;aid uuid;ap uuid;cost uuid;vat uuid;lines jsonb;ex public.expenses;adv public.supplier_ap_documents;used numeric;prior_net numeric;prior_vat numeric;begin
 actor:=private.operational_finance_actor(cid,'accounting.post');perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');v:=private.normalize_supplier_ap_input(v);
 if v is null or jsonb_typeof(v)<>'object'or octet_length(v::text)>10000 or kind not in('ADVANCE','CREDIT_NOTE','ADVANCE_ALLOCATION','CREDIT_ALLOCATION')then raise exception 'Supported Supplier adjustment required'using errcode='22023';end if;
 if v-array['date','supplier_id','project_id','net_minor','vat_minor','expense_id','advance_id','credit_note_id','treasury_id','custodian_id','external_reference','evidence']<>'{}'::jsonb then raise exception 'Unsupported Supplier adjustment input'using errcode='22023';end if;
 if v->>'net_minor'!~'^[0-9]{1,16}$'or coalesce(v->>'vat_minor','0')!~'^[0-9]{1,16}$'or coalesce(length(btrim(v->>'evidence')),0)not between 1 and 2000 then raise exception 'Exact positive minor units and supporting evidence required'using errcode='22023';end if;
 d:=(v->>'date')::date;n:=(v->>'net_minor')::bigint;tax:=coalesce(v->>'vat_minor','0')::bigint;sid:=(v->>'supplier_id')::uuid;pid:=nullif(v->>'project_id','')::uuid;
 if n is null or n<1 or n::numeric+tax>9000000000000000 then raise exception 'Positive supported amount required'using errcode='23514';end if;perform private.opening_period(cid,d);
 perform 1 from public.parties p where p.company_id=cid and p.id=sid and p.type='SUPPLIER'and(kind<>'ADVANCE'or p.status='ACTIVE')for share;
 if not found then raise exception 'Same-Company Supplier required'using errcode='23514';end if;
 if kind='ADVANCE'then
 if not(private.company_commercial_readiness(cid)->>'ready')::boolean then raise exception 'Commercial readiness required for new advance'using errcode='42501';end if;
 if tax<>0 or nullif(v->>'expense_id','')is not null or nullif(v->>'advance_id','')is not null or coalesce(length(btrim(v->>'external_reference')),0)not between 1 and 200 then raise exception 'Advance payment reference required; no invoice, VAT or cost recognition'using errcode='23514';end if;
 if pid is not null and not exists(select 1 from public.projects where company_id=cid and id=pid and status<>'CLOSED')then raise exception 'Available same-Company Project required for new advance'using errcode='23514';end if;
 select c.account_id into aid from public.supplier_advance_configuration c join public.accounts a on a.company_id=c.company_id and a.id=c.account_id where c.company_id=cid and a.status='ACTIVE'and a.account_type='ASSET'and a.requires_party;
 if aid is null then raise exception 'Configure Supplier advances control account first'using errcode='23514';end if;
 lines:=jsonb_build_array(jsonb_build_object('account_id',aid,'party_id',sid,'project_id',pid,'debit_minor',n::text,'credit_minor','0'),private.settlement_funding(cid,nullif(v->>'treasury_id','')::uuid,nullif(v->>'custodian_id','')::uuid,d,n,pid));
 else
 if nullif(v->>'treasury_id','')is not null or nullif(v->>'custodian_id','')is not null then raise exception 'Credit note/advance allocation creates no new cash movement'using errcode='23514';end if;
 select *into ex from public.expenses where company_id=cid and id=(v->>'expense_id')::uuid for update;
 if ex.id is null or ex.status<>'POSTED'or (ex.funding_mode<>'SUPPLIER_CREDIT'and not(kind='CREDIT_NOTE'and ex.funding_mode in('TREASURY','CUSTODIAN')))or ex.supplier_id<>sid or d<ex.expense_date or pid is distinct from ex.project_id then raise exception 'Live same-Supplier payable, original Project and non-earlier date required'using errcode='23514';end if;
 if kind<>'CREDIT_NOTE'and private.supplier_ap_used(cid,ex.id)+n+tax>ex.gross_amount_minor then raise exception 'Adjustment exceeds unpaid invoice'using errcode='23514';end if;
 select id into ap from public.accounts where company_id=cid and system_key='SUPPLIER_PAYABLE'and status='ACTIVE';if ap is null then raise exception 'Supplier Payable mapping required'using errcode='23514';end if;
 lines:=jsonb_build_array(jsonb_build_object('account_id',ap,'party_id',sid,'project_id',pid,'debit_minor',(n+tax)::text,'credit_minor','0'));
 if kind='CREDIT_ALLOCATION'then
 if tax<>0 then raise exception 'Credit allocation creates no VAT'using errcode='23514';end if;
 select *into adv from public.supplier_ap_documents where company_id=cid and id=(v->>'credit_note_id')::uuid for update;
 if adv.id is null or adv.kind<>'CREDIT_NOTE'or adv.status<>'POSTED'or adv.supplier_id<>sid or adv.expense_id=ex.id or adv.posting_date>d then raise exception 'Available same-Supplier credit note on another invoice required'using errcode='23514';end if;
 select coalesce(sum(amount_minor::numeric),0)into used from public.supplier_ap_documents where company_id=cid and credit_note_id=adv.id and status='POSTED';
 if n>adv.amount_minor-used or n>private.supplier_ap_used(cid,adv.expense_id)-(select gross_amount_minor from public.expenses where company_id=cid and id=adv.expense_id)then raise exception 'Allocation exceeds available Supplier credit balance'using errcode='23514';end if;
 lines:=lines||jsonb_build_array(jsonb_build_object('account_id',ap,'party_id',sid,'project_id',adv.project_id,'debit_minor','0','credit_minor',n::text));
 elsif kind='ADVANCE_ALLOCATION'then
 if tax<>0 then raise exception 'Advance allocation does not recognize VAT'using errcode='23514';end if;
 select *into adv from public.supplier_ap_documents where company_id=cid and id=(v->>'advance_id')::uuid for update;
 if adv.id is null or adv.status<>'POSTED'or adv.kind<>'ADVANCE'or adv.supplier_id<>sid or adv.posting_date>d or adv.project_id is not null and adv.project_id is distinct from pid then raise exception 'Available same-Supplier advance and matching restricted Project required'using errcode='23514';end if;
 select coalesce(sum(amount_minor::numeric),0)into used from public.supplier_ap_documents where company_id=cid and advance_id=adv.id and status='POSTED';if used+n>adv.amount_minor then raise exception 'Allocation exceeds available Supplier advance'using errcode='23514';end if;
 select l.account_id into aid from public.journal_lines l where l.company_id=cid and l.journal_entry_id=adv.posted_journal_entry_id and l.party_id=sid and l.debit_minor=adv.amount_minor and l.credit_minor=0;
 -- Clear the analytic dimension on the original advance; payable keeps invoice dimensions.
 lines:=lines||jsonb_build_array(jsonb_build_object('account_id',aid,'party_id',sid,'project_id',adv.project_id,'debit_minor','0','credit_minor',n::text));
 else
 if coalesce(length(btrim(v->>'external_reference')),0)not between 1 and 200 then raise exception 'Original Supplier credit-note reference required'using errcode='23514';end if;
 if exists(select 1 from public.inventory_events e where e.company_id=cid and e.state='POSTED'and e.snapshot->>'expense_id'=ex.id::text and e.snapshot->>'kind'in('RECEIPT','MATCH','INVOICE')and not exists(select 1 from public.inventory_events r where r.company_id=cid and r.document_id=e.document_id and r.state='REVERSED'))or ex.allocation_plan is not null or exists(select 1 from public.project_cost_corrections where company_id=cid and expense_id=ex.id)then raise exception 'Inventory/shared/corrected cost requires its specialized return or correction workflow; do not credit ordinary Expense'using errcode='23514';end if;
 select coalesce(sum(net_minor::numeric),0),coalesce(sum(vat_minor::numeric),0)into prior_net,prior_vat from public.supplier_ap_documents z where z.company_id=cid and z.expense_id=ex.id and z.kind='CREDIT_NOTE'and z.status='POSTED';
 if prior_net+n>ex.net_amount_minor or prior_vat+tax>ex.vat_amount_minor then raise exception 'Credit exceeds original net/VAT evidence'using errcode='23514';end if;
 if tax>n then raise exception 'Credit VAT exceeds supported net amount'using errcode='23514';end if;
 if ex.vat_mode='AUTO_5'and ex.vat_amount_minor>0 and abs(tax::numeric*ex.net_amount_minor-n::numeric*ex.vat_amount_minor)>ex.net_amount_minor then raise exception 'Credit-note VAT must follow original invoice treatment within one minor-unit rounding'using errcode='23514';end if;
 select l.account_id into cost from public.journal_lines l join public.accounts a on a.company_id=l.company_id and a.id=l.account_id where l.company_id=cid and l.journal_entry_id=ex.posted_journal_entry_id and a.system_key=case when ex.project_id is null then 'COMPANY_EXPENSE'::public.system_account_key else 'PROJECT_COST'::public.system_account_key end and l.debit_minor=ex.net_amount_minor;
 if cost is null then raise exception 'Original canonical cost line required'using errcode='23514';end if;
 lines:=lines||jsonb_build_array(jsonb_build_object('account_id',cost,'project_id',pid,'debit_minor','0','credit_minor',n::text));
 if tax>0 then select l.account_id into vat from public.journal_lines l join public.accounts a on a.company_id=l.company_id and a.id=l.account_id where l.company_id=cid and l.journal_entry_id=ex.posted_journal_entry_id and a.system_key='INPUT_VAT'and l.debit_minor=ex.vat_amount_minor;
 if vat is null then raise exception 'Original recoverable VAT line/evidence required'using errcode='23514';end if;lines:=lines||jsonb_build_array(jsonb_build_object('account_id',vat,'debit_minor','0','credit_minor',tax::text));end if;
 end if;end if;
 return jsonb_build_object('company_id',cid,'kind',kind,'date',d,'supplier_id',sid,'project_id',pid,'net_minor',n::text,'vat_minor',tax::text,'gross_minor',(n+tax)::text,'lines',lines);end$$;
revoke all on function private.supplier_adjustment_plan(uuid,text,jsonb)from public,anon,authenticated,service_role;
create function public.preview_supplier_adjustment(cid uuid,kind text,input jsonb)returns jsonb language sql security definer set search_path=''as $$select private.supplier_adjustment_plan(cid,kind,input)$$;
revoke all on function public.preview_supplier_adjustment(uuid,text,jsonb)from public,anon,authenticated,service_role;
grant execute on function public.preview_supplier_adjustment(uuid,text,jsonb)to authenticated;
create function public.command_supplier_adjustment(cid uuid,request_id uuid,kind text,input jsonb)returns jsonb language plpgsql security definer set search_path=''as $$
#variable_conflict use_variable
declare actor uuid;req private.financial_command_requests;plan jsonb;did uuid:=gen_random_uuid();ref text;j uuid;original public.supplier_ap_documents;begin
 actor:=private.operational_finance_actor(cid,case when kind='REVERSE'then 'accounting.reverse'else 'accounting.post'end);perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 if kind is null or request_id is null or input is null or jsonb_typeof(input)<>'object'or octet_length(input::text)>10000 then raise exception 'Supplier command inputs required'using errcode='22023';end if;
 input:=private.normalize_supplier_ap_input(input);
 req:=private.reserve_financial_command(cid,'SUPPLIER_AP_'||kind,request_id,encode(extensions.digest(jsonb_build_array(actor,cid,kind,input)::text,'sha256'),'hex'),actor);
 if req.status='COMPLETED'then return jsonb_build_object('company_id',cid,'id',(select id from public.supplier_ap_documents where company_id=cid and(posted_journal_entry_id=req.resulting_journal_entry_id or reversal_journal_entry_id=req.resulting_journal_entry_id)),'journal',req.resulting_journal_entry_id,'replayed',true);end if;
 if kind='REVERSE'then
 if not public.has_company_role(cid,'ACCOUNTING_ADMIN')or input-array['id','date','evidence']<>'{}'::jsonb or coalesce(length(btrim(input->>'evidence')),0)not between 1 and 2000 then raise exception 'Accounting Admin and reversal reason required'using errcode='42501';end if;
 select *into original from public.supplier_ap_documents where company_id=cid and id=(input->>'id')::uuid for update;
 if original.id is null or original.status<>'POSTED'then raise exception 'Live posted Supplier document required'using errcode='23514';end if;
 perform private.opening_period(cid,(input->>'date')::date);if(input->>'date')::date<original.posting_date then raise exception 'Reversal cannot precede original'using errcode='23514';end if;
 if original.kind in('ADVANCE','CREDIT_NOTE')and exists(select 1 from public.supplier_ap_documents where company_id=cid and(advance_id=original.id or credit_note_id=original.id)and status='POSTED')then raise exception 'Reverse dependent Supplier allocations first'using errcode='23514';end if;
 j:=private.reverse_journal(original.posted_journal_entry_id,(input->>'date')::date,btrim(input->>'evidence'),actor);update public.supplier_ap_documents set status='REVERSED',reversal_journal_entry_id=j where company_id=cid and id=original.id;did:=original.id;
 else
 plan:=private.supplier_adjustment_plan(cid,kind,input);ref:=private.allocate_reference(cid,'SAP',extract(year from(plan->>'date')::date)::integer);
 j:=private.create_journal(cid,(plan->>'date')::date,ref||' '||btrim(input->>'evidence'),'SUPPLIER_'||kind,did,'ORIGINAL',plan->'lines',actor,null);
 insert into public.supplier_ap_documents(id,company_id,kind,reference,external_reference,supplier_id,project_id,expense_id,advance_id,credit_note_id,posting_date,net_minor,vat_minor,amount_minor,evidence,posted_journal_entry_id,created_by,custodian_id,treasury_account_id)
 values(did,cid,kind,ref,nullif(btrim(input->>'external_reference'),''),(plan->>'supplier_id')::uuid,(plan->>'project_id')::uuid,nullif(input->>'expense_id','')::uuid,nullif(input->>'advance_id','')::uuid,nullif(input->>'credit_note_id','')::uuid,(plan->>'date')::date,(plan->>'net_minor')::bigint,(plan->>'vat_minor')::bigint,(plan->>'gross_minor')::bigint,btrim(input->>'evidence'),j,actor,case when kind='ADVANCE'then nullif(input->>'custodian_id','')::uuid end,case when kind='ADVANCE'then nullif(input->>'treasury_id','')::uuid end);
 end if;perform private.complete_financial_command(req.id,j);return jsonb_build_object('company_id',cid,'id',did,'journal',j,'reference',ref,'replayed',false);end$$;
revoke all on function public.command_supplier_adjustment(uuid,uuid,text,jsonb)from public,anon,authenticated,service_role;
grant execute on function public.command_supplier_adjustment(uuid,uuid,text,jsonb)to authenticated;

create function private.supplier_invoice_plan(cid uuid,v jsonb)returns jsonb language plpgsql security definer set search_path=''as $$
declare actor uuid;summary jsonb;d date;due date;sid uuid;pid uuid;fund text;cost uuid;ap uuid;vat uuid;net bigint;tax bigint;lines jsonb;receipt public.inventory_events;cfg public.inventory_configuration;begin
 actor:=private.operational_finance_actor(cid,'accounting.post');perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 if v is null or jsonb_typeof(v)<>'object'or octet_length(v::text)>16000 or v-array['date','due_date','supplier_id','project_id','category_id','description','net_minor','vat_mode','vat_minor','has_tax_invoice','invoice_number','funding_mode','treasury_id','custodian_id','receipt_id','purchase_kind','notes']<>'{}'::jsonb then raise exception 'Supported invoice business inputs required'using errcode='22023';end if;
 if coalesce(v->>'net_minor','')!~'^[0-9]{1,16}$'or coalesce(v->>'vat_minor','0')!~'^[0-9]{1,16}$'or coalesce(length(btrim(v->>'invoice_number')),0)not between 1 and 100 or coalesce(length(btrim(v->>'description')),0)not between 1 and 1000 or coalesce(length(v->>'notes'),0)>2000 then raise exception 'Supplier invoice number, description and exact amounts required'using errcode='22023';end if;
 if v->>'purchase_kind' is null or v->>'purchase_kind'not in('SERVICE','INVENTORY')or(v->>'purchase_kind'='INVENTORY')is distinct from(nullif(v->>'receipt_id','')is not null)then raise exception 'Choose service/Project cost or an actual Inventory receipt; assets require their existing specialized workflow'using errcode='23514';end if;
 d:=(v->>'date')::date;due:=coalesce(nullif(v->>'due_date','')::date,d);sid:=(v->>'supplier_id')::uuid;pid:=nullif(v->>'project_id','')::uuid;fund:=v->>'funding_mode';perform private.opening_period(cid,d);
 if due<d or fund is null or fund not in('SUPPLIER_CREDIT','TREASURY','CUSTODIAN')then raise exception 'Valid due date and credit or actual payment source required'using errcode='23514';end if;
 if fund='SUPPLIER_CREDIT'and(nullif(v->>'treasury_id','')is not null or nullif(v->>'custodian_id','')is not null)then raise exception 'Credit invoice must not create a cash payment'using errcode='23514';end if;
 perform 1 from public.parties where company_id=cid and id=sid and type='SUPPLIER'and status='ACTIVE'for share;if not found then raise exception 'Active same-Company Supplier required'using errcode='23514';end if;
 if exists(select 1 from public.expenses e where e.company_id=cid and e.supplier_id=sid and e.status='POSTED'and lower(btrim(e.invoice_number))=lower(btrim(v->>'invoice_number')))or exists(select 1 from public.supplier_invoice_terms t join public.expenses e on e.company_id=t.company_id and e.id=t.expense_id where t.company_id=cid and t.supplier_id=sid and lower(btrim(t.invoice_number))=lower(btrim(v->>'invoice_number'))and e.status='POSTED')then raise exception 'Supplier invoice already posted; open the existing invoice'using errcode='23505';end if;
 summary:=private.validate_expense_draft(cid,jsonb_build_object('date',d,'period_month',to_char(d,'YYYY-MM'),'description',btrim(v->>'description'),'nature',case when pid is null then 'OPERATING_EXPENSE'else 'PROJECT_COST'end,'net_aed',((v->>'net_minor')::numeric/100)::numeric(20,2)::text,'vat_aed',(coalesce(v->>'vat_minor','0')::numeric/100)::numeric(20,2)::text,'vat_mode',v->>'vat_mode','funding_mode',fund,'project_id',pid,'category_id',v->>'category_id','supplier_id',sid,'treasury_id',nullif(v->>'treasury_id',''),'paid_by_id',nullif(v->>'custodian_id',''),'has_invoice',coalesce((v->>'has_tax_invoice')::boolean,false),'invoice_number',case when coalesce((v->>'has_tax_invoice')::boolean,false)then btrim(v->>'invoice_number')else ''end,'source_reference','SUPPLIER-INVOICE:'||sid::text||':'||lower(btrim(v->>'invoice_number')),'supporting_reference',v->>'invoice_number','original_cost_not_posted',true));
 net:=(summary->>'net_minor')::bigint;tax:=(summary->>'vat_minor')::bigint;
 select id into cost from public.accounts where company_id=cid and system_key=case when pid is null then 'COMPANY_EXPENSE'::public.system_account_key else 'PROJECT_COST'::public.system_account_key end and status='ACTIVE';
 if nullif(v->>'receipt_id','')is not null then
 receipt:=private.inventory_current(cid,(v->>'receipt_id')::uuid);
 if receipt.id is null or receipt.state<>'POSTED'or receipt.snapshot->>'kind'<>'RECEIPT'or receipt.snapshot->>'recognition'<>'GRNI'or receipt.snapshot->>'supplier_id'<>sid::text or(receipt.snapshot->>'computed' is null)or(receipt.snapshot->'computed'->>'value')::bigint<>net or(receipt.snapshot->>'date')::date>d then raise exception 'Posted same-Supplier GRNI receipt of matching net amount/date required'using errcode='23514';end if;
 select *into cfg from public.inventory_configuration where company_id=cid;cost:=cfg.grni_account_id;
 end if;
 if cost is null then raise exception 'Canonical cost/inventory mapping required'using errcode='23514';end if;
 lines:=jsonb_build_array(jsonb_build_object('account_id',cost,'project_id',case when nullif(v->>'receipt_id','')is null then pid end,'party_id',case when nullif(v->>'receipt_id','')is not null then sid end,'debit_minor',net::text,'credit_minor','0'));
 if tax>0 then select id into vat from public.accounts where company_id=cid and system_key='INPUT_VAT'and status='ACTIVE';if vat is null then raise exception 'Input VAT mapping and tax invoice evidence required'using errcode='23514';end if;lines:=lines||jsonb_build_array(jsonb_build_object('account_id',vat,'debit_minor',tax::text,'credit_minor','0'));end if;
 if fund='SUPPLIER_CREDIT'then select id into ap from public.accounts where company_id=cid and system_key='SUPPLIER_PAYABLE'and status='ACTIVE';if ap is null then raise exception 'Supplier Payable mapping required'using errcode='23514';end if;lines:=lines||jsonb_build_array(jsonb_build_object('account_id',ap,'party_id',sid,'project_id',pid,'debit_minor','0','credit_minor',(net+tax)::text));
 else lines:=lines||jsonb_build_array(private.settlement_funding(cid,nullif(v->>'treasury_id','')::uuid,nullif(v->>'custodian_id','')::uuid,d,net+tax,pid));end if;
 return summary||jsonb_build_object('company_id',cid,'date',d,'due_date',due,'lines',lines,'inventory_receipt',nullif(v->>'receipt_id',''));end$$;
revoke all on function private.supplier_invoice_plan(uuid,jsonb)from public,anon,authenticated,service_role;
create function public.preview_supplier_invoice(cid uuid,input jsonb)returns jsonb language sql security definer set search_path=''as $$select private.supplier_invoice_plan(cid,input)$$;
revoke all on function public.preview_supplier_invoice(uuid,jsonb)from public,anon,authenticated,service_role;
grant execute on function public.preview_supplier_invoice(uuid,jsonb)to authenticated;
create function public.post_supplier_invoice(cid uuid,request_id uuid,input jsonb)returns jsonb language plpgsql security definer set search_path=''as $$
declare actor uuid;req private.financial_command_requests;plan jsonb;ex record;inv jsonb;old public.inventory_events;payment record;did uuid;v jsonb:=input;begin
 actor:=private.operational_finance_actor(cid,'accounting.post');perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 if request_id is null or v is null or jsonb_typeof(v)<>'object'or octet_length(v::text)>16000 then raise exception 'Invoice request required'using errcode='22023';end if;
 v:=private.normalize_supplier_ap_input(v);
 req:=private.reserve_financial_command(cid,'POST_SUPPLIER_INVOICE',request_id,encode(extensions.digest(jsonb_build_array(actor,cid,v)::text,'sha256'),'hex'),actor);
 if req.status='COMPLETED'then return jsonb_build_object('company_id',cid,'id',(select id from public.expenses where company_id=cid and posted_journal_entry_id=req.resulting_journal_entry_id),'journal',req.resulting_journal_entry_id,'replayed',true);end if;
 perform pg_advisory_xact_lock(hashtextextended('supplier-invoice:'||cid::text||(v->>'supplier_id')||lower(btrim(v->>'invoice_number')),0));plan:=private.supplier_invoice_plan(cid,v);
 select *into ex from public.post_expense(cid,(v->>'date')::date,nullif(v->>'project_id','')::uuid,(v->>'category_id')::uuid,btrim(v->>'description'),(plan->>'net_minor')::bigint,(v->>'vat_mode')::public.expense_vat_mode,case when v->>'vat_mode'='MANUAL'then(plan->>'vat_minor')::bigint end,case when nullif(v->>'receipt_id','')is not null then 'SUPPLIER_CREDIT'::public.expense_funding_mode else(v->>'funding_mode')::public.expense_funding_mode end,case when nullif(v->>'receipt_id','')is null then nullif(v->>'treasury_id','')::uuid end,case when nullif(v->>'receipt_id','')is null then nullif(v->>'custodian_id','')::uuid end,(v->>'supplier_id')::uuid,'OTHER',coalesce((v->>'has_tax_invoice')::boolean,false),case when coalesce((v->>'has_tax_invoice')::boolean,false)then v->>'invoice_number'end,nullif(btrim(v->>'notes'),''),request_id);
 if nullif(v->>'receipt_id','')is not null then
 old:=private.inventory_current(cid,(v->>'receipt_id')::uuid);did:=gen_random_uuid();
 inv:=public.command_inventory(cid,gen_random_uuid(),'SAVE',jsonb_build_object('id',did,'version',0,'kind','MATCH','date',v->>'date','material_id',old.snapshot->>'material_id','location_id',old.snapshot->>'location_id','origin_id',old.document_id,'expense_id',ex.expense_id,'qty_micros','0','unit',old.snapshot->>'unit','value_minor',plan->>'net_minor','supplier_id',v->>'supplier_id','project_id',nullif(v->>'project_id',''),'source_reference','SUPPLIER-INVOICE:'||(v->>'supplier_id')||':'||lower(btrim(v->>'invoice_number')),'evidence',v->>'description'));
 inv:=public.command_inventory(cid,gen_random_uuid(),'REVIEW',jsonb_build_object('id',did,'version',(inv->>'version')::integer,'evidence','Supplier invoice preview approved'));
 inv:=public.command_inventory(cid,gen_random_uuid(),'POST',jsonb_build_object('id',did,'version',(inv->>'version')::integer,'evidence','Supplier invoice approved for canonical inventory matching'));
 if v->>'funding_mode'<>'SUPPLIER_CREDIT'then select *into payment from public.post_supplier_payment(cid,(v->>'date')::date,(v->>'supplier_id')::uuid,nullif(v->>'treasury_id','')::uuid,(plan->>'gross_minor')::bigint,'OTHER',v->>'invoice_number',null,jsonb_build_array(jsonb_build_object('expense_id',ex.expense_id,'amount_minor',plan->>'gross_minor')),gen_random_uuid(),nullif(v->>'custodian_id','')::uuid);end if;
 end if;
 insert into public.supplier_invoice_terms(company_id,expense_id,supplier_id,invoice_number,due_date,due_date_confirmed,created_by)values(cid,ex.expense_id,(v->>'supplier_id')::uuid,btrim(v->>'invoice_number'),(plan->>'due_date')::date,nullif(v->>'due_date','')is not null,actor);
 perform private.complete_financial_command(req.id,ex.journal_entry_id);return jsonb_build_object('company_id',cid,'id',ex.expense_id,'reference',ex.expense_reference,'journal',ex.journal_entry_id,'inventory_document',did,'replayed',false);end$$;
revoke all on function public.post_supplier_invoice(uuid,uuid,jsonb)from public,anon,authenticated,service_role;
grant execute on function public.post_supplier_invoice(uuid,uuid,jsonb)to authenticated;

create function public.read_supplier_accounts(cid uuid,as_of date default ((now()at time zone 'Asia/Dubai')::date))returns jsonb language plpgsql stable security definer set search_path=''as $$begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'MANAGEMENT_VIEWER'))then raise exception 'Company accounting reader required'using errcode='42501';end if;
 if as_of is null or as_of>(clock_timestamp()at time zone 'Asia/Dubai')::date then raise exception 'Valid nonfuture as-of date required'using errcode='22023';end if;
 return jsonb_build_object('company_id',cid,'as_of',as_of,'today',(clock_timestamp()at time zone 'Asia/Dubai')::date,'advance_account_id',(select account_id from public.supplier_advance_configuration where company_id=cid),
 'invoices',(select coalesce(jsonb_agg(to_jsonb(x)order by x.expense_date,x.id),'[]')from(
 select e.id,e.company_id,e.supplier_id,e.expense_reference,e.expense_date,e.project_id,e.description,e.funding_mode,case when e.status='REVERSED'and r.posting_date>as_of then 'POSTED'else e.status::text end status,e.posted_journal_entry_id,e.reversal_journal_entry_id,
 e.net_amount_minor::text net_minor,e.vat_amount_minor::text vat_minor,e.gross_amount_minor::text gross_minor,coalesce(t.invoice_number,e.invoice_number)invoice_number,coalesce(t.due_date,e.expense_date)due_date,coalesce(t.due_date_confirmed,false)due_date_recorded,
 private.supplier_ap_used(cid,e.id,as_of)::text settled_minor,
 greatest(0,e.gross_amount_minor-private.supplier_ap_used(cid,e.id,as_of))::text outstanding_minor,greatest(0,private.supplier_ap_used(cid,e.id,as_of)-e.gross_amount_minor)::text credit_balance_minor,
 greatest(0,as_of-coalesce(t.due_date,e.expense_date))aging_days,case when coalesce(t.due_date_confirmed,false)then greatest(0,as_of-t.due_date)else 0 end overdue_days
 from public.expenses e left join public.supplier_invoice_terms t on t.company_id=e.company_id and t.expense_id=e.id left join public.journal_entries r on r.company_id=e.company_id and r.id=e.reversal_journal_entry_id
 where e.company_id=cid and e.supplier_id is not null and e.expense_date<=as_of and(e.status='POSTED'or e.status='REVERSED'and r.posting_date>as_of))x),
 'payments',(select coalesce(jsonb_agg(to_jsonb(p)||jsonb_build_object('total_amount_minor',p.total_amount_minor::text,'status',case when p.status='REVERSED'and(select posting_date from public.journal_entries where company_id=cid and id=p.reversal_journal_entry_id)>as_of then 'POSTED'else p.status::text end)order by p.payment_date,p.id),'[]')from public.supplier_payments p where p.company_id=cid and p.payment_date<=as_of),
 'allocations',(select coalesce(jsonb_agg(to_jsonb(a)||jsonb_build_object('allocated_amount_minor',a.allocated_amount_minor::text)order by a.id),'[]')from public.supplier_payment_allocations a join public.supplier_payments p on p.company_id=a.company_id and p.id=a.supplier_payment_id where a.company_id=cid and p.payment_date<=as_of),
 'adjustments',(select coalesce(jsonb_agg(to_jsonb(d)||jsonb_build_object('net_minor',d.net_minor::text,'vat_minor',d.vat_minor::text,'amount_minor',d.amount_minor::text,'status',case when d.status='REVERSED'and r.posting_date>as_of then 'POSTED'else d.status::text end,'effective',d.status='POSTED'or r.posting_date>as_of)order by d.posting_date,d.id),'[]')from public.supplier_ap_documents d left join public.journal_entries r on r.company_id=d.company_id and r.id=d.reversal_journal_entry_id where d.company_id=cid and d.posting_date<=as_of),
 'gl',(select coalesce(jsonb_agg(to_jsonb(x)),'[]')from(select l.party_id,sum(l.credit_minor::numeric-l.debit_minor)::text payable_minor from public.journal_lines l join public.journal_entries j on j.company_id=l.company_id and j.id=l.journal_entry_id join public.accounts a on a.company_id=l.company_id and a.id=l.account_id where l.company_id=cid and a.system_key='SUPPLIER_PAYABLE'and j.posting_date<=as_of group by l.party_id)x));
end$$;
revoke all on function public.read_supplier_accounts(uuid,date)from public,anon,authenticated,service_role;
grant execute on function public.read_supplier_accounts(uuid,date)to authenticated;

create function public.preview_supplier_payment(cid uuid,input jsonb)returns jsonb language plpgsql security definer set search_path=''as $$
declare actor uuid;item jsonb;e public.expenses;n bigint:=0;ap uuid;t public.treasury_accounts;lines jsonb:='[]';seen uuid[]:='{}';begin
 actor:=private.operational_finance_actor(cid,'accounting.post');perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 if input is null or jsonb_typeof(input)<>'object'or input-array['date','supplier_id','treasury_id','custodian_id','allocations']<>'{}'::jsonb or jsonb_typeof(input->'allocations')<>'array'or jsonb_array_length(input->'allocations')not between 1 and 999 then raise exception 'Payment date, Supplier and explicit allocations required'using errcode='22023';end if;
 select id into ap from public.accounts where company_id=cid and system_key='SUPPLIER_PAYABLE'and status='ACTIVE';if ap is null then raise exception 'Supplier Payable account mapping required'using errcode='23514';end if;
 for item in select x from jsonb_array_elements(input->'allocations')x order by(x->>'expense_id')::uuid loop
 if coalesce(item->>'amount_minor','')!~'^[0-9]{1,16}$'or(item->>'amount_minor')::bigint<1 then raise exception 'Positive exact allocations required'using errcode='22023';end if;
 select *into e from public.expenses where company_id=cid and id=(item->>'expense_id')::uuid for update;
 if e.id is null or e.id=any(seen)or e.status<>'POSTED'or e.funding_mode<>'SUPPLIER_CREDIT'or e.supplier_id is distinct from(input->>'supplier_id')::uuid or(input->>'date')::date<e.expense_date or private.supplier_ap_used(cid,e.id)+(item->>'amount_minor')::bigint>e.gross_amount_minor then raise exception 'Allocation exceeds live same-Supplier payable or conflicts with invoice date'using errcode='23514';end if;
 seen:=array_append(seen,e.id);n:=n+(item->>'amount_minor')::bigint;
 lines:=lines||jsonb_build_array(jsonb_build_object('account_id',ap,'party_id',e.supplier_id,'project_id',e.project_id,'debit_minor',item->>'amount_minor','credit_minor','0'));
 end loop;
 if nullif(input->>'treasury_id','')is not null then select *into t from public.treasury_accounts where company_id=cid and id=(input->>'treasury_id')::uuid;
 if t.project_id is not null and exists(select 1 from public.expenses where company_id=cid and id=any(seen)and project_id is distinct from t.project_id)then raise exception 'Project Treasury may settle only its own Project invoices'using errcode='23514';end if;end if;
 lines:=lines||jsonb_build_array(private.settlement_funding(cid,nullif(input->>'treasury_id','')::uuid,nullif(input->>'custodian_id','')::uuid,(input->>'date')::date,n,t.project_id));
 return jsonb_build_object('company_id',cid,'gross_minor',n::text,'net_minor',n::text,'vat_minor','0','lines',lines);end$$;
revoke all on function public.preview_supplier_payment(uuid,jsonb)from public,anon,authenticated,service_role;
grant execute on function public.preview_supplier_payment(uuid,jsonb)to authenticated;

-- Existing monthly GL reader: include canonical Supplier cash outflows; no report-basis change.
create or replace function public.read_accounting_dashboard(cid uuid,selected_month date,comparison integer default 6,project uuid default null,company_only boolean default false)
returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare result jsonb;hr boolean;complete boolean;begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'MANAGEMENT_VIEWER'))then raise exception 'Dashboard access denied'using errcode='42501';end if;
 if selected_month is null or extract(day from selected_month)<>1 or comparison not in(6,12)or selected_month<'0002-01-01'::date or selected_month>'9998-12-01'::date or project is not null and(company_only or not exists(select 1 from public.projects where company_id=cid and id=project))then raise exception 'Invalid dashboard scope'using errcode='22023';end if;
 hr:=public.has_permission(cid,'payroll.manage');
 select coalesce(bool_and(public.custody_reporting_complete(cid,p.id)),true)into complete from public.parties p where p.company_id=cid;
 with months as(select generate_series(selected_month-make_interval(months=>comparison-1),selected_month,'1 month')::date m),
 ledger as(
 select e.id,e.posting_date,coalesce(o.source_type,e.source_type)typ,a.system_key,a.account_type,l.project_id,
 l.debit_minor::numeric-l.credit_minor::numeric net,t.type treasury_type,t.id treasury_id, a.id account_id
 from public.journal_entries e join public.journal_lines l on l.company_id=cid and l.journal_entry_id=e.id
 join public.accounts a on a.company_id=cid and a.id=l.account_id
 left join public.journal_entries o on o.company_id=cid and o.id=e.reversal_of_journal_entry_id
 left join public.treasury_accounts t on t.company_id=cid and t.gl_account_id=a.id
 where e.company_id=cid and e.posting_date<selected_month+interval '1 month'
 and(case when company_only then l.project_id is null when project is not null then l.project_id=project else true end)
 ),rows as(select to_char(m.m,'YYYY-MM') as month,
 (select count(distinct id)from ledger where posting_date>=m.m and posting_date<m.m+interval '1 month')journals,
 coalesce((select sum(net)from ledger where system_key='CUSTODY_ADVANCE'and posting_date<m.m),0)::text "custodyOpening",
 coalesce((select sum(net)from ledger where system_key='CUSTODY_ADVANCE'and posting_date<m.m+interval '1 month'),0)::text "custodyClosing",
 coalesce((select sum(net)from ledger where treasury_id is not null and posting_date<m.m),0)::text "treasuryOpening",
 coalesce((select sum(net)from ledger where treasury_id is not null and posting_date<m.m+interval '1 month'),0)::text "treasuryClosing",
 jsonb_build_object(
 'treasuryIn',coalesce(sum(l.net)filter(where treasury_id is not null and net>=0),0)::text,
 'treasuryOut',coalesce(-sum(l.net)filter(where treasury_id is not null and net<0),0)::text,
 'cashChange',coalesce(sum(l.net)filter(where treasury_type in('CASH','PETTY_CASH','PROJECT_CASH_BOX')),0)::text,
 'bankChange',coalesce(sum(l.net)filter(where treasury_id is not null and treasury_type not in('CASH','PETTY_CASH','PROJECT_CASH_BOX')),0)::text,
 'custodyFunding',coalesce(sum(l.net)filter(where system_key='CUSTODY_ADVANCE'and typ in('CUSTODY_ADVANCE','PARTNER_LOAN_FUNDING','PARTNER_CAPITAL_FUNDING','PARTNER_ADDITIONAL_CAPITAL_FUNDING','PARTNER_CURRENT_FUNDING')),0)::text,
 'custodyPayments',coalesce(-sum(l.net)filter(where system_key='CUSTODY_ADVANCE'and typ in('EXPENSE','SUBCONTRACTOR_ADVANCE','SUBCONTRACTOR_PAYMENT','HR_EMPLOYEE_ADVANCE')),0)::text,
 'custodyReturns',coalesce(-sum(l.net)filter(where system_key='CUSTODY_ADVANCE'and typ='CUSTODY_CASH_RETURN'),0)::text,
 'custodyOther',coalesce(sum(l.net)filter(where system_key='CUSTODY_ADVANCE'and typ not in('CUSTODY_ADVANCE','PARTNER_LOAN_FUNDING','PARTNER_CAPITAL_FUNDING','PARTNER_ADDITIONAL_CAPITAL_FUNDING','PARTNER_CURRENT_FUNDING','EXPENSE','SUBCONTRACTOR_ADVANCE','SUBCONTRACTOR_PAYMENT','HR_EMPLOYEE_ADVANCE','CUSTODY_CASH_RETURN','SUPPLIER_PAYMENT','SUPPLIER_ADVANCE')),0)::text,
 'operating',coalesce(sum(l.net)filter(where account_type='EXPENSE'and project_id is null and typ<>'PAYROLL'),0)::text,
 'projectCost',coalesce(sum(l.net)filter(where account_type='EXPENSE'and project_id is not null),0)::text,
 'contractAdvances',coalesce(sum(l.net)filter(where system_key='SUBCONTRACTOR_ADVANCE'),0)::text,
 'contractSettlements',coalesce(sum(l.net)filter(where system_key in('SUBCONTRACTOR_PAYABLE','SUBCONTRACTOR_RETENTION_PAYABLE')and typ in('SUBCONTRACTOR_PAYMENT','SUBCONTRACTOR_RETENTION_PAYMENT')),0)::text,
 'employeeAdvances',case when hr then coalesce(sum(l.net)filter(where typ='HR_EMPLOYEE_ADVANCE'and account_type='ASSET'and system_key is distinct from 'CUSTODY_ADVANCE'and treasury_id is null),0)::text end,
 'payrollCost',case when hr then coalesce(sum(l.net)filter(where typ='PAYROLL'and account_type='EXPENSE'),0)::text end,
 'payrollPayments',case when hr then coalesce(sum(l.net)filter(where typ='SALARY_PAYMENT'and system_key='SALARY_PAYABLE'),0)::text end,
 'stockValue',coalesce(sum(l.net)filter(where l.account_id=(select inventory_account_id from public.inventory_configuration where company_id=cid)),0)::text
 )"values" from months m left join ledger l on l.posting_date>=m.m and l.posting_date<m.m+interval '1 month'group by m.m
 ),sources as materialized(select * from public.read_dashboard_sources(cid,to_char(selected_month,'YYYY-MM'),project,company_only,true)),counts as(
 select count(*)filter(where report_month=to_char(selected_month,'YYYY-MM'))total,
 count(*)filter(where report_month=to_char(selected_month,'YYYY-MM')and status='POSTED')posted,
 count(*)filter(where report_month=to_char(selected_month,'YYYY-MM')and status='DRAFT')draft,
 count(*)filter(where report_month=to_char(selected_month,'YYYY-MM')and status='CLASSIFIED_UNPOSTED')classified,
 count(*)filter(where report_month=to_char(selected_month,'YYYY-MM')and status='UNCLASSIFIED')unclassified,
 count(*)filter(where report_month=to_char(selected_month,'YYYY-MM')and status<>'POSTED')review,
 count(*)filter(where report_month=to_char(selected_month,'YYYY-MM')and possible_duplicate)duplicates,
 count(*)filter(where report_month is null)unknown
 from sources)
 select jsonb_build_object('company',cid,'month',to_char(selected_month,'YYYY-MM'),'rows',(select jsonb_agg(to_jsonb(rows)order by month)from rows),'counts',(select to_jsonb(counts)from counts),'payrollVisible',hr,'custodyComplete',complete,'captured',statement_timestamp())into result;
 -- Confidential incomplete Custody must never appear as a verified partial balance.
 if not complete then select jsonb_set(result,'{rows}',jsonb_agg((x-'custodyOpening'-'custodyClosing')||jsonb_build_object('custodyOpening',null,'custodyClosing',null,'values',(x->'values')||jsonb_build_object('custodyFunding',null,'custodyPayments',null,'custodyReturns',null,'custodyOther',null))))into result from jsonb_array_elements(result->'rows')x;end if;
 -- HR journal RLS can hide Treasury salary movements and Project payroll cost.
 -- Never turn that partial view into a claimed complete closing balance.
 if not hr then select jsonb_set(result,'{rows}',jsonb_agg(x||jsonb_build_object('treasuryOpening',null,'treasuryClosing',null,'values',(x->'values')||jsonb_build_object('treasuryIn',null,'treasuryOut',null,'cashChange',null,'bankChange',null,'projectCost',null))))into result from jsonb_array_elements(result->'rows')x;end if;
 return result;
end$$;

-- Preserve canonical reversal behavior; acquire the same Company locks before document rows.
create or replace function public.reverse_expense(
  target_company_id uuid,
  target_expense_id uuid,
  target_reversal_date date,
  target_reason text,
  target_idempotency_key uuid
)
returns table (expense_id uuid, expense_reference text, reversal_journal_entry_id uuid, replayed boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  normalized_reason text := btrim(target_reason);
  request_hash text;
  request_row private.financial_command_requests;
  expense_row public.expenses;
  new_reversal_id uuid;
begin
  if actor_id is null or not public.has_permission(target_company_id, 'accounting.reverse') then
    raise exception 'Not authorized to reverse expenses' using errcode = '42501';
  end if;
  perform private.attendance_company_lock(target_company_id);perform private.serialize_operational_finance(target_company_id,'OPERATIONS');
  if target_company_id is null or target_expense_id is null or target_idempotency_key is null then
    raise exception 'Required Expense reversal input is missing' using errcode = '22023';
  end if;
  if target_reversal_date is null or normalized_reason is null or length(normalized_reason) not between 1 and 1000 then
    raise exception 'Reversal date and reason are required' using errcode = '22023';
  end if;
  request_hash := encode(extensions.digest(convert_to(jsonb_build_object(
    'company_id', target_company_id, 'expense_id', target_expense_id,
    'reversal_date', target_reversal_date, 'reason', normalized_reason
  )::text, 'UTF8'), 'sha256'), 'hex');
  request_row := private.reserve_financial_command(
    target_company_id, 'REVERSE_EXPENSE', target_idempotency_key, request_hash, actor_id
  );
  if request_row.status = 'COMPLETED' then
    return query select e.id, e.expense_reference, e.reversal_journal_entry_id, true
    from public.expenses e where e.company_id = target_company_id
      and e.reversal_journal_entry_id = request_row.resulting_journal_entry_id;
    return;
  end if;

  select e.* into expense_row from public.expenses e
  where e.company_id = target_company_id and e.id = target_expense_id for update;
  if not found then raise exception 'Expense not found in company' using errcode = '23503'; end if;
  if expense_row.status <> 'POSTED' then raise exception 'Only a posted expense can be reversed' using errcode = '23514'; end if;
  new_reversal_id := private.reverse_journal(
    expense_row.posted_journal_entry_id, target_reversal_date,
    'Reversal of ' || expense_row.expense_reference || ': ' || normalized_reason, actor_id
  );
  update public.expenses set status = 'REVERSED', reversal_journal_entry_id = new_reversal_id,
    reversed_at = now(), reversed_by = actor_id, updated_by = actor_id
  where id = expense_row.id;
  perform private.complete_financial_command(request_row.id, new_reversal_id);
  return query select expense_row.id, expense_row.expense_reference, new_reversal_id, false;
end;
$$;

-- Preserve canonical reversal behavior; acquire the same Company locks before document rows.
create or replace function public.reverse_supplier_payment(
  target_company_id uuid,
  target_supplier_payment_id uuid,
  target_reversal_date date,
  target_reason text,
  target_idempotency_key uuid
)
returns table (supplier_payment_id uuid, payment_reference text, reversal_journal_entry_id uuid, replayed boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  normalized_reason text := btrim(target_reason);
  request_hash text;
  request_row private.financial_command_requests;
  payment_row public.supplier_payments;
  new_reversal_id uuid;
begin
  if actor_id is null or not public.has_permission(target_company_id, 'accounting.reverse') then
    raise exception 'Not authorized to reverse Supplier Payments' using errcode = '42501';
  end if;
  perform private.attendance_company_lock(target_company_id);perform private.serialize_operational_finance(target_company_id,'OPERATIONS');
  if target_company_id is null or target_supplier_payment_id is null or target_reversal_date is null
     or target_idempotency_key is null or normalized_reason is null
     or length(normalized_reason) not between 1 and 1000 then
    raise exception 'Valid Supplier Payment reversal inputs are required' using errcode = '22023';
  end if;
  request_hash := encode(extensions.digest(convert_to(jsonb_build_object(
    'company_id', target_company_id, 'supplier_payment_id', target_supplier_payment_id,
    'reversal_date', target_reversal_date, 'reason', normalized_reason
  )::text, 'UTF8'), 'sha256'), 'hex');
  request_row := private.reserve_financial_command(
    target_company_id, 'REVERSE_SUPPLIER_PAYMENT', target_idempotency_key, request_hash, actor_id
  );
  if request_row.status = 'COMPLETED' then
    return query select p.id, p.payment_reference, p.reversal_journal_entry_id, true
    from public.supplier_payments p where p.company_id = target_company_id
      and p.reversal_journal_entry_id = request_row.resulting_journal_entry_id;
    return;
  end if;
  select p.* into payment_row from public.supplier_payments p
  where p.company_id = target_company_id and p.id = target_supplier_payment_id for update;
  if not found then raise exception 'Supplier Payment not found in company' using errcode = '23503'; end if;
  if payment_row.status <> 'POSTED' then
    raise exception 'Only a posted Supplier Payment can be reversed' using errcode = '23514';
  end if;
  new_reversal_id := private.reverse_journal(
    payment_row.posted_journal_entry_id, target_reversal_date,
    'Reversal of ' || payment_row.payment_reference || ': ' || normalized_reason, actor_id
  );
  update public.supplier_payments set status = 'REVERSED',
    reversal_journal_entry_id = new_reversal_id, reversed_at = now(), reversed_by = actor_id,
    updated_by = actor_id where id = payment_row.id;
  perform private.complete_financial_command(request_row.id, new_reversal_id);
  return query select payment_row.id, payment_row.payment_reference, new_reversal_id, false;
end;
$$;

-- A business-document reversal preview, never an arbitrary journal-line browser command.
create function public.preview_supplier_reversal(cid uuid,kind text,id uuid,date date)returns jsonb language plpgsql security definer set search_path=''as $$
#variable_conflict use_variable
declare actor uuid;jid uuid;ref text;sid uuid;d date;n bigint;net bigint;tax bigint;lines jsonb;begin
 actor:=private.operational_finance_actor(cid,'accounting.reverse');perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');perform private.opening_period(cid,date);
 if kind='PAYMENT'then select p.posted_journal_entry_id,p.payment_reference,p.supplier_id,p.payment_date,p.total_amount_minor into jid,ref,sid,d,n from public.supplier_payments p where p.company_id=cid and p.id=id and p.status='POSTED'for share;net:=n;tax:=0;
 elsif kind='DOCUMENT'then
 if not public.has_company_role(cid,'ACCOUNTING_ADMIN')then raise exception 'Accounting Admin reversal approval required'using errcode='42501';end if;
 select p.posted_journal_entry_id,p.reference,p.supplier_id,p.posting_date,p.amount_minor,p.net_minor,p.vat_minor into jid,ref,sid,d,n,net,tax from public.supplier_ap_documents p where p.company_id=cid and p.id=id and p.status='POSTED'for share;
 if exists(select 1 from public.supplier_ap_documents p where p.company_id=cid and(p.advance_id=id or p.credit_note_id=id)and p.status='POSTED')then raise exception 'Reverse dependent Supplier allocations first'using errcode='23514';end if;
 else raise exception 'Supported Supplier business document required'using errcode='22023';end if;
 if jid is null or date<d then raise exception 'Live original document and non-earlier reversal date required'using errcode='23514';end if;
 select jsonb_agg(jsonb_build_object('account_id',l.account_id,'party_id',l.party_id,'project_id',l.project_id,'treasury_account_id',l.treasury_account_id,'debit_minor',l.credit_minor::text,'credit_minor',l.debit_minor::text)order by l.line_number)into lines from public.journal_lines l where l.company_id=cid and l.journal_entry_id=jid;
 return jsonb_build_object('company_id',cid,'reference',ref,'supplier_id',sid,'original_journal',jid,'gross_minor',n::text,'net_minor',net::text,'vat_minor',tax::text,'lines',lines);end$$;
revoke all on function public.preview_supplier_reversal(uuid,text,uuid,date)from public,anon,authenticated,service_role;
grant execute on function public.preview_supplier_reversal(uuid,text,uuid,date)to authenticated;
