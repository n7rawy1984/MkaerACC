-- Fixture/Auth cleanup complete. Retained documentation; see README.md for current status.
-- MakerACC-Development (eqnzueginpkskbnqvgoc) ONLY. Controlled fixture, not a migration. Execute once.
begin;
do $fixture$
declare r record; n bigint;
begin
  if (select count(*) from auth.users where id='dc9ad1f5-804d-4f33-ab65-5e796fec0616' and email='p6c-slice3-user@example.test') <> 1
    or (select count(*) from auth.users where id='dc9ad1f5-804d-4f33-ab65-5e796fec0616' or lower(email)='p6c-slice3-user@example.test') <> 1
    or (select count(*) from public.profiles where user_id='dc9ad1f5-804d-4f33-ab65-5e796fec0616' and email_snapshot='p6c-slice3-user@example.test' and status='ACTIVE') <> 1 then
    raise exception 'Synthetic identity/profile mismatch';
  end if;
  if (select count(*) from (
select id from public.companies where id::text like '73000000-0000-4000-8000-%' or lower(code) like 'p6c-s3-%' or name like 'P6C Slice 3%'
union all select company_id from public.company_settings where company_id::text like '73000000-0000-4000-8000-%' or tenant_slug like 'p6c-s3-%'
union all select id from public.company_memberships where id::text like '73000000-0000-4000-8000-%' or user_id='dc9ad1f5-804d-4f33-ab65-5e796fec0616'
union all select id from public.projects where id::text like '73000000-0000-4000-8000-%' or lower(btrim(code)) like 'p6c-s3-%'
union all select id from public.project_assignments where id::text like '73000000-0000-4000-8000-%' or user_id='dc9ad1f5-804d-4f33-ab65-5e796fec0616'
union all select id from public.accounts where id::text like '73000000-0000-4000-8000-%' or lower(btrim(code)) like 'p6c-s3-%'
union all select id from public.treasury_accounts where id::text like '73000000-0000-4000-8000-%' or lower(btrim(code)) like 'p6c-s3-%'
) x) <> 0 then raise exception 'Fixture ID/code/slug/user collision'; end if;
  if (select count(*) from public.companies) <> 14 or (select count(*) from public.company_settings) <> 14 then raise exception 'Baseline changed'; end if;
  insert into public.companies (id,code,name,legal_name,status,notes) values
    ('73000000-0000-4000-8000-0000000000a1','P6C-S3-ALPHA','P6C Slice 3 Alpha','P6C Slice 3 Alpha Synthetic LLC','ACTIVE','Temporary P6C Slice 3 verification only'),
    ('73000000-0000-4000-8000-0000000000a2','P6C-S3-BETA','P6C Slice 3 Beta','P6C Slice 3 Beta Synthetic LLC','ACTIVE','Temporary P6C Slice 3 verification only');
  insert into public.company_settings (company_id,tenant_slug,app_display_name,default_locale,primary_color,accent_color) values
    ('73000000-0000-4000-8000-0000000000a1','p6c-s3-alpha','P6C S3 Alpha','en','#1d4ed8','#0891b2'),
    ('73000000-0000-4000-8000-0000000000a2','p6c-s3-beta','P6C S3 Beta','ar','#7e22ce','#c2410c');
  insert into public.company_memberships (id,company_id,user_id,role,status) values
    ('73000000-0000-4000-8000-0000000000b1','73000000-0000-4000-8000-0000000000a1','dc9ad1f5-804d-4f33-ab65-5e796fec0616','MANAGEMENT_VIEWER','ACTIVE'),
    ('73000000-0000-4000-8000-0000000000b2','73000000-0000-4000-8000-0000000000a2','dc9ad1f5-804d-4f33-ab65-5e796fec0616','MANAGEMENT_VIEWER','ACTIVE');
  insert into public.projects (id,company_id,code,name,status) values
    ('73000000-0000-4000-8000-0000000000c1','73000000-0000-4000-8000-0000000000a1','P6C-S3-PROJECT','P6C Slice 3 Assignment Project','ACTIVE');
  insert into public.project_assignments (id,company_id,project_id,user_id,status) values
    ('73000000-0000-4000-8000-0000000000d1','73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000c1','dc9ad1f5-804d-4f33-ab65-5e796fec0616','ACTIVE');
  insert into public.accounts (id,company_id,code,name,account_type,parent_account_id,requires_party,status,system_key) values
    ('73000000-0000-4000-8000-0000000000e1','73000000-0000-4000-8000-0000000000a1','P6C-S3-1000','P6C S3 Assets Root','ASSET',null,false,'ACTIVE',null),
    ('73000000-0000-4000-8000-0000000000e2','73000000-0000-4000-8000-0000000000a1','P6C-S3-1010','P6C S3 Cash GL — النقد','ASSET','73000000-0000-4000-8000-0000000000e1',false,'ACTIVE',null),
    ('73000000-0000-4000-8000-0000000000e3','73000000-0000-4000-8000-0000000000a1','P6C-S3-1020','P6C S3 Petty Cash GL','ASSET','73000000-0000-4000-8000-0000000000e1',false,'INACTIVE',null),
    ('73000000-0000-4000-8000-0000000000e4','73000000-0000-4000-8000-0000000000a1','P6C-S3-1030','P6C S3 Bank GL','ASSET','73000000-0000-4000-8000-0000000000e1',false,'ACTIVE',null),
    ('73000000-0000-4000-8000-0000000000e5','73000000-0000-4000-8000-0000000000a1','P6C-S3-1040','P6C S3 Project Cash GL','ASSET','73000000-0000-4000-8000-0000000000e1',false,'ACTIVE',null),
    ('73000000-0000-4000-8000-0000000000e6','73000000-0000-4000-8000-0000000000a1','P6C-S3-1050','P6C S3 Project Bank GL','ASSET','73000000-0000-4000-8000-0000000000e1',false,'ACTIVE',null),
    ('73000000-0000-4000-8000-0000000000e7','73000000-0000-4000-8000-0000000000a1','P6C-S3-1100','P6C S3 Custody System — عهدة','ASSET','73000000-0000-4000-8000-0000000000e1',true,'ACTIVE','CUSTODY_ADVANCE'),
    ('73000000-0000-4000-8000-0000000000e8','73000000-0000-4000-8000-0000000000a1','P6C-S3-5000','P6C S3 Expense Inactive','EXPENSE',null,false,'INACTIVE',null);
  insert into public.treasury_accounts (id,company_id,code,name,type,gl_account_id,project_id,status,bank_name,account_reference,notes) values
    ('73000000-0000-4000-8000-0000000000f1','73000000-0000-4000-8000-0000000000a1','P6C-S3-CASH','P6C S3 Cash — نقد','CASH','73000000-0000-4000-8000-0000000000e2',null,'ACTIVE',null,null,null),
    ('73000000-0000-4000-8000-0000000000f2','73000000-0000-4000-8000-0000000000a1','P6C-S3-PETTY','P6C S3 Petty Cash Inactive','PETTY_CASH','73000000-0000-4000-8000-0000000000e3',null,'INACTIVE',null,null,'Synthetic inactive reference'),
    ('73000000-0000-4000-8000-0000000000f3','73000000-0000-4000-8000-0000000000a1','P6C-S3-BANK','P6C S3 Main Bank','BANK','73000000-0000-4000-8000-0000000000e4',null,'ACTIVE','Synthetic Verification Bank','001234567890','Synthetic bank reference only'),
    ('73000000-0000-4000-8000-0000000000f4','73000000-0000-4000-8000-0000000000a1','P6C-S3-PROJECT-CASH','P6C S3 Site Cash — الموقع','PROJECT_CASH_BOX','73000000-0000-4000-8000-0000000000e5','73000000-0000-4000-8000-0000000000c1','ACTIVE',null,null,null),
    ('73000000-0000-4000-8000-0000000000f5','73000000-0000-4000-8000-0000000000a1','P6C-S3-PROJECT-BANK','P6C S3 Project Bank','PROJECT_BANK','73000000-0000-4000-8000-0000000000e6','73000000-0000-4000-8000-0000000000c1','ACTIVE','Synthetic Project Bank','000987654321',null);
  if (select count(*) from public.company_settings where company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2')) <> 2 then raise exception 'Unexpected company_settings count'; end if;
  if (select count(*) from public.company_memberships where company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2')) <> 2 then raise exception 'Unexpected company_memberships count'; end if;
  if (select count(*) from public.projects where company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2')) <> 1 then raise exception 'Unexpected projects count'; end if;
  if (select count(*) from public.project_assignments where company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2')) <> 1 then raise exception 'Unexpected project_assignments count'; end if;
  if (select count(*) from public.accounts where company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2')) <> 8 then raise exception 'Unexpected accounts count'; end if;
  if (select count(*) from public.treasury_accounts where company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2')) <> 5 then raise exception 'Unexpected treasury_accounts count'; end if;
  if exists (select 1 from public.treasury_accounts t left join public.accounts a on a.id=t.gl_account_id and a.company_id=t.company_id where t.company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2') and (a.id is null or a.account_type<>'ASSET')) then raise exception 'Invalid Treasury GL link'; end if;
  if exists (select gl_account_id from public.treasury_accounts where company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2') group by gl_account_id having count(*)>1) then raise exception 'Duplicate Treasury GL'; end if;
  if exists (select 1 from public.treasury_accounts where company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2') and (company_id<>'73000000-0000-4000-8000-0000000000a1' or (project_id is not null and project_id<>'73000000-0000-4000-8000-0000000000c1'))) then raise exception 'Invalid Treasury Project/Company'; end if;
  if exists (select 1 from public.accounts where company_id='73000000-0000-4000-8000-0000000000a2') or exists (select 1 from public.projects where company_id='73000000-0000-4000-8000-0000000000a2') then raise exception 'Beta must be empty'; end if;
  if exists (select 1 from public.company_memberships where user_id='dc9ad1f5-804d-4f33-ab65-5e796fec0616' and id not in ('73000000-0000-4000-8000-0000000000b1','73000000-0000-4000-8000-0000000000b2'))
    or exists (select 1 from public.project_assignments where user_id='dc9ad1f5-804d-4f33-ab65-5e796fec0616' and id<>'73000000-0000-4000-8000-0000000000d1') then raise exception 'Unrelated user membership/assignment'; end if;
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
$fixture$;
commit;
