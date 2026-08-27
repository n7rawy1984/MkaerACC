-- P3: authoritative production master-data schema.
-- Extends the P2 company authorization parent; creates no accounting
-- transactions, journals, demo imports, or frontend data path.

create type public.project_status as enum ('PLANNING', 'ACTIVE', 'ON_HOLD', 'COMPLETED', 'CLOSED');
create type public.party_type as enum ('OWNER', 'CUSTODIAN', 'SUPPLIER', 'EMPLOYEE', 'SUBCONTRACTOR', 'OTHER');
create type public.account_type as enum ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE');
create type public.system_account_key as enum (
  'INPUT_VAT',
  'CUSTODY_ADVANCE',
  'SUPPLIER_PAYABLE',
  'OWNER_CURRENT',
  'SUBCONTRACTOR_ADVANCE',
  'SUBCONTRACTOR_PAYABLE',
  'SUBCONTRACTOR_RETENTION_PAYABLE',
  'PROJECT_COST',
  'PROJECT_COST_SUBCONTRACTORS',
  'COMPANY_EXPENSE'
);
create type public.treasury_account_type as enum ('CASH', 'PETTY_CASH', 'BANK', 'PROJECT_CASH_BOX', 'PROJECT_BANK');
create type public.subcontract_status as enum ('ACTIVE', 'COMPLETED', 'CLOSED');

-- P2 already created companies as the tenant authorization parent.
alter table public.companies
  add column legal_name text,
  add column trn text,
  add column address text,
  add column notes text,
  add column created_by uuid references auth.users (id) on delete restrict,
  add column updated_by uuid references auth.users (id) on delete restrict;

alter table public.companies drop constraint companies_code_unique;
create unique index companies_code_unique_ci on public.companies (lower(btrim(code)));

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  code text not null check (length(btrim(code)) between 1 and 50),
  name text not null check (length(btrim(name)) between 1 and 200),
  client_name text,
  location text,
  contract_number text,
  original_contract_value_minor bigint check (original_contract_value_minor >= 0),
  budget_minor bigint check (budget_minor >= 0),
  start_date date,
  expected_completion_date date,
  status public.project_status not null default 'PLANNING',
  notes text,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete restrict,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete restrict,
  constraint projects_company_id_id_unique unique (company_id, id)
);
create unique index projects_company_code_unique_ci on public.projects (company_id, lower(btrim(code)));

create table public.parties (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  type public.party_type not null,
  name text not null check (length(btrim(name)) between 1 and 200),
  code text check (code is null or length(btrim(code)) between 1 and 50),
  trn text,
  contact_person text,
  phone text,
  email text,
  address text,
  status public.account_status not null default 'ACTIVE',
  notes text,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete restrict,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete restrict,
  constraint parties_company_id_id_unique unique (company_id, id)
);
create unique index parties_company_code_unique_ci
  on public.parties (company_id, lower(btrim(code))) where code is not null;

create table public.expense_categories (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  code text not null check (length(btrim(code)) between 1 and 50),
  name text not null check (length(btrim(name)) between 1 and 200),
  description text,
  status public.account_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete restrict,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete restrict
);
create unique index expense_categories_company_code_unique_ci
  on public.expense_categories (company_id, lower(btrim(code)));

create table public.accounts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  code text not null check (length(btrim(code)) between 1 and 50),
  name text not null check (length(btrim(name)) between 1 and 200),
  account_type public.account_type not null,
  parent_account_id uuid,
  requires_party boolean not null default false,
  status public.account_status not null default 'ACTIVE',
  system_key public.system_account_key,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete restrict,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete restrict,
  constraint accounts_not_own_parent check (parent_account_id is null or parent_account_id <> id),
  constraint accounts_company_id_id_unique unique (company_id, id),
  constraint accounts_parent_same_company foreign key (company_id, parent_account_id)
    references public.accounts (company_id, id) on delete restrict
);
create unique index accounts_company_code_unique_ci on public.accounts (company_id, lower(btrim(code)));
create unique index accounts_company_system_key_unique
  on public.accounts (company_id, system_key) where system_key is not null;

