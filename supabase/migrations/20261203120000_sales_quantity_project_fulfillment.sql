-- 115: Quantity-based consolidated billing and Project goods sales. No financial backfill.
create table public.sales_invoice_allocations(
 company_id uuid not null,invoice_id uuid not null,stock_event_id uuid not null,
 quantity_micros bigint not null check(quantity_micros>0),base_quantity_micros bigint not null check(base_quantity_micros>0),
 net_minor bigint not null check(net_minor>0),vat_minor bigint not null check(vat_minor>=0),unit text not null check(length(unit)between 1 and 50),
 primary key(company_id,invoice_id,stock_event_id),
 foreign key(company_id,invoice_id)references public.commercial_documents(company_id,id)on delete restrict,
 foreign key(company_id,stock_event_id)references public.sales_delivery_lines(company_id,stock_event_id)on delete restrict);
create table public.sales_return_allocations(
 company_id uuid not null,return_event_id uuid not null,invoice_id uuid not null,stock_event_id uuid not null,credit_id uuid not null,
 quantity_micros bigint not null check(quantity_micros>0),base_quantity_micros bigint not null check(base_quantity_micros>0),
 net_minor bigint not null check(net_minor>0),vat_minor bigint not null check(vat_minor>=0),
 primary key(company_id,return_event_id),unique(company_id,credit_id),
 foreign key(company_id,invoice_id,stock_event_id)references public.sales_invoice_allocations(company_id,invoice_id,stock_event_id)on delete restrict,
 foreign key(company_id,return_event_id)references public.inventory_events(company_id,id)on delete restrict,
 foreign key(company_id,credit_id)references public.commercial_documents(company_id,id)on delete restrict);
create table private.sales_billing_context(tx bigint not null,company_id uuid not null,kind text not null,input jsonb not null,primary key(tx,company_id));
alter table private.sales_billing_context enable row level security;
alter table private.sales_billing_context force row level security;
revoke all on private.sales_billing_context from public,anon,authenticated,service_role;
do $$declare t text;begin foreach t in array array['sales_invoice_allocations','sales_return_allocations']loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);execute format('grant select on public.%I to authenticated',t);
 execute format('create policy sales_allocation_read on public.%I for select to authenticated using(auth.uid()is not null and(public.has_company_role(company_id,''ACCOUNTING_ADMIN'')or public.has_company_role(company_id,''ACCOUNTANT'')or public.has_company_role(company_id,''MANAGEMENT_VIEWER'')))',t);
 execute format('create trigger sales_allocation_immutable before update or delete on public.%I for each row execute function private.financial_evidence_immutable()',t);
 end loop;end$$;

create function private.sales_billed(cid uuid,stock uuid)returns jsonb language sql stable set search_path=''as $$
 select jsonb_build_object('quantity',coalesce(sum(a.base_quantity_micros),0)::text,'base',coalesce(sum(a.base_quantity_micros),0)::text,'net',coalesce(sum(a.net_minor),0)::text)
 from public.sales_invoice_allocations a where a.company_id=cid and a.stock_event_id=stock and private.commercial_live(cid,a.invoice_id);
$$;
create function private.sales_unbilled_base(cid uuid,stock uuid)returns bigint language sql stable set search_path=''as $$
 select greatest(0,(s.snapshot->'computed'->>'qty')::bigint
 -coalesce((select sum((r.snapshot->'computed'->>'qty')::numeric)from public.inventory_events r where r.company_id=cid and r.state='POSTED'and r.snapshot->>'kind'='RETURN'and r.snapshot->>'origin_id'=s.document_id::text and(private.inventory_current(cid,r.document_id)).id=r.id),0)
 -case when exists(select 1 from public.commercial_documents c where c.company_id=cid and c.stock_event_id=stock and private.commercial_live(cid,c.id))then(s.snapshot->'computed'->>'qty')::bigint else(private.sales_billed(cid,stock)->>'base')::bigint end
 +coalesce((select sum(a.base_quantity_micros)from public.sales_return_allocations a where a.company_id=cid and a.stock_event_id=stock and private.commercial_live(cid,a.credit_id)),0)
 +coalesce((select sum((r.snapshot->'computed'->>'qty')::numeric)from public.commercial_documents c join public.inventory_events r on r.company_id=c.company_id and r.id=c.return_event_id join public.commercial_documents p on p.company_id=c.company_id and p.id=c.parent_id where c.company_id=cid and p.stock_event_id=stock and private.commercial_live(cid,c.id)),0))::bigint
 from public.inventory_events s where s.company_id=cid and s.id=stock;
