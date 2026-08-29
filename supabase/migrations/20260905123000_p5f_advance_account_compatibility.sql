-- P5F forward correction: the established SUBCONTRACTOR_ADVANCE stable-key
-- account does not need its generic requires_party master flag enabled because
-- the P5F command always writes the authoritative party dimension explicitly.

create or replace function public.post_subcontractor_advance(
  target_company_id uuid, target_advance_date date, target_subcontract_id uuid,
  target_treasury_account_id uuid, target_amount_minor bigint, target_payment_method public.payment_method,
  target_external_reference text, target_notes text, target_idempotency_key uuid
)
returns table (subcontractor_advance_id uuid, advance_reference text, journal_entry_id uuid, replayed boolean)
language plpgsql security definer set search_path = '' as $$
declare
  actor_id uuid := auth.uid(); normalized_external_reference text := nullif(btrim(target_external_reference), '');
  normalized_notes text := nullif(btrim(target_notes), ''); subcontract_row public.subcontracts;
  project_row public.projects; treasury_row public.treasury_accounts; advance_account_id uuid;
  request_hash text; request_row private.financial_command_requests; new_advance_id uuid := gen_random_uuid();
  new_reference text; new_journal_id uuid; journal_lines jsonb;
begin
  if actor_id is null or not public.has_permission(target_company_id, 'accounting.post') then
    raise exception 'Not authorized to post Subcontractor Advances' using errcode = '42501';
  end if;
  if target_company_id is null or target_advance_date is null or target_subcontract_id is null
     or target_treasury_account_id is null or target_amount_minor is null
     or target_payment_method is null or target_idempotency_key is null then
    raise exception 'Required Subcontractor Advance input is missing' using errcode = '22023';
  end if;
  if target_amount_minor not between 1 and 9000000000000000 then
    raise exception 'Subcontractor Advance amount is invalid' using errcode = '22023';
  end if;
  if normalized_external_reference is not null and length(normalized_external_reference) > 200 then
    raise exception 'External reference is too long' using errcode = '22023';
  end if;
  if normalized_notes is not null and length(normalized_notes) > 2000 then
    raise exception 'Subcontractor Advance notes are too long' using errcode = '22023';
  end if;
  select s.* into subcontract_row from public.subcontracts s
  where s.company_id = target_company_id and s.id = target_subcontract_id for update;
  if not found then raise exception 'Subcontract not found in company' using errcode = '23503'; end if;
  if subcontract_row.status = 'CLOSED' then
    raise exception 'Closed Subcontract cannot receive a new Advance' using errcode = '23514';
  end if;
  select p.* into project_row from public.projects p
  where p.company_id = target_company_id and p.id = subcontract_row.project_id;
  if not found then raise exception 'Subcontract Project not found in company' using errcode = '23503'; end if;
  if project_row.status = 'CLOSED' then
    raise exception 'Closed Project cannot receive a new Subcontractor Advance' using errcode = '23514';
  end if;
  perform 1 from public.parties p where p.company_id = target_company_id
    and p.id = subcontract_row.subcontractor_id and p.type = 'SUBCONTRACTOR' and p.status = 'ACTIVE' for update;
  if not found then raise exception 'Active Subcontractor not found in company' using errcode = '23514'; end if;
  select t.* into treasury_row from public.treasury_accounts t
  join public.accounts a on a.company_id = t.company_id and a.id = t.gl_account_id
  where t.company_id = target_company_id and t.id = target_treasury_account_id
    and t.status = 'ACTIVE' and a.status = 'ACTIVE' and a.account_type = 'ASSET';
  if not found then raise exception 'Active same-company Treasury with active Asset GL is required' using errcode = '23514'; end if;
  if treasury_row.project_id is not null and treasury_row.project_id <> subcontract_row.project_id then
    raise exception 'Project Treasury may fund only its own Project' using errcode = '23514';
  end if;
  select a.id into advance_account_id from public.accounts a
  where a.company_id = target_company_id and a.system_key = 'SUBCONTRACTOR_ADVANCE'
    and a.status = 'ACTIVE' and a.account_type = 'ASSET';
  if advance_account_id is null then raise exception 'Subcontractor Advance system account is unavailable' using errcode = '23514'; end if;
  request_hash := encode(extensions.digest(convert_to(jsonb_build_object(
    'company_id', target_company_id, 'advance_date', target_advance_date, 'subcontract_id', target_subcontract_id,
    'treasury_id', target_treasury_account_id, 'amount_minor', target_amount_minor,
    'payment_method', target_payment_method, 'external_reference', normalized_external_reference,
    'notes', normalized_notes
  )::text, 'UTF8'), 'sha256'), 'hex');
  request_row := private.reserve_financial_command(target_company_id, 'POST_SUBCONTRACTOR_ADVANCE',
    target_idempotency_key, request_hash, actor_id);
  if request_row.status = 'COMPLETED' then
    return query select a.id, a.advance_reference, a.posted_journal_entry_id, true
    from public.subcontractor_advances a where a.company_id = target_company_id
      and a.posted_journal_entry_id = request_row.resulting_journal_entry_id;
    return;
  end if;
  new_reference := private.allocate_reference(target_company_id, 'SADV', extract(year from target_advance_date)::integer);
  insert into public.subcontractor_advances (id, company_id, advance_reference, advance_date, project_id,
    subcontractor_id, subcontract_id, treasury_account_id, amount_minor, payment_method,
    external_reference, notes, created_by, updated_by)
  values (new_advance_id, target_company_id, new_reference, target_advance_date, subcontract_row.project_id,
    subcontract_row.subcontractor_id, subcontract_row.id, target_treasury_account_id, target_amount_minor,
    target_payment_method, normalized_external_reference, normalized_notes, actor_id, actor_id);
  journal_lines := jsonb_build_array(
    jsonb_build_object('account_id', advance_account_id, 'debit_minor', target_amount_minor, 'credit_minor', 0,
      'project_id', subcontract_row.project_id, 'party_id', subcontract_row.subcontractor_id,
      'subcontract_id', subcontract_row.id, 'memo', 'Subcontractor Advance funded'),
    jsonb_build_object('account_id', treasury_row.gl_account_id, 'debit_minor', 0, 'credit_minor', target_amount_minor,
      'project_id', subcontract_row.project_id, 'treasury_account_id', target_treasury_account_id,
      'subcontract_id', subcontract_row.id, 'memo', 'Subcontractor Advance treasury funding'));
  new_journal_id := private.create_journal(target_company_id, target_advance_date,
    'Subcontractor Advance ' || new_reference, 'SUBCONTRACTOR_ADVANCE', new_advance_id,
    'ORIGINAL', journal_lines, actor_id, null);
  update public.subcontractor_advances set status = 'POSTED', posted_journal_entry_id = new_journal_id,
    posted_at = now(), posted_by = actor_id, updated_by = actor_id where id = new_advance_id;
  perform private.complete_financial_command(request_row.id, new_journal_id);
  return query select new_advance_id, new_reference, new_journal_id, false;
end;
$$;

revoke all on function public.post_subcontractor_advance(uuid,date,uuid,uuid,bigint,public.payment_method,text,text,uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.post_subcontractor_advance(uuid,date,uuid,uuid,bigint,public.payment_method,text,text,uuid)
  to authenticated;
