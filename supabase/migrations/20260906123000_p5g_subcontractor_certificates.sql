-- P5G: Subcontractor Certificates, mapped deductions, Advance recovery,
-- Retention and residual payable recognition. No cash settlement is created.

create type public.subcontractor_certificate_status as enum ('DRAFT', 'POSTED', 'REVERSED');
create type public.certificate_deduction_type as enum ('COMPANY_MATERIALS', 'BACKCHARGE', 'OTHER');

create table public.certificate_deduction_account_mappings (
  company_id uuid not null references public.companies (id) on delete restrict,
  deduction_type public.certificate_deduction_type not null,
  account_id uuid not null,
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete restrict,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete restrict,
  primary key (company_id, deduction_type),
  constraint certificate_deduction_mapping_account_same_company foreign key (company_id, account_id)
    references public.accounts (company_id, id) on delete restrict
);

create table public.subcontractor_certificates (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  certificate_reference text not null check (length(btrim(certificate_reference)) between 1 and 100),
  contractor_certificate_number text not null check (length(btrim(contractor_certificate_number)) between 1 and 100),
  certificate_date date not null,
  project_id uuid not null,
  subcontractor_id uuid not null,
  subcontract_id uuid not null,
  work_value_to_date_minor bigint not null check (work_value_to_date_minor between 0 and 9000000000000000),
  current_variation_amount_minor bigint not null default 0 check (current_variation_amount_minor between 0 and 9000000000000000),
  requested_advance_recovery_minor bigint not null default 0 check (requested_advance_recovery_minor between 0 and 9000000000000000),
  vat_mode public.expense_vat_mode not null,
  manual_vat_amount_minor bigint check (manual_vat_amount_minor between 0 and 9000000000000000),
  tax_invoice_received boolean not null default false,
  tax_invoice_number text check (tax_invoice_number is null or length(btrim(tax_invoice_number)) between 1 and 200),
  tax_invoice_date date,
  notes text check (notes is null or length(btrim(notes)) between 1 and 2000),
  previous_certified_work_minor bigint,
  current_work_amount_minor bigint,
  gross_certified_minor bigint,
  retention_bps integer,
  retention_amount_minor bigint,
  advance_recovery_minor bigint,
  deductions_total_minor bigint,
  net_before_vat_minor bigint,
  vat_amount_minor bigint,
  payable_amount_minor bigint,
  status public.subcontractor_certificate_status not null default 'DRAFT',
  posted_journal_entry_id uuid,
  reversal_journal_entry_id uuid,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users (id) on delete restrict,
  approved_at timestamptz,
  approved_by uuid references auth.users (id) on delete restrict,
  reversed_at timestamptz,
  reversed_by uuid references auth.users (id) on delete restrict,
  reversal_reason text check (reversal_reason is null or length(btrim(reversal_reason)) between 1 and 1000),
  constraint subcontractor_certificates_company_id_id_unique unique (company_id, id),
  constraint subcontractor_certificates_company_reference_unique unique (company_id, certificate_reference),
  constraint subcontractor_certificates_contract_number_unique unique (subcontract_id, contractor_certificate_number),
  constraint subcontractor_certificates_identity foreign key
    (company_id, subcontract_id, project_id, subcontractor_id)
    references public.subcontracts (company_id, id, project_id, subcontractor_id) on delete restrict,
  constraint subcontractor_certificates_posted_journal_same_company foreign key (company_id, posted_journal_entry_id)
    references public.journal_entries (company_id, id) on delete restrict,
  constraint subcontractor_certificates_reversal_journal_same_company foreign key (company_id, reversal_journal_entry_id)
    references public.journal_entries (company_id, id) on delete restrict,
  constraint subcontractor_certificates_posted_journal_unique unique (posted_journal_entry_id),
  constraint subcontractor_certificates_reversal_journal_unique unique (reversal_journal_entry_id),
  constraint subcontractor_certificates_vat_input_shape check (
    (vat_mode = 'ZERO' and coalesce(manual_vat_amount_minor, 0) = 0)
    or (vat_mode = 'AUTO_5' and coalesce(manual_vat_amount_minor, 0) = 0)
    or (vat_mode = 'MANUAL' and manual_vat_amount_minor is not null)
  ),
  constraint subcontractor_certificates_state_shape check (
    (status = 'DRAFT' and previous_certified_work_minor is null and current_work_amount_minor is null
      and gross_certified_minor is null and retention_bps is null and retention_amount_minor is null
      and advance_recovery_minor is null and deductions_total_minor is null and net_before_vat_minor is null
      and vat_amount_minor is null and payable_amount_minor is null and posted_journal_entry_id is null
      and reversal_journal_entry_id is null and approved_at is null and approved_by is null
      and reversed_at is null and reversed_by is null and reversal_reason is null)
    or (status = 'POSTED' and previous_certified_work_minor is not null and current_work_amount_minor is not null
      and gross_certified_minor is not null and retention_bps is not null and retention_amount_minor is not null
      and advance_recovery_minor is not null and deductions_total_minor is not null and net_before_vat_minor is not null
      and vat_amount_minor is not null and payable_amount_minor is not null and posted_journal_entry_id is not null
      and reversal_journal_entry_id is null and approved_at is not null and approved_by is not null
      and reversed_at is null and reversed_by is null and reversal_reason is null)
    or (status = 'REVERSED' and previous_certified_work_minor is not null and current_work_amount_minor is not null
      and gross_certified_minor is not null and retention_bps is not null and retention_amount_minor is not null
      and advance_recovery_minor is not null and deductions_total_minor is not null and net_before_vat_minor is not null
      and vat_amount_minor is not null and payable_amount_minor is not null and posted_journal_entry_id is not null
      and reversal_journal_entry_id is not null and approved_at is not null and approved_by is not null
      and reversed_at is not null and reversed_by is not null and reversal_reason is not null)
  )
);

