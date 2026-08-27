-- P4 corrective migration: assignment validation must inspect protected identity
-- rows while the caller remains authorized by project_assignments RLS.

create or replace function public.validate_project_assignment()
returns trigger
language plpgsql
security definer
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

revoke all on function public.validate_project_assignment() from public, anon, authenticated;
