-- Read-only Development acceptance checks.
select
 (select count(*) from public.employee_site_assignments) assignment_rows,
 (select count(*) from public.attendance_exceptions) exception_rows,
 (select count(*) from public.attendance_periods) period_rows,
 (select count(*) from public.attendance_audit) audit_rows,
 (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public'
  and c.relname in ('employee_site_assignments','attendance_exceptions','attendance_periods','attendance_audit')
  and c.relrowsecurity and c.relforcerowsecurity) forced_rls_tables,
 (select count(*) from information_schema.role_table_grants where table_schema='public'
  and table_name in ('employee_site_assignments','attendance_exceptions','attendance_periods','attendance_audit')
  and grantee in ('anon','authenticated','service_role') and privilege_type<>'SELECT') forbidden_table_grants,
 (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
  and p.proname in ('attendance_context','attendance_day','attendance_month','save_attendance_exception','save_employee_site_assignment','confirm_attendance_review')
  and p.prosecdef and p.proconfig @> array['search_path=""']) constrained_definer_commands,
 (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private'
  and p.proname in ('attendance_company_lock','attendance_staff','attendance_scope','validate_employee_site_assignment','attendance_audit_change','attendance_no_delete','lock_attendance_month')
  and (has_function_privilege('authenticated',p.oid,'EXECUTE') or has_function_privilege('anon',p.oid,'EXECUTE') or has_function_privilege('service_role',p.oid,'EXECUTE'))) exposed_private_helpers,
 (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public'
  and p.proname in ('attendance_context','attendance_day','attendance_month','save_attendance_exception','save_employee_site_assignment','confirm_attendance_review')
  and has_function_privilege('anon',p.oid,'EXECUTE')) anonymous_commands,
 (select count(*) from public.role_permissions where role='FOREMAN' and permission_key<>'attendance.record') extra_foreman_permissions,
 (select count(*) from supabase_migrations.schema_migrations) migration_count;