create table public.subcontractor_certificate_deductions (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null,
  certificate_id uuid not null,
  line_number smallint not null check (line_number between 1 and 100),
  deduction_type public.certificate_deduction_type not null,
  description text not null check (length(btrim(description)) between 1 and 500),
  amount_minor bigint not null check (amount_minor between 1 and 9000000000000000),
  account_id uuid not null,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users (id) on delete restrict,
  constraint subcontractor_certificate_deductions_company_id_id_unique unique (company_id, id),
  constraint subcontractor_certificate_deductions_line_unique unique (certificate_id, line_number),
  constraint subcontractor_certificate_deductions_certificate_same_company foreign key (company_id, certificate_id)
    references public.subcontractor_certificates (company_id, id) on delete restrict,
  constraint subcontractor_certificate_deductions_account_same_company foreign key (company_id, account_id)
    references public.accounts (company_id, id) on delete restrict
);

create index subcontractor_certificates_contract_date_idx
  on public.subcontractor_certificates (company_id, subcontract_id, certificate_date desc, id);
create index subcontractor_certificates_project_date_idx
  on public.subcontractor_certificates (company_id, project_id, certificate_date desc, id);

create function private.validate_certificate_deduction_mapping()
returns trigger language plpgsql set search_path = '' as $$
declare mapped_type public.account_type; mapped_status public.account_status;
begin
  select a.account_type, a.status into mapped_type, mapped_status from public.accounts a
  where a.company_id = new.company_id and a.id = new.account_id;
  if mapped_type is distinct from 'REVENUE' or mapped_status is distinct from 'ACTIVE' then
    raise exception 'Certificate deduction mapping requires an active REVENUE account' using errcode = '23514';
  end if;
  return new;
end;
$$;

