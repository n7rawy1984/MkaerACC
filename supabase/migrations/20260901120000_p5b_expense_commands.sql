-- P5B: Expense business documents and specialized post/reversal commands.
-- No supplier payment, custody funding/settlement, subcontract flow, or UI cutover.

create type public.expense_status as enum ('DRAFT', 'POSTED', 'REVERSED');
create type public.expense_funding_mode as enum ('TREASURY', 'CUSTODIAN', 'OWNER', 'SUPPLIER_CREDIT');
create type public.expense_vat_mode as enum ('ZERO', 'AUTO_5', 'MANUAL');
create type public.payment_method as enum ('CASH', 'BANK', 'TRANSFER', 'CHEQUE', 'OTHER');

insert into public.permissions (key, description) values
  ('accounting.reverse', 'Reverse permitted posted accounting documents');
insert into public.role_permissions (role, permission_key) values
  ('ACCOUNTING_ADMIN', 'accounting.reverse');

alter table public.expense_categories
  add constraint expense_categories_company_id_id_unique unique (company_id, id);

create table public.expenses (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  expense_reference text not null check (length(btrim(expense_reference)) between 1 and 100),
  expense_date date not null,
  project_id uuid,
  expense_category_id uuid not null,
  supplier_id uuid,
  description text not null check (length(btrim(description)) between 1 and 1000),
  net_amount_minor bigint not null check (net_amount_minor between 1 and 9000000000000000),
  vat_mode public.expense_vat_mode not null,
  vat_amount_minor bigint not null check (vat_amount_minor between 0 and 9000000000000000),
  gross_amount_minor bigint not null check (gross_amount_minor between 1 and 9000000000000000),
  funding_mode public.expense_funding_mode not null,
  treasury_account_id uuid,
  paid_by_party_id uuid,
  payment_method public.payment_method not null,
  has_tax_invoice boolean not null default false,
  invoice_number text check (invoice_number is null or length(btrim(invoice_number)) between 1 and 100),
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
  constraint expenses_company_id_id_unique unique (company_id, id),
  constraint expenses_company_reference_unique unique (company_id, expense_reference),
  constraint expenses_project_same_company foreign key (company_id, project_id)
    references public.projects (company_id, id) on delete restrict,
  constraint expenses_category_same_company foreign key (company_id, expense_category_id)
    references public.expense_categories (company_id, id) on delete restrict,
  constraint expenses_supplier_same_company foreign key (company_id, supplier_id)
    references public.parties (company_id, id) on delete restrict,
  constraint expenses_treasury_same_company foreign key (company_id, treasury_account_id)
    references public.treasury_accounts (company_id, id) on delete restrict,
  constraint expenses_paid_by_party_same_company foreign key (company_id, paid_by_party_id)
    references public.parties (company_id, id) on delete restrict,
  constraint expenses_posted_journal_same_company foreign key (company_id, posted_journal_entry_id)
    references public.journal_entries (company_id, id) on delete restrict,
  constraint expenses_reversal_journal_same_company foreign key (company_id, reversal_journal_entry_id)
    references public.journal_entries (company_id, id) on delete restrict,
  constraint expenses_posted_journal_unique unique (posted_journal_entry_id),
  constraint expenses_reversal_journal_unique unique (reversal_journal_entry_id),
  constraint expenses_amount_equation check (
    gross_amount_minor::numeric = net_amount_minor::numeric + vat_amount_minor::numeric
  ),
  constraint expenses_vat_shape check (
    (vat_mode = 'ZERO' and vat_amount_minor = 0)
    or (vat_mode in ('AUTO_5', 'MANUAL') and vat_amount_minor > 0)
  ),
  constraint expenses_invoice_shape check (
    (has_tax_invoice and invoice_number is not null)
    or (not has_tax_invoice and invoice_number is null and vat_amount_minor = 0)
  ),
  constraint expenses_funding_shape check (
    (funding_mode = 'TREASURY' and treasury_account_id is not null and paid_by_party_id is null)
    or (funding_mode in ('CUSTODIAN', 'OWNER') and treasury_account_id is null and paid_by_party_id is not null)
    or (funding_mode = 'SUPPLIER_CREDIT' and treasury_account_id is null
        and paid_by_party_id is null and supplier_id is not null)
  ),
  constraint expenses_state_shape check (
    (status = 'DRAFT' and posted_journal_entry_id is null and reversal_journal_entry_id is null
      and posted_at is null and posted_by is null and reversed_at is null and reversed_by is null)
    or (status = 'POSTED' and posted_journal_entry_id is not null and reversal_journal_entry_id is null
      and posted_at is not null and posted_by is not null and reversed_at is null and reversed_by is null)
    or (status = 'REVERSED' and posted_journal_entry_id is not null and reversal_journal_entry_id is not null
      and posted_at is not null and posted_by is not null and reversed_at is not null and reversed_by is not null)
  )
);

