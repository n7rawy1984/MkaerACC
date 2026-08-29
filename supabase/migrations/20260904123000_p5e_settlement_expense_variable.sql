-- P5E forward correction: remove PL/pgSQL ambiguity between the local
-- Expense UUID variable and custody_settlement_items.expense_id.

create or replace function public.finalize_custody_settlement(
  target_company_id uuid,
  target_settlement_date date,
  target_custodian_id uuid,
  target_expense_ids uuid[],
  target_expected_total_minor bigint,
  target_notes text
)
returns table (custody_settlement_id uuid, settlement_reference text, total_expenses_minor bigint)
language plpgsql security definer set search_path = '' as $$
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
    and p.id = target_custodian_id and p.type = 'CUSTODIAN' for update;
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
$$;

revoke all on function public.finalize_custody_settlement(uuid,date,uuid,uuid[],bigint,text)
  from public,anon,authenticated,service_role;
grant execute on function public.finalize_custody_settlement(uuid,date,uuid,uuid[],bigint,text)
  to authenticated;
