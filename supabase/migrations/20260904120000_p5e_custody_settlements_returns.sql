-- P5E: operational Custody Settlements and financial Custody Cash Returns.
-- Custody remains pooled by company + Custodian. Settlement finalization
-- groups already-posted Expenses and deliberately creates no journal.

create type public.custody_settlement_status as enum ('DRAFT', 'FINALIZED');

create table public.custody_settlements (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  settlement_reference text not null check (length(btrim(settlement_reference)) between 1 and 100),
  settlement_date date not null,
  custodian_id uuid not null,
  notes text check (notes is null or length(btrim(notes)) between 1 and 2000),
  status public.custody_settlement_status not null default 'DRAFT',
  total_expenses_minor bigint not null check (total_expenses_minor between 1 and 9000000000000000),
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users (id) on delete restrict,
  finalized_at timestamptz,
  finalized_by uuid references auth.users (id) on delete restrict,
  constraint custody_settlements_company_id_id_unique unique (company_id, id),
  constraint custody_settlements_company_reference_unique unique (company_id, settlement_reference),
  constraint custody_settlements_custodian_same_company foreign key (company_id, custodian_id)
    references public.parties (company_id, id) on delete restrict,
  constraint custody_settlements_state_shape check (
    (status = 'DRAFT' and finalized_at is null and finalized_by is null)
    or (status = 'FINALIZED' and finalized_at is not null and finalized_by is not null)
  )
);

create table public.custody_settlement_items (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  settlement_id uuid not null,
  expense_id uuid not null,
  expense_amount_minor bigint not null check (expense_amount_minor between 1 and 9000000000000000),
  created_at timestamptz not null default now(),
  constraint custody_settlement_items_company_id_id_unique unique (company_id, id),
  constraint custody_settlement_items_settlement_expense_unique unique (settlement_id, expense_id),
  constraint custody_settlement_items_expense_unique unique (expense_id),
  constraint custody_settlement_items_settlement_same_company foreign key (company_id, settlement_id)
    references public.custody_settlements (company_id, id) on delete restrict,
  constraint custody_settlement_items_expense_same_company foreign key (company_id, expense_id)
    references public.expenses (company_id, id) on delete restrict
);

create index custody_settlements_custodian_date_idx
  on public.custody_settlements (company_id, custodian_id, settlement_date desc, id);
create index custody_settlement_items_company_expense_idx
  on public.custody_settlement_items (company_id, expense_id);

create table public.custody_cash_returns (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  return_reference text not null check (length(btrim(return_reference)) between 1 and 100),
  return_date date not null,
  custodian_id uuid not null,
  treasury_account_id uuid not null,
  amount_minor bigint not null check (amount_minor between 1 and 9000000000000000),
  payment_method public.payment_method not null,
  external_reference text check (external_reference is null or length(btrim(external_reference)) between 1 and 200),
  notes text check (notes is null or length(btrim(notes)) between 1 and 2000),
  status public.expense_status not null default 'DRAFT',
  posted_journal_entry_id uuid,
  reversal_journal_entry_id uuid,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users (id) on delete restrict,
  updated_at timestamptz not null default now(),
  updated_by uuid not null references auth.users (id) on delete restrict,
  posted_at timestamptz,
  posted_by uuid references auth.users (id) on delete restrict,
  reversed_at timestamptz,
  reversed_by uuid references auth.users (id) on delete restrict,
  constraint custody_cash_returns_company_id_id_unique unique (company_id, id),
  constraint custody_cash_returns_company_reference_unique unique (company_id, return_reference),
  constraint custody_cash_returns_custodian_same_company foreign key (company_id, custodian_id)
    references public.parties (company_id, id) on delete restrict,
  constraint custody_cash_returns_treasury_same_company foreign key (company_id, treasury_account_id)
    references public.treasury_accounts (company_id, id) on delete restrict,
  constraint custody_cash_returns_posted_journal_same_company foreign key (company_id, posted_journal_entry_id)
    references public.journal_entries (company_id, id) on delete restrict,
  constraint custody_cash_returns_reversal_journal_same_company foreign key (company_id, reversal_journal_entry_id)
    references public.journal_entries (company_id, id) on delete restrict,
  constraint custody_cash_returns_posted_journal_unique unique (posted_journal_entry_id),
  constraint custody_cash_returns_reversal_journal_unique unique (reversal_journal_entry_id),
  constraint custody_cash_returns_state_shape check (
    (status = 'DRAFT' and posted_journal_entry_id is null and reversal_journal_entry_id is null
      and posted_at is null and posted_by is null and reversed_at is null and reversed_by is null)
    or (status = 'POSTED' and posted_journal_entry_id is not null and reversal_journal_entry_id is null
      and posted_at is not null and posted_by is not null and reversed_at is null and reversed_by is null)
    or (status = 'REVERSED' and posted_journal_entry_id is not null and reversal_journal_entry_id is not null
      and posted_at is not null and posted_by is not null and reversed_at is not null and reversed_by is not null)
  )
);

