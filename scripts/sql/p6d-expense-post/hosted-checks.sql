-- Development only. Reuse existing synthetic masters/actor; all command effects roll back.
begin;
do $$
declare
  fixture record;
  result record;
  replay record;
  doc public.expenses;
  request_key uuid := gen_random_uuid();
  before_count bigint;
  checked integer := 0;
  test_role public.company_role;
  foreign_company uuid;
  foreign_category uuid;
begin
  select m.user_id, m.role original_role, c.id company_id, t.id treasury_id, t.gl_account_id, t.project_id,
    cat.id category_id, cost.id cost_id, vat.id vat_id into fixture
  from public.company_memberships m join public.profiles p on p.user_id=m.user_id
  join public.companies c on c.id=m.company_id
  join public.treasury_accounts t on t.company_id=c.id and t.status='ACTIVE'
  join public.expense_categories cat on cat.company_id=c.id and cat.status='ACTIVE'
  join public.accounts cost on cost.company_id=c.id and cost.status='ACTIVE'
    and cost.system_key=case when t.project_id is null then 'COMPANY_EXPENSE'::public.system_account_key else 'PROJECT_COST'::public.system_account_key end
  join public.accounts vat on vat.company_id=c.id and vat.status='ACTIVE' and vat.system_key='INPUT_VAT'
  left join public.projects project on project.id=t.project_id
  where m.role in ('ACCOUNTING_ADMIN','ACCOUNTANT') and m.status='ACTIVE' and p.status='ACTIVE' and c.status='ACTIVE'
    and (t.project_id is null or project.status<>'CLOSED')
  order by m.role::text,c.id,t.id limit 1;
  if fixture.user_id is null then raise exception 'No existing synthetic posting fixture available'; end if;
  select count(*) into before_count from public.expenses;
  perform set_config('request.jwt.claim.sub',fixture.user_id::text,true);
  set local role authenticated;
  select * into result from public.post_expense(fixture.company_id,current_date,fixture.project_id,fixture.category_id,
    'P6D Treasury checkpoint rollback test',101,'AUTO_5',null,'TREASURY',fixture.treasury_id,null,null,'BANK',true,'P6D-ROLLBACK',null,request_key);
  select * into replay from public.post_expense(fixture.company_id,current_date,fixture.project_id,fixture.category_id,
    'P6D Treasury checkpoint rollback test',101,'AUTO_5',null,'TREASURY',fixture.treasury_id,null,null,'BANK',true,'P6D-ROLLBACK',null,request_key);
  if result.replayed or not replay.replayed or replay.expense_id<>result.expense_id or replay.journal_entry_id<>result.journal_entry_id then raise exception 'Replay failed'; end if;
  begin
    perform public.post_expense(fixture.company_id,current_date,fixture.project_id,fixture.category_id,
      'Changed payload',101,'AUTO_5',null,'TREASURY',fixture.treasury_id,null,null,'BANK',true,'P6D-ROLLBACK',null,request_key);
    raise exception 'Changed replay unexpectedly succeeded' using errcode='ZX001';
  exception when unique_violation then null;
  end;
  reset role;
  select * into doc from public.expenses where id=result.expense_id;
  if doc.net_amount_minor<>101 or doc.vat_amount_minor<>5 or doc.gross_amount_minor<>106 or doc.status<>'POSTED'
    or doc.funding_mode<>'TREASURY' or doc.posted_journal_entry_id<>result.journal_entry_id or doc.posted_by<>fixture.user_id
    or doc.project_id is distinct from fixture.project_id or doc.treasury_account_id<>fixture.treasury_id then raise exception 'Stored expense mismatch'; end if;
  if (select count(*) from public.expenses)<>before_count+1 then raise exception 'Duplicate expense'; end if;
  if (select count(*) from public.journal_lines where journal_entry_id=result.journal_entry_id)<>3
    or (select sum(debit_minor-credit_minor) from public.journal_lines where journal_entry_id=result.journal_entry_id)<>0 then raise exception 'Unbalanced or unexpected lines'; end if;
  if not exists(select 1 from public.journal_lines where journal_entry_id=result.journal_entry_id and account_id=fixture.cost_id and debit_minor=101 and credit_minor=0 and project_id is not distinct from fixture.project_id)
    or not exists(select 1 from public.journal_lines where journal_entry_id=result.journal_entry_id and account_id=fixture.vat_id and debit_minor=5 and credit_minor=0)
    or not exists(select 1 from public.journal_lines where journal_entry_id=result.journal_entry_id and account_id=fixture.gl_account_id and credit_minor=106 and debit_minor=0 and treasury_account_id=fixture.treasury_id)
    then raise exception 'Accounting effects mismatch'; end if;
  checked:=checked+1;
  set local role authenticated;
  select * into result from public.post_expense(fixture.company_id,current_date,fixture.project_id,fixture.category_id,
    'P6D exact large amount rollback',9000000000000000,'ZERO',null,'TREASURY',fixture.treasury_id,null,null,'OTHER',false,null,null,gen_random_uuid());
  reset role;
  if not exists(select 1 from public.expenses where id=result.expense_id and net_amount_minor::text='9000000000000000' and gross_amount_minor=net_amount_minor and vat_amount_minor=0) then raise exception 'BIGINT mismatch'; end if;
  checked:=checked+1;
  set local role authenticated;
  select * into result from public.post_expense(fixture.company_id,current_date,fixture.project_id,fixture.category_id,
    'P6D manual VAT rollback',1000,'MANUAL',47,'TREASURY',fixture.treasury_id,null,null,'TRANSFER',true,'MANUAL-ROLLBACK',null,gen_random_uuid());
  reset role;
  if not exists(select 1 from public.expenses where id=result.expense_id and vat_amount_minor=47 and gross_amount_minor=1047) then raise exception 'Manual VAT mismatch'; end if;
  checked:=checked+1;
  -- Exercise the existing synthetic actor under every role, inside this rollback only.
  foreach test_role in array enum_range(null::public.company_role) loop
    update public.company_memberships set role=test_role where company_id=fixture.company_id and user_id=fixture.user_id;
    set local role authenticated;
    begin
      perform public.post_expense(fixture.company_id,current_date,fixture.project_id,fixture.category_id,
        'P6D role rollback',100,'ZERO',null,'TREASURY',fixture.treasury_id,null,null,'CASH',false,null,null,gen_random_uuid());
      if test_role not in ('ACCOUNTING_ADMIN','ACCOUNTANT') then raise exception 'Denied role posted: %',test_role; end if;
    exception when insufficient_privilege then
      if test_role in ('ACCOUNTING_ADMIN','ACCOUNTANT') then raise; end if;
    end;
    reset role;
  end loop;
  update public.company_memberships set role=fixture.original_role where company_id=fixture.company_id and user_id=fixture.user_id;
  select c.id into foreign_company from public.companies c where c.id<>fixture.company_id
    and not exists(select 1 from public.company_memberships m where m.company_id=c.id and m.user_id=fixture.user_id and m.status='ACTIVE') limit 1;
  select id into foreign_category from public.expense_categories where company_id<>fixture.company_id limit 1;
  if foreign_company is null or foreign_category is null then raise exception 'Missing cross-tenant fixture'; end if;
  set local role authenticated;
  if exists(select 1 from public.expenses where company_id=foreign_company) then raise exception 'Cross-tenant Expense read'; end if;
  if not exists(select 1 from public.expenses where id=result.expense_id and company_id=fixture.company_id) then raise exception 'Authoritative readback denied'; end if;
  begin
    perform public.post_expense(foreign_company,current_date,null,fixture.category_id,
      'Cross tenant denied',100,'ZERO',null,'TREASURY',fixture.treasury_id,null,null,'CASH',false,null,null,gen_random_uuid());
    raise exception 'Cross-tenant command allowed';
  exception when insufficient_privilege then null;
  end;
  begin
    perform public.post_expense(fixture.company_id,current_date,fixture.project_id,foreign_category,
      'Cross dimension denied',100,'ZERO',null,'TREASURY',fixture.treasury_id,null,null,'CASH',false,null,null,gen_random_uuid());
    raise exception 'Cross-tenant dimension allowed';
  exception when foreign_key_violation then null;
  end;
  reset role;
  -- Empty actor cannot post, regardless of caller-supplied Company.
  perform set_config('request.jwt.claim.sub','',true);
  set local role authenticated;
  begin
    perform public.post_expense(fixture.company_id,current_date,fixture.project_id,fixture.category_id,
      'Denied',100,'ZERO',null,'TREASURY',fixture.treasury_id,null,null,'CASH',false,null,null,gen_random_uuid());
    raise exception 'Unauthenticated actor posted' using errcode='ZX001';
  exception when insufficient_privilege then null;
  end;
  reset role;
  perform set_config('makeracc.p6d_post_result',jsonb_build_object('posting_modes_checked',checked,'all_roles_checked',true,'cross_tenant_and_dimension_denied',true,'rls_readback',true,'auto_rounding_and_exact_lines',true,'same_key_single_effect',true,'changed_payload_denied',true,'bigint_exact',true,'missing_actor_denied',true)::text,true);
end;
$$;
set constraints all immediate;
select current_setting('makeracc.p6d_post_result')::jsonb result;
rollback;
