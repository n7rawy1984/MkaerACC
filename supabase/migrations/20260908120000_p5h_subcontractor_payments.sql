-- P5H: contract-scoped Subcontractor Payments and immutable Certificate allocations.
-- Payment settles only P5G Subcontractor Payable: Dr payable / Cr Treasury.

create table public.subcontractor_payments (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  payment_reference text not null check (length(btrim(payment_reference)) between 1 and 100),
  payment_date date not null,
  project_id uuid not null,
  subcontractor_id uuid not null,
  subcontract_id uuid not null,
  treasury_account_id uuid not null,
  total_amount_minor bigint not null check (total_amount_minor between 1 and 9000000000000000),
  payment_method public.payment_method not null,
  external_reference text check (external_reference is null or length(btrim(external_reference)) between 1 and 200),
  notes text check (notes is null or length(btrim(notes)) between 1 and 2000),
  status public.expense_status not null default 'DRAFT',
  posted_journal_entry_id uuid,
  reversal_journal_entry_id uuid,
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users (id) on delete restrict,
  updated_at timestamptz not null default now(),
  updated_by uuid not null references auth.users (id) on delete restrict,
  posted_at timestamptz,
  posted_by uuid references auth.users (id) on delete restrict,
  reversed_at timestamptz,
  reversed_by uuid references auth.users (id) on delete restrict,
  reversal_reason text check (reversal_reason is null or length(btrim(reversal_reason)) between 1 and 1000),
  constraint subcontractor_payments_company_id_id_unique unique (company_id, id),
  constraint subcontractor_payments_company_reference_unique unique (company_id, payment_reference),
  constraint subcontractor_payments_identity foreign key
    (company_id, subcontract_id, project_id, subcontractor_id)
    references public.subcontracts (company_id, id, project_id, subcontractor_id) on delete restrict,
  constraint subcontractor_payments_treasury_same_company foreign key (company_id, treasury_account_id)
    references public.treasury_accounts (company_id, id) on delete restrict,
  constraint subcontractor_payments_posted_journal_same_company foreign key (company_id, posted_journal_entry_id)
    references public.journal_entries (company_id, id) on delete restrict,
  constraint subcontractor_payments_reversal_journal_same_company foreign key (company_id, reversal_journal_entry_id)
    references public.journal_entries (company_id, id) on delete restrict,
  constraint subcontractor_payments_posted_journal_unique unique (posted_journal_entry_id),
  constraint subcontractor_payments_reversal_journal_unique unique (reversal_journal_entry_id),
  constraint subcontractor_payments_state_shape check (
    (status = 'DRAFT' and posted_journal_entry_id is null and reversal_journal_entry_id is null
      and posted_at is null and posted_by is null and reversed_at is null and reversed_by is null
      and reversal_reason is null)
    or (status = 'POSTED' and posted_journal_entry_id is not null and reversal_journal_entry_id is null
      and posted_at is not null and posted_by is not null and reversed_at is null and reversed_by is null
      and reversal_reason is null)
    or (status = 'REVERSED' and posted_journal_entry_id is not null and reversal_journal_entry_id is not null
      and posted_at is not null and posted_by is not null and reversed_at is not null and reversed_by is not null
      and reversal_reason is not null)
  )
);

create table public.subcontractor_payment_allocations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  subcontractor_payment_id uuid not null,
  subcontractor_certificate_id uuid not null,
  allocated_amount_minor bigint not null check (allocated_amount_minor between 1 and 9000000000000000),
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users (id) on delete restrict,
  constraint subcontractor_payment_allocations_company_id_id_unique unique (company_id, id),
  constraint subcontractor_payment_allocations_payment_certificate_unique
    unique (subcontractor_payment_id, subcontractor_certificate_id),
  constraint subcontractor_payment_allocations_payment_same_company foreign key
    (company_id, subcontractor_payment_id)
    references public.subcontractor_payments (company_id, id) on delete restrict,
  constraint subcontractor_payment_allocations_certificate_same_company foreign key
    (company_id, subcontractor_certificate_id)
    references public.subcontractor_certificates (company_id, id) on delete restrict
);

create index subcontractor_payments_contract_date_idx
  on public.subcontractor_payments (company_id, subcontract_id, payment_date desc, id);