create index custody_cash_returns_custodian_date_idx
  on public.custody_cash_returns (company_id, custodian_id, return_date desc, id);

create function private.protect_custody_settlement_history()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'Custody Settlement history cannot be deleted' using errcode = '55000';
  end if;
  if new.company_id <> old.company_id or new.settlement_reference <> old.settlement_reference
     or new.settlement_date <> old.settlement_date or new.custodian_id <> old.custodian_id
     or new.notes is distinct from old.notes or new.total_expenses_minor <> old.total_expenses_minor
     or new.created_at <> old.created_at or new.created_by <> old.created_by then
    raise exception 'Custody Settlement provenance is immutable' using errcode = '55000';
  end if;
  if old.status <> 'DRAFT' or new.status <> 'FINALIZED'
     or new.finalized_at is null or new.finalized_by is null then
    raise exception 'Custody Settlement may transition only from DRAFT to FINALIZED'
      using errcode = '55000';
  end if;
  return new;
end;
$$;

create function private.protect_custody_settlement_item_history()
returns trigger language plpgsql set search_path = '' as $$
begin
  raise exception 'Custody Settlement items are immutable' using errcode = '55000';
end;
$$;

create function private.validate_custody_settlement_item()
returns trigger language plpgsql security definer set search_path = '' as $$
declare settlement_row public.custody_settlements; expense_row public.expenses;
begin
  select s.* into settlement_row from public.custody_settlements s
  where s.company_id = new.company_id and s.id = new.settlement_id for update;
  if not found or settlement_row.status <> 'DRAFT' then
    raise exception 'Settlement item requires a same-company DRAFT Settlement' using errcode = '23514';
  end if;
  select e.* into expense_row from public.expenses e
  where e.company_id = new.company_id and e.id = new.expense_id for update;
  if not found or expense_row.status <> 'POSTED' or expense_row.funding_mode <> 'CUSTODIAN'
     or expense_row.paid_by_party_id is distinct from settlement_row.custodian_id then
    raise exception 'Expense is not eligible for this Custody Settlement' using errcode = '23514';
  end if;
  if new.expense_amount_minor <> expense_row.gross_amount_minor then
    raise exception 'Settlement item amount must equal authoritative Expense gross' using errcode = '23514';
  end if;
  return new;
end;
$$;

create function private.protect_custody_cash_return_history()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'Custody Cash Return history cannot be deleted' using errcode = '55000';
  end if;
  if new.company_id <> old.company_id or new.return_reference <> old.return_reference
     or new.return_date <> old.return_date or new.custodian_id <> old.custodian_id
     or new.treasury_account_id <> old.treasury_account_id or new.amount_minor <> old.amount_minor
     or new.payment_method <> old.payment_method
     or new.external_reference is distinct from old.external_reference
     or new.notes is distinct from old.notes or new.created_at <> old.created_at
     or new.created_by <> old.created_by then
    raise exception 'Posted Custody Cash Return economics and provenance are immutable'
      using errcode = '55000';
  end if;
  if old.status = 'DRAFT' then
    if new.status <> 'POSTED' or new.posted_journal_entry_id is null
       or new.reversal_journal_entry_id is not null then
      raise exception 'Custody Cash Return may transition only from DRAFT to POSTED'
        using errcode = '55000';
    end if;
  elsif old.status = 'POSTED' then
    if new.status <> 'REVERSED' or new.posted_journal_entry_id <> old.posted_journal_entry_id
       or new.reversal_journal_entry_id is null then
      raise exception 'Posted Custody Cash Return may transition only to REVERSED'
        using errcode = '55000';
    end if;
  else
    raise exception 'Reversed Custody Cash Return is immutable' using errcode = '55000';
  end if;
  new.updated_at := now();
  return new;
