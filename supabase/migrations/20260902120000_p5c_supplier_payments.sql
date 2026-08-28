-- P5C: immutable Supplier Payment documents, explicit payable allocations,
-- and specialized post/reversal commands. No frontend, custody, subcontract,
-- payroll, AR/revenue, or import behavior.

create table public.supplier_payments (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  payment_reference text not null check (length(btrim(payment_reference)) between 1 and 100),
  payment_date date not null,
  supplier_id uuid not null,
  treasury_account_id uuid not null,
  total_amount_minor bigint not null check (total_amount_minor between 1 and 9000000000000000),
  payment_method public.payment_method not null,
  external_reference text check (external_reference is null or length(btrim(external_reference)) between 1 and 200),
  notes text check (notes is null or length(btrim(notes)) between 1 and 2000),
  status public.expense_status not null default 'DRAFT',
  posted_journal_entry_id uuid,
  reversal_journal_entry_id uuid,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete restrict,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete restrict,
  posted_at timestamptz,
  posted_by uuid references auth.users (id) on delete restrict,
  reversed_at timestamptz,
  reversed_by uuid references auth.users (id) on delete restrict,
  constraint supplier_payments_company_id_id_unique unique (company_id, id),
  constraint supplier_payments_company_reference_unique unique (company_id, payment_reference),
  constraint supplier_payments_supplier_same_company foreign key (company_id, supplier_id)
    references public.parties (company_id, id) on delete restrict,
  constraint supplier_payments_treasury_same_company foreign key (company_id, treasury_account_id)
    references public.treasury_accounts (company_id, id) on delete restrict,
  constraint supplier_payments_posted_journal_same_company foreign key (company_id, posted_journal_entry_id)
    references public.journal_entries (company_id, id) on delete restrict,
  constraint supplier_payments_reversal_journal_same_company foreign key (company_id, reversal_journal_entry_id)
    references public.journal_entries (company_id, id) on delete restrict,
  constraint supplier_payments_posted_journal_unique unique (posted_journal_entry_id),
  constraint supplier_payments_reversal_journal_unique unique (reversal_journal_entry_id),
  constraint supplier_payments_state_shape check (
    (status = 'DRAFT' and posted_journal_entry_id is null and reversal_journal_entry_id is null
      and posted_at is null and posted_by is null and reversed_at is null and reversed_by is null)
    or (status = 'POSTED' and posted_journal_entry_id is not null and reversal_journal_entry_id is null
      and posted_at is not null and posted_by is not null and reversed_at is null and reversed_by is null)
    or (status = 'REVERSED' and posted_journal_entry_id is not null and reversal_journal_entry_id is not null
      and posted_at is not null and posted_by is not null and reversed_at is not null and reversed_by is not null)
  )
);

create table public.supplier_payment_allocations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  supplier_payment_id uuid not null,
  expense_id uuid not null,
  allocated_amount_minor bigint not null check (allocated_amount_minor between 1 and 9000000000000000),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete restrict,
  constraint supplier_payment_allocations_company_id_id_unique unique (company_id, id),
  constraint supplier_payment_allocations_payment_expense_unique unique (supplier_payment_id, expense_id),
  constraint supplier_payment_allocations_payment_same_company foreign key (company_id, supplier_payment_id)
    references public.supplier_payments (company_id, id) on delete restrict,
  constraint supplier_payment_allocations_expense_same_company foreign key (company_id, expense_id)
    references public.expenses (company_id, id) on delete restrict
);

create index supplier_payments_company_date_idx
  on public.supplier_payments (company_id, payment_date desc, id);
create index supplier_payments_supplier_idx
  on public.supplier_payments (company_id, supplier_id, payment_date desc);
create index supplier_payment_allocations_expense_idx
  on public.supplier_payment_allocations (company_id, expense_id);

