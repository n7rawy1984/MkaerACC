-- Disposable rollback-only verification, NOT a migration or browser fixture.
-- Execute only against verified MakerACC-Development.
begin;
create temporary table slice5_results (label text, passed boolean);
create function pg_temp.check_sql(label text, statement text, expected_state text default null, expected_rows integer default null)
returns void language plpgsql as $$
declare actual_rows integer; actual_state text;
begin
  begin
    execute statement;
    get diagnostics actual_rows = row_count;
  exception when others then get stacked diagnostics actual_state = returned_sqlstate;
  end;
  if actual_state is distinct from expected_state or (expected_rows is not null and actual_rows is distinct from expected_rows) then
    raise exception 'FAIL %: SQLSTATE %, rows % (expected %, %)', label, actual_state, actual_rows, expected_state, expected_rows;
  end if;
  insert into pg_temp.slice5_results values (label, true);
end;
$$;
grant select, insert on slice5_results to authenticated, service_role, anon;

insert into auth.users(id,email,raw_user_meta_data) values
('75000000-0000-4000-8000-000000000001','p6c-s5-rollback@example.test','{"display_name":"Slice 5 rollback"}');
insert into public.companies(id,code,name) values
('75000000-0000-4000-8000-0000000000a1','P6C-S5-ROLLBACK-A','Slice 5 rollback Alpha'),
('75000000-0000-4000-8000-0000000000a2','P6C-S5-ROLLBACK-B','Slice 5 rollback Beta');
insert into public.company_memberships(company_id,user_id,role) values
('75000000-0000-4000-8000-0000000000a1','75000000-0000-4000-8000-000000000001','ACCOUNTING_ADMIN');
insert into public.expense_categories(id,company_id,code,name) values ('75000000-0000-4000-8000-0000000000b1','75000000-0000-4000-8000-0000000000a2','HIDDEN','Hidden other tenant');
select set_config('request.jwt.claim.sub','75000000-0000-4000-8000-000000000001',true);
select set_config('request.jwt.claim.role','authenticated',true);

-- Effective privileges include inheritance and table-wide grants.
do $$ declare c record; begin
  for c in select attname from pg_attribute where attrelid='public.expense_categories'::regclass and attnum>0 and not attisdropped loop
    if has_column_privilege('authenticated','public.expense_categories',c.attname,'INSERT') <> (c.attname=any(array['company_id','code','name','description']))
      or has_column_privilege('authenticated','public.expense_categories',c.attname,'UPDATE') <> (c.attname=any(array['code','name','description','status'])) then raise exception 'Privilege mismatch %',c.attname; end if;
  end loop;
  if has_table_privilege('authenticated','public.expense_categories','INSERT,UPDATE,DELETE') then raise exception 'Broad privilege'; end if;
  if (select count(*) from pg_trigger where tgrelid='public.expense_categories'::regclass and not tgisinternal)<>2
    or exists(select 1 from pg_trigger where tgrelid='public.expense_categories'::regclass and tgname='expense_categories_set_updated_at') then raise exception 'Trigger mismatch'; end if;
  if not (select relrowsecurity and relforcerowsecurity from pg_class where oid='public.expense_categories'::regclass) then raise exception 'RLS mismatch'; end if;
  insert into slice5_results values ('effective grants, forced RLS, single token owner',true);
end $$;

set local role authenticated;
select pg_temp.check_sql('admin insert', $$insert into public.expense_categories(company_id,code,name,description) values ('75000000-0000-4000-8000-0000000000a1',' MAT ',' Materials ',' ')$$,null,1);
do $$ declare c public.expense_categories; old_token timestamptz; begin
  select * into strict c from public.expense_categories where company_id='75000000-0000-4000-8000-0000000000a1' and code='MAT';
  if c.status<>'ACTIVE' or c.name<>'Materials' or c.description is not null or c.created_by<>auth.uid() or c.updated_by<>auth.uid() or c.created_at<>c.updated_at then raise exception 'Creation provenance/default/normalization mismatch'; end if;
  old_token:=c.updated_at;
  update public.expense_categories set name=name where id=c.id and company_id=c.company_id and updated_at=c.updated_at returning * into c;
  if c.updated_at<=old_token then raise exception 'No-op token did not advance'; end if;
  perform pg_temp.check_sql('stale update zero rows',format('update public.expense_categories set name=''stale'' where id=%L and updated_at=%L',c.id,old_token),null,0);
  old_token:=c.updated_at;
  update public.expense_categories set status='INACTIVE' where id=c.id returning * into c;
  if c.updated_at<=old_token or c.created_by<>auth.uid() or c.updated_by<>auth.uid() then raise exception 'Update provenance mismatch'; end if;
  insert into pg_temp.slice5_results values ('ACTIVE creation, normalization, actors, no-op advancing token and deactivation',true);
