-- Controlled synthetic fixture only. Choose one approved role in execution copy.
begin;
select set_config('makeracc.fixture_user','',true);
select set_config('makeracc.fixture_role','ACCOUNTING_ADMIN',true);
do $$ declare actor uuid:=nullif(current_setting('makeracc.fixture_user'),'')::uuid; n integer; begin
 if actor is null or not exists(select 1 from auth.users where id=actor and email='p6c-s8-browser@example.test')
 or not exists(select 1 from public.companies where id='78200000-0000-4000-8000-0000000000a1' and code='P6C-S8-BROWSER-A' and name='Slice 8 Alpha') then raise exception 'Exact fixture missing'; end if;
 update public.company_memberships set role=current_setting('makeracc.fixture_role')::public.company_role
 where company_id='78200000-0000-4000-8000-0000000000a1' and user_id=actor;
 get diagnostics n=row_count; if n<>1 then raise exception 'Membership manifest mismatch'; end if;
end $$;
commit;
