-- MakerACC-Development only. Existing synthetic masters/actor; every change rolls back.
begin;
do $$
declare
  f record; d1 record; d2 record; c1 record; c2 record; payment record; replay record; second_payment record; reversed record; reverse_replay record;
  original_project_status public.project_status; original_subcontract_status public.subcontract_status; original_party_status public.account_status; original_role public.company_role;
  previous_work bigint; p1 bigint; p2 bigint; remaining1 bigint; payment_key uuid:=gen_random_uuid(); reverse_key uuid:=gen_random_uuid(); foreign_company uuid; test_role public.company_role;
begin
  select m.user_id,m.role,c.id company_id,s.id subcontract_id,s.project_id,s.subcontractor_id,t.id treasury_id,pr.status project_status,s.status subcontract_status,p.status party_status
  into f from public.company_memberships m
  join public.profiles pf on pf.user_id=m.user_id and pf.status='ACTIVE'
  join public.companies c on c.id=m.company_id and c.status='ACTIVE'
  join public.subcontracts s on s.company_id=c.id and s.status='ACTIVE'
  join public.projects pr on pr.company_id=c.id and pr.id=s.project_id and pr.status<>'CLOSED'
  join public.parties p on p.company_id=c.id and p.id=s.subcontractor_id and p.type='SUBCONTRACTOR'
  join public.treasury_accounts t on t.company_id=c.id and t.status='ACTIVE' and (t.project_id is null or t.project_id=s.project_id)
  join public.accounts ta on ta.company_id=c.id and ta.id=t.gl_account_id and ta.status='ACTIVE' and ta.account_type='ASSET'
  where m.status='ACTIVE' and exists(select 1 from public.accounts a where a.company_id=c.id and a.status='ACTIVE' and a.system_key in ('PROJECT_COST_SUBCONTRACTORS','SUBCONTRACTOR_RETENTION_PAYABLE','SUBCONTRACTOR_PAYABLE') group by a.company_id having count(distinct a.system_key)=3)
    and (s.original_contract_value_minor::numeric+s.approved_variations_minor::numeric-coalesce((select sum(sc.gross_certified_minor) from public.subcontractor_certificates sc where sc.company_id=c.id and sc.subcontract_id=s.id and sc.status='POSTED'),0))>=3000
  order by c.id,m.user_id,s.id,t.id limit 1;
  if f.user_id is null then raise exception 'No synthetic Subcontractor Payment fixture'; end if;
  original_role:=f.role; original_project_status:=f.project_status; original_subcontract_status:=f.subcontract_status; original_party_status:=f.party_status;
  select coalesce(max(work_value_to_date_minor),0) into previous_work from public.subcontractor_certificates where company_id=f.company_id and subcontract_id=f.subcontract_id and status='POSTED';
  update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id=f.company_id and user_id=f.user_id;
  perform set_config('request.jwt.claim.sub',f.user_id::text,true); set local role authenticated;
  select * into d1 from public.create_subcontractor_certificate_draft(f.company_id,current_date,f.subcontract_id,'P6D-PAY-1-'||gen_random_uuid()::text,previous_work+1000,0,0,'ZERO',null,false,null,null,'[]',null);
  select * into c1 from public.approve_post_subcontractor_certificate(f.company_id,d1.subcontractor_certificate_id,gen_random_uuid());
  select * into d2 from public.create_subcontractor_certificate_draft(f.company_id,current_date,f.subcontract_id,'P6D-PAY-2-'||gen_random_uuid()::text,previous_work+2000,0,0,'ZERO',null,false,null,null,'[]',null);
  select * into c2 from public.approve_post_subcontractor_certificate(f.company_id,d2.subcontractor_certificate_id,gen_random_uuid()); reset role;
  select payable_amount_minor into p1 from public.subcontractor_certificates where id=d1.subcontractor_certificate_id;
  select payable_amount_minor into p2 from public.subcontractor_certificates where id=d2.subcontractor_certificate_id;
  if least(p1,p2)<2 then raise exception 'Certificate payable fixture too small'; end if;

  -- Liabilities remain payable after masters close or become inactive.
  update public.projects set status='CLOSED' where id=f.project_id; update public.subcontracts set status='CLOSED' where id=f.subcontract_id; update public.parties set status='INACTIVE' where id=f.subcontractor_id;
  update public.company_memberships set role='ACCOUNTANT' where company_id=f.company_id and user_id=f.user_id; set local role authenticated;
  select * into payment from public.post_subcontractor_payment(f.company_id,current_date,f.subcontract_id,f.treasury_id,2,'TRANSFER','P6D payment','partial multi',jsonb_build_array(jsonb_build_object('certificate_id',d1.subcontractor_certificate_id,'amount_minor',1),jsonb_build_object('certificate_id',d2.subcontractor_certificate_id,'amount_minor',1)),payment_key);
  select * into replay from public.post_subcontractor_payment(f.company_id,current_date,f.subcontract_id,f.treasury_id,2,'TRANSFER','P6D payment','partial multi',jsonb_build_array(jsonb_build_object('certificate_id',d2.subcontractor_certificate_id,'amount_minor',1),jsonb_build_object('certificate_id',d1.subcontractor_certificate_id,'amount_minor',1)),payment_key); reset role;
  if payment.replayed or not replay.replayed or payment.subcontractor_payment_id<>replay.subcontractor_payment_id or payment.journal_entry_id<>replay.journal_entry_id then raise exception 'Subcontractor Payment replay mismatch'; end if;
  if not exists(select 1 from public.subcontractor_payments p where p.id=payment.subcontractor_payment_id and p.project_id=f.project_id and p.subcontractor_id=f.subcontractor_id and p.subcontract_id=f.subcontract_id and p.total_amount_minor=2 and p.status='POSTED') or (select count(*) from public.subcontractor_payment_allocations where subcontractor_payment_id=payment.subcontractor_payment_id)<>2 then raise exception 'Payment document/allocation mismatch'; end if;
  if (select sum(debit_minor-credit_minor) from public.journal_lines where journal_entry_id=payment.journal_entry_id)<>0
    or not exists(select 1 from public.journal_lines l join public.accounts a on a.id=l.account_id where l.journal_entry_id=payment.journal_entry_id and a.system_key='SUBCONTRACTOR_PAYABLE' and l.debit_minor=2 and l.project_id=f.project_id and l.party_id=f.subcontractor_id and l.subcontract_id=f.subcontract_id)
    or not exists(select 1 from public.journal_lines l where l.journal_entry_id=payment.journal_entry_id and l.credit_minor=2 and l.treasury_account_id=f.treasury_id and l.project_id=f.project_id and l.subcontract_id=f.subcontract_id)
    or exists(select 1 from public.journal_lines l join public.accounts a on a.id=l.account_id where l.journal_entry_id=payment.journal_entry_id and a.system_key in ('PROJECT_COST_SUBCONTRACTORS','INPUT_VAT','SUBCONTRACTOR_RETENTION_PAYABLE','SUBCONTRACTOR_ADVANCE')) then raise exception 'Payment journal mismatch or forbidden recreation'; end if;
  set local role authenticated; begin perform public.post_subcontractor_payment(f.company_id,current_date,f.subcontract_id,f.treasury_id,p1,'TRANSFER',null,null,jsonb_build_array(jsonb_build_object('certificate_id',d1.subcontractor_certificate_id,'amount_minor',p1)),gen_random_uuid()); raise exception 'Over-allocation allowed'; exception when check_violation then null; end; reset role;

  -- ACCOUNTING_ADMIN posting completes one Certificate; active payment blocks Certificate reversal.
  remaining1:=p1-1; update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id=f.company_id and user_id=f.user_id; set local role authenticated;
  select * into second_payment from public.post_subcontractor_payment(f.company_id,current_date,f.subcontract_id,f.treasury_id,remaining1,'CHEQUE',null,null,jsonb_build_array(jsonb_build_object('certificate_id',d1.subcontractor_certificate_id,'amount_minor',remaining1)),gen_random_uuid());
  begin perform public.reverse_subcontractor_certificate(f.company_id,d1.subcontractor_certificate_id,current_date,'blocked',gen_random_uuid()); raise exception 'Live payment did not block Certificate reversal'; exception when check_violation then null; end;
  select * into reversed from public.reverse_subcontractor_payment(f.company_id,second_payment.subcontractor_payment_id,current_date,'restore outstanding',reverse_key);
  select * into reverse_replay from public.reverse_subcontractor_payment(f.company_id,second_payment.subcontractor_payment_id,current_date,'restore outstanding',reverse_key); reset role;
  if reversed.replayed or not reverse_replay.replayed or reversed.reversal_journal_entry_id<>reverse_replay.reversal_journal_entry_id then raise exception 'Reversal replay mismatch'; end if;
  if exists(select 1 from public.journal_lines o full join public.journal_lines r on r.journal_entry_id=reversed.reversal_journal_entry_id and r.line_number=o.line_number where o.journal_entry_id=second_payment.journal_entry_id and (r.account_id<>o.account_id or r.debit_minor<>o.credit_minor or r.credit_minor<>o.debit_minor or r.project_id is distinct from o.project_id or r.party_id is distinct from o.party_id or r.subcontract_id is distinct from o.subcontract_id or r.treasury_account_id is distinct from o.treasury_account_id)) then raise exception 'Payment reversal is not exact'; end if;
  if (select payable_amount_minor-coalesce(sum(a.allocated_amount_minor) filter(where p.status='POSTED'),0) from public.subcontractor_certificates c left join public.subcontractor_payment_allocations a on a.subcontractor_certificate_id=c.id left join public.subcontractor_payments p on p.id=a.subcontractor_payment_id where c.id=d1.subcontractor_certificate_id group by c.payable_amount_minor)<>p1-1 then raise exception 'Reversal did not restore outstanding'; end if;

  -- Read/RPC roles, inactive membership, and tenant isolation fail closed.
  foreach test_role in array enum_range(null::public.company_role) loop update public.company_memberships set role=test_role where company_id=f.company_id and user_id=f.user_id; set local role authenticated;
    if test_role in ('ACCOUNTING_ADMIN','ACCOUNTANT','MANAGEMENT_VIEWER') then if not exists(select 1 from public.subcontractor_payments where id=payment.subcontractor_payment_id) then raise exception 'Allowed read failed: %',test_role; end if; elsif exists(select 1 from public.subcontractor_payments where id=payment.subcontractor_payment_id) then raise exception 'Denied read: %',test_role; end if;
    if test_role not in ('ACCOUNTING_ADMIN','ACCOUNTANT') then begin perform public.post_subcontractor_payment(f.company_id,current_date,f.subcontract_id,f.treasury_id,1,'TRANSFER',null,null,jsonb_build_array(jsonb_build_object('certificate_id',d2.subcontractor_certificate_id,'amount_minor',1)),gen_random_uuid()); raise exception 'Denied post: %',test_role; exception when insufficient_privilege then null; end; end if;
    if test_role<>'ACCOUNTING_ADMIN' then begin perform public.reverse_subcontractor_payment(f.company_id,payment.subcontractor_payment_id,current_date,'denied',gen_random_uuid()); raise exception 'Denied reversal: %',test_role; exception when insufficient_privilege then null; end; end if; reset role;
  end loop;
  update public.company_memberships set role='ACCOUNTING_ADMIN',status='INACTIVE' where company_id=f.company_id and user_id=f.user_id; set local role authenticated; begin perform public.post_subcontractor_payment(f.company_id,current_date,f.subcontract_id,f.treasury_id,1,'TRANSFER',null,null,jsonb_build_array(jsonb_build_object('certificate_id',d2.subcontractor_certificate_id,'amount_minor',1)),gen_random_uuid()); raise exception 'Inactive member posted'; exception when insufficient_privilege then null; end; reset role;
  update public.company_memberships set status='ACTIVE' where company_id=f.company_id and user_id=f.user_id;
  select c.id into foreign_company from public.companies c where c.id<>f.company_id and not exists(select 1 from public.company_memberships m where m.company_id=c.id and m.user_id=f.user_id and m.status='ACTIVE') limit 1; set local role authenticated; begin perform public.post_subcontractor_payment(foreign_company,current_date,f.subcontract_id,f.treasury_id,1,'TRANSFER',null,null,jsonb_build_array(jsonb_build_object('certificate_id',d2.subcontractor_certificate_id,'amount_minor',1)),gen_random_uuid()); raise exception 'Cross-tenant post'; exception when insufficient_privilege then null; end; reset role;

  update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id=f.company_id and user_id=f.user_id; set local role authenticated; perform public.reverse_subcontractor_payment(f.company_id,payment.subcontractor_payment_id,current_date,'remove dependency',gen_random_uuid()); perform public.reverse_subcontractor_certificate(f.company_id,d1.subcontractor_certificate_id,current_date,'dependency removed',gen_random_uuid()); reset role;
  update public.projects set status=original_project_status where id=f.project_id; update public.subcontracts set status=original_subcontract_status where id=f.subcontract_id; update public.parties set status=original_party_status where id=f.subcontractor_id; update public.company_memberships set role=original_role where company_id=f.company_id and user_id=f.user_id;
  perform set_config('makeracc.p6d_subcontractor_payment_result',jsonb_build_object('exact_bigint',true,'partial_multi_full',true,'accountant_admin_post',true,'viewer_read',true,'denied_system_inactive_cross_tenant',true,'payable_treasury_only',true,'closed_inactive_settlement',true,'over_allocation',true,'idempotency',true,'certificate_guard',true,'exact_reversal_restore',true)::text,true);
end $$;
set constraints all immediate;
select current_setting('makeracc.p6d_subcontractor_payment_result')::jsonb result;
rollback;