create index subcontractor_payments_project_date_idx
  on public.subcontractor_payments (company_id, project_id, payment_date desc, id);
create index subcontractor_payment_allocations_certificate_idx
  on public.subcontractor_payment_allocations (company_id, subcontractor_certificate_id);

create function private.protect_subcontractor_payment_history()
returns trigger language plpgsql set search_path = '' as $$
declare allocation_total numeric;
begin
  if tg_op = 'DELETE' then
    raise exception 'Subcontractor Payment history cannot be deleted; reverse posted accounting' using errcode='55000';
  end if;
  if new.company_id <> old.company_id or new.payment_reference <> old.payment_reference
     or new.payment_date <> old.payment_date or new.project_id <> old.project_id
     or new.subcontractor_id <> old.subcontractor_id or new.subcontract_id <> old.subcontract_id
     or new.treasury_account_id <> old.treasury_account_id
     or new.total_amount_minor <> old.total_amount_minor or new.payment_method <> old.payment_method
     or new.external_reference is distinct from old.external_reference or new.notes is distinct from old.notes
     or new.created_at <> old.created_at or new.created_by <> old.created_by then
    raise exception 'Posted Subcontractor Payment economics and provenance are immutable' using errcode='55000';
  end if;
  if old.status = 'DRAFT' then
    if new.status <> 'POSTED' or new.posted_journal_entry_id is null or new.reversal_journal_entry_id is not null then
      raise exception 'Subcontractor Payment may transition only from DRAFT to POSTED' using errcode='55000';
    end if;
    select coalesce(sum(a.allocated_amount_minor::numeric),0) into allocation_total
    from public.subcontractor_payment_allocations a where a.subcontractor_payment_id=old.id;
    if allocation_total <> old.total_amount_minor::numeric then
      raise exception 'Subcontractor Payment allocations must equal its total' using errcode='23514';
    end if;
  elsif old.status = 'POSTED' then
    if new.status <> 'REVERSED' or new.posted_journal_entry_id <> old.posted_journal_entry_id
       or new.reversal_journal_entry_id is null or new.reversal_reason is null then
      raise exception 'Posted Subcontractor Payment may transition only to REVERSED' using errcode='55000';
    end if;
  else
    raise exception 'Reversed Subcontractor Payment is immutable' using errcode='55000';
  end if;
  new.updated_at:=now(); return new;
end;
$$;

create function private.validate_subcontractor_payment_allocation()
returns trigger language plpgsql security definer set search_path = '' as $$
declare payment_row public.subcontractor_payments; certificate_row public.subcontractor_certificates;
  already_allocated numeric;
begin
  if tg_op <> 'INSERT' then raise exception 'Subcontractor Payment allocations are immutable' using errcode='55000'; end if;
  select p.* into payment_row from public.subcontractor_payments p
  where p.company_id=new.company_id and p.id=new.subcontractor_payment_id for share;
  if not found or payment_row.status <> 'DRAFT' then
    raise exception 'Allocations may be added only during atomic Subcontractor Payment posting' using errcode='55000';
  end if;
  select c.* into certificate_row from public.subcontractor_certificates c
  where c.company_id=new.company_id and c.id=new.subcontractor_certificate_id for update;
  if not found then raise exception 'Allocated Certificate not found in company' using errcode='23503'; end if;
  if certificate_row.status <> 'POSTED' then
    raise exception 'Allocation source must be a live POSTED Certificate' using errcode='23514';
  end if;
  if certificate_row.subcontract_id <> payment_row.subcontract_id
     or certificate_row.project_id <> payment_row.project_id
     or certificate_row.subcontractor_id <> payment_row.subcontractor_id then
    raise exception 'Allocated Certificate belongs to a different Subcontract' using errcode='23514';
  end if;
  select coalesce(sum(a.allocated_amount_minor::numeric),0) into already_allocated
  from public.subcontractor_payment_allocations a
  join public.subcontractor_payments p on p.id=a.subcontractor_payment_id
  where a.company_id=new.company_id and a.subcontractor_certificate_id=new.subcontractor_certificate_id
    and p.status='POSTED';
  if already_allocated + new.allocated_amount_minor::numeric > certificate_row.payable_amount_minor::numeric then
    raise exception 'Subcontractor Payment allocation exceeds outstanding Certificate payable' using errcode='23514';
  end if;
  return new;