create index expenses_company_date_idx on public.expenses (company_id, expense_date desc, id);
create index expenses_project_idx on public.expenses (company_id, project_id) where project_id is not null;
create index expenses_category_idx on public.expenses (company_id, expense_category_id);
create index expenses_supplier_idx on public.expenses (company_id, supplier_id) where supplier_id is not null;

create function private.protect_expense_history()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'Expense history cannot be deleted; reverse posted accounting'
      using errcode = '55000';
  end if;
  if new.company_id <> old.company_id
     or new.expense_reference <> old.expense_reference
     or new.expense_date <> old.expense_date
     or new.project_id is distinct from old.project_id
     or new.expense_category_id <> old.expense_category_id
     or new.supplier_id is distinct from old.supplier_id
     or new.description <> old.description
     or new.net_amount_minor <> old.net_amount_minor
     or new.vat_mode <> old.vat_mode
     or new.vat_amount_minor <> old.vat_amount_minor
     or new.gross_amount_minor <> old.gross_amount_minor
     or new.funding_mode <> old.funding_mode
     or new.treasury_account_id is distinct from old.treasury_account_id
     or new.paid_by_party_id is distinct from old.paid_by_party_id
     or new.payment_method <> old.payment_method
     or new.has_tax_invoice <> old.has_tax_invoice
     or new.invoice_number is distinct from old.invoice_number
     or new.notes is distinct from old.notes
     or new.created_at <> old.created_at
     or new.created_by is distinct from old.created_by then
    raise exception 'Posted expense economics and provenance are immutable'
      using errcode = '55000';
  end if;
  if old.status = 'DRAFT' then
    if new.status <> 'POSTED' or new.posted_journal_entry_id is null
       or new.reversal_journal_entry_id is not null then
      raise exception 'Expense may transition only from DRAFT to POSTED'
        using errcode = '55000';
    end if;
  elsif old.status = 'POSTED' then
    if new.status <> 'REVERSED'
       or new.posted_journal_entry_id <> old.posted_journal_entry_id
       or new.reversal_journal_entry_id is null then
      raise exception 'Posted expense may transition only to REVERSED with a linked journal'
        using errcode = '55000';
    end if;
  else
    raise exception 'Reversed expense is immutable' using errcode = '55000';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger expenses_protect_history
  before update or delete on public.expenses
  for each row execute function private.protect_expense_history();

alter table public.expenses enable row level security;
alter table public.expenses force row level security;

create policy expenses_read_authorized on public.expenses
  for select to authenticated using (
    public.has_company_role(company_id, 'ACCOUNTING_ADMIN')
    or public.has_company_role(company_id, 'ACCOUNTANT')
    or public.has_company_role(company_id, 'MANAGEMENT_VIEWER')
    or (
      project_id is not null
      and public.has_company_role(company_id, 'PROJECT_MANAGER')
      and public.has_active_project_assignment(company_id, project_id)
    )
  );

