-- Development only. All synthetic master fixtures roll back; no financial writes.
begin;
create temporary table treasury_results(label text, passed boolean);
create function pg_temp.check_sql(label text, statement text, expected_state text default null, expected_rows integer default null)
returns void language plpgsql as $$
declare actual_rows integer; actual_state text;
begin
 begin execute statement; get diagnostics actual_rows=row_count;
 exception when others then get stacked diagnostics actual_state=returned_sqlstate; end;
 if actual_state is distinct from expected_state or (expected_rows is not null and actual_rows is distinct from expected_rows) then
 raise exception 'FAIL %: state %, rows % expected %, %',label,actual_state,actual_rows,expected_state,expected_rows; end if;
 insert into pg_temp.treasury_results values(label,true);
end; $$;
create function pg_temp.assert_true(label text, passed boolean) returns void language plpgsql as $$
begin if passed is distinct from true then raise exception 'FAIL %',label; end if;
 insert into pg_temp.treasury_results values(label,true); end; $$;
grant select,insert on treasury_results to authenticated,anon,service_role;
create temporary table treasury_before as select
 (select md5(coalesce(jsonb_agg(to_jsonb(t) order by id)::text,'')) from public.treasury_accounts t) treasuries,
 (select md5(coalesce(jsonb_agg(to_jsonb(t) order by id)::text,'')) from public.accounts t) accounts,
 (select md5(coalesce(jsonb_agg(to_jsonb(t) order by id)::text,'')) from public.expenses t) expenses,
 (select md5(coalesce(jsonb_agg(to_jsonb(t) order by id)::text,'')) from public.journal_entries t) journals,
 (select md5(coalesce(jsonb_agg(to_jsonb(t) order by id)::text,'')) from public.journal_lines t) lines;
insert into auth.users(id,email,raw_user_meta_data) values
 ('98000000-0000-4000-8000-000000000001','treasury-master-rollback@example.test','{"display_name":"Rollback"}');
insert into public.companies(id,code,name) values
 ('98000000-0000-4000-8000-0000000000a1','TREASURY-ROLLBACK-A','Rollback A'),
 ('98000000-0000-4000-8000-0000000000a2','TREASURY-ROLLBACK-B','Rollback B');
insert into public.company_memberships(company_id,user_id,role) values
 ('98000000-0000-4000-8000-0000000000a1','98000000-0000-4000-8000-000000000001','ACCOUNTING_ADMIN');
insert into public.accounts(id,company_id,code,name,account_type,status,requires_party,system_key) values
 ('98000000-0000-4000-8000-000000000011','98000000-0000-4000-8000-0000000000a1','A1','Cash GL','ASSET','ACTIVE',false,null),
 ('98000000-0000-4000-8000-000000000012','98000000-0000-4000-8000-0000000000a1','A2','Bank GL','ASSET','ACTIVE',false,null),
 ('98000000-0000-4000-8000-000000000013','98000000-0000-4000-8000-0000000000a1','A3','Inactive','ASSET','INACTIVE',false,null),
 ('98000000-0000-4000-8000-000000000014','98000000-0000-4000-8000-0000000000a1','A4','Party Asset','ASSET','ACTIVE',true,null),
 ('98000000-0000-4000-8000-000000000015','98000000-0000-4000-8000-0000000000a1','A5','VAT','ASSET','ACTIVE',false,'INPUT_VAT'),
 ('98000000-0000-4000-8000-000000000016','98000000-0000-4000-8000-0000000000a1','A6','Liability','LIABILITY','ACTIVE',false,null),
 ('98000000-0000-4000-8000-000000000017','98000000-0000-4000-8000-0000000000a2','A1','Other GL','ASSET','ACTIVE',false,null);
create temporary table fixture_accounts as select md5(jsonb_agg(to_jsonb(a) order by id)::text) hash from public.accounts a where company_id in ('98000000-0000-4000-8000-0000000000a1','98000000-0000-4000-8000-0000000000a2');
insert into public.projects(id,company_id,code,name,status) values
 ('98000000-0000-4000-8000-000000000021','98000000-0000-4000-8000-0000000000a1','P1','Site','ACTIVE'),
 ('98000000-0000-4000-8000-000000000022','98000000-0000-4000-8000-0000000000a2','P2','Foreign','ACTIVE'),
 ('98000000-0000-4000-8000-000000000023','98000000-0000-4000-8000-0000000000a1','P3','Closed','CLOSED');
