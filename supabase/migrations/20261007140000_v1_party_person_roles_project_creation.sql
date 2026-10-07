-- V1 bounded person capabilities: primary Party type remains authoritative and immutable.
create table public.party_person_roles (
 company_id uuid not null references public.companies(id) on delete restrict,
 party_id uuid not null,
 role public.party_type not null check(role in ('EMPLOYEE','CUSTODIAN')),
 created_at timestamptz not null default now(),
 created_by uuid not null references auth.users(id) on delete restrict,
 primary key(company_id,party_id,role),
 foreign key(company_id,party_id) references public.parties(company_id,id) on delete restrict
);
alter table public.party_person_roles enable row level security;
alter table public.party_person_roles force row level security;
revoke all on public.party_person_roles from public,anon,authenticated,service_role;
grant select on public.party_person_roles to authenticated,service_role;

create function private.party_has_person_role(c uuid,pid uuid,r public.party_type)
returns boolean language sql stable security definer set search_path='' as $$
 select r in ('EMPLOYEE','CUSTODIAN') and exists (
  select 1 from public.parties p where p.company_id=c and p.id=pid
  and p.type in ('EMPLOYEE','CUSTODIAN') and (p.type=r or exists(
   select 1 from public.party_person_roles pr where pr.company_id=c and pr.party_id=pid and pr.role=r))
 );
$$;
revoke all on function private.party_has_person_role(uuid,uuid,public.party_type) from public,anon,authenticated,service_role;
-- Policy calls use stored function identity; private schema remains inaccessible to browser RPCs.
grant execute on function private.party_has_person_role(uuid,uuid,public.party_type) to authenticated;

create function private.validate_party_person_role() returns trigger
language plpgsql set search_path='' as $$
declare base public.party_type;
begin
 if tg_op <> 'INSERT' then raise exception 'Person role history is immutable' using errcode='23514'; end if;
 select type into base from public.parties where company_id=new.company_id and id=new.party_id for share;
 if base is null or base not in ('EMPLOYEE','CUSTODIAN') or base=new.role then
  raise exception 'Only the opposite Employee/Custodian capability is supported' using errcode='23514'; end if;
 return new;
end;$$;
revoke all on function private.validate_party_person_role() from public,anon,authenticated,service_role;
create trigger party_person_roles_guard before insert or update or delete on public.party_person_roles
 for each row execute function private.validate_party_person_role();
create policy party_person_roles_read on public.party_person_roles for select to authenticated
 using(exists(select 1 from public.parties p where p.company_id=party_person_roles.company_id and p.id=party_person_roles.party_id));

-- Employee-sensitive identity stays hidden from operational readers even with CUSTODIAN primary type.
drop policy parties_read_sensitive_roles on public.parties;
create policy parties_read_sensitive_roles on public.parties for select to authenticated using (
 public.has_company_role(company_id,'ACCOUNTING_ADMIN') or public.has_company_role(company_id,'ACCOUNTANT')
 or public.has_company_role(company_id,'MANAGEMENT_VIEWER') or (
  type not in ('OWNER','EMPLOYEE') and not private.party_has_person_role(company_id,id,'EMPLOYEE')
  and (public.has_company_role(company_id,'PROCUREMENT') or public.has_company_role(company_id,'DATA_ENTRY'))
 ));

create function public.add_party_person_role(target_company_id uuid,target_party_id uuid,target_role public.party_type)
returns uuid language plpgsql security definer set search_path='' as $$
declare base public.party_type;
begin
 if auth.uid() is null or not public.has_company_role(target_company_id,'ACCOUNTING_ADMIN')
 or not public.has_permission(target_company_id,'party.manage') then raise exception 'Role assignment denied' using errcode='42501'; end if;
 if target_role is null or target_role not in ('EMPLOYEE','CUSTODIAN') then raise exception 'Unsupported person role' using errcode='23514'; end if;
 select type into base from public.parties where company_id=target_company_id and id=target_party_id and status='ACTIVE' for update;
 if base is null or base not in ('EMPLOYEE','CUSTODIAN') then raise exception 'Same-Company active person required' using errcode='23514'; end if;
 if base<>target_role then insert into public.party_person_roles(company_id,party_id,role,created_by)
 values(target_company_id,target_party_id,target_role,auth.uid()) on conflict do nothing; end if;
 return target_party_id;
end;$$;

