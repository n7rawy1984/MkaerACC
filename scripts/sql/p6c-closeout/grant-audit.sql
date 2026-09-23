-- Read-only P6C closeout catalog snapshot; run only on MakerACC-Development.
-- Compare before/after: only eight project_assignments table grants and their
-- inherited REFERENCES column privileges may change. No business rows returned.
begin read only;
select jsonb_build_object(
  'grants', (
    select jsonb_agg(jsonb_build_object(
      'table', c.relname, 'role', r.rolname, 'privilege', p.privilege,
      'allowed', has_table_privilege(r.rolname, c.oid, p.privilege)))
    from pg_class c cross join pg_roles r
    cross join (values ('SELECT'), ('INSERT'), ('UPDATE'), ('DELETE'),
      ('TRUNCATE'), ('REFERENCES'), ('TRIGGER'), ('MAINTAIN')) p(privilege)
    where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p')
      and r.rolname in ('anon', 'authenticated', 'service_role')
  ),
  'columns', (
    select jsonb_agg(jsonb_build_object(
      'table', c.relname, 'column', a.attname, 'role', r.rolname,
      'privilege', p.privilege,
      'allowed', has_column_privilege(r.rolname, c.oid, a.attnum, p.privilege)))
    from pg_class c join pg_attribute a on a.attrelid = c.oid
    cross join pg_roles r
    cross join (values ('SELECT'), ('INSERT'), ('UPDATE'), ('REFERENCES')) p(privilege)
    where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p')
      and a.attnum > 0 and not a.attisdropped
      and r.rolname in ('anon', 'authenticated', 'service_role')
  ),
  'functions', (
    select jsonb_agg(jsonb_build_object('name', p.proname,
      'definition', pg_get_functiondef(p.oid), 'acl', p.proacl::text))
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.prokind = 'f'
  ),
  'constraints', (
    select jsonb_agg(jsonb_build_object('table', c.conrelid::regclass::text,
      'name', c.conname, 'definition', pg_get_constraintdef(c.oid)))
    from pg_constraint c where c.connamespace = 'public'::regnamespace
  ),
  'rls', (
    select jsonb_agg(jsonb_build_object('table', relname,
      'enabled', relrowsecurity, 'forced', relforcerowsecurity,
      'owner', relowner::regrole::text))
    from pg_class
    where relnamespace = 'public'::regnamespace and relkind in ('r', 'p')
  ),
  'policies', (
    select jsonb_agg(to_jsonb(p)) from pg_policies p where schemaname = 'public'
  ),
  'permissions', (
    select jsonb_agg(to_jsonb(r)) from public.role_permissions r
  ),
  'integrity', jsonb_build_object(
    'companies', (select count(*) from public.companies),
    'settings', (select count(*) from public.company_settings),
    'missing', (select count(*) from public.companies c
      left join public.company_settings s on c.id = s.company_id
      where s.company_id is null),
    'orphan', (select count(*) from public.company_settings s
      left join public.companies c on c.id = s.company_id where c.id is null)
  )
) audit;
commit;
