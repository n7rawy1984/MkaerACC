-- 89: future payroll recoveries settle the exact canonical entitlement Project.
-- No backfill or historical journal edits; existing authorization/locks/idempotency preserved.
create or replace function private.hr_post_recoveries(cid uuid,payroll uuid) returns void language plpgsql set search_path='' as $$
declare p public.payroll_postings;r jsonb;x jsonb;loan public.hr_advance_postings;j uuid;rid uuid;payable uuid;entitlement public.payroll_entitlements;net bigint;
begin
 select * into p from public.payroll_postings where company_id=cid and id=payroll;
 for r in select jsonb_array_elements(p.snapshot->'rows') loop
  if not coalesce((r->>'included')::boolean,false) or r->'hr_basis' is null or r->'hr_basis'='null' then continue;end if;
  select * into entitlement from public.payroll_entitlements where company_id=cid and payroll_id=payroll and employee_id=(r->>'employee_id')::uuid;
  payable:=entitlement.payable_account_id;
  for x in select jsonb_array_elements(r->'hr_basis'->'recoveries') loop
   net:=(x->>'amount_minor')::bigint;if net=0 then continue;end if;
 if entitlement.id is null then raise exception 'Canonical employee payroll entitlement required for recovery' using errcode='23514';end if;
   if exists(select 1 from public.hr_recovery_postings where company_id=cid and payroll_id=payroll and advance_id=(x->>'advance_id')::uuid) then continue;end if;
   select * into loan from public.hr_advance_postings where company_id=cid and id=(x->>'advance_id')::uuid for update;
   if loan.employee_id<>(r->>'employee_id')::uuid or loan.posting_date>p.posting_date or coalesce(private.hr_recovery_balance(cid,loan.id),0)<net or net>loan.monthly_limit_minor then raise exception 'Approved recovery no longer eligible' using errcode='23514';end if;
   rid:=gen_random_uuid();j:=private.create_journal(cid,p.posting_date,'Approved payroll advance recovery','HR_PAYROLL_RECOVERY',rid,'POST',jsonb_build_array(jsonb_build_object('account_id',payable,'project_id',entitlement.project_id,'party_id',loan.employee_id,'debit_minor',net::text,'credit_minor','0'),jsonb_build_object('account_id',loan.account_id,'party_id',loan.employee_id,'debit_minor','0','credit_minor',net::text)),auth.uid());
   insert into public.hr_recovery_postings(id,company_id,advance_id,payroll_id,amount_minor,journal_id) values(rid,cid,loan.id,payroll,net,j);
  end loop;
 end loop;
end;$$;

revoke all on function private.hr_post_recoveries(uuid,uuid) from public,anon,authenticated,service_role;
