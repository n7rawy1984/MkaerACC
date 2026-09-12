-- Fixture/Auth cleanup complete. Retained documentation; see README.md for current status.
begin read only;
do $guard$
begin
  if (select count(*) from auth.users where id='dc9ad1f5-804d-4f33-ab65-5e796fec0616' and email='p6c-slice3-user@example.test') <> 1
    or (select count(*) from auth.users where id='dc9ad1f5-804d-4f33-ab65-5e796fec0616' or lower(email)='p6c-slice3-user@example.test') <> 1
    or (select count(*) from public.profiles where user_id='dc9ad1f5-804d-4f33-ab65-5e796fec0616' and email_snapshot='p6c-slice3-user@example.test' and status='ACTIVE') <> 1 then
    raise exception 'Synthetic identity/profile mismatch';
  end if;
  if (select count(*) from (
select id from public.companies where id::text like '73000000-0000-4000-8000-%' or lower(code) like 'p6c-s3-%' or name like 'P6C Slice 3%'
union all select company_id from public.company_settings where company_id::text like '73000000-0000-4000-8000-%' or tenant_slug like 'p6c-s3-%'
union all select id from public.company_memberships where id::text like '73000000-0000-4000-8000-%' or user_id='dc9ad1f5-804d-4f33-ab65-5e796fec0616'
union all select id from public.projects where id::text like '73000000-0000-4000-8000-%' or lower(btrim(code)) like 'p6c-s3-%'
union all select id from public.project_assignments where id::text like '73000000-0000-4000-8000-%' or user_id='dc9ad1f5-804d-4f33-ab65-5e796fec0616'
union all select id from public.accounts where id::text like '73000000-0000-4000-8000-%' or lower(btrim(code)) like 'p6c-s3-%'
union all select id from public.treasury_accounts where id::text like '73000000-0000-4000-8000-%' or lower(btrim(code)) like 'p6c-s3-%'
) x) <> 0 then raise exception 'Fixture ID/code/slug/user collision'; end if;
end;
$guard$;
select 'identity ACTIVE; UUID/code/slug/user collisions = 0' as preflight;
commit;
