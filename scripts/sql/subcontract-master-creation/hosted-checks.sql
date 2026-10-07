-- Development only; transaction-isolated fixtures, never population data.
-- Run after canonical migration. All fixtures and successful creations roll back.
begin;
create temporary table creation_results(label text primary key);
create function pg_temp.check(label text, command text, expected text default null) returns void language plpgsql as $$
begin
  begin
    execute command;
    if expected is not null then raise exception 'Expected SQLSTATE %: %', expected,label; end if;
  exception when others then
    if expected is null or sqlstate <> expected then raise; end if;
  end;
  insert into creation_results values(label);
end $$;
create function pg_temp.assert_true(label text, value boolean) returns void language plpgsql as $$
begin if value is not true then raise exception 'Failed: %',label; end if; insert into creation_results values(label); end $$;
grant select,insert on creation_results to authenticated;
select set_config('request.jwt.claim.sub',(select u.id::text from auth.users u join public.profiles p on p.user_id=u.id where p.status='ACTIVE' order by u.created_at limit 1),true);
do $$ begin if nullif(current_setting('request.jwt.claim.sub'), '') is null then raise exception 'No existing active test actor'; end if; end $$;
insert into public.companies(id,code,name,status) values
 ('97000000-0000-4000-8000-000000000001','VERIFY-CREATE-A','Rollback creation Alpha','ACTIVE'),
 ('97000000-0000-4000-8000-000000000002','VERIFY-CREATE-B','Rollback creation Beta','ACTIVE');
insert into public.company_memberships(company_id,user_id,role,status) values
 ('97000000-0000-4000-8000-000000000001',auth.uid(),'ACCOUNTING_ADMIN','ACTIVE');
insert into public.projects(id,company_id,code,name,status) values
 ('97000000-0000-4000-8000-000000000011','97000000-0000-4000-8000-000000000001','P1','Rollback Project','ACTIVE'),
 ('97000000-0000-4000-8000-000000000012','97000000-0000-4000-8000-000000000002','P2','Rollback Project','ACTIVE'),
 ('97000000-0000-4000-8000-000000000013','97000000-0000-4000-8000-000000000001','P3','Rollback Closed','CLOSED');
insert into public.parties(id,company_id,type,name,status) values
 ('97000000-0000-4000-8000-000000000021','97000000-0000-4000-8000-000000000001','SUBCONTRACTOR','Rollback Active','ACTIVE'),
 ('97000000-0000-4000-8000-000000000022','97000000-0000-4000-8000-000000000001','SUBCONTRACTOR','Rollback Inactive','INACTIVE'),
 ('97000000-0000-4000-8000-000000000023','97000000-0000-4000-8000-000000000002','SUBCONTRACTOR','Rollback Beta','ACTIVE');
create temporary table creation_counts as select
 (select count(*) from public.journal_entries) journals,(select count(*) from public.journal_lines) lines,
 (select count(*) from public.subcontractor_advances) advances,(select count(*) from public.subcontractor_certificates) certificates,
 (select count(*) from public.subcontractor_payments) payments,(select count(*) from public.subcontractor_retention_releases) releases,
 (select count(*) from public.subcontractor_retention_payments) retention_payments;
