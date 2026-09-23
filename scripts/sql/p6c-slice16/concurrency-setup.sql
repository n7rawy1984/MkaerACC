begin;
do $$ begin if exists(select 1 from public.companies where id='86100000-0000-4000-8000-0000000000a1') then raise exception 'Fixture collision'; end if; end $$;
insert into public.companies(id,code,name) values ('86100000-0000-4000-8000-0000000000a1','P6C-S16-CONCURRENCY','Slice 16 concurrency');
insert into public.company_settings(company_id,tenant_slug) values ('86100000-0000-4000-8000-0000000000a1','p6c-s16-concurrency');
insert into public.company_memberships(company_id,user_id,role) values ('86100000-0000-4000-8000-0000000000a1','7cf0bfff-6938-4beb-a0ff-0ed726867304','ACCOUNTING_ADMIN');
insert into public.projects(id,company_id,code,name,status) values ('86100000-0000-4000-8000-0000000000c1','86100000-0000-4000-8000-0000000000a1','P1','Project','ACTIVE');
insert into public.parties(id,company_id,code,name,type) values ('86100000-0000-4000-8000-0000000000b1','86100000-0000-4000-8000-0000000000a1','SC1','Subcontractor','SUBCONTRACTOR');
insert into public.subcontracts(id,company_id,project_id,subcontractor_id,contract_number,scope_of_work,original_contract_value_minor,retention_bps,updated_at) values ('86100000-0000-4000-8000-0000000000d1','86100000-0000-4000-8000-0000000000a1','86100000-0000-4000-8000-0000000000c1','86100000-0000-4000-8000-0000000000b1','0001','Original',1,0,'2000-01-01T00:00:00.123456Z'); commit;
