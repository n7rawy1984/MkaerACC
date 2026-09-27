-- Read-only Development closure, no fixture creation.
select
 (select count(*) from public.payroll_profiles) profiles,
 (select count(*) from public.payroll_draft_periods) periods,
 (select count(*) from public.payroll_draft_rows) rows,
 (select count(*) from public.payroll_draft_adjustments) adjustments,
 (select count(*) from public.payroll_draft_audit) audit,
 (select count(*) from public.attendance_exceptions) attendance_exceptions,
 (select count(*) from public.attendance_periods where locked_at is not null) locked_attendance_periods,
 (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in
 ('payroll_profiles','payroll_draft_periods','payroll_draft_rows','payroll_draft_adjustments','payroll_draft_audit') and c.relrowsecurity and c.relforcerowsecurity) forced_rls,
 (select count(*) from information_schema.role_table_grants where table_schema='public' and table_name in
 ('payroll_profiles','payroll_draft_periods','payroll_draft_rows','payroll_draft_adjustments','payroll_draft_audit')
 and grantee in ('anon','authenticated','service_role') and privilege_type<>'SELECT') forbidden_table_grants,
 (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in
 ('save_payroll_profile','refresh_payroll_draft','save_payroll_draft_adjustment','review_payroll_draft','read_payroll_profiles','read_payroll_draft')
 and p.prosecdef and p.proconfig @> array['search_path=""']) constrained_definers,
 (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in
 ('save_payroll_profile','refresh_payroll_draft','save_payroll_draft_adjustment','review_payroll_draft','read_payroll_profiles','read_payroll_draft')
 and has_function_privilege('anon',p.oid,'EXECUTE')) anonymous_commands,
 (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname in
 ('payroll_draft_audit_change','payroll_draft_no_delete','payroll_profile_employee_guard','calculate_payroll_draft','payroll_draft_source','require_payroll_review')
 and (has_function_privilege('authenticated',p.oid,'EXECUTE') or has_function_privilege('anon',p.oid,'EXECUTE') or has_function_privilege('service_role',p.oid,'EXECUTE'))) exposed_helpers,
 (select count(*) from public.role_permissions where permission_key='payroll.manage' and role not in ('ACCOUNTANT','ACCOUNTING_ADMIN')) unauthorized_payroll_roles,
 (select count(*) from supabase_migrations.schema_migrations) migrations;