select set_config('test.creation.input','{"project_id":"97000000-0000-4000-8000-000000000011","subcontractor_id":"97000000-0000-4000-8000-000000000021","contract_number":"EXACT-1","scope_of_work":" Scope ","original_contract_value_minor":"9007199254740993","retention_bps":"525"}',true);
set local role authenticated;
select pg_temp.check('admin creates party', $q$select public.create_subcontractor_party('97000000-0000-4000-8000-000000000001','{"name":"  إنشاء Test  ","code":" SC-NEW ","notes":" "}')$q$);
select pg_temp.assert_true('party readback and provenance',exists(select 1 from public.parties where company_id='97000000-0000-4000-8000-000000000001' and code='SC-NEW' and type='SUBCONTRACTOR' and status='ACTIVE' and name='إنشاء Test' and notes is null and created_by=auth.uid() and updated_by=auth.uid()));
select pg_temp.check('missing name',$q$select public.create_subcontractor_party('97000000-0000-4000-8000-000000000001','{"name":" "}')$q$,'23514');
select pg_temp.check('duplicate code',$q$select public.create_subcontractor_party('97000000-0000-4000-8000-000000000001','{"name":"Test","code":"sc-new"}')$q$,'23505');
select pg_temp.check('protected party field',$q$select public.create_subcontractor_party('97000000-0000-4000-8000-000000000001','{"name":"Test","type":"SUPPLIER"}')$q$,'22023');
select pg_temp.check('admin creates subcontract',$q$select public.create_subcontract('97000000-0000-4000-8000-000000000001',current_setting('test.creation.input')::jsonb)$q$);
select pg_temp.assert_true('contract exact readback and provenance',exists(select 1 from public.subcontracts where company_id='97000000-0000-4000-8000-000000000001' and contract_number='EXACT-1' and scope_of_work='Scope' and original_contract_value_minor=9007199254740993 and approved_variations_minor=0 and retention_bps=525 and status='ACTIVE' and created_by=auth.uid() and updated_by=auth.uid()));
select pg_temp.check('duplicate contract',$q$select public.create_subcontract('97000000-0000-4000-8000-000000000001',current_setting('test.creation.input')::jsonb)$q$,'23505');
select pg_temp.check('missing project',$q$select public.create_subcontract('97000000-0000-4000-8000-000000000001',current_setting('test.creation.input')::jsonb || '{"project_id": null}'::jsonb)$q$,'22023');
select pg_temp.check('missing subcontractor',$q$select public.create_subcontract('97000000-0000-4000-8000-000000000001',current_setting('test.creation.input')::jsonb || '{"subcontractor_id": null}'::jsonb)$q$,'22023');
select pg_temp.check('inactive subcontractor',$q$select public.create_subcontract('97000000-0000-4000-8000-000000000001',current_setting('test.creation.input')::jsonb || '{"subcontractor_id": "97000000-0000-4000-8000-000000000022"}'::jsonb)$q$,'23514');
select pg_temp.check('cross company project',$q$select public.create_subcontract('97000000-0000-4000-8000-000000000001',current_setting('test.creation.input')::jsonb || '{"project_id": "97000000-0000-4000-8000-000000000012"}'::jsonb)$q$,'23514');
select pg_temp.check('cross company party',$q$select public.create_subcontract('97000000-0000-4000-8000-000000000001',current_setting('test.creation.input')::jsonb || '{"subcontractor_id": "97000000-0000-4000-8000-000000000023"}'::jsonb)$q$,'23514');
select pg_temp.check('closed project',$q$select public.create_subcontract('97000000-0000-4000-8000-000000000001',current_setting('test.creation.input')::jsonb || '{"project_id": "97000000-0000-4000-8000-000000000013"}'::jsonb)$q$,'23514');
select pg_temp.check('retention range',$q$select public.create_subcontract('97000000-0000-4000-8000-000000000001',current_setting('test.creation.input')::jsonb || '{"retention_bps": "10001"}'::jsonb)$q$,'23514');
select pg_temp.check('negative revised value',$q$select public.create_subcontract('97000000-0000-4000-8000-000000000001',current_setting('test.creation.input')::jsonb || '{"approved_variations_minor": "-9007199254740994"}'::jsonb)$q$,'23514');
select pg_temp.check('money overflow',$q$select public.create_subcontract('97000000-0000-4000-8000-000000000001',current_setting('test.creation.input')::jsonb || '{"original_contract_value_minor": "9223372036854775808"}'::jsonb)$q$,'22003');
select pg_temp.check('numeric json rejected',$q$select public.create_subcontract('97000000-0000-4000-8000-000000000001',current_setting('test.creation.input')::jsonb || '{"original_contract_value_minor": 1.25}'::jsonb)$q$,'22023');
select pg_temp.check('unrelated Company denied',$q$select public.create_subcontractor_party('97000000-0000-4000-8000-000000000002','{"name":"Test"}')$q$,'42501');
select pg_temp.assert_true('no broad inserts',not has_table_privilege('authenticated','public.parties','INSERT') and not has_table_privilege('authenticated','public.subcontracts','INSERT'));
select pg_temp.check('subcontract direct insert denied',$q$insert into public.subcontracts(company_id) values('97000000-0000-4000-8000-000000000001')$q$,'42501');
select pg_temp.check('subcontractor direct insert denied',$q$insert into public.parties(company_id,type,name) values('97000000-0000-4000-8000-000000000001','SUBCONTRACTOR','Test')$q$,'42501');
reset role;
update public.company_memberships set role='MANAGEMENT_VIEWER' where company_id='97000000-0000-4000-8000-000000000001' and user_id=auth.uid();
set local role authenticated;
select pg_temp.check('MANAGEMENT_VIEWER create_subcontractor_party denied',$q$select public.create_subcontractor_party('97000000-0000-4000-8000-000000000001','{"name":"Test"}')$q$,'42501');
select pg_temp.check('MANAGEMENT_VIEWER create_subcontract denied',$q$select public.create_subcontract('97000000-0000-4000-8000-000000000001',current_setting('test.creation.input')::jsonb)$q$,'42501');
reset role;
update public.company_memberships set role='PROCUREMENT' where company_id='97000000-0000-4000-8000-000000000001' and user_id=auth.uid();
set local role authenticated;
select pg_temp.check('PROCUREMENT create_subcontractor_party denied',$q$select public.create_subcontractor_party('97000000-0000-4000-8000-000000000001','{"name":"Test"}')$q$,'42501');
select pg_temp.check('PROCUREMENT create_subcontract denied',$q$select public.create_subcontract('97000000-0000-4000-8000-000000000001',current_setting('test.creation.input')::jsonb)$q$,'42501');
reset role;
update public.company_memberships set role='SYSTEM_ADMIN' where company_id='97000000-0000-4000-8000-000000000001' and user_id=auth.uid();
set local role authenticated;
select pg_temp.check('SYSTEM_ADMIN create_subcontractor_party denied',$q$select public.create_subcontractor_party('97000000-0000-4000-8000-000000000001','{"name":"Test"}')$q$,'42501');
select pg_temp.check('SYSTEM_ADMIN create_subcontract denied',$q$select public.create_subcontract('97000000-0000-4000-8000-000000000001',current_setting('test.creation.input')::jsonb)$q$,'42501');
reset role;
update public.company_memberships set role='ACCOUNTANT' where company_id='97000000-0000-4000-8000-000000000001' and user_id=auth.uid();
set local role authenticated;
select pg_temp.check('ACCOUNTANT create_subcontractor_party denied',$q$select public.create_subcontractor_party('97000000-0000-4000-8000-000000000001','{"name":"Test"}')$q$,'42501');
select pg_temp.check('ACCOUNTANT create_subcontract denied',$q$select public.create_subcontract('97000000-0000-4000-8000-000000000001',current_setting('test.creation.input')::jsonb)$q$,'42501');
reset role;
update public.company_memberships set role='ACCOUNTING_ADMIN',status='INACTIVE' where company_id='97000000-0000-4000-8000-000000000001' and user_id=auth.uid();
set local role authenticated;
select pg_temp.check('inactive membership denied',$q$select public.create_subcontractor_party('97000000-0000-4000-8000-000000000001','{"name":"Test"}')$q$,'42501');
reset role;
select set_config('request.jwt.claim.sub','',true);
set local role authenticated;
select pg_temp.check('missing actor denied',$q$select public.create_subcontractor_party('97000000-0000-4000-8000-000000000001','{"name":"Test"}')$q$,'42501');
reset role;
select pg_temp.assert_true('zero accounting effects', (select journals=(select count(*) from public.journal_entries) and lines=(select count(*) from public.journal_lines) and advances=(select count(*) from public.subcontractor_advances) and certificates=(select count(*) from public.subcontractor_certificates) and payments=(select count(*) from public.subcontractor_payments) and releases=(select count(*) from public.subcontractor_retention_releases) and retention_payments=(select count(*) from public.subcontractor_retention_payments) from creation_counts));
select pg_temp.assert_true('minimal execute grants',not has_function_privilege('anon','public.create_subcontract(uuid,jsonb)','EXECUTE') and not has_function_privilege('service_role','public.create_subcontract(uuid,jsonb)','EXECUTE') and not has_function_privilege('anon','public.create_subcontractor_party(uuid,jsonb)','EXECUTE') and not has_function_privilege('service_role','public.create_subcontractor_party(uuid,jsonb)','EXECUTE'));
select count(*) as passing_checks from creation_results;
rollback;