select set_config('request.jwt.claim.sub','98000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;
select pg_temp.check_sql('admin creation', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":" Cash ","code":" CASH ","type":"CASH","gl_account_id":"98000000-0000-4000-8000-000000000011"}')$$,null,1);
select pg_temp.assert_true('authoritative normalized read and provenance',exists(select 1 from public.treasury_accounts where company_id='98000000-0000-4000-8000-0000000000a1' and code='CASH' and name='Cash' and status='ACTIVE' and gl_account_id='98000000-0000-4000-8000-000000000011' and created_by=auth.uid() and updated_by=auth.uid()));
select pg_temp.check_sql('direct insert remains denied', $$insert into public.treasury_accounts(company_id,code,name,type,gl_account_id) values('98000000-0000-4000-8000-0000000000a1','DIRECT','Denied','CASH','98000000-0000-4000-8000-000000000012')$$,'42501');
select pg_temp.check_sql('direct mapping write denied', $$update public.treasury_accounts set gl_account_id='98000000-0000-4000-8000-000000000012' where company_id='98000000-0000-4000-8000-0000000000a1'$$,'42501');
select pg_temp.check_sql('delete denied', $$delete from public.treasury_accounts where company_id='98000000-0000-4000-8000-0000000000a1'$$,'42501');
select pg_temp.check_sql('cross-company creation denied', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a2','{"name":"Foreign","code":"F","type":"BANK","gl_account_id":"98000000-0000-4000-8000-000000000017"}')$$,'42501');
select pg_temp.check_sql('foreign GL rejected', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Foreign GL","code":"F","type":"BANK","gl_account_id":"98000000-0000-4000-8000-000000000017"}')$$,'23514');
select pg_temp.check_sql('inactive GL rejected', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Invalid","code":"F","type":"BANK","gl_account_id":"98000000-0000-4000-8000-000000000013"}')$$,'23514');
select pg_temp.check_sql('Party GL rejected', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Invalid","code":"F","type":"BANK","gl_account_id":"98000000-0000-4000-8000-000000000014"}')$$,'23514');
select pg_temp.check_sql('system GL rejected', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Invalid","code":"F","type":"BANK","gl_account_id":"98000000-0000-4000-8000-000000000015"}')$$,'23514');
select pg_temp.check_sql('non-Asset GL rejected', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Invalid","code":"F","type":"BANK","gl_account_id":"98000000-0000-4000-8000-000000000016"}')$$,'23514');
select pg_temp.check_sql('missing GL rejected', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Invalid","code":"F","type":"BANK","gl_account_id":"98000000-0000-4000-8000-000000000099"}')$$,'23514');
select pg_temp.check_sql('foreign Project rejected', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Invalid","code":"F","type":"BANK","gl_account_id":"98000000-0000-4000-8000-000000000012","project_id":"98000000-0000-4000-8000-000000000022"}')$$,'23514');
select pg_temp.check_sql('closed Project rejected', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Invalid","code":"F","type":"BANK","gl_account_id":"98000000-0000-4000-8000-000000000012","project_id":"98000000-0000-4000-8000-000000000023"}')$$,'23514');
select pg_temp.check_sql('balance field rejected', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Invalid","code":"F","type":"BANK","gl_account_id":"98000000-0000-4000-8000-000000000012","balance":"100"}')$$,'22023');
select pg_temp.check_sql('forged actor rejected', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Invalid","code":"F","type":"BANK","gl_account_id":"98000000-0000-4000-8000-000000000012","created_by":"98000000-0000-4000-8000-000000000001"}')$$,'22023');
select pg_temp.check_sql('invalid type rejected', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"X","code":"X","type":"FAKE","gl_account_id":"98000000-0000-4000-8000-000000000012"}')$$,'22P02');
select pg_temp.check_sql('malformed GL rejected', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"X","code":"X","type":"CASH","gl_account_id":"bad"}')$$,'22P02');
select pg_temp.check_sql('blank name rejected', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"   ","code":"X","type":"CASH","gl_account_id":"98000000-0000-4000-8000-000000000012"}')$$,'23514');
select pg_temp.check_sql('invalid status rejected', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"X","code":"X","type":"CASH","gl_account_id":"98000000-0000-4000-8000-000000000012","status":"CLOSED"}')$$,'22P02');
select pg_temp.check_sql('funding input rejected', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"X","code":"X","type":"CASH","gl_account_id":"98000000-0000-4000-8000-000000000012","funding_source":"OWNER"}')$$,'22023');
select pg_temp.check_sql('duplicate normalized code', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Duplicate","code":" cash ","type":"BANK","gl_account_id":"98000000-0000-4000-8000-000000000012"}')$$,'23505');
select pg_temp.check_sql('one GL per Treasury', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Duplicate GL","code":"OTHER","type":"BANK","gl_account_id":"98000000-0000-4000-8000-000000000011"}')$$,'23505');
select pg_temp.check_sql('deactivate', $$select public.set_treasury_master_status(company_id,id,'INACTIVE',updated_at) from public.treasury_accounts where company_id='98000000-0000-4000-8000-0000000000a1' and code='CASH'$$,null,1);
select pg_temp.assert_true('inactive Treasury preserves mapping and identity',exists(select 1 from public.treasury_accounts where company_id='98000000-0000-4000-8000-0000000000a1' and code='CASH' and status='INACTIVE' and gl_account_id='98000000-0000-4000-8000-000000000011'));
select pg_temp.assert_true('Payroll context excludes inactive Treasury',jsonb_array_length(public.read_payroll_postings('98000000-0000-4000-8000-0000000000a1','2026-10-01')->'treasuries')=0);
select pg_temp.check_sql('inactive GL mapping stays reserved', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Reused","code":"OTHER","type":"CASH","gl_account_id":"98000000-0000-4000-8000-000000000011"}')$$,'23505');
select pg_temp.check_sql('stale status fails', $$select public.set_treasury_master_status(company_id,id,'ACTIVE','2000-01-01') from public.treasury_accounts where company_id='98000000-0000-4000-8000-0000000000a1' and code='CASH'$$,'40001');
select pg_temp.check_sql('reactivate', $$select public.set_treasury_master_status(company_id,id,'ACTIVE',updated_at) from public.treasury_accounts where company_id='98000000-0000-4000-8000-0000000000a1' and code='CASH'$$,null,1);
select pg_temp.check_sql('existing name update works', $$update public.treasury_accounts set name='Cash renamed' where company_id='98000000-0000-4000-8000-0000000000a1' and code='CASH'$$,null,1);
select pg_temp.check_sql('Project Bank creation', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Site Bank","code":"BANK","type":"PROJECT_BANK","project_id":"98000000-0000-4000-8000-000000000021","gl_account_id":"98000000-0000-4000-8000-000000000012","bank_name":"Test","account_reference":"REF","notes":"Synthetic"}')$$,null,1);
select pg_temp.assert_true('current active Treasury/Asset selectors see new masters', (select count(*)=2 from public.treasury_accounts t join public.accounts a on a.id=t.gl_account_id and a.company_id=t.company_id where t.company_id='98000000-0000-4000-8000-0000000000a1' and t.status='ACTIVE' and a.status='ACTIVE' and a.account_type='ASSET'));
select pg_temp.assert_true('Payroll context reads both active Treasury masters',jsonb_array_length(public.read_payroll_postings('98000000-0000-4000-8000-0000000000a1','2026-10-01')->'treasuries')=2);
select pg_temp.check_sql('Payroll Treasury context Company boundary', $$select public.read_payroll_postings('98000000-0000-4000-8000-0000000000a2','2026-10-01')$$,'42501');
select pg_temp.assert_true('Project selector scope unchanged',(select count(*)=1 from public.treasury_accounts where company_id='98000000-0000-4000-8000-0000000000a1' and status='ACTIVE' and project_id is null));
reset role;
create temporary table selected_treasury as select company_id,id,updated_at from public.treasury_accounts where company_id='98000000-0000-4000-8000-0000000000a1' and code='CASH';
grant select on selected_treasury to authenticated;
select pg_temp.check_sql('trusted remapping still forbidden', $$update public.treasury_accounts set gl_account_id='98000000-0000-4000-8000-000000000012' where company_id='98000000-0000-4000-8000-0000000000a1' and code='CASH'$$,'23514');
update public.company_memberships set role='ACCOUNTANT' where user_id='98000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('ACCOUNTANT creation denied', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Denied","code":"D","type":"CASH","gl_account_id":"98000000-0000-4000-8000-000000000011"}')$$,'42501');
select pg_temp.check_sql('ACCOUNTANT status denied', $$select public.set_treasury_master_status(company_id,id,'INACTIVE',updated_at) from pg_temp.selected_treasury$$,'42501');
select pg_temp.check_sql('ACCOUNTANT name update denied', $$update public.treasury_accounts set name='Denied' where company_id='98000000-0000-4000-8000-0000000000a1'$$,null,0);
reset role;
update public.company_memberships set role='MANAGEMENT_VIEWER' where user_id='98000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('MANAGEMENT_VIEWER creation denied', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Denied","code":"D","type":"CASH","gl_account_id":"98000000-0000-4000-8000-000000000011"}')$$,'42501');
select pg_temp.check_sql('MANAGEMENT_VIEWER status denied', $$select public.set_treasury_master_status(company_id,id,'INACTIVE',updated_at) from pg_temp.selected_treasury$$,'42501');
select pg_temp.check_sql('MANAGEMENT_VIEWER name update denied', $$update public.treasury_accounts set name='Denied' where company_id='98000000-0000-4000-8000-0000000000a1'$$,null,0);
reset role;
update public.company_memberships set role='PROJECT_MANAGER' where user_id='98000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('PROJECT_MANAGER creation denied', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Denied","code":"D","type":"CASH","gl_account_id":"98000000-0000-4000-8000-000000000011"}')$$,'42501');
select pg_temp.check_sql('PROJECT_MANAGER status denied', $$select public.set_treasury_master_status(company_id,id,'INACTIVE',updated_at) from pg_temp.selected_treasury$$,'42501');
select pg_temp.check_sql('PROJECT_MANAGER name update denied', $$update public.treasury_accounts set name='Denied' where company_id='98000000-0000-4000-8000-0000000000a1'$$,null,0);
reset role;
update public.company_memberships set role='SYSTEM_ADMIN' where user_id='98000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('SYSTEM_ADMIN creation denied', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Denied","code":"D","type":"CASH","gl_account_id":"98000000-0000-4000-8000-000000000011"}')$$,'42501');
select pg_temp.check_sql('SYSTEM_ADMIN status denied', $$select public.set_treasury_master_status(company_id,id,'INACTIVE',updated_at) from pg_temp.selected_treasury$$,'42501');
select pg_temp.check_sql('SYSTEM_ADMIN name update denied', $$update public.treasury_accounts set name='Denied' where company_id='98000000-0000-4000-8000-0000000000a1'$$,null,0);
reset role;
update public.company_memberships set role='PROCUREMENT' where user_id='98000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('PROCUREMENT creation denied', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Denied","code":"D","type":"CASH","gl_account_id":"98000000-0000-4000-8000-000000000011"}')$$,'42501');
select pg_temp.check_sql('PROCUREMENT status denied', $$select public.set_treasury_master_status(company_id,id,'INACTIVE',updated_at) from pg_temp.selected_treasury$$,'42501');
select pg_temp.check_sql('PROCUREMENT name update denied', $$update public.treasury_accounts set name='Denied' where company_id='98000000-0000-4000-8000-0000000000a1'$$,null,0);
reset role;
update public.company_memberships set role='DATA_ENTRY' where user_id='98000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('DATA_ENTRY creation denied', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Denied","code":"D","type":"CASH","gl_account_id":"98000000-0000-4000-8000-000000000011"}')$$,'42501');
select pg_temp.check_sql('DATA_ENTRY status denied', $$select public.set_treasury_master_status(company_id,id,'INACTIVE',updated_at) from pg_temp.selected_treasury$$,'42501');
select pg_temp.check_sql('DATA_ENTRY name update denied', $$update public.treasury_accounts set name='Denied' where company_id='98000000-0000-4000-8000-0000000000a1'$$,null,0);
reset role;
update public.company_memberships set role='FOREMAN' where user_id='98000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('FOREMAN creation denied', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Denied","code":"D","type":"CASH","gl_account_id":"98000000-0000-4000-8000-000000000011"}')$$,'42501');
select pg_temp.check_sql('FOREMAN status denied', $$select public.set_treasury_master_status(company_id,id,'INACTIVE',updated_at) from pg_temp.selected_treasury$$,'42501');
select pg_temp.check_sql('FOREMAN name update denied', $$update public.treasury_accounts set name='Denied' where company_id='98000000-0000-4000-8000-0000000000a1'$$,null,0);
reset role;
update public.company_memberships set role='ACCOUNTING_ADMIN' where user_id='98000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('foreign-company status denied', $$select public.set_treasury_master_status('98000000-0000-4000-8000-0000000000a2',id,'INACTIVE',updated_at) from pg_temp.selected_treasury$$,'42501');
select pg_temp.check_sql('foreign identity with authorized Company denied', $$select public.set_treasury_master_status('98000000-0000-4000-8000-0000000000a1','98000000-0000-4000-8000-000000000099','INACTIVE',now())$$,'42501');
reset role;
update public.profiles set status='INACTIVE' where user_id='98000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('inactive profiles create denied', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Denied","code":"D","type":"CASH","gl_account_id":"98000000-0000-4000-8000-000000000011"}')$$,'42501');
select pg_temp.check_sql('inactive profiles status denied', $$select public.set_treasury_master_status(company_id,id,'INACTIVE',updated_at) from pg_temp.selected_treasury$$,'42501');
reset role;
update public.profiles set status='ACTIVE' where user_id='98000000-0000-4000-8000-000000000001';
update public.company_memberships set status='INACTIVE' where user_id='98000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('inactive company_memberships create denied', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Denied","code":"D","type":"CASH","gl_account_id":"98000000-0000-4000-8000-000000000011"}')$$,'42501');
select pg_temp.check_sql('inactive company_memberships status denied', $$select public.set_treasury_master_status(company_id,id,'INACTIVE',updated_at) from pg_temp.selected_treasury$$,'42501');
reset role;
update public.company_memberships set status='ACTIVE' where user_id='98000000-0000-4000-8000-000000000001';
update public.companies set status='INACTIVE' where id='98000000-0000-4000-8000-0000000000a1';
set local role authenticated;
select pg_temp.check_sql('inactive companies create denied', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{"name":"Denied","code":"D","type":"CASH","gl_account_id":"98000000-0000-4000-8000-000000000011"}')$$,'42501');
select pg_temp.check_sql('inactive companies status denied', $$select public.set_treasury_master_status(company_id,id,'INACTIVE',updated_at) from pg_temp.selected_treasury$$,'42501');
reset role;
update public.companies set status='ACTIVE' where id='98000000-0000-4000-8000-0000000000a1';
insert into public.company_memberships(company_id,user_id,role) values('98000000-0000-4000-8000-0000000000a2','98000000-0000-4000-8000-000000000001','ACCOUNTING_ADMIN');
set local role authenticated;
select pg_temp.check_sql('same code other Company allowed', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a2','{"name":"Cash","code":"CASH","type":"CASH","gl_account_id":"98000000-0000-4000-8000-000000000017"}')$$,null,1);
reset role;
set local role anon;
select pg_temp.check_sql('anon RPC denied', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{}')$$,'42501');
reset role;
set local role service_role;
select pg_temp.check_sql('service role RPC denied', $$select public.create_treasury_master('98000000-0000-4000-8000-0000000000a1','{}')$$,'42501');
reset role;
select pg_temp.assert_true('forced RLS',(select relrowsecurity and relforcerowsecurity from pg_class where oid='public.treasury_accounts'::regclass));
select pg_temp.assert_true('financial references cannot cascade delete',not exists(select 1 from pg_constraint where confrelid='public.treasury_accounts'::regclass and contype='f' and confdeltype not in ('r','a')));
select pg_temp.assert_true('no broad browser DML',not has_table_privilege('authenticated','public.treasury_accounts','INSERT,UPDATE,DELETE,TRUNCATE'));
select pg_temp.assert_true('fixture GL rows unchanged', (select hash=(select md5(jsonb_agg(to_jsonb(a) order by id)::text) from public.accounts a where company_id in ('98000000-0000-4000-8000-0000000000a1','98000000-0000-4000-8000-0000000000a2')) from fixture_accounts));
select pg_temp.assert_true('Demo/existing Treasury, GL and financial data unchanged', exists(select 1 from treasury_before where
 treasuries=(select md5(coalesce(jsonb_agg(to_jsonb(t) order by id)::text,'')) from public.treasury_accounts t where company_id not in ('98000000-0000-4000-8000-0000000000a1','98000000-0000-4000-8000-0000000000a2')) and
 accounts=(select md5(coalesce(jsonb_agg(to_jsonb(t) order by id)::text,'')) from public.accounts t where company_id not in ('98000000-0000-4000-8000-0000000000a1','98000000-0000-4000-8000-0000000000a2')) and
 expenses=(select md5(coalesce(jsonb_agg(to_jsonb(t) order by id)::text,'')) from public.expenses t) and
 journals=(select md5(coalesce(jsonb_agg(to_jsonb(t) order by id)::text,'')) from public.journal_entries t) and
 lines=(select md5(coalesce(jsonb_agg(to_jsonb(t) order by id)::text,'')) from public.journal_lines t)));
select pg_temp.assert_true('RPCs constrained SECURITY DEFINER and empty search_path',
 (select count(*)=2 and bool_and(prosecdef and proconfig=array['search_path=""'] and not has_function_privilege('anon',oid,'EXECUTE') and not has_function_privilege('service_role',oid,'EXECUTE') and has_function_privilege('authenticated',oid,'EXECUTE')) from pg_proc where oid in ('public.create_treasury_master(uuid,jsonb)'::regprocedure,'public.set_treasury_master_status(uuid,uuid,public.account_status,timestamptz)'::regprocedure)));
select count(*) passing_assertions,bool_and(passed) all_passed,jsonb_agg(label) checks from treasury_results;
rollback;