end;
$$;

create trigger custody_settlements_protect_history before update or delete on public.custody_settlements
  for each row execute function private.protect_custody_settlement_history();
create trigger custody_settlement_items_validate before insert on public.custody_settlement_items
  for each row execute function private.validate_custody_settlement_item();
create trigger custody_settlement_items_protect before update or delete on public.custody_settlement_items
  for each row execute function private.protect_custody_settlement_item_history();
create trigger custody_cash_returns_protect_history before update or delete on public.custody_cash_returns
  for each row execute function private.protect_custody_cash_return_history();

alter table public.custody_settlements enable row level security;
alter table public.custody_settlements force row level security;
alter table public.custody_settlement_items enable row level security;
alter table public.custody_settlement_items force row level security;
alter table public.custody_cash_returns enable row level security;
alter table public.custody_cash_returns force row level security;

create policy custody_settlements_read_accounting on public.custody_settlements for select to authenticated using (
  public.has_company_role(company_id, 'ACCOUNTING_ADMIN') or public.has_company_role(company_id, 'ACCOUNTANT')
  or public.has_company_role(company_id, 'MANAGEMENT_VIEWER')
);
create policy custody_settlement_items_read_accounting on public.custody_settlement_items for select to authenticated using (
  public.has_company_role(company_id, 'ACCOUNTING_ADMIN') or public.has_company_role(company_id, 'ACCOUNTANT')
  or public.has_company_role(company_id, 'MANAGEMENT_VIEWER')
);
create policy custody_cash_returns_read_accounting on public.custody_cash_returns for select to authenticated using (
  public.has_company_role(company_id, 'ACCOUNTING_ADMIN') or public.has_company_role(company_id, 'ACCOUNTANT')
  or public.has_company_role(company_id, 'MANAGEMENT_VIEWER')
);

revoke all on table public.custody_settlements from public, anon, authenticated, service_role;
revoke all on table public.custody_settlement_items from public, anon, authenticated, service_role;
revoke all on table public.custody_cash_returns from public, anon, authenticated, service_role;
grant select on table public.custody_settlements to authenticated, service_role;
grant select on table public.custody_settlement_items to authenticated, service_role;
grant select on table public.custody_cash_returns to authenticated, service_role;

create function public.finalize_custody_settlement(
  target_company_id uuid,
  target_settlement_date date,
  target_custodian_id uuid,
  target_expense_ids uuid[],
  target_expected_total_minor bigint,
  target_notes text
)
returns table (custody_settlement_id uuid, settlement_reference text, total_expenses_minor bigint)
language plpgsql security definer set search_path = '' as $$
declare
  actor_id uuid := auth.uid(); normalized_notes text := nullif(btrim(target_notes), '');
  expense_id uuid; expense_row public.expenses; calculated_total numeric := 0;
  new_settlement_id uuid := gen_random_uuid(); new_reference text;
