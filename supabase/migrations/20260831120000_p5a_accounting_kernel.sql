-- P5A: immutable journal core and private accounting kernel.
-- No browser-callable posting command or business transaction table is added.

create table private.reference_counters (
  company_id uuid not null references public.companies (id) on delete restrict,
  reference_type text not null check (reference_type ~ '^[A-Z][A-Z0-9_]{1,11}$'),
  fiscal_year integer not null check (fiscal_year between 2000 and 9999),
  last_value bigint not null check (last_value > 0),
  primary key (company_id, reference_type, fiscal_year)
);

create table public.journal_entries (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  journal_reference text not null check (length(btrim(journal_reference)) between 1 and 100),
  posting_date date not null,
  description text not null check (length(btrim(description)) between 1 and 1000),
  source_type text not null check (source_type ~ '^[A-Z][A-Z0-9_]{1,49}$'),
  source_id uuid not null,
  posting_purpose text not null check (posting_purpose ~ '^[A-Z][A-Z0-9_]{1,49}$'),
  reversal_of_journal_entry_id uuid,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete restrict,
  posted_at timestamptz not null default now(),
  constraint journal_entries_company_id_id_unique unique (company_id, id),
  constraint journal_entries_company_reference_unique unique (company_id, journal_reference),
  constraint journal_entries_source_posting_unique
    unique (company_id, source_type, source_id, posting_purpose),
  constraint journal_entries_reversal_same_company foreign key
    (company_id, reversal_of_journal_entry_id)
    references public.journal_entries (company_id, id) on delete restrict,
  constraint journal_entries_not_self_reversal
    check (reversal_of_journal_entry_id is null or reversal_of_journal_entry_id <> id),
  constraint journal_entries_one_reversal_per_original unique (reversal_of_journal_entry_id)
);

alter table public.treasury_accounts
  add constraint treasury_accounts_company_id_id_unique unique (company_id, id);
alter table public.subcontracts
  add constraint subcontracts_company_id_id_project_id_unique unique (company_id, id, project_id);

create table public.journal_lines (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  journal_entry_id uuid not null,
  line_number smallint not null check (line_number > 0),
  account_id uuid not null,
  debit_minor bigint not null default 0,
  credit_minor bigint not null default 0,
  project_id uuid,
  party_id uuid,
  treasury_account_id uuid,
  subcontract_id uuid,
  memo text check (memo is null or length(btrim(memo)) between 1 and 500),
  created_at timestamptz not null default now(),
  constraint journal_lines_entry_same_company foreign key (company_id, journal_entry_id)
    references public.journal_entries (company_id, id) on delete restrict,
  constraint journal_lines_account_same_company foreign key (company_id, account_id)
    references public.accounts (company_id, id) on delete restrict,
  constraint journal_lines_project_same_company foreign key (company_id, project_id)
    references public.projects (company_id, id) on delete restrict,
  constraint journal_lines_party_same_company foreign key (company_id, party_id)
    references public.parties (company_id, id) on delete restrict,
  constraint journal_lines_treasury_same_company foreign key (company_id, treasury_account_id)
    references public.treasury_accounts (company_id, id) on delete restrict,
  constraint journal_lines_subcontract_project_same_company foreign key
    (company_id, subcontract_id, project_id)
    references public.subcontracts (company_id, id, project_id) on delete restrict,
  constraint journal_lines_entry_line_unique unique (journal_entry_id, line_number),
  constraint journal_lines_exactly_one_side check (
    (debit_minor > 0 and credit_minor = 0)
    or (credit_minor > 0 and debit_minor = 0)
  ),
  constraint journal_lines_debit_safe_bound check (debit_minor between 0 and 9000000000000000),
  constraint journal_lines_credit_safe_bound check (credit_minor between 0 and 9000000000000000),
  constraint journal_lines_subcontract_requires_project check (subcontract_id is null or project_id is not null)
);

create index journal_entries_company_posting_date_idx
  on public.journal_entries (company_id, posting_date desc, id);
create index journal_entries_source_idx
  on public.journal_entries (company_id, source_type, source_id);
create index journal_lines_account_idx on public.journal_lines (company_id, account_id);
create index journal_lines_project_idx
  on public.journal_lines (company_id, project_id) where project_id is not null;
create index journal_lines_party_idx
  on public.journal_lines (company_id, party_id) where party_id is not null;
create index journal_lines_subcontract_idx
  on public.journal_lines (company_id, subcontract_id) where subcontract_id is not null;

