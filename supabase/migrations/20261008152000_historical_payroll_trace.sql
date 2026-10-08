-- Link only user-verified Payroll profiles to canonical posted monthly entitlements.
-- This does not change Payroll calculation, source net or attendance.
create function private.link_historical_payroll_entitlement() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 update public.historical_source_records s set payroll_entitlement_id=new.id,
  updated_by=auth.uid(),updated_at=clock_timestamp()
 from public.payroll_profiles profile,public.payroll_postings posting,public.payroll_draft_periods period
 where s.company_id=new.company_id and s.record_type='PAYROLL' and s.review_status<>'CANCELLED'
  and s.payroll_entitlement_id is null and s.payroll_profile_id=profile.id
  and profile.company_id=new.company_id and profile.employee_id=new.employee_id
  and posting.company_id=new.company_id and posting.id=new.payroll_id
  and period.company_id=new.company_id and period.id=posting.period_id
  and s.source_month=to_char(period.month,'YYYY-MM');
 return new;
end $$;
revoke all on function private.link_historical_payroll_entitlement() from public,anon,authenticated,service_role;
create trigger historical_payroll_entitlement_link after insert on public.payroll_entitlements
 for each row execute function private.link_historical_payroll_entitlement();

-- Match existing Payroll company-lock order before source/profile locks.
create or replace function public.link_historical_payroll_profile(target_company_id uuid,target_source_id uuid,target_profile_id uuid)
returns void language plpgsql security definer set search_path='' as $$
declare r public.historical_source_records;p public.payroll_profiles;expected text;
begin
 if auth.uid() is null or not public.has_permission(target_company_id,'payroll.manage') then raise exception 'Denied' using errcode='42501';end if;
 perform private.attendance_company_lock(target_company_id);
 select * into r from public.historical_source_records where company_id=target_company_id and id=target_source_id for update;
 if not found or r.record_type<>'PAYROLL' or r.review_status='CANCELLED' or r.payroll_entitlement_id is not null then raise exception 'Source unavailable' using errcode='23514';end if;
 select * into p from public.payroll_profiles where company_id=target_company_id and id=target_profile_id for share;
 expected:=coalesce(nullif(r.completion->>'employee_id',''),nullif(r.raw_source->>'Payroll ID',''));
 if not found or expected is null or p.payroll_id<>expected or (r.payroll_profile_id is not null and r.payroll_profile_id<>p.id) then raise exception 'Complete and verify source payroll identifier before linking' using errcode='23514';end if;
 if r.payroll_profile_id is null then update public.historical_source_records set payroll_profile_id=p.id,updated_by=auth.uid(),updated_at=clock_timestamp() where id=r.id;end if;
end $$;