$$;
create function private.sales_context_valid(cid uuid,k text,v jsonb)returns void language plpgsql set search_path=''as $$begin
 if not exists(select 1 from private.sales_billing_context where tx=txid_current()and company_id=cid and kind=k and input=private.normalize_commercial_input(v))then raise exception 'SALES_CANONICAL_CONTEXT'using errcode='42501';end if;
end$$;
-- Extend the existing AR planner's evidence branch, not its journal/accounting arithmetic.
do $$declare d text;a text;b text;begin
 d:=pg_get_functiondef('private.customer_plan_legacy104(uuid,text,jsonb)'::regprocedure);
 a:='v->>''economic_kind''not in(''EARNED_SERVICE'',''DELIVERED_GOODS'')';if strpos(d,a)=0 then raise exception 'Canonical goods invoice dependency changed';end if;
 d:=replace(d,a,'v->>''economic_kind''not in(''EARNED_SERVICE'',''DELIVERED_GOODS'',''FULFILLED_GOODS'')');
 a:='else if v?''stock_event_id''then';b:='elsif v->>''economic_kind''=''FULFILLED_GOODS''then perform private.sales_context_valid(cid,kind,v); else if v?''stock_event_id''then';
 if strpos(d,a)=0 then raise exception 'Canonical stock validation dependency changed';end if;d:=replace(d,a,b);
 a:='if parent.input->>''economic_kind''=''DELIVERED_GOODS''then';b:='if parent.input->>''economic_kind''=''FULFILLED_GOODS''then perform private.sales_context_valid(cid,kind,v); elsif parent.input->>''economic_kind''=''DELIVERED_GOODS''then';
 if strpos(d,a)=0 then raise exception 'Canonical credit dependency changed';end if;execute replace(d,a,b);
