-- 97: Fixed assets and period-based recognition, through the existing journal kernel.
-- Straight-line, explicit residual/life, completed calendar-month convention; no tax depreciation claim.
create or replace function private.commercial_control_type(k text)returns text language sql immutable set search_path='' as $$
 select case when k in('AR','ASSET_COST','ACCUMULATED_DEPRECIATION','PREPAYMENT')then 'ASSET'
 when k in('CUSTOMER_ADVANCE','OUTPUT_VAT','ACCRUED_LIABILITY')then 'LIABILITY'
 when k in('REVENUE','DISPOSAL_GAIN')then 'REVENUE'
 when k in('DEPRECIATION_EXPENSE','DISPOSAL_LOSS','ACCRUAL_EXPENSE')then 'EXPENSE'end;
$$;
create function private.recognition_plan(cid uuid,kind text,v jsonb)returns jsonb language plpgsql volatile set search_path='' as $$
#variable_conflict use_variable
declare n bigint:=(v->>'amount_minor')::bigint;d date:=(v->>'date')::date;project uuid:=nullif(v->>'project_id','')::uuid;t uuid:=nullif(v->>'treasury_id','')::uuid;
 parent public.commercial_documents;lines jsonb;bank uuid;used bigint;due date;months integer;residual bigint;cost bigint;sequence integer;expected bigint;proceeds bigint;
