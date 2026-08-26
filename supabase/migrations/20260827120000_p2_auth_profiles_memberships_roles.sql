-- P2: authentication identity, tenant membership, roles and permissions.
--
-- This migration deliberately creates only the minimum company identity parent
-- needed to enforce and test membership. P3 extends public.companies and does
-- not create a second company table.

create type public.account_status as enum ('ACTIVE', 'INACTIVE');
create type public.app_locale as enum ('en', 'ar');
create type public.company_role as enum (
  'SYSTEM_ADMIN',
  'ACCOUNTING_ADMIN',
  'ACCOUNTANT',
  'PROJECT_MANAGER',
  'DATA_ENTRY',
  'PROCUREMENT',
  'MANAGEMENT_VIEWER'
);

create table public.profiles (
  user_id uuid primary key references auth.users (id) on delete restrict,
  display_name text not null check (length(btrim(display_name)) between 1 and 200),
  email_snapshot text,
  status public.account_status not null default 'ACTIVE',
  locale public.app_locale not null default 'en',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.companies (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  name text not null,
  status public.account_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint companies_code_not_blank check (length(btrim(code)) between 1 and 50),
  constraint companies_name_not_blank check (length(btrim(name)) between 1 and 200),
  constraint companies_code_unique unique (code)
);

comment on table public.companies is
  'P2 minimum tenant identity parent. P3 extends this table with business master-data fields.';

create table public.company_memberships (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  user_id uuid not null references auth.users (id) on delete restrict,
  role public.company_role not null,
  status public.account_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete restrict,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete restrict
);

create unique index company_memberships_one_active_per_user_company
  on public.company_memberships (company_id, user_id)
  where status = 'ACTIVE';
create index company_memberships_active_user_idx
  on public.company_memberships (user_id, company_id)
  where status = 'ACTIVE';

create table public.permissions (
  key text primary key,
  description text not null,
  constraint permissions_key_format check (key ~ '^[a-z]+(\.[a-z_]+)+$')
);

create table public.role_permissions (
  role public.company_role not null,
  permission_key text not null references public.permissions (key) on delete restrict,
  primary key (role, permission_key)
);

insert into public.permissions (key, description) values
  ('company.manage', 'Manage company configuration'),
  ('users.manage', 'Invite and administer company users'),
  ('project.view', 'View permitted projects'),
  ('project.manage', 'Manage permitted projects'),
  ('accounting.view', 'View permitted accounting information'),
  ('accounting.create', 'Create accounting drafts'),
  ('accounting.post', 'Post permitted accounting documents'),
  ('certificate.approve_post', 'Approve and post subcontractor certificates'),
  ('treasury.view', 'View permitted treasury information'),
  ('treasury.manage', 'Manage permitted treasury operations');

insert into public.role_permissions (role, permission_key) values
  ('SYSTEM_ADMIN', 'company.manage'), ('SYSTEM_ADMIN', 'users.manage'),
  ('ACCOUNTING_ADMIN', 'company.manage'), ('ACCOUNTING_ADMIN', 'users.manage'),
  ('ACCOUNTING_ADMIN', 'project.view'), ('ACCOUNTING_ADMIN', 'project.manage'),
  ('ACCOUNTING_ADMIN', 'accounting.view'), ('ACCOUNTING_ADMIN', 'accounting.create'),
  ('ACCOUNTING_ADMIN', 'accounting.post'), ('ACCOUNTING_ADMIN', 'certificate.approve_post'),
  ('ACCOUNTING_ADMIN', 'treasury.view'), ('ACCOUNTING_ADMIN', 'treasury.manage'),
  ('ACCOUNTANT', 'project.view'), ('ACCOUNTANT', 'accounting.view'),
  ('ACCOUNTANT', 'accounting.create'), ('ACCOUNTANT', 'accounting.post'),
  ('ACCOUNTANT', 'treasury.view'),
  ('PROJECT_MANAGER', 'project.view'), ('PROJECT_MANAGER', 'project.manage'),
  ('PROJECT_MANAGER', 'accounting.view'),
  ('DATA_ENTRY', 'project.view'), ('DATA_ENTRY', 'accounting.view'),
  ('DATA_ENTRY', 'accounting.create'),
  ('PROCUREMENT', 'project.view'), ('PROCUREMENT', 'accounting.view'),
  ('PROCUREMENT', 'accounting.create'),
  ('MANAGEMENT_VIEWER', 'project.view'), ('MANAGEMENT_VIEWER', 'accounting.view'),
  ('MANAGEMENT_VIEWER', 'treasury.view');

-- Platform administrators are deliberately outside the exposed public schema.
-- Membership role SYSTEM_ADMIN has no implicit cross-company effect: ordinary
-- browser access still requires an active membership in the target company.
-- Cross-company administration must use a trusted server/service pathway which
-- checks this registry, requires MFA operationally, and emits P7 audit events.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table private.system_administrators (
  user_id uuid primary key references auth.users (id) on delete restrict,
  status public.account_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete restrict,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete restrict
);

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
create trigger companies_set_updated_at before update on public.companies
  for each row execute function public.set_updated_at();
create trigger company_memberships_set_updated_at before update on public.company_memberships
  for each row execute function public.set_updated_at();
create trigger system_administrators_set_updated_at before update on private.system_administrators
  for each row execute function public.set_updated_at();

-- Auth owns identity creation. This trigger makes the required profile part of
-- the same transaction as an admin create/invite operation. It never copies a
-- password or credential and safely normalizes untrusted user metadata.
create function public.handle_new_auth_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  requested_name text;
  requested_locale text;
begin
  requested_name := nullif(btrim(coalesce(new.raw_user_meta_data ->> 'display_name', '')), '');
  requested_locale := new.raw_user_meta_data ->> 'locale';

  insert into public.profiles (user_id, display_name, email_snapshot, locale)
  values (
    new.id,
    left(coalesce(requested_name, nullif(split_part(coalesce(new.email, ''), '@', 1), ''), 'Invited user'), 200),
    new.email,
    case when requested_locale = 'ar' then 'ar'::public.app_locale else 'en'::public.app_locale end
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_auth_user();

create function public.is_active_user()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select auth.uid() is not null
    and exists (
      select 1 from public.profiles p
      where p.user_id = auth.uid() and p.status = 'ACTIVE'
    );
$$;

create function public.is_company_member(target_company_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_active_user()
    and exists (
      select 1
      from public.company_memberships m
      join public.companies c on c.id = m.company_id
      where m.user_id = auth.uid()
        and m.company_id = target_company_id
        and m.status = 'ACTIVE'
        and c.status = 'ACTIVE'
    );
$$;

create function public.has_company_role(target_company_id uuid, required_role public.company_role)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_active_user()
    and exists (
      select 1
      from public.company_memberships m
      join public.companies c on c.id = m.company_id
      where m.user_id = auth.uid()
        and m.company_id = target_company_id
        and m.role = required_role
        and m.status = 'ACTIVE'
        and c.status = 'ACTIVE'
    );
$$;

create function public.has_permission(target_company_id uuid, required_permission text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_active_user()
    and exists (
      select 1
      from public.company_memberships m
      join public.companies c on c.id = m.company_id
      join public.role_permissions rp on rp.role = m.role
      where m.user_id = auth.uid()
        and m.company_id = target_company_id
        and m.status = 'ACTIVE'
        and c.status = 'ACTIVE'
        and rp.permission_key = required_permission
    );
$$;

alter table public.profiles enable row level security;
alter table public.profiles force row level security;
alter table public.companies enable row level security;
alter table public.companies force row level security;
alter table public.company_memberships enable row level security;
alter table public.company_memberships force row level security;
alter table public.permissions enable row level security;
alter table public.permissions force row level security;
alter table public.role_permissions enable row level security;
alter table public.role_permissions force row level security;

create policy profiles_read_own on public.profiles
  for select to authenticated
  using (user_id = auth.uid());

create policy companies_read_active_membership on public.companies
  for select to authenticated
  using (public.is_company_member(id));

create policy memberships_read_own on public.company_memberships
  for select to authenticated
  using (user_id = auth.uid());

-- Permission definitions can be discovered by active users, but the mapping is
-- resolved only through has_permission(). Neither table is directly writable.
create policy permissions_read_active_user on public.permissions
  for select to authenticated
  using (public.is_active_user());

revoke all on table public.profiles from anon, authenticated;
revoke all on table public.companies from anon, authenticated;
revoke all on table public.company_memberships from anon, authenticated;
revoke all on table public.permissions from anon, authenticated;
revoke all on table public.role_permissions from anon, authenticated;
revoke all on all tables in schema private from anon, authenticated;

grant select on table public.profiles to authenticated;
grant select on table public.companies to authenticated;
grant select on table public.company_memberships to authenticated;
grant select on table public.permissions to authenticated;

revoke all on function public.set_updated_at() from public, anon, authenticated;
revoke all on function public.handle_new_auth_user() from public, anon, authenticated;
revoke all on function public.is_active_user() from public, anon;
revoke all on function public.is_company_member(uuid) from public, anon;
revoke all on function public.has_company_role(uuid, public.company_role) from public, anon;
revoke all on function public.has_permission(uuid, text) from public, anon;
grant execute on function public.is_active_user() to authenticated;
grant execute on function public.is_company_member(uuid) to authenticated;
grant execute on function public.has_company_role(uuid, public.company_role) to authenticated;
grant execute on function public.has_permission(uuid, text) to authenticated;

comment on function public.has_permission(uuid, text) is
  'Resolves role permissions only for the caller active in the target active company; SYSTEM_ADMIN is configuration-only and does not bypass membership.';
comment on table public.company_memberships is
  'Server-administered tenant boundary. Browser roles have SELECT-only access to their own rows and no mutation grants.';
