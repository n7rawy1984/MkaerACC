-- Later manual verification only. MakerACC-Development.
begin;
do $guard$
declare n integer;
begin
  if (select count(*) from auth.users where id='74e36291-172a-44e7-95be-f6c1283c315b' and email='p6c-slice2-user@example.test') <> 1
    or (select count(*) from auth.users where id='74e36291-172a-44e7-95be-f6c1283c315b' or lower(email)='p6c-slice2-user@example.test') <> 1
    or (select count(*) from public.profiles where user_id='74e36291-172a-44e7-95be-f6c1283c315b' and email_snapshot='p6c-slice2-user@example.test' and status='ACTIVE') <> 1 then
    raise exception 'Synthetic identity/profile mismatch';
  end if;
  perform id from public.companies where id in ('72000000-0000-4000-8000-0000000000a1','72000000-0000-4000-8000-0000000000a2') for update;
  if (select count(*) from public.companies where (id,code,name) in (
    ('72000000-0000-4000-8000-0000000000a1'::uuid,'P6C-S2-ALPHA','P6C Slice 2 Alpha'),
    ('72000000-0000-4000-8000-0000000000a2'::uuid,'P6C-S2-BETA','P6C Slice 2 Beta'))) <> 2 then
    raise exception 'Fixture Company identity mismatch';
  end if;
  update public.company_memberships set role='PROJECT_MANAGER'
    where id='72000000-0000-4000-8000-0000000000b1' and company_id='72000000-0000-4000-8000-0000000000a1' and user_id='74e36291-172a-44e7-95be-f6c1283c315b' and status='ACTIVE';
  get diagnostics n = row_count;
  if n <> 1 then raise exception 'Expected exactly one active Alpha membership'; end if;
end;
$guard$;
commit;
