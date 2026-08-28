-- P5C forward correction: make the caller's stated Supplier Payment total
-- explicit and reject any mismatch with the authoritative allocation sum.
-- Move the already-applied implementation into private and expose a narrow
-- validating wrapper; do not rewrite shared migration history.

revoke execute on function public.post_supplier_payment(uuid, date, uuid, uuid,
  public.payment_method, text, text, jsonb, uuid) from authenticated;
alter function public.post_supplier_payment(uuid, date, uuid, uuid,
  public.payment_method, text, text, jsonb, uuid) set schema private;
revoke all on function private.post_supplier_payment(uuid, date, uuid, uuid,
  public.payment_method, text, text, jsonb, uuid)
  from public, anon, authenticated, service_role;

create function public.post_supplier_payment(
  target_company_id uuid,
  target_payment_date date,
  target_supplier_id uuid,
  target_treasury_account_id uuid,
  target_total_amount_minor bigint,
  target_payment_method public.payment_method,
  target_external_reference text,
  target_notes text,
  target_allocations jsonb,
  target_idempotency_key uuid
)
returns table (supplier_payment_id uuid, payment_reference text, journal_entry_id uuid, replayed boolean)
language plpgsql
security definer
set search_path = ''
as $$
declare allocation_total numeric;
begin
  if target_total_amount_minor is null
     or target_total_amount_minor not between 1 and 9000000000000000 then
    raise exception 'Supplier Payment total is invalid' using errcode = '22023';
  end if;
  if target_allocations is null or jsonb_typeof(target_allocations) <> 'array' then
    raise exception 'Supplier Payment allocations must be a JSON array' using errcode = '22023';
  end if;
  select sum((x ->> 'amount_minor')::numeric) into allocation_total
  from jsonb_array_elements(target_allocations) x;
  if allocation_total is distinct from target_total_amount_minor::numeric then
    raise exception 'Supplier Payment total must equal allocation total'
      using errcode = '23514';
  end if;
  return query select * from private.post_supplier_payment(
    target_company_id, target_payment_date, target_supplier_id, target_treasury_account_id,
    target_payment_method, target_external_reference, target_notes, target_allocations,
    target_idempotency_key
  );
end;
$$;

revoke all on function public.post_supplier_payment(uuid, date, uuid, uuid, bigint,
  public.payment_method, text, text, jsonb, uuid)
  from public, anon, authenticated, service_role;
grant execute on function public.post_supplier_payment(uuid, date, uuid, uuid, bigint,
  public.payment_method, text, text, jsonb, uuid) to authenticated;

comment on function public.post_supplier_payment(uuid, date, uuid, uuid, bigint,
  public.payment_method, text, text, jsonb, uuid) is
  'Specialized authenticated Supplier Payment command; verifies stated total equals locked Expense allocations before Treasury/AP settlement.';
