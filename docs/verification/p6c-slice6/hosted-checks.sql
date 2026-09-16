-- PREPARED / NOT EXECUTED. MakerACC-Development only; NOT a migration.
-- All test data and temporary helpers roll back. Stop on first error.
begin;
do $$ begin
 if not exists(select 1 from supabase_migrations.schema_migrations where version='20260913123000') then raise exception 'Slice 6 migration required'; end if;
end $$;
create temporary table slice6_function_before as
select p.oid,md5(pg_get_functiondef(p.oid)) as fingerprint from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname in ('public','private') and p.prokind='f';
create temporary table slice6_results(label text, passed boolean);
grant select,insert on pg_temp.slice6_results to authenticated,anon,service_role;
create function pg_temp.check_sql(label text, statement text, expected_state text default null, expected_rows integer default null)
returns void language plpgsql as $$
declare actual_rows integer; actual_state text;
begin
 begin execute statement; get diagnostics actual_rows=row_count;
 exception when others then get stacked diagnostics actual_state=returned_sqlstate; end;
 if actual_state is distinct from expected_state or (expected_rows is not null and actual_rows is distinct from expected_rows) then
  raise exception 'FAIL %: state %, rows % (expected %, %)',label,actual_state,actual_rows,expected_state,expected_rows;
 end if;
 insert into pg_temp.slice6_results values(label,true);
end $$;
insert into auth.users(id,email,raw_user_meta_data) values ('76000000-0000-4000-8000-000000000001','p6c-s6-rollback@example.test','{"display_name":"Slice 6 rollback"}');
insert into public.companies(id,code,name) values ('76000000-0000-4000-8000-0000000000a1','P6C-S6-ROLLBACK-A','Slice 6 rollback A'),('76000000-0000-4000-8000-0000000000a2','P6C-S6-ROLLBACK-B','Slice 6 rollback B');
insert into public.company_memberships(company_id,user_id,role) values ('76000000-0000-4000-8000-0000000000a1','76000000-0000-4000-8000-000000000001','ACCOUNTING_ADMIN');
insert into public.parties(id,company_id,type,code,name) values ('76000000-0000-4000-8000-000000000001','76000000-0000-4000-8000-0000000000a1','OWNER','OWNER','  OWNER  ');
insert into public.parties(id,company_id,type,code,name) values ('76000000-0000-4000-8000-000000000002','76000000-0000-4000-8000-0000000000a1','CUSTODIAN','CUSTODIAN','  CUSTODIAN  ');
insert into public.parties(id,company_id,type,code,name) values ('76000000-0000-4000-8000-000000000003','76000000-0000-4000-8000-0000000000a1','EMPLOYEE','EMPLOYEE','  EMPLOYEE  ');
insert into public.parties(id,company_id,type,code,name) values ('76000000-0000-4000-8000-000000000004','76000000-0000-4000-8000-0000000000a1','SUBCONTRACTOR','SUBCONTRACTOR','  SUBCONTRACTOR  ');
insert into public.parties(id,company_id,type,code,name) values ('76000000-0000-4000-8000-000000000005','76000000-0000-4000-8000-0000000000a1','OTHER','OTHER','  OTHER  ');
insert into public.parties(id,company_id,type,name,code) values ('76000000-0000-4000-8000-0000000000b1','76000000-0000-4000-8000-0000000000a2','SUPPLIER','Hidden tenant supplier','HIDDEN');
-- Same-Company composite FK and referenced subcontractor type guard remain intact.
insert into public.projects(id,company_id,code,name,status) values
('76000000-0000-4000-8000-0000000000c1','76000000-0000-4000-8000-0000000000a1','REFERENCE','Reference guard','ACTIVE');
insert into public.subcontracts(id,company_id,project_id,subcontractor_id,contract_number,scope_of_work,original_contract_value_minor,retention_bps) values
('76000000-0000-4000-8000-0000000000d1','76000000-0000-4000-8000-0000000000a1','76000000-0000-4000-8000-0000000000c1','76000000-0000-4000-8000-000000000004','REFERENCE','Rollback only',0,0);
select pg_temp.check_sql('referenced subcontractor cannot change type', $q$update public.parties set type='OTHER' where id='76000000-0000-4000-8000-000000000004'$q$,'23514');
select pg_temp.check_sql('referenced subcontractor restrictive FK', $q$delete from public.parties where id='76000000-0000-4000-8000-000000000004'$q$,'23503');
-- Snapshot financial rows and P5 function definitions without creating financial activity.
create temporary table slice6_financial_before(rel text primary key, fingerprint text);
do $$ declare t record; fingerprint text; begin
 for t in select table_name from information_schema.tables where table_schema='public'
 and table_name in ('expenses','supplier_payments','supplier_payment_allocations','journal_entries','journal_lines','custody_advances','custody_settlements','custody_cash_returns','subcontractor_advances','subcontractor_certificates','subcontractor_payments','subcontractor_retention_releases','subcontractor_retention_payments') loop
  execute format('select md5(coalesce(string_agg(to_jsonb(x)::text, %L order by to_jsonb(x)::text), %L)) from public.%I x','','',t.table_name) into fingerprint;
  insert into slice6_financial_before values(t.table_name,fingerprint);
 end loop;
