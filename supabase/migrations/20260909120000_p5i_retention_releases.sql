-- P5I-A: manual, contract-scoped Retention Release with immutable
-- Certificate allocations. This is liability reclassification only:
-- Dr Subcontractor Retention Payable / Cr Subcontractor Payable.

create table public.subcontractor_retention_releases (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  release_reference text not null check (length(btrim(release_reference)) between 1 and 100),
  release_date date not null,
  project_id uuid not null,
  subcontractor_id uuid not null,
  subcontract_id uuid not null,
  total_amount_minor bigint not null check (total_amount_minor between 1 and 9000000000000000),
  authorization_reference text check (authorization_reference is null or length(btrim(authorization_reference)) between 1 and 200),
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
  constraint subcontractor_retention_releases_company_id_id_unique unique (company_id, id),
  constraint subcontractor_retention_releases_company_reference_unique unique (company_id, release_reference),
  constraint subcontractor_retention_releases_identity foreign key
    (company_id, subcontract_id, project_id, subcontractor_id)
    references public.subcontracts (company_id, id, project_id, subcontractor_id) on delete restrict,
  constraint subcontractor_retention_releases_posted_journal_same_company foreign key
    (company_id, posted_journal_entry_id) references public.journal_entries (company_id, id) on delete restrict,
  constraint subcontractor_retention_releases_reversal_journal_same_company foreign key
    (company_id, reversal_journal_entry_id) references public.journal_entries (company_id, id) on delete restrict,
  constraint subcontractor_retention_releases_posted_journal_unique unique (posted_journal_entry_id),
  constraint subcontractor_retention_releases_reversal_journal_unique unique (reversal_journal_entry_id),
  constraint subcontractor_retention_releases_state_shape check (
    (status='DRAFT' and posted_journal_entry_id is null and reversal_journal_entry_id is null
      and posted_at is null and posted_by is null and reversed_at is null and reversed_by is null
      and reversal_reason is null)
    or (status='POSTED' and posted_journal_entry_id is not null and reversal_journal_entry_id is null
      and posted_at is not null and posted_by is not null and reversed_at is null and reversed_by is null
      and reversal_reason is null)
    or (status='REVERSED' and posted_journal_entry_id is not null and reversal_journal_entry_id is not null
      and posted_at is not null and posted_by is not null and reversed_at is not null and reversed_by is not null
      and reversal_reason is not null)
  )
);

create table public.subcontractor_retention_release_allocations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies (id) on delete restrict,
  retention_release_id uuid not null,
  subcontractor_certificate_id uuid not null,
  allocated_amount_minor bigint not null check (allocated_amount_minor between 1 and 9000000000000000),
  created_at timestamptz not null default now(),
  created_by uuid not null references auth.users (id) on delete restrict,
  constraint subcontractor_retention_release_allocations_company_id_id_unique unique (company_id, id),
  constraint subcontractor_retention_release_allocations_release_certificate_unique
    unique (retention_release_id, subcontractor_certificate_id),
  constraint subcontractor_retention_release_allocations_release_same_company foreign key
    (company_id, retention_release_id)
    references public.subcontractor_retention_releases (company_id, id) on delete restrict,
  constraint subcontractor_retention_release_allocations_certificate_same_company foreign key
    (company_id, subcontractor_certificate_id)
    references public.subcontractor_certificates (company_id, id) on delete restrict
);

create index subcontractor_retention_releases_contract_date_idx
  on public.subcontractor_retention_releases (company_id, subcontract_id, release_date desc, id);
create index subcontractor_retention_release_allocations_certificate_idx
  on public.subcontractor_retention_release_allocations (company_id, subcontractor_certificate_id);