begin
  if actor_id is null or not public.has_permission(target_company_id, 'accounting.post') then
    raise exception 'Not authorized to finalize Custody Settlements' using errcode = '42501';
  end if;
  if target_company_id is null or target_settlement_date is null or target_custodian_id is null
     or target_expense_ids is null or cardinality(target_expense_ids) not between 1 and 999
     or target_expected_total_minor is null then
    raise exception 'Valid Custody Settlement inputs are required' using errcode = '22023';
  end if;
  if normalized_notes is not null and length(normalized_notes) > 2000 then
    raise exception 'Settlement notes are too long' using errcode = '22023';
  end if;
  if cardinality(target_expense_ids) <> (select count(distinct x) from unnest(target_expense_ids) x) then
    raise exception 'Settlement Expense list contains duplicates' using errcode = '22023';
  end if;
  perform 1 from public.parties p where p.company_id = target_company_id
    and p.id = target_custodian_id and p.type = 'CUSTODIAN' for update;
  if not found then raise exception 'Custodian not found in company' using errcode = '23503'; end if;
  foreach expense_id in array (select array_agg(x order by x) from unnest(target_expense_ids) x) loop
    select e.* into expense_row from public.expenses e
    where e.company_id = target_company_id and e.id = expense_id for update;
    if not found or expense_row.status <> 'POSTED' or expense_row.funding_mode <> 'CUSTODIAN'
       or expense_row.paid_by_party_id is distinct from target_custodian_id then
      raise exception 'Expense is not eligible for this Custody Settlement' using errcode = '23514';
    end if;
    if exists (select 1 from public.custody_settlement_items i where i.expense_id = expense_id) then
      raise exception 'Expense is already included in a finalized Custody Settlement' using errcode = '23514';
    end if;
    calculated_total := calculated_total + expense_row.gross_amount_minor::numeric;
  end loop;
  if calculated_total <> target_expected_total_minor::numeric or calculated_total not between 1 and 9000000000000000 then
    raise exception 'Expected Settlement total does not match authoritative Expense total' using errcode = '23514';
  end if;
  new_reference := private.allocate_reference(target_company_id, 'CSTL', extract(year from target_settlement_date)::integer);
  insert into public.custody_settlements (id, company_id, settlement_reference, settlement_date,
    custodian_id, notes, total_expenses_minor, created_by)
  values (new_settlement_id, target_company_id, new_reference, target_settlement_date,
    target_custodian_id, normalized_notes, calculated_total::bigint, actor_id);
  foreach expense_id in array target_expense_ids loop
    select e.* into expense_row from public.expenses e where e.id = expense_id;
    insert into public.custody_settlement_items (company_id, settlement_id, expense_id, expense_amount_minor)
    values (target_company_id, new_settlement_id, expense_id, expense_row.gross_amount_minor);
  end loop;
  update public.custody_settlements set status = 'FINALIZED', finalized_at = now(), finalized_by = actor_id
  where id = new_settlement_id;
  return query select new_settlement_id, new_reference, calculated_total::bigint;
end;
$$;

create function public.post_custody_cash_return(
  target_company_id uuid, target_return_date date, target_custodian_id uuid,
  target_treasury_account_id uuid, target_amount_minor bigint,
  target_payment_method public.payment_method, target_external_reference text,
  target_notes text, target_idempotency_key uuid
)
returns table (custody_cash_return_id uuid, return_reference text, journal_entry_id uuid, replayed boolean)
language plpgsql security definer set search_path = '' as $$
declare
  actor_id uuid := auth.uid(); normalized_external_reference text := nullif(btrim(target_external_reference), '');
  normalized_notes text := nullif(btrim(target_notes), ''); treasury_row public.treasury_accounts;
  custody_account_id uuid; available_balance numeric; request_hash text;
  request_row private.financial_command_requests; new_return_id uuid := gen_random_uuid();
  new_reference text; new_journal_id uuid; journal_lines jsonb;