create function private.protect_certificate_history()
returns trigger language plpgsql set search_path = '' as $$
begin
  if tg_op = 'DELETE' then raise exception 'Certificate history cannot be deleted' using errcode = '55000'; end if;
  if new.company_id <> old.company_id or new.certificate_reference <> old.certificate_reference
     or new.contractor_certificate_number <> old.contractor_certificate_number
     or new.certificate_date <> old.certificate_date or new.project_id <> old.project_id
     or new.subcontractor_id <> old.subcontractor_id or new.subcontract_id <> old.subcontract_id
     or new.work_value_to_date_minor <> old.work_value_to_date_minor
     or new.current_variation_amount_minor <> old.current_variation_amount_minor
     or new.requested_advance_recovery_minor <> old.requested_advance_recovery_minor
     or new.vat_mode <> old.vat_mode or new.manual_vat_amount_minor is distinct from old.manual_vat_amount_minor
     or new.tax_invoice_received <> old.tax_invoice_received
     or new.tax_invoice_number is distinct from old.tax_invoice_number
     or new.tax_invoice_date is distinct from old.tax_invoice_date or new.notes is distinct from old.notes
     or new.created_at <> old.created_at or new.created_by <> old.created_by then
    raise exception 'Certificate source economics and provenance are immutable' using errcode = '55000';
  end if;
  if old.status = 'DRAFT' then
    if new.status <> 'POSTED' or new.posted_journal_entry_id is null or new.reversal_journal_entry_id is not null then
      raise exception 'Certificate may transition only from DRAFT to POSTED' using errcode = '55000';
    end if;
  elsif old.status = 'POSTED' then
    if new.status <> 'REVERSED' or new.posted_journal_entry_id <> old.posted_journal_entry_id
       or new.reversal_journal_entry_id is null then
      raise exception 'Posted Certificate may transition only to REVERSED' using errcode = '55000';
    end if;
    if new.previous_certified_work_minor <> old.previous_certified_work_minor
       or new.current_work_amount_minor <> old.current_work_amount_minor
       or new.gross_certified_minor <> old.gross_certified_minor or new.retention_bps <> old.retention_bps
       or new.retention_amount_minor <> old.retention_amount_minor
       or new.advance_recovery_minor <> old.advance_recovery_minor
       or new.deductions_total_minor <> old.deductions_total_minor
       or new.net_before_vat_minor <> old.net_before_vat_minor or new.vat_amount_minor <> old.vat_amount_minor
       or new.payable_amount_minor <> old.payable_amount_minor then
      raise exception 'Posted Certificate calculations are immutable' using errcode = '55000';
    end if;
  else
    raise exception 'Reversed Certificate is immutable' using errcode = '55000';
  end if;
  return new;
end;
$$;

create function private.protect_certificate_deduction_history()
returns trigger language plpgsql set search_path = '' as $$
begin raise exception 'Certificate deductions are immutable' using errcode = '55000'; end;
$$;

create trigger certificate_deduction_mappings_validate before insert or update
  on public.certificate_deduction_account_mappings for each row
  execute function private.validate_certificate_deduction_mapping();
create trigger certificate_deduction_mappings_set_updated_at before update
  on public.certificate_deduction_account_mappings for each row execute function public.set_updated_at();
create trigger subcontractor_certificates_protect before update or delete on public.subcontractor_certificates
  for each row execute function private.protect_certificate_history();
create trigger subcontractor_certificate_deductions_protect before update or delete
  on public.subcontractor_certificate_deductions for each row
  execute function private.protect_certificate_deduction_history();

alter table public.certificate_deduction_account_mappings enable row level security;
alter table public.certificate_deduction_account_mappings force row level security;
alter table public.subcontractor_certificates enable row level security;
alter table public.subcontractor_certificates force row level security;
alter table public.subcontractor_certificate_deductions enable row level security;
alter table public.subcontractor_certificate_deductions force row level security;