create function private.protect_subcontractor_retention_release_history()
returns trigger language plpgsql set search_path='' as $$
declare allocation_total numeric;
begin
  if tg_op='DELETE' then
    raise exception 'Retention Release history cannot be deleted; reverse posted accounting' using errcode='55000';
  end if;
  if new.company_id<>old.company_id or new.release_reference<>old.release_reference
     or new.release_date<>old.release_date or new.project_id<>old.project_id
     or new.subcontractor_id<>old.subcontractor_id or new.subcontract_id<>old.subcontract_id
     or new.total_amount_minor<>old.total_amount_minor
     or new.authorization_reference is distinct from old.authorization_reference
     or new.notes is distinct from old.notes or new.created_at<>old.created_at or new.created_by<>old.created_by then
    raise exception 'Posted Retention Release economics and provenance are immutable' using errcode='55000';
  end if;
  if old.status='DRAFT' then
    if new.status<>'POSTED' or new.posted_journal_entry_id is null or new.reversal_journal_entry_id is not null then
      raise exception 'Retention Release may transition only from DRAFT to POSTED' using errcode='55000';
    end if;
    select coalesce(sum(a.allocated_amount_minor::numeric),0) into allocation_total
    from public.subcontractor_retention_release_allocations a where a.retention_release_id=old.id;
    if allocation_total<>old.total_amount_minor::numeric then
      raise exception 'Retention Release allocations must equal its total' using errcode='23514';
    end if;
  elsif old.status='POSTED' then
    if new.status<>'REVERSED' or new.posted_journal_entry_id<>old.posted_journal_entry_id
       or new.reversal_journal_entry_id is null or new.reversal_reason is null then
      raise exception 'Posted Retention Release may transition only to REVERSED' using errcode='55000';
    end if;
  else
    raise exception 'Reversed Retention Release is immutable' using errcode='55000';
  end if;
  new.updated_at:=now(); return new;
end;
$$;

create function private.validate_subcontractor_retention_release_allocation()
returns trigger language plpgsql security definer set search_path='' as $$
declare release_row public.subcontractor_retention_releases;
  certificate_row public.subcontractor_certificates; already_released numeric;
begin
  if tg_op<>'INSERT' then raise exception 'Retention Release allocations are immutable' using errcode='55000'; end if;
  select r.* into release_row from public.subcontractor_retention_releases r
  where r.company_id=new.company_id and r.id=new.retention_release_id for share;
  if not found or release_row.status<>'DRAFT' then
    raise exception 'Allocations may be added only during atomic Retention Release posting' using errcode='55000';
  end if;
  select c.* into certificate_row from public.subcontractor_certificates c
  where c.company_id=new.company_id and c.id=new.subcontractor_certificate_id for update;
  if not found then raise exception 'Allocated Certificate not found in company' using errcode='23503'; end if;
  if certificate_row.status<>'POSTED' then
    raise exception 'Allocation source must be a live POSTED Certificate' using errcode='23514';
  end if;
  if certificate_row.subcontract_id<>release_row.subcontract_id
     or certificate_row.project_id<>release_row.project_id
     or certificate_row.subcontractor_id<>release_row.subcontractor_id then
    raise exception 'Allocated Certificate belongs to a different Subcontract' using errcode='23514';
  end if;
  select coalesce(sum(a.allocated_amount_minor::numeric),0) into already_released
  from public.subcontractor_retention_release_allocations a
  join public.subcontractor_retention_releases r on r.id=a.retention_release_id
  where a.company_id=new.company_id and a.subcontractor_certificate_id=new.subcontractor_certificate_id
    and r.status='POSTED';
  if already_released+new.allocated_amount_minor::numeric>certificate_row.retention_amount_minor::numeric then
    raise exception 'Retention Release allocation exceeds remaining Certificate retention' using errcode='23514';
  end if;
  return new;
end;
$$;

create function private.protect_certificate_with_live_retention_release()
returns trigger language plpgsql security definer set search_path='' as $$
begin
  if old.status='POSTED' and new.status='REVERSED' and exists (
    select 1 from public.subcontractor_retention_release_allocations a
    join public.subcontractor_retention_releases r on r.id=a.retention_release_id
    where a.company_id=old.company_id and a.subcontractor_certificate_id=old.id and r.status='POSTED'
  ) then
    raise exception 'Reverse active Retention Releases before reversing this Certificate' using errcode='23514';
  end if;
  return new;
end;
$$;

create trigger subcontractor_retention_releases_protect before update or delete
  on public.subcontractor_retention_releases for each row
  execute function private.protect_subcontractor_retention_release_history();
create trigger subcontractor_retention_release_allocations_validate before insert or update or delete
  on public.subcontractor_retention_release_allocations for each row
  execute function private.validate_subcontractor_retention_release_allocation();
create trigger certificates_protect_live_retention_releases before update
  on public.subcontractor_certificates for each row
  execute function private.protect_certificate_with_live_retention_release();

