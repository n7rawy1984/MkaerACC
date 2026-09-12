-- Fixture/Auth cleanup complete. Retained documentation; see README.md for current status.
-- CLEANUP COMPLETE for this run. No fixture remains; historical guarded script, do not rerun.
-- Restore profile ACTIVE first. Delete Auth user manually AFTER verify.sql reports zero fixture counts.
begin;
do $cleanup$
declare r record; n bigint;
begin
  if (select count(*) from auth.users where id='dc9ad1f5-804d-4f33-ab65-5e796fec0616' and email='p6c-slice3-user@example.test') <> 1
    or (select count(*) from auth.users where id='dc9ad1f5-804d-4f33-ab65-5e796fec0616' or lower(email)='p6c-slice3-user@example.test') <> 1
    or (select count(*) from public.profiles where user_id='dc9ad1f5-804d-4f33-ab65-5e796fec0616' and email_snapshot='p6c-slice3-user@example.test' and status='ACTIVE') <> 1 then
    raise exception 'Synthetic identity/profile mismatch';
  end if;
  perform id from public.companies where id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2') for update;
  if (select count(*) from public.companies where (id,code,name) in (
    ('73000000-0000-4000-8000-0000000000a1'::uuid,'P6C-S3-ALPHA','P6C Slice 3 Alpha'),
    ('73000000-0000-4000-8000-0000000000a2'::uuid,'P6C-S3-BETA','P6C Slice 3 Beta'))) <> 2 then raise exception 'Fixture Company identity mismatch'; end if;
  if (select count(*) from public.company_settings where company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2')) <> 2 then raise exception 'Unexpected company_settings count'; end if;
  if (select count(*) from public.company_memberships where company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2')) <> 2 then raise exception 'Unexpected company_memberships count'; end if;
  if (select count(*) from public.projects where company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2')) <> 1 then raise exception 'Unexpected projects count'; end if;
  if (select count(*) from public.project_assignments where company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2')) <> 1 then raise exception 'Unexpected project_assignments count'; end if;
  if (select count(*) from public.accounts where company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2')) <> 8 then raise exception 'Unexpected accounts count'; end if;
  if (select count(*) from public.treasury_accounts where company_id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2')) <> 5 then raise exception 'Unexpected treasury_accounts count'; end if;
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
  delete from public.project_assignments where id='73000000-0000-4000-8000-0000000000d1' and company_id='73000000-0000-4000-8000-0000000000a1' and project_id='73000000-0000-4000-8000-0000000000c1' and user_id='dc9ad1f5-804d-4f33-ab65-5e796fec0616';
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Unexpected project_assignments cleanup count'; end if;
  delete from public.treasury_accounts where id='73000000-0000-4000-8000-0000000000f1' and company_id='73000000-0000-4000-8000-0000000000a1' and code='P6C-S3-CASH' and type='CASH' and gl_account_id='73000000-0000-4000-8000-0000000000e2';
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Unexpected treasury_accounts cleanup count'; end if;
  delete from public.treasury_accounts where id='73000000-0000-4000-8000-0000000000f2' and company_id='73000000-0000-4000-8000-0000000000a1' and code='P6C-S3-PETTY' and type='PETTY_CASH' and gl_account_id='73000000-0000-4000-8000-0000000000e3';
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Unexpected treasury_accounts cleanup count'; end if;
  delete from public.treasury_accounts where id='73000000-0000-4000-8000-0000000000f3' and company_id='73000000-0000-4000-8000-0000000000a1' and code='P6C-S3-BANK' and type='BANK' and gl_account_id='73000000-0000-4000-8000-0000000000e4';
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Unexpected treasury_accounts cleanup count'; end if;
  delete from public.treasury_accounts where id='73000000-0000-4000-8000-0000000000f4' and company_id='73000000-0000-4000-8000-0000000000a1' and code='P6C-S3-PROJECT-CASH' and type='PROJECT_CASH_BOX' and gl_account_id='73000000-0000-4000-8000-0000000000e5';
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Unexpected treasury_accounts cleanup count'; end if;
  delete from public.treasury_accounts where id='73000000-0000-4000-8000-0000000000f5' and company_id='73000000-0000-4000-8000-0000000000a1' and code='P6C-S3-PROJECT-BANK' and type='PROJECT_BANK' and gl_account_id='73000000-0000-4000-8000-0000000000e6';
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Unexpected treasury_accounts cleanup count'; end if;
  delete from public.projects where id='73000000-0000-4000-8000-0000000000c1' and company_id='73000000-0000-4000-8000-0000000000a1' and code='P6C-S3-PROJECT';
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Unexpected projects cleanup count'; end if;
  delete from public.accounts where id='73000000-0000-4000-8000-0000000000e8' and company_id='73000000-0000-4000-8000-0000000000a1' and code='P6C-S3-5000' and account_type='EXPENSE' and parent_account_id is not distinct from null::uuid;
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Unexpected accounts cleanup count'; end if;
  delete from public.accounts where id='73000000-0000-4000-8000-0000000000e7' and company_id='73000000-0000-4000-8000-0000000000a1' and code='P6C-S3-1100' and account_type='ASSET' and parent_account_id is not distinct from '73000000-0000-4000-8000-0000000000e1'::uuid;
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Unexpected accounts cleanup count'; end if;
  delete from public.accounts where id='73000000-0000-4000-8000-0000000000e6' and company_id='73000000-0000-4000-8000-0000000000a1' and code='P6C-S3-1050' and account_type='ASSET' and parent_account_id is not distinct from '73000000-0000-4000-8000-0000000000e1'::uuid;
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Unexpected accounts cleanup count'; end if;
  delete from public.accounts where id='73000000-0000-4000-8000-0000000000e5' and company_id='73000000-0000-4000-8000-0000000000a1' and code='P6C-S3-1040' and account_type='ASSET' and parent_account_id is not distinct from '73000000-0000-4000-8000-0000000000e1'::uuid;
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Unexpected accounts cleanup count'; end if;
  delete from public.accounts where id='73000000-0000-4000-8000-0000000000e4' and company_id='73000000-0000-4000-8000-0000000000a1' and code='P6C-S3-1030' and account_type='ASSET' and parent_account_id is not distinct from '73000000-0000-4000-8000-0000000000e1'::uuid;
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Unexpected accounts cleanup count'; end if;
  delete from public.accounts where id='73000000-0000-4000-8000-0000000000e3' and company_id='73000000-0000-4000-8000-0000000000a1' and code='P6C-S3-1020' and account_type='ASSET' and parent_account_id is not distinct from '73000000-0000-4000-8000-0000000000e1'::uuid;
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Unexpected accounts cleanup count'; end if;
  delete from public.accounts where id='73000000-0000-4000-8000-0000000000e2' and company_id='73000000-0000-4000-8000-0000000000a1' and code='P6C-S3-1010' and account_type='ASSET' and parent_account_id is not distinct from '73000000-0000-4000-8000-0000000000e1'::uuid;
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Unexpected accounts cleanup count'; end if;
  delete from public.accounts where id='73000000-0000-4000-8000-0000000000e1' and company_id='73000000-0000-4000-8000-0000000000a1' and code='P6C-S3-1000' and account_type='ASSET' and parent_account_id is not distinct from null::uuid;
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Unexpected accounts cleanup count'; end if;
  delete from public.company_memberships where id='73000000-0000-4000-8000-0000000000b1' and company_id='73000000-0000-4000-8000-0000000000a1' and user_id='dc9ad1f5-804d-4f33-ab65-5e796fec0616';
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Unexpected company_memberships cleanup count'; end if;
  delete from public.company_memberships where id='73000000-0000-4000-8000-0000000000b2' and company_id='73000000-0000-4000-8000-0000000000a2' and user_id='dc9ad1f5-804d-4f33-ab65-5e796fec0616';
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Unexpected company_memberships cleanup count'; end if;
  delete from public.company_settings where company_id='73000000-0000-4000-8000-0000000000a1' and tenant_slug='p6c-s3-alpha';
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Unexpected company_settings cleanup count'; end if;
  delete from public.company_settings where company_id='73000000-0000-4000-8000-0000000000a2' and tenant_slug='p6c-s3-beta';
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Unexpected company_settings cleanup count'; end if;
  delete from public.companies where id='73000000-0000-4000-8000-0000000000a1' and code='P6C-S3-ALPHA';
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Unexpected companies cleanup count'; end if;
  delete from public.companies where id='73000000-0000-4000-8000-0000000000a2' and code='P6C-S3-BETA';
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Unexpected companies cleanup count'; end if;
  delete from public.profiles where user_id='dc9ad1f5-804d-4f33-ab65-5e796fec0616' and email_snapshot='p6c-slice3-user@example.test';
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Unexpected profiles cleanup count'; end if;
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
$cleanup$;
commit;
