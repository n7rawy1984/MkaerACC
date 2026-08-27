-- P4: full authorization policies for current P2/P3 identity and master data.
-- No financial transaction tables or posting commands are introduced.

insert into public.permissions (key, description) values
  ('party.manage', 'Manage permitted party master records'),
  ('category.manage', 'Manage expense category masters'),
  ('account.manage', 'Manage chart of accounts masters'),
  ('subcontract.manage', 'Manage subcontract master records'),
  ('project.assign_users', 'Assign company members to projects');

insert into public.role_permissions (role, permission_key) values
  ('ACCOUNTING_ADMIN', 'party.manage'),
  ('ACCOUNTING_ADMIN', 'category.manage'),
  ('ACCOUNTING_ADMIN', 'account.manage'),
  ('ACCOUNTING_ADMIN', 'subcontract.manage'),
  ('ACCOUNTING_ADMIN', 'project.assign_users'),
  ('PROCUREMENT', 'party.manage'),
  ('PROCUREMENT', 'subcontract.manage'),
  ('SYSTEM_ADMIN', 'project.assign_users');

create table public.project_assignments (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  project_id uuid not null,
  user_id uuid not null references auth.users (id) on delete restrict,
  status public.account_status not null default 'ACTIVE',
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete restrict,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete restrict,
  constraint project_assignments_project_same_company foreign key (company_id, project_id)
    references public.projects (company_id, id) on delete restrict
);
create unique index project_assignments_one_active
  on public.project_assignments (project_id, user_id) where status = 'ACTIVE';
create index project_assignments_active_user_project
  on public.project_assignments (user_id, project_id) where status = 'ACTIVE';

create function public.validate_project_assignment()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if not exists (
    select 1 from public.company_memberships m
    join public.profiles p on p.user_id = m.user_id
    where m.company_id = new.company_id
      and m.user_id = new.user_id
      and m.status = 'ACTIVE'
      and p.status = 'ACTIVE'
  ) then
    raise exception 'Project assignee must be an active user with active membership in the same company'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create function public.prevent_tenant_reassignment()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.company_id <> old.company_id then
    raise exception 'Tenant-owned master records cannot be reassigned to another company'
      using errcode = '23514';
  end if;
  return new;
end;
$$;