begin
  if actor_id is null or not public.has_permission(target_company_id, 'accounting.post') then
    raise exception 'Not authorized to post Custody Cash Returns' using errcode = '42501';
  end if;
  if target_company_id is null or target_return_date is null or target_custodian_id is null
     or target_treasury_account_id is null or target_amount_minor is null
     or target_payment_method is null or target_idempotency_key is null then
    raise exception 'Required Custody Cash Return input is missing' using errcode = '22023';
  end if;
  if target_amount_minor not between 1 and 9000000000000000 then
    raise exception 'Custody Cash Return amount is invalid' using errcode = '22023';
  end if;
  if normalized_external_reference is not null and length(normalized_external_reference) > 200 then
    raise exception 'External reference is too long' using errcode = '22023';
  end if;
  if normalized_notes is not null and length(normalized_notes) > 2000 then
    raise exception 'Cash Return notes are too long' using errcode = '22023';
  end if;
  perform 1 from public.parties p where p.company_id = target_company_id
    and p.id = target_custodian_id and p.type = 'CUSTODIAN' for update;
  if not found then raise exception 'Custodian not found in company' using errcode = '23503'; end if;
  select t.* into treasury_row from public.treasury_accounts t
  join public.accounts a on a.company_id = t.company_id and a.id = t.gl_account_id
  where t.company_id = target_company_id and t.id = target_treasury_account_id
    and t.status = 'ACTIVE' and a.status = 'ACTIVE' and a.account_type = 'ASSET';
  if not found then raise exception 'Active same-company Treasury with active Asset GL is required' using errcode = '23514'; end if;
  available_balance := private.custody_balance_minor(target_company_id, target_custodian_id);
  if target_amount_minor::numeric > available_balance then
    raise exception 'Custody Cash Return exceeds available pooled Custody balance' using errcode = '23514';
  end if;
  select a.id into custody_account_id from public.accounts a where a.company_id = target_company_id
    and a.system_key = 'CUSTODY_ADVANCE' and a.status = 'ACTIVE'
    and a.account_type = 'ASSET' and a.requires_party;
  if custody_account_id is null then raise exception 'Custody Advance system account is unavailable' using errcode = '23514'; end if;
  request_hash := encode(extensions.digest(convert_to(jsonb_build_object(
    'company_id',target_company_id,'return_date',target_return_date,'custodian_id',target_custodian_id,
    'treasury_id',target_treasury_account_id,'amount_minor',target_amount_minor,
    'payment_method',target_payment_method,'external_reference',normalized_external_reference,'notes',normalized_notes
  )::text,'UTF8'),'sha256'),'hex');
  request_row := private.reserve_financial_command(target_company_id,'POST_CUSTODY_CASH_RETURN',
    target_idempotency_key,request_hash,actor_id);
  if request_row.status = 'COMPLETED' then
    return query select r.id,r.return_reference,r.posted_journal_entry_id,true from public.custody_cash_returns r
    where r.company_id=target_company_id and r.posted_journal_entry_id=request_row.resulting_journal_entry_id;
    return;
  end if;
  new_reference := private.allocate_reference(target_company_id,'CRET',extract(year from target_return_date)::integer);
  insert into public.custody_cash_returns (id,company_id,return_reference,return_date,custodian_id,
    treasury_account_id,amount_minor,payment_method,external_reference,notes,created_by,updated_by)
  values (new_return_id,target_company_id,new_reference,target_return_date,target_custodian_id,
    target_treasury_account_id,target_amount_minor,target_payment_method,normalized_external_reference,
    normalized_notes,actor_id,actor_id);
  journal_lines := jsonb_build_array(
    jsonb_build_object('account_id',treasury_row.gl_account_id,'debit_minor',target_amount_minor,'credit_minor',0,
      'treasury_account_id',target_treasury_account_id,'memo','Custody cash returned to Treasury'),
    jsonb_build_object('account_id',custody_account_id,'debit_minor',0,'credit_minor',target_amount_minor,
      'party_id',target_custodian_id,'memo','Custody Cash Return')
  );
  new_journal_id := private.create_journal(target_company_id,target_return_date,
    'Custody Cash Return '||new_reference,'CUSTODY_CASH_RETURN',new_return_id,'ORIGINAL',journal_lines,actor_id,null);
  update public.custody_cash_returns set status='POSTED',posted_journal_entry_id=new_journal_id,
    posted_at=now(),posted_by=actor_id,updated_by=actor_id where id=new_return_id;
  perform private.complete_financial_command(request_row.id,new_journal_id);
  return query select new_return_id,new_reference,new_journal_id,false;
end;
$$;

create function public.reverse_custody_cash_return(
  target_company_id uuid, target_custody_cash_return_id uuid, target_reversal_date date,
  target_reason text, target_idempotency_key uuid
)
returns table (custody_cash_return_id uuid, return_reference text, reversal_journal_entry_id uuid, replayed boolean)
language plpgsql security definer set search_path = '' as $$
declare
  actor_id uuid := auth.uid(); normalized_reason text := btrim(target_reason); request_hash text;
  request_row private.financial_command_requests; return_row public.custody_cash_returns; new_reversal_id uuid;
