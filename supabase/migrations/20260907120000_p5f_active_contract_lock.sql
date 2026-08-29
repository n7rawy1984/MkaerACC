-- Retrospective P0-P5G correction: serialize the P5F ACTIVE lifecycle check
-- with Subcontract status transitions before delegating to the applied
-- posting implementation. This changes no existing Advance or journal.

create or replace function public.post_subcontractor_advance(
  target_company_id uuid, target_advance_date date, target_subcontract_id uuid,
  target_treasury_account_id uuid, target_amount_minor bigint, target_payment_method public.payment_method,
  target_external_reference text, target_notes text, target_idempotency_key uuid
)
returns table (subcontractor_advance_id uuid, advance_reference text, journal_entry_id uuid, replayed boolean)
language plpgsql security definer set search_path = '' as $$
declare
  locked_status public.subcontract_status;
begin
  if auth.uid() is null or not public.has_permission(target_company_id, 'accounting.post') then
    raise exception 'Not authorized to post Subcontractor Advances' using errcode = '42501';
  end if;
  select s.status into locked_status
  from public.subcontracts s
  where s.company_id = target_company_id and s.id = target_subcontract_id
  for update;
  if locked_status is distinct from 'ACTIVE' then
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
  'P5F active-only posting boundary with a serialized Subcontract lifecycle check.';