create table public.treasury_accounts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  project_id uuid,
  code text not null check (length(btrim(code)) between 1 and 50),
  name text not null check (length(btrim(name)) between 1 and 200),
  type public.treasury_account_type not null,
  gl_account_id uuid not null,
  status public.account_status not null default 'ACTIVE',
  bank_name text,
  account_reference text,
  notes text,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete restrict,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete restrict,
  constraint treasury_project_same_company foreign key (company_id, project_id)
    references public.projects (company_id, id) on delete restrict,
  constraint treasury_gl_same_company foreign key (company_id, gl_account_id)
    references public.accounts (company_id, id) on delete restrict,
  constraint treasury_gl_account_unique unique (gl_account_id)
);
create unique index treasury_accounts_company_code_unique_ci
  on public.treasury_accounts (company_id, lower(btrim(code)));

create table public.subcontracts (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  project_id uuid not null,
  subcontractor_id uuid not null,
  contract_number text not null check (length(btrim(contract_number)) between 1 and 100),
  scope_of_work text not null check (length(btrim(scope_of_work)) > 0),
  original_contract_value_minor bigint not null check (original_contract_value_minor >= 0),
  approved_variations_minor bigint not null default 0,
  retention_bps integer not null check (retention_bps between 0 and 10000),
  start_date date,
  expected_end_date date,
  status public.subcontract_status not null default 'ACTIVE',
  notes text,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete restrict,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete restrict,
  constraint subcontracts_revised_value_nonnegative check (
    original_contract_value_minor::numeric + approved_variations_minor::numeric >= 0
  ),
  constraint subcontracts_project_same_company foreign key (company_id, project_id)
    references public.projects (company_id, id) on delete restrict,
  constraint subcontracts_party_same_company foreign key (company_id, subcontractor_id)
    references public.parties (company_id, id) on delete restrict
);
create unique index subcontracts_project_contract_number_unique_ci
  on public.subcontracts (project_id, lower(btrim(contract_number)));

comment on column public.accounts.system_key is
  'Stable per-company posting-account identifier. Future commands resolve by this key, never by display name or hardcoded UUID.';
comment on column public.treasury_accounts.gl_account_id is
  'Permanent one-to-one GL identity for this treasury account; updates are rejected.';
comment on table public.expense_categories is
  'Category classification remains document/project-driven; the current domain has no category-level project/company class.';

create function public.validate_treasury_account()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  linked_account_type public.account_type;
begin
  if tg_op = 'UPDATE' and (new.gl_account_id <> old.gl_account_id or new.company_id <> old.company_id) then
    raise exception 'Treasury GL account and company are permanent after creation' using errcode = '23514';
  end if;

  select a.account_type into linked_account_type
  from public.accounts a
  where a.id = new.gl_account_id and a.company_id = new.company_id;

  if linked_account_type is null then
    raise exception 'Treasury GL account must belong to the same company' using errcode = '23514';
  end if;
  if linked_account_type <> 'ASSET' then
    raise exception 'Treasury GL account must be an ASSET account' using errcode = '23514';
  end if;
  return new;
end;
$$;

create function public.validate_subcontract()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  target_project_status public.project_status;
  target_party_type public.party_type;
  target_party_status public.account_status;
begin
  select p.status into target_project_status
  from public.projects p where p.id = new.project_id and p.company_id = new.company_id;
  select p.type, p.status into target_party_type, target_party_status
  from public.parties p where p.id = new.subcontractor_id and p.company_id = new.company_id;

  if target_party_type is distinct from 'SUBCONTRACTOR'::public.party_type then
    raise exception 'Subcontract party must be a SUBCONTRACTOR in the same company' using errcode = '23514';
  end if;

  if tg_op = 'INSERT' or new.project_id <> old.project_id or new.subcontractor_id <> old.subcontractor_id then
    if target_project_status = 'CLOSED' then
      raise exception 'A closed project cannot receive a new subcontract' using errcode = '23514';
    end if;
    if target_party_status <> 'ACTIVE' then
      raise exception 'An inactive subcontractor cannot receive a new subcontract' using errcode = '23514';
    end if;
  end if;
  return new;
