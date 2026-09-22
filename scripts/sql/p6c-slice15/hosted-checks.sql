-- Development-only rollback verification. No durable fixtures or schema changes.
begin;
do $$ begin
 if not exists(select 1 from supabase_migrations.schema_migrations where version='20260922150000') then raise exception 'Slice 15 migration required'; end if;
end $$;
create temporary table slice15_results(label text, passed boolean);
grant select,insert on pg_temp.slice15_results to authenticated,anon,service_role;
create function pg_temp.check_sql(label text, statement text, expected_state text default null, expected_rows integer default null)
returns void language plpgsql as $$
declare actual_rows integer; actual_state text;
begin
 begin execute statement; get diagnostics actual_rows=row_count;
 exception when others then get stacked diagnostics actual_state=returned_sqlstate; end;
 if actual_state is distinct from expected_state or (expected_rows is not null and actual_rows is distinct from expected_rows) then
  raise exception 'FAIL %: state %, rows % (expected %, %)',label,actual_state,actual_rows,expected_state,expected_rows;
 end if;
 insert into pg_temp.slice15_results values(label,true);
end $$;
create function pg_temp.assert_true(label text, passed boolean) returns void language plpgsql as $$
begin if passed is distinct from true then raise exception 'FAIL %',label; end if;
 insert into pg_temp.slice15_results values(label,true); end $$;

-- Reuse an existing synthetic actor; never create/delete an Auth user.
do $$ begin
 if not exists(select 1 from auth.users u join public.profiles p on p.user_id=u.id where u.id='7cf0bfff-6938-4beb-a0ff-0ed726867304' and u.email='maker-p2v-accountant_a-1787848792973-68f666@example.invalid' and p.status='ACTIVE') then raise exception 'Existing synthetic actor unavailable'; end if;
