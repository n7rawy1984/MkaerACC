-- P6C final closeout: remove provider-default browser maintenance privileges.
-- P4 permits authenticated SELECT/INSERT/UPDATE under assignment RLS only.
-- MAINTAIN was also found in the PostgreSQL 17 residual-grant audit.
-- Preserve DELETE denial, policies, ownership, FORCE RLS and trusted grants.
revoke truncate, references, trigger, maintain
  on table public.project_assignments from anon, authenticated;

do $$
begin
  if has_table_privilege('anon', 'public.project_assignments',
       'SELECT,INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN')
     or has_table_privilege('authenticated', 'public.project_assignments',
       'DELETE,TRUNCATE,REFERENCES,TRIGGER,MAINTAIN') then
    raise exception 'Unexpected browser project assignment privilege';
  end if;
  if not has_table_privilege('authenticated', 'public.project_assignments', 'SELECT')
     or not has_table_privilege('authenticated', 'public.project_assignments', 'INSERT')
     or not has_table_privilege('authenticated', 'public.project_assignments', 'UPDATE') then
    raise exception 'Intended project assignment grants missing';
  end if;
  if not exists (
    select 1 from pg_class
    where oid = 'public.project_assignments'::regclass
      and relrowsecurity and relforcerowsecurity
  ) then
    raise exception 'Project assignment RLS must remain enabled and forced';
  end if;
end;
$$;
