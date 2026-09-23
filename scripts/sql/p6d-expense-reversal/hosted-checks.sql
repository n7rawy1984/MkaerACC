-- Development only. Existing synthetic masters/actor; all setup, role changes and reversal effects roll back.
begin;
do $$
declare
  fixture record;
  posted record;
  reversed record;
  replay record;
  expense_before jsonb;
  expense_after public.expenses;
  journal_before jsonb;
  lines_before jsonb;
  test_role public.company_role;
  foreign_company uuid;
  draft_id uuid := gen_random_uuid();
  request_key uuid := gen_random_uuid();
begin
  select m.user_id,m.role original_role,c.id company_id,t.id treasury_id,t.project_id,cat.id category_id
  into fixture
  from public.company_memberships m
  join public.profiles p on p.user_id=m.user_id and p.status='ACTIVE'
  join public.companies c on c.id=m.company_id and c.status='ACTIVE'
  join public.treasury_accounts t on t.company_id=c.id and t.status='ACTIVE'
  join public.expense_categories cat on cat.company_id=c.id and cat.status='ACTIVE'
  join public.accounts cost on cost.company_id=c.id and cost.status='ACTIVE'
    and cost.system_key=case when t.project_id is null then 'COMPANY_EXPENSE'::public.system_account_key else 'PROJECT_COST'::public.system_account_key end
  left join public.projects project on project.id=t.project_id
  where m.status='ACTIVE' and (t.project_id is null or project.status<>'CLOSED')
  order by c.id,m.user_id,t.id limit 1;
  if fixture.user_id is null then raise exception 'No existing synthetic reversal fixture'; end if;
  update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id=fixture.company_id and user_id=fixture.user_id;
  perform set_config('request.jwt.claim.sub',fixture.user_id::text,true);
  set local role authenticated;
  select * into posted from public.post_expense(fixture.company_id,current_date,fixture.project_id,fixture.category_id,
    'P6D reversal exact BIGINT rollback fixture',9000000000000000,'ZERO',null,'TREASURY',fixture.treasury_id,
    null,null,'OTHER',false,null,null,gen_random_uuid());
  reset role;

  select to_jsonb(e) into expense_before from public.expenses e where e.id=posted.expense_id;
  select to_jsonb(j) into journal_before from public.journal_entries j where j.id=posted.journal_entry_id;
  select jsonb_agg(to_jsonb(l) order by l.line_number) into lines_before from public.journal_lines l where l.journal_entry_id=posted.journal_entry_id;

  -- Only ACCOUNTING_ADMIN owns accounting.reverse. Every other current role is denied.
  foreach test_role in array enum_range(null::public.company_role) loop
    if test_role<>'ACCOUNTING_ADMIN' then
      update public.company_memberships set role=test_role where company_id=fixture.company_id and user_id=fixture.user_id;
      set local role authenticated;
      begin
        perform public.reverse_expense(fixture.company_id,posted.expense_id,current_date,'Denied role',gen_random_uuid());
        raise exception 'Denied role reversed Expense: %',test_role;
      exception when insufficient_privilege then null;
      end;
      reset role;
    end if;
  end loop;
  update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id=fixture.company_id and user_id=fixture.user_id;

  select c.id into foreign_company from public.companies c where c.id<>fixture.company_id
    and not exists(select 1 from public.company_memberships m where m.company_id=c.id and m.user_id=fixture.user_id and m.status='ACTIVE') limit 1;
  if foreign_company is null then raise exception 'No foreign Company fixture'; end if;
  set local role authenticated;
  if exists(select 1 from public.expenses where company_id=foreign_company) then raise exception 'Cross-tenant Expense read allowed'; end if;
  begin
    perform public.reverse_expense(foreign_company,posted.expense_id,current_date,'Cross tenant',gen_random_uuid());
    raise exception 'Cross-tenant reversal allowed';
  exception when insufficient_privilege then null;
  end;

  select * into reversed from public.reverse_expense(fixture.company_id,posted.expense_id,current_date,'  Exact reversal rollback  ',request_key);
  select * into replay from public.reverse_expense(fixture.company_id,posted.expense_id,current_date,'Exact reversal rollback',request_key);
  if reversed.replayed or not replay.replayed or replay.expense_id<>reversed.expense_id
    or replay.reversal_journal_entry_id<>reversed.reversal_journal_entry_id then raise exception 'Idempotent replay mismatch'; end if;
  begin
    perform public.reverse_expense(fixture.company_id,posted.expense_id,current_date,'Changed reason',request_key);
    raise exception 'Changed-payload replay allowed';
  exception when unique_violation then null;
  end;
  select * into expense_after from public.expenses where id=posted.expense_id;
  if expense_after.status<>'REVERSED' or expense_after.reversal_journal_entry_id<>reversed.reversal_journal_entry_id
    or expense_after.reversed_by<>fixture.user_id then raise exception 'Authoritative reversed state mismatch'; end if;
  if (to_jsonb(expense_after)-array['status','reversal_journal_entry_id','reversed_at','reversed_by','updated_at','updated_by'])
      <> (expense_before-array['status','reversal_journal_entry_id','reversed_at','reversed_by','updated_at','updated_by'])
    then raise exception 'Original Expense economics/provenance mutated'; end if;
  if expense_after.net_amount_minor::text<>'9000000000000000' or expense_after.gross_amount_minor::text<>'9000000000000000'
    then raise exception 'Expense BIGINT precision changed'; end if;
  if (select to_jsonb(j) from public.journal_entries j where j.id=posted.journal_entry_id)<>journal_before
    or (select jsonb_agg(to_jsonb(l) order by l.line_number) from public.journal_lines l where l.journal_entry_id=posted.journal_entry_id)<>lines_before
    then raise exception 'Original journal mutated'; end if;
  if not exists(select 1 from public.journal_entries r where r.id=reversed.reversal_journal_entry_id
      and r.company_id=fixture.company_id and r.source_type='JOURNAL_REVERSAL' and r.source_id=posted.journal_entry_id
      and r.posting_purpose='REVERSAL' and r.reversal_of_journal_entry_id=posted.journal_entry_id)
    then raise exception 'Reversal journal linkage mismatch'; end if;
  if (select count(*) from public.journal_lines where journal_entry_id=reversed.reversal_journal_entry_id)
      <> (select count(*) from public.journal_lines where journal_entry_id=posted.journal_entry_id)
    or exists(select 1 from public.journal_lines o join public.journal_lines r on r.journal_entry_id=reversed.reversal_journal_entry_id and r.line_number=o.line_number
      where o.journal_entry_id=posted.journal_entry_id and (r.account_id<>o.account_id or r.debit_minor<>o.credit_minor or r.credit_minor<>o.debit_minor
        or r.project_id is distinct from o.project_id or r.party_id is distinct from o.party_id
        or r.treasury_account_id is distinct from o.treasury_account_id or r.subcontract_id is distinct from o.subcontract_id
        or r.memo is distinct from case when o.memo is null then null else 'Reversal: '||o.memo end))
    then raise exception 'Reversal lines are not exact opposites'; end if;
  if (select sum(debit_minor-credit_minor) from public.journal_lines where journal_entry_id=reversed.reversal_journal_entry_id)<>0
    or not exists(select 1 from public.journal_lines where journal_entry_id=reversed.reversal_journal_entry_id and debit_minor=9000000000000000)
    then raise exception 'Reversal balance or BIGINT precision mismatch'; end if;
  if not exists(select 1 from public.expenses where id=posted.expense_id and status='REVERSED'
      and reversal_journal_entry_id=reversed.reversal_journal_entry_id) then raise exception 'RLS readback failed'; end if;
  begin
    perform public.reverse_expense(fixture.company_id,posted.expense_id,current_date,'Second reversal',gen_random_uuid());
    raise exception 'Reversed Expense accepted again';
  exception when check_violation then null;
  end;
  reset role;

  -- DRAFT is internal/unreachable through browser commands, but remains ineligible.
  insert into public.expenses(id,company_id,expense_reference,expense_date,project_id,expense_category_id,supplier_id,description,
    net_amount_minor,vat_mode,vat_amount_minor,gross_amount_minor,funding_mode,treasury_account_id,paid_by_party_id,payment_method,
    has_tax_invoice,invoice_number,notes,status,created_by,updated_by)
  select draft_id,company_id,'P6D-DRAFT-'||draft_id::text,expense_date,project_id,expense_category_id,supplier_id,'Rollback draft lifecycle check',
    net_amount_minor,vat_mode,vat_amount_minor,gross_amount_minor,funding_mode,treasury_account_id,paid_by_party_id,payment_method,
    has_tax_invoice,invoice_number,notes,'DRAFT',created_by,updated_by from public.expenses where id=posted.expense_id;
  set local role authenticated;
  begin
    perform public.reverse_expense(fixture.company_id,draft_id,current_date,'Draft denied',gen_random_uuid());
    raise exception 'DRAFT Expense reversed';
  exception when check_violation then null;
  end;
  reset role;

  perform set_config('request.jwt.claim.sub','',true);
  set local role authenticated;
  begin
    perform public.reverse_expense(fixture.company_id,posted.expense_id,current_date,'Missing actor',gen_random_uuid());
    raise exception 'Missing actor reversed Expense';
  exception when insufficient_privilege then null;
  end;
  reset role;
  update public.company_memberships set role=fixture.original_role where company_id=fixture.company_id and user_id=fixture.user_id;
  perform set_config('makeracc.p6d_reverse_result',jsonb_build_object(
    'exact_five_input_command',true,'posted_allowed_draft_reversed_denied',true,'accounting_admin_only',true,
    'cross_tenant_rls_denied',true,'exact_opposite_balanced_lines',true,'original_expense_journal_immutable',true,
    'bigint_exact',true,'same_key_replayed',true,'changed_payload_denied',true,'authoritative_readback',true)::text,true);
end;
$$;
set constraints all immediate;
select current_setting('makeracc.p6d_reverse_result')::jsonb result;
rollback;
