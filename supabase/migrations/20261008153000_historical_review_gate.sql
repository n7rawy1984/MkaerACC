-- Require explicit source completion review before new Expense recognition.
create or replace function public.post_historical_expense(target_company_id uuid,target_source_id uuid,business_input jsonb)
returns table(expense_id uuid,expense_reference text,journal_entry_id uuid,replayed boolean)
language plpgsql security definer set search_path='' as $$
declare r public.historical_source_records; result record; v jsonb:=business_input; gross bigint; vat bigint;
begin
 if auth.uid() is null or not public.has_permission(target_company_id,'accounting.post') then raise exception 'Denied' using errcode='42501';end if;
 select * into r from public.historical_source_records where company_id=target_company_id and id=target_source_id for update;
 if not found or r.record_type<>'GENERAL' or r.review_status<>'REVIEWED' or r.cash_treasury_id is null or coalesce(r.outflow_minor,0)<=0
 or coalesce(r.completion->>'nature',r.classification->>'nature')<>'EXPENSE' then raise exception 'Complete recognized expense source first' using errcode='23514';end if;
 if (v->>'target_expense_date')::date is distinct from coalesce(nullif(r.completion->>'date','')::date,r.source_date)
 or btrim(v->>'target_description') is distinct from btrim(coalesce(r.completion->>'description',r.description)) then
  raise exception 'Save confirmed source date and description before posting' using errcode='23514';end if;
 if (v->>'target_treasury_account_id')::uuid is distinct from r.cash_treasury_id or v->>'target_funding_mode'<>'TREASURY' or v->>'target_payment_method'<>'CASH' then raise exception 'Confirmed cash source mismatch' using errcode='23514';end if;
 vat:=case v->>'target_vat_mode' when 'ZERO' then 0 when 'AUTO_5' then round((v->>'target_net_amount_minor')::numeric*5/100)::bigint else (v->>'target_manual_vat_amount_minor')::bigint end;
 gross:=(v->>'target_net_amount_minor')::bigint+vat;
 if gross is distinct from coalesce((r.completion->>'amount_minor')::bigint,r.outflow_minor) then raise exception 'Gross must match completed source outflow' using errcode='23514';end if;
 select * into result from public.post_expense(target_company_id,(v->>'target_expense_date')::date,(v->>'target_project_id')::uuid,(v->>'target_expense_category_id')::uuid,v->>'target_description',(v->>'target_net_amount_minor')::bigint,(v->>'target_vat_mode')::public.expense_vat_mode,(v->>'target_manual_vat_amount_minor')::bigint,'TREASURY',r.cash_treasury_id,null,(v->>'target_supplier_id')::uuid,'CASH',(v->>'target_has_tax_invoice')::boolean,v->>'target_invoice_number',v->>'target_notes',r.id);
 if r.expense_id is not null and r.expense_id<>result.expense_id then raise exception 'Source already linked';end if;
 if r.expense_id is null then update public.historical_source_records set expense_id=result.expense_id,updated_by=auth.uid(),updated_at=clock_timestamp() where id=r.id;end if;
 return query select result.expense_id,result.expense_reference,result.journal_entry_id,result.replayed;
end $$;

-- Capture all canonical links and cash confirmations in append-only review history.
create or replace function private.audit_historical_source() returns trigger language plpgsql security definer set search_path='' as $$
begin
 insert into public.historical_source_audit(company_id,source_id,actor_id,action,before_state,after_state)
 values(new.company_id,new.id,coalesce(new.updated_by,new.created_by),
 case when new.review_status='CANCELLED' then 'CANCEL'
  when new.expense_id is distinct from old.expense_id or new.payroll_entitlement_id is distinct from old.payroll_entitlement_id then 'POST_LINK'
  when new.payroll_profile_id is distinct from old.payroll_profile_id then 'PROFILE_LINK'
  when new.cash_treasury_id is distinct from old.cash_treasury_id then 'CASH_CONFIRM' else 'COMPLETE' end,
 jsonb_build_object('completion',old.completion,'status',old.review_status,'expense_id',old.expense_id,'payroll_entitlement_id',old.payroll_entitlement_id,'payroll_profile_id',old.payroll_profile_id,'cash_treasury_id',old.cash_treasury_id),
 jsonb_build_object('completion',new.completion,'status',new.review_status,'expense_id',new.expense_id,'payroll_entitlement_id',new.payroll_entitlement_id,'payroll_profile_id',new.payroll_profile_id,'cash_treasury_id',new.cash_treasury_id));
 return new;
end $$;