create function private.protect_supplier_payment_history()
returns trigger
language plpgsql
set search_path = ''
as $$
declare allocation_total numeric;
begin
  if tg_op = 'DELETE' then
    raise exception 'Supplier Payment history cannot be deleted; reverse posted accounting'
      using errcode = '55000';
  end if;
  if new.company_id <> old.company_id
     or new.payment_reference <> old.payment_reference
     or new.payment_date <> old.payment_date
     or new.supplier_id <> old.supplier_id
     or new.treasury_account_id <> old.treasury_account_id
     or new.total_amount_minor <> old.total_amount_minor
     or new.payment_method <> old.payment_method
     or new.external_reference is distinct from old.external_reference
     or new.notes is distinct from old.notes
     or new.created_at <> old.created_at
     or new.created_by is distinct from old.created_by then
    raise exception 'Posted Supplier Payment economics and provenance are immutable'
      using errcode = '55000';
  end if;
  if old.status = 'DRAFT' then
    if new.status <> 'POSTED' or new.posted_journal_entry_id is null
       or new.reversal_journal_entry_id is not null then
      raise exception 'Supplier Payment may transition only from DRAFT to POSTED'
        using errcode = '55000';
    end if;
    select coalesce(sum(a.allocated_amount_minor::numeric), 0) into allocation_total
    from public.supplier_payment_allocations a where a.supplier_payment_id = old.id;
    if allocation_total <> old.total_amount_minor::numeric then
      raise exception 'Supplier Payment allocations must equal its total'
        using errcode = '23514';
    end if;
  elsif old.status = 'POSTED' then
    if new.status <> 'REVERSED'
       or new.posted_journal_entry_id <> old.posted_journal_entry_id
       or new.reversal_journal_entry_id is null then
      raise exception 'Posted Supplier Payment may transition only to REVERSED with a linked journal'
        using errcode = '55000';
    end if;
  else
    raise exception 'Reversed Supplier Payment is immutable' using errcode = '55000';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create function private.validate_supplier_payment_allocation()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  payment_row public.supplier_payments;
  expense_row public.expenses;
  already_allocated numeric;
begin
  if tg_op <> 'INSERT' then
    raise exception 'Supplier Payment allocations are immutable' using errcode = '55000';
  end if;
  select p.* into payment_row from public.supplier_payments p
  where p.company_id = new.company_id and p.id = new.supplier_payment_id for share;
  if not found or payment_row.status <> 'DRAFT' then
    raise exception 'Allocations may be added only during atomic Supplier Payment posting'
      using errcode = '55000';
  end if;
  select e.* into expense_row from public.expenses e
  where e.company_id = new.company_id and e.id = new.expense_id for update;
  if not found then raise exception 'Allocated Expense not found in company' using errcode = '23503'; end if;
  if expense_row.funding_mode <> 'SUPPLIER_CREDIT' or expense_row.status <> 'POSTED' then
    raise exception 'Allocation source must be a live posted Supplier Credit Expense'
      using errcode = '23514';
  end if;
  if expense_row.supplier_id <> payment_row.supplier_id then
    raise exception 'Allocated Expense belongs to a different Supplier'
      using errcode = '23514';
  end if;
  select coalesce(sum(a.allocated_amount_minor::numeric), 0) into already_allocated
  from public.supplier_payment_allocations a
  join public.supplier_payments p on p.id = a.supplier_payment_id
  where a.company_id = new.company_id and a.expense_id = new.expense_id and p.status = 'POSTED';
  if already_allocated + new.allocated_amount_minor::numeric > expense_row.gross_amount_minor::numeric then
    raise exception 'Supplier Payment allocation exceeds outstanding payable'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create function private.protect_allocated_supplier_credit_reversal()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if old.status = 'POSTED' and new.status = 'REVERSED' and exists (
    select 1 from public.supplier_payment_allocations a
    join public.supplier_payments p on p.id = a.supplier_payment_id
    where a.company_id = old.company_id and a.expense_id = old.id and p.status = 'POSTED'
  ) then
    raise exception 'Reverse active Supplier Payments before reversing this Supplier Credit Expense'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger supplier_payments_protect_history
  before update or delete on public.supplier_payments
  for each row execute function private.protect_supplier_payment_history();
create trigger supplier_payment_allocations_validate
  before insert or update or delete on public.supplier_payment_allocations
  for each row execute function private.validate_supplier_payment_allocation();
create trigger expenses_protect_active_supplier_payments
  before update on public.expenses
  for each row execute function private.protect_allocated_supplier_credit_reversal();

alter table public.supplier_payments enable row level security;
alter table public.supplier_payments force row level security;
alter table public.supplier_payment_allocations enable row level security;
alter table public.supplier_payment_allocations force row level security;

create policy supplier_payments_read_accounting on public.supplier_payments
  for select to authenticated using (
    public.has_company_role(company_id, 'ACCOUNTING_ADMIN')
    or public.has_company_role(company_id, 'ACCOUNTANT')
    or public.has_company_role(company_id, 'MANAGEMENT_VIEWER')
  );
create policy supplier_payment_allocations_read_accounting on public.supplier_payment_allocations
  for select to authenticated using (
    public.has_company_role(company_id, 'ACCOUNTING_ADMIN')
    or public.has_company_role(company_id, 'ACCOUNTANT')
    or public.has_company_role(company_id, 'MANAGEMENT_VIEWER')
  );

