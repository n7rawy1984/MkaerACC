-- Fixture/Auth cleanup complete. Retained documentation; see README.md for current status.
-- Read-only; works before and after cleanup. Only fixture-scoped counts inspect out-of-scope tables.
begin read only;
do $verify$
declare r record; n bigint;
begin
  for r in select n.nspname as schema_name,c.relname as table_name from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('public','private') and c.relkind='r'
      and exists (select 1 from pg_attribute x where x.attrelid=c.oid and x.attname='company_id' and not x.attisdropped)
      and not (n.nspname='public' and c.relname in ('company_settings','company_memberships','projects','project_assignments','accounts','treasury_accounts'))
  loop
    execute format('select count(*) from %I.%I where company_id in ($1,$2)',r.schema_name,r.table_name) into n using '73000000-0000-4000-8000-0000000000a1'::uuid,'73000000-0000-4000-8000-0000000000a2'::uuid;
    if n <> 0 then raise exception 'Unexpected non-fixture rows in %.%',r.schema_name,r.table_name; end if;
  end loop;
  if (select count(*) from public.companies c full join public.company_settings s on s.company_id=c.id where c.id is null or s.company_id is null) <> 0 then raise exception 'Company/settings mismatch'; end if;
end;
$verify$;
select jsonb_build_object(
  'auth_exact',(select count(*) from auth.users where id='dc9ad1f5-804d-4f33-ab65-5e796fec0616' and email='p6c-slice3-user@example.test'),
  'profile',(select count(*) from public.profiles where user_id='dc9ad1f5-804d-4f33-ab65-5e796fec0616'),
  'companies',(select count(*) from public.companies where id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2')),
  'global_companies',(select count(*) from public.companies),
  'global_settings',(select count(*) from public.company_settings),
  'company_settings_mismatch',(select count(*) from public.companies c full join public.company_settings s on s.company_id=c.id where c.id is null or s.company_id is null),
  'company_settings',(select count(*) from public.company_settings where company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2')),
  'company_memberships',(select count(*) from public.company_memberships where company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2')),
  'projects',(select count(*) from public.projects where company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2')),
  'project_assignments',(select count(*) from public.project_assignments where company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2')),
  'accounts',(select count(*) from public.accounts where company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2')),
  'treasury_accounts',(select count(*) from public.treasury_accounts where company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2')),
  'alpha_projects',(select count(*) from public.projects where company_id='73000000-0000-4000-8000-0000000000a1'),
  'alpha_accounts',(select count(*) from public.accounts where company_id='73000000-0000-4000-8000-0000000000a1'),
  'alpha_treasury_accounts',(select count(*) from public.treasury_accounts where company_id='73000000-0000-4000-8000-0000000000a1'),
  'beta_projects',(select count(*) from public.projects where company_id='73000000-0000-4000-8000-0000000000a2'),
  'beta_accounts',(select count(*) from public.accounts where company_id='73000000-0000-4000-8000-0000000000a2'),
  'beta_treasury_accounts',(select count(*) from public.treasury_accounts where company_id='73000000-0000-4000-8000-0000000000a2'),
  'project_treasury',(select count(*) from public.treasury_accounts where company_id='73000000-0000-4000-8000-0000000000a1' and project_id='73000000-0000-4000-8000-0000000000c1'),
  'unrelated_memberships',(select count(*) from public.company_memberships where user_id='dc9ad1f5-804d-4f33-ab65-5e796fec0616' and id not in ('73000000-0000-4000-8000-0000000000b1','73000000-0000-4000-8000-0000000000b2')),
  'unrelated_assignments',(select count(*) from public.project_assignments where user_id='dc9ad1f5-804d-4f33-ab65-5e796fec0616' and id<>'73000000-0000-4000-8000-0000000000d1'),
  'active_assignment',(select count(*) from public.project_assignments where id='73000000-0000-4000-8000-0000000000d1' and status='ACTIVE'),
  'invalid_gl_links',(select count(*) from public.treasury_accounts t left join public.accounts a on a.id=t.gl_account_id and a.company_id=t.company_id where t.company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2') and (a.id is null or a.account_type<>'ASSET')),
  'duplicate_gl_links',(select count(*) from (select gl_account_id from public.treasury_accounts where company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2') group by gl_account_id having count(*)>1) d),
  'invalid_project_links',(select count(*) from public.treasury_accounts where company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2') and (company_id<>'73000000-0000-4000-8000-0000000000a1' or (project_id is not null and project_id<>'73000000-0000-4000-8000-0000000000c1'))),
  'financial_and_other_out_of_scope_rows',0,
  'memberships_detail',(select jsonb_agg(jsonb_build_object('company_id',company_id,'role',role,'status',status)) from public.company_memberships where user_id='dc9ad1f5-804d-4f33-ab65-5e796fec0616')
) as fixture_counts;
commit;