create table private.financial_command_requests (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  command_type text not null check (command_type ~ '^[A-Z][A-Z0-9_]{1,49}$'),
  idempotency_key uuid not null,
  request_hash bytea not null check (octet_length(request_hash) = 32),
  status text not null default 'PENDING' check (status in ('PENDING', 'COMPLETED')),
  resulting_journal_entry_id uuid,
  actor_user_id uuid references auth.users (id) on delete restrict,
  created_at timestamptz not null default now(),
  completed_at timestamptz,
  constraint financial_command_requests_scope_unique
    unique (company_id, command_type, idempotency_key),
  constraint financial_command_requests_result_same_company foreign key
    (company_id, resulting_journal_entry_id)
    references public.journal_entries (company_id, id) on delete restrict,
  constraint financial_command_requests_status_shape check (
    (status = 'PENDING' and completed_at is null)
    or (status = 'COMPLETED' and completed_at is not null and resulting_journal_entry_id is not null)
  )
);

create function private.allocate_reference(
  target_company_id uuid,
  target_reference_type text,
  target_fiscal_year integer
)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_type text := upper(btrim(target_reference_type));
  company_code text;
  allocated_value bigint;
begin
  if normalized_type !~ '^[A-Z][A-Z0-9_]{1,11}$' then
    raise exception 'Invalid reference type' using errcode = '22023';
  end if;
  if target_fiscal_year not between 2000 and 9999 then
    raise exception 'Invalid fiscal year' using errcode = '22023';
  end if;

  select btrim(c.code) into company_code
  from public.companies c where c.id = target_company_id;
  if company_code is null then
    raise exception 'Unknown company' using errcode = '23503';
  end if;

  insert into private.reference_counters (company_id, reference_type, fiscal_year, last_value)
  values (target_company_id, normalized_type, target_fiscal_year, 1)
  on conflict (company_id, reference_type, fiscal_year)
  do update set last_value = private.reference_counters.last_value + 1
  returning last_value into allocated_value;

  return company_code || '-' || normalized_type || '-' || target_fiscal_year::text || '-' ||
    lpad(allocated_value::text, 6, '0');
end;
$$;

create function private.reserve_financial_command(
  target_company_id uuid,
  target_command_type text,
  target_idempotency_key uuid,
  target_request_hash_hex text,
  target_actor_user_id uuid default null
)
returns private.financial_command_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  normalized_type text := upper(btrim(target_command_type));
  decoded_hash bytea;
  reserved private.financial_command_requests;
begin
  if normalized_type !~ '^[A-Z][A-Z0-9_]{1,49}$' then
    raise exception 'Invalid command type' using errcode = '22023';
  end if;
  if target_request_hash_hex !~ '^[0-9a-f]{64}$' then
    raise exception 'Request hash must be lowercase hexadecimal SHA-256' using errcode = '22023';
  end if;
  decoded_hash := decode(target_request_hash_hex, 'hex');

  insert into private.financial_command_requests
    (company_id, command_type, idempotency_key, request_hash, actor_user_id)
  values
    (target_company_id, normalized_type, target_idempotency_key, decoded_hash, target_actor_user_id)
  on conflict (company_id, command_type, idempotency_key) do nothing;

  select r.* into reserved
  from private.financial_command_requests r
  where r.company_id = target_company_id
    and r.command_type = normalized_type
    and r.idempotency_key = target_idempotency_key
  for update;

  if reserved.request_hash <> decoded_hash then
    raise exception 'Idempotency key was already used with a different request'
      using errcode = '23505';
  end if;
  return reserved;
end;
$$;

create function private.complete_financial_command(
  target_request_id uuid,
  target_journal_entry_id uuid
)
returns private.financial_command_requests
language plpgsql
security definer
set search_path = ''
as $$
declare
  request_row private.financial_command_requests;
begin
  select r.* into request_row
  from private.financial_command_requests r where r.id = target_request_id
  for update;
  if not found then
    raise exception 'Unknown financial command request' using errcode = '23503';
  end if;
  if request_row.status = 'COMPLETED' then
    if request_row.resulting_journal_entry_id <> target_journal_entry_id then
      raise exception 'Completed command outcome cannot change' using errcode = '23514';
    end if;
    return request_row;
  end if;

  update private.financial_command_requests
  set status = 'COMPLETED', resulting_journal_entry_id = target_journal_entry_id, completed_at = now()
  where id = target_request_id
  returning * into request_row;
  return request_row;
