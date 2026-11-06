-- 87: operational document/report integration. Additive; no financial backfill.
create function private.guard_reimbursement_project() returns trigger
language plpgsql security definer set search_path='' as $$
declare original_project uuid;
begin
 if new.kind='PERSONAL_REIMBURSEMENT' then
  select p.project_id into original_project from public.operational_liability_postings p
   where p.company_id=new.company_id and p.id=new.parent_posting_id and p.kind='PERSONAL_EXPENSE_RECOGNITION';
  if not found or new.project_id is distinct from original_project then
   raise exception 'Reimbursement Project must match its original liability; select matching reviewed evidence' using errcode='23514';
  end if;
 end if;
 return new;
end;$$;
revoke all on function private.guard_reimbursement_project() from public,anon,authenticated,service_role;
create trigger reimbursement_project_boundary before insert on public.operational_liability_postings
 for each row execute function private.guard_reimbursement_project();

-- Return accounting-only flags for already visible journal IDs. Never expose HR
-- source/person/approval/amounts to ordinary accounting readers.
create function public.read_operational_correction_movements(cid uuid,journal_ids uuid[])
returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if auth.uid() is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'MANAGEMENT_VIEWER')) then
  raise exception 'Company accounting read authority required' using errcode='42501';
 end if;
 if journal_ids is null or cardinality(journal_ids)>500 or array_position(journal_ids,null)is not null then
  raise exception 'At most 500 explicit journal IDs required' using errcode='22023';
 end if;
 return coalesce((select jsonb_agg(jsonb_build_object(
  'journal_id',j.id,'phase',case when j.id=e.reversal_journal_id then 'REVERSAL' else 'REPLACEMENT' end,
  'actual_new_payment',false,
  'correction_id',case when not e.hr_sensitive or public.has_permission(cid,'payroll.manage') then e.id end,
  'source_id',case when not e.hr_sensitive or public.has_permission(cid,'payroll.manage') then e.source_id end,
  'original_payment_date',case when not e.hr_sensitive or public.has_permission(cid,'payroll.manage') then e.replacement->>'original_payment_date' end,
  'original_payment_journal',case when not e.hr_sensitive or public.has_permission(cid,'payroll.manage') then e.replacement->>'original_payment_journal' end,
  'restricted',e.hr_sensitive and not public.has_permission(cid,'payroll.manage'))order by j.id)
 from public.source_reclassification_events e join public.journal_entries j on j.company_id=e.company_id
  and (j.id=e.reversal_journal_id or j.id=(e.replacement->>'journal')::uuid)
 where e.company_id=cid and e.state='POSTED' and j.id=any(journal_ids)and public.payroll_journal_visible(cid,j.id)), '[]'::jsonb);
end;$$;
revoke all on function public.read_operational_correction_movements(uuid,uuid[]) from public,anon,authenticated,service_role;
grant execute on function public.read_operational_correction_movements(uuid,uuid[]) to authenticated;
