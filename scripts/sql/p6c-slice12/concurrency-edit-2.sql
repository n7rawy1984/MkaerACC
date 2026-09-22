begin;
do $$ begin if not exists(select 1 from public.companies where id='82100000-0000-4000-8000-0000000000a1' and code='P6C-S12-CONCURRENCY') then raise exception 'Fixture missing'; end if; end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','7cf0bfff-6938-4beb-a0ff-0ed726867304',true);
with changed as (update public.parties set name='Editor 2' where company_id='82100000-0000-4000-8000-0000000000a1' and id='82100000-0000-4000-8000-0000000000b1' and updated_at='2000-01-01T00:00:00.123456Z' returning id)
select set_config('makeracc.test_rows',count(*)::text,true) from changed;
select pg_sleep(4);
select current_setting('makeracc.test_rows')::integer as affected_rows;
commit;
