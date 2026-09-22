begin read only;
select name, updated_by='7cf0bfff-6938-4beb-a0ff-0ed726867304'::uuid as correct_actor,updated_at>'2000-01-01T00:00:00.123456Z' as advanced_token from public.parties where company_id='83100000-0000-4000-8000-0000000000a1' and id='83100000-0000-4000-8000-0000000000b1';
commit;
