begin read only;
select
 (select count(*) from public.companies where id in ('77200000-0000-4000-8000-0000000000a1','77200000-0000-4000-8000-0000000000a2')) as browser_companies,
 (select count(*) from auth.users where email='p6c-s7-browser@example.test') as browser_auth,
 (select count(*) from public.companies where id in ('77000000-0000-4000-8000-0000000000a1','77000000-0000-4000-8000-0000000000a2','77000000-0000-4000-8000-0000000000a3','77100000-0000-4000-8000-0000000000a1')) as fixture_companies,
 (select count(*) from auth.users where id in ('77000000-0000-4000-8000-000000000001','77100000-0000-4000-8000-000000000001')) as fixture_auth,
 (select count(*) from public.profiles where user_id in ('77000000-0000-4000-8000-000000000001','77100000-0000-4000-8000-000000000001')) as fixture_profiles,
 (select count(*) from public.company_memberships where user_id in ('77000000-0000-4000-8000-000000000001','77100000-0000-4000-8000-000000000001')) as fixture_memberships,
 (select count(*) from public.companies) as companies,
 (select count(*) from public.company_settings) as settings,
 (select count(*) from public.companies c left join public.company_settings s on s.company_id=c.id where s.company_id is null) as missing,
 (select count(*) from public.company_settings s left join public.companies c on c.id=s.company_id where c.id is null) as orphan;
commit;