end $$;
select pg_temp.check_sql('insert denied id 75000000-0000-4000-8000-0000000000f1', $$insert into public.expense_categories(company_id,code,name,id) values ('75000000-0000-4000-8000-0000000000a1','FORGED','Forged','75000000-0000-4000-8000-0000000000f1')$$,'42501');
select pg_temp.check_sql('insert denied status ACTIVE', $$insert into public.expense_categories(company_id,code,name,status) values ('75000000-0000-4000-8000-0000000000a1','FORGED','Forged','ACTIVE')$$,'42501');
select pg_temp.check_sql('insert denied status INACTIVE', $$insert into public.expense_categories(company_id,code,name,status) values ('75000000-0000-4000-8000-0000000000a1','FORGED','Forged','INACTIVE')$$,'42501');
select pg_temp.check_sql('insert denied created_by null', $$insert into public.expense_categories(company_id,code,name,created_by) values ('75000000-0000-4000-8000-0000000000a1','FORGED','Forged',null)$$,'42501');
select pg_temp.check_sql('insert denied updated_by null', $$insert into public.expense_categories(company_id,code,name,updated_by) values ('75000000-0000-4000-8000-0000000000a1','FORGED','Forged',null)$$,'42501');
select pg_temp.check_sql('insert denied created_at 2000-01-01', $$insert into public.expense_categories(company_id,code,name,created_at) values ('75000000-0000-4000-8000-0000000000a1','FORGED','Forged','2000-01-01')$$,'42501');
select pg_temp.check_sql('insert denied updated_at 2000-01-01', $$insert into public.expense_categories(company_id,code,name,updated_at) values ('75000000-0000-4000-8000-0000000000a1','FORGED','Forged','2000-01-01')$$,'42501');
select pg_temp.check_sql('update denied id', $$update public.expense_categories set id='75000000-0000-4000-8000-0000000000f1' where code='MAT'$$,'42501');
select pg_temp.check_sql('update denied company_id', $$update public.expense_categories set company_id='75000000-0000-4000-8000-0000000000a2' where code='MAT'$$,'42501');
select pg_temp.check_sql('update denied created_by', $$update public.expense_categories set created_by=null where code='MAT'$$,'42501');
select pg_temp.check_sql('update denied updated_by', $$update public.expense_categories set updated_by=null where code='MAT'$$,'42501');
select pg_temp.check_sql('update denied created_at', $$update public.expense_categories set created_at='2000-01-01' where code='MAT'$$,'42501');
select pg_temp.check_sql('update denied updated_at', $$update public.expense_categories set updated_at='2000-01-01' where code='MAT'$$,'42501');
select pg_temp.check_sql('inactive normalized duplicate', $q$insert into public.expense_categories(company_id,code,name) values ('75000000-0000-4000-8000-0000000000a1',' mat ','Duplicate')$q$,'23505');
select pg_temp.check_sql('reactivate', $q$update public.expense_categories set status='ACTIVE' where code='MAT'$q$,null,1);
select pg_temp.check_sql('null code', $$insert into public.expense_categories(company_id,code,name) values ('75000000-0000-4000-8000-0000000000a1',null,'Blank')$$,'23502');
select pg_temp.check_sql('duplicate names allowed', $$insert into public.expense_categories(company_id,code,name) values ('75000000-0000-4000-8000-0000000000a1','SECOND','Materials')$$,null,1);
select pg_temp.check_sql('update normalized duplicate', $$update public.expense_categories set code=' mat ' where code='SECOND'$$,'23505');
select pg_temp.check_sql('blank code', $q$insert into public.expense_categories(company_id,code,name) values ('75000000-0000-4000-8000-0000000000a1',' ','Blank')$q$,'23514');
select pg_temp.check_sql('long name', $q$update public.expense_categories set name=repeat('x',201) where code='MAT'$q$,'23514');
select pg_temp.check_sql('long code', $q$update public.expense_categories set code=repeat('x',51) where code='MAT'$q$,'23514');
select pg_temp.check_sql('null name', $q$update public.expense_categories set name=null where code='MAT'$q$,'23502');
select pg_temp.check_sql('null status', $q$update public.expense_categories set status=null where code='MAT'$q$,'23502');
select pg_temp.check_sql('invalid status', $q$update public.expense_categories set status='CLOSED' where code='MAT'$q$,'22P02');
select pg_temp.check_sql('delete denied', $q$delete from public.expense_categories where code='MAT'$q$,'42501');
select pg_temp.check_sql('cross tenant insert', $q$insert into public.expense_categories(company_id,code,name) values ('75000000-0000-4000-8000-0000000000a2','MAT','Other')$q$,'42501');
select pg_temp.check_sql('cross tenant update', $q$update public.expense_categories set name='Other' where company_id='75000000-0000-4000-8000-0000000000a2' and id='75000000-0000-4000-8000-0000000000b1'$q$,null,0);
reset role;
update public.company_memberships set role='ACCOUNTANT' where user_id='75000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('ACCOUNTANT insert denied', $$insert into public.expense_categories(company_id,code,name) values ('75000000-0000-4000-8000-0000000000a1','DENIED','Denied')$$,'42501');
select pg_temp.check_sql('ACCOUNTANT name=Denied denied', $$update public.expense_categories set name='Denied' where company_id='75000000-0000-4000-8000-0000000000a1'$$,null,0);
select pg_temp.check_sql('ACCOUNTANT status=INACTIVE denied', $$update public.expense_categories set status='INACTIVE' where company_id='75000000-0000-4000-8000-0000000000a1'$$,null,0);
select pg_temp.check_sql('ACCOUNTANT status=ACTIVE denied', $$update public.expense_categories set status='ACTIVE' where company_id='75000000-0000-4000-8000-0000000000a1'$$,null,0);
reset role;
update public.company_memberships set role='PROCUREMENT' where user_id='75000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('PROCUREMENT insert denied', $$insert into public.expense_categories(company_id,code,name) values ('75000000-0000-4000-8000-0000000000a1','DENIED','Denied')$$,'42501');
select pg_temp.check_sql('PROCUREMENT name=Denied denied', $$update public.expense_categories set name='Denied' where company_id='75000000-0000-4000-8000-0000000000a1'$$,null,0);
select pg_temp.check_sql('PROCUREMENT status=INACTIVE denied', $$update public.expense_categories set status='INACTIVE' where company_id='75000000-0000-4000-8000-0000000000a1'$$,null,0);
select pg_temp.check_sql('PROCUREMENT status=ACTIVE denied', $$update public.expense_categories set status='ACTIVE' where company_id='75000000-0000-4000-8000-0000000000a1'$$,null,0);
reset role;
update public.company_memberships set role='DATA_ENTRY' where user_id='75000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('DATA_ENTRY insert denied', $$insert into public.expense_categories(company_id,code,name) values ('75000000-0000-4000-8000-0000000000a1','DENIED','Denied')$$,'42501');
select pg_temp.check_sql('DATA_ENTRY name=Denied denied', $$update public.expense_categories set name='Denied' where company_id='75000000-0000-4000-8000-0000000000a1'$$,null,0);
select pg_temp.check_sql('DATA_ENTRY status=INACTIVE denied', $$update public.expense_categories set status='INACTIVE' where company_id='75000000-0000-4000-8000-0000000000a1'$$,null,0);
select pg_temp.check_sql('DATA_ENTRY status=ACTIVE denied', $$update public.expense_categories set status='ACTIVE' where company_id='75000000-0000-4000-8000-0000000000a1'$$,null,0);
reset role;
update public.company_memberships set role='MANAGEMENT_VIEWER' where user_id='75000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('MANAGEMENT_VIEWER insert denied', $$insert into public.expense_categories(company_id,code,name) values ('75000000-0000-4000-8000-0000000000a1','DENIED','Denied')$$,'42501');
select pg_temp.check_sql('MANAGEMENT_VIEWER name=Denied denied', $$update public.expense_categories set name='Denied' where company_id='75000000-0000-4000-8000-0000000000a1'$$,null,0);
select pg_temp.check_sql('MANAGEMENT_VIEWER status=INACTIVE denied', $$update public.expense_categories set status='INACTIVE' where company_id='75000000-0000-4000-8000-0000000000a1'$$,null,0);
select pg_temp.check_sql('MANAGEMENT_VIEWER status=ACTIVE denied', $$update public.expense_categories set status='ACTIVE' where company_id='75000000-0000-4000-8000-0000000000a1'$$,null,0);
reset role;
update public.company_memberships set role='PROJECT_MANAGER' where user_id='75000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('PROJECT_MANAGER insert denied', $$insert into public.expense_categories(company_id,code,name) values ('75000000-0000-4000-8000-0000000000a1','DENIED','Denied')$$,'42501');
select pg_temp.check_sql('PROJECT_MANAGER name=Denied denied', $$update public.expense_categories set name='Denied' where company_id='75000000-0000-4000-8000-0000000000a1'$$,null,0);
select pg_temp.check_sql('PROJECT_MANAGER status=INACTIVE denied', $$update public.expense_categories set status='INACTIVE' where company_id='75000000-0000-4000-8000-0000000000a1'$$,null,0);
select pg_temp.check_sql('PROJECT_MANAGER status=ACTIVE denied', $$update public.expense_categories set status='ACTIVE' where company_id='75000000-0000-4000-8000-0000000000a1'$$,null,0);
reset role;
update public.company_memberships set role='SYSTEM_ADMIN' where user_id='75000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('SYSTEM_ADMIN insert denied', $$insert into public.expense_categories(company_id,code,name) values ('75000000-0000-4000-8000-0000000000a1','DENIED','Denied')$$,'42501');
select pg_temp.check_sql('SYSTEM_ADMIN name=Denied denied', $$update public.expense_categories set name='Denied' where company_id='75000000-0000-4000-8000-0000000000a1'$$,null,0);
select pg_temp.check_sql('SYSTEM_ADMIN status=INACTIVE denied', $$update public.expense_categories set status='INACTIVE' where company_id='75000000-0000-4000-8000-0000000000a1'$$,null,0);
select pg_temp.check_sql('SYSTEM_ADMIN status=ACTIVE denied', $$update public.expense_categories set status='ACTIVE' where company_id='75000000-0000-4000-8000-0000000000a1'$$,null,0);
reset role;
update public.company_memberships set role='ACCOUNTING_ADMIN' where user_id='75000000-0000-4000-8000-000000000001';
update public.profiles set status='INACTIVE' where user_id='75000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('inactive profiles insert', $$insert into public.expense_categories(company_id,code,name) values ('75000000-0000-4000-8000-0000000000a1','DENIED','Denied')$$,'42501');
select pg_temp.check_sql('inactive profiles update', $$update public.expense_categories set name='Denied'$$,null,0);
reset role;
update public.profiles set status='ACTIVE' where user_id='75000000-0000-4000-8000-000000000001';
update public.company_memberships set status='INACTIVE' where user_id='75000000-0000-4000-8000-000000000001';
set local role authenticated;
select pg_temp.check_sql('inactive company_memberships insert', $$insert into public.expense_categories(company_id,code,name) values ('75000000-0000-4000-8000-0000000000a1','DENIED','Denied')$$,'42501');
select pg_temp.check_sql('inactive company_memberships update', $$update public.expense_categories set name='Denied'$$,null,0);
reset role;
update public.company_memberships set status='ACTIVE' where user_id='75000000-0000-4000-8000-000000000001';
update public.companies set status='INACTIVE' where id='75000000-0000-4000-8000-0000000000a1';
set local role authenticated;
select pg_temp.check_sql('inactive companies insert', $$insert into public.expense_categories(company_id,code,name) values ('75000000-0000-4000-8000-0000000000a1','DENIED','Denied')$$,'42501');
select pg_temp.check_sql('inactive companies update', $$update public.expense_categories set name='Denied'$$,null,0);
reset role;
update public.companies set status='ACTIVE' where id='75000000-0000-4000-8000-0000000000a1';
-- A second authorized tenant may reuse the normalized code.
insert into public.company_memberships(company_id,user_id,role) values ('75000000-0000-4000-8000-0000000000a2','75000000-0000-4000-8000-000000000001','ACCOUNTING_ADMIN');
set local role authenticated;
select pg_temp.check_sql('same code other authorized Company', $$insert into public.expense_categories(company_id,code,name) values ('75000000-0000-4000-8000-0000000000a2','MAT','Materials')$$,null,1);
reset role;
-- Actual service role, with a populated JWT, must preserve imported NULL actors.
set local role service_role;
insert into public.expense_categories(id,company_id,code,name,created_at,updated_at,created_by,updated_by) values
('75000000-0000-4000-8000-0000000000f1','75000000-0000-4000-8000-0000000000a1','IMPORT','Imported','2001-01-01','2002-01-01',null,null),
('75000000-0000-4000-8000-0000000000f2','75000000-0000-4000-8000-0000000000a1','IMPORT-ACTOR','Imported actor','2001-01-01','2002-01-01','75000000-0000-4000-8000-000000000001','75000000-0000-4000-8000-000000000001');
do $$ declare c public.expense_categories; begin
 select * into strict c from public.expense_categories where code='IMPORT' and company_id='75000000-0000-4000-8000-0000000000a1';
 if c.created_by is not null or c.updated_by is not null or c.created_at<>'2001-01-01'::timestamptz or c.updated_at<>'2002-01-01'::timestamptz then raise exception 'Trusted import provenance overwritten'; end if;
 update public.expense_categories set name=name where id=c.id returning * into c;
 if c.updated_by is not null or c.created_by is not null or c.updated_at<='2002-01-01'::timestamptz then raise exception 'Trusted update mismatch'; end if;
 insert into pg_temp.slice5_results values ('service role with JWT preserves NULL import provenance and advances token',true);
