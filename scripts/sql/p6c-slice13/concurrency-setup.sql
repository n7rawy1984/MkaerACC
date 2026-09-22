-- Development only; existing synthetic actor, no Auth creation or profile mutation.
begin;
do $$ begin
 if not exists(select 1 from auth.users u join public.profiles p on p.user_id=u.id where u.id='7cf0bfff-6938-4beb-a0ff-0ed726867304' and u.email='maker-p2v-accountant_a-1787848792973-68f666@example.invalid' and p.status='ACTIVE') then raise exception 'Existing synthetic actor unavailable'; end if;
 if exists(select 1 from public.companies where id='83100000-0000-4000-8000-0000000000a1' or lower(btrim(code))='p6c-s13-concurrency') or exists(select 1 from public.parties where id='83100000-0000-4000-8000-0000000000b1') or exists(select 1 from public.company_settings where tenant_slug='p6c-s13-concurrency') then raise exception 'Fixture collision'; end if;
end $$;
insert into public.companies(id,code,name) values ('83100000-0000-4000-8000-0000000000a1','P6C-S13-CONCURRENCY','Slice 13 concurrency');
insert into public.company_settings(company_id,tenant_slug) values ('83100000-0000-4000-8000-0000000000a1','p6c-s13-concurrency');
insert into public.company_memberships(company_id,user_id,role) values ('83100000-0000-4000-8000-0000000000a1','7cf0bfff-6938-4beb-a0ff-0ed726867304','ACCOUNTING_ADMIN');
insert into public.parties(id,company_id,code,name,type,updated_at) values ('83100000-0000-4000-8000-0000000000b1','83100000-0000-4000-8000-0000000000a1','P1','Original','CUSTODIAN','2000-01-01T00:00:00.123456Z');
commit;
