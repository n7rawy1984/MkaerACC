-- 114: Operational sales orchestration. No seeds, financial backfills or replacement accounting engine.
-- Quotes/orders are append-only nonfinancial versions. Deliveries and invoices call existing commands atomically.
create table public.sales_events(
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id) on delete restrict,
 document_id uuid not null,version integer not null check(version>0),kind text not null check(kind in('QUOTATION','ORDER','DELIVERY')),
 state text not null check(state in('DRAFT','REVIEW','APPROVED','CONFIRMED','POSTED','CANCELLED')),
 reference text not null,snapshot jsonb not null,actor uuid not null references auth.users(id),created_at timestamptz not null default now(),
 unique(company_id,id),unique(company_id,document_id,version));
create table public.sales_requests(
 company_id uuid not null references public.companies(id)on delete restrict,request_id uuid not null,request_hash text not null,
 result jsonb not null,actor uuid not null references auth.users(id),created_at timestamptz not null default now(),primary key(company_id,request_id));
create table public.sales_delivery_lines(
 company_id uuid not null,delivery_id uuid not null,line_number integer not null,order_id uuid not null,order_line integer not null,
 quantity_micros bigint not null check(quantity_micros>0),base_quantity_micros bigint not null check(base_quantity_micros>0),
 stock_event_id uuid not null,net_minor bigint not null check(net_minor>0),vat_minor bigint not null check(vat_minor>=0),
 primary key(company_id,delivery_id,line_number),unique(company_id,stock_event_id),
 foreign key(company_id,delivery_id)references public.sales_events(company_id,id)on delete restrict,
 foreign key(company_id,order_id)references public.sales_events(company_id,id)on delete restrict,
 foreign key(company_id,stock_event_id)references public.inventory_events(company_id,id)on delete restrict);
create table public.sales_invoice_links(
 company_id uuid not null,stock_event_id uuid not null,invoice_id uuid not null,
 primary key(company_id,stock_event_id),unique(company_id,invoice_id),
 foreign key(company_id,stock_event_id)references public.inventory_events(company_id,id)on delete restrict,
 foreign key(company_id,invoice_id)references public.commercial_documents(company_id,id)on delete restrict);
create function private.sales_reader(cid uuid)returns boolean language sql stable set search_path=''as $$
 select auth.uid()is not null and(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'MANAGEMENT_VIEWER'));
$$;
revoke all on function private.sales_reader(uuid)from public,anon,authenticated,service_role;
-- Policies use public role checks directly; private helpers remain unavailable to browser roles.
do $$declare t text;begin foreach t in array array['sales_events','sales_requests','sales_delivery_lines','sales_invoice_links']loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);execute format('grant select on public.%I to authenticated',t);
 execute format('create policy sales_company_read on public.%I for select to authenticated using(auth.uid()is not null and(public.has_company_role(company_id,''ACCOUNTING_ADMIN'')or public.has_company_role(company_id,''ACCOUNTANT'')or public.has_company_role(company_id,''MANAGEMENT_VIEWER'')))',t);
 execute format('create trigger sales_immutable before update or delete on public.%I for each row execute function private.financial_evidence_immutable()',t);
 end loop;end$$;
create function private.sales_current(cid uuid,did uuid)returns public.sales_events language sql stable set search_path=''as $$
 select e from public.sales_events e where company_id=cid and document_id=did order by version desc limit 1;
