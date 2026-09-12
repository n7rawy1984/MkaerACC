-- CLEANUP COMPLETE for this run. Historical guarded script; do not rerun.
-- MakerACC-Development only.
-- Restore synthetic profile ACTIVE before running; delete Auth user manually afterward.
begin;
do $cleanup$
declare r record; n bigint;
begin
  if (select count(*) from auth.users where id='74e36291-172a-44e7-95be-f6c1283c315b' and email='p6c-slice2-user@example.test') <> 1
    or (select count(*) from auth.users where id='74e36291-172a-44e7-95be-f6c1283c315b' or lower(email)='p6c-slice2-user@example.test') <> 1
    or (select count(*) from public.profiles where user_id='74e36291-172a-44e7-95be-f6c1283c315b' and email_snapshot='p6c-slice2-user@example.test' and status='ACTIVE') <> 1 then
    raise exception 'Synthetic identity/profile mismatch';
  end if;
  perform id from public.companies where id in ('72000000-0000-4000-8000-0000000000a1','72000000-0000-4000-8000-0000000000a2') for update;
  if (select count(*) from public.companies where (id,code,name) in (
    ('72000000-0000-4000-8000-0000000000a1'::uuid,'P6C-S2-ALPHA','P6C Slice 2 Alpha'),
    ('72000000-0000-4000-8000-0000000000a2'::uuid,'P6C-S2-BETA','P6C Slice 2 Beta'))) <> 2 then
    raise exception 'Fixture Company identity mismatch';
  end if;
  for r in select n.nspname as schema_name,c.relname as table_name from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('public','private') and c.relkind='r'
      and exists (select 1 from pg_attribute x where x.attrelid=c.oid and x.attname='company_id' and not x.attisdropped)
      and not (n.nspname='public' and c.relname in ('company_settings','company_memberships','projects','project_assignments','parties','expense_categories'))
  loop
    execute format('select count(*) from %I.%I where company_id in ($1,$2)',r.schema_name,r.table_name) into n using '72000000-0000-4000-8000-0000000000a1'::uuid,'72000000-0000-4000-8000-0000000000a2'::uuid;
    if n <> 0 then raise exception 'Unexpected non-fixture rows in %.%',r.schema_name,r.table_name; end if;
  end loop;
  if (select count(*) from public.project_assignments where company_id in ('72000000-0000-4000-8000-0000000000a1','72000000-0000-4000-8000-0000000000a2')) <> 1 then raise exception 'Unexpected project_assignments count'; end if;
  if (select count(*) from public.projects where company_id in ('72000000-0000-4000-8000-0000000000a1','72000000-0000-4000-8000-0000000000a2')) <> 1 then raise exception 'Unexpected projects count'; end if;
  if (select count(*) from public.parties where company_id in ('72000000-0000-4000-8000-0000000000a1','72000000-0000-4000-8000-0000000000a2')) <> 6 then raise exception 'Unexpected parties count'; end if;
  if (select count(*) from public.expense_categories where company_id in ('72000000-0000-4000-8000-0000000000a1','72000000-0000-4000-8000-0000000000a2')) <> 3 then raise exception 'Unexpected expense_categories count'; end if;
  if (select count(*) from public.company_memberships where company_id in ('72000000-0000-4000-8000-0000000000a1','72000000-0000-4000-8000-0000000000a2')) <> 2 then raise exception 'Unexpected company_memberships count'; end if;
  if (select count(*) from public.company_settings where company_id in ('72000000-0000-4000-8000-0000000000a1','72000000-0000-4000-8000-0000000000a2')) <> 2 then raise exception 'Unexpected company_settings count'; end if;
  if exists (select 1 from public.company_memberships where user_id='74e36291-172a-44e7-95be-f6c1283c315b' and id not in ('72000000-0000-4000-8000-0000000000b1','72000000-0000-4000-8000-0000000000b2'))
    or exists (select 1 from public.project_assignments where user_id='74e36291-172a-44e7-95be-f6c1283c315b' and id<>'72000000-0000-4000-8000-0000000000d1') then raise exception 'User has unrelated membership/assignment'; end if;
  delete from public.project_assignments where id='72000000-0000-4000-8000-0000000000d1' and company_id='72000000-0000-4000-8000-0000000000a1' and project_id='72000000-0000-4000-8000-0000000000c1' and user_id='74e36291-172a-44e7-95be-f6c1283c315b';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Unexpected project_assignments cleanup row count'; end if;
  delete from public.projects where id='72000000-0000-4000-8000-0000000000c1' and company_id='72000000-0000-4000-8000-0000000000a1' and code='P6C-S2-PROJECT';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Unexpected projects cleanup row count'; end if;
  delete from public.parties where id='72000000-0000-4000-8000-0000000000e1' and company_id='72000000-0000-4000-8000-0000000000a1' and code='P6C-S2-OWNER' and type='OWNER';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Unexpected parties cleanup row count'; end if;
  delete from public.parties where id='72000000-0000-4000-8000-0000000000e2' and company_id='72000000-0000-4000-8000-0000000000a1' and code='P6C-S2-EMPLOYEE' and type='EMPLOYEE';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Unexpected parties cleanup row count'; end if;
  delete from public.parties where id='72000000-0000-4000-8000-0000000000e3' and company_id='72000000-0000-4000-8000-0000000000a1' and code='P6C-S2-CUSTODIAN' and type='CUSTODIAN';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Unexpected parties cleanup row count'; end if;
  delete from public.parties where id='72000000-0000-4000-8000-0000000000e4' and company_id='72000000-0000-4000-8000-0000000000a1' and code='P6C-S2-SUPPLIER' and type='SUPPLIER';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Unexpected parties cleanup row count'; end if;
  delete from public.parties where id='72000000-0000-4000-8000-0000000000e5' and company_id='72000000-0000-4000-8000-0000000000a1' and code='P6C-S2-SUBCONTRACTOR' and type='SUBCONTRACTOR';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Unexpected parties cleanup row count'; end if;
  delete from public.parties where id='72000000-0000-4000-8000-0000000000e6' and company_id='72000000-0000-4000-8000-0000000000a1' and code='P6C-S2-OTHER' and type='OTHER';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Unexpected parties cleanup row count'; end if;
  delete from public.expense_categories where id='72000000-0000-4000-8000-0000000000f1' and company_id='72000000-0000-4000-8000-0000000000a1' and code='P6C-S2-CAT-ACTIVE';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Unexpected expense_categories cleanup row count'; end if;
  delete from public.expense_categories where id='72000000-0000-4000-8000-0000000000f2' and company_id='72000000-0000-4000-8000-0000000000a1' and code='P6C-S2-CAT-INACTIVE';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Unexpected expense_categories cleanup row count'; end if;
  delete from public.expense_categories where id='72000000-0000-4000-8000-0000000000f3' and company_id='72000000-0000-4000-8000-0000000000a1' and code='P6C-S2-CAT-NULL';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Unexpected expense_categories cleanup row count'; end if;
  delete from public.company_memberships where id='72000000-0000-4000-8000-0000000000b1' and company_id='72000000-0000-4000-8000-0000000000a1' and user_id='74e36291-172a-44e7-95be-f6c1283c315b';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Unexpected company_memberships cleanup row count'; end if;
  delete from public.company_memberships where id='72000000-0000-4000-8000-0000000000b2' and company_id='72000000-0000-4000-8000-0000000000a2' and user_id='74e36291-172a-44e7-95be-f6c1283c315b';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Unexpected company_memberships cleanup row count'; end if;
  delete from public.company_settings where company_id='72000000-0000-4000-8000-0000000000a1' and tenant_slug='p6c-s2-alpha';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Unexpected company_settings cleanup row count'; end if;
  delete from public.company_settings where company_id='72000000-0000-4000-8000-0000000000a2' and tenant_slug='p6c-s2-beta';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Unexpected company_settings cleanup row count'; end if;
  delete from public.companies where id='72000000-0000-4000-8000-0000000000a1' and code='P6C-S2-ALPHA';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Unexpected companies cleanup row count'; end if;
  delete from public.companies where id='72000000-0000-4000-8000-0000000000a2' and code='P6C-S2-BETA';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Unexpected companies cleanup row count'; end if;
  delete from public.profiles where user_id='74e36291-172a-44e7-95be-f6c1283c315b' and email_snapshot='p6c-slice2-user@example.test';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Unexpected profiles cleanup row count'; end if;
end;
$cleanup$;
commit;