begin
 if kind not in('ASSET_CAPITALIZE','ASSET_DEPRECIATE','ASSET_DISPOSE','ACCRUAL_RECOGNIZE','ACCRUAL_SETTLE','PREPAY_RECOGNIZE','PREPAY_AMORTIZE')then raise exception 'Unsupported recognition event'using errcode='22023';end if;
 if exists(select 1 from jsonb_object_keys(v)x where x<>all(array['date','project_id','treasury_id','parent_id','reference','amount_minor','evidence','life_months','residual_minor','service_date','convention','proceeds_minor']))or n is null or n<=0 or n>9000000000000000 or d is null or d>current_date or coalesce(length(btrim(v->>'reference')),0)not between 1 and 120 or coalesce(length(btrim(v->>'evidence')),0)not between 5 and 1000 then raise exception 'Valid amount, date, reference and evidence required'using errcode='23514';end if;
 if kind in('ASSET_CAPITALIZE','PREPAY_RECOGNIZE','ACCRUAL_RECOGNIZE')and v?'parent_id'or kind not in('ASSET_CAPITALIZE','PREPAY_RECOGNIZE')and(v?'life_months'or v?'service_date'or v?'residual_minor'or v?'convention')or kind<>'ASSET_DISPOSE'and v?'proceeds_minor'or kind not in('ASSET_CAPITALIZE','ASSET_DISPOSE','PREPAY_RECOGNIZE','ACCRUAL_SETTLE')and v?'treasury_id'then raise exception 'Fields do not belong to this recognition event'using errcode='22023';end if;
 if project is not null and not exists(select 1 from public.projects where company_id=cid and id=project)then raise exception 'Company Project required'using errcode='23514';end if;perform private.opening_period(cid,d);
 if kind in('ASSET_CAPITALIZE','PREPAY_RECOGNIZE')then
 months:=(v->>'life_months')::integer;residual:=coalesce((v->>'residual_minor')::bigint,0);
 if months is null or months not between 1 and 1200 or residual<0 or residual>=n or (v->>'service_date')::date is null or (v->>'service_date')::date<d or v->>'convention'is distinct from 'COMPLETED_MONTHS'or(kind='PREPAY_RECOGNIZE'and residual<>0)then raise exception 'Explicit useful life, residual and completed-month service convention required'using errcode='23514';end if;
 bank:=private.commercial_bank(cid,t,d,n,true);
 lines:=jsonb_build_array(private.commercial_line(private.commercial_account(cid,case when kind='ASSET_CAPITALIZE'then 'ASSET_COST'else 'PREPAYMENT'end),n,false,null,project),private.commercial_line(bank,n,true,null,null,t));
 elsif kind='ACCRUAL_RECOGNIZE'then
 lines:=jsonb_build_array(private.commercial_line(private.commercial_account(cid,'ACCRUAL_EXPENSE'),n,false,null,project),private.commercial_line(private.commercial_account(cid,'ACCRUED_LIABILITY'),n,true,null,project));
 else
 select *into parent from public.commercial_documents where company_id=cid and id=(v->>'parent_id')::uuid for update;
 if parent.id is null or parent.date>d or parent.project_id is distinct from project or exists(select 1 from public.commercial_documents where company_id=cid and parent_id=parent.id and commercial_documents.kind='ASSET_DISPOSE')then raise exception 'Available same-Project original document required'using errcode='23514';end if;
 select coalesce(sum(amount_minor),0)::bigint,count(*)::integer into used,sequence from public.commercial_documents where company_id=cid and parent_id=parent.id;
 if kind='ACCRUAL_SETTLE'then
 if parent.kind<>'ACCRUAL_RECOGNIZE'or n>parent.amount_minor-used then raise exception 'Settlement exceeds accrued liability'using errcode='23514';end if;
 bank:=private.commercial_bank(cid,t,d,n,true);lines:=jsonb_build_array(private.commercial_line(private.commercial_account(cid,'ACCRUED_LIABILITY'),n,false,null,project),private.commercial_line(bank,n,true,null,null,t));
 elsif kind in('ASSET_DEPRECIATE','PREPAY_AMORTIZE')then
 if parent.kind<>(case when kind='ASSET_DEPRECIATE'then 'ASSET_CAPITALIZE'else 'PREPAY_RECOGNIZE'end)then raise exception 'Incompatible recognition schedule'using errcode='23514';end if;
 months:=(parent.input->>'life_months')::integer;residual:=coalesce((parent.input->>'residual_minor')::bigint,0);cost:=parent.amount_minor-residual;
 due:=(date_trunc('month',(parent.input->>'service_date')::date)+(sequence+1)*interval '1 month'-interval '1 day')::date;
 expected:=case when sequence=months-1 then cost-used else cost/months end;
 if sequence>=months or d<>due or n<>expected then raise exception 'Post only the next completed month and exact scheduled amount %, due %',expected,due using errcode='23514';end if;
 lines:=jsonb_build_array(private.commercial_line(private.commercial_account(cid,case when kind='ASSET_DEPRECIATE'then 'DEPRECIATION_EXPENSE'else 'ACCRUAL_EXPENSE'end),n,false,null,project),private.commercial_line(private.commercial_account(cid,case when kind='ASSET_DEPRECIATE'then 'ACCUMULATED_DEPRECIATION'else 'PREPAYMENT'end),n,true,null,project));
 else
 if parent.kind<>'ASSET_CAPITALIZE'or n<>parent.amount_minor then raise exception 'Original asset cost required'using errcode='23514';end if;
 -- Complete every prior calendar month before disposal; no invented pro-rata amount.
 due:=(date_trunc('month',(parent.input->>'service_date')::date)+(sequence+1)*interval '1 month'-interval '1 day')::date;
 if sequence<(parent.input->>'life_months')::integer and due<date_trunc('month',d)::date then raise exception 'Complete prior-month depreciation before disposal'using errcode='23514';end if;
 proceeds:=(v->>'proceeds_minor')::bigint;if proceeds is null or proceeds<0 or proceeds>9000000000000000 then raise exception 'Explicit actual disposal proceeds required'using errcode='23514';end if;
 lines:=jsonb_build_array(private.commercial_line(private.commercial_account(cid,'ASSET_COST'),parent.amount_minor,true,null,project));
 if used>0 then lines:=lines||jsonb_build_array(private.commercial_line(private.commercial_account(cid,'ACCUMULATED_DEPRECIATION'),used,false,null,project));end if;
 if proceeds>0 then bank:=private.commercial_bank(cid,t,d,proceeds,false);lines:=lines||jsonb_build_array(private.commercial_line(bank,proceeds,false,null,null,t));end if;
 if proceeds>parent.amount_minor-used then lines:=lines||jsonb_build_array(private.commercial_line(private.commercial_account(cid,'DISPOSAL_GAIN'),proceeds-parent.amount_minor+used,true,null,project));
 elsif proceeds<parent.amount_minor-used then lines:=lines||jsonb_build_array(private.commercial_line(private.commercial_account(cid,'DISPOSAL_LOSS'),parent.amount_minor-used-proceeds,false,null,project));end if;
 end if;end if;
 return jsonb_build_object('lines',lines,'amount',n);