$$;
create function private.sales_lines(cid uuid,v jsonb)returns jsonb language plpgsql set search_path=''as $$
declare x jsonb;r jsonb:='[]';m public.inventory_materials;q bigint;price bigint;discount integer;rate integer;base bigint;net bigint;tax bigint;i integer:=0;begin
 if jsonb_typeof(v)is distinct from 'array'or jsonb_array_length(v)not between 1 and 50 then raise exception 'SALES_LINES'using errcode='23514';end if;
 for x in select value from jsonb_array_elements(v)loop
 if exists(select 1 from jsonb_object_keys(x)k where k not in('material_id','description','unit','quantity_micros','unit_price_minor','discount_bps','vat_rate_bps','tax_evidence'))or coalesce(length(btrim(x->>'description')),0)not between 1 and 500 or coalesce(x->>'quantity_micros','')!~'^[0-9]{1,16}$'or coalesce(x->>'unit_price_minor','')!~'^[0-9]{1,16}$'or coalesce(x->>'discount_bps','0')!~'^[0-9]{1,5}$'or coalesce(x->>'vat_rate_bps','')!~'^[0-9]{1,5}$' then raise exception 'SALES_LINES'using errcode='23514';end if;
 select *into m from public.inventory_materials where company_id=cid and id=(x->>'material_id')::uuid and active;
 q:=(x->>'quantity_micros')::bigint;price:=(x->>'unit_price_minor')::bigint;discount:=coalesce((x->>'discount_bps')::integer,0);rate:=(x->>'vat_rate_bps')::integer;
 if m.id is null or q<=0 or price<=0 or discount not between 0 and 9999 or rate not between 0 and 10000 or coalesce(length(btrim(x->>'tax_evidence')),0)not between 5 and 1000 then raise exception 'SALES_LINES'using errcode='23514';end if;
 base:=private.uom_quantity(cid,m.id,x->>'unit',q::text);net:=round(q::numeric*price*(10000-discount)/10000000000)::bigint;tax:=round(net::numeric*rate/10000)::bigint;
 if net<=0 or net>9000000000000000 or net+tax>9000000000000000 then raise exception 'SALES_AMOUNT'using errcode='23514';end if;i:=i+1;
 r:=r||jsonb_build_array(x||jsonb_build_object('line_number',i,'base_quantity_micros',base::text,'base_unit',m.base_unit,'net_minor',net::text,'vat_minor',tax::text));end loop;return r;end$$;

-- Allocate minor-unit return credit cumulatively, using only actual credited return quantities.
-- This closes the independently demonstrated 3-unit / 100-minor split-return rounding gap.
create function private.goods_return_credit_limit(cid uuid,invoice uuid,returned uuid)returns bigint language sql stable set search_path=''as $$
 select round((p.input->>'amount_minor')::numeric*((r.snapshot->'computed'->>'qty')::numeric+coalesce((select sum((s.snapshot->'computed'->>'qty')::numeric)from public.commercial_documents c join public.inventory_events s on s.company_id=c.company_id and s.id=c.return_event_id where c.company_id=cid and c.parent_id=p.id and c.kind='AR_CREDIT'and private.commercial_live(cid,c.id)),0))/(original.snapshot->'computed'->>'qty')::numeric)::bigint-coalesce((select sum((c.input->>'amount_minor')::bigint)from public.commercial_documents c where c.company_id=cid and c.parent_id=p.id and c.kind='AR_CREDIT'and c.return_event_id is not null and private.commercial_live(cid,c.id)),0)::bigint
 from public.commercial_documents p join public.inventory_events original on original.company_id=p.company_id and original.id=p.stock_event_id join public.inventory_events r on r.company_id=p.company_id and r.id=returned and r.snapshot->>'origin_id'=original.document_id::text where p.company_id=cid and p.id=invoice;
$$;
revoke all on function private.goods_return_credit_limit(uuid,uuid,uuid)from public,anon,authenticated,service_role;
do $$declare d text;old_expression text:='n>round((parent.input->>''amount_minor'')::numeric*(returned.snapshot->''computed''->>''qty'')::numeric/(stock.snapshot->''computed''->>''qty'')::numeric)';begin
 d:=pg_get_functiondef('private.customer_plan_legacy104(uuid,text,jsonb)'::regprocedure);
 if strpos(d,old_expression)=0 then raise exception 'Expected canonical goods return dependency missing';end if;
 d:=replace(d,old_expression,'n>private.goods_return_credit_limit(cid,parent.id,returned.id)');execute d;
end$$;

create function public.command_sales(cid uuid,request_id uuid,action text,input jsonb)returns jsonb
 language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_variable