end;
$$;

create function private.protect_certificate_with_live_subcontractor_payment()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  if old.status='POSTED' and new.status='REVERSED' and exists (
    select 1 from public.subcontractor_payment_allocations a
    join public.subcontractor_payments p on p.id=a.subcontractor_payment_id
    where a.company_id=old.company_id and a.subcontractor_certificate_id=old.id and p.status='POSTED'
  ) then
    raise exception 'Reverse active Subcontractor Payments before reversing this Certificate' using errcode='23514';
  end if;
  return new;
end;
$$;

create trigger subcontractor_payments_protect before update or delete on public.subcontractor_payments
  for each row execute function private.protect_subcontractor_payment_history();
create trigger subcontractor_payment_allocations_validate before insert or update or delete
  on public.subcontractor_payment_allocations for each row
  execute function private.validate_subcontractor_payment_allocation();
create trigger certificates_protect_live_subcontractor_payments before update
  on public.subcontractor_certificates for each row
  execute function private.protect_certificate_with_live_subcontractor_payment();

alter table public.subcontractor_payments enable row level security;
alter table public.subcontractor_payments force row level security;
alter table public.subcontractor_payment_allocations enable row level security;
alter table public.subcontractor_payment_allocations force row level security;
create policy subcontractor_payments_read_accounting on public.subcontractor_payments
  for select to authenticated using (public.has_company_role(company_id,'ACCOUNTING_ADMIN')
    or public.has_company_role(company_id,'ACCOUNTANT') or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create policy subcontractor_payment_allocations_read_accounting on public.subcontractor_payment_allocations
  for select to authenticated using (public.has_company_role(company_id,'ACCOUNTING_ADMIN')
    or public.has_company_role(company_id,'ACCOUNTANT') or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
revoke all on table public.subcontractor_payments,public.subcontractor_payment_allocations
  from public,anon,authenticated,service_role;
grant select on table public.subcontractor_payments,public.subcontractor_payment_allocations
  to authenticated,service_role;

create function public.post_subcontractor_payment(
  target_company_id uuid,target_payment_date date,target_subcontract_id uuid,
  target_treasury_account_id uuid,target_total_amount_minor bigint,target_payment_method public.payment_method,
  target_external_reference text,target_notes text,target_allocations jsonb,target_idempotency_key uuid
)
returns table (subcontractor_payment_id uuid,payment_reference text,journal_entry_id uuid,replayed boolean)
language plpgsql security definer set search_path = '' as $$
declare actor_id uuid:=auth.uid(); normalized_external_reference text:=nullif(btrim(target_external_reference),'');
  normalized_notes text:=nullif(btrim(target_notes),''); normalized_allocations jsonb; allocation_total numeric;
  request_hash text; request_row private.financial_command_requests; subcontract_row public.subcontracts;
  treasury_row public.treasury_accounts; payable_account_id uuid; item jsonb;
  new_payment_id uuid:=gen_random_uuid(); new_reference text; new_journal_id uuid; lines jsonb;
begin
  if actor_id is null or not public.has_permission(target_company_id,'accounting.post') then
    raise exception 'Not authorized to post Subcontractor Payments' using errcode='42501'; end if;
  if target_company_id is null or target_payment_date is null or target_subcontract_id is null
     or target_treasury_account_id is null or target_total_amount_minor is null
     or target_payment_method is null or target_idempotency_key is null then
    raise exception 'Required Subcontractor Payment input is missing' using errcode='22023'; end if;
  if target_total_amount_minor not between 1 and 9000000000000000 then
    raise exception 'Subcontractor Payment total is invalid' using errcode='22023'; end if;
  if normalized_external_reference is not null and length(normalized_external_reference)>200 then
    raise exception 'External payment reference is too long' using errcode='22023'; end if;
  if normalized_notes is not null and length(normalized_notes)>2000 then
    raise exception 'Subcontractor Payment notes are too long' using errcode='22023'; end if;
  if target_allocations is null or jsonb_typeof(target_allocations)<>'array'
     or jsonb_array_length(target_allocations) not between 1 and 999 then
    raise exception 'Subcontractor Payment requires 1 to 999 allocations' using errcode='22023'; end if;
  if exists(select 1 from jsonb_array_elements(target_allocations) x
    where not(x?'certificate_id') or not(x?'amount_minor')) then
    raise exception 'Each allocation requires certificate_id and amount_minor' using errcode='22023'; end if;
  begin
    select jsonb_agg(jsonb_build_object('certificate_id',(x->>'certificate_id')::uuid,
      'amount_minor',(x->>'amount_minor')::bigint) order by (x->>'certificate_id')::uuid),
      sum((x->>'amount_minor')::numeric) into normalized_allocations,allocation_total
    from jsonb_array_elements(target_allocations) x;
  exception when others then raise exception 'Valid Certificate allocation identifiers and amounts are required' using errcode='22023'; end;
  if allocation_total is distinct from target_total_amount_minor::numeric then
    raise exception 'Subcontractor Payment total must equal allocation total' using errcode='23514'; end if;
  if exists(select 1 from jsonb_array_elements(normalized_allocations) x
    where (x->>'amount_minor')::bigint<=0) then raise exception 'Allocation amounts must be positive' using errcode='22023'; end if;
  if exists(select 1 from jsonb_array_elements(normalized_allocations) x
    group by (x->>'certificate_id')::uuid having count(*)>1) then
    raise exception 'A Certificate may appear only once per Subcontractor Payment' using errcode='23505'; end if;

  select s.* into subcontract_row from public.subcontracts s
  where s.company_id=target_company_id and s.id=target_subcontract_id for update;
  if not found then raise exception 'Subcontract not found in company' using errcode='23503'; end if;
  -- Existing liabilities remain settleable for CLOSED/COMPLETED Projects or Subcontracts and inactive parties.
  perform 1 from public.parties p where p.company_id=target_company_id
    and p.id=subcontract_row.subcontractor_id and p.type='SUBCONTRACTOR';
  if not found then raise exception 'Subcontractor identity is invalid' using errcode='23514'; end if;
  select t.* into treasury_row from public.treasury_accounts t
  join public.accounts a on a.company_id=t.company_id and a.id=t.gl_account_id
  where t.company_id=target_company_id and t.id=target_treasury_account_id
    and t.status='ACTIVE' and a.status='ACTIVE' and a.account_type='ASSET';
  if not found then raise exception 'An active same-company Treasury with an active Asset GL is required' using errcode='23514'; end if;
  if treasury_row.project_id is not null and treasury_row.project_id<>subcontract_row.project_id then
    raise exception 'Project Treasury may settle only its own Project liability' using errcode='23514'; end if;
  select a.id into payable_account_id from public.accounts a where a.company_id=target_company_id
    and a.system_key='SUBCONTRACTOR_PAYABLE' and a.status='ACTIVE' and a.account_type='LIABILITY';
  if payable_account_id is null then raise exception 'Subcontractor Payable system account is unavailable' using errcode='23514'; end if;

  request_hash:=encode(extensions.digest(convert_to(jsonb_build_object('company_id',target_company_id,
    'payment_date',target_payment_date,'subcontract_id',target_subcontract_id,
    'treasury_id',target_treasury_account_id,'total_amount_minor',target_total_amount_minor,
    'payment_method',target_payment_method,'external_reference',normalized_external_reference,
    'notes',normalized_notes,'allocations',normalized_allocations)::text,'UTF8'),'sha256'),'hex');
  request_row:=private.reserve_financial_command(target_company_id,'POST_SUBCONTRACTOR_PAYMENT',
    target_idempotency_key,request_hash,actor_id);
  if request_row.status='COMPLETED' then
    return query select p.id,p.payment_reference,p.posted_journal_entry_id,true
    from public.subcontractor_payments p where p.company_id=target_company_id
      and p.posted_journal_entry_id=request_row.resulting_journal_entry_id; return;
  end if;
  new_reference:=private.allocate_reference(target_company_id,'SCPAY',extract(year from target_payment_date)::integer);
  insert into public.subcontractor_payments(id,company_id,payment_reference,payment_date,project_id,
    subcontractor_id,subcontract_id,treasury_account_id,total_amount_minor,payment_method,
    external_reference,notes,created_by,updated_by)
  values(new_payment_id,target_company_id,new_reference,target_payment_date,subcontract_row.project_id,
    subcontract_row.subcontractor_id,subcontract_row.id,target_treasury_account_id,target_total_amount_minor,
    target_payment_method,normalized_external_reference,normalized_notes,actor_id,actor_id);
  for item in select x from jsonb_array_elements(normalized_allocations) x order by (x->>'certificate_id')::uuid loop
    insert into public.subcontractor_payment_allocations(company_id,subcontractor_payment_id,
      subcontractor_certificate_id,allocated_amount_minor,created_by)
    values(target_company_id,new_payment_id,(item->>'certificate_id')::uuid,(item->>'amount_minor')::bigint,actor_id);
  end loop;
  lines:=jsonb_build_array(
    jsonb_build_object('account_id',payable_account_id,'debit_minor',target_total_amount_minor,'credit_minor',0,
      'project_id',subcontract_row.project_id,'party_id',subcontract_row.subcontractor_id,
      'subcontract_id',subcontract_row.id,'memo','Subcontractor payable settlement'),
    jsonb_build_object('account_id',treasury_row.gl_account_id,'debit_minor',0,'credit_minor',target_total_amount_minor,
      'project_id',subcontract_row.project_id,'subcontract_id',subcontract_row.id,
      'treasury_account_id',target_treasury_account_id,'memo','Subcontractor Payment treasury settlement'));
  new_journal_id:=private.create_journal(target_company_id,target_payment_date,
    'Subcontractor Payment '||new_reference,'SUBCONTRACTOR_PAYMENT',new_payment_id,'ORIGINAL',lines,actor_id,null);
  update public.subcontractor_payments set status='POSTED',posted_journal_entry_id=new_journal_id,
    posted_at=now(),posted_by=actor_id,updated_by=actor_id where id=new_payment_id;
  perform private.complete_financial_command(request_row.id,new_journal_id);
  return query select new_payment_id,new_reference,new_journal_id,false;
end;
$$;

create function public.reverse_subcontractor_payment(target_company_id uuid,target_subcontractor_payment_id uuid,
  target_reversal_date date,target_reason text,target_idempotency_key uuid)
returns table(subcontractor_payment_id uuid,payment_reference text,reversal_journal_entry_id uuid,replayed boolean)
language plpgsql security definer set search_path = '' as $$
declare actor_id uuid:=auth.uid(); normalized_reason text:=btrim(target_reason); request_hash text;
  request_row private.financial_command_requests; payment_row public.subcontractor_payments; new_journal_id uuid;
begin
  if actor_id is null or not public.has_permission(target_company_id,'accounting.reverse') then
    raise exception 'Not authorized to reverse Subcontractor Payments' using errcode='42501'; end if;
  if target_company_id is null or target_subcontractor_payment_id is null or target_reversal_date is null
     or target_idempotency_key is null or normalized_reason is null or length(normalized_reason) not between 1 and 1000 then
    raise exception 'Valid Subcontractor Payment reversal inputs are required' using errcode='22023'; end if;
  request_hash:=encode(extensions.digest(convert_to(jsonb_build_object('company_id',target_company_id,
    'subcontractor_payment_id',target_subcontractor_payment_id,'reversal_date',target_reversal_date,
    'reason',normalized_reason)::text,'UTF8'),'sha256'),'hex');
  request_row:=private.reserve_financial_command(target_company_id,'REVERSE_SUBCONTRACTOR_PAYMENT',
    target_idempotency_key,request_hash,actor_id);
  if request_row.status='COMPLETED' then
    return query select p.id,p.payment_reference,p.reversal_journal_entry_id,true
    from public.subcontractor_payments p where p.company_id=target_company_id
      and p.reversal_journal_entry_id=request_row.resulting_journal_entry_id; return;
  end if;
  select p.* into payment_row from public.subcontractor_payments p
  where p.company_id=target_company_id and p.id=target_subcontractor_payment_id;
  if not found then raise exception 'Subcontractor Payment not found in company' using errcode='23503'; end if;
  perform 1 from public.subcontracts s where s.company_id=target_company_id and s.id=payment_row.subcontract_id for update;
  select p.* into payment_row from public.subcontractor_payments p
  where p.company_id=target_company_id and p.id=target_subcontractor_payment_id for update;
  if payment_row.status<>'POSTED' then raise exception 'Only a POSTED Subcontractor Payment can be reversed' using errcode='23514'; end if;
  perform 1 from public.subcontractor_certificates c join public.subcontractor_payment_allocations a
    on a.subcontractor_certificate_id=c.id where a.subcontractor_payment_id=payment_row.id
    order by c.id for update of c;
  new_journal_id:=private.reverse_journal(payment_row.posted_journal_entry_id,target_reversal_date,
    'Reversal of '||payment_row.payment_reference||': '||normalized_reason,actor_id);
  update public.subcontractor_payments set status='REVERSED',reversal_journal_entry_id=new_journal_id,
    reversed_at=now(),reversed_by=actor_id,reversal_reason=normalized_reason,updated_by=actor_id
    where id=payment_row.id;
  perform private.complete_financial_command(request_row.id,new_journal_id);
  return query select payment_row.id,payment_row.payment_reference,new_journal_id,false;
end;
$$;

-- Preserve the applied P5G implementation privately and expose a wrapper that
-- uses the same Subcontract-first lock order as Payment posting/reversal.
revoke execute on function public.reverse_subcontractor_certificate(uuid,uuid,date,text,uuid) from authenticated;
alter function public.reverse_subcontractor_certificate(uuid,uuid,date,text,uuid) set schema private;
revoke all on function private.reverse_subcontractor_certificate(uuid,uuid,date,text,uuid)
  from public,anon,authenticated,service_role;

create function public.reverse_subcontractor_certificate(target_company_id uuid,
  target_subcontractor_certificate_id uuid,target_reversal_date date,target_reason text,target_idempotency_key uuid)
returns table(subcontractor_certificate_id uuid,certificate_reference text,reversal_journal_entry_id uuid,replayed boolean)
language plpgsql security definer set search_path = '' as $$
declare target_subcontract_id uuid;
begin
  if auth.uid() is null or not public.has_permission(target_company_id,'accounting.reverse') then
    raise exception 'Not authorized to reverse Subcontractor Certificates' using errcode='42501'; end if;
  select c.subcontract_id into target_subcontract_id from public.subcontractor_certificates c
  where c.company_id=target_company_id and c.id=target_subcontractor_certificate_id;
  if target_subcontract_id is null then raise exception 'Certificate not found in company' using errcode='23503'; end if;
  perform 1 from public.subcontracts s where s.company_id=target_company_id and s.id=target_subcontract_id for update;
  return query select * from private.reverse_subcontractor_certificate(target_company_id,
    target_subcontractor_certificate_id,target_reversal_date,target_reason,target_idempotency_key);
end;
$$;

revoke all on function private.protect_subcontractor_payment_history() from public,anon,authenticated,service_role;
revoke all on function private.validate_subcontractor_payment_allocation() from public,anon,authenticated,service_role;
revoke all on function private.protect_certificate_with_live_subcontractor_payment() from public,anon,authenticated,service_role;
revoke all on function public.post_subcontractor_payment(uuid,date,uuid,uuid,bigint,public.payment_method,text,text,jsonb,uuid)
  from public,anon,authenticated,service_role;
revoke all on function public.reverse_subcontractor_payment(uuid,uuid,date,text,uuid)
  from public,anon,authenticated,service_role;
revoke all on function public.reverse_subcontractor_certificate(uuid,uuid,date,text,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.post_subcontractor_payment(uuid,date,uuid,uuid,bigint,public.payment_method,text,text,jsonb,uuid)
  to authenticated;
grant execute on function public.reverse_subcontractor_payment(uuid,uuid,date,text,uuid) to authenticated;
grant execute on function public.reverse_subcontractor_certificate(uuid,uuid,date,text,uuid) to authenticated;

comment on table public.subcontractor_payments is
  'P5H immutable contract-scoped Subcontractor Payment documents; Treasury-only payable settlement.';
comment on table public.subcontractor_payment_allocations is
  'Immutable Certificate-level settlement provenance; only allocations of live POSTED Payments consume payable.';
comment on function public.post_subcontractor_payment(uuid,date,uuid,uuid,bigint,public.payment_method,text,text,jsonb,uuid) is
  'Atomic contract-scoped settlement of P5G Certificate payables: Dr Subcontractor Payable / Cr Treasury.';