create policy certificate_deduction_mappings_read_accounting on public.certificate_deduction_account_mappings
  for select to authenticated using (public.has_company_role(company_id,'ACCOUNTING_ADMIN')
    or public.has_company_role(company_id,'ACCOUNTANT') or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create policy subcontractor_certificates_read_accounting on public.subcontractor_certificates
  for select to authenticated using (public.has_company_role(company_id,'ACCOUNTING_ADMIN')
    or public.has_company_role(company_id,'ACCOUNTANT') or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create policy subcontractor_certificate_deductions_read_accounting on public.subcontractor_certificate_deductions
  for select to authenticated using (public.has_company_role(company_id,'ACCOUNTING_ADMIN')
    or public.has_company_role(company_id,'ACCOUNTANT') or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));

revoke all on table public.certificate_deduction_account_mappings from public,anon,authenticated,service_role;
revoke all on table public.subcontractor_certificates from public,anon,authenticated,service_role;
revoke all on table public.subcontractor_certificate_deductions from public,anon,authenticated,service_role;
grant select on table public.certificate_deduction_account_mappings to authenticated,service_role;
grant insert,update on table public.certificate_deduction_account_mappings to service_role;
revoke delete on table public.certificate_deduction_account_mappings from service_role;
grant select on table public.subcontractor_certificates to authenticated,service_role;
grant select on table public.subcontractor_certificate_deductions to authenticated,service_role;

create function public.create_subcontractor_certificate_draft(
  target_company_id uuid, target_certificate_date date, target_subcontract_id uuid,
  target_contractor_certificate_number text, target_work_value_to_date_minor bigint,
  target_current_variation_amount_minor bigint, target_advance_recovery_minor bigint,
  target_vat_mode public.expense_vat_mode, target_manual_vat_amount_minor bigint,
  target_tax_invoice_received boolean, target_tax_invoice_number text, target_tax_invoice_date date,
  target_deductions jsonb, target_notes text
)
returns table (subcontractor_certificate_id uuid, certificate_reference text)
language plpgsql security definer set search_path = '' as $$
declare
  actor_id uuid := auth.uid(); subcontract_row public.subcontracts; new_id uuid := gen_random_uuid();
  new_reference text; normalized_number text := btrim(target_contractor_certificate_number);
  normalized_invoice text := nullif(btrim(target_tax_invoice_number),''); normalized_notes text := nullif(btrim(target_notes),'');
  item jsonb; item_type public.certificate_deduction_type; item_description text; item_amount bigint;
  mapped_account_id uuid; line_no integer := 0;
begin
  if actor_id is null or not (public.has_company_role(target_company_id,'ACCOUNTING_ADMIN')
      or public.has_company_role(target_company_id,'ACCOUNTANT')) then
    raise exception 'Not authorized to prepare Subcontractor Certificates' using errcode = '42501';
  end if;
  if target_company_id is null or target_certificate_date is null or target_subcontract_id is null
     or normalized_number is null or length(normalized_number) not between 1 and 100
     or target_work_value_to_date_minor is null or target_current_variation_amount_minor is null
     or target_advance_recovery_minor is null or target_vat_mode is null
     or target_tax_invoice_received is null or target_deductions is null
     or jsonb_typeof(target_deductions) <> 'array' or jsonb_array_length(target_deductions) > 100 then
    raise exception 'Valid Certificate draft inputs are required' using errcode = '22023';
  end if;
  if target_work_value_to_date_minor not between 0 and 9000000000000000
     or target_current_variation_amount_minor not between 0 and 9000000000000000
     or target_advance_recovery_minor not between 0 and 9000000000000000
     or coalesce(target_manual_vat_amount_minor,0) not between 0 and 9000000000000000 then
    raise exception 'Certificate money input is invalid' using errcode = '22023';
  end if;
  if target_vat_mode <> 'MANUAL' and coalesce(target_manual_vat_amount_minor,0) <> 0 then
    raise exception 'Manual VAT amount is valid only in MANUAL mode' using errcode = '22023';
  end if;
  if target_vat_mode = 'MANUAL' and target_manual_vat_amount_minor is null then
    raise exception 'MANUAL VAT requires an amount' using errcode = '22023';
  end if;
  if normalized_invoice is not null and length(normalized_invoice) > 200 then raise exception 'Tax invoice number is too long' using errcode='22023'; end if;
  if normalized_notes is not null and length(normalized_notes) > 2000 then raise exception 'Certificate notes are too long' using errcode='22023'; end if;
  select s.* into subcontract_row from public.subcontracts s
  where s.company_id=target_company_id and s.id=target_subcontract_id;
  if not found then raise exception 'Subcontract not found in company' using errcode='23503'; end if;
  new_reference := private.allocate_reference(target_company_id,'SCERT',extract(year from target_certificate_date)::integer);
  insert into public.subcontractor_certificates (id,company_id,certificate_reference,
    contractor_certificate_number,certificate_date,project_id,subcontractor_id,subcontract_id,
    work_value_to_date_minor,current_variation_amount_minor,requested_advance_recovery_minor,
    vat_mode,manual_vat_amount_minor,tax_invoice_received,tax_invoice_number,tax_invoice_date,notes,created_by)
  values (new_id,target_company_id,new_reference,normalized_number,target_certificate_date,
    subcontract_row.project_id,subcontract_row.subcontractor_id,subcontract_row.id,
    target_work_value_to_date_minor,target_current_variation_amount_minor,target_advance_recovery_minor,
    target_vat_mode,case when target_vat_mode='MANUAL' then target_manual_vat_amount_minor else null end,
    target_tax_invoice_received,normalized_invoice,target_tax_invoice_date,normalized_notes,actor_id);
  for item in select value from jsonb_array_elements(target_deductions) loop
    line_no := line_no + 1;
    begin item_type := (item->>'type')::public.certificate_deduction_type;
    exception when invalid_text_representation then raise exception 'Unknown Certificate deduction type' using errcode='22023'; end;
    item_description := btrim(item->>'description');
    begin item_amount := (item->>'amount_minor')::bigint;
    exception when others then raise exception 'Valid Certificate deduction amount is required' using errcode='22023'; end;
    if item_description is null or length(item_description) not between 1 and 500
       or item_amount not between 1 and 9000000000000000 then
      raise exception 'Valid positive Certificate deduction is required' using errcode='22023';
    end if;
    select m.account_id into mapped_account_id from public.certificate_deduction_account_mappings m
    join public.accounts a on a.company_id=m.company_id and a.id=m.account_id
    where m.company_id=target_company_id and m.deduction_type=item_type
      and a.status='ACTIVE' and a.account_type='REVENUE';
    if mapped_account_id is null then raise exception 'Certificate deduction type is not mapped to an active Revenue account' using errcode='23514'; end if;
    insert into public.subcontractor_certificate_deductions
      (company_id,certificate_id,line_number,deduction_type,description,amount_minor,account_id,created_by)
    values (target_company_id,new_id,line_no,item_type,item_description,item_amount,mapped_account_id,actor_id);
  end loop;
  return query select new_id,new_reference;
end;
$$;

create function public.approve_post_subcontractor_certificate(
  target_company_id uuid, target_subcontractor_certificate_id uuid, target_idempotency_key uuid
)
returns table (subcontractor_certificate_id uuid, certificate_reference text, journal_entry_id uuid, replayed boolean)
language plpgsql security definer set search_path = '' as $$
declare
  actor_id uuid:=auth.uid(); cert public.subcontractor_certificates; subcontract_row public.subcontracts;
  project_status public.project_status; previous_work numeric; current_work numeric; gross numeric;
  retention numeric; recovery numeric; deduction_total numeric; net_before_vat numeric; vat numeric; payable numeric;
  revised_value numeric; live_certified numeric; available_advance numeric; project_cost_account uuid;
  vat_account uuid; retention_account uuid; advance_account uuid; payable_account uuid;
  deduction_row public.subcontractor_certificate_deductions; lines jsonb := '[]'::jsonb;
  request_hash text; request_row private.financial_command_requests; new_journal_id uuid;
begin
  if actor_id is null or not public.has_permission(target_company_id,'certificate.approve_post') then
    raise exception 'Not authorized to approve/post Subcontractor Certificates' using errcode='42501';
  end if;
  if target_company_id is null or target_subcontractor_certificate_id is null or target_idempotency_key is null then
    raise exception 'Required Certificate approval input is missing' using errcode='22023';
  end if;
  request_hash:=encode(extensions.digest(convert_to(jsonb_build_object('company_id',target_company_id,
    'certificate_id',target_subcontractor_certificate_id)::text,'UTF8'),'sha256'),'hex');
  request_row:=private.reserve_financial_command(target_company_id,'APPROVE_SUBCONTRACTOR_CERTIFICATE',
    target_idempotency_key,request_hash,actor_id);
  if request_row.status='COMPLETED' then
    return query select c.id,c.certificate_reference,c.posted_journal_entry_id,true
    from public.subcontractor_certificates c where c.company_id=target_company_id
      and c.posted_journal_entry_id=request_row.resulting_journal_entry_id;
    return;
  end if;
  select c.* into cert from public.subcontractor_certificates c
  where c.company_id=target_company_id and c.id=target_subcontractor_certificate_id for update;
  if not found then raise exception 'Certificate not found in company' using errcode='23503'; end if;
  if cert.status<>'DRAFT' then raise exception 'Only a DRAFT Certificate can be approved' using errcode='23514'; end if;
  select s.* into subcontract_row from public.subcontracts s
  where s.company_id=target_company_id and s.id=cert.subcontract_id for update;
  if not found then raise exception 'Subcontract not found in company' using errcode='23503'; end if;
  if subcontract_row.status='CLOSED' then raise exception 'CLOSED Subcontract cannot receive a new Certificate' using errcode='23514'; end if;
  select p.status into project_status from public.projects p
  where p.company_id=target_company_id and p.id=subcontract_row.project_id;
  if project_status='CLOSED' then raise exception 'CLOSED Project cannot receive a new Certificate' using errcode='23514'; end if;
  perform 1 from public.parties p where p.company_id=target_company_id
    and p.id=subcontract_row.subcontractor_id and p.type='SUBCONTRACTOR';
  if not found then raise exception 'Certificate Subcontractor identity is invalid' using errcode='23514'; end if;
  select coalesce(max(c.work_value_to_date_minor),0),coalesce(sum(c.gross_certified_minor),0)
    into previous_work,live_certified from public.subcontractor_certificates c
    where c.company_id=target_company_id and c.subcontract_id=cert.subcontract_id and c.status='POSTED';
  current_work:=cert.work_value_to_date_minor::numeric-previous_work;
  gross:=current_work+cert.current_variation_amount_minor::numeric;
  revised_value:=subcontract_row.original_contract_value_minor::numeric+subcontract_row.approved_variations_minor::numeric;
  if current_work<0 then raise exception 'Work value to date cannot be below authoritative previous certification' using errcode='23514'; end if;
  if gross<=0 or gross>9000000000000000 then raise exception 'Current gross certified amount must be positive and within bounds' using errcode='23514'; end if;
  if live_certified+gross>revised_value then raise exception 'Cumulative certified work exceeds revised Subcontract value' using errcode='23514'; end if;
  retention:=round(gross*subcontract_row.retention_bps::numeric/10000);
  recovery:=cert.requested_advance_recovery_minor;
  available_advance:=private.subcontractor_advance_balance_minor(target_company_id,cert.subcontract_id);
  if recovery>available_advance then raise exception 'Advance recovery exceeds available same-contract Advance' using errcode='23514'; end if;
  select coalesce(sum(d.amount_minor),0) into deduction_total from public.subcontractor_certificate_deductions d
  where d.company_id=target_company_id and d.certificate_id=cert.id;
  net_before_vat:=gross-retention-recovery-deduction_total;
  if net_before_vat<0 then raise exception 'Certificate deductions, retention and recovery exceed gross certified amount' using errcode='23514'; end if;
  vat:=case cert.vat_mode when 'ZERO' then 0 when 'AUTO_5' then round(net_before_vat*5/100)
    when 'MANUAL' then cert.manual_vat_amount_minor::numeric end;
  if vat>0 and (not cert.tax_invoice_received or cert.tax_invoice_number is null or cert.tax_invoice_date is null) then
    raise exception 'Recoverable VAT requires tax invoice evidence' using errcode='23514';
  end if;
  payable:=net_before_vat+vat;
  select a.id into project_cost_account from public.accounts a where a.company_id=target_company_id
    and a.system_key='PROJECT_COST_SUBCONTRACTORS' and a.status='ACTIVE' and a.account_type='EXPENSE';
  select a.id into vat_account from public.accounts a where a.company_id=target_company_id
    and a.system_key='INPUT_VAT' and a.status='ACTIVE' and a.account_type='ASSET';
  select a.id into retention_account from public.accounts a where a.company_id=target_company_id
    and a.system_key='SUBCONTRACTOR_RETENTION_PAYABLE' and a.status='ACTIVE' and a.account_type='LIABILITY';
  select a.id into advance_account from public.accounts a where a.company_id=target_company_id
    and a.system_key='SUBCONTRACTOR_ADVANCE' and a.status='ACTIVE' and a.account_type='ASSET';
  select a.id into payable_account from public.accounts a where a.company_id=target_company_id
    and a.system_key='SUBCONTRACTOR_PAYABLE' and a.status='ACTIVE' and a.account_type='LIABILITY';
  if project_cost_account is null or (vat>0 and vat_account is null) or (retention>0 and retention_account is null)
     or (recovery>0 and advance_account is null) or (payable>0 and payable_account is null) then
    raise exception 'Required Certificate system account is unavailable' using errcode='23514';
  end if;
  lines:=lines||jsonb_build_array(jsonb_build_object('account_id',project_cost_account,'debit_minor',gross::bigint,
    'credit_minor',0,'project_id',cert.project_id,'party_id',cert.subcontractor_id,
    'subcontract_id',cert.subcontract_id,'memo','Subcontract work certified'));
  if vat>0 then lines:=lines||jsonb_build_array(jsonb_build_object('account_id',vat_account,'debit_minor',vat::bigint,
    'credit_minor',0,'project_id',cert.project_id,'party_id',cert.subcontractor_id,
    'subcontract_id',cert.subcontract_id,'memo','Recoverable Certificate VAT')); end if;
  if retention>0 then lines:=lines||jsonb_build_array(jsonb_build_object('account_id',retention_account,'debit_minor',0,
    'credit_minor',retention::bigint,'project_id',cert.project_id,'party_id',cert.subcontractor_id,
    'subcontract_id',cert.subcontract_id,'memo','Subcontract retention withheld')); end if;
  if recovery>0 then lines:=lines||jsonb_build_array(jsonb_build_object('account_id',advance_account,'debit_minor',0,
    'credit_minor',recovery::bigint,'project_id',cert.project_id,'party_id',cert.subcontractor_id,
    'subcontract_id',cert.subcontract_id,'memo','Subcontract Advance recovered')); end if;
  for deduction_row in select d.* from public.subcontractor_certificate_deductions d
    where d.company_id=target_company_id and d.certificate_id=cert.id order by d.line_number loop
    perform 1 from public.accounts a where a.company_id=target_company_id and a.id=deduction_row.account_id
      and a.status='ACTIVE' and a.account_type='REVENUE';
    if not found then raise exception 'Certificate deduction account is unavailable' using errcode='23514'; end if;
    lines:=lines||jsonb_build_array(jsonb_build_object('account_id',deduction_row.account_id,'debit_minor',0,
      'credit_minor',deduction_row.amount_minor,'project_id',cert.project_id,'party_id',cert.subcontractor_id,
      'subcontract_id',cert.subcontract_id,'memo',deduction_row.description));
  end loop;
  if payable>0 then lines:=lines||jsonb_build_array(jsonb_build_object('account_id',payable_account,'debit_minor',0,
    'credit_minor',payable::bigint,'project_id',cert.project_id,'party_id',cert.subcontractor_id,
    'subcontract_id',cert.subcontract_id,'memo','Subcontractor payable recognized')); end if;
  new_journal_id:=private.create_journal(target_company_id,cert.certificate_date,
    'Subcontractor Certificate '||cert.certificate_reference,'SUBCONTRACTOR_CERTIFICATE',cert.id,
    'ORIGINAL',lines,actor_id,null);
  update public.subcontractor_certificates set status='POSTED',previous_certified_work_minor=previous_work::bigint,
    current_work_amount_minor=current_work::bigint,gross_certified_minor=gross::bigint,
    retention_bps=subcontract_row.retention_bps,retention_amount_minor=retention::bigint,
    advance_recovery_minor=recovery::bigint,deductions_total_minor=deduction_total::bigint,
    net_before_vat_minor=net_before_vat::bigint,vat_amount_minor=vat::bigint,payable_amount_minor=payable::bigint,
    posted_journal_entry_id=new_journal_id,approved_at=now(),approved_by=actor_id where id=cert.id;
  perform private.complete_financial_command(request_row.id,new_journal_id);
  return query select cert.id,cert.certificate_reference,new_journal_id,false;
end;
$$;

create function public.reverse_subcontractor_certificate(
  target_company_id uuid,target_subcontractor_certificate_id uuid,target_reversal_date date,
  target_reason text,target_idempotency_key uuid
)
returns table (subcontractor_certificate_id uuid,certificate_reference text,reversal_journal_entry_id uuid,replayed boolean)
language plpgsql security definer set search_path = '' as $$
declare actor_id uuid:=auth.uid(); normalized_reason text:=btrim(target_reason); cert public.subcontractor_certificates;
  request_hash text; request_row private.financial_command_requests; new_journal_id uuid;
begin
  if actor_id is null or not public.has_permission(target_company_id,'accounting.reverse') then
    raise exception 'Not authorized to reverse Subcontractor Certificates' using errcode='42501'; end if;
  if target_company_id is null or target_subcontractor_certificate_id is null or target_reversal_date is null
     or target_idempotency_key is null or normalized_reason is null or length(normalized_reason) not between 1 and 1000 then
    raise exception 'Valid Certificate reversal inputs are required' using errcode='22023'; end if;
  request_hash:=encode(extensions.digest(convert_to(jsonb_build_object('company_id',target_company_id,
    'certificate_id',target_subcontractor_certificate_id,'reversal_date',target_reversal_date,
    'reason',normalized_reason)::text,'UTF8'),'sha256'),'hex');
  request_row:=private.reserve_financial_command(target_company_id,'REVERSE_SUBCONTRACTOR_CERTIFICATE',
    target_idempotency_key,request_hash,actor_id);
  if request_row.status='COMPLETED' then
    return query select c.id,c.certificate_reference,c.reversal_journal_entry_id,true
    from public.subcontractor_certificates c where c.company_id=target_company_id
      and c.reversal_journal_entry_id=request_row.resulting_journal_entry_id; return;
  end if;
  select c.* into cert from public.subcontractor_certificates c
  where c.company_id=target_company_id and c.id=target_subcontractor_certificate_id for update;
  if not found then raise exception 'Certificate not found in company' using errcode='23503'; end if;
  if cert.status<>'POSTED' then raise exception 'Only a POSTED Certificate can be reversed' using errcode='23514'; end if;
  perform 1 from public.subcontracts s where s.company_id=target_company_id and s.id=cert.subcontract_id for update;
  -- P5H must add a live-payment dependency check before settling this payable.
  new_journal_id:=private.reverse_journal(cert.posted_journal_entry_id,target_reversal_date,
    'Reversal of '||cert.certificate_reference||': '||normalized_reason,actor_id);
  update public.subcontractor_certificates set status='REVERSED',reversal_journal_entry_id=new_journal_id,
    reversed_at=now(),reversed_by=actor_id,reversal_reason=normalized_reason where id=cert.id;
  perform private.complete_financial_command(request_row.id,new_journal_id);
  return query select cert.id,cert.certificate_reference,new_journal_id,false;
end;
$$;

revoke all on function private.validate_certificate_deduction_mapping() from public,anon,authenticated,service_role;
revoke all on function private.protect_certificate_history() from public,anon,authenticated,service_role;
revoke all on function private.protect_certificate_deduction_history() from public,anon,authenticated,service_role;
revoke all on function public.create_subcontractor_certificate_draft(uuid,date,uuid,text,bigint,bigint,bigint,
  public.expense_vat_mode,bigint,boolean,text,date,jsonb,text) from public,anon,authenticated,service_role;
revoke all on function public.approve_post_subcontractor_certificate(uuid,uuid,uuid)
  from public,anon,authenticated,service_role;
revoke all on function public.reverse_subcontractor_certificate(uuid,uuid,date,text,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.create_subcontractor_certificate_draft(uuid,date,uuid,text,bigint,bigint,bigint,
  public.expense_vat_mode,bigint,boolean,text,date,jsonb,text) to authenticated;
grant execute on function public.approve_post_subcontractor_certificate(uuid,uuid,uuid) to authenticated;
grant execute on function public.reverse_subcontractor_certificate(uuid,uuid,date,text,uuid) to authenticated;

comment on table public.certificate_deduction_account_mappings is
  'Trusted per-company mapping for the three approved local-domain Certificate deduction types; browser callers never choose GL accounts.';
comment on table public.subcontractor_certificates is
  'P5G contract-scoped Certificate drafts and immutable posted/reversed accounting provenance.';
