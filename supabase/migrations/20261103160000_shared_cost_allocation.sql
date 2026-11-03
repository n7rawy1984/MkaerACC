-- Extend the existing correction receipt, period and exact-reversal mechanism.
alter table public.project_cost_corrections add column allocation_plan jsonb,
 add constraint correction_allocation_plan_object check(allocation_plan is null or jsonb_typeof(allocation_plan)='object');

create function private.shared_cost_plan(amount bigint,plan jsonb) returns jsonb
language plpgsql immutable set search_path='' as $$
declare method text;basis text;support text;driver text;unit text;d jsonb;normalized jsonb;result jsonb;total numeric;begin
 if amount is null or amount<=0 or plan is null or jsonb_typeof(plan)<>'object' or (plan-array['method','basis','support','driver','unit','destinations'])<>'{}'::jsonb then raise exception 'Invalid allocation plan' using errcode='22023';end if;
 method:=plan->>'method';basis:=private.correction_text(plan->>'basis');support:=private.correction_text(plan->>'support');driver:=private.correction_text(plan->>'driver');unit:=private.correction_text(plan->>'unit');
 if method is null or method not in ('DIRECT','PERCENT','QUANTITY','INDIRECT') or basis is null or support is null or length(basis)>500 or length(support)>500 or coalesce(length(driver),0)>100 or coalesce(length(unit),0)>50 then raise exception 'Documented allocation basis and support required' using errcode='22023';end if;
 if method in ('QUANTITY','INDIRECT') and (driver is null or unit is null) then raise exception 'Measurable driver and unit required' using errcode='22023';end if;
 if jsonb_typeof(plan->'destinations') is distinct from 'array' then raise exception 'Destinations required' using errcode='22023';end if;
 if jsonb_array_length(plan->'destinations') not between 1 and 20 or (method='DIRECT' and jsonb_array_length(plan->'destinations')<>1) or (method<>'DIRECT' and jsonb_array_length(plan->'destinations')<2) then raise exception 'Invalid destination count' using errcode='22023';end if;
 for d in select value from jsonb_array_elements(plan->'destinations') loop
  if jsonb_typeof(d)<>'object' or (d-array['project_id','weight'])<>'{}'::jsonb or not(d?'project_id') or jsonb_typeof(d->'weight') is distinct from 'string' or coalesce(d->>'weight','') !~ '^[0-9]{1,16}$' then raise exception 'Invalid destination' using errcode='22023';end if;
  if (d->>'weight')::numeric not between 1 and 9000000000000000 or (d->>'project_id' is not null and jsonb_typeof(d->'project_id')<>'string') then raise exception 'Invalid allocation weight' using errcode='22023';end if;
 end loop;
 select jsonb_agg(jsonb_build_object('project_id',(v->>'project_id')::uuid,'weight',((v->>'weight')::numeric)::text) order by coalesce(((v->>'project_id')::uuid)::text,'~') collate "C"),sum((v->>'weight')::numeric) into normalized,total from jsonb_array_elements(plan->'destinations') v;
 if (select count(distinct coalesce(v->>'project_id','~')) from jsonb_array_elements(normalized) v)<>jsonb_array_length(normalized) then raise exception 'Duplicate allocation destination' using errcode='22023';end if;
 if (method='PERCENT' and total<>10000) or (method='DIRECT' and total<>1) then raise exception 'Percentages must total 100 percent' using errcode='22023';end if;
 -- Largest remainder; equal residuals use canonical UUID order, overhead last.
 with shares as (select v,coalesce(v->>'project_id','~') k,div(amount::numeric*(v->>'weight')::numeric,total) whole,mod(amount::numeric*(v->>'weight')::numeric,total) remainder from jsonb_array_elements(normalized) v),
 ranked as(select *,row_number() over(order by remainder desc,k collate "C") rank,amount-sum(whole) over() residual from shares)
 select jsonb_agg(v||jsonb_build_object('amount_minor',(whole+case when rank<=residual then 1 else 0 end)::bigint::text) order by k collate "C") into result from ranked;
 if exists(select 1 from jsonb_array_elements(result) v where (v->>'amount_minor')::bigint<=0) then raise exception 'Allocation below one minor unit; revise destinations or weights' using errcode='23514';end if;
 return jsonb_build_object('method',method,'basis',basis,'support',support,'driver',driver,'unit',unit,'rounding','LARGEST_REMAINDER_V1','weight_scale',case when method='PERCENT' then 100 when method='DIRECT' then 1 else 1000000 end,'destinations',result);
end;$$;
revoke all on function private.shared_cost_plan(bigint,jsonb) from public,anon,authenticated,service_role;

