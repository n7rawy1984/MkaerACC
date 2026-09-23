-- MakerACC-Development only. Existing synthetic masters/actor; every mutation and financial effect rolls back.
begin;
do $$
declare
  fixture record;
  expense_project record;
  expense_company record;
  payment record;
  replay record;
  reversed record;
  payment_before jsonb;
  lines_before jsonb;
  test_role public.company_role;
  foreign_company uuid;
  project_treasury uuid;
  payment_key uuid := gen_random_uuid();
  reversal_key uuid := gen_random_uuid();
begin
  select m.user_id,m.role original_role,c.id company_id,p.id supplier_id,pr.id project_id,cat.id category_id,
    (select t.id from public.treasury_accounts t join public.accounts a on a.id=t.gl_account_id and a.company_id=t.company_id
      where t.company_id=c.id and t.project_id is null and t.status='ACTIVE' and a.status='ACTIVE' and a.account_type='ASSET' limit 1) company_treasury
  into fixture
  from public.company_memberships m
  join public.profiles profile on profile.user_id=m.user_id and profile.status='ACTIVE'
  join public.companies c on c.id=m.company_id and c.status='ACTIVE'
  join public.parties p on p.company_id=c.id and p.type='SUPPLIER' and p.status='ACTIVE'
  join public.projects pr on pr.company_id=c.id and pr.status<>'CLOSED'
  join public.expense_categories cat on cat.company_id=c.id and cat.status='ACTIVE'
  where m.status='ACTIVE' and exists(select 1 from public.accounts a where a.company_id=c.id and a.system_key='SUPPLIER_PAYABLE' and a.status='ACTIVE')
    and exists(select 1 from public.treasury_accounts t join public.accounts a on a.id=t.gl_account_id and a.company_id=t.company_id where t.company_id=c.id and t.project_id is null and t.status='ACTIVE' and a.status='ACTIVE' and a.account_type='ASSET')
  order by c.id,m.user_id limit 1;
  if fixture.user_id is null then raise exception 'No existing synthetic Supplier Payment fixture'; end if;
  update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id=fixture.company_id and user_id=fixture.user_id;
  perform set_config('request.jwt.claim.sub',fixture.user_id::text,true);
  set local role authenticated;
  select * into expense_project from public.post_expense(fixture.company_id,current_date,fixture.project_id,fixture.category_id,
    'P6D Supplier payable Project rollback fixture',10000,'ZERO',null,'SUPPLIER_CREDIT',null,null,fixture.supplier_id,'TRANSFER',false,null,null,gen_random_uuid());
  select * into expense_company from public.post_expense(fixture.company_id,current_date,null,fixture.category_id,
    'P6D Supplier payable Company rollback fixture',20000,'ZERO',null,'SUPPLIER_CREDIT',null,null,fixture.supplier_id,'TRANSFER',false,null,null,gen_random_uuid());
  reset role;

  -- Existing liabilities remain payable after Supplier/Project closure.
  update public.parties set status='INACTIVE' where id=fixture.supplier_id;
  update public.projects set status='CLOSED' where id=fixture.project_id;
  set local role authenticated;
  select * into payment from public.post_supplier_payment(fixture.company_id,current_date,fixture.supplier_id,fixture.company_treasury,10000,
    'TRANSFER','  EXT-P6D  ','  partial multi Expense  ',jsonb_build_array(
      jsonb_build_object('expense_id',expense_project.expense_id,'amount_minor',4000),
      jsonb_build_object('expense_id',expense_company.expense_id,'amount_minor',6000)),payment_key);
  select * into replay from public.post_supplier_payment(fixture.company_id,current_date,fixture.supplier_id,fixture.company_treasury,10000,
    'TRANSFER','EXT-P6D','partial multi Expense',jsonb_build_array(
      jsonb_build_object('expense_id',expense_company.expense_id,'amount_minor',6000),
      jsonb_build_object('expense_id',expense_project.expense_id,'amount_minor',4000)),payment_key);
  if payment.replayed or not replay.replayed or payment.supplier_payment_id<>replay.supplier_payment_id or payment.journal_entry_id<>replay.journal_entry_id then raise exception 'Supplier Payment idempotent replay mismatch'; end if;
  begin
    perform public.post_supplier_payment(fixture.company_id,current_date,fixture.supplier_id,fixture.company_treasury,10001,
      'TRANSFER','EXT-P6D','changed',jsonb_build_array(jsonb_build_object('expense_id',expense_company.expense_id,'amount_minor',10001)),payment_key);
    raise exception 'Changed Supplier Payment replay allowed';
  exception when unique_violation then null;
  end;
  reset role;

  select to_jsonb(p) into payment_before from public.supplier_payments p where p.id=payment.supplier_payment_id;
  select jsonb_agg(to_jsonb(l) order by l.line_number) into lines_before from public.journal_lines l where l.journal_entry_id=payment.journal_entry_id;
  if (select status from public.supplier_payments where id=payment.supplier_payment_id)<>'POSTED'
    or (select total_amount_minor from public.supplier_payments where id=payment.supplier_payment_id)<>10000
    or (select count(*) from public.supplier_payment_allocations where supplier_payment_id=payment.supplier_payment_id)<>2
    then raise exception 'Supplier Payment document/allocation readback mismatch'; end if;
  if (select sum(debit_minor-credit_minor) from public.journal_lines where journal_entry_id=payment.journal_entry_id)<>0
    or (select sum(debit_minor) from public.journal_lines where journal_entry_id=payment.journal_entry_id and party_id=fixture.supplier_id)<>10000
    or not exists(select 1 from public.journal_lines where journal_entry_id=payment.journal_entry_id and debit_minor=4000 and project_id=fixture.project_id and party_id=fixture.supplier_id)
    or not exists(select 1 from public.journal_lines where journal_entry_id=payment.journal_entry_id and debit_minor=6000 and project_id is null and party_id=fixture.supplier_id)
    or not exists(select 1 from public.journal_lines where journal_entry_id=payment.journal_entry_id and credit_minor=10000 and treasury_account_id=fixture.company_treasury)
    or exists(select 1 from public.journal_lines l join public.accounts a on a.id=l.account_id where l.journal_entry_id=payment.journal_entry_id and (a.account_type='EXPENSE' or a.system_key='INPUT_VAT'))
    then raise exception 'Supplier Payment journal/account/dimension mismatch'; end if;
  if (select e.gross_amount_minor-coalesce(sum(case when p.status='POSTED' then a.allocated_amount_minor else 0 end),0) from public.expenses e left join public.supplier_payment_allocations a on a.expense_id=e.id left join public.supplier_payments p on p.id=a.supplier_payment_id where e.id=expense_project.expense_id group by e.id)<>6000
    or (select e.gross_amount_minor-coalesce(sum(case when p.status='POSTED' then a.allocated_amount_minor else 0 end),0) from public.expenses e left join public.supplier_payment_allocations a on a.expense_id=e.id left join public.supplier_payments p on p.id=a.supplier_payment_id where e.id=expense_company.expense_id group by e.id)<>14000
    then raise exception 'Partial/multi Expense outstanding mismatch'; end if;
  set local role authenticated;
  begin
    perform public.post_supplier_payment(fixture.company_id,current_date,fixture.supplier_id,fixture.company_treasury,14001,'TRANSFER',null,null,
      jsonb_build_array(jsonb_build_object('expense_id',expense_company.expense_id,'amount_minor',14001)),gen_random_uuid());
    raise exception 'Over-allocation allowed';
  exception when check_violation then null;
  end;
  begin
    perform public.reverse_expense(fixture.company_id,expense_project.expense_id,current_date,'Allocated Expense denial',gen_random_uuid());
    raise exception 'Allocated Expense reversal allowed';
  exception when others then if sqlerrm not like 'Reverse active Supplier Payments before reversing this Supplier Credit Expense%' then raise; end if;
  end;
  reset role;

  -- Active Treasury and mapped Asset GL remain mandatory.
  update public.treasury_accounts set status='INACTIVE' where id=fixture.company_treasury;
  set local role authenticated;
  begin
    perform public.post_supplier_payment(fixture.company_id,current_date,fixture.supplier_id,fixture.company_treasury,1000,'TRANSFER',null,null,
      jsonb_build_array(jsonb_build_object('expense_id',expense_company.expense_id,'amount_minor',1000)),gen_random_uuid());
    raise exception 'Inactive Treasury accepted';
  exception when check_violation then null;
  end;
  reset role;
  update public.treasury_accounts set status='ACTIVE' where id=fixture.company_treasury;
  select t.id into project_treasury from public.treasury_accounts t join public.accounts a on a.id=t.gl_account_id and a.company_id=t.company_id where t.company_id=fixture.company_id and t.project_id=fixture.project_id and t.status='ACTIVE' and a.status='ACTIVE' and a.account_type='ASSET' limit 1;
  if project_treasury is not null then
    set local role authenticated;
    begin
      perform public.post_supplier_payment(fixture.company_id,current_date,fixture.supplier_id,project_treasury,1000,'TRANSFER',null,null,
        jsonb_build_array(jsonb_build_object('expense_id',expense_company.expense_id,'amount_minor',1000)),gen_random_uuid());
      raise exception 'Project Treasury settled Company-level liability';
    exception when check_violation then null;
    end;
    reset role;
  end if;

  -- POST role matrix and canonical read RLS.
  foreach test_role in array enum_range(null::public.company_role) loop
    update public.company_memberships set role=test_role where company_id=fixture.company_id and user_id=fixture.user_id;
    set local role authenticated;
    if test_role in ('ACCOUNTING_ADMIN','ACCOUNTANT','MANAGEMENT_VIEWER') then
      if not exists(select 1 from public.supplier_payments where id=payment.supplier_payment_id) then raise exception 'Allowed role cannot read Supplier Payment: %',test_role; end if;
    elsif exists(select 1 from public.supplier_payments where id=payment.supplier_payment_id) then raise exception 'Denied role read Supplier Payment: %',test_role;
    end if;
    if test_role not in ('ACCOUNTING_ADMIN','ACCOUNTANT') then
      begin
        perform public.post_supplier_payment(fixture.company_id,current_date,fixture.supplier_id,fixture.company_treasury,1000,'TRANSFER',null,null,jsonb_build_array(jsonb_build_object('expense_id',expense_company.expense_id,'amount_minor',1000)),gen_random_uuid());
        raise exception 'Denied role posted Supplier Payment: %',test_role;
      exception when insufficient_privilege then null;
      end;
    end if;
    reset role;
  end loop;
  update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id=fixture.company_id and user_id=fixture.user_id;
  select c.id into foreign_company from public.companies c where c.id<>fixture.company_id and not exists(select 1 from public.company_memberships m where m.company_id=c.id and m.user_id=fixture.user_id and m.status='ACTIVE') limit 1;
  set local role authenticated;
  if exists(select 1 from public.supplier_payments where company_id=foreign_company) then raise exception 'Cross-tenant Supplier Payment read allowed'; end if;
  begin
    perform public.reverse_supplier_payment(foreign_company,payment.supplier_payment_id,current_date,'Cross tenant',gen_random_uuid()); raise exception 'Cross-tenant reversal allowed';
  exception when insufficient_privilege then null;
  end;
  select * into reversed from public.reverse_supplier_payment(fixture.company_id,payment.supplier_payment_id,current_date,'  Rollback exact reversal  ',reversal_key);
  select * into replay from public.reverse_supplier_payment(fixture.company_id,payment.supplier_payment_id,current_date,'Rollback exact reversal',reversal_key);
  if reversed.replayed or not replay.replayed or reversed.reversal_journal_entry_id<>replay.reversal_journal_entry_id then raise exception 'Reversal replay mismatch'; end if;
  reset role;
  if (select status from public.supplier_payments where id=payment.supplier_payment_id)<>'REVERSED'
    or (to_jsonb((select p from public.supplier_payments p where p.id=payment.supplier_payment_id))-array['status','reversal_journal_entry_id','reversed_at','reversed_by','updated_at','updated_by'])
      <> (payment_before-array['status','reversal_journal_entry_id','reversed_at','reversed_by','updated_at','updated_by'])
    then raise exception 'Reversal mutated original Supplier Payment economics/provenance'; end if;
  if (select count(*) from public.journal_lines where journal_entry_id=reversed.reversal_journal_entry_id)<>(select count(*) from public.journal_lines where journal_entry_id=payment.journal_entry_id)
    or exists(select 1 from public.journal_lines o join public.journal_lines r on r.journal_entry_id=reversed.reversal_journal_entry_id and r.line_number=o.line_number where o.journal_entry_id=payment.journal_entry_id and (r.account_id<>o.account_id or r.debit_minor<>o.credit_minor or r.credit_minor<>o.debit_minor or r.project_id is distinct from o.project_id or r.party_id is distinct from o.party_id or r.treasury_account_id is distinct from o.treasury_account_id))
    or (select jsonb_agg(to_jsonb(l) order by l.line_number) from public.journal_lines l where l.journal_entry_id=payment.journal_entry_id)<>lines_before
    then raise exception 'Supplier Payment reversal is not exact or original journal changed'; end if;
  if (select e.gross_amount_minor-coalesce(sum(case when p.status='POSTED' then a.allocated_amount_minor else 0 end),0) from public.expenses e left join public.supplier_payment_allocations a on a.expense_id=e.id left join public.supplier_payments p on p.id=a.supplier_payment_id where e.id=expense_project.expense_id group by e.id)<>10000
    or (select e.gross_amount_minor-coalesce(sum(case when p.status='POSTED' then a.allocated_amount_minor else 0 end),0) from public.expenses e left join public.supplier_payment_allocations a on a.expense_id=e.id left join public.supplier_payments p on p.id=a.supplier_payment_id where e.id=expense_company.expense_id group by e.id)<>20000
    then raise exception 'Reversal did not restore outstanding'; end if;
  update public.company_memberships set role=fixture.original_role where company_id=fixture.company_id and user_id=fixture.user_id;
  perform set_config('makeracc.p6d_supplier_payment_result',jsonb_build_object('read_allocations_outstanding',true,'partial_multi_expense',true,'inactive_supplier_closed_project',true,'company_treasury_dimensions',true,'no_cost_vat',true,'overallocation_denied',true,'expense_reversal_dependency',true,'active_treasury_required',true,'project_treasury_rule',project_treasury is not null,'post_role_matrix',true,'read_rls_matrix',true,'tenant_isolation',true,'idempotent_replay',true,'exact_reversal',true,'outstanding_restored',true)::text,true);
end;
$$;
set constraints all immediate;
select current_setting('makeracc.p6d_supplier_payment_result')::jsonb result;
rollback;