revoke all on table public.supplier_payments, public.supplier_payment_allocations
  from public, anon, authenticated, service_role;
grant select on table public.supplier_payments, public.supplier_payment_allocations
  to authenticated, service_role;

create function public.post_supplier_payment(
  target_company_id uuid,
  target_payment_date date,
  target_supplier_id uuid,
  target_treasury_account_id uuid,
  target_payment_method public.payment_method,
  target_external_reference text,
  target_notes text,
  target_allocations jsonb,
  target_idempotency_key uuid
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
  journal_lines jsonb;
begin
  if actor_id is null or not public.has_permission(target_company_id, 'accounting.post') then
    raise exception 'Not authorized to post Supplier Payments' using errcode = '42501';
  end if;
  if target_company_id is null or target_payment_date is null or target_supplier_id is null
     or target_treasury_account_id is null or target_payment_method is null
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

  select p.* into supplier_row from public.parties p
  where p.company_id = target_company_id and p.id = target_supplier_id and p.type = 'SUPPLIER';
  if not found then raise exception 'Supplier not found in company' using errcode = '23503'; end if;
  -- Inactive is intentionally allowed: this command settles an existing liability.
  select t.* into treasury_row from public.treasury_accounts t
  join public.accounts a on a.company_id = t.company_id and a.id = t.gl_account_id
  where t.company_id = target_company_id and t.id = target_treasury_account_id
    and t.status = 'ACTIVE' and a.status = 'ACTIVE' and a.account_type = 'ASSET';
  if not found then raise exception 'An active same-company Treasury with an active Asset GL is required' using errcode = '23514'; end if;
  select a.id into payable_account_id from public.accounts a
  where a.company_id = target_company_id and a.system_key = 'SUPPLIER_PAYABLE' and a.status = 'ACTIVE';
  if payable_account_id is null then raise exception 'Supplier Payable system account is unavailable' using errcode = '23514'; end if;

  request_hash := encode(extensions.digest(convert_to(jsonb_build_object(
    'company_id', target_company_id, 'payment_date', target_payment_date,
    'supplier_id', target_supplier_id, 'treasury_id', target_treasury_account_id,
    'payment_method', target_payment_method, 'external_reference', normalized_external_reference,
    'notes', normalized_notes, 'allocations', normalized_allocations
  )::text, 'UTF8'), 'sha256'), 'hex');
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
    total_amount_minor, payment_method, external_reference, notes, created_by, updated_by
  ) values (
    new_payment_id, target_company_id, new_payment_reference, target_payment_date,
    target_supplier_id, target_treasury_account_id, allocation_total::bigint,
    target_payment_method, normalized_external_reference, normalized_notes, actor_id, actor_id
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
  journal_lines := journal_lines || jsonb_build_array(jsonb_build_object(
    'account_id', treasury_row.gl_account_id,
    'debit_minor', 0,
    'credit_minor', allocation_total::bigint,
    'treasury_account_id', target_treasury_account_id,
    'memo', 'Supplier Payment treasury settlement'
  ));
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

create function public.reverse_supplier_payment(
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

revoke all on function private.protect_supplier_payment_history()
  from public, anon, authenticated, service_role;
revoke all on function private.validate_supplier_payment_allocation()
  from public, anon, authenticated, service_role;
revoke all on function private.protect_allocated_supplier_credit_reversal()
  from public, anon, authenticated, service_role;
revoke all on function public.post_supplier_payment(uuid, date, uuid, uuid,
  public.payment_method, text, text, jsonb, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.reverse_supplier_payment(uuid, uuid, date, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.post_supplier_payment(uuid, date, uuid, uuid,
  public.payment_method, text, text, jsonb, uuid) to authenticated;
grant execute on function public.reverse_supplier_payment(uuid, uuid, date, text, uuid)
  to authenticated;

comment on table public.supplier_payments is
  'P5C immutable Supplier Payment documents. Treasury-only AP settlement; no cost or VAT recognition.';
comment on table public.supplier_payment_allocations is
  'Immutable provenance linking Supplier Payments to live P5B Supplier Credit Expenses. Reversal preserves rows and makes them inactive through Payment status.';
comment on function public.post_supplier_payment(uuid, date, uuid, uuid,
  public.payment_method, text, text, jsonb, uuid) is
  'Specialized authenticated Treasury-to-Supplier-Payable settlement command with locked explicit allocations.';
