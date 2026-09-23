-- Existing Development synthetic identities only. No new fixtures or mutations.
-- Compare actual authenticated RLS results with an independent role/scope model.
begin read only;
do $$
declare
  actor record;
  tenant record;
  expected_ids uuid[];
  actual_ids uuid[];
  checks integer := 0;
  positive_checks integer := 0;
  roles_seen text[];
begin
  select array_agg(distinct role::text order by role::text) into roles_seen
    from public.company_memberships;
  for actor in select user_id from public.profiles loop
    for tenant in select id from public.companies loop
      select coalesce(array_agg(e.id order by e.id), '{}'::uuid[]) into expected_ids
      from public.expenses e
      where e.company_id = tenant.id and exists (
        select 1 from public.company_memberships m
        join public.profiles p on p.user_id = m.user_id
        join public.companies c on c.id = m.company_id
        where m.user_id = actor.user_id and m.company_id = e.company_id
          and m.status = 'ACTIVE' and p.status = 'ACTIVE' and c.status = 'ACTIVE'
          and (m.role in ('ACCOUNTING_ADMIN', 'ACCOUNTANT', 'MANAGEMENT_VIEWER')
            or (m.role = 'PROJECT_MANAGER' and e.project_id is not null and exists (
              select 1 from public.project_assignments a
              where a.user_id = actor.user_id and a.company_id = e.company_id
                and a.project_id = e.project_id and a.status = 'ACTIVE')))
      );
      perform set_config('request.jwt.claim.sub', actor.user_id::text, true);
      set local role authenticated;
      select coalesce(array_agg(id order by id), '{}'::uuid[]) into actual_ids
        from public.expenses where company_id = tenant.id;
      reset role;
      if actual_ids is distinct from expected_ids then
        raise exception 'Expense RLS result differs from canonical role/scope model';
      end if;
      checks := checks + 1;
      if cardinality(expected_ids) > 0 then positive_checks := positive_checks + 1; end if;
    end loop;
  end loop;
  if checks = 0 or positive_checks = 0 then raise exception 'Insufficient existing Expense RLS evidence'; end if;
  set local role anon;
  begin
    perform count(*) from public.expenses;
    raise exception 'Anonymous Expense SELECT unexpectedly permitted';
  exception when insufficient_privilege then null;
  end;
  reset role;
  perform set_config('makeracc.expense_read_checks', jsonb_build_object(
    'comparisons', checks, 'nonempty', positive_checks, 'empty_or_denied', checks-positive_checks,
    'membership_roles_present', roles_seen, 'anonymous_select_denied', true)::text, true);
end;
$$;
select current_setting('makeracc.expense_read_checks')::jsonb result;
rollback;