declare actor uuid;h text;prior public.sales_requests;old public.sales_events;o public.sales_events;e public.sales_events;quote public.sales_events;
 did uuid;v jsonb;st text;ver integer;kind text;ref text;result jsonb;x jsonb;l jsonb;s public.inventory_events;r jsonb;doc jsonb;
 issued bigint;qty bigint;base bigint;net bigint;tax bigint;previous_net bigint;total_net bigint;location public.inventory_locations;i integer;dl public.sales_delivery_lines;
begin
 actor:=private.operational_finance_actor(cid,'accounting.post');
 if request_id is null or action is null or action not in('SAVE','REVIEW','APPROVE','CONFIRM','REVISE','CANCEL','CONVERT','POST','INVOICE','RETURN')or jsonb_typeof(input)is distinct from 'object'or octet_length(input::text)>60000 then raise exception 'SALES_INPUT'using errcode='22023';end if;
 perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'action',action,'input',input)::text,'UTF8'),'sha256'),'hex');
 select *into prior from public.sales_requests where company_id=cid and sales_requests.request_id=command_sales.request_id;
 if prior.request_id is not null then if prior.request_hash<>h then raise exception 'SALES_REQUEST_CHANGED'using errcode='23505';end if;return prior.result;end if;
 if action not in('CANCEL','RETURN')and not coalesce((private.company_commercial_readiness(cid)->>'ready')::boolean,false)then raise exception 'SALES_SETUP'using errcode='42501';end if;
 if exists(select 1 from jsonb_object_keys(input)k where k not in('id','version','kind','date','customer_id','project_id','valid_until','customer_reference','notes','lines','reason','quote_id','order_id','evidence','due_date','stock_events','quantity_micros'))then raise exception 'SALES_INPUT'using errcode='22023';end if;
 if action='RETURN'then
 select *into dl from public.sales_delivery_lines where company_id=cid and stock_event_id=(input->>'id')::uuid;
 select *into s from public.inventory_events where company_id=cid and id=dl.stock_event_id;
 select *into o from public.sales_events where company_id=cid and id=dl.order_id;
 select to_jsonb(c)into doc from public.commercial_documents c where c.company_id=cid and c.stock_event_id=dl.stock_event_id and private.commercial_live(cid,c.id);
 if dl.stock_event_id is null or doc is null or coalesce(input->>'quantity_micros','')!~'^[0-9]{1,16}$'or coalesce(length(btrim(input->>'evidence')),0)not between 5 and 1000 then raise exception 'SALES_RETURN_INVOICE'using errcode='23514';end if;
 l:=o.snapshot->'lines'->(dl.order_line-1);qty:=(input->>'quantity_micros')::bigint;
 base:=private.uom_quantity(cid,(l->>'material_id')::uuid,l->>'unit',qty::text);
 r:=public.command_inventory(cid,gen_random_uuid(),'SAVE',jsonb_build_object('id',gen_random_uuid(),'version',0,'kind','RETURN','date',input->>'date','material_id',l->>'material_id','location_id',s.snapshot->>'location_id','qty_micros',qty::text,'unit',l->>'unit','origin_id',s.document_id,'source_reference','SALES-RETURN-'||request_id::text,'evidence',input->>'evidence'));
 r:=public.command_inventory(cid,gen_random_uuid(),'REVIEW',jsonb_build_object('id',r->>'document_id','version',r->>'version','evidence',input->>'evidence'));
 r:=public.command_inventory(cid,gen_random_uuid(),'POST',jsonb_build_object('id',r->>'document_id','version',r->>'version','evidence',input->>'evidence'));
 net:=private.goods_return_credit_limit(cid,(doc->>'id')::uuid,(r->>'id')::uuid);
 select coalesce(sum((c.input->>'amount_minor')::bigint),0),coalesce(sum((c.input->>'vat_minor')::bigint),0)into previous_net,tax from public.commercial_documents c where c.company_id=cid and c.parent_id=(doc->>'id')::uuid and c.kind='AR_CREDIT'and private.commercial_live(cid,c.id);
 tax:=case when previous_net+net=(doc->'input'->>'amount_minor')::bigint then(doc->'input'->>'vat_minor')::bigint-tax else round(net::numeric*(l->>'vat_rate_bps')::integer/10000)::bigint end;
 result:=public.command_customer_accounting(cid,gen_random_uuid(),'AR_CREDIT',jsonb_build_object('date',input->>'date','party_id',o.snapshot->>'customer_id','parent_id',doc->>'id','amount_minor',net::text,'vat_minor',tax::text,'credit_reason','GOODS_RETURN','return_event_id',r->>'id','reference','SALES-CREDIT-'||request_id::text,'evidence',input->>'evidence'))||jsonb_build_object('return_event_id',r->>'id');
 elsif action='INVOICE'then
 if jsonb_typeof(input->'stock_events')is distinct from 'array'or jsonb_array_length(input->'stock_events')not between 1 and 50 or coalesce(length(btrim(input->>'evidence')),0)not between 5 and 1000 then raise exception 'SALES_EVIDENCE'using errcode='23514';end if;
 result:=jsonb_build_object('invoices','[]'::jsonb);
 for x in select value from jsonb_array_elements(input->'stock_events')loop
 select *into dl from public.sales_delivery_lines where company_id=cid and stock_event_id=(x#>>'{}')::uuid;
 if dl.stock_event_id is null or exists(select 1 from public.sales_invoice_links where company_id=cid and stock_event_id=dl.stock_event_id)then raise exception 'SALES_ALREADY_INVOICED'using errcode='23505';end if;
 select *into o from public.sales_events where company_id=cid and id=dl.order_id;
 select *into s from public.inventory_events where company_id=cid and id=dl.stock_event_id;
 l:=o.snapshot->'lines'->(dl.order_line-1);
 if exists(select 1 from public.inventory_events r where r.company_id=cid and r.state='POSTED'and r.snapshot->>'kind'='RETURN'and r.snapshot->>'origin_id'=s.document_id::text and(private.inventory_current(cid,r.document_id)).id=r.id)then raise exception 'SALES_UNBILLED_RETURN'using errcode='23514';end if;
 -- Preserve existing one-issued-line/one-invoice policy. Partial billing selects delivery lines, never reissues stock.
 doc:=public.command_customer_accounting(cid,gen_random_uuid(),'AR_INVOICE',jsonb_build_object('date',s.snapshot->>'date','due_date',input->>'due_date','party_id',o.snapshot->>'customer_id','economic_kind','DELIVERED_GOODS','stock_event_id',s.id,'amount_minor',dl.net_minor::text,'vat_minor',dl.vat_minor::text,'vat_rate_bps',l->>'vat_rate_bps','tax_evidence',l->>'tax_evidence','recognition_confirmed',true,'reference',private.allocate_reference(cid,'SINV',extract(year from(s.snapshot->>'date')::date)::integer),'evidence',input->>'evidence'));
 insert into public.sales_invoice_links values(cid,s.id,(doc->>'id')::uuid);
 result:=jsonb_set(result,'{invoices}',(result->'invoices')||jsonb_build_array(doc||jsonb_build_object('stock_event_id',s.id)));end loop;
 else
 did:=(input->>'id')::uuid;if did is null then raise exception 'SALES_INPUT'using errcode='22023';end if;
 old:=private.sales_current(cid,did);ver:=coalesce(old.version,0);
 if coalesce(input->>'version','')!~'^[0-9]{1,8}$'or(input->>'version')::integer<>ver then raise exception 'SALES_STALE'using errcode='40001';end if;
 if action='CONVERT'then
 if old.id is not null then raise exception 'SALES_STATE'using errcode='23514';end if;
 quote:=private.sales_current(cid,(input->>'quote_id')::uuid);
 if quote.kind is distinct from 'QUOTATION'or quote.state is distinct from 'APPROVED'or(quote.snapshot->>'valid_until')::date<current_date then raise exception 'SALES_QUOTE'using errcode='23514';end if;
 if exists(select 1 from public.sales_events se where se.company_id=cid and se.kind='ORDER'and se.snapshot->>'quote_id'=quote.document_id::text)then raise exception 'SALES_CONVERTED'using errcode='23505';end if;
 kind:='ORDER';st:='DRAFT';v:=quote.snapshot||jsonb_build_object('quote_id',quote.document_id,'quote_version',quote.version,'date',current_date::text);v:=v-'valid_until';
 elsif action='SAVE'then
 if old.id is not null and old.state<>'DRAFT'then raise exception 'SALES_STATE'using errcode='23514';end if;
 kind:=input->>'kind';if kind is null or kind not in('QUOTATION','ORDER','DELIVERY')or old.id is not null and old.kind<>kind then raise exception 'SALES_STATE'using errcode='23514';end if;
 v:=input-array['id','version','kind'];st:='DRAFT';
 if coalesce(v->>'date','')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'or(v->>'date')::date>current_date then raise exception 'SALES_DATE'using errcode='23514';end if;
 if kind in('QUOTATION','ORDER')then
 if not exists(select 1 from public.customer_accounts c join public.parties p on p.company_id=c.company_id and p.id=c.party_id where c.company_id=cid and c.party_id=(v->>'customer_id')::uuid and p.status='ACTIVE')then raise exception 'SALES_CUSTOMER'using errcode='23514';end if;
 if nullif(v->>'project_id','')is not null and not exists(select 1 from public.projects where company_id=cid and id=(v->>'project_id')::uuid and status='ACTIVE')then raise exception 'SALES_PROJECT'using errcode='23514';end if;
 if kind='QUOTATION'and(coalesce(v->>'valid_until','')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'or(v->>'valid_until')::date<(v->>'date')::date)then raise exception 'SALES_DATE'using errcode='23514';end if;
 v:=v||jsonb_build_object('lines',private.sales_lines(cid,v->'lines'));
 if old.snapshot?'quote_id'then v:=v||jsonb_build_object('quote_id',old.snapshot->'quote_id','quote_version',old.snapshot->'quote_version');end if;
 else
 o:=private.sales_current(cid,(v->>'order_id')::uuid);
 if o.kind is distinct from 'ORDER'or o.state is distinct from 'CONFIRMED'or(v->>'date')::date<(o.snapshot->>'date')::date then raise exception 'SALES_ORDER'using errcode='23514';end if;
 if nullif(o.snapshot->>'project_id','')is not null then raise exception 'SALES_PROJECT_STOCK_POLICY'using errcode='23514';end if;
 if jsonb_typeof(v->'lines')is distinct from 'array'or jsonb_array_length(v->'lines')not between 1 and 50 then raise exception 'SALES_LINES'using errcode='23514';end if;
 if(select count(*)from jsonb_array_elements(v->'lines'))<>(select count(distinct a.value->>'order_line')from jsonb_array_elements(v->'lines')a(value))then raise exception 'SALES_LINES'using errcode='23514';end if;
 for x in select value from jsonb_array_elements(v->'lines')loop
 if exists(select 1 from jsonb_object_keys(x)k where k not in('order_line','quantity_micros','location_id'))or coalesce(x->>'order_line','')!~'^[0-9]{1,2}$'or coalesce(x->>'quantity_micros','')!~'^[0-9]{1,16}$'then raise exception 'SALES_LINES'using errcode='23514';end if;
 l:=o.snapshot->'lines'->((x->>'order_line')::integer-1);qty:=(x->>'quantity_micros')::bigint;
 select coalesce(sum(quantity_micros),0)into issued from public.sales_delivery_lines where company_id=cid and order_id=o.id and order_line=(x->>'order_line')::integer;
 select *into location from public.inventory_locations where company_id=cid and id=(x->>'location_id')::uuid and active and project_id is null;
 if l is null or qty<=0 or qty+issued>(l->>'quantity_micros')::bigint or location.id is null then raise exception 'SALES_DELIVERY_QUANTITY'using errcode='23514';end if;
 end loop;
 v:=v||jsonb_build_object('order_version_id',o.id,'customer_id',o.snapshot->>'customer_id');
 end if;
 elsif action='REVISE'then
 if old.kind is distinct from 'QUOTATION'or old.state is distinct from 'APPROVED'or coalesce(length(btrim(input->>'reason')),0)not between 5 and 1000 then raise exception 'SALES_REASON'using errcode='23514';end if;
 kind:=old.kind;v:=old.snapshot||jsonb_build_object('revision_reason',input->>'reason');st:='DRAFT';
 else
 if old.id is null then raise exception 'SALES_STATE'using errcode='23514';end if;kind:=old.kind;v:=old.snapshot;
 if action='REVIEW'and old.state='DRAFT'then st:='REVIEW';
 elsif action='APPROVE'and kind='QUOTATION'and old.state='REVIEW'then st:='APPROVED';
 elsif action='CONFIRM'and kind='ORDER'and old.state='REVIEW'then st:='CONFIRMED';
 elsif action='CANCEL'and old.state in('DRAFT','REVIEW','APPROVED','CONFIRMED')and coalesce(length(btrim(input->>'reason')),0)between 5 and 1000 then st:='CANCELLED';v:=v||jsonb_build_object('cancellation_reason',input->>'reason');
 elsif action='POST'and kind='DELIVERY'and old.state='REVIEW'then
 st:='POSTED';o:=private.sales_current(cid,(v->>'order_id')::uuid);
 if o.state is distinct from 'CONFIRMED'or o.id::text is distinct from v->>'order_version_id'or coalesce(length(btrim(input->>'evidence')),0)not between 5 and 1000 then raise exception 'SALES_ORDER'using errcode='23514';end if;
 else raise exception 'SALES_STATE'using errcode='23514';end if;
 end if;
 -- Revalidate reviewed prices/masters at the transition; approval never posts journals.
 if kind in('QUOTATION','ORDER')and action in('REVIEW','APPROVE','CONFIRM')then
 perform private.sales_lines(cid,(select jsonb_agg(a.value-array['line_number','base_quantity_micros','base_unit','net_minor','vat_minor'])from jsonb_array_elements(v->'lines')a(value)));
 end if;
 ref:=coalesce(old.reference,private.allocate_reference(cid,case kind when 'QUOTATION'then 'SQUO'when 'ORDER'then 'SORD'else 'SDEL'end,extract(year from(v->>'date')::date)::integer));
 insert into public.sales_events(company_id,document_id,version,kind,state,reference,snapshot,actor)values(cid,did,ver+1,kind,st,ref,v,actor)returning *into e;
 if st='POSTED'then
 i:=0;for x in select value from jsonb_array_elements(v->'lines')loop
 i:=i+1;l:=o.snapshot->'lines'->((x->>'order_line')::integer-1);qty:=(x->>'quantity_micros')::bigint;
 select coalesce(sum(quantity_micros),0),coalesce(sum(net_minor),0)into issued,previous_net from public.sales_delivery_lines where company_id=cid and order_id=o.id and order_line=(x->>'order_line')::integer;
 if qty+issued>(l->>'quantity_micros')::bigint then raise exception 'SALES_DELIVERY_QUANTITY'using errcode='23514';end if;
 total_net:=case when qty+issued=(l->>'quantity_micros')::bigint then(l->>'net_minor')::bigint else round((l->>'net_minor')::numeric*(qty+issued)/(l->>'quantity_micros')::numeric)::bigint end;
 net:=total_net-previous_net;tax:=round(net::numeric*(l->>'vat_rate_bps')::integer/10000)::bigint;
 if net<=0 then raise exception 'SALES_AMOUNT'using errcode='23514';end if;
 doc:=jsonb_build_object('id',gen_random_uuid(),'version',0,'kind','ISSUE','date',v->>'date','material_id',l->>'material_id','location_id',x->>'location_id','recipient_id',v->>'customer_id','qty_micros',qty::text,'unit',l->>'unit','cost_purpose','SALE','source_reference',ref||'-'||i,'evidence',input->>'evidence');
 r:=public.command_inventory(cid,gen_random_uuid(),'SAVE',doc);
 r:=public.command_inventory(cid,gen_random_uuid(),'REVIEW',jsonb_build_object('id',r->>'document_id','version',r->>'version','evidence',input->>'evidence'));
 r:=public.command_inventory(cid,gen_random_uuid(),'POST',jsonb_build_object('id',r->>'document_id','version',r->>'version','evidence',input->>'evidence'));
 select *into s from public.inventory_events where company_id=cid and id=(r->>'id')::uuid;
 base:=(s.snapshot->'computed'->>'qty')::bigint;
 insert into public.sales_delivery_lines values(cid,e.id,i,o.id,(x->>'order_line')::integer,qty,base,s.id,net,tax);
 end loop;end if;
 result:=jsonb_build_object('id',did,'event_id',e.id,'version',e.version,'state',st,'reference',ref);
 end if;
 insert into public.sales_requests values(cid,request_id,h,result,actor,now());return result;
end$$;

-- Fulfillment links cannot be made false by independently reversing a stock delivery.
create function private.sales_stock_guard()returns trigger language plpgsql set search_path=''as $$begin
 if new.state='REVERSED'and exists(select 1 from public.sales_delivery_lines d join public.inventory_events s on s.company_id=d.company_id and s.id=d.stock_event_id where d.company_id=new.company_id and s.document_id=new.document_id)then raise exception 'SALES_RETURN_REQUIRED'using errcode='23514';end if;return new;end$$;
create trigger sales_stock_history before insert on public.inventory_events for each row execute function private.sales_stock_guard();

create function public.read_sales(cid uuid,page integer default 0,page_size integer default 25)returns jsonb language plpgsql stable security definer set search_path=''as $$
declare result jsonb;begin
 if not private.sales_reader(cid)then raise exception 'SALES_DENIED'using errcode='42501';end if;
 if page is null or page<0 or page_size is null or page_size not between 1 and 100 then raise exception 'SALES_PAGE'using errcode='22023';end if;
 with current_docs as(select distinct on(document_id)*from public.sales_events where company_id=cid order by document_id,version desc)
 select jsonb_build_object('today',current_date,'can_edit',public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT'),
 'can_start',coalesce((private.company_commercial_readiness(cid)->>'ready')::boolean,false),'count',(select count(*)from current_docs),'documents',coalesce((select jsonb_agg(to_jsonb(d))from(select *from current_docs order by created_at desc,document_id limit page_size offset page*page_size)d),'[]'::jsonb))into result;
 return result||jsonb_build_object(
 'customers',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name))from public.customer_accounts c join public.parties p on p.company_id=c.company_id and p.id=c.party_id where c.company_id=cid and p.status='ACTIVE'),'[]'::jsonb),
 'projects',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name))from public.projects where company_id=cid and status='ACTIVE'),'[]'::jsonb),
 'materials',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'base_unit',base_unit,'conversions',conversions))from public.inventory_materials where company_id=cid and active),'[]'::jsonb),
 'locations',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name))from public.inventory_locations where company_id=cid and active and project_id is null),'[]'::jsonb),
 'delivery_lines',coalesce((select jsonb_agg(to_jsonb(d)||jsonb_build_object('quantity_micros',d.quantity_micros::text,'base_quantity_micros',d.base_quantity_micros::text,'net_minor',d.net_minor::text,'vat_minor',d.vat_minor::text,'invoice_id',c.id,'invoice_effective',case when c.id is null then false else private.commercial_live(cid,c.id)end,'journal_id',c.journal_id,'customer_id',s.snapshot->>'recipient_id','stock_document_id',s.document_id,'stock_reference',s.reference,'invoice_reference',c.reference,'order_document_id',so.document_id,'sales_unit',so.snapshot->'lines'->(d.order_line-1)->>'unit','description',so.snapshot->'lines'->(d.order_line-1)->>'description','date',s.snapshot->>'date','cost_minor',s.snapshot->'computed'->>'value','recognized_net_minor',case when c.id is null or not private.commercial_live(cid,c.id)then '0'else((c.input->>'amount_minor')::bigint-coalesce((select sum((cr.input->>'amount_minor')::bigint)from public.commercial_documents cr where cr.company_id=cid and cr.parent_id=c.id and cr.kind='AR_CREDIT'and private.commercial_live(cid,cr.id)),0))::text end,'returned_cost_minor',coalesce((select sum((r.snapshot->'computed'->>'value')::numeric)::text from public.inventory_events r where r.company_id=cid and r.state='POSTED'and r.snapshot->>'kind'='RETURN'and r.snapshot->>'origin_id'=s.document_id::text and(private.inventory_current(cid,r.document_id)).id=r.id),'0'),'returned_base_micros',coalesce((select sum((r.snapshot->'computed'->>'qty')::numeric)::text from public.inventory_events r where r.company_id=cid and r.state='POSTED'and r.snapshot->>'kind'='RETURN'and r.snapshot->>'origin_id'=s.document_id::text and(private.inventory_current(cid,r.document_id)).id=r.id),'0')))from public.sales_delivery_lines d join public.sales_events so on so.company_id=d.company_id and so.id=d.order_id join public.inventory_events s on s.company_id=d.company_id and s.id=d.stock_event_id left join public.commercial_documents c on c.company_id=d.company_id and c.stock_event_id=d.stock_event_id where d.company_id=cid),'[]'::jsonb));