end$$;
-- Project is an analytic dimension. SALE uses COGS; internal CONSUMPTION still uses Project Cost.
do $$declare d text;a text;begin
 d:=pg_get_functiondef('private.inventory_plan(uuid,jsonb)'::regprocedure);
 a:='if project is not null or l.project_id is not null or not exists(select 1 from public.customer_accounts';
 if strpos(d,a)=0 then raise exception 'Canonical sales warehouse dependency changed';end if;
 d:=replace(d,a,'if (l.project_id is not null and l.project_id is distinct from project)or(project is not null and exists(select 1 from public.construction_contracts where company_id=cid and project_id=project))or not exists(select 1 from public.customer_accounts');execute d;
 -- Same explicit Project must follow a legacy single-issue goods invoice too.
 d:=pg_get_functiondef('private.customer_plan_legacy104(uuid,text,jsonb)'::regprocedure);
 a:='or project is not null or (private.inventory_current(cid,stock.document_id)).id<>stock.id';
 if strpos(d,a)=0 then raise exception 'Canonical goods Project dependency changed';end if;
 execute replace(d,a,'or project is distinct from nullif(stock.snapshot->''computed''->>''project'','''')::uuid or (private.inventory_current(cid,stock.document_id)).id<>stock.id');
end$$;

create function private.sales_invoice_plan(cid uuid,v jsonb)returns jsonb language plpgsql set search_path=''as $$
#variable_conflict use_variable
declare x jsonb;dl public.sales_delivery_lines;s public.inventory_events;o public.sales_events;l jsonb;b jsonb;rows jsonb:='[]';q bigint;base bigint;n bigint;tax bigint;total bigint:=0;vat bigint:=0;rate integer;this_rate integer;customer uuid;project uuid;first boolean:=true;d date;latest date;used bigint;returned bigint;original jsonb;begin
 if jsonb_typeof(v)is distinct from 'object'or v-array['lines','date','due_date','evidence','currency']<>'{}'or jsonb_typeof(v->'lines')is distinct from 'array'or jsonb_array_length(v->'lines')not between 1 and 50 or coalesce(length(btrim(v->>'evidence')),0)not between 5 and 1000 or coalesce(v->>'currency','AED')<>'AED' then raise exception 'SALES_BILLING_INPUT'using errcode='22023';end if;
 if coalesce(v->>'date','')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'or coalesce(v->>'due_date','')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'or(v->>'date')::date>current_date or(v->>'due_date')::date<(v->>'date')::date then raise exception 'SALES_DATE'using errcode='23514';end if;d:=(v->>'date')::date;perform private.opening_period(cid,d);
 if(select count(*)from jsonb_array_elements(v->'lines'))<>(select count(distinct a.value->>'stock_event_id')from jsonb_array_elements(v->'lines')a(value))then raise exception 'SALES_BILLING_DUPLICATE'using errcode='23505';end if;
 for x in select value from jsonb_array_elements(v->'lines')loop
 if x-array['stock_event_id','quantity_micros','expected_billed_micros','expected_returned_base_micros','unit']<>'{}'or coalesce(x->>'quantity_micros','')!~'^[0-9]{1,16}$'then raise exception 'SALES_BILLING_INPUT'using errcode='22023';end if;
 select *into dl from public.sales_delivery_lines where company_id=cid and stock_event_id=(x->>'stock_event_id')::uuid;
 select *into s from public.inventory_events where company_id=cid and id=dl.stock_event_id;
 select *into o from public.sales_events where company_id=cid and id=dl.order_id;
 if dl.stock_event_id is null or(private.inventory_current(cid,s.document_id)).id is distinct from s.id then raise exception 'SALES_DELIVERY_REQUIRED'using errcode='23514';end if;
 l:=o.snapshot->'lines'->(dl.order_line-1);q:=(x->>'quantity_micros')::bigint;base:=private.uom_quantity(cid,(l->>'material_id')::uuid,coalesce(x->>'unit',l->>'unit'),q::text);b:=private.sales_billed(cid,s.id);
 returned:=coalesce((select sum((r.snapshot->'computed'->>'qty')::numeric)from public.inventory_events r where r.company_id=cid and r.state='POSTED'and r.snapshot->>'kind'='RETURN'and r.snapshot->>'origin_id'=s.document_id::text and(private.inventory_current(cid,r.document_id)).id=r.id),0);
 if (x?'expected_billed_micros'and x->>'expected_billed_micros'<>b->>'quantity')or(x?'expected_returned_base_micros'and x->>'expected_returned_base_micros'<>returned::text)then raise exception 'SALES_STALE'using errcode='40001';end if;
 if q<=0 or base<=0 or base>private.sales_unbilled_base(cid,s.id)then raise exception 'SALES_BILLING_QUANTITY'using errcode='23514';end if;
 this_rate:=(l->>'vat_rate_bps')::integer;
 if first then customer:=(o.snapshot->>'customer_id')::uuid;project:=nullif(o.snapshot->>'project_id','')::uuid;rate:=this_rate;first:=false;
 elsif customer is distinct from(o.snapshot->>'customer_id')::uuid or project is distinct from nullif(o.snapshot->>'project_id','')::uuid or rate<>this_rate then raise exception 'SALES_BILLING_COMPATIBILITY'using errcode='23514';end if;
 -- Keep the established goods-recognition date; one GL journal cannot represent different recognition dates.
 if(s.snapshot->>'date')::date<>d or date_trunc('month',(s.snapshot->>'date')::date)<>date_trunc('month',d)or exists(select 1 from public.accounting_fiscal_periods p where p.company_id=cid and(s.snapshot->>'date')::date between p.from_date and p.through_date and d not between p.from_date and p.through_date)then raise exception 'SALES_RECOGNITION_PERIOD'using errcode='23514';end if;
 perform private.opening_period(cid,(s.snapshot->>'date')::date);
 if project is distinct from nullif(s.snapshot->'computed'->>'project','')::uuid then raise exception 'SALES_PROJECT'using errcode='23514';end if;
 used:=(b->>'base')::bigint;n:=round(dl.net_minor::numeric*(used+base)/dl.base_quantity_micros)::bigint-(b->>'net')::bigint;
 if n<=0 or total::numeric+n>9000000000000000 then raise exception 'SALES_AMOUNT'using errcode='23514';end if;
 total:=total+n;tax:=round(total::numeric*rate/10000)::bigint-vat;vat:=vat+tax;
 rows:=rows||jsonb_build_array(jsonb_build_object('stock_event_id',s.id,'quantity_micros',q::text,'base_quantity_micros',base::text,'net_minor',n::text,'vat_minor',tax::text,'description',l->>'description','unit',coalesce(x->>'unit',l->>'unit'),'stock_reference',s.reference));end loop;
 if total::numeric+vat>9000000000000000 then raise exception 'SALES_AMOUNT'using errcode='23514';end if;
 original:=private.normalize_commercial_input(jsonb_build_object('date',d,'due_date',v->>'due_date','party_id',customer,'project_id',project,'economic_kind','FULFILLED_GOODS','amount_minor',total::text,'vat_minor',vat::text,'vat_rate_bps',rate,'tax_evidence',v->>'evidence','recognition_confirmed',true,'reference','PREVIEW','evidence',v->>'evidence'));
 return jsonb_build_object('lines',rows,'net_minor',total::text,'vat_minor',vat::text,'gross_minor',(total+vat)::text,'customer_id',customer,'project_id',project,'date',d,'currency','AED','input',original);
end$$;
create function public.preview_sales_invoice(cid uuid,input jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$begin
 perform private.operational_finance_actor(cid,'accounting.post');perform private.serialize_operational_finance(cid,'OPERATIONS');
 if not coalesce((private.company_commercial_readiness(cid)->>'ready')::boolean,false)then raise exception 'SALES_SETUP'using errcode='42501';end if;
 return private.sales_invoice_plan(cid,input)-'input';end$$;

-- Keep previous quotation/order/delivery and old invoice evidence intact; no backfill/rewritten documents.
do $$declare d text;begin
 d:=pg_get_functiondef('public.command_sales(uuid,uuid,text,jsonb)'::regprocedure);
 d:=replace(d,'public.command_sales(','private.sales_command_pre115(');d:=replace(d,'command_sales.request_id','sales_command_pre115.request_id');
 d:=replace(d,'if nullif(o.snapshot->>''project_id'','''')is not null then raise exception ''SALES_PROJECT_STOCK_POLICY''using errcode=''23514'';end if;', 'if exists(select 1 from public.construction_contracts where company_id=cid and project_id=nullif(o.snapshot->>''project_id'','''')::uuid)then raise exception ''SALES_CONSTRUCTION_POLICY''using errcode=''23514'';end if;');
 d:=replace(d,'and active and project_id is null;','and active and(project_id is null or project_id=nullif(o.snapshot->>''project_id'','''')::uuid);');
 d:=replace(d,'''cost_purpose'',''SALE'',''source_reference''','''project_id'',o.snapshot->>''project_id'',''cost_purpose'',''SALE'',''source_reference''');execute d;