end;
$$;

create function public.protect_subcontractor_party_type()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.type = 'SUBCONTRACTOR' and new.type <> 'SUBCONTRACTOR'
     and exists (select 1 from public.subcontracts s where s.subcontractor_id = old.id) then
    raise exception 'A party used by a subcontract must remain SUBCONTRACTOR' using errcode = '23514';
  end if;
  return new;
end;
$$;

create trigger treasury_accounts_validate before insert or update on public.treasury_accounts
  for each row execute function public.validate_treasury_account();
create trigger subcontracts_validate before insert or update on public.subcontracts
  for each row execute function public.validate_subcontract();
create trigger parties_protect_subcontractor_type before update of type on public.parties
  for each row execute function public.protect_subcontractor_party_type();

create trigger projects_set_updated_at before update on public.projects
  for each row execute function public.set_updated_at();
create trigger parties_set_updated_at before update on public.parties
  for each row execute function public.set_updated_at();
create trigger expense_categories_set_updated_at before update on public.expense_categories
  for each row execute function public.set_updated_at();
create trigger accounts_set_updated_at before update on public.accounts
  for each row execute function public.set_updated_at();
create trigger treasury_accounts_set_updated_at before update on public.treasury_accounts
  for each row execute function public.set_updated_at();
create trigger subcontracts_set_updated_at before update on public.subcontracts
  for each row execute function public.set_updated_at();

alter table public.projects enable row level security;
alter table public.projects force row level security;
alter table public.parties enable row level security;
alter table public.parties force row level security;
alter table public.expense_categories enable row level security;
alter table public.expense_categories force row level security;
alter table public.accounts enable row level security;
alter table public.accounts force row level security;
alter table public.treasury_accounts enable row level security;
alter table public.treasury_accounts force row level security;
alter table public.subcontracts enable row level security;
alter table public.subcontracts force row level security;

create policy projects_read_active_company_member on public.projects
  for select to authenticated using (public.is_company_member(company_id));
create policy parties_read_active_company_member on public.parties
  for select to authenticated using (public.is_company_member(company_id));
create policy expense_categories_read_active_company_member on public.expense_categories
  for select to authenticated using (public.is_company_member(company_id));
create policy accounts_read_active_company_member on public.accounts
  for select to authenticated using (public.is_company_member(company_id));
create policy treasury_accounts_read_active_company_member on public.treasury_accounts
  for select to authenticated using (public.is_company_member(company_id));
create policy subcontracts_read_active_company_member on public.subcontracts
  for select to authenticated using (public.is_company_member(company_id));

revoke all on table public.projects from anon, authenticated;
revoke all on table public.parties from anon, authenticated;
revoke all on table public.expense_categories from anon, authenticated;
revoke all on table public.accounts from anon, authenticated;
revoke all on table public.treasury_accounts from anon, authenticated;
revoke all on table public.subcontracts from anon, authenticated;
grant select on table public.projects, public.parties, public.expense_categories,
  public.accounts, public.treasury_accounts, public.subcontracts to authenticated;

grant select, insert, update on table public.projects, public.parties,
  public.expense_categories, public.accounts, public.treasury_accounts,
  public.subcontracts to service_role;
revoke delete on table public.projects, public.parties, public.expense_categories,
  public.accounts, public.treasury_accounts, public.subcontracts from service_role;

revoke all on function public.validate_treasury_account() from public, anon, authenticated;
revoke all on function public.validate_subcontract() from public, anon, authenticated;
revoke all on function public.protect_subcontractor_party_type() from public, anon, authenticated;
