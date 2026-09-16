-- PREPARED / NOT EXECUTED. MakerACC-Development only; NOT a migration.
begin;
do $$ begin
 if not exists(select 1 from auth.users where id='76100000-0000-4000-8000-000000000001' and email='p6c-s6-concurrency@example.test')
 or not exists(select 1 from public.companies where id='76100000-0000-4000-8000-0000000000a1' and code='P6C-S6-CONCURRENCY') then raise exception 'Concurrency fixture missing'; end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','76100000-0000-4000-8000-000000000001',true);
with changed as (update public.parties set name='Editor 2' where company_id='76100000-0000-4000-8000-0000000000a1' and id='76100000-0000-4000-8000-0000000000f1' and type='SUPPLIER' and updated_at='2000-01-01T00:00:00Z'::timestamptz returning id) select set_config('makeracc.test_rows',count(*)::text,true) from changed;
select current_setting('makeracc.test_rows')::integer as affected_rows;
commit;
