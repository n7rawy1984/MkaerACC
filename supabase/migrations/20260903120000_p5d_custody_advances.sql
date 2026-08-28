-- P5D: Custody Advance funding documents and atomic commands.
-- Pooled custody is company + Custodian scoped; Project remains an analytic
-- dimension. Also hardens future P5B Custodian Expenses against overspending.

create table public.custody_advances (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  advance_reference text not null check (length(btrim(advance_reference)) between 1 and 100),
  advance_date date not null,
  custodian_id uuid not null,
  treasury_account_id uuid not null,
  project_id uuid,
  amount_minor bigint not null check (amount_minor between 1 and 9000000000000000),
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
  constraint custody_advances_company_id_id_unique unique (company_id, id),
  constraint custody_advances_company_reference_unique unique (company_id, advance_reference),
  constraint custody_advances_custodian_same_company foreign key (company_id, custodian_id)
    references public.parties (company_id, id) on delete restrict,
  constraint custody_advances_treasury_same_company foreign key (company_id, treasury_account_id)
    references public.treasury_accounts (company_id, id) on delete restrict,
  constraint custody_advances_project_same_company foreign key (company_id, project_id)
    references public.projects (company_id, id) on delete restrict,
  constraint custody_advances_posted_journal_same_company foreign key (company_id, posted_journal_entry_id)
    references public.journal_entries (company_id, id) on delete restrict,
  constraint custody_advances_reversal_journal_same_company foreign key (company_id, reversal_journal_entry_id)
    references public.journal_entries (company_id, id) on delete restrict,
  constraint custody_advances_posted_journal_unique unique (posted_journal_entry_id),
  constraint custody_advances_reversal_journal_unique unique (reversal_journal_entry_id),
  constraint custody_advances_state_shape check (
    (status = 'DRAFT' and posted_journal_entry_id is null and reversal_journal_entry_id is null
      and posted_at is null and posted_by is null and reversed_at is null and reversed_by is null)
    or (status = 'POSTED' and posted_journal_entry_id is not null and reversal_journal_entry_id is null
      and posted_at is not null and posted_by is not null and reversed_at is null and reversed_by is null)
    or (status = 'REVERSED' and posted_journal_entry_id is not null and reversal_journal_entry_id is not null
      and posted_at is not null and posted_by is not null and reversed_at is not null and reversed_by is not null)
  )
);

create index custody_advances_company_date_idx
  on public.custody_advances (company_id, advance_date desc, id);
create index custody_advances_custodian_idx
  on public.custody_advances (company_id, custodian_id, advance_date desc);
create index custody_advances_project_idx
  on public.custody_advances (company_id, project_id) where project_id is not null;

create function private.custody_balance_minor(
  target_company_id uuid,
  target_custodian_id uuid
)
returns numeric
language sql
stable
security definer
set search_path = ''
as $$
  select coalesce(sum(l.debit_minor::numeric - l.credit_minor::numeric), 0)
  from public.journal_lines l
  join public.accounts a on a.company_id = l.company_id and a.id = l.account_id
  where l.company_id = target_company_id
    and l.party_id = target_custodian_id
    and a.system_key = 'CUSTODY_ADVANCE'
$$;

create function private.protect_custody_advance_history()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'Custody Advance history cannot be deleted; reverse posted accounting'
      using errcode = '55000';
  end if;
  if new.company_id <> old.company_id
     or new.advance_reference <> old.advance_reference
     or new.advance_date <> old.advance_date
     or new.custodian_id <> old.custodian_id
     or new.treasury_account_id <> old.treasury_account_id
     or new.project_id is distinct from old.project_id
     or new.amount_minor <> old.amount_minor
     or new.payment_method <> old.payment_method
     or new.external_reference is distinct from old.external_reference
     or new.notes is distinct from old.notes
     or new.created_at <> old.created_at
     or new.created_by is distinct from old.created_by then
    raise exception 'Posted Custody Advance economics and provenance are immutable'
      using errcode = '55000';
  end if;
  if old.status = 'DRAFT' then
    if new.status <> 'POSTED' or new.posted_journal_entry_id is null
       or new.reversal_journal_entry_id is not null then
      raise exception 'Custody Advance may transition only from DRAFT to POSTED'
        using errcode = '55000';
    end if;
  elsif old.status = 'POSTED' then
    if new.status <> 'REVERSED'
       or new.posted_journal_entry_id <> old.posted_journal_entry_id
       or new.reversal_journal_entry_id is null then
      raise exception 'Posted Custody Advance may transition only to REVERSED with a linked journal'
        using errcode = '55000';
    end if;
  else
    raise exception 'Reversed Custody Advance is immutable' using errcode = '55000';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger custody_advances_protect_history
  before update or delete on public.custody_advances
  for each row execute function private.protect_custody_advance_history();

