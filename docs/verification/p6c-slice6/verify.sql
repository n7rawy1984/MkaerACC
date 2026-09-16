-- PREPARED / NOT EXECUTED. MakerACC-Development only; NOT a migration.
begin transaction read only;
-- Fill the recorded browser UUID in an execution copy, including after Auth deletion.
select set_config('makeracc.fixture_user','',true);
do $$ begin
 if nullif(current_setting('makeracc.fixture_user',true),'') is null then raise exception 'Recorded browser fixture UUID required'; end if;
end $$;
select 'fixture_companies' as item,count(*) as remaining from public.companies where id in ('76100000-0000-4000-8000-0000000000a1','76200000-0000-4000-8000-0000000000a1','76200000-0000-4000-8000-0000000000a2')
union all select 'fixture_parties',count(*) from public.parties where company_id in ('76100000-0000-4000-8000-0000000000a1','76200000-0000-4000-8000-0000000000a1','76200000-0000-4000-8000-0000000000a2')
union all select 'fixture_memberships',count(*) from public.company_memberships where company_id in ('76100000-0000-4000-8000-0000000000a1','76200000-0000-4000-8000-0000000000a1','76200000-0000-4000-8000-0000000000a2')
union all select 'fixture_settings',count(*) from public.company_settings where company_id in ('76100000-0000-4000-8000-0000000000a1','76200000-0000-4000-8000-0000000000a1','76200000-0000-4000-8000-0000000000a2')
union all select 'fixture_auth',count(*) from auth.users where id='76100000-0000-4000-8000-000000000001' or email in ('p6c-s6-concurrency@example.test','p6c-slice6-user@example.test')
union all select 'fixture_profiles',count(*) from public.profiles where user_id='76100000-0000-4000-8000-000000000001' or user_id=current_setting('makeracc.fixture_user')::uuid
union all select 'browser_auth_exact_uuid',count(*) from auth.users where id=current_setting('makeracc.fixture_user')::uuid
union all select 'global_companies',count(*) from public.companies
union all select 'global_settings',count(*) from public.company_settings
union all select 'missing_settings',count(*) from public.companies c where not exists(select 1 from public.company_settings s where s.company_id=c.id)
union all select 'orphan_settings',count(*) from public.company_settings s where not exists(select 1 from public.companies c where c.id=s.company_id);
-- All fixture counts must be zero; global counts must match recorded preflight.
rollback;