end$$;
create or replace function public.command_sales(cid uuid,request_id uuid,action text,input jsonb)returns jsonb language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_variable
declare actor uuid;h text;prior public.sales_requests;plan jsonb;doc jsonb;v jsonb;x jsonb;r jsonb;b jsonb;dl public.sales_delivery_lines;stock public.inventory_events;o public.sales_events;a public.sales_invoice_allocations;p public.commercial_documents;
 q bigint;base bigint;used bigint;used_net bigint;net bigint;tax bigint;prior_tax bigint;project uuid;result jsonb;d date;chosen uuid;begin
 if action is distinct from 'INVOICE'and action is distinct from 'RETURN'and action is distinct from 'RETURN_UNBILLED'then return private.sales_command_pre115(cid,request_id,action,input);end if;
 actor:=private.operational_finance_actor(cid,'accounting.post');if request_id is null or jsonb_typeof(input)is distinct from 'object'or octet_length(input::text)>60000 then raise exception 'SALES_INPUT'using errcode='22023';end if;
 perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 -- Legacy114 returns retain their original canonical request hash and recovery semantics.
 if action='RETURN'then
 select *into dl from public.sales_delivery_lines where company_id=cid and stock_event_id=(input->>'id')::uuid;
 if dl.stock_event_id is not null and not exists(select 1 from public.sales_invoice_allocations where company_id=cid and stock_event_id=dl.stock_event_id)then
 select *into o from public.sales_events where company_id=cid and id=dl.order_id;
 if(input?'unit'and input->>'unit'<>o.snapshot->'lines'->(dl.order_line-1)->>'unit')or(input?'invoice_id'and not exists(select 1 from public.commercial_documents c where c.company_id=cid and c.id=(input->>'invoice_id')::uuid and c.stock_event_id=dl.stock_event_id))then raise exception 'SALES_BILLING_INPUT'using errcode='22023';end if;
 return private.sales_command_pre115(cid,request_id,action,input-array['invoice_id','unit']);end if;end if;
 h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'action',action,'input',input)::text,'UTF8'),'sha256'),'hex');
 select *into prior from public.sales_requests where company_id=cid and sales_requests.request_id=command_sales.request_id;
 if prior.request_id is not null then if prior.request_hash<>h then raise exception 'SALES_REQUEST_CHANGED'using errcode='23505';end if;return prior.result;end if;
 if action='INVOICE'then
 if not coalesce((private.company_commercial_readiness(cid)->>'ready')::boolean,false)then raise exception 'SALES_SETUP'using errcode='42501';end if;
 v:=input;
 -- Compatible old UI requests bill their remaining delivered quantities, never duplicate prior invoices.
 if v?'stock_events'then
 if v-array['stock_events','due_date','evidence']<>'{}'or jsonb_typeof(v->'stock_events')is distinct from 'array'then raise exception 'SALES_BILLING_INPUT'using errcode='22023';end if;
 v:=jsonb_build_object('due_date',input->>'due_date','evidence',input->>'evidence','lines','[]'::jsonb);
 for x in select value from jsonb_array_elements(input->'stock_events')loop
 select *into dl from public.sales_delivery_lines where company_id=cid and stock_event_id=(x#>>'{}')::uuid;select *into stock from public.inventory_events where company_id=cid and id=dl.stock_event_id;
 if dl.stock_event_id is null then raise exception 'SALES_DELIVERY_REQUIRED'using errcode='23514';end if;
 q:=(private.sales_unbilled_base(cid,stock.id)::numeric*dl.quantity_micros/dl.base_quantity_micros)::bigint;
 if q::numeric*dl.base_quantity_micros<>private.sales_unbilled_base(cid,stock.id)::numeric*dl.quantity_micros then raise exception 'SALES_BILLING_QUANTITY'using errcode='23514';end if;
 v:=v||jsonb_build_object('date',stock.snapshot->>'date','lines',(v->'lines')||jsonb_build_array(jsonb_build_object('stock_event_id',stock.id,'quantity_micros',q::text)));end loop;
 end if;
 plan:=private.sales_invoice_plan(cid,v);doc:=plan->'input';doc:=doc||jsonb_build_object('reference',private.allocate_reference(cid,'SINV',extract(year from(v->>'date')::date)::integer));
 insert into private.sales_billing_context values(txid_current(),cid,'AR_INVOICE',private.normalize_commercial_input(doc));
 r:=public.command_customer_accounting(cid,gen_random_uuid(),'AR_INVOICE',doc);
 for x in select value from jsonb_array_elements(plan->'lines')loop insert into public.sales_invoice_allocations values(cid,(r->>'id')::uuid,(x->>'stock_event_id')::uuid,(x->>'quantity_micros')::bigint,(x->>'base_quantity_micros')::bigint,(x->>'net_minor')::bigint,(x->>'vat_minor')::bigint,x->>'unit');end loop;
 result:=r||jsonb_build_object('invoices',jsonb_build_array(r),'line_count',jsonb_array_length(plan->'lines'),'gross_minor',plan->>'gross_minor');
 else
 if input-array['id','invoice_id','date','quantity_micros','evidence','unit']<>'{}'or coalesce(input->>'quantity_micros','')!~'^[0-9]{1,16}$'or coalesce(length(btrim(input->>'evidence')),0)not between 5 and 1000 or coalesce(input->>'date','')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'then raise exception 'SALES_BILLING_INPUT'using errcode='22023';end if;
 select *into dl from public.sales_delivery_lines where company_id=cid and stock_event_id=(input->>'id')::uuid;
 select *into stock from public.inventory_events where company_id=cid and id=dl.stock_event_id;
 select *into o from public.sales_events where company_id=cid and id=dl.order_id;
 if dl.stock_event_id is null then raise exception 'SALES_DELIVERY_REQUIRED'using errcode='23514';end if;

 q:=(input->>'quantity_micros')::bigint;project:=nullif(o.snapshot->>'project_id','')::uuid;x:=o.snapshot->'lines'->(dl.order_line-1);base:=private.uom_quantity(cid,(x->>'material_id')::uuid,coalesce(input->>'unit',x->>'unit'),q::text);
 if q<=0 or base<=0 then raise exception 'SALES_BILLING_QUANTITY'using errcode='23514';end if;
 if action='RETURN_UNBILLED'then
 if base>private.sales_unbilled_base(cid,stock.id)then raise exception 'SALES_BILLING_QUANTITY'using errcode='23514';end if;
 else
 chosen:=nullif(input->>'invoice_id','')::uuid;
 if chosen is null then
 if(select count(*)from public.sales_invoice_allocations z where z.company_id=cid and z.stock_event_id=stock.id and private.commercial_live(cid,z.invoice_id))<>1 then raise exception 'SALES_RETURN_SELECT_INVOICE'using errcode='23514';end if;
 select invoice_id into chosen from public.sales_invoice_allocations z where z.company_id=cid and z.stock_event_id=stock.id and private.commercial_live(cid,z.invoice_id);end if;
 select *into a from public.sales_invoice_allocations where company_id=cid and stock_event_id=stock.id and invoice_id=chosen;
 select *into p from public.commercial_documents where company_id=cid and id=chosen;
 select coalesce(sum(z.base_quantity_micros),0),coalesce(sum(z.net_minor),0)into used,used_net from public.sales_return_allocations z where z.company_id=cid and z.invoice_id=chosen and z.stock_event_id=stock.id and private.commercial_live(cid,z.credit_id);
 if a.invoice_id is null or not private.commercial_live(cid,p.id)or base>a.base_quantity_micros-used then raise exception 'SALES_BILLING_QUANTITY'using errcode='23514';end if;
 net:=round(a.net_minor::numeric*(used+base)/a.base_quantity_micros)::bigint-used_net;
 select coalesce(sum((c.input->>'amount_minor')::bigint),0),coalesce(sum((c.input->>'vat_minor')::bigint),0)into used_net,prior_tax from public.commercial_documents c where c.company_id=cid and c.parent_id=p.id and c.kind='AR_CREDIT'and private.commercial_live(cid,c.id);
 tax:=case when used_net+net=(p.input->>'amount_minor')::bigint then(p.input->>'vat_minor')::bigint-prior_tax else round(net::numeric*(p.input->>'vat_rate_bps')::integer/10000)::bigint end;
 end if;
 insert into private.sales_billing_context values(txid_current(),cid,'RETURN_STOCK',jsonb_build_object('stock',stock.id,'base',base::text));
 v:=jsonb_build_object('id',gen_random_uuid(),'version',0,'kind','RETURN','date',input->>'date','material_id',x->>'material_id','location_id',stock.snapshot->>'location_id','qty_micros',q::text,'unit',coalesce(input->>'unit',x->>'unit'),'origin_id',stock.document_id,'source_reference',private.allocate_reference(cid,'SRET',extract(year from(input->>'date')::date)::integer),'evidence',input->>'evidence');
 r:=public.command_inventory(cid,gen_random_uuid(),'SAVE',v);r:=public.command_inventory(cid,gen_random_uuid(),'REVIEW',jsonb_build_object('id',r->>'document_id','version',r->>'version','evidence',input->>'evidence'));r:=public.command_inventory(cid,gen_random_uuid(),'POST',jsonb_build_object('id',r->>'document_id','version',r->>'version','evidence',input->>'evidence'));
 if action='RETURN'then
 doc:=private.normalize_commercial_input(jsonb_build_object('date',input->>'date','party_id',p.party_id,'project_id',p.project_id,'parent_id',p.id,'amount_minor',net::text,'vat_minor',tax::text,'credit_reason','GOODS_RETURN','return_event_id',r->>'id','reference',private.allocate_reference(cid,'SCREDIT',extract(year from(input->>'date')::date)::integer),'evidence',input->>'evidence'));
 update private.sales_billing_context set kind='AR_CREDIT',input=doc where tx=txid_current()and company_id=cid;
 result:=public.command_customer_accounting(cid,gen_random_uuid(),'AR_CREDIT',doc);
 insert into public.sales_return_allocations values(cid,(r->>'id')::uuid,p.id,stock.id,(result->>'id')::uuid,q,base,net,tax);
 result:=result||jsonb_build_object('return_event_id',r->>'id');else result:=jsonb_build_object('id',r->>'id','return_event_id',r->>'id','journal_id',r->>'journal_id','state','POSTED');end if;
 end if;
 delete from private.sales_billing_context where tx=txid_current()and company_id=cid;
 insert into public.sales_requests values(cid,request_id,h,result,actor,now());return result;
end$$;

-- Prevent the old whole-issue entry point from double-billing an allocated delivery.
create or replace function private.sales_invoice_guard()returns trigger language plpgsql set search_path=''as $$declare d public.sales_delivery_lines;begin
 if new.stock_event_id is not null then
 select *into d from public.sales_delivery_lines where company_id=new.company_id and stock_event_id=new.stock_event_id;
 if d.stock_event_id is not null and(new.kind<>'AR_INVOICE'or(new.input->>'amount_minor')::bigint<>d.net_minor or coalesce((new.input->>'vat_minor')::bigint,0)<>d.vat_minor or private.sales_unbilled_base(new.company_id,new.stock_event_id)<>d.base_quantity_micros)then raise exception 'SALES_AGREED_PRICE'using errcode='23514';end if;
 end if;return new;end$$;
create function private.sales_return_guard()returns trigger language plpgsql set search_path=''as $$declare stock uuid;begin
 if new.state='POSTED'and new.snapshot->>'kind'='RETURN'then
 select e.id into stock from public.inventory_events e where e.company_id=new.company_id and e.document_id=(new.snapshot->>'origin_id')::uuid and e.state='POSTED'and e.snapshot->>'kind'='ISSUE';
 if exists(select 1 from public.sales_invoice_allocations a where a.company_id=new.company_id and a.stock_event_id=stock and private.commercial_live(new.company_id,a.invoice_id))and not exists(select 1 from private.sales_billing_context c where c.tx=txid_current()and c.company_id=new.company_id and c.kind='RETURN_STOCK'and c.input->>'stock'=stock::text and c.input->>'base'=new.snapshot->'computed'->>'qty')then raise exception 'SALES_RETURN_ALLOCATION_REQUIRED'using errcode='23514';end if;
 end if;return new;end$$;
create trigger sales_return_allocation_guard before insert on public.inventory_events for each row execute function private.sales_return_guard();
-- Billed quantity is released only by the existing audited reversal engine, after dependent settlements/credits.
do $$declare d text;begin
 d:=pg_get_functiondef('public.preview_commercial_reversal(uuid,uuid,date,text)'::regprocedure);
 d:=replace(d,'p.kind not in(', '(p.kind<>''AR_INVOICE''or p.input->>''economic_kind''is distinct from ''FULFILLED_GOODS'')and p.kind not in(');execute d;
 -- Existing unbilled-delivery year-end safeguard now understands quantity allocations.
 d:=pg_get_functiondef('public.command_annual_closing(uuid,uuid,text,jsonb)'::regprocedure);
 if strpos(d,'and not exists(select 1 from public.commercial_documents d where d.company_id=cid and d.stock_event_id=e.id)')=0 then raise exception 'Canonical annual closing dependency changed';end if;
 d:=replace(d,'and not exists(select 1 from public.commercial_documents d where d.company_id=cid and d.stock_event_id=e.id)','and private.sales_unbilled_base(cid,e.id)>0 and not exists(select 1 from public.commercial_documents d where d.company_id=cid and d.stock_event_id=e.id)');execute d;
end$$;
-- Enrich the existing read model; legacy invoice/source relationships are read as-is, not migrated.
do $$declare d text;begin d:=pg_get_functiondef('public.read_sales(uuid,integer,integer)'::regprocedure);execute replace(d,'public.read_sales(','private.sales_read_pre115(');end$$;
create or replace function public.read_sales(cid uuid,page integer default 0,page_size integer default 25)returns jsonb language plpgsql stable security definer set search_path=''as $$
declare result jsonb;rows jsonb:='[]';x jsonb;stock uuid;b jsonb;alloc jsonb;revenue bigint;legacy boolean;cost bigint;billed_cost bigint;begin
 result:=private.sales_read_pre115(cid,page,page_size);
 for x in select value from jsonb_array_elements(result->'delivery_lines')loop
 stock:=(x->>'stock_event_id')::uuid;b:=private.sales_billed(cid,stock);legacy:=x->>'invoice_id'is not null;
 select coalesce(jsonb_agg(to_jsonb(a)||jsonb_build_object('quantity_micros',a.quantity_micros::text,'base_quantity_micros',a.base_quantity_micros::text,'net_minor',a.net_minor::text,'vat_minor',a.vat_minor::text,'effective',private.commercial_live(cid,a.invoice_id),'reference',c.reference,'journal_id',c.journal_id,'date',c.date,'returned_base_micros',coalesce((select sum(r.base_quantity_micros)::text from public.sales_return_allocations r where r.company_id=cid and r.invoice_id=a.invoice_id and r.stock_event_id=stock and private.commercial_live(cid,r.credit_id)),'0'))order by c.created_at,c.id),'[]')into alloc from public.sales_invoice_allocations a join public.commercial_documents c on c.company_id=a.company_id and c.id=a.invoice_id where a.company_id=cid and a.stock_event_id=stock;
 revenue:=(x->>'recognized_net_minor')::bigint+coalesce((select sum(a.net_minor)from public.sales_invoice_allocations a where a.company_id=cid and a.stock_event_id=stock and private.commercial_live(cid,a.invoice_id)),0)-coalesce((select sum(r.net_minor)from public.sales_return_allocations r where r.company_id=cid and r.stock_event_id=stock and private.commercial_live(cid,r.credit_id)),0);
 cost:=(x->>'cost_minor')::bigint-(x->>'returned_cost_minor')::bigint;
 billed_cost:=case when legacy then cost else round((x->>'cost_minor')::numeric*((b->>'base')::bigint-coalesce((select sum(r.base_quantity_micros)from public.sales_return_allocations r where r.company_id=cid and r.stock_event_id=stock and private.commercial_live(cid,r.credit_id)),0))/(x->>'base_quantity_micros')::numeric)::bigint end;
 rows:=rows||jsonb_build_array(x||jsonb_build_object('billing_allocations',alloc,'legacy_invoice_id',x->'invoice_id','invoice_id',coalesce(nullif(x->'invoice_id','null'::jsonb),alloc->0->'invoice_id'),'invoice_reference',coalesce(nullif(x->'invoice_reference','null'::jsonb),alloc->0->'reference'),'journal_id',coalesce(nullif(x->'journal_id','null'::jsonb),alloc->0->'journal_id'),'invoice_effective',legacy or exists(select 1 from public.sales_invoice_allocations aa where aa.company_id=cid and aa.stock_event_id=stock and private.commercial_live(cid,aa.invoice_id)),'billed_base_micros',case when legacy then x->>'base_quantity_micros'else b->>'base'end,'remaining_unbilled_base_micros',private.sales_unbilled_base(cid,stock)::text,'recognized_net_minor',revenue::text,'billed_cost_minor',billed_cost::text,'net_cost_minor',cost::text,'project_id',(select nullif(e.snapshot->'computed'->>'project','')::uuid from public.inventory_events e where e.company_id=cid and e.id=stock),'base_unit',(select m.base_unit from public.inventory_events s join public.inventory_materials m on m.company_id=s.company_id and m.id=(s.snapshot->>'material_id')::uuid where s.company_id=cid and s.id=stock)));
 end loop;
 return result||jsonb_build_object('delivery_lines',rows,'projects',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'active',status='ACTIVE'))from public.projects where company_id=cid),'[]'::jsonb),'customers',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'active',p.status='ACTIVE'))from public.customer_accounts c join public.parties p on p.company_id=c.company_id and p.id=c.party_id where c.company_id=cid),'[]'::jsonb),'locations',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'project_id',project_id))from public.inventory_locations where company_id=cid and active),'[]'::jsonb));