end$$;
revoke all on function private.sales_current(uuid,uuid),private.sales_lines(uuid,jsonb),private.sales_stock_guard()from public,anon,authenticated,service_role;
revoke all on function public.command_sales(uuid,uuid,text,jsonb),public.read_sales(uuid,integer,integer)from public,anon,authenticated,service_role;
grant execute on function public.command_sales(uuid,uuid,text,jsonb),public.read_sales(uuid,integer,integer)to authenticated;

create function public.read_sales_history(cid uuid,did uuid)returns jsonb language plpgsql stable security definer set search_path=''as $$begin
 if not private.sales_reader(cid)then raise exception 'SALES_DENIED'using errcode='42501';end if;
 return coalesce((select jsonb_agg(to_jsonb(e)order by version)from public.sales_events e where company_id=cid and document_id=did),'[]'::jsonb);end$$;
revoke all on function public.read_sales_history(uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.read_sales_history(uuid,uuid)to authenticated;

create function private.sales_invoice_guard()returns trigger language plpgsql set search_path=''as $$declare d public.sales_delivery_lines;begin
 if new.stock_event_id is not null then
 select *into d from public.sales_delivery_lines where company_id=new.company_id and stock_event_id=new.stock_event_id;
 if d.stock_event_id is not null and(new.kind<>'AR_INVOICE'or(new.input->>'amount_minor')::bigint<>d.net_minor or coalesce((new.input->>'vat_minor')::bigint,0)<>d.vat_minor)then raise exception 'SALES_AGREED_PRICE'using errcode='23514';end if;
 end if;return new;end$$;
create trigger sales_invoice_pricing before insert on public.commercial_documents for each row execute function private.sales_invoice_guard();
create function private.sales_material_guard()returns trigger language plpgsql set search_path=''as $$begin
 if exists(select 1 from public.sales_events e cross join lateral jsonb_array_elements(e.snapshot->'lines')l where e.company_id=old.company_id and e.kind in('QUOTATION','ORDER')and l->>'material_id'=old.id::text)and(new.base_unit is distinct from old.base_unit or exists(select 1 from jsonb_each(old.conversions)c where new.conversions->c.key is distinct from c.value))then raise exception 'SALES_UNIT_HISTORY'using errcode='23514';end if;return new;end$$;
create trigger sales_material_units before update on public.inventory_materials for each row execute function private.sales_material_guard();
revoke all on function private.sales_invoice_guard(),private.sales_material_guard()from public,anon,authenticated,service_role;