end;$$;
create function public.command_period_recognition(cid uuid,request_id uuid,kind text,input jsonb)returns jsonb language plpgsql volatile security definer set search_path='' as $$
#variable_conflict use_variable
declare actor uuid;req private.financial_command_requests;h text;prior public.commercial_documents;plan jsonb;doc uuid:=gen_random_uuid();j uuid;begin
 actor:=private.operational_finance_actor(cid,'accounting.post');if request_id is null or jsonb_typeof(input)is distinct from 'object'or octet_length(input::text)>16000 then raise exception 'Invalid recognition command'using errcode='22023';end if;
 input:=private.normalize_commercial_input(input);
 perform private.serialize_operational_finance(cid,'OPERATIONS');h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'kind',kind,'input',input)::text,'UTF8'),'sha256'),'hex');
 select *into prior from public.commercial_documents where company_id=cid and commercial_documents.request_id=command_period_recognition.request_id;
 if prior.id is not null then if prior.request_hash<>h then raise exception 'Changed recognition request'using errcode='23505';end if;return jsonb_build_object('id',prior.id,'journal_id',prior.journal_id);end if;
 req:=private.reserve_financial_command(cid,'COMMERCIAL_'||kind,request_id,h,actor);
 plan:=private.recognition_plan(cid,kind,input);j:=private.create_journal(cid,(input->>'date')::date,btrim(input->>'reference')||' '||btrim(input->>'evidence'),kind,doc,'ORIGINAL',plan->'lines',actor);
 insert into public.commercial_documents(id,company_id,kind,date,project_id,treasury_id,parent_id,reference,amount_minor,journal_id,input,request_id,request_hash,created_by)values(doc,cid,kind,(input->>'date')::date,nullif(input->>'project_id','')::uuid,nullif(input->>'treasury_id','')::uuid,nullif(input->>'parent_id','')::uuid,btrim(input->>'reference'),(plan->>'amount')::bigint,j,input,request_id,h,actor);
 perform private.complete_financial_command(req.id,j);return jsonb_build_object('id',doc,'journal_id',j);end;$$;
create function public.read_period_recognition(cid uuid,as_of date)returns jsonb language plpgsql stable security invoker set search_path='' as $$
begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'MANAGEMENT_VIEWER'))then raise exception 'Recognition access denied'using errcode='42501';end if;
 if as_of is null then raise exception 'As-of date required'using errcode='22023';end if;
 return jsonb_build_object('documents',coalesce((select jsonb_agg(to_jsonb(x)||jsonb_build_object('amount_minor',x.amount_minor::text,'remaining_minor',(case when x.kind='ASSET_CAPITALIZE'and exists(select 1 from public.commercial_documents z where z.company_id=cid and z.parent_id=x.id and z.kind='ASSET_DISPOSE'and z.date<=as_of)then 0 else x.amount_minor-coalesce((select sum(s.amount_minor)from public.commercial_documents s where s.company_id=cid and s.parent_id=x.id and s.date<=as_of),0)end)::text)order by x.date,x.id)from public.commercial_documents x where x.company_id=cid and x.kind not like 'AR_%'and x.date<=as_of),'[]'::jsonb));
end;$$;
revoke all on function private.recognition_plan(uuid,text,jsonb),public.command_period_recognition(uuid,uuid,text,jsonb),public.read_period_recognition(uuid,date)from public,anon,authenticated,service_role;
grant execute on function public.command_period_recognition(uuid,uuid,text,jsonb),public.read_period_recognition(uuid,date)to authenticated;