begin
  if actor_id is null or not public.has_permission(target_company_id,'accounting.reverse') then
    raise exception 'Not authorized to reverse Custody Cash Returns' using errcode = '42501';
  end if;
  if target_company_id is null or target_custody_cash_return_id is null or target_reversal_date is null
     or target_idempotency_key is null or normalized_reason is null or length(normalized_reason) not between 1 and 1000 then
    raise exception 'Valid Custody Cash Return reversal inputs are required' using errcode = '22023';
  end if;
  request_hash := encode(extensions.digest(convert_to(jsonb_build_object(
    'company_id',target_company_id,'cash_return_id',target_custody_cash_return_id,
    'reversal_date',target_reversal_date,'reason',normalized_reason
  )::text,'UTF8'),'sha256'),'hex');
  request_row := private.reserve_financial_command(target_company_id,'REVERSE_CUSTODY_CASH_RETURN',
    target_idempotency_key,request_hash,actor_id);
  if request_row.status='COMPLETED' then
    return query select r.id,r.return_reference,r.reversal_journal_entry_id,true from public.custody_cash_returns r
    where r.company_id=target_company_id and r.reversal_journal_entry_id=request_row.resulting_journal_entry_id;
    return;
  end if;
  select r.* into return_row from public.custody_cash_returns r
  where r.company_id=target_company_id and r.id=target_custody_cash_return_id for update;
  if not found then raise exception 'Custody Cash Return not found in company' using errcode = '23503'; end if;
  if return_row.status <> 'POSTED' then raise exception 'Only a posted Custody Cash Return can be reversed' using errcode = '23514'; end if;
  perform 1 from public.parties p where p.company_id=target_company_id and p.id=return_row.custodian_id for update;
  if not found then raise exception 'Custodian not found in company' using errcode = '23503'; end if;
  new_reversal_id := private.reverse_journal(return_row.posted_journal_entry_id,target_reversal_date,
    'Reversal of '||return_row.return_reference||': '||normalized_reason,actor_id);
  update public.custody_cash_returns set status='REVERSED',reversal_journal_entry_id=new_reversal_id,
    reversed_at=now(),reversed_by=actor_id,updated_by=actor_id where id=return_row.id;
  perform private.complete_financial_command(request_row.id,new_reversal_id);
  return query select return_row.id,return_row.return_reference,new_reversal_id,false;
end;
$$;

revoke all on function private.protect_custody_settlement_history() from public,anon,authenticated,service_role;
revoke all on function private.protect_custody_settlement_item_history() from public,anon,authenticated,service_role;
revoke all on function private.validate_custody_settlement_item() from public,anon,authenticated,service_role;
revoke all on function private.protect_custody_cash_return_history() from public,anon,authenticated,service_role;
revoke all on function public.finalize_custody_settlement(uuid,date,uuid,uuid[],bigint,text) from public,anon,authenticated,service_role;
revoke all on function public.post_custody_cash_return(uuid,date,uuid,uuid,bigint,public.payment_method,text,text,uuid) from public,anon,authenticated,service_role;
revoke all on function public.reverse_custody_cash_return(uuid,uuid,date,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.finalize_custody_settlement(uuid,date,uuid,uuid[],bigint,text) to authenticated;
grant execute on function public.post_custody_cash_return(uuid,date,uuid,uuid,bigint,public.payment_method,text,text,uuid) to authenticated;
grant execute on function public.reverse_custody_cash_return(uuid,uuid,date,text,uuid) to authenticated;

comment on table public.custody_settlements is 'P5E operational grouping of already-posted Custodian Expenses; finalization creates no journal.';
comment on table public.custody_settlement_items is 'Immutable P5E Expense provenance; one Expense may belong to only one finalized Settlement.';
comment on table public.custody_cash_returns is 'P5E Treasury-only return of pooled Custodian cash: Dr Treasury / Cr Custody control.';
