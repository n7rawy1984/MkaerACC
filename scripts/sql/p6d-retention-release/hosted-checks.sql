-- MakerACC-Development only. Existing synthetic masters/actor; every change rolls back.
begin;
do $$
declare
  f record; other record; d1 record; d2 record; d3 record; c1 record; c2 record; c3 record;
  release1 record; replay1 record; release2 record; reversed record; reverse_replay record;
  original_project_status public.project_status; original_subcontract_status public.subcontract_status;
  original_party_status public.account_status; original_role public.company_role;
  previous_work bigint; other_previous_work bigint; r1 bigint; r2 bigint; a1 bigint; a2 bigint; release_total bigint; foreign_company uuid;
  release_key uuid:=gen_random_uuid(); reverse_key uuid:=gen_random_uuid(); test_role public.company_role;
  payments_before bigint; payment_allocations_before bigint;
begin
  select m.user_id,m.role,c.id company_id,s.id subcontract_id,s.project_id,s.subcontractor_id,
    pr.status project_status,s.status subcontract_status,p.status party_status
  into f
  from public.company_memberships m
  join public.profiles pf on pf.user_id=m.user_id and pf.status='ACTIVE'
  join public.companies c on c.id=m.company_id and c.status='ACTIVE'
  join public.subcontracts s on s.company_id=c.id and s.status='ACTIVE' and s.retention_bps between 1 and 5000
  join public.projects pr on pr.company_id=c.id and pr.id=s.project_id and pr.status<>'CLOSED'
  join public.parties p on p.company_id=c.id and p.id=s.subcontractor_id and p.type='SUBCONTRACTOR'
  where m.status='ACTIVE'
    and exists(select 1 from public.accounts a where a.company_id=c.id and a.status='ACTIVE' and a.system_key in ('PROJECT_COST_SUBCONTRACTORS','SUBCONTRACTOR_RETENTION_PAYABLE','SUBCONTRACTOR_PAYABLE') group by a.company_id having count(distinct a.system_key)=3)
    and (s.original_contract_value_minor::numeric+s.approved_variations_minor::numeric-coalesce((select sum(sc.gross_certified_minor) from public.subcontractor_certificates sc where sc.company_id=c.id and sc.subcontract_id=s.id and sc.status='POSTED'),0))>=3000
    and exists(select 1 from public.subcontracts sx where sx.company_id=c.id and sx.id<>s.id and sx.status='ACTIVE' and sx.retention_bps between 1 and 5000
      and (sx.original_contract_value_minor::numeric+sx.approved_variations_minor::numeric-coalesce((select sum(sc.gross_certified_minor) from public.subcontractor_certificates sc where sc.company_id=c.id and sc.subcontract_id=sx.id and sc.status='POSTED'),0))>=1000)
  order by c.id,m.user_id,s.id limit 1;
  if f.user_id is null then raise exception 'No synthetic Retention Release fixture'; end if;
  select s.id subcontract_id,s.project_id,s.subcontractor_id into other from public.subcontracts s
  where s.company_id=f.company_id and s.id<>f.subcontract_id and s.status='ACTIVE' and s.retention_bps between 1 and 5000
    and (s.original_contract_value_minor::numeric+s.approved_variations_minor::numeric-coalesce((select sum(sc.gross_certified_minor) from public.subcontractor_certificates sc where sc.company_id=f.company_id and sc.subcontract_id=s.id and sc.status='POSTED'),0))>=1000
  order by s.id limit 1;
  original_role:=f.role; original_project_status:=f.project_status; original_subcontract_status:=f.subcontract_status; original_party_status:=f.party_status;
  select coalesce(max(work_value_to_date_minor),0) into previous_work from public.subcontractor_certificates where company_id=f.company_id and subcontract_id=f.subcontract_id and status='POSTED';
  select coalesce(max(work_value_to_date_minor),0) into other_previous_work from public.subcontractor_certificates where company_id=f.company_id and subcontract_id=other.subcontract_id and status='POSTED';
  select count(*) into payments_before from public.subcontractor_payments where company_id=f.company_id;
  select count(*) into payment_allocations_before from public.subcontractor_payment_allocations where company_id=f.company_id;

  update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id=f.company_id and user_id=f.user_id;
  perform set_config('request.jwt.claim.sub',f.user_id::text,true); set local role authenticated;
  select * into d1 from public.create_subcontractor_certificate_draft(f.company_id,current_date,f.subcontract_id,'P6D-REL-1-'||gen_random_uuid()::text,previous_work+1000,0,0,'ZERO',null,false,null,null,'[]','release fixture');
  select * into c1 from public.approve_post_subcontractor_certificate(f.company_id,d1.subcontractor_certificate_id,gen_random_uuid());
  select * into d2 from public.create_subcontractor_certificate_draft(f.company_id,current_date,f.subcontract_id,'P6D-REL-2-'||gen_random_uuid()::text,previous_work+2000,0,0,'ZERO',null,false,null,null,'[]','release fixture');
  select * into c2 from public.approve_post_subcontractor_certificate(f.company_id,d2.subcontractor_certificate_id,gen_random_uuid());
  select * into d3 from public.create_subcontractor_certificate_draft(f.company_id,current_date,other.subcontract_id,'P6D-REL-X-'||gen_random_uuid()::text,other_previous_work+1000,0,0,'ZERO',null,false,null,null,'[]','cross-contract fixture');
  select * into c3 from public.approve_post_subcontractor_certificate(f.company_id,d3.subcontractor_certificate_id,gen_random_uuid()); reset role;
  select retention_amount_minor into r1 from public.subcontractor_certificates where id=d1.subcontractor_certificate_id;
  select retention_amount_minor into r2 from public.subcontractor_certificates where id=d2.subcontractor_certificate_id;
  if least(r1,r2)<2 then raise exception 'Certificate retention fixture too small'; end if;
  a1:=greatest(1,r1/2); a2:=greatest(1,r2/2); release_total:=a1+a2;

  -- Canonical lifecycle allows release of existing retention after related masters close or become inactive.
  update public.projects set status='CLOSED' where id=f.project_id;
  update public.subcontracts set status='CLOSED' where id=f.subcontract_id;
  update public.parties set status='INACTIVE' where id=f.subcontractor_id;
  set local role authenticated;
  select * into release1 from public.post_subcontractor_retention_release(f.company_id,current_date,f.subcontract_id,release_total,' P6D-AUTH ',' partial multi ',jsonb_build_array(jsonb_build_object('certificate_id',d1.subcontractor_certificate_id,'amount_minor',a1),jsonb_build_object('certificate_id',d2.subcontractor_certificate_id,'amount_minor',a2)),release_key);
  select * into replay1 from public.post_subcontractor_retention_release(f.company_id,current_date,f.subcontract_id,release_total,'P6D-AUTH','partial multi',jsonb_build_array(jsonb_build_object('certificate_id',d2.subcontractor_certificate_id,'amount_minor',a2),jsonb_build_object('certificate_id',d1.subcontractor_certificate_id,'amount_minor',a1)),release_key); reset role;
  if release1.replayed or not replay1.replayed or release1.retention_release_id<>replay1.retention_release_id or release1.journal_entry_id<>replay1.journal_entry_id then raise exception 'Retention Release replay mismatch'; end if;
  if not exists(select 1 from public.subcontractor_retention_releases r where r.id=release1.retention_release_id and r.project_id=f.project_id and r.subcontractor_id=f.subcontractor_id and r.subcontract_id=f.subcontract_id and r.total_amount_minor=release_total and r.authorization_reference='P6D-AUTH' and r.notes='partial multi' and r.status='POSTED')
    or (select count(*) from public.subcontractor_retention_release_allocations where retention_release_id=release1.retention_release_id)<>2 then raise exception 'Release document/allocation mismatch'; end if;
  if (select count(*) from public.journal_lines where journal_entry_id=release1.journal_entry_id)<>2
    or (select sum(debit_minor-credit_minor) from public.journal_lines where journal_entry_id=release1.journal_entry_id)<>0
    or not exists(select 1 from public.journal_lines l join public.accounts a on a.id=l.account_id where l.journal_entry_id=release1.journal_entry_id and a.system_key='SUBCONTRACTOR_RETENTION_PAYABLE' and l.debit_minor=release_total and l.credit_minor=0 and l.project_id=f.project_id and l.party_id=f.subcontractor_id and l.subcontract_id=f.subcontract_id and l.treasury_account_id is null)
    or not exists(select 1 from public.journal_lines l join public.accounts a on a.id=l.account_id where l.journal_entry_id=release1.journal_entry_id and a.system_key='SUBCONTRACTOR_PAYABLE' and l.debit_minor=0 and l.credit_minor=release_total and l.project_id=f.project_id and l.party_id=f.subcontractor_id and l.subcontract_id=f.subcontract_id and l.treasury_account_id is null)
    or exists(select 1 from public.journal_lines l join public.accounts a on a.id=l.account_id where l.journal_entry_id=release1.journal_entry_id and a.system_key not in ('SUBCONTRACTOR_RETENTION_PAYABLE','SUBCONTRACTOR_PAYABLE')) then raise exception 'Retention Release journal mismatch or forbidden reposting'; end if;

  -- Staged full remainder, authoritative availability, over-release, cross-Subcontract rejection, and Certificate dependency.
  set local role authenticated;
  select * into release2 from public.post_subcontractor_retention_release(f.company_id,current_date,f.subcontract_id,r1-a1,null,'full remaining stage',jsonb_build_array(jsonb_build_object('certificate_id',d1.subcontractor_certificate_id,'amount_minor',r1-a1)),gen_random_uuid());
  begin perform public.post_subcontractor_retention_release(f.company_id,current_date,f.subcontract_id,r2-a2+1,null,null,jsonb_build_array(jsonb_build_object('certificate_id',d2.subcontractor_certificate_id,'amount_minor',r2-a2+1)),gen_random_uuid()); raise exception 'Over-release allowed'; exception when check_violation then null; end;
  begin perform public.post_subcontractor_retention_release(f.company_id,current_date,f.subcontract_id,1,null,null,jsonb_build_array(jsonb_build_object('certificate_id',d3.subcontractor_certificate_id,'amount_minor',1)),gen_random_uuid()); raise exception 'Cross-Subcontract allocation allowed'; exception when check_violation then null; end;
  begin perform public.reverse_subcontractor_certificate(f.company_id,d1.subcontractor_certificate_id,current_date,'blocked',gen_random_uuid()); raise exception 'Live release did not block Certificate reversal'; exception when check_violation then null; end; reset role;
  if (select c.retention_amount_minor-coalesce(sum(a.allocated_amount_minor) filter(where r.status='POSTED'),0) from public.subcontractor_certificates c left join public.subcontractor_retention_release_allocations a on a.subcontractor_certificate_id=c.id left join public.subcontractor_retention_releases r on r.id=a.retention_release_id where c.id=d1.subcontractor_certificate_id group by c.retention_amount_minor)<>0 then raise exception 'Authoritative remaining retention mismatch'; end if;

  -- Read/RPC role matrix, inactive membership, and tenant isolation fail closed.
  foreach test_role in array enum_range(null::public.company_role) loop
    update public.company_memberships set role=test_role where company_id=f.company_id and user_id=f.user_id; set local role authenticated;
    if test_role in ('ACCOUNTING_ADMIN','ACCOUNTANT','MANAGEMENT_VIEWER') then
      if not exists(select 1 from public.subcontractor_retention_releases where id=release1.retention_release_id) or not exists(select 1 from public.subcontractor_retention_release_allocations where retention_release_id=release1.retention_release_id) then raise exception 'Allowed release read failed: %',test_role; end if;
    elsif exists(select 1 from public.subcontractor_retention_releases where id=release1.retention_release_id) then raise exception 'Denied release read: %',test_role; end if;
    if test_role<>'ACCOUNTING_ADMIN' then
      begin perform public.post_subcontractor_retention_release(f.company_id,current_date,f.subcontract_id,1,null,null,jsonb_build_array(jsonb_build_object('certificate_id',d2.subcontractor_certificate_id,'amount_minor',1)),gen_random_uuid()); raise exception 'Denied release post: %',test_role; exception when insufficient_privilege then null; end;
      begin perform public.reverse_subcontractor_retention_release(f.company_id,release2.retention_release_id,current_date,'denied',gen_random_uuid()); raise exception 'Denied release reversal: %',test_role; exception when insufficient_privilege then null; end;
    end if; reset role;
  end loop;
  update public.company_memberships set role='ACCOUNTING_ADMIN',status='INACTIVE' where company_id=f.company_id and user_id=f.user_id; set local role authenticated;
  begin perform public.post_subcontractor_retention_release(f.company_id,current_date,f.subcontract_id,1,null,null,jsonb_build_array(jsonb_build_object('certificate_id',d2.subcontractor_certificate_id,'amount_minor',1)),gen_random_uuid()); raise exception 'Inactive member posted'; exception when insufficient_privilege then null; end; reset role;
  update public.company_memberships set status='ACTIVE' where company_id=f.company_id and user_id=f.user_id;
  select c.id into foreign_company from public.companies c where c.id<>f.company_id and not exists(select 1 from public.company_memberships m where m.company_id=c.id and m.user_id=f.user_id and m.status='ACTIVE') limit 1; set local role authenticated;
  begin perform public.post_subcontractor_retention_release(foreign_company,current_date,f.subcontract_id,1,null,null,jsonb_build_array(jsonb_build_object('certificate_id',d2.subcontractor_certificate_id,'amount_minor',1)),gen_random_uuid()); raise exception 'Cross-tenant release posted'; exception when insufficient_privilege then null; end; reset role;

  -- Exact reversal/replay restores availability and removes only the Release dependency.
  update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id=f.company_id and user_id=f.user_id; set local role authenticated;
  select * into reversed from public.reverse_subcontractor_retention_release(f.company_id,release2.retention_release_id,current_date,'restore retention',reverse_key);
  select * into reverse_replay from public.reverse_subcontractor_retention_release(f.company_id,release2.retention_release_id,current_date,'restore retention',reverse_key); reset role;
  if reversed.replayed or not reverse_replay.replayed or reversed.reversal_journal_entry_id<>reverse_replay.reversal_journal_entry_id then raise exception 'Retention Release reversal replay mismatch'; end if;
  if exists(select 1 from public.journal_lines o full join public.journal_lines r on r.journal_entry_id=reversed.reversal_journal_entry_id and r.line_number=o.line_number where o.journal_entry_id=release2.journal_entry_id and (r.account_id<>o.account_id or r.debit_minor<>o.credit_minor or r.credit_minor<>o.debit_minor or r.project_id is distinct from o.project_id or r.party_id is distinct from o.party_id or r.subcontract_id is distinct from o.subcontract_id or r.treasury_account_id is distinct from o.treasury_account_id)) then raise exception 'Retention Release reversal is not exact'; end if;
  if (select c.retention_amount_minor-coalesce(sum(a.allocated_amount_minor) filter(where r.status='POSTED'),0) from public.subcontractor_certificates c left join public.subcontractor_retention_release_allocations a on a.subcontractor_certificate_id=c.id left join public.subcontractor_retention_releases r on r.id=a.retention_release_id where c.id=d1.subcontractor_certificate_id group by c.retention_amount_minor)<>r1-a1 then raise exception 'Reversal did not restore releasable retention'; end if;
  set local role authenticated; perform public.reverse_subcontractor_retention_release(f.company_id,release1.retention_release_id,current_date,'remove dependency',gen_random_uuid()); perform public.reverse_subcontractor_certificate(f.company_id,d1.subcontractor_certificate_id,current_date,'dependency removed',gen_random_uuid()); reset role;
  if (select count(*) from public.subcontractor_payments where company_id=f.company_id)<>payments_before or (select count(*) from public.subcontractor_payment_allocations where company_id=f.company_id)<>payment_allocations_before then raise exception 'Independent Subcontractor Payment data changed'; end if;
  update public.projects set status=original_project_status where id=f.project_id; update public.subcontracts set status=original_subcontract_status where id=f.subcontract_id; update public.parties set status=original_party_status where id=f.subcontractor_id; update public.company_memberships set role=original_role where company_id=f.company_id and user_id=f.user_id;
  perform set_config('makeracc.p6d_retention_release_result',jsonb_build_object('exact_bigint',true,'partial_full_staged_multi',true,'same_subcontract',true,'authoritative_availability',true,'closed_inactive_release',true,'admin_only_mutations',true,'authorized_reads',true,'denied_system_inactive_cross_tenant',true,'retention_to_payable_only',true,'no_treasury_cost_vat_advance_deductions',true,'idempotency',true,'certificate_guard',true,'exact_reversal_restore',true,'payments_unchanged',true)::text,true);
end $$;
set constraints all immediate;
select current_setting('makeracc.p6d_retention_release_result')::jsonb result;
rollback;