end $$;
select pg_temp.check_sql('creation timestamp immutable for trusted update', $$update public.expense_categories set created_at=now() where id='75000000-0000-4000-8000-0000000000f1'$$,'23514');
select pg_temp.check_sql('creation actor immutable for trusted update', $$update public.expense_categories set created_by=null where id='75000000-0000-4000-8000-0000000000f2'$$,'23514');
select pg_temp.check_sql('trusted tenant reassignment rejected', $$update public.expense_categories set company_id='75000000-0000-4000-8000-0000000000a2' where id='75000000-0000-4000-8000-0000000000f1'$$,'23514');
reset role;
set local role authenticated;
update public.expense_categories set name='Imported edited' where id='75000000-0000-4000-8000-0000000000f1';
do $$ declare c public.expense_categories; begin
 select * into strict c from public.expense_categories where id='75000000-0000-4000-8000-0000000000f1';
 if c.created_by is not null or c.created_at<>'2001-01-01'::timestamptz or c.updated_by<>auth.uid() then raise exception 'Browser update fabricated creation provenance'; end if;
 insert into pg_temp.slice5_results values ('browser update preserves imported creation provenance',true);
end $$;
reset role;
-- A valid internal draft dependency exists only inside this rolled-back test.
insert into public.parties(id,company_id,type,name) values ('75000000-0000-4000-8000-0000000000e1','75000000-0000-4000-8000-0000000000a1','SUPPLIER','Rollback supplier');
insert into public.expenses(company_id,expense_reference,expense_date,expense_category_id,supplier_id,description,net_amount_minor,vat_mode,vat_amount_minor,gross_amount_minor,funding_mode,payment_method) values
('75000000-0000-4000-8000-0000000000a1','P6C-S5-ROLLBACK',current_date,'75000000-0000-4000-8000-0000000000f1','75000000-0000-4000-8000-0000000000e1','Rollback dependency',1,'ZERO',0,1,'SUPPLIER_CREDIT','OTHER');
create temporary table financial_before as select
 (select md5(coalesce(jsonb_agg(to_jsonb(e) order by id)::text,'')) from public.expenses e) expenses,
 (select md5(coalesce(jsonb_agg(to_jsonb(e) order by id)::text,'')) from public.journal_entries e) journals,
 (select md5(coalesce(jsonb_agg(to_jsonb(e) order by id)::text,'')) from public.journal_lines e) lines;