revoke all on table public.expenses from public, anon, authenticated, service_role;
grant select on table public.expenses to authenticated, service_role;

create function public.post_expense(
  target_company_id uuid,
  target_expense_date date,
  target_project_id uuid,
  target_expense_category_id uuid,
  target_description text,
  target_net_amount_minor bigint,
  target_vat_mode public.expense_vat_mode,
  target_manual_vat_amount_minor bigint,
  target_funding_mode public.expense_funding_mode,
  target_treasury_account_id uuid,
  target_paid_by_party_id uuid,
  target_supplier_id uuid,
  target_payment_method public.payment_method,
  target_has_tax_invoice boolean,
  target_invoice_number text,
  target_notes text,
  target_idempotency_key uuid
)
returns table (expense_id uuid, expense_reference text, journal_entry_id uuid, replayed boolean)
language plpgsql
security definer
set search_path = ''
as $$
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
begin
  if actor_id is null or not public.has_permission(target_company_id, 'accounting.post') then
    raise exception 'Not authorized to post expenses' using errcode = '42501';
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
    if funding_party.id is null or funding_party.type::text <> target_funding_mode::text then
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

  request_hash := encode(extensions.digest(convert_to(jsonb_build_object(
    'company_id', target_company_id, 'expense_date', target_expense_date, 'project_id', target_project_id,
    'category_id', target_expense_category_id, 'description', normalized_description,
    'net_minor', target_net_amount_minor, 'vat_mode', target_vat_mode, 'manual_vat_minor', target_manual_vat_amount_minor,
    'funding_mode', target_funding_mode, 'treasury_id', target_treasury_account_id,
    'paid_by_party_id', target_paid_by_party_id, 'supplier_id', target_supplier_id,
    'payment_method', target_payment_method, 'has_tax_invoice', target_has_tax_invoice,
    'invoice_number', normalized_invoice_number, 'notes', normalized_notes
  )::text, 'UTF8'), 'sha256'), 'hex');
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
    invoice_number, notes, created_by, updated_by
  ) values (
    new_expense_id, target_company_id, new_expense_reference, target_expense_date, target_project_id,
    target_expense_category_id, target_supplier_id, normalized_description, target_net_amount_minor,
    target_vat_mode, calculated_vat_minor, calculated_gross::bigint, target_funding_mode,
    target_treasury_account_id, target_paid_by_party_id, target_payment_method,
    target_has_tax_invoice, normalized_invoice_number, normalized_notes, actor_id, actor_id
  );

  journal_lines := jsonb_build_array(jsonb_build_object(
    'account_id', cost_account_id, 'debit_minor', target_net_amount_minor, 'credit_minor', 0,
    'project_id', target_project_id
  ));
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
$$;

create function public.reverse_expense(
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

revoke all on function private.protect_expense_history() from public, anon, authenticated, service_role;
revoke all on function public.post_expense(uuid, date, uuid, uuid, text, bigint,
  public.expense_vat_mode, bigint, public.expense_funding_mode, uuid, uuid, uuid,
  public.payment_method, boolean, text, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.reverse_expense(uuid, uuid, date, text, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.post_expense(uuid, date, uuid, uuid, text, bigint,
  public.expense_vat_mode, bigint, public.expense_funding_mode, uuid, uuid, uuid,
  public.payment_method, boolean, text, text, uuid) to authenticated;
grant execute on function public.reverse_expense(uuid, uuid, date, text, uuid) to authenticated;

comment on table public.expenses is
  'P5B immutable posted Expense documents. DRAFT is an internal atomic-posting transition; no browser draft CRUD exists.';
comment on function public.post_expense(uuid, date, uuid, uuid, text, bigint,
  public.expense_vat_mode, bigint, public.expense_funding_mode, uuid, uuid, uuid,
  public.payment_method, boolean, text, text, uuid) is
  'Specialized authenticated Expense command; accepts business inputs only and uses the private P5A journal kernel.';
