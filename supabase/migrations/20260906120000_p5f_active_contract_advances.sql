-- Pre-P5G lifecycle hardening: new funding is commercial activity and is
-- allowed only while the Subcontract is ACTIVE. Existing P5F history and
-- later Certificate/recovery/payment cleanup remain unaffected.

revoke execute on function public.post_subcontractor_advance(uuid,date,uuid,uuid,bigint,
  public.payment_method,text,text,uuid) from authenticated;
alter function public.post_subcontractor_advance(uuid,date,uuid,uuid,bigint,
  public.payment_method,text,text,uuid) set schema private;
revoke all on function private.post_subcontractor_advance(uuid,date,uuid,uuid,bigint,
  public.payment_method,text,text,uuid) from public,anon,authenticated,service_role;

create function public.post_subcontractor_advance(
  target_company_id uuid, target_advance_date date, target_subcontract_id uuid,
  target_treasury_account_id uuid, target_amount_minor bigint, target_payment_method public.payment_method,
  target_external_reference text, target_notes text, target_idempotency_key uuid
)
returns table (subcontractor_advance_id uuid, advance_reference text, journal_entry_id uuid, replayed boolean)
language plpgsql security definer set search_path = '' as $$
begin
  if auth.uid() is null or not public.has_permission(target_company_id, 'accounting.post') then
    raise exception 'Not authorized to post Subcontractor Advances' using errcode = '42501';
  end if;
  if not exists (
    select 1 from public.subcontracts s
    where s.company_id = target_company_id and s.id = target_subcontract_id and s.status = 'ACTIVE'
  ) then
    raise exception 'Only an ACTIVE Subcontract can receive a new Advance' using errcode = '23514';
  end if;
  return query select * from private.post_subcontractor_advance(
    target_company_id, target_advance_date, target_subcontract_id, target_treasury_account_id,
    target_amount_minor, target_payment_method, target_external_reference, target_notes,
    target_idempotency_key
  );
end;
$$;

revoke all on function public.post_subcontractor_advance(uuid,date,uuid,uuid,bigint,
  public.payment_method,text,text,uuid) from public,anon,authenticated,service_role;
grant execute on function public.post_subcontractor_advance(uuid,date,uuid,uuid,bigint,
  public.payment_method,text,text,uuid) to authenticated;

comment on function public.post_subcontractor_advance(uuid,date,uuid,uuid,bigint,
  public.payment_method,text,text,uuid) is
  'P5F posting boundary hardened before P5G: only ACTIVE Subcontracts receive new funding.';
