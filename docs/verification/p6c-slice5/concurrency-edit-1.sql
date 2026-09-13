begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','75100000-0000-4000-8000-000000000001',true);
with changed as (update public.expense_categories set name='Editor 1' where company_id='75100000-0000-4000-8000-0000000000a1' and id='75100000-0000-4000-8000-0000000000f1' and updated_at='2000-01-01'::timestamptz returning id,name,updated_at) select set_config('makeracc.test_rows',count(*)::text,true) from changed;
select pg_sleep(4);
select current_setting('makeracc.test_rows')::integer as affected_rows;
commit;
