-- Development-only controlled synthetic fixture. Not a migration. Execute once.
begin;
do $fixture$
declare r record; n bigint;
begin
  if (select count(*) from auth.users where id='74e36291-172a-44e7-95be-f6c1283c315b' and email='p6c-slice2-user@example.test') <> 1
    or (select count(*) from auth.users where id='74e36291-172a-44e7-95be-f6c1283c315b' or lower(email)='p6c-slice2-user@example.test') <> 1
    or (select count(*) from public.profiles where user_id='74e36291-172a-44e7-95be-f6c1283c315b' and email_snapshot='p6c-slice2-user@example.test' and status='ACTIVE') <> 1 then
    raise exception 'Synthetic identity/profile mismatch';
  end if;
  if (select count(*) from (
select id from public.companies where id::text like '72000000-0000-4000-8000-%' or lower(code) like 'p6c-s2-%' or name like 'P6C Slice 2%'
union all select company_id from public.company_settings where company_id::text like '72000000-0000-4000-8000-%' or tenant_slug like 'p6c-s2-%'
union all select id from public.company_memberships where id::text like '72000000-0000-4000-8000-%' or user_id='74e36291-172a-44e7-95be-f6c1283c315b'
union all select id from public.projects where id::text like '72000000-0000-4000-8000-%' or code like 'P6C-S2-%'
union all select id from public.project_assignments where id::text like '72000000-0000-4000-8000-%' or user_id='74e36291-172a-44e7-95be-f6c1283c315b'
union all select id from public.parties where id::text like '72000000-0000-4000-8000-%' or code like 'P6C-S2-%'
union all select id from public.expense_categories where id::text like '72000000-0000-4000-8000-%' or code like 'P6C-S2-%'
) x) <> 0 then raise exception 'Fixture ID/code/slug/user collision'; end if;
  if (select count(*) from public.companies) <> 14 or (select count(*) from public.company_settings) <> 14 then raise exception 'Baseline changed'; end if;
  insert into public.companies (id,code,name,legal_name,status,notes) values
    ('72000000-0000-4000-8000-0000000000a1','P6C-S2-ALPHA','P6C Slice 2 Alpha','P6C Slice 2 Alpha Synthetic LLC','ACTIVE','Temporary P6C Slice 2 verification only'),
    ('72000000-0000-4000-8000-0000000000a2','P6C-S2-BETA','P6C Slice 2 Beta','P6C Slice 2 Beta Synthetic LLC','ACTIVE','Temporary P6C Slice 2 verification only');
  insert into public.company_settings (company_id,tenant_slug,app_display_name,default_locale,primary_color,accent_color) values
    ('72000000-0000-4000-8000-0000000000a1','p6c-s2-alpha','P6C S2 Alpha','en','#1d4ed8','#0891b2'),
    ('72000000-0000-4000-8000-0000000000a2','p6c-s2-beta','P6C S2 Beta','ar','#7e22ce','#c2410c');
  insert into public.company_memberships (id,company_id,user_id,role,status) values
    ('72000000-0000-4000-8000-0000000000b1','72000000-0000-4000-8000-0000000000a1','74e36291-172a-44e7-95be-f6c1283c315b','MANAGEMENT_VIEWER','ACTIVE'),
    ('72000000-0000-4000-8000-0000000000b2','72000000-0000-4000-8000-0000000000a2','74e36291-172a-44e7-95be-f6c1283c315b','MANAGEMENT_VIEWER','ACTIVE');
  insert into public.projects (id,company_id,code,name,status) values
    ('72000000-0000-4000-8000-0000000000c1','72000000-0000-4000-8000-0000000000a1','P6C-S2-PROJECT','P6C Slice 2 Assignment Project','ACTIVE');
  insert into public.project_assignments (id,company_id,project_id,user_id,status) values
    ('72000000-0000-4000-8000-0000000000d1','72000000-0000-4000-8000-0000000000a1','72000000-0000-4000-8000-0000000000c1','74e36291-172a-44e7-95be-f6c1283c315b','ACTIVE');
  insert into public.parties (id,company_id,type,code,name,status,trn,contact_person,notes) values
    ('72000000-0000-4000-8000-0000000000e1','72000000-0000-4000-8000-0000000000a1','OWNER','P6C-S2-OWNER','P6C S2 Owner','ACTIVE',null,null,null),
    ('72000000-0000-4000-8000-0000000000e2','72000000-0000-4000-8000-0000000000a1','EMPLOYEE','P6C-S2-EMPLOYEE','P6C S2 Employee','ACTIVE',null,null,null),
    ('72000000-0000-4000-8000-0000000000e3','72000000-0000-4000-8000-0000000000a1','CUSTODIAN','P6C-S2-CUSTODIAN','P6C S2 Custodian','ACTIVE',null,null,null),
    ('72000000-0000-4000-8000-0000000000e4','72000000-0000-4000-8000-0000000000a1','SUPPLIER','P6C-S2-SUPPLIER','P6C S2 Supplier','ACTIVE','001234567890123','P6C جهة اتصال','Leading-zero TRN verification'),
    ('72000000-0000-4000-8000-0000000000e5','72000000-0000-4000-8000-0000000000a1','SUBCONTRACTOR','P6C-S2-SUBCONTRACTOR','P6C S2 Subcontractor','ACTIVE',null,null,null),
    ('72000000-0000-4000-8000-0000000000e6','72000000-0000-4000-8000-0000000000a1','OTHER','P6C-S2-OTHER','P6C S2 Other','INACTIVE',null,null,null);
  insert into public.expense_categories (id,company_id,code,name,status,description) values
    ('72000000-0000-4000-8000-0000000000f1','72000000-0000-4000-8000-0000000000a1','P6C-S2-CAT-ACTIVE','P6C CAT ACTIVE','ACTIVE','Synthetic active category — مواد'),
    ('72000000-0000-4000-8000-0000000000f2','72000000-0000-4000-8000-0000000000a1','P6C-S2-CAT-INACTIVE','P6C CAT INACTIVE','INACTIVE','Synthetic inactive reference'),
    ('72000000-0000-4000-8000-0000000000f3','72000000-0000-4000-8000-0000000000a1','P6C-S2-CAT-NULL','P6C CAT NULL DESCRIPTION','ACTIVE',null);
  for r in select n.nspname as schema_name,c.relname as table_name from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('public','private') and c.relkind='r'
      and exists (select 1 from pg_attribute x where x.attrelid=c.oid and x.attname='company_id' and not x.attisdropped)
      and not (n.nspname='public' and c.relname in ('company_settings','company_memberships','projects','project_assignments','parties','expense_categories'))
  loop
    execute format('select count(*) from %I.%I where company_id in ($1,$2)',r.schema_name,r.table_name) into n using '72000000-0000-4000-8000-0000000000a1'::uuid,'72000000-0000-4000-8000-0000000000a2'::uuid;
    if n <> 0 then raise exception 'Unexpected non-fixture rows in %.%',r.schema_name,r.table_name; end if;
  end loop;
  if (select count(*) from public.companies c full join public.company_settings s on s.company_id=c.id where c.id is null or s.company_id is null) <> 0 then raise exception 'Company/settings mismatch'; end if;
end;
$fixture$;
commit;