end;
$$;

create function private.validate_journal_line_dimensions()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  treasury_gl_id uuid;
begin
  if new.treasury_account_id is not null then
    select t.gl_account_id into treasury_gl_id
    from public.treasury_accounts t
    where t.company_id = new.company_id and t.id = new.treasury_account_id;
    if treasury_gl_id is distinct from new.account_id then
      raise exception 'Treasury dimension must use that treasury account''s permanent GL account'
        using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

create function private.assert_journal_balanced(target_journal_entry_id uuid)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  line_count bigint;
  debit_total numeric;
  credit_total numeric;
begin
  select count(*), coalesce(sum(l.debit_minor::numeric), 0), coalesce(sum(l.credit_minor::numeric), 0)
  into line_count, debit_total, credit_total
  from public.journal_lines l where l.journal_entry_id = target_journal_entry_id;

  if line_count < 2 then
    raise exception 'Posted journal must contain at least two lines' using errcode = '23514';
  end if;
  if debit_total <= 0 or debit_total <> credit_total then
    raise exception 'Posted journal is not balanced' using errcode = '23514';
  end if;
end;
$$;

create function private.enforce_journal_balance()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.assert_journal_balanced(
    case when tg_table_name = 'journal_entries' then new.id else new.journal_entry_id end
  );
  return new;
end;
$$;

create function private.reject_journal_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  raise exception 'Posted journal accounting is immutable; create a linked reversal'
    using errcode = '55000';
end;
$$;

