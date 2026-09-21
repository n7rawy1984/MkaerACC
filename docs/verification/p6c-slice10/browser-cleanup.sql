-- Exact-manifest cleanup of only the disposable Slice 10 browser fixture.
begin;
select set_config('makeracc.fixture_user','',true);
do $$
declare
 actor uuid := nullif(current_setting('makeracc.fixture_user'),'')::uuid;
 fixture_companies uuid[] := array['80200000-0000-4000-8000-0000000000a1','80200000-0000-4000-8000-0000000000a2']::uuid[];
 t record; n bigint; removed integer;
begin
 if actor is null or not exists(select 1 from auth.users where id=actor and email='p6c-s10-browser@example.test') then raise exception 'Exact fixture Auth identity required'; end if;
 if (select count(*) from public.companies where ((id=fixture_companies[1] and code='P6C-S10-BROWSER-A' and name='Slice 10 Alpha') or (id=fixture_companies[2] and code='P6C-S10-BROWSER-B' and name='Slice 10 Beta')))<>cardinality(fixture_companies) then raise exception 'Company manifest mismatch'; end if;
 if (select count(*) from public.company_memberships where company_id=any(fixture_companies))<>cardinality(fixture_companies)
 or exists(select 1 from public.company_memberships where (user_id=actor and not(company_id=any(fixture_companies))) or (company_id=any(fixture_companies) and user_id<>actor))
 or exists(select 1 from public.project_assignments where user_id=actor and id<>'80200000-0000-4000-8000-0000000000e1') then raise exception 'Unexpected authority dependency'; end if;
 if (select count(*) from public.treasury_accounts where company_id=any(fixture_companies))<>3 or
 (select count(*) from public.treasury_accounts where
 (id='80200000-0000-4000-8000-0000000000b1' and company_id=fixture_companies[1] and code='0001' and type='BANK' and status='INACTIVE' and gl_account_id='80200000-0000-4000-8000-0000000000d1' and project_id is null and bank_name='Bank Alpha' and account_reference='000123' and notes='Keep notes') or
 (id='80200000-0000-4000-8000-0000000000b2' and company_id=fixture_companies[1] and code='0002' and type='CASH' and status='ACTIVE' and gl_account_id='80200000-0000-4000-8000-0000000000d2' and project_id='80200000-0000-4000-8000-0000000000c1' and bank_name is null and account_reference is null and notes is null) or
 (id='80200000-0000-4000-8000-0000000000b3' and company_id=fixture_companies[2] and code='0003' and type='CASH' and status='ACTIVE' and gl_account_id='80200000-0000-4000-8000-0000000000d3' and project_id is null and bank_name is null and account_reference is null and notes is null))<>3 then raise exception 'Treasury manifest mismatch'; end if;
 if (select count(*) from public.accounts where company_id=any(fixture_companies))<>3 or
 (select count(*) from public.accounts where account_type='ASSET' and status='ACTIVE' and parent_account_id is null and system_key is null and not requires_party and
 ((id='80200000-0000-4000-8000-0000000000d1' and company_id=fixture_companies[1] and code='GL1') or (id='80200000-0000-4000-8000-0000000000d2' and company_id=fixture_companies[1] and code='GL2') or (id='80200000-0000-4000-8000-0000000000d3' and company_id=fixture_companies[2] and code='GL3')))<>3 then raise exception 'GL manifest mismatch'; end if;
 if (select count(*) from public.projects where company_id=any(fixture_companies))<>1 or not exists(select 1 from public.projects where id='80200000-0000-4000-8000-0000000000c1' and company_id=fixture_companies[1] and code='P1') then raise exception 'Project manifest mismatch'; end if;
 if (select count(*) from public.project_assignments where company_id=any(fixture_companies))<>1 or not exists(select 1 from public.project_assignments where id='80200000-0000-4000-8000-0000000000e1' and company_id=fixture_companies[1] and project_id='80200000-0000-4000-8000-0000000000c1' and user_id=actor) then raise exception 'Assignment manifest mismatch'; end if;
 -- Fail before deleting anything if any other Company-owned table contains rows.
 for t in select table_name from information_schema.columns where table_schema='public' and column_name='company_id'
 and table_name not in ('company_settings','company_memberships','accounts','treasury_accounts','projects','project_assignments') loop
  execute format('select count(*) from public.%I where company_id=any($1)',t.table_name) into n using fixture_companies;
  if n<>0 then raise exception 'Unexpected dependency in %',t.table_name; end if;
 end loop;
 -- Actor FKs elsewhere must not be silently removed or orphaned.
 for t in select table_name,column_name from information_schema.columns where table_schema='public'
 and column_name in ('created_by','updated_by') loop
  if t.table_name in ('companies','company_settings','company_memberships','accounts','treasury_accounts','projects','project_assignments') then
   if t.table_name='companies' then
    execute format('select count(*) from public.%I where %I=$1 and not(id=any($2))',t.table_name,t.column_name) into n using actor,fixture_companies;
   else
    execute format('select count(*) from public.%I where %I=$1 and not(company_id=any($2))',t.table_name,t.column_name) into n using actor,fixture_companies;
   end if;
  else
   execute format('select count(*) from public.%I where %I=$1',t.table_name,t.column_name) into n using actor;
  end if;
  if n<>0 then raise exception 'Unexpected actor dependency %.%',t.table_name,t.column_name; end if;
 end loop;
 if (select count(*) from public.company_settings where (company_id=fixture_companies[1] and tenant_slug='p6c-s10-browser-a') or (company_id=fixture_companies[2] and tenant_slug='p6c-s10-browser-b'))<>cardinality(fixture_companies) then raise exception 'Settings manifest mismatch'; end if;
 delete from public.treasury_accounts where company_id=any(fixture_companies) and id in ('80200000-0000-4000-8000-0000000000b1','80200000-0000-4000-8000-0000000000b2','80200000-0000-4000-8000-0000000000b3');
 get diagnostics removed=row_count; if removed<>3 then raise exception 'Treasury delete mismatch'; end if;
 delete from public.accounts where company_id=any(fixture_companies) and id in ('80200000-0000-4000-8000-0000000000d1','80200000-0000-4000-8000-0000000000d2','80200000-0000-4000-8000-0000000000d3');
 get diagnostics removed=row_count; if removed<>3 then raise exception 'GL delete mismatch'; end if;
 delete from public.project_assignments where company_id=fixture_companies[1] and id='80200000-0000-4000-8000-0000000000e1' and user_id=actor;
 get diagnostics removed=row_count; if removed<>1 then raise exception 'Assignment delete mismatch'; end if;
 delete from public.projects where company_id=fixture_companies[1] and id='80200000-0000-4000-8000-0000000000c1';
 get diagnostics removed=row_count; if removed<>1 then raise exception 'Project delete mismatch'; end if;
 delete from public.company_memberships where company_id=any(fixture_companies) and user_id=actor;
 get diagnostics removed=row_count; if removed<>cardinality(fixture_companies) then raise exception 'Membership delete count mismatch'; end if;
 delete from public.company_settings where company_id=any(fixture_companies);
 get diagnostics removed=row_count; if removed<>cardinality(fixture_companies) then raise exception 'Settings delete count mismatch'; end if;
 delete from public.companies where ((id=fixture_companies[1] and code='P6C-S10-BROWSER-A' and name='Slice 10 Alpha') or (id=fixture_companies[2] and code='P6C-S10-BROWSER-B' and name='Slice 10 Beta'));
 get diagnostics removed=row_count; if removed<>cardinality(fixture_companies) then raise exception 'Company delete count mismatch'; end if;
 delete from public.profiles where user_id=actor;
 get diagnostics removed=row_count; if removed<>1 then raise exception 'Profile delete count mismatch'; end if;
 delete from auth.users where id=actor and email='p6c-s10-browser@example.test';
 get diagnostics removed=row_count; if removed<>1 then raise exception 'Auth delete count mismatch'; end if;
end $$;
commit;