end $$;
insert into public.companies(id,code,name) values ('85000000-0000-4000-8000-0000000000a1','P6C-S15-ROLLBACK-A','S15 rollback A'),('85000000-0000-4000-8000-0000000000a2','P6C-S15-ROLLBACK-B','S15 rollback B');
insert into public.company_memberships(company_id,user_id,role) values ('85000000-0000-4000-8000-0000000000a1','7cf0bfff-6938-4beb-a0ff-0ed726867304','ACCOUNTING_ADMIN');
insert into public.parties(id,company_id,type,name,code,status,updated_at) values ('85000000-0000-4000-8000-0000000000b1','85000000-0000-4000-8000-0000000000a1','SUBCONTRACTOR','Original','0001','INACTIVE','2000-01-01T00:00:00.123456Z'),('85000000-0000-4000-8000-0000000000b2','85000000-0000-4000-8000-0000000000a1','SUBCONTRACTOR','Active','0002','ACTIVE','2000-01-01T00:00:00.123456Z'),('85000000-0000-4000-8000-0000000000b3','85000000-0000-4000-8000-0000000000a2','SUBCONTRACTOR','Beta','0003','ACTIVE','2000-01-01T00:00:00.123456Z');
select pg_temp.assert_true('FORCE RLS',(select relrowsecurity and relforcerowsecurity from pg_class where oid='public.parties'::regclass));
select pg_temp.assert_true('no broad writes',not has_table_privilege('authenticated','public.parties','INSERT,UPDATE,DELETE,TRUNCATE'));
select pg_temp.assert_true('invoker fixed path',(select not prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.prepare_subcontractor_party_name_update()'::regprocedure));
do $$ declare c record; begin
 for c in select attname from pg_attribute where attrelid='public.parties'::regclass and attnum>0 and not attisdropped loop
 perform pg_temp.assert_true(c.attname||' exact update grant',has_column_privilege('authenticated','public.parties',c.attname,'UPDATE')=(c.attname=any(array['name','code','trn','contact_person','phone','email','address','notes','status'])));
 perform pg_temp.assert_true(c.attname||' exact insert grant',has_column_privilege('authenticated','public.parties',c.attname,'INSERT')=(c.attname=any(array['company_id','name','code','trn','contact_person','phone','email','address','notes'])));
 end loop;
end $$;
select pg_temp.assert_true('anon no trigger execute',not has_function_privilege('anon','public.prepare_subcontractor_party_name_update()','EXECUTE'));
select pg_temp.assert_true('authenticated no trigger execute',not has_function_privilege('authenticated','public.prepare_subcontractor_party_name_update()','EXECUTE'));
select pg_temp.assert_true('service_role no trigger execute',not has_function_privilege('service_role','public.prepare_subcontractor_party_name_update()','EXECUTE'));
select set_config('request.jwt.claim.sub','7cf0bfff-6938-4beb-a0ff-0ed726867304',true);
reset role; update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id='85000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
reset role;
insert into public.projects(id,company_id,code,name) values ('85000000-0000-4000-8000-0000000000c1','85000000-0000-4000-8000-0000000000a1','P1','Test project');
insert into public.subcontracts(id,company_id,project_id,subcontractor_id,contract_number,scope_of_work,original_contract_value_minor,retention_bps)
values ('85000000-0000-4000-8000-0000000000d1','85000000-0000-4000-8000-0000000000a1','85000000-0000-4000-8000-0000000000c1','85000000-0000-4000-8000-0000000000b2','0001','Historic scope',0,0);
create temporary table historical_subcontract as select to_jsonb(s) as row from public.subcontracts s where id='85000000-0000-4000-8000-0000000000d1';
create temporary table historical_counts as select
 (select count(*) from public.subcontractor_advances) advances,
 (select count(*) from public.subcontractor_certificates) certificates,
 (select count(*) from public.subcontractor_payments) payments,
 (select count(*) from public.subcontractor_retention_releases) releases,
 (select count(*) from public.subcontractor_retention_payments) retention_payments,
 (select count(*) from public.journal_entries) journals,
 (select count(*) from public.journal_lines) lines;
set local role authenticated;
select pg_temp.check_sql('ACCOUNTING_ADMIN row 1',$q$update public.parties set name=chr(65279)||'  جهة Mixed  ' where id='85000000-0000-4000-8000-0000000000b1'$q$,null,1);
select pg_temp.check_sql('ACCOUNTING_ADMIN row 2',$q$update public.parties set name=chr(65279)||'  جهة Mixed  ' where id='85000000-0000-4000-8000-0000000000b2'$q$,null,1);
select pg_temp.check_sql('ACCOUNTING_ADMIN row 3',$q$update public.parties set name=chr(65279)||'  جهة Mixed  ' where id='85000000-0000-4000-8000-0000000000b3'$q$,null,0);
select pg_temp.check_sql('ACCOUNTING_ADMIN local SUBCONTRACTOR read',$q$select id from public.parties where id='85000000-0000-4000-8000-0000000000b1'$q$,null,1);
select pg_temp.check_sql('ACCOUNTING_ADMIN cross tenant read',$q$select id from public.parties where id='85000000-0000-4000-8000-0000000000b3'$q$,null,0);
reset role; update public.company_memberships set role='PROCUREMENT' where company_id='85000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('PROCUREMENT row 1',$q$update public.parties set name=chr(65279)||'  جهة Mixed  ' where id='85000000-0000-4000-8000-0000000000b1'$q$,null,1);
select pg_temp.check_sql('PROCUREMENT row 2',$q$update public.parties set name=chr(65279)||'  جهة Mixed  ' where id='85000000-0000-4000-8000-0000000000b2'$q$,null,1);
select pg_temp.check_sql('PROCUREMENT row 3',$q$update public.parties set name=chr(65279)||'  جهة Mixed  ' where id='85000000-0000-4000-8000-0000000000b3'$q$,null,0);
select pg_temp.check_sql('PROCUREMENT local SUBCONTRACTOR read',$q$select id from public.parties where id='85000000-0000-4000-8000-0000000000b1'$q$,null,1);
select pg_temp.check_sql('PROCUREMENT cross tenant read',$q$select id from public.parties where id='85000000-0000-4000-8000-0000000000b3'$q$,null,0);
reset role; update public.company_memberships set role='ACCOUNTANT' where company_id='85000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('ACCOUNTANT row 1',$q$update public.parties set name=chr(65279)||'  جهة Mixed  ' where id='85000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('ACCOUNTANT row 2',$q$update public.parties set name=chr(65279)||'  جهة Mixed  ' where id='85000000-0000-4000-8000-0000000000b2'$q$,null,0);
select pg_temp.check_sql('ACCOUNTANT row 3',$q$update public.parties set name=chr(65279)||'  جهة Mixed  ' where id='85000000-0000-4000-8000-0000000000b3'$q$,null,0);
select pg_temp.check_sql('ACCOUNTANT local SUBCONTRACTOR read',$q$select id from public.parties where id='85000000-0000-4000-8000-0000000000b1'$q$,null,1);
select pg_temp.check_sql('ACCOUNTANT cross tenant read',$q$select id from public.parties where id='85000000-0000-4000-8000-0000000000b3'$q$,null,0);
reset role; update public.company_memberships set role='DATA_ENTRY' where company_id='85000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('DATA_ENTRY row 1',$q$update public.parties set name=chr(65279)||'  جهة Mixed  ' where id='85000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('DATA_ENTRY row 2',$q$update public.parties set name=chr(65279)||'  جهة Mixed  ' where id='85000000-0000-4000-8000-0000000000b2'$q$,null,0);
select pg_temp.check_sql('DATA_ENTRY row 3',$q$update public.parties set name=chr(65279)||'  جهة Mixed  ' where id='85000000-0000-4000-8000-0000000000b3'$q$,null,0);
select pg_temp.check_sql('DATA_ENTRY local SUBCONTRACTOR read',$q$select id from public.parties where id='85000000-0000-4000-8000-0000000000b1'$q$,null,1);
select pg_temp.check_sql('DATA_ENTRY cross tenant read',$q$select id from public.parties where id='85000000-0000-4000-8000-0000000000b3'$q$,null,0);
reset role; update public.company_memberships set role='MANAGEMENT_VIEWER' where company_id='85000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('MANAGEMENT_VIEWER row 1',$q$update public.parties set name=chr(65279)||'  جهة Mixed  ' where id='85000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('MANAGEMENT_VIEWER row 2',$q$update public.parties set name=chr(65279)||'  جهة Mixed  ' where id='85000000-0000-4000-8000-0000000000b2'$q$,null,0);
select pg_temp.check_sql('MANAGEMENT_VIEWER row 3',$q$update public.parties set name=chr(65279)||'  جهة Mixed  ' where id='85000000-0000-4000-8000-0000000000b3'$q$,null,0);
select pg_temp.check_sql('MANAGEMENT_VIEWER local SUBCONTRACTOR read',$q$select id from public.parties where id='85000000-0000-4000-8000-0000000000b1'$q$,null,1);
select pg_temp.check_sql('MANAGEMENT_VIEWER cross tenant read',$q$select id from public.parties where id='85000000-0000-4000-8000-0000000000b3'$q$,null,0);
reset role; update public.company_memberships set role='PROJECT_MANAGER' where company_id='85000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('PROJECT_MANAGER row 1',$q$update public.parties set name=chr(65279)||'  جهة Mixed  ' where id='85000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('PROJECT_MANAGER row 2',$q$update public.parties set name=chr(65279)||'  جهة Mixed  ' where id='85000000-0000-4000-8000-0000000000b2'$q$,null,0);
select pg_temp.check_sql('PROJECT_MANAGER row 3',$q$update public.parties set name=chr(65279)||'  جهة Mixed  ' where id='85000000-0000-4000-8000-0000000000b3'$q$,null,0);
select pg_temp.check_sql('PROJECT_MANAGER local SUBCONTRACTOR read',$q$select id from public.parties where id='85000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('PROJECT_MANAGER cross tenant read',$q$select id from public.parties where id='85000000-0000-4000-8000-0000000000b3'$q$,null,0);
reset role; update public.company_memberships set role='SYSTEM_ADMIN' where company_id='85000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('SYSTEM_ADMIN row 1',$q$update public.parties set name=chr(65279)||'  جهة Mixed  ' where id='85000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('SYSTEM_ADMIN row 2',$q$update public.parties set name=chr(65279)||'  جهة Mixed  ' where id='85000000-0000-4000-8000-0000000000b2'$q$,null,0);
select pg_temp.check_sql('SYSTEM_ADMIN row 3',$q$update public.parties set name=chr(65279)||'  جهة Mixed  ' where id='85000000-0000-4000-8000-0000000000b3'$q$,null,0);
select pg_temp.check_sql('SYSTEM_ADMIN local SUBCONTRACTOR read',$q$select id from public.parties where id='85000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('SYSTEM_ADMIN cross tenant read',$q$select id from public.parties where id='85000000-0000-4000-8000-0000000000b3'$q$,null,0);
reset role; update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id='85000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('protected id',$q$update public.parties set id=id where id='85000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected company_id',$q$update public.parties set company_id=company_id where id='85000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected type',$q$update public.parties set type=type where id='85000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected created_by',$q$update public.parties set created_by=created_by where id='85000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected created_at',$q$update public.parties set created_at=created_at where id='85000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected updated_by',$q$update public.parties set updated_by=updated_by where id='85000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected updated_at',$q$update public.parties set updated_at=updated_at where id='85000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected status',$q$update public.parties set status='ACTIVE' where id='85000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected code',$q$update public.parties set code='FORGED' where id='85000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected trn',$q$update public.parties set trn='999' where id='85000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected contact_person',$q$update public.parties set contact_person='X' where id='85000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected phone',$q$update public.parties set phone='1' where id='85000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected email',$q$update public.parties set email='x@example.test' where id='85000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected address',$q$update public.parties set address='X' where id='85000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected notes',$q$update public.parties set notes='X' where id='85000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('invalid 12889',$q$update public.parties set name='' where id='85000000-0000-4000-8000-0000000000b1'$q$,'23514');
select pg_temp.check_sql('invalid 13028',$q$update public.parties set name=chr(65279)||chr(160) where id='85000000-0000-4000-8000-0000000000b1'$q$,'23514');
select pg_temp.check_sql('invalid 13185',$q$update public.parties set name=repeat('a',201) where id='85000000-0000-4000-8000-0000000000b1'$q$,'23514');
select pg_temp.check_sql('invalid 13337',$q$update public.parties set name=null where id='85000000-0000-4000-8000-0000000000b1'$q$,'23502');
select pg_temp.check_sql('unicode 200',$q$update public.parties set name=repeat('😀',200) where id='85000000-0000-4000-8000-0000000000b2'$q$,null,1);
select pg_temp.check_sql('trim name',$q$update public.parties set name=chr(65279)||'  جهة Mixed  ' where id='85000000-0000-4000-8000-0000000000b1'$q$,null,1);
reset role;
select pg_temp.assert_true('subcontract source fields unchanged',(select to_jsonb(s)=(select row from pg_temp.historical_subcontract) from public.subcontracts s where id='85000000-0000-4000-8000-0000000000d1'));
select pg_temp.assert_true('financial and journal counts unchanged',(select
 (select count(*) from public.subcontractor_advances)=h.advances and
 (select count(*) from public.subcontractor_certificates)=h.certificates and
 (select count(*) from public.subcontractor_payments)=h.payments and
 (select count(*) from public.subcontractor_retention_releases)=h.releases and
 (select count(*) from public.subcontractor_retention_payments)=h.retention_payments and
 (select count(*) from public.journal_entries)=h.journals and
 (select count(*) from public.journal_lines)=h.lines from pg_temp.historical_counts h));
reset role;
select pg_temp.assert_true('normalized and actor',(select name='جهة Mixed' and updated_by='7cf0bfff-6938-4beb-a0ff-0ed726867304' and code='0001' and status='INACTIVE' and created_by is null from public.parties where id='85000000-0000-4000-8000-0000000000b1'));
create temporary table original_token as select updated_at from public.parties where id='85000000-0000-4000-8000-0000000000b1';
grant select on pg_temp.original_token to authenticated;
set local role authenticated;
select pg_temp.check_sql('first exact token',$q$update public.parties set name=name where id='85000000-0000-4000-8000-0000000000b1' and updated_at=(select updated_at from pg_temp.original_token)$q$,null,1);
select pg_temp.check_sql('stale exact token',$q$update public.parties set name='stale' where id='85000000-0000-4000-8000-0000000000b1' and updated_at=(select updated_at from pg_temp.original_token)$q$,null,0);
reset role;
select pg_temp.assert_true('no-op monotonic',(select updated_at>(select updated_at from pg_temp.original_token) from public.parties where id='85000000-0000-4000-8000-0000000000b1'));
insert into public.parties(id,company_id,type,name,updated_at) values ('85000000-0000-4000-8000-0000000000b4','85000000-0000-4000-8000-0000000000a1','SUBCONTRACTOR','Future','2099-01-01');
set local role authenticated;
select pg_temp.check_sql('future token',$q$update public.parties set name='Future rename' where id='85000000-0000-4000-8000-0000000000b4'$q$,null,1);
reset role; select pg_temp.assert_true('future monotonic',(select updated_at>'2099-01-01' from public.parties where id='85000000-0000-4000-8000-0000000000b4'));
reset role; update public.company_memberships set status='INACTIVE' where company_id='85000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('inactive membership',$q$update public.parties set name='denied' where id='85000000-0000-4000-8000-0000000000b1'$q$,null,0);
reset role; update public.company_memberships set status='ACTIVE' where company_id='85000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304';
reset role; update public.profiles set status='INACTIVE' where user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('inactive profile',$q$update public.parties set name='denied' where id='85000000-0000-4000-8000-0000000000b1'$q$,null,0);
reset role; update public.profiles set status='ACTIVE' where user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304';
reset role; update public.companies set status='INACTIVE' where id='85000000-0000-4000-8000-0000000000a1'; set local role authenticated;
select pg_temp.check_sql('inactive company',$q$update public.parties set name='denied' where id='85000000-0000-4000-8000-0000000000b1'$q$,null,0);
reset role; update public.companies set status='ACTIVE' where id='85000000-0000-4000-8000-0000000000a1';
insert into public.parties(id,company_id,type,name) values ('85000000-0000-4000-8000-0000000000b5','85000000-0000-4000-8000-0000000000a1','CUSTODIAN','Trusted'); set local role authenticated;
select pg_temp.check_sql('CUSTODIAN previous scope retained',$q$update public.parties set name='allowed' where id='85000000-0000-4000-8000-0000000000b5'$q$,null,1);
reset role;
insert into public.parties(id,company_id,type,name) values ('85000000-0000-4000-8000-0000000000b6','85000000-0000-4000-8000-0000000000a1','OTHER','Trusted'); set local role authenticated;
select pg_temp.check_sql('OTHER previous scope retained',$q$update public.parties set name='allowed' where id='85000000-0000-4000-8000-0000000000b6'$q$,null,1);
reset role;
insert into public.parties(id,company_id,type,name) values ('85000000-0000-4000-8000-0000000000b7','85000000-0000-4000-8000-0000000000a1','EMPLOYEE','Trusted'); set local role authenticated;
select pg_temp.check_sql('EMPLOYEE previous scope retained',$q$update public.parties set name='allowed' where id='85000000-0000-4000-8000-0000000000b7'$q$,null,1);
reset role;
insert into public.parties(id,company_id,type,name) values ('85000000-0000-4000-8000-0000000000b8','85000000-0000-4000-8000-0000000000a1','OWNER','Trusted'); set local role authenticated;
select pg_temp.check_sql('OWNER previous scope retained',$q$update public.parties set name='denied' where id='85000000-0000-4000-8000-0000000000b8'$q$,null,1);
reset role;
set local role authenticated;
select pg_temp.check_sql('Supplier create retained',$q$insert into public.parties(company_id,name,code) values ('85000000-0000-4000-8000-0000000000a1','  Supplier  ',' S15-SUP ')$q$,null,1);
select pg_temp.check_sql('Supplier metadata and status retained',$q$update public.parties set notes=' note ',status='INACTIVE' where company_id='85000000-0000-4000-8000-0000000000a1' and code='S15-SUP'$q$,null,1);
reset role; select pg_temp.assert_true('Supplier normalized actor retained',(select name='Supplier' and notes='note' and type='SUPPLIER' and status='INACTIVE' and created_by='7cf0bfff-6938-4beb-a0ff-0ed726867304' and updated_by='7cf0bfff-6938-4beb-a0ff-0ed726867304' from public.parties where company_id='85000000-0000-4000-8000-0000000000a1' and code='S15-SUP')); set local role authenticated;
select pg_temp.check_sql('no typed SUBCONTRACTOR insert',$q$insert into public.parties(company_id,type,name) values ('85000000-0000-4000-8000-0000000000a1','SUBCONTRACTOR','Denied')$q$,'42501');
select pg_temp.check_sql('no delete',$q$delete from public.parties where id='85000000-0000-4000-8000-0000000000b1'$q$,'42501');
reset role; create temporary table trusted_token as select updated_at from public.parties where id='85000000-0000-4000-8000-0000000000b4';
set local role service_role;
select pg_temp.check_sql('trusted SUBCONTRACTOR metadata retained',$q$update public.parties set notes='trusted' where id='85000000-0000-4000-8000-0000000000b1'$q$,null,1);
select pg_temp.check_sql('trusted future metadata',$q$update public.parties set notes='trusted future' where id='85000000-0000-4000-8000-0000000000b4'$q$,null,1);
reset role; select pg_temp.assert_true('trusted token monotonic',(select updated_at>(select updated_at from pg_temp.trusted_token) from public.parties where id='85000000-0000-4000-8000-0000000000b4'));
reset role; select count(*) as passed, bool_and(passed) as all_passed from pg_temp.slice15_results; rollback;
