-- Read-only final Development boundary review.
select
 (select count(*) from supabase_migrations.schema_migrations) migrations,
 (select count(*) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relname in ('payroll_draft_accounting','payroll_postings','payroll_entitlements','salary_payments','salary_payment_reversals','payroll_reversals') and c.relrowsecurity and c.relforcerowsecurity) forced_rls,
 (select count(*) from information_schema.role_table_grants where table_schema='public' and table_name in ('payroll_draft_accounting','payroll_postings','payroll_entitlements','salary_payments','salary_payment_reversals','payroll_reversals') and grantee in ('anon','authenticated','service_role') and privilege_type<>'SELECT') forbidden_table_grants,
 (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname in ('prepare_payroll_accounting','post_payroll','pay_salary','reverse_salary_payment','reverse_payroll','read_payroll_postings','payroll_journal_visible') and p.prosecdef and p.proconfig @> array['search_path=""'] and has_function_privilege('authenticated',p.oid,'EXECUTE') and not has_function_privilege('anon',p.oid,'EXECUTE')) constrained_definers,
 (select count(*) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='private' and p.proname in ('payroll_open_draft_guard','payroll_reserve','payroll_unpaid') and (has_function_privilege('authenticated',p.oid,'EXECUTE') or has_function_privilege('anon',p.oid,'EXECUTE') or has_function_privilege('service_role',p.oid,'EXECUTE'))) exposed_helpers,
 (select count(*) from pg_policies where schemaname='public' and policyname in ('payroll_journal_privacy','payroll_journal_line_privacy') and permissive='RESTRICTIVE') journal_privacy_policies,
 (select count(*) from public.payroll_postings where company_id<>'95610000-0000-4000-8000-000000000001') nonfixture_postings,
 (select count(*) from private.live_payroll_periods) live_payroll,
 (select count(*) from public.attendance_periods where locked_at is not null) locked_attendance,
 (select count(*) from public.payroll_postings where company_id='95610000-0000-4000-8000-000000000001') retained_synthetic_postings,
 (select count(*) from public.payroll_reversals where company_id='95610000-0000-4000-8000-000000000001') retained_synthetic_reversals,
 (select count(*) from public.salary_payments where company_id='95610000-0000-4000-8000-000000000001') retained_synthetic_payments,
 (select count(*) from public.salary_payment_reversals where company_id='95610000-0000-4000-8000-000000000001') retained_synthetic_payment_reversals,
 (select count(*) from public.company_memberships where company_id='95610000-0000-4000-8000-000000000001' and status='ACTIVE') active_fixture_memberships,
 (select count(*) from public.companies where id='95610000-0000-4000-8000-000000000001' and status='ACTIVE') active_fixture_companies,
 (select count(*) from public.companies c left join public.company_settings s on s.company_id=c.id where s.company_id is null) missing_company_settings,
 (select count(*) from (select account_id,party_id,project_id,treasury_account_id from public.journal_lines where company_id='95610000-0000-4000-8000-000000000001' group by account_id,party_id,project_id,treasury_account_id having sum(debit_minor::numeric-credit_minor::numeric)<>0) x) nonzero_fixture_dimensions;