alter table public.custody_advances enable row level security;
alter table public.custody_advances force row level security;
create policy custody_advances_read_accounting on public.custody_advances
  for select to authenticated using (
    public.has_company_role(company_id, 'ACCOUNTING_ADMIN')
    or public.has_company_role(company_id, 'ACCOUNTANT')
    or public.has_company_role(company_id, 'MANAGEMENT_VIEWER')
  );
revoke all on table public.custody_advances from public, anon, authenticated, service_role;
grant select on table public.custody_advances to authenticated, service_role;

create function public.post_custody_advance(
  target_company_id uuid,
  target_advance_date date,
  target_custodian_id uuid,
  target_treasury_account_id uuid,
  target_project_id uuid,
  target_amount_minor bigint,
  target_payment_method public.payment_method,
  target_external_reference text,
  target_notes text,
  target_idempotency_key uuid
)
returns table (custody_advance_id uuid, advance_reference text, journal_entry_id uuid, replayed boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  normalized_external_reference text := nullif(btrim(target_external_reference), '');
  normalized_notes text := nullif(btrim(target_notes), '');
  project_row public.projects;
  treasury_row public.treasury_accounts;
  custody_account_id uuid;
  request_hash text;
  request_row private.financial_command_requests;
  new_advance_id uuid := gen_random_uuid();
  new_advance_reference text;
  new_journal_id uuid;
  journal_lines jsonb;
begin
  if actor_id is null or not public.has_permission(target_company_id, 'accounting.post') then
    raise exception 'Not authorized to post Custody Advances' using errcode = '42501';
  end if;
  if target_company_id is null or target_advance_date is null or target_custodian_id is null
     or target_treasury_account_id is null or target_amount_minor is null
     or target_payment_method is null or target_idempotency_key is null then
    raise exception 'Required Custody Advance input is missing' using errcode = '22023';
  end if;
  if target_amount_minor not between 1 and 9000000000000000 then
    raise exception 'Custody Advance amount is invalid' using errcode = '22023';
  end if;
  if normalized_external_reference is not null and length(normalized_external_reference) > 200 then
    raise exception 'External reference is too long' using errcode = '22023';
  end if;
  if normalized_notes is not null and length(normalized_notes) > 2000 then
    raise exception 'Custody Advance notes are too long' using errcode = '22023';
  end if;

  perform 1 from public.parties p
  where p.company_id = target_company_id and p.id = target_custodian_id
    and p.type = 'CUSTODIAN' and p.status = 'ACTIVE' for update;
  if not found then raise exception 'Active Custodian not found in company' using errcode = '23503'; end if;
  if target_project_id is not null then
    select p.* into project_row from public.projects p
    where p.company_id = target_company_id and p.id = target_project_id;
    if not found then raise exception 'Project not found in company' using errcode = '23503'; end if;
    if project_row.status = 'CLOSED' then
      raise exception 'Closed Project cannot receive a new Custody Advance' using errcode = '23514';
    end if;
  end if;
  select t.* into treasury_row from public.treasury_accounts t
  join public.accounts a on a.company_id = t.company_id and a.id = t.gl_account_id
  where t.company_id = target_company_id and t.id = target_treasury_account_id
    and t.status = 'ACTIVE' and a.status = 'ACTIVE' and a.account_type = 'ASSET';
  if not found then
    raise exception 'Active same-company Treasury with active Asset GL is required' using errcode = '23514';
  end if;
  if treasury_row.project_id is not null
     and treasury_row.project_id is distinct from target_project_id then
    raise exception 'Project Treasury may fund only its own Project custody'
      using errcode = '23514';
  end if;
  select a.id into custody_account_id from public.accounts a
  where a.company_id = target_company_id and a.system_key = 'CUSTODY_ADVANCE'
    and a.status = 'ACTIVE' and a.account_type = 'ASSET' and a.requires_party;
  if custody_account_id is null then
    raise exception 'Custody Advance system account is unavailable' using errcode = '23514';
  end if;

  request_hash := encode(extensions.digest(convert_to(jsonb_build_object(
    'company_id', target_company_id, 'advance_date', target_advance_date,
    'custodian_id', target_custodian_id, 'treasury_id', target_treasury_account_id,
    'project_id', target_project_id, 'amount_minor', target_amount_minor,
    'payment_method', target_payment_method, 'external_reference', normalized_external_reference,
    'notes', normalized_notes
  )::text, 'UTF8'), 'sha256'), 'hex');
  request_row := private.reserve_financial_command(
    target_company_id, 'POST_CUSTODY_ADVANCE', target_idempotency_key, request_hash, actor_id
  );
  if request_row.status = 'COMPLETED' then
    return query select a.id, a.advance_reference, a.posted_journal_entry_id, true
    from public.custody_advances a where a.company_id = target_company_id
      and a.posted_journal_entry_id = request_row.resulting_journal_entry_id;
    return;
  end if;

  new_advance_reference := private.allocate_reference(
    target_company_id, 'CADV', extract(year from target_advance_date)::integer
  );
  insert into public.custody_advances (
    id, company_id, advance_reference, advance_date, custodian_id, treasury_account_id,
    project_id, amount_minor, payment_method, external_reference, notes, created_by, updated_by
  ) values (
    new_advance_id, target_company_id, new_advance_reference, target_advance_date,
    target_custodian_id, target_treasury_account_id, target_project_id, target_amount_minor,
    target_payment_method, normalized_external_reference, normalized_notes, actor_id, actor_id
  );
  journal_lines := jsonb_build_array(
    jsonb_build_object(
      'account_id', custody_account_id, 'debit_minor', target_amount_minor, 'credit_minor', 0,
      'project_id', target_project_id, 'party_id', target_custodian_id,
      'memo', 'Custody funded'
    ),
    jsonb_build_object(
      'account_id', treasury_row.gl_account_id, 'debit_minor', 0, 'credit_minor', target_amount_minor,
      'project_id', target_project_id, 'treasury_account_id', target_treasury_account_id,
      'memo', 'Custody Advance treasury funding'
    )
  );
  new_journal_id := private.create_journal(
    target_company_id, target_advance_date, 'Custody Advance ' || new_advance_reference,
    'CUSTODY_ADVANCE', new_advance_id, 'ORIGINAL', journal_lines, actor_id, null
  );
  update public.custody_advances set status = 'POSTED', posted_journal_entry_id = new_journal_id,
    posted_at = now(), posted_by = actor_id, updated_by = actor_id where id = new_advance_id;
  perform private.complete_financial_command(request_row.id, new_journal_id);
  return query select new_advance_id, new_advance_reference, new_journal_id, false;
end;
$$;

create function public.reverse_custody_advance(
  target_company_id uuid,
  target_custody_advance_id uuid,
  target_reversal_date date,
  target_reason text,
  target_idempotency_key uuid
)
returns table (custody_advance_id uuid, advance_reference text, reversal_journal_entry_id uuid, replayed boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare
  actor_id uuid := auth.uid();
  normalized_reason text := btrim(target_reason);
  request_hash text;
  request_row private.financial_command_requests;
  advance_row public.custody_advances;
  available_balance numeric;
  new_reversal_id uuid;
begin
  if actor_id is null or not public.has_permission(target_company_id, 'accounting.reverse') then
    raise exception 'Not authorized to reverse Custody Advances' using errcode = '42501';
  end if;
  if target_company_id is null or target_custody_advance_id is null or target_reversal_date is null
     or target_idempotency_key is null or normalized_reason is null
     or length(normalized_reason) not between 1 and 1000 then
    raise exception 'Valid Custody Advance reversal inputs are required' using errcode = '22023';
  end if;
  request_hash := encode(extensions.digest(convert_to(jsonb_build_object(
    'company_id', target_company_id, 'custody_advance_id', target_custody_advance_id,
    'reversal_date', target_reversal_date, 'reason', normalized_reason
  )::text, 'UTF8'), 'sha256'), 'hex');
  request_row := private.reserve_financial_command(
    target_company_id, 'REVERSE_CUSTODY_ADVANCE', target_idempotency_key, request_hash, actor_id
  );
  if request_row.status = 'COMPLETED' then
    return query select a.id, a.advance_reference, a.reversal_journal_entry_id, true
    from public.custody_advances a where a.company_id = target_company_id
      and a.reversal_journal_entry_id = request_row.resulting_journal_entry_id;
    return;
  end if;
  select a.* into advance_row from public.custody_advances a
  where a.company_id = target_company_id and a.id = target_custody_advance_id for update;
  if not found then raise exception 'Custody Advance not found in company' using errcode = '23503'; end if;
  if advance_row.status <> 'POSTED' then
    raise exception 'Only a posted Custody Advance can be reversed' using errcode = '23514';
  end if;
  perform 1 from public.parties p
  where p.company_id = target_company_id and p.id = advance_row.custodian_id for update;
  if not found then raise exception 'Custodian not found in company' using errcode = '23503'; end if;
  available_balance := private.custody_balance_minor(target_company_id, advance_row.custodian_id);
  if available_balance < advance_row.amount_minor::numeric then
    raise exception 'Custody Advance cannot be reversed after its pooled balance was consumed'
      using errcode = '23514';
  end if;
  new_reversal_id := private.reverse_journal(
    advance_row.posted_journal_entry_id, target_reversal_date,
    'Reversal of ' || advance_row.advance_reference || ': ' || normalized_reason, actor_id
  );
  update public.custody_advances set status = 'REVERSED', reversal_journal_entry_id = new_reversal_id,
    reversed_at = now(), reversed_by = actor_id, updated_by = actor_id where id = advance_row.id;
  perform private.complete_financial_command(request_row.id, new_reversal_id);
  return query select advance_row.id, advance_row.advance_reference, new_reversal_id, false;
end;
$$;

-- Forward-only P5B hardening: move the applied implementation to private and
-- expose a compatible wrapper that serializes/checks pooled Custodian balance.
revoke execute on function public.post_expense(uuid, date, uuid, uuid, text, bigint,
  public.expense_vat_mode, bigint, public.expense_funding_mode, uuid, uuid, uuid,
  public.payment_method, boolean, text, text, uuid) from authenticated;
alter function public.post_expense(uuid, date, uuid, uuid, text, bigint,
  public.expense_vat_mode, bigint, public.expense_funding_mode, uuid, uuid, uuid,
  public.payment_method, boolean, text, text, uuid) set schema private;
revoke all on function private.post_expense(uuid, date, uuid, uuid, text, bigint,
  public.expense_vat_mode, bigint, public.expense_funding_mode, uuid, uuid, uuid,
  public.payment_method, boolean, text, text, uuid) from public, anon, authenticated, service_role;

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
  requested_vat numeric;
  requested_gross numeric;
  available_balance numeric;
begin
  if target_funding_mode = 'CUSTODIAN' then
    if actor_id is null or not public.has_permission(target_company_id, 'accounting.post') then
      raise exception 'Not authorized to post expenses' using errcode = '42501';
    end if;
    perform 1 from public.parties p
    where p.company_id = target_company_id and p.id = target_paid_by_party_id
      and p.type = 'CUSTODIAN' for update;
    if not found then raise exception 'Custodian not found in company' using errcode = '23503'; end if;
    requested_vat := case target_vat_mode
      when 'ZERO' then 0
      when 'AUTO_5' then round(target_net_amount_minor::numeric * 5 / 100)
      when 'MANUAL' then target_manual_vat_amount_minor::numeric
    end;
    requested_gross := target_net_amount_minor::numeric + requested_vat;
    available_balance := private.custody_balance_minor(target_company_id, target_paid_by_party_id);
    if requested_gross > available_balance then
      raise exception 'Custodian Expense exceeds available pooled Custody balance'
        using errcode = '23514';
    end if;
  end if;
  return query select * from private.post_expense(
    target_company_id, target_expense_date, target_project_id, target_expense_category_id,
    target_description, target_net_amount_minor, target_vat_mode, target_manual_vat_amount_minor,
    target_funding_mode, target_treasury_account_id, target_paid_by_party_id, target_supplier_id,
    target_payment_method, target_has_tax_invoice, target_invoice_number, target_notes,
    target_idempotency_key
  );
end;
$$;

revoke all on function private.custody_balance_minor(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function private.protect_custody_advance_history()
  from public, anon, authenticated, service_role;
revoke all on function public.post_custody_advance(uuid, date, uuid, uuid, uuid, bigint,
  public.payment_method, text, text, uuid) from public, anon, authenticated, service_role;
revoke all on function public.reverse_custody_advance(uuid, uuid, date, text, uuid)
  from public, anon, authenticated, service_role;
revoke all on function public.post_expense(uuid, date, uuid, uuid, text, bigint,
  public.expense_vat_mode, bigint, public.expense_funding_mode, uuid, uuid, uuid,
  public.payment_method, boolean, text, text, uuid) from public, anon, authenticated, service_role;
grant execute on function public.post_custody_advance(uuid, date, uuid, uuid, uuid, bigint,
  public.payment_method, text, text, uuid) to authenticated;
grant execute on function public.reverse_custody_advance(uuid, uuid, date, text, uuid)
  to authenticated;
grant execute on function public.post_expense(uuid, date, uuid, uuid, text, bigint,
  public.expense_vat_mode, bigint, public.expense_funding_mode, uuid, uuid, uuid,
  public.payment_method, boolean, text, text, uuid) to authenticated;

comment on table public.custody_advances is
  'P5D immutable Treasury-funded Custody Advances. Funding is an Asset movement, never cost.';
comment on function private.custody_balance_minor(uuid, uuid) is
  'Authoritative pooled company/Custodian control-account balance across advances, Custodian Expenses, future returns, and reversals.';
comment on function public.post_expense(uuid, date, uuid, uuid, text, bigint,
  public.expense_vat_mode, bigint, public.expense_funding_mode, uuid, uuid, uuid,
  public.payment_method, boolean, text, text, uuid) is
  'P5B Expense command with P5D pooled Custodian balance locking and overspend protection.';