create function public.create_person_party(target_company_id uuid,business_input jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare v jsonb:=business_input; k text; pid uuid; base public.party_type; kind text;
 trim_chars text := E' \t\n\r\f' || chr(11) || chr(160) || chr(5760)
  || chr(8192) || chr(8193) || chr(8194) || chr(8195) || chr(8196) || chr(8197)
  || chr(8198) || chr(8199) || chr(8200) || chr(8201) || chr(8202)
  || chr(8232) || chr(8233) || chr(8239) || chr(8287) || chr(12288) || chr(65279);

begin
 if auth.uid() is null or not public.has_company_role(target_company_id,'ACCOUNTING_ADMIN')
 or not public.has_permission(target_company_id,'party.manage') then raise exception 'Creation denied' using errcode='42501'; end if;
 if v is null or jsonb_typeof(v)<>'object' then raise exception 'Invalid input' using errcode='22023'; end if;
 for k in select jsonb_object_keys(v) loop
  if k<>all(array['name','code','status','kind','notes']) or jsonb_typeof(v->k) not in ('string','null') then raise exception 'Invalid input' using errcode='22023'; end if;
  v:=jsonb_set(v,array[k],coalesce(to_jsonb(nullif(btrim(v->>k,trim_chars),'')),'null'::jsonb));
 end loop;
 kind:=v->>'kind';
 if kind is null or kind not in ('EMPLOYEE','CUSTODIAN','EMPLOYEE_CUSTODIAN') or v->>'name' is null
 or v->>'status' is null or v->>'status' not in ('ACTIVE','INACTIVE') then raise exception 'Invalid person' using errcode='23514'; end if;
 base:=case when kind='CUSTODIAN' then 'CUSTODIAN'::public.party_type else 'EMPLOYEE'::public.party_type end;
 insert into public.parties(company_id,type,name,code,status,notes,created_by,updated_by)
 values(target_company_id,base,v->>'name',v->>'code',(v->>'status')::public.account_status,v->>'notes',auth.uid(),auth.uid()) returning id into pid;
 if kind='EMPLOYEE_CUSTODIAN' then insert into public.party_person_roles(company_id,party_id,role,created_by)
 values(target_company_id,pid,'CUSTODIAN',auth.uid()); end if;
 return pid;
end;$$;

create function public.create_project(target_company_id uuid,business_input jsonb)
returns uuid language plpgsql security definer set search_path='' as $$
declare v jsonb:=business_input; k text; pid uuid;
 trim_chars text := E' \t\n\r\f' || chr(11) || chr(160) || chr(5760)
  || chr(8192) || chr(8193) || chr(8194) || chr(8195) || chr(8196) || chr(8197)
  || chr(8198) || chr(8199) || chr(8200) || chr(8201) || chr(8202)
  || chr(8232) || chr(8233) || chr(8239) || chr(8287) || chr(12288) || chr(65279);
begin
 if auth.uid() is null or not public.has_company_role(target_company_id,'ACCOUNTING_ADMIN')
 or not public.has_permission(target_company_id,'project.manage') then raise exception 'Creation denied' using errcode='42501'; end if;
 if v is null or jsonb_typeof(v)<>'object' then raise exception 'Invalid input' using errcode='22023'; end if;
 for k in select jsonb_object_keys(v) loop
  if k<>all(array['code','name','status','client_name','location','contract_number','notes']) or jsonb_typeof(v->k) not in ('string','null') then raise exception 'Invalid input' using errcode='22023'; end if;
  v:=jsonb_set(v,array[k],coalesce(to_jsonb(nullif(btrim(v->>k,trim_chars),'')),'null'::jsonb));
 end loop;
 if v->>'code' is null or v->>'name' is null or v->>'status' is null
 or v->>'status' not in ('PLANNING','ACTIVE','ON_HOLD','COMPLETED','CLOSED') then raise exception 'Invalid Project' using errcode='23514'; end if;
 insert into public.projects(company_id,code,name,status,client_name,location,contract_number,notes,created_by,updated_by)
 values(target_company_id,v->>'code',v->>'name',(v->>'status')::public.project_status,v->>'client_name',v->>'location',v->>'contract_number',v->>'notes',auth.uid(),auth.uid()) returning id into pid;
 return pid;
end;$$;
revoke all on function public.create_person_party(uuid,jsonb),public.create_project(uuid,jsonb),public.add_party_person_role(uuid,uuid,public.party_type) from public,anon,authenticated,service_role;
grant execute on function public.create_person_party(uuid,jsonb),public.create_project(uuid,jsonb),public.add_party_person_role(uuid,uuid,public.party_type) to authenticated;


-- Role eligibility adapters: preserve every other command/recognition/reversal statement and existing grants.

CREATE OR REPLACE FUNCTION private.payroll_profile_employee_guard()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 if not exists(select 1 from public.parties where company_id=new.company_id and id=new.employee_id and private.party_has_person_role(company_id,id,'EMPLOYEE')) then
  raise exception 'Same-Company EMPLOYEE required' using errcode='23514'; end if;
 if tg_op='UPDATE' and (new.id,new.company_id,new.employee_id,new.created_by,new.created_at) is distinct from (old.id,old.company_id,old.employee_id,old.created_by,old.created_at) then
  raise exception 'Profile identity immutable' using errcode='23514'; end if;
 return new;
end $function$;

CREATE OR REPLACE FUNCTION private.post_expense(target_company_id uuid, target_expense_date date, target_project_id uuid, target_expense_category_id uuid, target_description text, target_net_amount_minor bigint, target_vat_mode expense_vat_mode, target_manual_vat_amount_minor bigint, target_funding_mode expense_funding_mode, target_treasury_account_id uuid, target_paid_by_party_id uuid, target_supplier_id uuid, target_payment_method payment_method, target_has_tax_invoice boolean, target_invoice_number text, target_notes text, target_idempotency_key uuid)
 RETURNS TABLE(expense_id uuid, expense_reference text, journal_entry_id uuid, replayed boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  actor_id uuid := auth.uid();
  normalized_description text := btrim(target_description);
  normalized_invoice_number text := nullif(btrim(target_invoice_number), '');
  normalized_notes text := nullif(btrim(target_notes), '');
  request_hash text;
  request_row private.financial_command_requests;
  project_status public.project_status;
  category_status public.account_status;
  treasury_row public.treasury_accounts;
  funding_party public.parties;
  supplier_row public.parties;
  cost_account_id uuid;
  input_vat_account_id uuid;
  credit_account_id uuid;
  calculated_vat_minor bigint;
  calculated_gross numeric;
  new_expense_id uuid := gen_random_uuid();
  new_expense_reference text;
  new_journal_id uuid;
  journal_lines jsonb;
begin
  if actor_id is null or not public.has_permission(target_company_id, 'accounting.post') then
    raise exception 'Not authorized to post expenses' using errcode = '42501';
  end if;
  if target_company_id is null or target_expense_category_id is null or target_vat_mode is null
     or target_funding_mode is null or target_payment_method is null
     or target_has_tax_invoice is null or target_idempotency_key is null then
    raise exception 'Required Expense command input is missing' using errcode = '22023';
  end if;
  if target_expense_date is null or normalized_description is null or length(normalized_description) not between 1 and 1000 then
    raise exception 'Expense date and description are required' using errcode = '22023';
  end if;
  if target_net_amount_minor is null or target_net_amount_minor not between 1 and 9000000000000000 then
    raise exception 'Expense net amount is invalid' using errcode = '22023';
  end if;

  if target_project_id is not null then
    select p.status into project_status from public.projects p
    where p.company_id = target_company_id and p.id = target_project_id;
    if project_status is null then raise exception 'Project does not belong to company' using errcode = '23503'; end if;
    if project_status = 'CLOSED' then raise exception 'Closed project cannot receive a new expense' using errcode = '23514'; end if;
  end if;
  select c.status into category_status from public.expense_categories c
  where c.company_id = target_company_id and c.id = target_expense_category_id;
  if category_status is null then raise exception 'Expense category does not belong to company' using errcode = '23503'; end if;
  if category_status <> 'ACTIVE' then raise exception 'Expense category is inactive' using errcode = '23514'; end if;

  if target_vat_mode = 'ZERO' then
    if coalesce(target_manual_vat_amount_minor, 0) <> 0 then raise exception 'ZERO VAT cannot include VAT amount' using errcode = '22023'; end if;
    calculated_vat_minor := 0;
  elsif target_vat_mode = 'AUTO_5' then
    if target_manual_vat_amount_minor is not null then raise exception 'AUTO_5 does not accept manual VAT' using errcode = '22023'; end if;
    calculated_vat_minor := round(target_net_amount_minor::numeric * 5 / 100)::bigint;
  else
    if target_manual_vat_amount_minor is null or target_manual_vat_amount_minor <= 0
       or target_manual_vat_amount_minor > target_net_amount_minor then
      raise exception 'Manual VAT amount is invalid' using errcode = '22023';
    end if;
    calculated_vat_minor := target_manual_vat_amount_minor;
  end if;
  if calculated_vat_minor > 0 and (not target_has_tax_invoice or normalized_invoice_number is null) then
    raise exception 'Recoverable Input VAT requires a valid tax invoice reference' using errcode = '23514';
  end if;
  if not target_has_tax_invoice and normalized_invoice_number is not null then
    raise exception 'Invoice number requires invoice confirmation' using errcode = '23514';
  end if;
  calculated_gross := target_net_amount_minor::numeric + calculated_vat_minor::numeric;
  if calculated_gross > 9000000000000000 then raise exception 'Expense gross amount is too large' using errcode = '22003'; end if;

  if target_supplier_id is not null then
    select p.* into supplier_row from public.parties p
    where p.company_id = target_company_id and p.id = target_supplier_id;
    if supplier_row.id is null or supplier_row.type <> 'SUPPLIER' then raise exception 'Supplier is invalid' using errcode = '23514'; end if;
    if supplier_row.status <> 'ACTIVE' then raise exception 'Supplier is inactive' using errcode = '23514'; end if;
  end if;

  if target_funding_mode = 'TREASURY' then
    if target_treasury_account_id is null or target_paid_by_party_id is not null then raise exception 'TREASURY funding shape is invalid' using errcode = '23514'; end if;
    select t.* into treasury_row from public.treasury_accounts t
    where t.company_id = target_company_id and t.id = target_treasury_account_id;
    if treasury_row.id is null then raise exception 'Treasury does not belong to company' using errcode = '23503'; end if;
    if treasury_row.status <> 'ACTIVE' then raise exception 'Treasury is inactive' using errcode = '23514'; end if;
    if treasury_row.project_id is not null and treasury_row.project_id is distinct from target_project_id then
      raise exception 'Project treasury can be used only for its project' using errcode = '23514';
    end if;
    credit_account_id := treasury_row.gl_account_id;
  elsif target_funding_mode in ('CUSTODIAN', 'OWNER') then
    if target_treasury_account_id is not null or target_paid_by_party_id is null then raise exception 'Party funding shape is invalid' using errcode = '23514'; end if;
    select p.* into funding_party from public.parties p
    where p.company_id = target_company_id and p.id = target_paid_by_party_id;
    if funding_party.id is null or not (funding_party.type::text = target_funding_mode::text or (target_funding_mode = 'CUSTODIAN' and private.party_has_person_role(target_company_id,funding_party.id,'CUSTODIAN'))) then
      raise exception 'Funding party has the wrong type' using errcode = '23514';
    end if;
    if funding_party.status <> 'ACTIVE' then raise exception 'Funding party is inactive' using errcode = '23514'; end if;
  else
    if target_treasury_account_id is not null or target_paid_by_party_id is not null
       or target_supplier_id is null then raise exception 'SUPPLIER_CREDIT funding shape is invalid' using errcode = '23514'; end if;
  end if;

  select a.id into cost_account_id from public.accounts a
  where a.company_id = target_company_id
    and a.system_key = case when target_project_id is null then 'COMPANY_EXPENSE'::public.system_account_key
                          else 'PROJECT_COST'::public.system_account_key end
    and a.status = 'ACTIVE';
  if cost_account_id is null then raise exception 'Required cost system account is unavailable' using errcode = '23514'; end if;
  if calculated_vat_minor > 0 then
    select a.id into input_vat_account_id from public.accounts a
    where a.company_id = target_company_id and a.system_key = 'INPUT_VAT' and a.status = 'ACTIVE';
    if input_vat_account_id is null then raise exception 'Input VAT system account is unavailable' using errcode = '23514'; end if;
  end if;
  if target_funding_mode = 'CUSTODIAN' then
    select a.id into credit_account_id from public.accounts a
    where a.company_id = target_company_id and a.system_key = 'CUSTODY_ADVANCE' and a.status = 'ACTIVE';
  elsif target_funding_mode = 'OWNER' then
    select a.id into credit_account_id from public.accounts a
    where a.company_id = target_company_id and a.system_key = 'OWNER_CURRENT' and a.status = 'ACTIVE';
  elsif target_funding_mode = 'SUPPLIER_CREDIT' then
    select a.id into credit_account_id from public.accounts a
    where a.company_id = target_company_id and a.system_key = 'SUPPLIER_PAYABLE' and a.status = 'ACTIVE';
  end if;
  if credit_account_id is null then raise exception 'Required funding system account is unavailable' using errcode = '23514'; end if;

  request_hash := encode(extensions.digest(convert_to(jsonb_build_object(
    'company_id', target_company_id, 'expense_date', target_expense_date, 'project_id', target_project_id,
    'category_id', target_expense_category_id, 'description', normalized_description,
    'net_minor', target_net_amount_minor, 'vat_mode', target_vat_mode, 'manual_vat_minor', target_manual_vat_amount_minor,
    'funding_mode', target_funding_mode, 'treasury_id', target_treasury_account_id,
    'paid_by_party_id', target_paid_by_party_id, 'supplier_id', target_supplier_id,
    'payment_method', target_payment_method, 'has_tax_invoice', target_has_tax_invoice,
    'invoice_number', normalized_invoice_number, 'notes', normalized_notes
  )::text, 'UTF8'), 'sha256'), 'hex');
  request_row := private.reserve_financial_command(
    target_company_id, 'POST_EXPENSE', target_idempotency_key, request_hash, actor_id
  );
  if request_row.status = 'COMPLETED' then
    return query select e.id, e.expense_reference, e.posted_journal_entry_id, true
    from public.expenses e where e.company_id = target_company_id
      and e.posted_journal_entry_id = request_row.resulting_journal_entry_id;
    return;
  end if;

  new_expense_reference := private.allocate_reference(
    target_company_id, 'EXP', extract(year from target_expense_date)::integer
  );
  insert into public.expenses (
    id, company_id, expense_reference, expense_date, project_id, expense_category_id,
    supplier_id, description, net_amount_minor, vat_mode, vat_amount_minor, gross_amount_minor,
    funding_mode, treasury_account_id, paid_by_party_id, payment_method, has_tax_invoice,
    invoice_number, notes, created_by, updated_by
  ) values (
    new_expense_id, target_company_id, new_expense_reference, target_expense_date, target_project_id,
    target_expense_category_id, target_supplier_id, normalized_description, target_net_amount_minor,
    target_vat_mode, calculated_vat_minor, calculated_gross::bigint, target_funding_mode,
    target_treasury_account_id, target_paid_by_party_id, target_payment_method,
    target_has_tax_invoice, normalized_invoice_number, normalized_notes, actor_id, actor_id
  );

  journal_lines := jsonb_build_array(jsonb_build_object(
    'account_id', cost_account_id, 'debit_minor', target_net_amount_minor, 'credit_minor', 0,
    'project_id', target_project_id
  ));
  if calculated_vat_minor > 0 then
    journal_lines := journal_lines || jsonb_build_array(jsonb_build_object(
      'account_id', input_vat_account_id, 'debit_minor', calculated_vat_minor, 'credit_minor', 0,
      'project_id', target_project_id
    ));
  end if;
  journal_lines := journal_lines || jsonb_build_array(jsonb_build_object(
    'account_id', credit_account_id, 'debit_minor', 0, 'credit_minor', calculated_gross::bigint,
    'project_id', target_project_id,
    'party_id', case when target_funding_mode = 'SUPPLIER_CREDIT' then target_supplier_id else target_paid_by_party_id end,
    'treasury_account_id', case when target_funding_mode = 'TREASURY' then target_treasury_account_id else null end
  ));
  new_journal_id := private.create_journal(
    target_company_id, target_expense_date, normalized_description, 'EXPENSE', new_expense_id,
    'ORIGINAL', journal_lines, actor_id, null
  );
  update public.expenses set status = 'POSTED', posted_journal_entry_id = new_journal_id,
    posted_at = now(), posted_by = actor_id, updated_by = actor_id
  where id = new_expense_id;
  perform private.complete_financial_command(request_row.id, new_journal_id);
  return query select new_expense_id, new_expense_reference, new_journal_id, false;
end;
$function$;

CREATE OR REPLACE FUNCTION public.finalize_custody_settlement(target_company_id uuid, target_settlement_date date, target_custodian_id uuid, target_expense_ids uuid[], target_expected_total_minor bigint, target_notes text)
 RETURNS TABLE(custody_settlement_id uuid, settlement_reference text, total_expenses_minor bigint)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  actor_id uuid := auth.uid(); normalized_notes text := nullif(btrim(target_notes), '');
  current_expense_id uuid; expense_row public.expenses; calculated_total numeric := 0;
  new_settlement_id uuid := gen_random_uuid(); new_reference text;
begin
  if actor_id is null or not public.has_permission(target_company_id, 'accounting.post') then
    raise exception 'Not authorized to finalize Custody Settlements' using errcode = '42501';
  end if;
  if target_company_id is null or target_settlement_date is null or target_custodian_id is null
     or target_expense_ids is null or cardinality(target_expense_ids) not between 1 and 999
     or target_expected_total_minor is null then
    raise exception 'Valid Custody Settlement inputs are required' using errcode = '22023';
  end if;
  if normalized_notes is not null and length(normalized_notes) > 2000 then
    raise exception 'Settlement notes are too long' using errcode = '22023';
  end if;
  if cardinality(target_expense_ids) <> (select count(distinct x) from unnest(target_expense_ids) x) then
    raise exception 'Settlement Expense list contains duplicates' using errcode = '22023';
  end if;
  perform 1 from public.parties p where p.company_id = target_company_id
    and p.id = target_custodian_id and private.party_has_person_role(p.company_id,p.id,'CUSTODIAN') for update;
  if not found then raise exception 'Custodian not found in company' using errcode = '23503'; end if;
  foreach current_expense_id in array (select array_agg(x order by x) from unnest(target_expense_ids) x) loop
    select e.* into expense_row from public.expenses e
    where e.company_id = target_company_id and e.id = current_expense_id for update;
    if not found or expense_row.status <> 'POSTED' or expense_row.funding_mode <> 'CUSTODIAN'
       or expense_row.paid_by_party_id is distinct from target_custodian_id then
      raise exception 'Expense is not eligible for this Custody Settlement' using errcode = '23514';
    end if;
    if exists (select 1 from public.custody_settlement_items i
      where i.expense_id = current_expense_id) then
      raise exception 'Expense is already included in a finalized Custody Settlement' using errcode = '23514';
    end if;
    calculated_total := calculated_total + expense_row.gross_amount_minor::numeric;
  end loop;
  if calculated_total <> target_expected_total_minor::numeric or calculated_total not between 1 and 9000000000000000 then
    raise exception 'Expected Settlement total does not match authoritative Expense total' using errcode = '23514';
  end if;
  new_reference := private.allocate_reference(target_company_id, 'CSTL', extract(year from target_settlement_date)::integer);
  insert into public.custody_settlements (id, company_id, settlement_reference, settlement_date,
    custodian_id, notes, total_expenses_minor, created_by)
  values (new_settlement_id, target_company_id, new_reference, target_settlement_date,
    target_custodian_id, normalized_notes, calculated_total::bigint, actor_id);
  foreach current_expense_id in array target_expense_ids loop
    select e.* into expense_row from public.expenses e where e.id = current_expense_id;
    insert into public.custody_settlement_items (company_id, settlement_id, expense_id, expense_amount_minor)
    values (target_company_id, new_settlement_id, current_expense_id, expense_row.gross_amount_minor);
  end loop;
  update public.custody_settlements set status = 'FINALIZED', finalized_at = now(), finalized_by = actor_id
  where id = new_settlement_id;
  return query select new_settlement_id, new_reference, calculated_total::bigint;
end;
$function$;

CREATE OR REPLACE FUNCTION public.post_custody_advance(target_company_id uuid, target_advance_date date, target_custodian_id uuid, target_treasury_account_id uuid, target_project_id uuid, target_amount_minor bigint, target_payment_method payment_method, target_external_reference text, target_notes text, target_idempotency_key uuid)
 RETURNS TABLE(custody_advance_id uuid, advance_reference text, journal_entry_id uuid, replayed boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  actor_id uuid := auth.uid();
  normalized_external_reference text := nullif(btrim(target_external_reference), '');
  normalized_notes text := nullif(btrim(target_notes), '');
  project_row public.projects;
  treasury_row public.treasury_accounts;
  custody_account_id uuid;
  request_hash text;
  request_row private.financial_command_requests;
  new_advance_id uuid := gen_random_uuid();
  new_advance_reference text;
  new_journal_id uuid;
  journal_lines jsonb;
begin
  if actor_id is null or not public.has_permission(target_company_id, 'accounting.post') then
    raise exception 'Not authorized to post Custody Advances' using errcode = '42501';
  end if;
  if target_company_id is null or target_advance_date is null or target_custodian_id is null
     or target_treasury_account_id is null or target_amount_minor is null
     or target_payment_method is null or target_idempotency_key is null then
    raise exception 'Required Custody Advance input is missing' using errcode = '22023';
  end if;
  if target_amount_minor not between 1 and 9000000000000000 then
    raise exception 'Custody Advance amount is invalid' using errcode = '22023';
  end if;
  if normalized_external_reference is not null and length(normalized_external_reference) > 200 then
    raise exception 'External reference is too long' using errcode = '22023';
  end if;
  if normalized_notes is not null and length(normalized_notes) > 2000 then
    raise exception 'Custody Advance notes are too long' using errcode = '22023';
  end if;

  perform 1 from public.parties p
  where p.company_id = target_company_id and p.id = target_custodian_id
    and private.party_has_person_role(p.company_id,p.id,'CUSTODIAN') and p.status = 'ACTIVE' for update;
  if not found then raise exception 'Active Custodian not found in company' using errcode = '23503'; end if;
  if target_project_id is not null then
    select p.* into project_row from public.projects p
    where p.company_id = target_company_id and p.id = target_project_id;
    if not found then raise exception 'Project not found in company' using errcode = '23503'; end if;
    if project_row.status = 'CLOSED' then
      raise exception 'Closed Project cannot receive a new Custody Advance' using errcode = '23514';
    end if;
  end if;
  select t.* into treasury_row from public.treasury_accounts t
  join public.accounts a on a.company_id = t.company_id and a.id = t.gl_account_id
  where t.company_id = target_company_id and t.id = target_treasury_account_id
    and t.status = 'ACTIVE' and a.status = 'ACTIVE' and a.account_type = 'ASSET';
  if not found then
    raise exception 'Active same-company Treasury with active Asset GL is required' using errcode = '23514';
  end if;
  if treasury_row.project_id is not null
     and treasury_row.project_id is distinct from target_project_id then
    raise exception 'Project Treasury may fund only its own Project custody'
      using errcode = '23514';
  end if;
  select a.id into custody_account_id from public.accounts a
  where a.company_id = target_company_id and a.system_key = 'CUSTODY_ADVANCE'
    and a.status = 'ACTIVE' and a.account_type = 'ASSET' and a.requires_party;
  if custody_account_id is null then
    raise exception 'Custody Advance system account is unavailable' using errcode = '23514';
  end if;

  request_hash := encode(extensions.digest(convert_to(jsonb_build_object(
    'company_id', target_company_id, 'advance_date', target_advance_date,
    'custodian_id', target_custodian_id, 'treasury_id', target_treasury_account_id,
    'project_id', target_project_id, 'amount_minor', target_amount_minor,
    'payment_method', target_payment_method, 'external_reference', normalized_external_reference,
    'notes', normalized_notes
  )::text, 'UTF8'), 'sha256'), 'hex');
  request_row := private.reserve_financial_command(
    target_company_id, 'POST_CUSTODY_ADVANCE', target_idempotency_key, request_hash, actor_id
  );
  if request_row.status = 'COMPLETED' then
    return query select a.id, a.advance_reference, a.posted_journal_entry_id, true
    from public.custody_advances a where a.company_id = target_company_id
      and a.posted_journal_entry_id = request_row.resulting_journal_entry_id;
    return;
  end if;

  new_advance_reference := private.allocate_reference(
    target_company_id, 'CADV', extract(year from target_advance_date)::integer
  );
  insert into public.custody_advances (
    id, company_id, advance_reference, advance_date, custodian_id, treasury_account_id,
    project_id, amount_minor, payment_method, external_reference, notes, created_by, updated_by
  ) values (
    new_advance_id, target_company_id, new_advance_reference, target_advance_date,
    target_custodian_id, target_treasury_account_id, target_project_id, target_amount_minor,
    target_payment_method, normalized_external_reference, normalized_notes, actor_id, actor_id
  );
  journal_lines := jsonb_build_array(
    jsonb_build_object(
      'account_id', custody_account_id, 'debit_minor', target_amount_minor, 'credit_minor', 0,
      'project_id', target_project_id, 'party_id', target_custodian_id,
      'memo', 'Custody funded'
    ),
    jsonb_build_object(
      'account_id', treasury_row.gl_account_id, 'debit_minor', 0, 'credit_minor', target_amount_minor,
      'project_id', target_project_id, 'treasury_account_id', target_treasury_account_id,
      'memo', 'Custody Advance treasury funding'
    )
  );
  new_journal_id := private.create_journal(
    target_company_id, target_advance_date, 'Custody Advance ' || new_advance_reference,
    'CUSTODY_ADVANCE', new_advance_id, 'ORIGINAL', journal_lines, actor_id, null
  );
  update public.custody_advances set status = 'POSTED', posted_journal_entry_id = new_journal_id,
    posted_at = now(), posted_by = actor_id, updated_by = actor_id where id = new_advance_id;
  perform private.complete_financial_command(request_row.id, new_journal_id);
  return query select new_advance_id, new_advance_reference, new_journal_id, false;
end;
$function$;

CREATE OR REPLACE FUNCTION public.post_custody_cash_return(target_company_id uuid, target_return_date date, target_custodian_id uuid, target_treasury_account_id uuid, target_amount_minor bigint, target_payment_method payment_method, target_external_reference text, target_notes text, target_idempotency_key uuid)
 RETURNS TABLE(custody_cash_return_id uuid, return_reference text, journal_entry_id uuid, replayed boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  actor_id uuid := auth.uid(); normalized_external_reference text := nullif(btrim(target_external_reference), '');
  normalized_notes text := nullif(btrim(target_notes), ''); treasury_row public.treasury_accounts;
  custody_account_id uuid; available_balance numeric; request_hash text;
  request_row private.financial_command_requests; new_return_id uuid := gen_random_uuid();
  new_reference text; new_journal_id uuid; journal_lines jsonb;
begin
  if actor_id is null or not public.has_permission(target_company_id, 'accounting.post') then
    raise exception 'Not authorized to post Custody Cash Returns' using errcode = '42501';
  end if;
  if target_company_id is null or target_return_date is null or target_custodian_id is null
     or target_treasury_account_id is null or target_amount_minor is null
     or target_payment_method is null or target_idempotency_key is null then
    raise exception 'Required Custody Cash Return input is missing' using errcode = '22023';
  end if;
  if target_amount_minor not between 1 and 9000000000000000 then
    raise exception 'Custody Cash Return amount is invalid' using errcode = '22023';
  end if;
  if normalized_external_reference is not null and length(normalized_external_reference) > 200 then
    raise exception 'External reference is too long' using errcode = '22023';
  end if;
  if normalized_notes is not null and length(normalized_notes) > 2000 then
    raise exception 'Cash Return notes are too long' using errcode = '22023';
  end if;
  perform 1 from public.parties p where p.company_id = target_company_id
    and p.id = target_custodian_id and private.party_has_person_role(p.company_id,p.id,'CUSTODIAN') for update;
  if not found then raise exception 'Custodian not found in company' using errcode = '23503'; end if;
  select t.* into treasury_row from public.treasury_accounts t
  join public.accounts a on a.company_id = t.company_id and a.id = t.gl_account_id
  where t.company_id = target_company_id and t.id = target_treasury_account_id
    and t.status = 'ACTIVE' and a.status = 'ACTIVE' and a.account_type = 'ASSET';
  if not found then raise exception 'Active same-company Treasury with active Asset GL is required' using errcode = '23514'; end if;
  available_balance := private.custody_balance_minor(target_company_id, target_custodian_id);
  if target_amount_minor::numeric > available_balance then
    raise exception 'Custody Cash Return exceeds available pooled Custody balance' using errcode = '23514';
  end if;
  select a.id into custody_account_id from public.accounts a where a.company_id = target_company_id
    and a.system_key = 'CUSTODY_ADVANCE' and a.status = 'ACTIVE'
    and a.account_type = 'ASSET' and a.requires_party;
  if custody_account_id is null then raise exception 'Custody Advance system account is unavailable' using errcode = '23514'; end if;
  request_hash := encode(extensions.digest(convert_to(jsonb_build_object(
    'company_id',target_company_id,'return_date',target_return_date,'custodian_id',target_custodian_id,
    'treasury_id',target_treasury_account_id,'amount_minor',target_amount_minor,
    'payment_method',target_payment_method,'external_reference',normalized_external_reference,'notes',normalized_notes
  )::text,'UTF8'),'sha256'),'hex');
  request_row := private.reserve_financial_command(target_company_id,'POST_CUSTODY_CASH_RETURN',
    target_idempotency_key,request_hash,actor_id);
  if request_row.status = 'COMPLETED' then
    return query select r.id,r.return_reference,r.posted_journal_entry_id,true from public.custody_cash_returns r
    where r.company_id=target_company_id and r.posted_journal_entry_id=request_row.resulting_journal_entry_id;
    return;
  end if;
  new_reference := private.allocate_reference(target_company_id,'CRET',extract(year from target_return_date)::integer);
  insert into public.custody_cash_returns (id,company_id,return_reference,return_date,custodian_id,
    treasury_account_id,amount_minor,payment_method,external_reference,notes,created_by,updated_by)
  values (new_return_id,target_company_id,new_reference,target_return_date,target_custodian_id,
    target_treasury_account_id,target_amount_minor,target_payment_method,normalized_external_reference,
    normalized_notes,actor_id,actor_id);
  journal_lines := jsonb_build_array(
    jsonb_build_object('account_id',treasury_row.gl_account_id,'debit_minor',target_amount_minor,'credit_minor',0,
      'treasury_account_id',target_treasury_account_id,'memo','Custody cash returned to Treasury'),
    jsonb_build_object('account_id',custody_account_id,'debit_minor',0,'credit_minor',target_amount_minor,
      'party_id',target_custodian_id,'memo','Custody Cash Return')
  );
  new_journal_id := private.create_journal(target_company_id,target_return_date,
    'Custody Cash Return '||new_reference,'CUSTODY_CASH_RETURN',new_return_id,'ORIGINAL',journal_lines,actor_id,null);
  update public.custody_cash_returns set status='POSTED',posted_journal_entry_id=new_journal_id,
    posted_at=now(),posted_by=actor_id,updated_by=actor_id where id=new_return_id;
  perform private.complete_financial_command(request_row.id,new_journal_id);
  return query select new_return_id,new_reference,new_journal_id,false;
end;
$function$;

CREATE OR REPLACE FUNCTION public.post_expense(target_company_id uuid, target_expense_date date, target_project_id uuid, target_expense_category_id uuid, target_description text, target_net_amount_minor bigint, target_vat_mode expense_vat_mode, target_manual_vat_amount_minor bigint, target_funding_mode expense_funding_mode, target_treasury_account_id uuid, target_paid_by_party_id uuid, target_supplier_id uuid, target_payment_method payment_method, target_has_tax_invoice boolean, target_invoice_number text, target_notes text, target_idempotency_key uuid)
 RETURNS TABLE(expense_id uuid, expense_reference text, journal_entry_id uuid, replayed boolean)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare
  actor_id uuid := auth.uid();
  requested_vat numeric;
  requested_gross numeric;
  available_balance numeric;
begin
  if target_funding_mode = 'CUSTODIAN' then
    if actor_id is null or not public.has_permission(target_company_id, 'accounting.post') then
      raise exception 'Not authorized to post expenses' using errcode = '42501';
    end if;
    perform 1 from public.parties p
    where p.company_id = target_company_id and p.id = target_paid_by_party_id
      and private.party_has_person_role(p.company_id,p.id,'CUSTODIAN') for update;
    if not found then raise exception 'Custodian not found in company' using errcode = '23503'; end if;
    requested_vat := case target_vat_mode
      when 'ZERO' then 0
      when 'AUTO_5' then round(target_net_amount_minor::numeric * 5 / 100)
      when 'MANUAL' then target_manual_vat_amount_minor::numeric
    end;
    requested_gross := target_net_amount_minor::numeric + requested_vat;
    available_balance := private.custody_balance_minor(target_company_id, target_paid_by_party_id);
    if requested_gross > available_balance then
      raise exception 'Custodian Expense exceeds available pooled Custody balance'
        using errcode = '23514';
    end if;
  end if;
  return query select * from private.post_expense(
    target_company_id, target_expense_date, target_project_id, target_expense_category_id,
    target_description, target_net_amount_minor, target_vat_mode, target_manual_vat_amount_minor,
    target_funding_mode, target_treasury_account_id, target_paid_by_party_id, target_supplier_id,
    target_payment_method, target_has_tax_invoice, target_invoice_number, target_notes,
    target_idempotency_key
  );
end;
$function$;

CREATE OR REPLACE FUNCTION public.read_payroll_profiles(target_company_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 if not public.has_permission(target_company_id,'payroll.manage') then raise exception 'Payroll denied' using errcode='42501'; end if;
 return jsonb_build_object('profiles',coalesce((select jsonb_agg((to_jsonb(p)-'monthly_salary_minor')||jsonb_build_object('monthly_salary_minor',p.monthly_salary_minor::text,'employee_name',e.name,'employee_status',e.status) order by p.payroll_id,p.id)
  from public.payroll_profiles p join public.parties e on e.company_id=p.company_id and e.id=p.employee_id where p.company_id=target_company_id),'[]'::jsonb),
  'employees',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name,id) from public.parties where company_id=target_company_id and private.party_has_person_role(company_id,id,'EMPLOYEE')),'[]'::jsonb),
  'projects',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name,id) from public.projects where company_id=target_company_id),'[]'::jsonb));
