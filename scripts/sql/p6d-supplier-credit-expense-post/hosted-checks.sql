-- MakerACC-Development only. Existing synthetic masters/actor; all financial effects and role/master changes roll back.
begin;
do $$
declare
  fixture record;
  zero_expense record;
  auto_expense record;
  manual_expense record;
  bigint_expense record;
  replay record;
  paid_expense record;
  payment record;
  test_role public.company_role;
  foreign_company uuid;
  request_key uuid := gen_random_uuid();
begin
  select m.user_id,m.role original_role,c.id company_id,p.id supplier_id,pr.id project_id,pr.status original_project_status,cat.id category_id,
    (select t.id from public.treasury_accounts t join public.accounts a on a.id=t.gl_account_id and a.company_id=t.company_id
      where t.company_id=c.id and t.project_id is null and t.status='ACTIVE' and a.status='ACTIVE' and a.account_type='ASSET' limit 1) treasury_id
  into fixture
  from public.company_memberships m
  join public.profiles profile on profile.user_id=m.user_id and profile.status='ACTIVE'
  join public.companies c on c.id=m.company_id and c.status='ACTIVE'
  join public.parties p on p.company_id=c.id and p.type='SUPPLIER' and p.status='ACTIVE'
  join public.projects pr on pr.company_id=c.id and pr.status<>'CLOSED'
  join public.expense_categories cat on cat.company_id=c.id and cat.status='ACTIVE'
  where m.status='ACTIVE'
    and exists(select 1 from public.accounts a where a.company_id=c.id and a.system_key in ('PROJECT_COST','COMPANY_EXPENSE','INPUT_VAT','SUPPLIER_PAYABLE') and a.status='ACTIVE' group by a.company_id having count(distinct a.system_key)=4)
    and exists(select 1 from public.treasury_accounts t join public.accounts a on a.id=t.gl_account_id and a.company_id=t.company_id where t.company_id=c.id and t.project_id is null and t.status='ACTIVE' and a.status='ACTIVE' and a.account_type='ASSET')
  order by c.id,m.user_id limit 1;
  if fixture.user_id is null then raise exception 'No synthetic Supplier Credit Expense fixture'; end if;
  update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id=fixture.company_id and user_id=fixture.user_id;
  perform set_config('request.jwt.claim.sub',fixture.user_id::text,true);
  set local role authenticated;
  select * into zero_expense from public.post_expense(fixture.company_id,current_date,fixture.project_id,fixture.category_id,
    'P6D Supplier Credit ZERO rollback',10000,'ZERO',null,'SUPPLIER_CREDIT',null,null,fixture.supplier_id,'CHEQUE',false,null,'zero',request_key);
  select * into replay from public.post_expense(fixture.company_id,current_date,fixture.project_id,fixture.category_id,
    'P6D Supplier Credit ZERO rollback',10000,'ZERO',null,'SUPPLIER_CREDIT',null,null,fixture.supplier_id,'CHEQUE',false,null,'zero',request_key);
  if zero_expense.replayed or not replay.replayed or zero_expense.expense_id<>replay.expense_id or zero_expense.journal_entry_id<>replay.journal_entry_id then raise exception 'Supplier Credit idempotent replay mismatch'; end if;
  begin
    perform public.post_expense(fixture.company_id,current_date,fixture.project_id,fixture.category_id,'Changed',10000,'ZERO',null,'SUPPLIER_CREDIT',null,null,fixture.supplier_id,'CHEQUE',false,null,'zero',request_key);
    raise exception 'Changed Supplier Credit replay allowed';
  exception when unique_violation then null;
  end;
  select * into auto_expense from public.post_expense(fixture.company_id,current_date,null,fixture.category_id,
    'P6D Supplier Credit AUTO rollback',101,'AUTO_5',null,'SUPPLIER_CREDIT',null,null,fixture.supplier_id,'TRANSFER',true,'INV-AUTO',null,gen_random_uuid());
  select * into manual_expense from public.post_expense(fixture.company_id,current_date,fixture.project_id,fixture.category_id,
    'P6D Supplier Credit MANUAL rollback',1000,'MANUAL',47,'SUPPLIER_CREDIT',null,null,fixture.supplier_id,'BANK',true,'INV-MANUAL',null,gen_random_uuid());
  select * into bigint_expense from public.post_expense(fixture.company_id,current_date,null,fixture.category_id,
    'P6D Supplier Credit BIGINT rollback',9000000000000000,'ZERO',null,'SUPPLIER_CREDIT',null,null,fixture.supplier_id,'OTHER',false,null,null,gen_random_uuid());
  reset role;

  if not exists(select 1 from public.expenses where id=zero_expense.expense_id and status='POSTED' and funding_mode='SUPPLIER_CREDIT' and treasury_account_id is null and paid_by_party_id is null and supplier_id=fixture.supplier_id and payment_method='CHEQUE' and net_amount_minor=10000 and vat_amount_minor=0 and gross_amount_minor=10000)
    or not exists(select 1 from public.expenses where id=auto_expense.expense_id and project_id is null and net_amount_minor=101 and vat_amount_minor=5 and gross_amount_minor=106 and payment_method='TRANSFER')
    or not exists(select 1 from public.expenses where id=manual_expense.expense_id and net_amount_minor=1000 and vat_amount_minor=47 and gross_amount_minor=1047 and payment_method='BANK')
    or not exists(select 1 from public.expenses where id=bigint_expense.expense_id and net_amount_minor=9000000000000000 and gross_amount_minor=9000000000000000)
    then raise exception 'Supplier Credit Expense document/VAT/payment_method readback mismatch'; end if;
  if exists(select 1 from public.journal_lines l join public.accounts a on a.id=l.account_id where l.journal_entry_id=zero_expense.journal_entry_id and a.system_key not in ('PROJECT_COST','SUPPLIER_PAYABLE'))
    or not exists(select 1 from public.journal_lines l join public.accounts a on a.id=l.account_id where l.journal_entry_id=zero_expense.journal_entry_id and a.system_key='PROJECT_COST' and l.debit_minor=10000 and l.project_id=fixture.project_id and l.party_id is null and l.treasury_account_id is null)
    or not exists(select 1 from public.journal_lines l join public.accounts a on a.id=l.account_id where l.journal_entry_id=zero_expense.journal_entry_id and a.system_key='SUPPLIER_PAYABLE' and l.credit_minor=10000 and l.project_id=fixture.project_id and l.party_id=fixture.supplier_id and l.treasury_account_id is null)
    or (select sum(debit_minor-credit_minor) from public.journal_lines where journal_entry_id=zero_expense.journal_entry_id)<>0
    then raise exception 'ZERO Supplier Credit journal mismatch'; end if;
  if not exists(select 1 from public.journal_lines l join public.accounts a on a.id=l.account_id where l.journal_entry_id=auto_expense.journal_entry_id and a.system_key='COMPANY_EXPENSE' and l.debit_minor=101 and l.project_id is null)
    or not exists(select 1 from public.journal_lines l join public.accounts a on a.id=l.account_id where l.journal_entry_id=auto_expense.journal_entry_id and a.system_key='INPUT_VAT' and l.debit_minor=5 and l.project_id is null)
    or not exists(select 1 from public.journal_lines l join public.accounts a on a.id=l.account_id where l.journal_entry_id=auto_expense.journal_entry_id and a.system_key='SUPPLIER_PAYABLE' and l.credit_minor=106 and l.party_id=fixture.supplier_id and l.project_id is null)
    or (select sum(debit_minor-credit_minor) from public.journal_lines where journal_entry_id=auto_expense.journal_entry_id)<>0
    then raise exception 'AUTO Supplier Credit journal/VAT mismatch'; end if;
  if not exists(select 1 from public.journal_lines l join public.accounts a on a.id=l.account_id where l.journal_entry_id=manual_expense.journal_entry_id and a.system_key='INPUT_VAT' and l.debit_minor=47)
    or not exists(select 1 from public.journal_lines l join public.accounts a on a.id=l.account_id where l.journal_entry_id=manual_expense.journal_entry_id and a.system_key='SUPPLIER_PAYABLE' and l.credit_minor=1047 and l.party_id=fixture.supplier_id and l.project_id=fixture.project_id)
    then raise exception 'MANUAL Supplier Credit journal/VAT mismatch'; end if;
  if (select e.gross_amount_minor-coalesce(sum(case when p.status='POSTED' then a.allocated_amount_minor else 0 end),0) from public.expenses e left join public.supplier_payment_allocations a on a.expense_id=e.id left join public.supplier_payments p on p.id=a.supplier_payment_id where e.id=zero_expense.expense_id group by e.id)<>10000 then raise exception 'New Supplier Credit Expense unavailable as outstanding'; end if;

  set local role authenticated;
  begin
    perform public.post_expense(fixture.company_id,current_date,null,fixture.category_id,'No invoice VAT',1000,'AUTO_5',null,'SUPPLIER_CREDIT',null,null,fixture.supplier_id,'OTHER',false,null,null,gen_random_uuid()); raise exception 'VAT without invoice accepted';
  exception when check_violation then null;
  end;
  begin
    perform public.post_expense(fixture.company_id,current_date,null,fixture.category_id,'Missing method',1000,'ZERO',null,'SUPPLIER_CREDIT',null,null,fixture.supplier_id,null::public.payment_method,false,null,null,gen_random_uuid()); raise exception 'Missing payment_method accepted';
  exception when invalid_parameter_value then null;
  end;
  reset role;
  update public.parties set status='INACTIVE' where id=fixture.supplier_id;
  set local role authenticated;
  begin
    perform public.post_expense(fixture.company_id,current_date,null,fixture.category_id,'Inactive Supplier',1000,'ZERO',null,'SUPPLIER_CREDIT',null,null,fixture.supplier_id,'OTHER',false,null,null,gen_random_uuid()); raise exception 'Inactive Supplier accepted';
  exception when check_violation then null;
  end;
  reset role;
  update public.parties set status='ACTIVE' where id=fixture.supplier_id;
  update public.projects set status='CLOSED' where id=fixture.project_id;
  set local role authenticated;
  begin
    perform public.post_expense(fixture.company_id,current_date,fixture.project_id,fixture.category_id,'Closed Project',1000,'ZERO',null,'SUPPLIER_CREDIT',null,null,fixture.supplier_id,'OTHER',false,null,null,gen_random_uuid()); raise exception 'Closed Project accepted';
  exception when check_violation then null;
  end;
  reset role;
  update public.projects set status=fixture.original_project_status where id=fixture.project_id;

  foreach test_role in array enum_range(null::public.company_role) loop
    update public.company_memberships set role=test_role where company_id=fixture.company_id and user_id=fixture.user_id;
    set local role authenticated;
    if test_role in ('ACCOUNTING_ADMIN','ACCOUNTANT','MANAGEMENT_VIEWER') then
      if not exists(select 1 from public.expenses where id=zero_expense.expense_id) then raise exception 'Allowed role cannot read Expense: %',test_role; end if;
    elsif test_role<>'PROJECT_MANAGER' and exists(select 1 from public.expenses where id=zero_expense.expense_id) then raise exception 'Denied role read Expense: %',test_role;
    end if;
    if test_role not in ('ACCOUNTING_ADMIN','ACCOUNTANT') then
      begin
        perform public.post_expense(fixture.company_id,current_date,null,fixture.category_id,'Denied role',1000,'ZERO',null,'SUPPLIER_CREDIT',null,null,fixture.supplier_id,'OTHER',false,null,null,gen_random_uuid()); raise exception 'Denied role posted Supplier Credit Expense: %',test_role;
      exception when insufficient_privilege then null;
      end;
    elsif test_role='ACCOUNTANT' then
      perform public.post_expense(fixture.company_id,current_date,null,fixture.category_id,'Accountant allowed',1000,'ZERO',null,'SUPPLIER_CREDIT',null,null,fixture.supplier_id,'OTHER',false,null,null,gen_random_uuid());
    end if;
    reset role;
  end loop;
  update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id=fixture.company_id and user_id=fixture.user_id;
  update public.company_memberships set status='INACTIVE' where company_id=fixture.company_id and user_id=fixture.user_id;
  set local role authenticated;
  begin
    perform public.post_expense(fixture.company_id,current_date,null,fixture.category_id,'Inactive identity',1000,'ZERO',null,'SUPPLIER_CREDIT',null,null,fixture.supplier_id,'OTHER',false,null,null,gen_random_uuid()); raise exception 'Inactive identity posted Supplier Credit Expense';
  exception when insufficient_privilege then null;
  end;
  reset role;
  update public.company_memberships set status='ACTIVE' where company_id=fixture.company_id and user_id=fixture.user_id;
  select c.id into foreign_company from public.companies c where c.id<>fixture.company_id and not exists(select 1 from public.company_memberships m where m.company_id=c.id and m.user_id=fixture.user_id and m.status='ACTIVE') limit 1;
  set local role authenticated;
  begin
    perform public.post_expense(foreign_company,current_date,null,fixture.category_id,'Cross tenant',1000,'ZERO',null,'SUPPLIER_CREDIT',null,null,fixture.supplier_id,'OTHER',false,null,null,gen_random_uuid()); raise exception 'Cross-tenant Supplier Credit Expense allowed';
  exception when insufficient_privilege then null;
  end;
  select * into paid_expense from public.post_expense(fixture.company_id,current_date,fixture.project_id,fixture.category_id,'Paid dependency rollback',5000,'ZERO',null,'SUPPLIER_CREDIT',null,null,fixture.supplier_id,'TRANSFER',false,null,null,gen_random_uuid());
  select * into payment from public.post_supplier_payment(fixture.company_id,current_date,fixture.supplier_id,fixture.treasury_id,5000,'TRANSFER',null,null,jsonb_build_array(jsonb_build_object('expense_id',paid_expense.expense_id,'amount_minor',5000)),gen_random_uuid());
  begin
    perform public.reverse_expense(fixture.company_id,paid_expense.expense_id,current_date,'Active allocation',gen_random_uuid()); raise exception 'Expense reversal with active payment allocation allowed';
  exception when others then if sqlerrm not like 'Reverse active Supplier Payments before reversing this Supplier Credit Expense%' then raise; end if;
  end;
  reset role;
  update public.company_memberships set role=fixture.original_role where company_id=fixture.company_id and user_id=fixture.user_id;
  perform set_config('makeracc.p6d_supplier_credit_result',jsonb_build_object('exact_supplier_credit_shape',true,'exact_bigint',true,'zero_auto_manual_vat',true,'tax_invoice_enforced',true,'payment_method_required_preserved',true,'active_supplier_closed_project_enforced',true,'inactive_identity_denied',true,'post_roles',true,'read_rls',true,'tenant_isolation',true,'balanced_cost_vat_payable_journals',true,'party_project_dimensions',true,'idempotent_replay',true,'outstanding_available',true,'paid_expense_reversal_blocked',true)::text,true);
end;
$$;
set constraints all immediate;
select current_setting('makeracc.p6d_supplier_credit_result')::jsonb result;
rollback;
