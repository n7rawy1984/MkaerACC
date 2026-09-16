-- PREPARED / NOT EXECUTED. MakerACC-Development only; NOT a migration.
-- Controlled role change only for the confirmed synthetic Alpha membership.
begin;
select set_config('makeracc.fixture_user','',true);
select set_config('makeracc.fixture_role','',true);
do $$ declare actor uuid; next_role public.company_role; n integer; begin
 actor:=nullif(current_setting('makeracc.fixture_user',true),'')::uuid;
 next_role:=nullif(current_setting('makeracc.fixture_role',true),'')::public.company_role;
 if actor is null or next_role is null or not exists(select 1 from auth.users where id=actor and email='p6c-slice6-user@example.test')
 or not exists(select 1 from public.companies where id='76200000-0000-4000-8000-0000000000a1' and code='P6C-S6-BROWSER-A') then raise exception 'Exact fixture identity and role required'; end if;
 update public.company_memberships set role=next_role where company_id='76200000-0000-4000-8000-0000000000a1' and user_id=actor and status='ACTIVE';
 get diagnostics n=row_count; if n<>1 then raise exception 'Membership count mismatch'; end if;
end $$;
commit;
