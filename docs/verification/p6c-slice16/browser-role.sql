-- Development fixture only. Replace the empty UUID and choose one documented role.
begin; select set_config('makeracc.fixture_user','',true); select set_config('makeracc.fixture_role','ACCOUNTING_ADMIN',true);
do $$ declare actor uuid:=nullif(current_setting('makeracc.fixture_user'),'')::uuid;n integer;begin
 if actor is null or not exists(select 1 from auth.users where id=actor and email='p6c-s16-browser@example.test') or not exists(select 1 from public.companies where id='86200000-0000-4000-8000-0000000000a1' and code='P6C-S16-BROWSER-A') then raise exception 'Exact fixture required'; end if;
 update public.company_memberships set role=current_setting('makeracc.fixture_role')::public.company_role where company_id='86200000-0000-4000-8000-0000000000a1' and user_id=actor;get diagnostics n=row_count;if n<>1 then raise exception 'Membership mismatch';end if;
end $$;commit;
