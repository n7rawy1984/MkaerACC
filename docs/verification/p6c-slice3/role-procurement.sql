-- Fixture/Auth cleanup complete. Retained documentation; see README.md for current status.
-- Later manual verification only. MakerACC-Development; not executed during setup.
begin;
do $guard$
declare n integer;
begin
  if (select count(*) from auth.users where id='dc9ad1f5-804d-4f33-ab65-5e796fec0616' and email='p6c-slice3-user@example.test') <> 1
    or (select count(*) from auth.users where id='dc9ad1f5-804d-4f33-ab65-5e796fec0616' or lower(email)='p6c-slice3-user@example.test') <> 1
    or (select count(*) from public.profiles where user_id='dc9ad1f5-804d-4f33-ab65-5e796fec0616' and email_snapshot='p6c-slice3-user@example.test' and status='ACTIVE') <> 1 then
    raise exception 'Synthetic identity/profile mismatch';
  end if;
  perform id from public.companies where id in ('73000000-0000-4000-8000-0000000000a1','73000000-0000-4000-8000-0000000000a2') for update;
  if (select count(*) from public.companies where (id,code,name) in (
    ('73000000-0000-4000-8000-0000000000a1'::uuid,'P6C-S3-ALPHA','P6C Slice 3 Alpha'),
    ('73000000-0000-4000-8000-0000000000a2'::uuid,'P6C-S3-BETA','P6C Slice 3 Beta'))) <> 2 then raise exception 'Fixture Company identity mismatch'; end if;
  if exists (select 1 from public.company_memberships where user_id='dc9ad1f5-804d-4f33-ab65-5e796fec0616' and id not in ('73000000-0000-4000-8000-0000000000b1','73000000-0000-4000-8000-0000000000b2'))
    or exists (select 1 from public.project_assignments where user_id='dc9ad1f5-804d-4f33-ab65-5e796fec0616' and id<>'73000000-0000-4000-8000-0000000000d1') then raise exception 'Unrelated user membership/assignment'; end if;
  update public.company_memberships set role='PROCUREMENT' where id='73000000-0000-4000-8000-0000000000b1' and company_id='73000000-0000-4000-8000-0000000000a1' and user_id='dc9ad1f5-804d-4f33-ab65-5e796fec0616' and status='ACTIVE';
  get diagnostics n = row_count;
  if n<>1 then raise exception 'Expected exactly one active Alpha membership'; end if;
end;
$guard$;
commit;