end $function$;

-- Attendance eligibility adapters: only Employee predicates change; assignment, scope, review and locks stay intact.
CREATE OR REPLACE FUNCTION private.validate_employee_site_assignment()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO ''
AS $function$
begin
 perform private.attendance_company_lock(new.company_id);
 if not exists(select 1 from public.parties where id=new.employee_id and company_id=new.company_id and private.party_has_person_role(company_id,id,'EMPLOYEE')) then
  raise exception 'Employee required' using errcode='23514'; end if;
 if tg_op='UPDATE' and (new.id,new.company_id,new.employee_id,new.project_id,new.starts_on,new.created_by,new.created_at)
  is distinct from (old.id,old.company_id,old.employee_id,old.project_id,old.starts_on,old.created_by,old.created_at) then
  raise exception 'Assignment identity is immutable' using errcode='23514'; end if;
 if exists(select 1 from public.employee_site_assignments a where a.company_id=new.company_id and a.employee_id=new.employee_id and a.id<>new.id
  and daterange(a.starts_on,a.ends_on,'[]') && daterange(new.starts_on,new.ends_on,'[]')) then
  raise exception 'Employee already assigned for these dates' using errcode='23514'; end if;
 if tg_op='INSERT' and exists(select 1 from public.attendance_periods p where p.company_id=new.company_id and p.locked_at is not null
  and daterange(p.month,(p.month+interval '1 month')::date,'[)') && daterange(new.starts_on,new.ends_on,'[]')) then
  raise exception 'Attendance month locked' using errcode='23514'; end if;
 if tg_op='UPDATE' then
  if new.ends_on is distinct from old.ends_on then
   if exists(select 1 from public.attendance_periods p where p.company_id=new.company_id and p.locked_at is not null
    and daterange(p.month,(p.month+interval '1 month')::date,'[)') &&
     daterange(least(coalesce(old.ends_on,'infinity'::date),coalesce(new.ends_on,'infinity'::date))+1,
               greatest(coalesce(old.ends_on,'infinity'::date),coalesce(new.ends_on,'infinity'::date)),'[]')) then
    raise exception 'Attendance month locked' using errcode='23514'; end if;
  end if;
  if exists(select 1 from public.attendance_exceptions e where e.company_id=old.company_id and e.employee_id=old.employee_id
    and e.project_id=old.project_id and e.absence_date between old.starts_on and coalesce(old.ends_on,'infinity'::date)
    and not (e.absence_date between new.starts_on and coalesce(new.ends_on,'infinity'::date))) then
   raise exception 'Assignment cannot strand attendance history' using errcode='23514'; end if;
 end if;
 return new;
