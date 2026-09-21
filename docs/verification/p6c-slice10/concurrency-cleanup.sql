-- Exact fixture only; leave the existing Auth identity and profile untouched.
begin;
do $$ declare t record; n bigint; begin
 if (select count(*) from public.companies where id='80100000-0000-4000-8000-0000000000a1' and code='P6C-S10-CONCURRENCY' and name='Slice 10 concurrency')<>1 then raise exception 'Company manifest mismatch'; end if;
 if (select count(*) from public.treasury_accounts where company_id='80100000-0000-4000-8000-0000000000a1')<>1 or not exists(select 1 from public.treasury_accounts where id='80100000-0000-4000-8000-0000000000b1' and company_id='80100000-0000-4000-8000-0000000000a1' and code='P1') then raise exception 'Account manifest mismatch'; end if;
 if (select count(*) from public.company_memberships where company_id='80100000-0000-4000-8000-0000000000a1')<>1 or not exists(select 1 from public.company_memberships where company_id='80100000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304') then raise exception 'Membership mismatch'; end if;
 if (select count(*) from public.company_settings where company_id='80100000-0000-4000-8000-0000000000a1' and tenant_slug='p6c-s10-concurrency')<>1 then raise exception 'Settings mismatch'; end if;
 if (select count(*) from public.accounts where company_id='80100000-0000-4000-8000-0000000000a1')<>1 or not exists(select 1 from public.accounts where id='80100000-0000-4000-8000-0000000000d1' and company_id='80100000-0000-4000-8000-0000000000a1' and code='GL1') then raise exception 'GL manifest mismatch'; end if;
 for t in select table_name from information_schema.columns where table_schema='public' and column_name='company_id' and table_name not in ('company_settings','company_memberships','treasury_accounts','accounts') loop
 execute format('select count(*) from public.%I where company_id=$1',t.table_name) into n using '80100000-0000-4000-8000-0000000000a1'::uuid;
 if n<>0 then raise exception 'Unexpected dependency %',t.table_name; end if;
 end loop;
end $$;
delete from public.treasury_accounts where company_id='80100000-0000-4000-8000-0000000000a1' and id='80100000-0000-4000-8000-0000000000b1';
delete from public.accounts where company_id='80100000-0000-4000-8000-0000000000a1' and id='80100000-0000-4000-8000-0000000000d1';
delete from public.company_memberships where company_id='80100000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304';
delete from public.companies where id='80100000-0000-4000-8000-0000000000a1' and code='P6C-S10-CONCURRENCY';
commit;
