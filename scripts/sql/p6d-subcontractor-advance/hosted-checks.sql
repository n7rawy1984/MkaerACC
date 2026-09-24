-- MakerACC-Development only. Existing synthetic masters/actor; every change rolls back.
begin;
do $$
declare
  f record; posted record; replay record; large_post record; reversed record; reverse_replay record;
  dependency_advance record; accountant_advance record; cert_draft record; test_role public.company_role; foreign_company uuid;
  post_key uuid:=gen_random_uuid(); reverse_key uuid:=gen_random_uuid(); previous_work bigint;
begin
  select m.user_id,m.role original_role,c.id company_id,s.id subcontract_id,s.project_id,s.subcontractor_id,
    t.id treasury_id,t.gl_account_id treasury_gl_id
  into f
  from public.company_memberships m join public.profiles pf on pf.user_id=m.user_id and pf.status='ACTIVE'
  join public.companies c on c.id=m.company_id and c.status='ACTIVE'
  join public.subcontracts s on s.company_id=c.id and s.status='ACTIVE'
  join public.projects pr on pr.company_id=c.id and pr.id=s.project_id and pr.status<>'CLOSED'
  join public.parties p on p.company_id=c.id and p.id=s.subcontractor_id and p.type='SUBCONTRACTOR' and p.status='ACTIVE'
  join public.treasury_accounts t on t.company_id=c.id and t.status='ACTIVE' and (t.project_id is null or t.project_id=s.project_id)
  join public.accounts ta on ta.company_id=c.id and ta.id=t.gl_account_id and ta.status='ACTIVE' and ta.account_type='ASSET'
  where m.status='ACTIVE'
    and (s.original_contract_value_minor::numeric+s.approved_variations_minor::numeric-
      coalesce((select sum(sc.gross_certified_minor) from public.subcontractor_certificates sc where sc.company_id=c.id and sc.subcontract_id=s.id and sc.status='POSTED'),0))>=10000
    and private.subcontractor_advance_balance_minor(c.id,s.id)=0
    and exists(select 1 from public.accounts a where a.company_id=c.id and a.status='ACTIVE' and a.system_key in
      ('SUBCONTRACTOR_ADVANCE','PROJECT_COST_SUBCONTRACTORS','SUBCONTRACTOR_RETENTION_PAYABLE','SUBCONTRACTOR_PAYABLE')
      group by a.company_id having count(distinct a.system_key)=4)
  order by c.id,m.user_id,s.id,t.id limit 1;
  if f.user_id is null then raise exception 'No synthetic P6D Subcontractor Advance fixture'; end if;
  update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id=f.company_id and user_id=f.user_id;
  perform set_config('request.jwt.claim.sub',f.user_id::text,true); set local role authenticated;
  select * into posted from public.post_subcontractor_advance(f.company_id,current_date,f.subcontract_id,f.treasury_id,10000,'TRANSFER','P6D rollback','focused',post_key);
  select * into replay from public.post_subcontractor_advance(f.company_id,current_date,f.subcontract_id,f.treasury_id,10000,'TRANSFER','P6D rollback','focused',post_key);
  if posted.replayed or not replay.replayed or posted.subcontractor_advance_id<>replay.subcontractor_advance_id or posted.journal_entry_id<>replay.journal_entry_id then raise exception 'Advance replay mismatch'; end if;
  begin perform public.post_subcontractor_advance(f.company_id,current_date,f.subcontract_id,f.treasury_id,10001,'TRANSFER','P6D rollback','focused',post_key); raise exception 'Changed-key replay accepted'; exception when unique_violation then null; end;
  select * into large_post from public.post_subcontractor_advance(f.company_id,current_date,f.subcontract_id,f.treasury_id,9000000000000000,'CHEQUE',null,null,gen_random_uuid()); reset role;
  if not exists(select 1 from public.subcontractor_advances a where a.id=posted.subcontractor_advance_id and a.company_id=f.company_id and a.project_id=f.project_id and a.subcontractor_id=f.subcontractor_id and a.subcontract_id=f.subcontract_id and a.treasury_account_id=f.treasury_id and a.amount_minor=10000 and a.status='POSTED' and a.payment_method='TRANSFER')
    or not exists(select 1 from public.subcontractor_advances a where a.id=large_post.subcontractor_advance_id and a.amount_minor=9000000000000000) then raise exception 'Advance document/exact amount mismatch'; end if;
  if (select count(*) from public.journal_lines where journal_entry_id=posted.journal_entry_id)<>2
    or not exists(select 1 from public.journal_lines l join public.accounts a on a.id=l.account_id where l.journal_entry_id=posted.journal_entry_id and a.system_key='SUBCONTRACTOR_ADVANCE' and l.debit_minor=10000 and l.credit_minor=0 and l.project_id=f.project_id and l.party_id=f.subcontractor_id and l.subcontract_id=f.subcontract_id and l.treasury_account_id is null)
    or not exists(select 1 from public.journal_lines l where l.journal_entry_id=posted.journal_entry_id and l.account_id=f.treasury_gl_id and l.credit_minor=10000 and l.debit_minor=0 and l.project_id=f.project_id and l.party_id is null and l.subcontract_id=f.subcontract_id and l.treasury_account_id=f.treasury_id)
    or exists(select 1 from public.journal_lines l join public.accounts a on a.id=l.account_id where l.journal_entry_id=posted.journal_entry_id and a.system_key in ('PROJECT_COST','PROJECT_COST_SUBCONTRACTORS','INPUT_VAT','SUBCONTRACTOR_RETENTION_PAYABLE','SUBCONTRACTOR_PAYABLE'))
    or (select sum(debit_minor-credit_minor) from public.journal_lines where journal_entry_id=posted.journal_entry_id)<>0 then raise exception 'Advance journal shape/side effect mismatch'; end if;

  update public.subcontracts set status='COMPLETED' where id=f.subcontract_id; set local role authenticated;
  begin perform public.post_subcontractor_advance(f.company_id,current_date,f.subcontract_id,f.treasury_id,100,'OTHER',null,null,gen_random_uuid()); raise exception 'COMPLETED Subcontract funded'; exception when check_violation then null; end; reset role;
  update public.subcontracts set status='ACTIVE' where id=f.subcontract_id; update public.parties set status='INACTIVE' where id=f.subcontractor_id; set local role authenticated;
  begin perform public.post_subcontractor_advance(f.company_id,current_date,f.subcontract_id,f.treasury_id,100,'OTHER',null,null,gen_random_uuid()); raise exception 'Inactive Subcontractor funded'; exception when check_violation then null; end; reset role;
  update public.parties set status='ACTIVE' where id=f.subcontractor_id; update public.treasury_accounts set status='INACTIVE' where id=f.treasury_id; set local role authenticated;
  begin perform public.post_subcontractor_advance(f.company_id,current_date,f.subcontract_id,f.treasury_id,100,'OTHER',null,null,gen_random_uuid()); raise exception 'Inactive Treasury funded'; exception when check_violation then null; end; reset role;
  update public.treasury_accounts set status='ACTIVE' where id=f.treasury_id;

  foreach test_role in array enum_range(null::public.company_role) loop
    update public.company_memberships set role=test_role where company_id=f.company_id and user_id=f.user_id; set local role authenticated;
    if test_role in ('ACCOUNTING_ADMIN','ACCOUNTANT','MANAGEMENT_VIEWER') then if not exists(select 1 from public.subcontractor_advances where id=posted.subcontractor_advance_id) then raise exception 'Allowed read failed: %',test_role; end if;
    elsif exists(select 1 from public.subcontractor_advances where id=posted.subcontractor_advance_id) then raise exception 'Denied read succeeded: %',test_role; end if;
    if test_role='ACCOUNTANT' then select * into accountant_advance from public.post_subcontractor_advance(f.company_id,current_date,f.subcontract_id,f.treasury_id,100,'OTHER',null,null,gen_random_uuid());
    elsif test_role<>'ACCOUNTING_ADMIN' then begin perform public.post_subcontractor_advance(f.company_id,current_date,f.subcontract_id,f.treasury_id,100,'OTHER',null,null,gen_random_uuid()); raise exception 'Denied post succeeded: %',test_role; exception when insufficient_privilege then null; end; end if;
    if test_role<>'ACCOUNTING_ADMIN' then begin perform public.reverse_subcontractor_advance(f.company_id,posted.subcontractor_advance_id,current_date,'Denied',gen_random_uuid()); raise exception 'Denied reversal succeeded: %',test_role; exception when insufficient_privilege then null; end; end if;
    reset role;
  end loop;
  update public.company_memberships set role='ACCOUNTING_ADMIN',status='INACTIVE' where company_id=f.company_id and user_id=f.user_id; set local role authenticated;
  begin perform public.post_subcontractor_advance(f.company_id,current_date,f.subcontract_id,f.treasury_id,100,'OTHER',null,null,gen_random_uuid()); raise exception 'Inactive membership posted'; exception when insufficient_privilege then null; end; reset role;
  update public.company_memberships set status='ACTIVE' where company_id=f.company_id and user_id=f.user_id;
  select c.id into foreign_company from public.companies c where c.id<>f.company_id and not exists(select 1 from public.company_memberships m where m.company_id=c.id and m.user_id=f.user_id and m.status='ACTIVE') limit 1; set local role authenticated;
  begin perform public.post_subcontractor_advance(foreign_company,current_date,f.subcontract_id,f.treasury_id,100,'OTHER',null,null,gen_random_uuid()); raise exception 'Cross-tenant post succeeded'; exception when insufficient_privilege then null; end;

  select * into reversed from public.reverse_subcontractor_advance(f.company_id,posted.subcontractor_advance_id,current_date,'Focused exact reversal',reverse_key);
  select * into reverse_replay from public.reverse_subcontractor_advance(f.company_id,posted.subcontractor_advance_id,current_date,'Focused exact reversal',reverse_key); reset role;
  if reversed.replayed or not reverse_replay.replayed or reversed.reversal_journal_entry_id<>reverse_replay.reversal_journal_entry_id
    or not exists(select 1 from public.subcontractor_advances where id=posted.subcontractor_advance_id and status='REVERSED' and reversal_journal_entry_id=reversed.reversal_journal_entry_id)
    or exists(select 1 from public.journal_lines o full join public.journal_lines r on r.journal_entry_id=reversed.reversal_journal_entry_id and r.line_number=o.line_number where o.journal_entry_id=posted.journal_entry_id and (r.account_id<>o.account_id or r.debit_minor<>o.credit_minor or r.credit_minor<>o.debit_minor or r.project_id is distinct from o.project_id or r.party_id is distinct from o.party_id or r.subcontract_id is distinct from o.subcontract_id or r.treasury_account_id is distinct from o.treasury_account_id)) then raise exception 'Exact reversal mismatch'; end if;

  set local role authenticated;
  perform public.reverse_subcontractor_advance(f.company_id,large_post.subcontractor_advance_id,current_date,'Prepare dependency fixture',gen_random_uuid());
  perform public.reverse_subcontractor_advance(f.company_id,accountant_advance.subcontractor_advance_id,current_date,'Prepare dependency fixture',gen_random_uuid());
  select * into dependency_advance from public.post_subcontractor_advance(f.company_id,current_date,f.subcontract_id,f.treasury_id,10000,'BANK',null,null,gen_random_uuid());
  select coalesce(max(work_value_to_date_minor),0) into previous_work from public.subcontractor_certificates where company_id=f.company_id and subcontract_id=f.subcontract_id and status='POSTED';
  select * into cert_draft from public.create_subcontractor_certificate_draft(f.company_id,current_date,f.subcontract_id,'P6D-DEPENDENCY-'||gen_random_uuid()::text,previous_work+5000,0,1000,'ZERO',null,false,null,null,'[]'::jsonb,'rollback dependency');
  perform public.approve_post_subcontractor_certificate(f.company_id,cert_draft.subcontractor_certificate_id,gen_random_uuid());
  begin perform public.reverse_subcontractor_advance(f.company_id,dependency_advance.subcontractor_advance_id,current_date,'Should be blocked',gen_random_uuid()); raise exception 'Recovered Advance reversed'; exception when check_violation then null; end; reset role;

  update public.company_memberships set role=f.original_role where company_id=f.company_id and user_id=f.user_id;
  perform set_config('makeracc.p6d_subcontractor_advance_result',jsonb_build_object('read_post_reverse',true,'exact_bigint',true,'roles_rls_tenant',true,'active_subcontract_party_treasury',true,'balanced_asset_treasury_journal',true,'no_cost_vat_retention_payable',true,'dimensions',true,'idempotent_replay',true,'exact_reversal',true,'recovery_guard',true)::text,true);
end;
$$;
set constraints all immediate;
select current_setting('makeracc.p6d_subcontractor_advance_result')::jsonb result;
rollback;
