-- MakerACC-Development only; launch both writers concurrently.
begin;
do $$ begin
 if not exists(select 1 from auth.users where id='77100000-0000-4000-8000-000000000001' and email='p6c-s7-concurrency@example.test')
 or not exists(select 1 from public.companies where id='77100000-0000-4000-8000-0000000000a1' and code='P6C-S7-CONCURRENCY') then raise exception 'Concurrency fixture missing'; end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','77100000-0000-4000-8000-000000000001',true);
with changed as (update public.companies set legal_name='Editor 2' where id='77100000-0000-4000-8000-0000000000a1' and updated_at='2000-01-01T00:00:00.123456Z'::timestamptz returning id)
select set_config('makeracc.test_rows',count(*)::text,true) from changed;
select pg_sleep(4);
select current_setting('makeracc.test_rows')::integer as affected_rows;
commit;