create function private.create_journal(
  target_company_id uuid,
  target_posting_date date,
  target_description text,
  target_source_type text,
  target_source_id uuid,
  target_posting_purpose text,
  target_lines jsonb,
  target_created_by uuid default null,
  target_reversal_of_journal_entry_id uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  journal_id uuid := gen_random_uuid();
  journal_reference text;
  debit_total numeric;
  credit_total numeric;
  line_count bigint;
begin
  if target_lines is null or jsonb_typeof(target_lines) <> 'array' then
    raise exception 'Journal lines must be a JSON array' using errcode = '22023';
  end if;

  select count(*),
    coalesce(sum((item ->> 'debit_minor')::numeric), 0),
    coalesce(sum((item ->> 'credit_minor')::numeric), 0)
  into line_count, debit_total, credit_total
  from jsonb_array_elements(target_lines) item;
  if line_count < 2 or line_count > 1000 or debit_total <= 0 or debit_total <> credit_total then
    raise exception 'Journal must have at least two balanced positive-side lines'
      using errcode = '23514';
  end if;

  journal_reference := private.allocate_reference(
    target_company_id, 'JE', extract(year from target_posting_date)::integer
  );
  insert into public.journal_entries
    (id, company_id, journal_reference, posting_date, description, source_type,
     source_id, posting_purpose, reversal_of_journal_entry_id, created_by)
  values
    (journal_id, target_company_id, journal_reference, target_posting_date,
     target_description, upper(btrim(target_source_type)), target_source_id,
     upper(btrim(target_posting_purpose)), target_reversal_of_journal_entry_id,
     target_created_by);

  insert into public.journal_lines
    (company_id, journal_entry_id, line_number, account_id, debit_minor, credit_minor,
     project_id, party_id, treasury_account_id, subcontract_id, memo)
  select target_company_id, journal_id, ordinal::smallint,
    (item ->> 'account_id')::uuid,
    coalesce((item ->> 'debit_minor')::bigint, 0),
    coalesce((item ->> 'credit_minor')::bigint, 0),
    nullif(item ->> 'project_id', '')::uuid,
    nullif(item ->> 'party_id', '')::uuid,
    nullif(item ->> 'treasury_account_id', '')::uuid,
    nullif(item ->> 'subcontract_id', '')::uuid,
    nullif(btrim(item ->> 'memo'), '')
  from jsonb_array_elements(target_lines) with ordinality as input(item, ordinal);

  perform private.assert_journal_balanced(journal_id);
  return journal_id;
end;
$$;

create function private.reverse_journal(
  target_original_journal_entry_id uuid,
  target_posting_date date,
  target_description text,
  target_created_by uuid default null
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  original public.journal_entries;
  reversal_lines jsonb;
begin
  select j.* into original
  from public.journal_entries j where j.id = target_original_journal_entry_id
  for share;
  if not found then
    raise exception 'Original journal not found' using errcode = '23503';
  end if;
  if original.reversal_of_journal_entry_id is not null then
    raise exception 'A reversal journal cannot itself be reversed by the generic P5A primitive'
      using errcode = '23514';
  end if;
  if exists (
    select 1 from public.journal_entries r
    where r.reversal_of_journal_entry_id = original.id
  ) then
    raise exception 'Journal already has a reversal' using errcode = '23505';
  end if;

  select jsonb_agg(jsonb_build_object(
    'account_id', l.account_id,
    'debit_minor', l.credit_minor,
    'credit_minor', l.debit_minor,
    'project_id', l.project_id,
    'party_id', l.party_id,
    'treasury_account_id', l.treasury_account_id,
    'subcontract_id', l.subcontract_id,
    'memo', case when l.memo is null then null else 'Reversal: ' || l.memo end
  ) order by l.line_number)
  into reversal_lines
  from public.journal_lines l where l.journal_entry_id = original.id;

  return private.create_journal(
    original.company_id, target_posting_date, target_description,
    'JOURNAL_REVERSAL', original.id, 'REVERSAL', reversal_lines,
    target_created_by, original.id
  );
end;
$$;

create trigger journal_lines_validate_dimensions
  before insert on public.journal_lines
  for each row execute function private.validate_journal_line_dimensions();
create trigger journal_entries_immutable
  before update or delete on public.journal_entries
  for each row execute function private.reject_journal_mutation();
create trigger journal_lines_immutable
  before update or delete on public.journal_lines
  for each row execute function private.reject_journal_mutation();

create constraint trigger journal_entries_balance_at_commit
  after insert on public.journal_entries
  deferrable initially deferred
  for each row execute function private.enforce_journal_balance();
create constraint trigger journal_lines_balance_at_commit
  after insert on public.journal_lines
  deferrable initially deferred
  for each row execute function private.enforce_journal_balance();

alter table public.journal_entries enable row level security;
alter table public.journal_entries force row level security;
alter table public.journal_lines enable row level security;
alter table public.journal_lines force row level security;

create policy journal_entries_read_accounting on public.journal_entries
  for select to authenticated using (
    public.has_company_role(company_id, 'ACCOUNTING_ADMIN')
    or public.has_company_role(company_id, 'ACCOUNTANT')
    or public.has_company_role(company_id, 'MANAGEMENT_VIEWER')
  );
create policy journal_lines_read_accounting on public.journal_lines
  for select to authenticated using (
    public.has_company_role(company_id, 'ACCOUNTING_ADMIN')
    or public.has_company_role(company_id, 'ACCOUNTANT')
    or public.has_company_role(company_id, 'MANAGEMENT_VIEWER')
  );

revoke all on table public.journal_entries, public.journal_lines from public, anon, authenticated;
grant select on table public.journal_entries, public.journal_lines to authenticated;
grant select on table public.journal_entries, public.journal_lines to service_role;

revoke all on table private.reference_counters, private.financial_command_requests
  from public, anon, authenticated, service_role;
revoke all on function private.allocate_reference(uuid, text, integer)
  from public, anon, authenticated, service_role;
revoke all on function private.reserve_financial_command(uuid, text, uuid, text, uuid)
  from public, anon, authenticated, service_role;
revoke all on function private.complete_financial_command(uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function private.validate_journal_line_dimensions()
  from public, anon, authenticated, service_role;
revoke all on function private.assert_journal_balanced(uuid)
  from public, anon, authenticated, service_role;
revoke all on function private.enforce_journal_balance()
  from public, anon, authenticated, service_role;
revoke all on function private.reject_journal_mutation()
  from public, anon, authenticated, service_role;
revoke all on function private.create_journal(uuid, date, text, text, uuid, text, jsonb, uuid, uuid)
  from public, anon, authenticated, service_role;
revoke all on function private.reverse_journal(uuid, date, text, uuid)
  from public, anon, authenticated, service_role;

comment on table public.journal_entries is
  'Immutable posted journal headers. Corrections are separate linked reversal journals.';
comment on table public.journal_lines is
  'Immutable BIGINT AED-minor-unit debit/credit lines with company-consistent dimensions.';
comment on table private.financial_command_requests is
  'Private idempotency reservations for future specialized financial commands; stores SHA-256 only, never request payloads.';
comment on function private.create_journal(uuid, date, text, text, uuid, text, jsonb, uuid, uuid) is
  'Private accounting primitive. Never grant to browser roles; future specialized commands validate domain rules before calling.';