end $$;
select set_config('request.jwt.claim.sub','76000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);
set local role authenticated;
select pg_temp.check_sql('admin create', $q$insert into public.parties(company_id,name,code,trn,phone,notes) values ('76000000-0000-4000-8000-0000000000a1',E' \tSupplier\n ',' SUP ',' 00123 ',' +971 (0)01 ',E' \t')$q$,null,1);
do $$ declare p public.parties; token timestamptz; creation timestamptz; begin
 select * into strict p from public.parties where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP';
 if p.type<>'SUPPLIER' or p.status<>'ACTIVE' or p.name<>'Supplier' or p.trn<>'00123' or p.phone<>'+971 (0)01' or p.notes is not null
 or p.created_by is distinct from auth.uid() or p.updated_by is distinct from auth.uid() or p.created_at<>p.updated_at then raise exception 'Supplier creation mismatch'; end if;
 token:=p.updated_at; creation:=p.created_at;
 update public.parties set name=name where company_id=p.company_id and id=p.id and type='SUPPLIER' and updated_at=token returning * into p;
 if p.updated_at<=token or p.created_at<>creation or p.updated_by is distinct from auth.uid() then raise exception 'Supplier no-op token/provenance mismatch'; end if;
 perform pg_temp.check_sql('stale token',format('update public.parties set name=''stale'' where company_id=%L and id=%L and type=''SUPPLIER'' and updated_at=%L',p.company_id,p.id,token),null,0);
 insert into pg_temp.slice6_results values('creation normalization, provenance and monotonic token',true);
end $$;
select pg_temp.check_sql('protected insert id', $q$insert into public.parties(company_id,name,id) values ('76000000-0000-4000-8000-0000000000a1','Forgery','76000000-0000-4000-8000-0000000000ff')$q$,'42501',null);
select pg_temp.check_sql('protected insert type', $q$insert into public.parties(company_id,name,type) values ('76000000-0000-4000-8000-0000000000a1','Forgery','SUPPLIER')$q$,'42501',null);
select pg_temp.check_sql('protected insert status', $q$insert into public.parties(company_id,name,status) values ('76000000-0000-4000-8000-0000000000a1','Forgery','ACTIVE')$q$,'42501',null);
select pg_temp.check_sql('protected insert created_by', $q$insert into public.parties(company_id,name,created_by) values ('76000000-0000-4000-8000-0000000000a1','Forgery',null)$q$,'42501',null);
select pg_temp.check_sql('protected insert updated_by', $q$insert into public.parties(company_id,name,updated_by) values ('76000000-0000-4000-8000-0000000000a1','Forgery',null)$q$,'42501',null);
select pg_temp.check_sql('protected insert created_at', $q$insert into public.parties(company_id,name,created_at) values ('76000000-0000-4000-8000-0000000000a1','Forgery','2000-01-01')$q$,'42501',null);
select pg_temp.check_sql('protected insert updated_at', $q$insert into public.parties(company_id,name,updated_at) values ('76000000-0000-4000-8000-0000000000a1','Forgery','2000-01-01')$q$,'42501',null);
select pg_temp.check_sql('protected update id', $q$update public.parties set id='76000000-0000-4000-8000-0000000000ff' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,'42501',null);
select pg_temp.check_sql('protected update type', $q$update public.parties set type='OTHER' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,'42501',null);
select pg_temp.check_sql('protected update company_id', $q$update public.parties set company_id='76000000-0000-4000-8000-0000000000a2' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,'42501',null);
select pg_temp.check_sql('protected update created_by', $q$update public.parties set created_by=null where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,'42501',null);
select pg_temp.check_sql('protected update updated_by', $q$update public.parties set updated_by=null where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,'42501',null);
select pg_temp.check_sql('protected update created_at', $q$update public.parties set created_at='2000-01-01' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,'42501',null);
select pg_temp.check_sql('protected update updated_at', $q$update public.parties set updated_at='2000-01-01' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,'42501',null);
reset role;
update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id='76000000-0000-4000-8000-0000000000a1' and user_id='76000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('ACCOUNTING_ADMIN cannot insert OWNER', $q$insert into public.parties(company_id,type,name) values ('76000000-0000-4000-8000-0000000000a1','OWNER','Denied')$q$,'42501',null);
select pg_temp.check_sql('ACCOUNTING_ADMIN cannot update OWNER', $q$update public.parties set name='Denied',status='INACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and id='76000000-0000-4000-8000-000000000001'$q$,null,0);
select pg_temp.check_sql('ACCOUNTING_ADMIN cannot insert CUSTODIAN', $q$insert into public.parties(company_id,type,name) values ('76000000-0000-4000-8000-0000000000a1','CUSTODIAN','Denied')$q$,'42501',null);
select pg_temp.check_sql('ACCOUNTING_ADMIN cannot update CUSTODIAN', $q$update public.parties set name='Denied',status='INACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and id='76000000-0000-4000-8000-000000000002'$q$,null,0);
select pg_temp.check_sql('ACCOUNTING_ADMIN cannot insert EMPLOYEE', $q$insert into public.parties(company_id,type,name) values ('76000000-0000-4000-8000-0000000000a1','EMPLOYEE','Denied')$q$,'42501',null);
select pg_temp.check_sql('ACCOUNTING_ADMIN cannot update EMPLOYEE', $q$update public.parties set name='Denied',status='INACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and id='76000000-0000-4000-8000-000000000003'$q$,null,0);
select pg_temp.check_sql('ACCOUNTING_ADMIN cannot insert SUBCONTRACTOR', $q$insert into public.parties(company_id,type,name) values ('76000000-0000-4000-8000-0000000000a1','SUBCONTRACTOR','Denied')$q$,'42501',null);
select pg_temp.check_sql('ACCOUNTING_ADMIN cannot update SUBCONTRACTOR', $q$update public.parties set name='Denied',status='INACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and id='76000000-0000-4000-8000-000000000004'$q$,null,0);
select pg_temp.check_sql('ACCOUNTING_ADMIN cannot insert OTHER', $q$insert into public.parties(company_id,type,name) values ('76000000-0000-4000-8000-0000000000a1','OTHER','Denied')$q$,'42501',null);
select pg_temp.check_sql('ACCOUNTING_ADMIN cannot update OTHER', $q$update public.parties set name='Denied',status='INACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and id='76000000-0000-4000-8000-000000000005'$q$,null,0);
select pg_temp.check_sql('ACCOUNTING_ADMIN supplier create', $q$insert into public.parties(company_id,name) values ('76000000-0000-4000-8000-0000000000a1','Duplicate name')$q$,null,1);
select pg_temp.check_sql('ACCOUNTING_ADMIN supplier edit', $q$update public.parties set contact_person=' Contact ',email=' User@Example.test ',address=' Address ',notes=' Notes ' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,1);
select pg_temp.check_sql('ACCOUNTING_ADMIN status INACTIVE', $q$update public.parties set status='INACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,1);
select pg_temp.check_sql('ACCOUNTING_ADMIN status ACTIVE', $q$update public.parties set status='ACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,1);
reset role;
update public.company_memberships set role='PROCUREMENT' where company_id='76000000-0000-4000-8000-0000000000a1' and user_id='76000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('PROCUREMENT cannot insert OWNER', $q$insert into public.parties(company_id,type,name) values ('76000000-0000-4000-8000-0000000000a1','OWNER','Denied')$q$,'42501',null);
select pg_temp.check_sql('PROCUREMENT cannot update OWNER', $q$update public.parties set name='Denied',status='INACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and id='76000000-0000-4000-8000-000000000001'$q$,null,0);
select pg_temp.check_sql('PROCUREMENT cannot insert CUSTODIAN', $q$insert into public.parties(company_id,type,name) values ('76000000-0000-4000-8000-0000000000a1','CUSTODIAN','Denied')$q$,'42501',null);
select pg_temp.check_sql('PROCUREMENT cannot update CUSTODIAN', $q$update public.parties set name='Denied',status='INACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and id='76000000-0000-4000-8000-000000000002'$q$,null,0);
select pg_temp.check_sql('PROCUREMENT cannot insert EMPLOYEE', $q$insert into public.parties(company_id,type,name) values ('76000000-0000-4000-8000-0000000000a1','EMPLOYEE','Denied')$q$,'42501',null);
select pg_temp.check_sql('PROCUREMENT cannot update EMPLOYEE', $q$update public.parties set name='Denied',status='INACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and id='76000000-0000-4000-8000-000000000003'$q$,null,0);
select pg_temp.check_sql('PROCUREMENT cannot insert SUBCONTRACTOR', $q$insert into public.parties(company_id,type,name) values ('76000000-0000-4000-8000-0000000000a1','SUBCONTRACTOR','Denied')$q$,'42501',null);
select pg_temp.check_sql('PROCUREMENT cannot update SUBCONTRACTOR', $q$update public.parties set name='Denied',status='INACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and id='76000000-0000-4000-8000-000000000004'$q$,null,0);
select pg_temp.check_sql('PROCUREMENT cannot insert OTHER', $q$insert into public.parties(company_id,type,name) values ('76000000-0000-4000-8000-0000000000a1','OTHER','Denied')$q$,'42501',null);
select pg_temp.check_sql('PROCUREMENT cannot update OTHER', $q$update public.parties set name='Denied',status='INACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and id='76000000-0000-4000-8000-000000000005'$q$,null,0);
select pg_temp.check_sql('PROCUREMENT supplier create', $q$insert into public.parties(company_id,name) values ('76000000-0000-4000-8000-0000000000a1','Duplicate name')$q$,null,1);
select pg_temp.check_sql('PROCUREMENT supplier edit', $q$update public.parties set contact_person=' Contact ',email=' User@Example.test ',address=' Address ',notes=' Notes ' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,1);
select pg_temp.check_sql('PROCUREMENT status INACTIVE', $q$update public.parties set status='INACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,1);
select pg_temp.check_sql('PROCUREMENT status ACTIVE', $q$update public.parties set status='ACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,1);
select pg_temp.check_sql('hidden Owner code collision', $q$insert into public.parties(company_id,name,code) values ('76000000-0000-4000-8000-0000000000a1','Collision',' owner ')$q$,'23505',null);
select pg_temp.check_sql('deactivate', $q$update public.parties set status='INACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,1);
select pg_temp.check_sql('inactive code collision', $q$insert into public.parties(company_id,name,code) values ('76000000-0000-4000-8000-0000000000a1','Collision',' sup ')$q$,'23505',null);
select pg_temp.check_sql('inactive editable', $q$update public.parties set name='Supplier edited' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,1);
select pg_temp.check_sql('blank code nullable', $q$insert into public.parties(company_id,name,code) values ('76000000-0000-4000-8000-0000000000a1','Duplicate name',E' \t')$q$,null,1);
select pg_temp.check_sql('null code duplicate names', $q$insert into public.parties(company_id,name,code) values ('76000000-0000-4000-8000-0000000000a1','Duplicate name',null)$q$,null,1);
select pg_temp.check_sql('blank name', $q$update public.parties set name=E' \t\n' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,'23514',null);
select pg_temp.check_sql('long name', $q$update public.parties set name=repeat('x',201) where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,'23514',null);
select pg_temp.check_sql('long code', $q$update public.parties set code=repeat('x',51) where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,'23514',null);
select pg_temp.check_sql('null name', $q$update public.parties set name=null where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,'23502',null);
select pg_temp.check_sql('null status', $q$update public.parties set status=null where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,'23502',null);
select pg_temp.check_sql('invalid status', $q$update public.parties set status='CLOSED' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,'22P02',null);
select pg_temp.check_sql('cross tenant create', $q$insert into public.parties(company_id,name) values ('76000000-0000-4000-8000-0000000000a2','Denied')$q$,'42501',null);
select pg_temp.check_sql('cross tenant existing uuid', $q$update public.parties set name='Denied' where company_id='76000000-0000-4000-8000-0000000000a2' and id='76000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('delete denied', $q$delete from public.parties where company_id='76000000-0000-4000-8000-0000000000a1'$q$,'42501',null);
select pg_temp.check_sql('truncate denied', $q$truncate public.parties$q$,'42501',null);
select pg_temp.check_sql('browser upsert ownership denied', $q$insert into public.parties(company_id,code,name) values ('76000000-0000-4000-8000-0000000000a1','SUP','Upsert') on conflict (company_id,lower(btrim(code))) where code is not null do update set company_id=excluded.company_id,name=excluded.name$q$,'42501',null);
reset role;
update public.company_memberships set role='ACCOUNTANT' where company_id='76000000-0000-4000-8000-0000000000a1' and user_id='76000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('ACCOUNTANT insert denied', $q$insert into public.parties(company_id,name) values ('76000000-0000-4000-8000-0000000000a1','Denied')$q$,'42501',null);
select pg_temp.check_sql('ACCOUNTANT update denied', $q$update public.parties set name='Denied' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,0);
select pg_temp.check_sql('ACCOUNTANT update denied', $q$update public.parties set status='ACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,0);
select pg_temp.check_sql('ACCOUNTANT update denied', $q$update public.parties set status='INACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,0);
reset role;
update public.company_memberships set role='DATA_ENTRY' where company_id='76000000-0000-4000-8000-0000000000a1' and user_id='76000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('DATA_ENTRY insert denied', $q$insert into public.parties(company_id,name) values ('76000000-0000-4000-8000-0000000000a1','Denied')$q$,'42501',null);
select pg_temp.check_sql('DATA_ENTRY update denied', $q$update public.parties set name='Denied' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,0);
select pg_temp.check_sql('DATA_ENTRY update denied', $q$update public.parties set status='ACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,0);
select pg_temp.check_sql('DATA_ENTRY update denied', $q$update public.parties set status='INACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,0);
reset role;
update public.company_memberships set role='MANAGEMENT_VIEWER' where company_id='76000000-0000-4000-8000-0000000000a1' and user_id='76000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('MANAGEMENT_VIEWER insert denied', $q$insert into public.parties(company_id,name) values ('76000000-0000-4000-8000-0000000000a1','Denied')$q$,'42501',null);
select pg_temp.check_sql('MANAGEMENT_VIEWER update denied', $q$update public.parties set name='Denied' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,0);
select pg_temp.check_sql('MANAGEMENT_VIEWER update denied', $q$update public.parties set status='ACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,0);
select pg_temp.check_sql('MANAGEMENT_VIEWER update denied', $q$update public.parties set status='INACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,0);
reset role;
update public.company_memberships set role='PROJECT_MANAGER' where company_id='76000000-0000-4000-8000-0000000000a1' and user_id='76000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('PROJECT_MANAGER insert denied', $q$insert into public.parties(company_id,name) values ('76000000-0000-4000-8000-0000000000a1','Denied')$q$,'42501',null);
select pg_temp.check_sql('PROJECT_MANAGER update denied', $q$update public.parties set name='Denied' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,0);
select pg_temp.check_sql('PROJECT_MANAGER update denied', $q$update public.parties set status='ACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,0);
select pg_temp.check_sql('PROJECT_MANAGER update denied', $q$update public.parties set status='INACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,0);
reset role;
update public.company_memberships set role='SYSTEM_ADMIN' where company_id='76000000-0000-4000-8000-0000000000a1' and user_id='76000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('SYSTEM_ADMIN insert denied', $q$insert into public.parties(company_id,name) values ('76000000-0000-4000-8000-0000000000a1','Denied')$q$,'42501',null);
select pg_temp.check_sql('SYSTEM_ADMIN update denied', $q$update public.parties set name='Denied' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,0);
select pg_temp.check_sql('SYSTEM_ADMIN update denied', $q$update public.parties set status='ACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,0);
select pg_temp.check_sql('SYSTEM_ADMIN update denied', $q$update public.parties set status='INACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,0);
reset role;
update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id='76000000-0000-4000-8000-0000000000a1' and user_id='76000000-0000-4000-8000-000000000001';
update public.profiles set status='INACTIVE' where user_id='76000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('inactive profiles insert', $q$insert into public.parties(company_id,name) values ('76000000-0000-4000-8000-0000000000a1','Denied')$q$,'42501',null);
select pg_temp.check_sql('inactive profiles update', $q$update public.parties set name='Denied' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,0);
reset role;
update public.profiles set status='ACTIVE' where user_id='76000000-0000-4000-8000-000000000001';
update public.company_memberships set status='INACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and user_id='76000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('inactive company_memberships insert', $q$insert into public.parties(company_id,name) values ('76000000-0000-4000-8000-0000000000a1','Denied')$q$,'42501',null);
select pg_temp.check_sql('inactive company_memberships update', $q$update public.parties set name='Denied' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,0);
reset role;
update public.company_memberships set status='ACTIVE' where company_id='76000000-0000-4000-8000-0000000000a1' and user_id='76000000-0000-4000-8000-000000000001';
update public.companies set status='INACTIVE' where id='76000000-0000-4000-8000-0000000000a1';
set local role authenticated;
select pg_temp.check_sql('inactive companies insert', $q$insert into public.parties(company_id,name) values ('76000000-0000-4000-8000-0000000000a1','Denied')$q$,'42501',null);
select pg_temp.check_sql('inactive companies update', $q$update public.parties set name='Denied' where company_id='76000000-0000-4000-8000-0000000000a1' and code='SUP'$q$,null,0);
reset role;
update public.companies set status='ACTIVE' where id='76000000-0000-4000-8000-0000000000a1';
set local role anon;
select pg_temp.check_sql('anonymous insert', $q$insert into public.parties(company_id,name) values ('76000000-0000-4000-8000-0000000000a1','Denied')$q$,'42501',null);
select pg_temp.check_sql('anonymous update', $q$update public.parties set name='Denied' where company_id='76000000-0000-4000-8000-0000000000a1'$q$,'42501',null);
reset role;
-- Trusted role retains actors/timestamps despite authenticated JWT claims.
set local role service_role;
insert into public.parties(id,company_id,type,name,code,created_by,updated_by,created_at,updated_at)
values ('76000000-0000-4000-8000-0000000000f1','76000000-0000-4000-8000-0000000000a1','SUPPLIER',' Trusted ','TRUST',null,null,'1999-01-01T00:00:00Z','2000-01-01T00:00:00Z');
do $$ declare p public.parties; begin
 select * into strict p from public.parties where id='76000000-0000-4000-8000-0000000000f1';
 if p.created_by is not null or p.updated_by is not null or p.created_at<>'1999-01-01T00:00:00Z'::timestamptz or p.updated_at<>'2000-01-01T00:00:00Z'::timestamptz then raise exception 'Trusted insert provenance lost'; end if;
 update public.parties set notes=' trusted ',updated_by=null where id=p.id returning * into p;
 if p.updated_by is not null or p.created_at<>'1999-01-01T00:00:00Z'::timestamptz or p.updated_at<='2000-01-01T00:00:00Z'::timestamptz then raise exception 'Trusted update mismatch'; end if;
 insert into pg_temp.slice6_results values('trusted Supplier provenance',true);
end $$;
select pg_temp.check_sql('trusted creation time immutable', $q$update public.parties set created_at='2001-01-01' where id='76000000-0000-4000-8000-0000000000f1'$q$,'23514',null);
select pg_temp.check_sql('trusted creation actor immutable', $q$update public.parties set created_by='76000000-0000-4000-8000-000000000001' where id='76000000-0000-4000-8000-0000000000f1'$q$,'23514',null);
select pg_temp.check_sql('trusted tenant reassignment denied', $q$update public.parties set company_id='76000000-0000-4000-8000-0000000000a2' where id='76000000-0000-4000-8000-0000000000f1'$q$,'23514',null);
update public.parties set notes=E'  unchanged \t',updated_by=null,created_at='1998-01-01T00:00:00Z' where id='76000000-0000-4000-8000-000000000001';
do $$ begin
 if not exists(select 1 from public.parties where id='76000000-0000-4000-8000-000000000001' and name='  OWNER  ' and notes=E'  unchanged \t' and updated_by is null and created_at='1998-01-01T00:00:00Z'::timestamptz and updated_at=now()) then raise exception 'Trusted OWNER changed semantics'; end if;
 insert into pg_temp.slice6_results values('trusted OWNER unchanged',true);
end $$;
update public.parties set notes=E'  unchanged \t',updated_by=null,created_at='1998-01-01T00:00:00Z' where id='76000000-0000-4000-8000-000000000002';
do $$ begin
 if not exists(select 1 from public.parties where id='76000000-0000-4000-8000-000000000002' and name='  CUSTODIAN  ' and notes=E'  unchanged \t' and updated_by is null and created_at='1998-01-01T00:00:00Z'::timestamptz and updated_at=now()) then raise exception 'Trusted CUSTODIAN changed semantics'; end if;
 insert into pg_temp.slice6_results values('trusted CUSTODIAN unchanged',true);
end $$;
update public.parties set notes=E'  unchanged \t',updated_by=null,created_at='1998-01-01T00:00:00Z' where id='76000000-0000-4000-8000-000000000003';
do $$ begin
 if not exists(select 1 from public.parties where id='76000000-0000-4000-8000-000000000003' and name='  EMPLOYEE  ' and notes=E'  unchanged \t' and updated_by is null and created_at='1998-01-01T00:00:00Z'::timestamptz and updated_at=now()) then raise exception 'Trusted EMPLOYEE changed semantics'; end if;
 insert into pg_temp.slice6_results values('trusted EMPLOYEE unchanged',true);
end $$;
update public.parties set notes=E'  unchanged \t',updated_by=null,created_at='1998-01-01T00:00:00Z' where id='76000000-0000-4000-8000-000000000004';
do $$ begin
 if not exists(select 1 from public.parties where id='76000000-0000-4000-8000-000000000004' and name='  SUBCONTRACTOR  ' and notes=E'  unchanged \t' and updated_by is null and created_at='1998-01-01T00:00:00Z'::timestamptz and updated_at=now()) then raise exception 'Trusted SUBCONTRACTOR changed semantics'; end if;
 insert into pg_temp.slice6_results values('trusted SUBCONTRACTOR unchanged',true);
end $$;
update public.parties set notes=E'  unchanged \t',updated_by=null,created_at='1998-01-01T00:00:00Z' where id='76000000-0000-4000-8000-000000000005';
do $$ begin
 if not exists(select 1 from public.parties where id='76000000-0000-4000-8000-000000000005' and name='  OTHER  ' and notes=E'  unchanged \t' and updated_by is null and created_at='1998-01-01T00:00:00Z'::timestamptz and updated_at=now()) then raise exception 'Trusted OTHER changed semantics'; end if;
 insert into pg_temp.slice6_results values('trusted OTHER unchanged',true);
end $$;
reset role;
insert into public.company_memberships(company_id,user_id,role) values ('76000000-0000-4000-8000-0000000000a2','76000000-0000-4000-8000-000000000001','ACCOUNTING_ADMIN');
set local role authenticated;
select pg_temp.check_sql('same normalized code different Company', $q$insert into public.parties(company_id,name,code) values ('76000000-0000-4000-8000-0000000000a2','Other Company',' sup ')$q$,null,1);
reset role;
do $$ declare t record; fingerprint text; begin
 for t in select * from slice6_financial_before loop
  execute format('select md5(coalesce(string_agg(to_jsonb(x)::text, %L order by to_jsonb(x)::text), %L)) from public.%I x','','',t.rel) into fingerprint;
  if fingerprint is distinct from t.fingerprint then raise exception 'Financial table changed: %',t.rel; end if;
 end loop;
 insert into slice6_results values('financial row fingerprints unchanged',true);
end $$;
do $$ declare c record; begin
 if has_table_privilege('authenticated','public.parties','INSERT,UPDATE,DELETE,TRUNCATE') then raise exception 'Broad Party grants'; end if;
 for c in select attname from pg_attribute where attrelid='public.parties'::regclass and attnum>0 and not attisdropped loop
  if has_column_privilege('authenticated','public.parties',c.attname,'INSERT') <> (c.attname=any(array['company_id','name','code','trn','contact_person','phone','email','address','notes']))
  or has_column_privilege('authenticated','public.parties',c.attname,'UPDATE') <> (c.attname=any(array['name','code','trn','contact_person','phone','email','address','notes','status'])) then raise exception 'Column grant mismatch %',c.attname; end if;
 end loop;
 if not (select relrowsecurity and relforcerowsecurity from pg_class where oid='public.parties'::regclass)
 or (select count(*) from pg_policy where polrelid='public.parties'::regclass and not polpermissive and polname in ('parties_insert_supplier_only','parties_update_supplier_only'))<>2 then raise exception 'Supplier RLS gate missing'; end if;
 if (select count(*) from pg_trigger where tgrelid='public.parties'::regclass and not tgisinternal)<>3
 or exists(select 1 from pg_trigger where tgrelid='public.parties'::regclass and tgname='parties_set_updated_at') then raise exception 'Party trigger ownership mismatch'; end if;
 if exists(select 1 from pg_proc where oid='public.prepare_supplier_party_mutation()'::regprocedure and (prosecdef or proconfig is distinct from array['search_path=""'])) then raise exception 'Preparation security mismatch'; end if;
 if has_function_privilege('authenticated','public.prepare_supplier_party_mutation()','EXECUTE') or has_function_privilege('anon','public.prepare_supplier_party_mutation()','EXECUTE') or has_function_privilege('service_role','public.prepare_supplier_party_mutation()','EXECUTE') then raise exception 'Direct preparation EXECUTE exposed'; end if;
 if exists(select 1 from slice6_function_before b where md5(pg_get_functiondef(b.oid)) is distinct from b.fingerprint) then raise exception 'Function definition changed during test'; end if;
 insert into slice6_results values('effective grants, RLS, single timestamp owner, function integrity',true);
end $$;
select count(*) as passed_checks, bool_and(passed) as all_passed from slice6_results;
rollback;
