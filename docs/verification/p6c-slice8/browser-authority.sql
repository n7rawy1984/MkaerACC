-- Historical fixture reference. Development synthetic actor only; no credentials.
-- In an execution copy choose assignment, membership or profile and ACTIVE/INACTIVE.
begin;
select set_config('makeracc.fixture_user','',true);
select set_config('makeracc.fixture_target','assignment',true);
select set_config('makeracc.fixture_status','INACTIVE',true);
do $$ declare
 actor uuid:=nullif(current_setting('makeracc.fixture_user'),'')::uuid;
 target text:=current_setting('makeracc.fixture_target');
 next_status public.account_status:=current_setting('makeracc.fixture_status')::public.account_status;
 n integer;
begin
 if actor is null or not exists(select 1 from auth.users where id=actor and email='p6c-s8-browser@example.test')
 or not exists(select 1 from public.companies where id='78200000-0000-4000-8000-0000000000a1' and code='P6C-S8-BROWSER-A' and name='Slice 8 Alpha') then raise exception 'Exact fixture required'; end if;
 if target='assignment' then
 update public.project_assignments set status=next_status where id='78200000-0000-4000-8000-0000000000c1' and company_id='78200000-0000-4000-8000-0000000000a1' and project_id='78200000-0000-4000-8000-0000000000b1' and user_id=actor;
 elsif target='membership' then
 update public.company_memberships set status=next_status where company_id='78200000-0000-4000-8000-0000000000a1' and user_id=actor;
 elsif target='profile' then
 update public.profiles set status=next_status where user_id=actor;
 else raise exception 'Unsupported fixture target'; end if;
 get diagnostics n=row_count; if n<>1 then raise exception 'Authority manifest mismatch'; end if;
end $$;
commit;