create function public.execute_shared_cost_allocation(target_company_id uuid,target_review_id uuid,request_id uuid,plan jsonb,basis_approved boolean,unreconciled_confirmed boolean,evidence_reference text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;r public.expense_correction_reviews;e public.expenses;c public.project_cost_corrections;effect jsonb;allocation jsonb;d jsonb;digest text;cid uuid:=gen_random_uuid();jid uuid;lines jsonb:='[]';aid uuid;pid uuid;today date:=(statement_timestamp() at time zone 'UTC')::date;ev text:=private.correction_text(evidence_reference);begin
 perform 1 from public.companies where id=target_company_id for share;actor:=private.correction_authority(target_company_id);
 if request_id is null or target_review_id is null or basis_approved is distinct from true or unreconciled_confirmed is distinct from true or ev is null or length(ev)>500 then raise exception 'Approved basis and unreconciled evidence required' using errcode='22023';end if;
 select * into r from public.expense_correction_reviews where company_id=target_company_id and id=target_review_id;
 if not found then raise exception 'Review unavailable' using errcode='42501';end if;
 select * into e from public.expenses where company_id=target_company_id and id=r.expense_id;
 allocation:=private.shared_cost_plan(e.net_amount_minor,plan);
 digest:=encode(extensions.digest(jsonb_build_object('command','SHARED_V1','actor',actor,'company',target_company_id,'review',target_review_id,'plan',allocation,'basis_approved',true,'unreconciled',true,'evidence',ev)::text,'sha256'),'hex');
 perform pg_advisory_xact_lock(hashtextextended('project-cost-correction:'||target_company_id::text||':'||request_id::text,0));
 select * into c from public.project_cost_corrections x where x.company_id=target_company_id and x.request_id=execute_shared_cost_allocation.request_id;
 if found then if c.input_hash<>digest then raise exception 'Request changed' using errcode='22023';end if;return (to_jsonb(c)-'input_hash')||jsonb_build_object('amount_minor',c.amount_minor::text);end if;
 -- The reviewed destination is the anchor; the confirmed plan is the full allocation.
 if not exists(select 1 from jsonb_array_elements(allocation->'destinations') v where (v->>'project_id')::uuid is not distinct from r.proposed_project_id) then raise exception 'Reviewed destination must be included' using errcode='23514';end if;
 for pid in select distinct p from (select (v->>'project_id')::uuid p from jsonb_array_elements(allocation->'destinations') v union select r.original_project_id union select r.proposed_project_id) x where p is not null order by p loop
  perform 1 from public.projects where company_id=target_company_id and id=pid and status='ACTIVE' for share;
  if not found then raise exception 'Active Company Project required' using errcode='42501';end if;
 end loop;
 select * into e from public.expenses where company_id=target_company_id and id=r.expense_id for update;
 if exists(select 1 from public.project_cost_corrections x where x.review_id=r.id) then raise exception 'Review already executed' using errcode='23514';end if;
 effect:=private.project_correction_check(target_company_id,target_review_id);
 if not(effect->>'eligible')::boolean then raise exception 'Correction blocked: %',effect->>'blocker' using errcode='23514';end if;
 perform 1 from public.treasury_accounts where company_id=target_company_id and id=e.treasury_account_id for share;
 perform 1 from public.accounts where company_id=target_company_id and (system_key in ('PROJECT_COST','COMPANY_EXPENSE') or id=(effect->>'source_account_id')::uuid) order by id for share;
 effect:=private.project_correction_check(target_company_id,target_review_id);
 if not(effect->>'eligible')::boolean then raise exception 'Correction blocked: %',effect->>'blocker' using errcode='23514';end if;
 for d in select value from jsonb_array_elements(allocation->'destinations') loop
  select id into aid from public.accounts where company_id=target_company_id and system_key=case when d->>'project_id' is null then 'COMPANY_EXPENSE'::public.system_account_key else 'PROJECT_COST'::public.system_account_key end and status='ACTIVE' and account_type='EXPENSE';
  if aid is null then raise exception 'Cost mapping unavailable' using errcode='23514';end if;
  lines:=lines||jsonb_build_array(jsonb_build_object('account_id',aid,'debit_minor',d->>'amount_minor','credit_minor','0','project_id',d->>'project_id','memo',r.reason));
 end loop;
 lines:=lines||jsonb_build_array(jsonb_build_object('account_id',effect->>'source_account_id','debit_minor','0','credit_minor',e.net_amount_minor::text,'project_id',e.project_id,'memo',r.reason));
 jid:=private.create_journal(target_company_id,today,'Shared cost allocation: '||e.expense_reference,'PROJECT_COST_CORRECTION',cid,'POST',lines,actor);
 insert into public.project_cost_corrections(id,company_id,expense_id,review_id,correction_reference,request_id,actor_id,correction_date,month,original_project_id,corrected_project_id,source_account_id,destination_account_id,amount_minor,original_journal_entry_id,journal_entry_id,reason,evidence_reference,unreconciled_attested,input_hash,allocation_plan)
 values(cid,target_company_id,e.id,r.id,private.allocate_reference(target_company_id,'PCC',extract(year from today)::integer),request_id,actor,today,date_trunc('month',today)::date,e.project_id,r.proposed_project_id,(effect->>'source_account_id')::uuid,(effect->>'destination_account_id')::uuid,e.net_amount_minor,e.posted_journal_entry_id,jid,r.reason,ev,true,digest,allocation);
 return (select (to_jsonb(x)-'input_hash')||jsonb_build_object('amount_minor',x.amount_minor::text) from public.project_cost_corrections x where id=cid);
end;$$;
revoke all on function public.execute_shared_cost_allocation(uuid,uuid,uuid,jsonb,boolean,boolean,text) from public,anon,authenticated,service_role;
grant execute on function public.execute_shared_cost_allocation(uuid,uuid,uuid,jsonb,boolean,boolean,text) to authenticated;
