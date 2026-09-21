begin read only;
select
 (select count(*) from public.companies where id in ('80000000-0000-4000-8000-0000000000a1','80000000-0000-4000-8000-0000000000a2','80100000-0000-4000-8000-0000000000a1','80200000-0000-4000-8000-0000000000a1','80200000-0000-4000-8000-0000000000a2')) as fixture_companies,
 (select count(*) from public.accounts where company_id in ('80000000-0000-4000-8000-0000000000a1','80000000-0000-4000-8000-0000000000a2','80100000-0000-4000-8000-0000000000a1','80200000-0000-4000-8000-0000000000a1','80200000-0000-4000-8000-0000000000a2')) as fixture_accounts,
 (select count(*) from public.treasury_accounts where company_id in ('80000000-0000-4000-8000-0000000000a1','80000000-0000-4000-8000-0000000000a2','80100000-0000-4000-8000-0000000000a1','80200000-0000-4000-8000-0000000000a1','80200000-0000-4000-8000-0000000000a2')) as fixture_treasuries,
 (select count(*) from public.projects where company_id in ('80000000-0000-4000-8000-0000000000a1','80000000-0000-4000-8000-0000000000a2','80100000-0000-4000-8000-0000000000a1','80200000-0000-4000-8000-0000000000a1','80200000-0000-4000-8000-0000000000a2')) as fixture_projects,
 (select count(*) from public.company_memberships where company_id in ('80000000-0000-4000-8000-0000000000a1','80000000-0000-4000-8000-0000000000a2','80100000-0000-4000-8000-0000000000a1','80200000-0000-4000-8000-0000000000a1','80200000-0000-4000-8000-0000000000a2')) as fixture_memberships,
 (select count(*) from public.project_assignments where company_id in ('80000000-0000-4000-8000-0000000000a1','80000000-0000-4000-8000-0000000000a2','80100000-0000-4000-8000-0000000000a1','80200000-0000-4000-8000-0000000000a1','80200000-0000-4000-8000-0000000000a2')) as fixture_assignments,
 (select count(*) from auth.users where email='p6c-s10-browser@example.test') as browser_auth,
 (select count(*) from public.companies) as companies,
 (select count(*) from public.company_settings) as settings,
 (select count(*) from public.companies c left join public.company_settings s on s.company_id=c.id where s.company_id is null) as missing,
 (select count(*) from public.company_settings s left join public.companies c on c.id=s.company_id where c.id is null) as orphan;
commit;