end$$;
-- Untrusted callers never obtain generic posting or trusted billing-context capabilities.
do $$declare p record;begin for p in select oid::regprocedure sig from pg_proc where pronamespace='private'::regnamespace and(proname like'sales_%'or proname='goods_return_credit_limit')loop execute format('revoke all on function %s from public,anon,authenticated,service_role',p.sig);end loop;end$$;
revoke all on function public.preview_sales_invoice(uuid,jsonb)from public,anon,authenticated,service_role;
grant execute on function public.preview_sales_invoice(uuid,jsonb)to authenticated;
-- AR previously needed only construction reversals. Group invoices also use canonical commercial reversals.
do $$declare d text;begin
 d:=pg_get_functiondef('public.read_customer_accounts(uuid,date)'::regprocedure);
 d:=replace(d,'private.construction_live(cid,x.id,as_of)','(private.construction_live(cid,x.id,as_of)and private.commercial_live(cid,x.id,as_of))');
 d:=replace(d,'private.construction_live(cid,s.id,as_of)','(private.construction_live(cid,s.id,as_of)and private.commercial_live(cid,s.id,as_of))');execute d;
 d:=pg_get_functiondef('private.customer_plan(uuid,text,jsonb)'::regprocedure);
 d:=replace(d,' select *into ct from public.construction_contracts', ' if exists(select 1 from public.commercial_documents p where p.company_id=cid and(p.id=nullif(v->>''parent_id'','''')::uuid or p.id=nullif(v->>''related_id'','''')::uuid)and p.input->>''economic_kind''=''FULFILLED_GOODS''and not private.commercial_live(cid,p.id))then raise exception ''Reversed invoice cannot receive settlements or credits''using errcode=''23514'';end if;select *into ct from public.construction_contracts');execute d;
end$$;
create index sales_invoice_stock_quantity on public.sales_invoice_allocations(company_id,stock_event_id);
create index sales_return_invoice_quantity on public.sales_return_allocations(company_id,invoice_id,stock_event_id);