create function public.has_active_project_assignment(target_company_id uuid, target_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_company_member(target_company_id)
    and exists (
      select 1
      from public.project_assignments a
      join public.projects p on p.id = a.project_id and p.company_id = a.company_id
      where a.company_id = target_company_id
        and a.project_id = target_project_id
        and a.user_id = auth.uid()
        and a.status = 'ACTIVE'
    );
$$;

create function public.can_access_project(target_company_id uuid, target_project_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select public.is_company_member(target_company_id)
    and exists (
      select 1 from public.projects p
      where p.id = target_project_id and p.company_id = target_company_id
    )
    and (
      public.has_company_role(target_company_id, 'ACCOUNTING_ADMIN')
      or public.has_company_role(target_company_id, 'ACCOUNTANT')
      or public.has_company_role(target_company_id, 'DATA_ENTRY')
      or public.has_company_role(target_company_id, 'PROCUREMENT')
      or public.has_company_role(target_company_id, 'MANAGEMENT_VIEWER')
      or (
        public.has_company_role(target_company_id, 'PROJECT_MANAGER')
        and public.has_active_project_assignment(target_company_id, target_project_id)
      )
    );
$$;

create trigger project_assignments_validate before insert or update on public.project_assignments
  for each row execute function public.validate_project_assignment();
create trigger project_assignments_set_updated_at before update on public.project_assignments
  for each row execute function public.set_updated_at();
create trigger projects_prevent_tenant_reassignment before update of company_id on public.projects
  for each row execute function public.prevent_tenant_reassignment();
create trigger parties_prevent_tenant_reassignment before update of company_id on public.parties
  for each row execute function public.prevent_tenant_reassignment();
create trigger expense_categories_prevent_tenant_reassignment before update of company_id on public.expense_categories
  for each row execute function public.prevent_tenant_reassignment();
create trigger accounts_prevent_tenant_reassignment before update of company_id on public.accounts
  for each row execute function public.prevent_tenant_reassignment();
create trigger subcontracts_prevent_tenant_reassignment before update of company_id on public.subcontracts
  for each row execute function public.prevent_tenant_reassignment();
create trigger project_assignments_prevent_tenant_reassignment before update of company_id on public.project_assignments
  for each row execute function public.prevent_tenant_reassignment();

alter table public.project_assignments enable row level security;
alter table public.project_assignments force row level security;

-- Replace the deliberately broad P3 member-read baseline with role-aware P4 reads.
drop policy projects_read_active_company_member on public.projects;
drop policy parties_read_active_company_member on public.parties;
drop policy expense_categories_read_active_company_member on public.expense_categories;
drop policy accounts_read_active_company_member on public.accounts;
drop policy treasury_accounts_read_active_company_member on public.treasury_accounts;
drop policy subcontracts_read_active_company_member on public.subcontracts;

-- Companies remain membership-enumeration safe. Configuration changes require
-- company.manage inside that same active tenant; browser INSERT/DELETE stay absent.
create policy companies_update_config_admin on public.companies
  for update to authenticated
  using (public.has_permission(id, 'company.manage'))
  with check (public.has_permission(id, 'company.manage'));

-- Project master visibility is company-wide for operational/accounting/viewer
-- roles, assignment-only for PROJECT_MANAGER, and absent for SYSTEM_ADMIN.
create policy projects_read_authorized on public.projects
  for select to authenticated using (public.can_access_project(company_id, id));
create policy projects_insert_accounting_admin on public.projects
  for insert to authenticated
  with check (public.has_company_role(company_id, 'ACCOUNTING_ADMIN'));
create policy projects_update_authorized on public.projects
  for update to authenticated
  using (
    public.has_company_role(company_id, 'ACCOUNTING_ADMIN')
    or (
      public.has_company_role(company_id, 'PROJECT_MANAGER')
      and public.has_active_project_assignment(company_id, id)
    )
  )
  with check (
    public.has_company_role(company_id, 'ACCOUNTING_ADMIN')
    or (
      public.has_company_role(company_id, 'PROJECT_MANAGER')
      and public.has_active_project_assignment(company_id, id)
    )
  );

-- OWNER/EMPLOYEE are restricted to accounting and management readers.
-- Procurement/Data Entry get operational parties only. Project Managers get no
-- direct company-wide party table until a project-party relation/safe view exists.
create policy parties_read_sensitive_roles on public.parties
  for select to authenticated using (
    public.has_company_role(company_id, 'ACCOUNTING_ADMIN')
    or public.has_company_role(company_id, 'ACCOUNTANT')
    or public.has_company_role(company_id, 'MANAGEMENT_VIEWER')
    or (
      type not in ('OWNER', 'EMPLOYEE')
      and (
        public.has_company_role(company_id, 'PROCUREMENT')
        or public.has_company_role(company_id, 'DATA_ENTRY')
      )
    )
  );
create policy parties_insert_managers on public.parties
  for insert to authenticated with check (
    public.has_permission(company_id, 'party.manage')
    and (
      public.has_company_role(company_id, 'ACCOUNTING_ADMIN')
      or (
      public.has_company_role(company_id, 'PROCUREMENT')
      and type in ('SUPPLIER', 'SUBCONTRACTOR', 'OTHER')
      )
    )
  );
create policy parties_update_managers on public.parties
  for update to authenticated
  using (
    public.has_permission(company_id, 'party.manage')
    and (
      public.has_company_role(company_id, 'ACCOUNTING_ADMIN')
      or (
      public.has_company_role(company_id, 'PROCUREMENT')
      and type in ('SUPPLIER', 'SUBCONTRACTOR', 'OTHER')
      )
    )
  )
  with check (
    public.has_permission(company_id, 'party.manage')
    and (
      public.has_company_role(company_id, 'ACCOUNTING_ADMIN')
      or (
      public.has_company_role(company_id, 'PROCUREMENT')
      and type in ('SUPPLIER', 'SUBCONTRACTOR', 'OTHER')
      )
    )
  );

-- Categories are low-sensitivity operational reference data.
create policy categories_read_operational on public.expense_categories
  for select to authenticated using (
    public.has_company_role(company_id, 'ACCOUNTING_ADMIN')
    or public.has_company_role(company_id, 'ACCOUNTANT')
    or public.has_company_role(company_id, 'DATA_ENTRY')
    or public.has_company_role(company_id, 'PROCUREMENT')
    or public.has_company_role(company_id, 'MANAGEMENT_VIEWER')
    or (
      public.has_company_role(company_id, 'PROJECT_MANAGER')
      and exists (
        select 1 from public.project_assignments a
        where a.company_id = expense_categories.company_id
          and a.user_id = auth.uid() and a.status = 'ACTIVE'
      )
    )
  );
create policy categories_insert_admin on public.expense_categories
  for insert to authenticated with check (public.has_permission(company_id, 'category.manage'));
create policy categories_update_admin on public.expense_categories
  for update to authenticated
  using (public.has_permission(company_id, 'category.manage'))
  with check (public.has_permission(company_id, 'category.manage'));

-- Complete COA is sensitive accounting structure.
create policy accounts_read_accounting on public.accounts
  for select to authenticated using (
    public.has_company_role(company_id, 'ACCOUNTING_ADMIN')
    or public.has_company_role(company_id, 'ACCOUNTANT')
    or public.has_company_role(company_id, 'MANAGEMENT_VIEWER')
  );
create policy accounts_insert_admin on public.accounts
  for insert to authenticated with check (public.has_permission(company_id, 'account.manage'));
create policy accounts_update_admin on public.accounts
  for update to authenticated
  using (public.has_permission(company_id, 'account.manage'))
  with check (public.has_permission(company_id, 'account.manage'));

-- Treasury is company-wide for accounting/viewer roles; PROJECT_MANAGER sees
-- only a project-specific row attached to an assigned project.
create policy treasury_read_authorized on public.treasury_accounts
  for select to authenticated using (
    public.has_permission(company_id, 'treasury.view')
    or (
      public.has_company_role(company_id, 'PROJECT_MANAGER')
      and project_id is not null
      and public.has_active_project_assignment(company_id, project_id)
    )
  );
create policy treasury_insert_admin on public.treasury_accounts
  for insert to authenticated with check (public.has_permission(company_id, 'treasury.manage'));
create policy treasury_update_admin on public.treasury_accounts
  for update to authenticated
  using (public.has_permission(company_id, 'treasury.manage'))
  with check (public.has_permission(company_id, 'treasury.manage'));

-- Commercial contracts are project-scoped for PROJECT_MANAGER, company-wide
-- for accounting/procurement/management readers, and hidden from DATA_ENTRY.
create policy subcontracts_read_authorized on public.subcontracts
  for select to authenticated using (
    public.has_company_role(company_id, 'ACCOUNTING_ADMIN')
    or public.has_company_role(company_id, 'ACCOUNTANT')
    or public.has_company_role(company_id, 'PROCUREMENT')
    or public.has_company_role(company_id, 'MANAGEMENT_VIEWER')
    or (
      public.has_company_role(company_id, 'PROJECT_MANAGER')
      and public.has_active_project_assignment(company_id, project_id)
    )
  );
create policy subcontracts_insert_managers on public.subcontracts
  for insert to authenticated with check (
    public.has_permission(company_id, 'subcontract.manage')
  );
create policy subcontracts_update_managers on public.subcontracts
  for update to authenticated
  using (
    public.has_permission(company_id, 'subcontract.manage')
  )
  with check (
    public.has_permission(company_id, 'subcontract.manage')
  );

-- Assignment administration is explicit, tenant-scoped and cannot be reached
-- by PROJECT_MANAGER. Membership/profile validation is repeated by trigger.
create policy project_assignments_read_own_or_admin on public.project_assignments
  for select to authenticated using (
    (user_id = auth.uid() and public.is_active_user())
    or public.has_permission(company_id, 'project.assign_users')
  );
create policy project_assignments_insert_admin on public.project_assignments
  for insert to authenticated
  with check (public.has_permission(company_id, 'project.assign_users'));
create policy project_assignments_update_admin on public.project_assignments
  for update to authenticated
  using (public.has_permission(company_id, 'project.assign_users'))
  with check (public.has_permission(company_id, 'project.assign_users'));

-- Browser writes exist only where a policy above explicitly authorizes them.
grant update on table public.companies to authenticated;
grant insert, update on table public.projects, public.parties,
  public.expense_categories, public.accounts, public.treasury_accounts,
  public.subcontracts, public.project_assignments to authenticated;
grant select on table public.project_assignments to authenticated;

grant select, insert, update on table public.project_assignments to service_role;
revoke delete on table public.project_assignments from service_role;

revoke all on function public.validate_project_assignment() from public, anon, authenticated;
revoke all on function public.prevent_tenant_reassignment() from public, anon, authenticated;
revoke all on function public.has_active_project_assignment(uuid, uuid) from public, anon;
revoke all on function public.can_access_project(uuid, uuid) from public, anon;
grant execute on function public.has_active_project_assignment(uuid, uuid) to authenticated;
grant execute on function public.can_access_project(uuid, uuid) to authenticated;

comment on table public.project_assignments is
  'Project scope for project-restricted company roles. Membership role remains authoritative; inactive profile/membership/assignment denies access.';