alter table public.subcontractor_retention_releases enable row level security;
alter table public.subcontractor_retention_releases force row level security;
alter table public.subcontractor_retention_release_allocations enable row level security;
alter table public.subcontractor_retention_release_allocations force row level security;
create policy subcontractor_retention_releases_read_accounting on public.subcontractor_retention_releases
  for select to authenticated using (public.has_company_role(company_id,'ACCOUNTING_ADMIN')
    or public.has_company_role(company_id,'ACCOUNTANT') or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create policy subcontractor_retention_release_allocations_read_accounting
  on public.subcontractor_retention_release_allocations for select to authenticated
  using (public.has_company_role(company_id,'ACCOUNTING_ADMIN')
    or public.has_company_role(company_id,'ACCOUNTANT') or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
revoke all on table public.subcontractor_retention_releases,public.subcontractor_retention_release_allocations
  from public,anon,authenticated,service_role;
grant select on table public.subcontractor_retention_releases,public.subcontractor_retention_release_allocations
  to authenticated,service_role;

create function public.post_subcontractor_retention_release(
  target_company_id uuid,target_release_date date,target_subcontract_id uuid,
  target_total_amount_minor bigint,target_authorization_reference text,target_notes text,
  target_allocations jsonb,target_idempotency_key uuid
)
returns table(retention_release_id uuid,release_reference text,journal_entry_id uuid,replayed boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid:=auth.uid(); normalized_authorization_reference text:=nullif(btrim(target_authorization_reference),'');
  normalized_notes text:=nullif(btrim(target_notes),''); normalized_allocations jsonb; allocation_total numeric;
  request_hash text; request_row private.financial_command_requests; subcontract_row public.subcontracts;
  retention_account_id uuid; payable_account_id uuid; item jsonb; new_release_id uuid:=gen_random_uuid();
  new_reference text; new_journal_id uuid; lines jsonb;
begin
  if actor_id is null or not public.has_company_role(target_company_id,'ACCOUNTING_ADMIN') then
    raise exception 'Only Accounting Admin may authorize Retention Releases' using errcode='42501'; end if;
  if target_company_id is null or target_release_date is null or target_subcontract_id is null
     or target_total_amount_minor is null or target_idempotency_key is null then
    raise exception 'Required Retention Release input is missing' using errcode='22023'; end if;
  if target_total_amount_minor not between 1 and 9000000000000000 then
    raise exception 'Retention Release total is invalid' using errcode='22023'; end if;
  if normalized_authorization_reference is not null and length(normalized_authorization_reference)>200 then
    raise exception 'Authorization reference is too long' using errcode='22023'; end if;
  if normalized_notes is not null and length(normalized_notes)>2000 then
    raise exception 'Retention Release notes are too long' using errcode='22023'; end if;
  if target_allocations is null or jsonb_typeof(target_allocations)<>'array'
     or jsonb_array_length(target_allocations) not between 1 and 999 then
    raise exception 'Retention Release requires 1 to 999 Certificate allocations' using errcode='22023'; end if;
  if exists(select 1 from jsonb_array_elements(target_allocations) x
    where not(x?'certificate_id') or not(x?'amount_minor')) then
    raise exception 'Each allocation requires certificate_id and amount_minor' using errcode='22023'; end if;
  begin
    select jsonb_agg(jsonb_build_object('certificate_id',(x->>'certificate_id')::uuid,
      'amount_minor',(x->>'amount_minor')::bigint) order by (x->>'certificate_id')::uuid),
      sum((x->>'amount_minor')::numeric) into normalized_allocations,allocation_total
    from jsonb_array_elements(target_allocations) x;
  exception when others then
    raise exception 'Valid Certificate allocation identifiers and amounts are required' using errcode='22023';
  end;
  if allocation_total is distinct from target_total_amount_minor::numeric then
    raise exception 'Retention Release total must equal allocation total' using errcode='23514'; end if;
  if exists(select 1 from jsonb_array_elements(normalized_allocations) x
    where (x->>'amount_minor')::bigint<=0) then
    raise exception 'Allocation amounts must be positive' using errcode='22023'; end if;
  if exists(select 1 from jsonb_array_elements(normalized_allocations) x
    group by (x->>'certificate_id')::uuid having count(*)>1) then
    raise exception 'A Certificate may appear only once per Retention Release' using errcode='23505'; end if;

  select s.* into subcontract_row from public.subcontracts s
  where s.company_id=target_company_id and s.id=target_subcontract_id for update;
  if not found then raise exception 'Subcontract not found in company' using errcode='23503'; end if;
  -- Existing retention remains releasable through closed/completed/inactive master lifecycles.
  perform 1 from public.projects p where p.company_id=target_company_id and p.id=subcontract_row.project_id;
  if not found then raise exception 'Subcontract Project is invalid' using errcode='23514'; end if;
  perform 1 from public.parties p where p.company_id=target_company_id
    and p.id=subcontract_row.subcontractor_id and p.type='SUBCONTRACTOR';
  if not found then raise exception 'Subcontractor identity is invalid' using errcode='23514'; end if;
  select a.id into retention_account_id from public.accounts a where a.company_id=target_company_id
    and a.system_key='SUBCONTRACTOR_RETENTION_PAYABLE' and a.status='ACTIVE' and a.account_type='LIABILITY';
  select a.id into payable_account_id from public.accounts a where a.company_id=target_company_id
    and a.system_key='SUBCONTRACTOR_PAYABLE' and a.status='ACTIVE' and a.account_type='LIABILITY';
  if retention_account_id is null or payable_account_id is null then
    raise exception 'Required Retention Release system account is unavailable' using errcode='23514'; end if;

  request_hash:=encode(extensions.digest(convert_to(jsonb_build_object('company_id',target_company_id,
    'release_date',target_release_date,'subcontract_id',target_subcontract_id,
    'total_amount_minor',target_total_amount_minor,'authorization_reference',normalized_authorization_reference,
    'notes',normalized_notes,'allocations',normalized_allocations)::text,'UTF8'),'sha256'),'hex');
  request_row:=private.reserve_financial_command(target_company_id,'POST_RETENTION_RELEASE',
    target_idempotency_key,request_hash,actor_id);
  if request_row.status='COMPLETED' then
    return query select r.id,r.release_reference,r.posted_journal_entry_id,true
    from public.subcontractor_retention_releases r where r.company_id=target_company_id
      and r.posted_journal_entry_id=request_row.resulting_journal_entry_id; return;
  end if;
  new_reference:=private.allocate_reference(target_company_id,'SCREL',extract(year from target_release_date)::integer);
  insert into public.subcontractor_retention_releases(id,company_id,release_reference,release_date,project_id,
    subcontractor_id,subcontract_id,total_amount_minor,authorization_reference,notes,created_by,updated_by)
  values(new_release_id,target_company_id,new_reference,target_release_date,subcontract_row.project_id,
    subcontract_row.subcontractor_id,subcontract_row.id,target_total_amount_minor,
    normalized_authorization_reference,normalized_notes,actor_id,actor_id);
  for item in select x from jsonb_array_elements(normalized_allocations) x
    order by (x->>'certificate_id')::uuid loop
    insert into public.subcontractor_retention_release_allocations(company_id,retention_release_id,
      subcontractor_certificate_id,allocated_amount_minor,created_by)
    values(target_company_id,new_release_id,(item->>'certificate_id')::uuid,
      (item->>'amount_minor')::bigint,actor_id);
  end loop;
  lines:=jsonb_build_array(
    jsonb_build_object('account_id',retention_account_id,'debit_minor',target_total_amount_minor,'credit_minor',0,
      'project_id',subcontract_row.project_id,'party_id',subcontract_row.subcontractor_id,
      'subcontract_id',subcontract_row.id,'memo','Subcontract retention released'),
    jsonb_build_object('account_id',payable_account_id,'debit_minor',0,'credit_minor',target_total_amount_minor,
      'project_id',subcontract_row.project_id,'party_id',subcontract_row.subcontractor_id,
      'subcontract_id',subcontract_row.id,'memo','Released subcontractor payable'));
  new_journal_id:=private.create_journal(target_company_id,target_release_date,
    'Retention Release '||new_reference,'SUBCONTRACTOR_RETENTION_RELEASE',new_release_id,
    'ORIGINAL',lines,actor_id,null);
  update public.subcontractor_retention_releases set status='POSTED',posted_journal_entry_id=new_journal_id,
    posted_at=now(),posted_by=actor_id,updated_by=actor_id where id=new_release_id;
  perform private.complete_financial_command(request_row.id,new_journal_id);
  return query select new_release_id,new_reference,new_journal_id,false;
end;
$$;

create function public.reverse_subcontractor_retention_release(
  target_company_id uuid,target_retention_release_id uuid,target_reversal_date date,
  target_reason text,target_idempotency_key uuid
)
returns table(retention_release_id uuid,release_reference text,reversal_journal_entry_id uuid,replayed boolean)
language plpgsql security definer set search_path='' as $$
declare actor_id uuid:=auth.uid(); normalized_reason text:=btrim(target_reason); request_hash text;
  request_row private.financial_command_requests; release_row public.subcontractor_retention_releases;
  new_journal_id uuid;
begin
  if actor_id is null or not public.has_permission(target_company_id,'accounting.reverse') then
    raise exception 'Not authorized to reverse Retention Releases' using errcode='42501'; end if;
  if target_company_id is null or target_retention_release_id is null or target_reversal_date is null
     or target_idempotency_key is null or normalized_reason is null or length(normalized_reason) not between 1 and 1000 then
    raise exception 'Valid Retention Release reversal inputs are required' using errcode='22023'; end if;
  request_hash:=encode(extensions.digest(convert_to(jsonb_build_object('company_id',target_company_id,
    'retention_release_id',target_retention_release_id,'reversal_date',target_reversal_date,
    'reason',normalized_reason)::text,'UTF8'),'sha256'),'hex');
  request_row:=private.reserve_financial_command(target_company_id,'REVERSE_RETENTION_RELEASE',
    target_idempotency_key,request_hash,actor_id);
  if request_row.status='COMPLETED' then
    return query select r.id,r.release_reference,r.reversal_journal_entry_id,true
    from public.subcontractor_retention_releases r where r.company_id=target_company_id
      and r.reversal_journal_entry_id=request_row.resulting_journal_entry_id; return;
  end if;
  select r.* into release_row from public.subcontractor_retention_releases r
  where r.company_id=target_company_id and r.id=target_retention_release_id;
  if not found then raise exception 'Retention Release not found in company' using errcode='23503'; end if;
  perform 1 from public.subcontracts s where s.company_id=target_company_id and s.id=release_row.subcontract_id for update;
  select r.* into release_row from public.subcontractor_retention_releases r
  where r.company_id=target_company_id and r.id=target_retention_release_id for update;
  if release_row.status<>'POSTED' then
    raise exception 'Only a POSTED Retention Release can be reversed' using errcode='23514'; end if;
  perform 1 from public.subcontractor_certificates c
  join public.subcontractor_retention_release_allocations a on a.subcontractor_certificate_id=c.id
  where a.retention_release_id=release_row.id order by c.id for update of c;
  -- P5I-B will add the live Retention Payment dependency before payments exist.
  new_journal_id:=private.reverse_journal(release_row.posted_journal_entry_id,target_reversal_date,
    'Reversal of '||release_row.release_reference||': '||normalized_reason,actor_id);
  update public.subcontractor_retention_releases set status='REVERSED',reversal_journal_entry_id=new_journal_id,
    reversed_at=now(),reversed_by=actor_id,reversal_reason=normalized_reason,updated_by=actor_id
    where id=release_row.id;
  perform private.complete_financial_command(request_row.id,new_journal_id);
  return query select release_row.id,release_row.release_reference,new_journal_id,false;
end;
$$;

revoke all on function private.protect_subcontractor_retention_release_history()
  from public,anon,authenticated,service_role;
revoke all on function private.validate_subcontractor_retention_release_allocation()
  from public,anon,authenticated,service_role;
revoke all on function private.protect_certificate_with_live_retention_release()
  from public,anon,authenticated,service_role;
revoke all on function public.post_subcontractor_retention_release(uuid,date,uuid,bigint,text,text,jsonb,uuid)
  from public,anon,authenticated,service_role;
revoke all on function public.reverse_subcontractor_retention_release(uuid,uuid,date,text,uuid)
  from public,anon,authenticated,service_role;
grant execute on function public.post_subcontractor_retention_release(uuid,date,uuid,bigint,text,text,jsonb,uuid)
  to authenticated;
grant execute on function public.reverse_subcontractor_retention_release(uuid,uuid,date,text,uuid)
  to authenticated;

comment on table public.subcontractor_retention_releases is
  'P5I-A immutable manual, contract-scoped Retention Release documents; no Treasury movement.';
comment on table public.subcontractor_retention_release_allocations is
  'Immutable Certificate-level Retention Release provenance; only live POSTED Releases consume retention.';
comment on function public.post_subcontractor_retention_release(uuid,date,uuid,bigint,text,text,jsonb,uuid) is
  'Accounting Admin-only Retention reclassification: Dr Retention Payable / Cr Subcontractor Payable.';
