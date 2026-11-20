--105 / CR07: ordinary stock accounting uses configured fiscal periods, not source-reclassification policy.
-- No financial seeds, backfill, current-period source-correction relaxation or RLS/grant changes.
do $$declare d text;begin
 d:=pg_get_functiondef('private.inventory_plan(uuid,jsonb)'::regprocedure);
 if position('or date_trunc(''month'',(v->>''date'')::date)<>date_trunc(''month'',current_date)'in d)=0 or position('perform private.check_source_allocation_period(cid,(v->>''date'')::date)'in d)=0 then raise exception 'Unexpected canonical Inventory period guard';end if;
 d:=replace(d,' or date_trunc(''month'',(v->>''date'')::date)<>date_trunc(''month'',current_date)',' ');
 d:=replace(d,'Current-period chronological document date required','Actual non-future chronological Inventory date required');
 d:=replace(d,'perform private.check_source_allocation_period(cid,(v->>''date'')::date)','perform private.opening_period(cid,(v->>''date'')::date)');
 execute d;
end$$;
-- COUNT and TRANSFER can be journal-free. Enforce the same configured fiscal gate
-- at planning/approval time as journal-producing Inventory documents.
do $$declare d text;begin
 d:=pg_get_functiondef('private.inventory_plan(uuid,jsonb)'::regprocedure);
 if position('perform private.opening_period(cid,(v->>''date'')::date)'in d)=0 then raise exception 'Unexpected Inventory date validation';end if;
 d:=replace(d,'perform private.opening_period(cid,(v->>''date'')::date);',
 'perform private.opening_period(cid,(v->>''date'')::date);
 if not pg_try_advisory_xact_lock_shared(hashtextextended(''NARVO:FISCAL:''||cid::text,0))then raise exception ''Accounting period transition in progress; retry the same request''using errcode=''40001'';end if;
 if exists(select 1 from public.accounting_fiscal_years where company_id=cid)and not exists(select 1 from public.accounting_fiscal_periods where company_id=cid and state=''OPEN''and (v->>''date'')::date between from_date and through_date)then raise exception ''Inventory date has no open accounting period''using errcode=''23514'';end if;');
 execute d;
end$$;