select pg_temp.check_sql('referenced category delete restricted', $$delete from public.expense_categories where id='75000000-0000-4000-8000-0000000000f1'$$,'23503');
set local role authenticated;
update public.expense_categories set status='INACTIVE',code='IMPORT-RENAMED',name='Renamed' where id='75000000-0000-4000-8000-0000000000f1';
reset role;
do $$ begin
 if not exists(select 1 from financial_before where
 expenses=(select md5(coalesce(jsonb_agg(to_jsonb(e) order by id)::text,'')) from public.expenses e) and
 journals=(select md5(coalesce(jsonb_agg(to_jsonb(e) order by id)::text,'')) from public.journal_entries e) and
 lines=(select md5(coalesce(jsonb_agg(to_jsonb(e) order by id)::text,'')) from public.journal_lines e)) then raise exception 'Financial history changed'; end if;
 insert into slice5_results values ('referenced metadata/status update changes no expense or journal data',true);
end $$;
set local role anon;
select pg_temp.check_sql('anonymous insert denied', $$insert into public.expense_categories(company_id,code,name) values ('75000000-0000-4000-8000-0000000000a1','ANON','Anonymous')$$,'42501');
reset role;
select count(*) as passing_assertions, bool_and(passed) as all_passed, jsonb_agg(label) as checks from slice5_results;
rollback;