end $function$;

CREATE OR REPLACE FUNCTION public.attendance_context(target_company_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE SECURITY DEFINER
 SET search_path TO ''
AS $function$
begin
 if not (private.attendance_staff(target_company_id) or public.has_permission(target_company_id,'attendance.record')) then
  raise exception 'Attendance access denied' using errcode='42501'; end if;
 return jsonb_build_object('today',(current_timestamp at time zone 'UTC')::date,'projects',coalesce((
  select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name) order by p.name,p.id) from public.projects p
  where p.company_id=target_company_id and (private.attendance_staff(target_company_id) or private.attendance_scope(target_company_id,p.id))),'[]'::jsonb),
  'employees',case when public.has_permission(target_company_id,'attendance.manage') then coalesce((
   select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name,id) from public.parties where company_id=target_company_id and private.party_has_person_role(company_id,id,'EMPLOYEE') and status='ACTIVE'),'[]'::jsonb) else '[]'::jsonb end);
end $function$;

CREATE OR REPLACE FUNCTION public.save_employee_site_assignment(target_company_id uuid, target_employee_id uuid, target_project_id uuid, target_starts_on date, target_ends_on date, target_assignment_id uuid DEFAULT NULL::uuid, target_version integer DEFAULT 0, target_reason text DEFAULT NULL::text)
 RETURNS uuid
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare result_id uuid; old_row public.employee_site_assignments;
begin
 if not public.has_permission(target_company_id,'attendance.manage') then raise exception 'Attendance administration denied' using errcode='42501'; end if;
 perform private.attendance_company_lock(target_company_id);
 if target_assignment_id is null then
  if not exists(select 1 from public.parties where company_id=target_company_id and id=target_employee_id and private.party_has_person_role(company_id,id,'EMPLOYEE') and status='ACTIVE')
   or not exists(select 1 from public.projects where company_id=target_company_id and id=target_project_id and status<>'CLOSED') then
   raise exception 'Eligible employee and project required' using errcode='23514'; end if;
  insert into public.employee_site_assignments(company_id,employee_id,project_id,starts_on,ends_on,created_by,updated_by)
   values(target_company_id,target_employee_id,target_project_id,target_starts_on,target_ends_on,auth.uid(),auth.uid()) returning id into result_id;
 else
  if nullif(btrim(target_reason),'') is null or length(target_reason)>1000 then raise exception 'Correction reason required' using errcode='23514'; end if;
  select * into old_row from public.employee_site_assignments where company_id=target_company_id and id=target_assignment_id for update;
  if not found or old_row.version<>target_version then raise exception 'Assignment changed; refresh' using errcode='40001'; end if;
  if (old_row.employee_id,old_row.project_id,old_row.starts_on) is distinct from (target_employee_id,target_project_id,target_starts_on) then
   raise exception 'Only assignment end date may change' using errcode='23514'; end if;
  update public.employee_site_assignments set ends_on=target_ends_on,version=version+1,updated_by=auth.uid(),updated_at=clock_timestamp()
   where id=target_assignment_id returning id into result_id;
  insert into public.attendance_audit(company_id,entity,entity_id,actor_id,after_row)
   values(target_company_id,'assignment_correction_reason',result_id::text,auth.uid(),jsonb_build_object('reason',btrim(target_reason)));
 end if;
 update public.attendance_periods set revision=revision+1,reviewed_revision=null,reviewed_at=null,reviewed_by=null
 where company_id=target_company_id and locked_at is null
  and (month+interval '1 month')::date>target_starts_on
  and month<=greatest(coalesce(target_ends_on,'infinity'::date),coalesce(old_row.ends_on,'infinity'::date));
 return result_id;
end $function$;

