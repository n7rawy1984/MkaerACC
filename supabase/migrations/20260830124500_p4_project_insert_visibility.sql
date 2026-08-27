-- P4 corrective migration: make project row visibility row-local so an
-- authorized INSERT can safely use PostgREST return=representation. Keep
-- can_access_project() strict for direct RPC callers and other consumers.

drop policy projects_read_authorized on public.projects;

create policy projects_read_authorized on public.projects
  for select to authenticated
  using (
    public.is_company_member(company_id)
    and (
      public.has_company_role(company_id, 'ACCOUNTING_ADMIN')
      or public.has_company_role(company_id, 'ACCOUNTANT')
      or public.has_company_role(company_id, 'DATA_ENTRY')
      or public.has_company_role(company_id, 'PROCUREMENT')
      or public.has_company_role(company_id, 'MANAGEMENT_VIEWER')
      or (
        public.has_company_role(company_id, 'PROJECT_MANAGER')
        and public.has_active_project_assignment(company_id, id)
      )
    )
  );
