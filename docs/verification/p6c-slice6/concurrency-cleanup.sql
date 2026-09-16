-- PREPARED / NOT EXECUTED. MakerACC-Development only; NOT a migration.
-- DESTRUCTIVE OPERATIONAL CLEANUP: review and authorize separately after acceptance.
-- Never execute with tests or migrations. Supply EVERY browser/competing-create UUID.
-- Empty extra-ID list deliberately fails when generated Party rows exist.
begin;
select set_config('makeracc.fixture_user','',true);
select set_config('makeracc.created_party_ids','[]',true);
do $$
declare
 actor uuid := '76100000-0000-4000-8000-000000000001'::uuid;
 fixture_companies uuid[] := array['76100000-0000-4000-8000-0000000000a1']::uuid[];
 seeded uuid[] := array['76100000-0000-4000-8000-0000000000f1']::uuid[];
 extras uuid[]; expected uuid[]; t record; n bigint; removed integer;
begin
 if actor is null or not exists(select 1 from auth.users where id=actor and email='p6c-s6-concurrency@example.test') then raise exception 'Exact fixture Auth identity required'; end if;
 select coalesce(array_agg(value::uuid),array[]::uuid[]) into extras from jsonb_array_elements_text(current_setting('makeracc.created_party_ids')::jsonb);
 expected:=seeded||extras;
 if cardinality(expected)<>(select count(distinct x) from unnest(expected) x) then raise exception 'Duplicate manifest IDs'; end if;
 if (select count(*) from public.companies where ((id=fixture_companies[1] and code='P6C-S6-CONCURRENCY' and name='Slice 6 disposable concurrency')))<>cardinality(fixture_companies) then raise exception 'Company manifest mismatch'; end if;
 if (select count(*) from public.company_memberships where company_id=any(fixture_companies))<>cardinality(fixture_companies)
 or exists(select 1 from public.company_memberships where (user_id=actor and not(company_id=any(fixture_companies))) or (company_id=any(fixture_companies) and user_id<>actor))
 or exists(select 1 from public.project_assignments where user_id=actor) then raise exception 'Unexpected authority dependency'; end if;
 if (select count(*) from public.parties where company_id=any(fixture_companies))<>cardinality(expected)
 or (select count(*) from public.parties where company_id=any(fixture_companies) and id=any(expected))<>cardinality(expected)
 or exists(select 1 from public.parties where id=any(extras) and (type<>'SUPPLIER' or created_by is distinct from actor)) then raise exception 'Party manifest mismatch'; end if;
 -- Fail before deleting anything if any other Company-owned table contains rows.
 for t in select table_name from information_schema.columns where table_schema='public' and column_name='company_id'
 and table_name not in ('company_settings','company_memberships','parties') loop
  execute format('select count(*) from public.%I where company_id=any($1)',t.table_name) into n using fixture_companies;
  if n<>0 then raise exception 'Unexpected dependency in %',t.table_name; end if;
 end loop;
 -- Actor FKs elsewhere must not be silently removed or orphaned.
 for t in select table_name,column_name from information_schema.columns where table_schema='public'
 and column_name in ('created_by','updated_by') loop
  if t.table_name in ('parties','companies','company_settings','company_memberships') then
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
 delete from public.parties where company_id=any(fixture_companies) and id=any(expected);
 get diagnostics removed=row_count; if removed<>cardinality(expected) then raise exception 'Party delete count mismatch'; end if;
 delete from public.company_memberships where company_id=any(fixture_companies) and user_id=actor;
 get diagnostics removed=row_count; if removed<>cardinality(fixture_companies) then raise exception 'Membership delete count mismatch'; end if;
 delete from public.companies where ((id=fixture_companies[1] and code='P6C-S6-CONCURRENCY' and name='Slice 6 disposable concurrency'));
 get diagnostics removed=row_count; if removed<>cardinality(fixture_companies) then raise exception 'Company delete count mismatch'; end if;
 delete from public.profiles where user_id=actor;
 get diagnostics removed=row_count; if removed<>1 then raise exception 'Profile delete count mismatch'; end if;
 delete from auth.users where id=actor and email='p6c-s6-concurrency@example.test';
 get diagnostics removed=row_count; if removed<>1 then raise exception 'Auth delete count mismatch'; end if;
end $$;
commit;
