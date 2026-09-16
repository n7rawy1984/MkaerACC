-- Exact-manifest cleanup of only the disposable Slice 7 browser fixture.
begin;
select set_config('makeracc.fixture_user','',true);
do $$
declare
 actor uuid := nullif(current_setting('makeracc.fixture_user'),'')::uuid;
 fixture_companies uuid[] := array['77200000-0000-4000-8000-0000000000a1','77200000-0000-4000-8000-0000000000a2']::uuid[];
 t record; n bigint; removed integer;
begin
 if actor is null or not exists(select 1 from auth.users where id=actor and email='p6c-s7-browser@example.test') then raise exception 'Exact fixture Auth identity required'; end if;
 if (select count(*) from public.companies where ((id=fixture_companies[1] and code='P6C-S7-BROWSER-A' and name='Slice 7 Alpha') or (id=fixture_companies[2] and code='P6C-S7-BROWSER-B' and name='Slice 7 Beta')))<>cardinality(fixture_companies) then raise exception 'Company manifest mismatch'; end if;
 if (select count(*) from public.company_memberships where company_id=any(fixture_companies))<>cardinality(fixture_companies)
 or exists(select 1 from public.company_memberships where (user_id=actor and not(company_id=any(fixture_companies))) or (company_id=any(fixture_companies) and user_id<>actor))
 or exists(select 1 from public.project_assignments where user_id=actor) then raise exception 'Unexpected authority dependency'; end if;
 -- Fail before deleting anything if any other Company-owned table contains rows.
 for t in select table_name from information_schema.columns where table_schema='public' and column_name='company_id'
 and table_name not in ('company_settings','company_memberships') loop
  execute format('select count(*) from public.%I where company_id=any($1)',t.table_name) into n using fixture_companies;
  if n<>0 then raise exception 'Unexpected dependency in %',t.table_name; end if;
 end loop;
 -- Actor FKs elsewhere must not be silently removed or orphaned.
 for t in select table_name,column_name from information_schema.columns where table_schema='public'
 and column_name in ('created_by','updated_by') loop
  if t.table_name in ('companies','company_settings','company_memberships') then
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
 if (select count(*) from public.company_settings where company_id=any(fixture_companies))<>cardinality(fixture_companies) then raise exception 'Settings manifest mismatch'; end if;
 delete from public.company_memberships where company_id=any(fixture_companies) and user_id=actor;
 get diagnostics removed=row_count; if removed<>cardinality(fixture_companies) then raise exception 'Membership delete count mismatch'; end if;
 delete from public.companies where ((id=fixture_companies[1] and code='P6C-S7-BROWSER-A' and name='Slice 7 Alpha') or (id=fixture_companies[2] and code='P6C-S7-BROWSER-B' and name='Slice 7 Beta'));
 get diagnostics removed=row_count; if removed<>cardinality(fixture_companies) then raise exception 'Company delete count mismatch'; end if;
 delete from public.profiles where user_id=actor;
 get diagnostics removed=row_count; if removed<>1 then raise exception 'Profile delete count mismatch'; end if;
 delete from auth.users where id=actor and email='p6c-s7-browser@example.test';
 get diagnostics removed=row_count; if removed<>1 then raise exception 'Auth delete count mismatch'; end if;
end $$;
commit;
