--112: composite receiving and a single canonical AP invoice with authoritative line allocations.
-- No backfill, setup changes, stock movement or financial invocation at migration time.
create table public.procurement_invoice_lines(
 company_id uuid not null references public.companies(id),expense_id uuid not null,receipt_id uuid not null,
 quantity_micros bigint not null check(quantity_micros>0),net_minor bigint not null check(net_minor>0),vat_minor bigint not null check(vat_minor>=0),
 match_id uuid not null,primary key(company_id,expense_id,receipt_id),foreign key(company_id,expense_id)references public.expenses(company_id,id));
alter table public.procurement_invoice_lines enable row level security;
alter table public.procurement_invoice_lines force row level security;
revoke all on public.procurement_invoice_lines from public,anon,authenticated,service_role;
grant select on public.procurement_invoice_lines to authenticated;
create policy procurement_invoice_lines_read on public.procurement_invoice_lines for select to authenticated using(public.has_company_role(company_id,'ACCOUNTING_ADMIN')or public.has_company_role(company_id,'ACCOUNTANT')or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create trigger procurement_invoice_lines_immutable before update or delete on public.procurement_invoice_lines for each row execute function private.financial_evidence_immutable();
create table private.procurement_group_lines(company_id uuid not null references public.companies(id),parent_id uuid not null,child_id uuid not null,position integer not null,primary key(company_id,parent_id,position),unique(company_id,child_id));
revoke all on private.procurement_group_lines from public,anon,authenticated,service_role;
create trigger procurement_group_immutable before update or delete on private.procurement_group_lines for each row execute function private.financial_evidence_immutable();
-- Retain canonical implementations and all prior call-site OIDs/grants.
do $$declare a text;b text;definition text;begin for a,b in select *from(values
 ('private.procurement_plan','private.pre_multi_procurement_plan'),('public.command_procurement','private.pre_multi_command_procurement'),
 ('public.read_procurement','private.pre_multi_read_procurement'),('private.supplier_invoice_plan','private.pre_multi_supplier_invoice_plan'),
 ('public.post_supplier_invoice','private.pre_multi_post_supplier_invoice'))x(a,b)loop
 definition:=replace(pg_get_functiondef((a||case when a like'%command_procurement'then'(uuid,uuid,text,jsonb)'when a like'%read_procurement'then'(uuid,integer,integer)'when a like'%procurement_plan'then'(uuid,text,jsonb,boolean)'when a like'%post_supplier_invoice'then'(uuid,uuid,jsonb)'else'(uuid,jsonb)'end)::regprocedure),a||'(',b||'(');if a='public.command_procurement'then definition:=replace(definition,'command_procurement.request_id','pre_multi_command_procurement.request_id');end if;execute definition;
 end loop;end$$;

create function private.multi_invoice_plan(cid uuid,v jsonb)returns jsonb language plpgsql set search_path=''as $$
declare r public.inventory_events;x jsonb;b jsonb;header jsonb;plan jsonb;items jsonb:='[]';seen uuid[]:='{}';sid uuid;pid uuid;first boolean:=true;n numeric:=0;t numeric:=0;ln bigint;lt bigint;clearing numeric:=0;cfg public.inventory_configuration;lines jsonb:='[]';tax uuid;ap uuid;
begin
 perform private.operational_finance_actor(cid,'accounting.post');perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 if v is null or octet_length(v::text)>55000 or v-array['date','due_date','category_id','description','invoice_number','has_tax_invoice','receipt_lines','notes']<>'{}'::jsonb or jsonb_typeof(v->'receipt_lines')is distinct from'array'or jsonb_array_length(v->'receipt_lines')not between 1 and 50 then raise exception 'PROC_LINES: select1–50 receipt lines'using errcode='22023';end if;
 select *into cfg from public.inventory_configuration where company_id=cid;
 for x in select z from jsonb_array_elements(v->'receipt_lines')z loop
  if x-array['receipt_id','quantity_micros','net_minor','vat_mode','vat_minor','variance_reason']<>'{}'::jsonb or coalesce(x->>'net_minor','')!~'^[0-9]{1,16}$'or(x->>'net_minor')::numeric<=0 then raise exception 'PROC_LINES: exact line quantities/net required'using errcode='23514';end if;
  r:=private.inventory_current(cid,(x->>'receipt_id')::uuid);
  if r.id is null or r.document_id=any(seen)then raise exception 'PROC_LINES: missing, foreign or duplicate receipt line'using errcode='23514';end if;seen:=array_append(seen,r.document_id);
  if first then sid:=(r.snapshot->>'supplier_id')::uuid;pid:=nullif(r.snapshot->'computed'->>'project','')::uuid;first:=false;end if;
  if sid is null or sid::text is distinct from r.snapshot->>'supplier_id'or pid is distinct from nullif(r.snapshot->'computed'->>'project','')::uuid then raise exception 'PROC_CONSOLIDATION: same Company, Supplier and Project required'using errcode='23514';end if;
  b:=private.inventory_match_basis(cid,r.document_id,x->>'quantity_micros',(v->>'date')::date);ln:=(x->>'net_minor')::bigint;
  if ln<>(b->>'clearing_minor')::bigint and(not public.has_company_role(cid,'ACCOUNTING_ADMIN')or coalesce(length(btrim(x->>'variance_reason')),0)<5)then raise exception 'PROC_VARIANCE: Admin must approve each price difference'using errcode='42501';end if;
  if x->>'vat_mode'='ZERO'then lt:=0;
  elsif x->>'vat_mode'='AUTO_5'then lt:=round(ln::numeric*5/100)::bigint;
  elsif x->>'vat_mode'='MANUAL'and coalesce(x->>'vat_minor','')~'^[0-9]{1,16}$'then lt:=(x->>'vat_minor')::bigint;
  else raise exception 'PROC_TAX: verify each line tax treatment'using errcode='23514';end if;
  if lt>0 and v->>'has_tax_invoice'is distinct from'true'then raise exception 'PROC_TAX: recoverable VAT requires verified tax invoice'using errcode='23514';end if;
  n:=n+ln;t:=t+lt;clearing:=clearing+(b->>'clearing_minor')::bigint;
  items:=items||jsonb_build_array(x||b||jsonb_build_object('net_minor',ln::text,'vat_minor',lt::text,'material_id',r.snapshot->>'material_id','unit',r.snapshot->>'unit','location_id',r.snapshot->>'location_id'));
 end loop;
 if n+t>9000000000000000 then raise exception 'PROC_TOTAL'using errcode='23514';end if;
 header:=(v-'receipt_lines')||jsonb_build_object('supplier_id',sid,'project_id',pid,'funding_mode','SUPPLIER_CREDIT','purchase_kind','SERVICE','net_minor',n::bigint::text,'vat_mode',case when t=0 then'ZERO'else'MANUAL'end,'vat_minor',t::bigint::text);
 plan:=private.pre_multi_supplier_invoice_plan(cid,header);
 lines:=jsonb_build_array(jsonb_build_object('account_id',cfg.grni_account_id,'party_id',sid,'debit_minor',clearing::bigint::text,'credit_minor','0'));
 if n<>clearing then lines:=lines||jsonb_build_array(jsonb_build_object('account_id',cfg.variance_account_id,'debit_minor',greatest(n-clearing,0)::bigint::text,'credit_minor',greatest(clearing-n,0)::bigint::text));end if;
 for x in select z from jsonb_array_elements(plan->'lines')z where z->>'account_id'<>case when pid is null then(select id::text from public.accounts where company_id=cid and system_key='COMPANY_EXPENSE')else(select id::text from public.accounts where company_id=cid and system_key='PROJECT_COST')end loop lines:=lines||jsonb_build_array(x);end loop;
 return plan||jsonb_build_object('header',header,'receipt_lines',items,'lines',lines,'clearing_minor',clearing::bigint::text);
end$$;
create or replace function private.supplier_invoice_plan(cid uuid,v jsonb)returns jsonb language plpgsql security definer set search_path=''as $$begin if v ?'receipt_lines'then return private.multi_invoice_plan(cid,v);end if;return private.pre_multi_supplier_invoice_plan(cid,v);end$$;
create or replace function public.post_supplier_invoice(cid uuid,request_id uuid,input jsonb)returns jsonb language plpgsql security definer set search_path=''as $$
declare actor uuid;req private.financial_command_requests;plan jsonb;ex jsonb;x jsonb;old public.inventory_events;r jsonb;did uuid;ids jsonb:='[]';begin
 if not(input ?'receipt_lines')then return private.pre_multi_post_supplier_invoice(cid,request_id,input);end if;
 actor:=private.operational_finance_actor(cid,'accounting.post');perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 req:=private.reserve_financial_command(cid,'POST_SUPPLIER_MULTI_INVOICE',request_id,encode(sha256(convert_to(jsonb_build_array(actor,cid,input)::text,'UTF8')),'hex'),actor);
 if req.status='COMPLETED'then return jsonb_build_object('id',(select id from public.expenses where company_id=cid and posted_journal_entry_id=req.resulting_journal_entry_id),'journal',req.resulting_journal_entry_id,'replayed',true);end if;
 plan:=private.multi_invoice_plan(cid,input);ex:=private.pre_multi_post_supplier_invoice(cid,gen_random_uuid(),plan->'header');
 for x in select z from jsonb_array_elements(plan->'receipt_lines')z loop
  did:=gen_random_uuid();old:=private.inventory_current(cid,(x->>'receipt_id')::uuid);
  insert into public.procurement_invoice_lines values(cid,(ex->>'id')::uuid,old.document_id,(x->>'qty')::bigint,(x->>'net_minor')::bigint,(x->>'vat_minor')::bigint,did);
  r:=public.command_inventory(cid,gen_random_uuid(),'SAVE',jsonb_build_object('id',did,'version',0,'kind','MATCH','date',input->>'date','material_id',old.snapshot->>'material_id','location_id',old.snapshot->>'location_id','origin_id',old.document_id,'expense_id',ex->>'id','qty_micros','0','match_quantity_micros',x->>'qty','unit',old.snapshot->>'unit','value_minor',x->>'net_minor','variance_reason',coalesce(x->>'variance_reason',''),'supplier_id',plan->'header'->>'supplier_id','project_id',plan->'header'->>'project_id','source_reference',input->>'invoice_number','evidence',input->>'description'));
  r:=public.command_inventory(cid,gen_random_uuid(),'REVIEW',jsonb_build_object('id',did,'version',r->>'version','evidence',input->>'description'));
  r:=public.command_inventory(cid,gen_random_uuid(),'POST',jsonb_build_object('id',did,'version',r->>'version','evidence',input->>'description'));ids:=ids||jsonb_build_array(did);
 end loop;
 perform private.complete_financial_command(req.id,(ex->>'journal')::uuid);return ex||jsonb_build_object('inventory_documents',ids,'inventory_document',ids->>0);
end$$;
-- Only trusted, immutable invoice allocations permit multiple canonical MATCH events.
do $$declare d text;old text;begin d:=pg_get_functiondef('private.inventory_plan(uuid,jsonb)'::regprocedure);
 old:='ex.net_amount_minor<>amount';if position(old in d)=0 then raise exception 'Inventory invoice dependency changed';end if;
 d:=replace(d,old,'(ex.net_amount_minor<>amount and not exists(select 1 from public.procurement_invoice_lines a where a.company_id=cid and a.expense_id=ex.id and a.receipt_id=origin.document_id and a.net_minor=amount and a.quantity_micros=qty))');
 d:=replace(d,'l.debit_minor=amount and l.credit_minor=0','l.debit_minor=ex.net_amount_minor and l.credit_minor=0');
 old:='and e.snapshot->>''expense_id''=ex.id::text and e.snapshot->>''kind''in(''RECEIPT'',''MATCH'',''INVOICE'')';
 if position(old in d)=0 then raise exception 'Inventory duplicate guard changed';end if;
 d:=replace(d,old,old||'and(kind<>''MATCH''or not exists(select 1 from public.procurement_invoice_lines a where a.company_id=cid and a.expense_id=ex.id)or(kind=''MATCH''and e.snapshot->>''origin_id''=origin.document_id::text))');
 -- Allocated invoice lines must match exact approved net and quantity, even if equal to header net.
 d:=replace(d,'if kind=''MATCH''and ex.supplier_id', 'if kind<>''MATCH''and exists(select 1 from public.procurement_invoice_lines a where a.company_id=cid and a.expense_id=ex.id)then raise exception ''PROC_ALLOCATION: consolidated invoices use only their approved receipt matches''using errcode=''23514'';end if; if kind=''MATCH''and exists(select 1 from public.procurement_invoice_lines a where a.company_id=cid and a.expense_id=ex.id)and not exists(select 1 from public.procurement_invoice_lines a where a.company_id=cid and a.expense_id=ex.id and a.receipt_id=origin.document_id and a.net_minor=amount and a.quantity_micros=qty)then raise exception ''PROC_ALLOCATION: line differs from approved invoice''using errcode=''23514'';end if;\n  if kind=''MATCH''and ex.supplier_id');
 execute replace(d,E'\\n',E'\n');
 -- Credit only the returned allocation's net/VAT; preserve original header VAT journal lookup.
 d:=pg_get_functiondef('private.supplier_return_plan(uuid,text,jsonb)'::regprocedure);
 d:=replace(d,'n:=round(ex.net_amount_minor::numeric','if exists(select 1 from public.procurement_invoice_lines a where a.company_id=cid and a.expense_id=ex.id)then select a.net_minor,a.vat_minor into ex.net_amount_minor,ex.vat_amount_minor from public.procurement_invoice_lines a where a.company_id=cid and a.expense_id=ex.id and a.receipt_id=r.document_id;if not found then raise exception ''PROC_ALLOCATION''using errcode=''23514'';end if;end if; n:=round(ex.net_amount_minor::numeric');
 d:=replace(d,'l.debit_minor=ex.vat_amount_minor','l.debit_minor=(select vat_amount_minor from public.expenses where company_id=cid and id=ex.id)');execute d;
end$$;
create or replace function private.procurement_plan(cid uuid,kind text,v jsonb,complete boolean)returns jsonb language plpgsql set search_path=''as $$
declare x jsonb;p jsonb;items jsonb:='[]';canonical jsonb;total numeric:=0;seen text[]:='{}';begin
 if kind='RECEIPT'and v ?'receiving_lines'then
  if v-array['date','po_id','reference','evidence','receiving_lines']<>'{}'::jsonb or jsonb_typeof(v->'receiving_lines')is distinct from'array'or jsonb_array_length(v->'receiving_lines')not between 1 and 50 then raise exception 'PROC_LINES'using errcode='23514';end if;
  for x in select z from jsonb_array_elements(v->'receiving_lines')z loop
   if x-array['line_number','location_id','quantity_micros']<>'{}'::jsonb or coalesce(x->>'line_number','')!~'^[1-9][0-9]?$'or x->>'line_number'=any(seen)then raise exception 'PROC_LINES: order line may occur once per receipt'using errcode='23514';end if;seen:=array_append(seen,x->>'line_number');
   p:=private.pre_multi_procurement_plan(cid,kind,(v-'receiving_lines')||x,complete);items:=items||jsonb_build_array(p);total:=total+(p->>'value_minor')::bigint;
  end loop;
  return v||jsonb_build_object('receiving_lines',items,'supplier_id',p->>'supplier_id','project_id',p->>'project_id','value_minor',total::bigint::text);
 elsif kind='INVOICE'and v ?'invoice_lines'then
  if v-array['date','invoice_lines','category_id','invoice_number','due_date','has_tax_invoice','evidence']<>'{}'::jsonb or jsonb_typeof(v->'invoice_lines')is distinct from'array'or jsonb_array_length(v->'invoice_lines')not between 1 and 50 then raise exception 'PROC_LINES'using errcode='23514';end if;
  for x in select z from jsonb_array_elements(v->'invoice_lines')z loop
   if x-array['receipt_id','quantity_micros','net_minor','vat_mode','vat_minor','variance_reason']<>'{}'::jsonb then raise exception 'PROC_LINES'using errcode='23514';end if;
   p:=private.pre_multi_procurement_plan(cid,kind,(v-'invoice_lines')||x,complete);
   items:=items||jsonb_build_array(x||jsonb_build_object('receipt_id',p->'canonical'->>'receipt_id'));
  end loop;
  canonical:=jsonb_build_object('date',v->>'date','due_date',v->>'due_date','category_id',v->>'category_id','invoice_number',v->>'invoice_number','description',v->>'evidence','has_tax_invoice',coalesce((v->>'has_tax_invoice')::boolean,false),'receipt_lines',items);
  p:=private.multi_invoice_plan(cid,canonical);return v||jsonb_build_object('canonical',canonical,'preview',p);
 end if;
 if kind='RECEIPT'and coalesce(v->>'line_number','')!~'^[1-9][0-9]?$'then raise exception 'PROC_LINES: use canonical PO line number'using errcode='23514';end if;
 return private.pre_multi_procurement_plan(cid,kind,v,complete);
end$$;
create or replace function public.command_procurement(cid uuid,request_id uuid,action text,input jsonb)returns jsonb language plpgsql security definer set search_path=''as $$
#variable_conflict use_column
declare e public.procurement_events;prior public.procurement_events;actor uuid;h text;plan jsonb;x jsonb;r jsonb;child jsonb;children jsonb:='[]';res jsonb;state text;position integer:=0;inv public.inventory_events;ex public.expenses;
begin
 e:=private.procurement_current(cid,(input->>'id')::uuid);
 if action not in('EXECUTE','REVERSE')or not(coalesce(e.snapshot,'{}') ?'receiving_lines'or coalesce(e.snapshot,'{}') ?'invoice_lines')then return private.pre_multi_command_procurement(cid,request_id,action,input);end if;
 actor:=private.operational_finance_actor(cid,case when action='REVERSE'then'accounting.reverse'else'accounting.post'end);perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 if request_id is null or input-array['id','version','reason']<>'{}'::jsonb then raise exception 'PROC_INPUT'using errcode='22023';end if;
 h:=encode(sha256(convert_to(jsonb_build_array(actor,action,input)::text,'UTF8')),'hex');select *into prior from public.procurement_events p where p.company_id=cid and p.request_id=command_procurement.request_id;
 if found then if prior.request_hash<>h then raise exception 'PROC_REPLAY'using errcode='22023';end if;return jsonb_build_object('id',prior.document_id,'version',prior.version,'state',prior.state,'reference',prior.reference,'result',prior.result,'replayed',true);end if;
 e:=private.procurement_current(cid,(input->>'id')::uuid);if e.version is distinct from(input->>'version')::integer then raise exception 'PROC_STALE'using errcode='40001';end if;
 if action='EXECUTE'then
  if e.state<>'REVIEWED'then raise exception 'PROC_STATE'using errcode='23514';end if;
  plan:=private.procurement_plan(cid,e.kind,e.snapshot,true);
  if e.kind='RECEIPT'then
   if exists(select 1 from(select distinct on(document_id)*from public.procurement_events where company_id=cid order by document_id,version desc)p where p.kind='RECEIPT'and p.state='EXECUTED'and p.snapshot->>'po_id'=e.snapshot->>'po_id'and lower(btrim(p.snapshot->>'reference'))=lower(btrim(e.snapshot->>'reference'))and not exists(select 1 from private.procurement_group_lines g where g.company_id=cid and g.child_id=p.document_id))then raise exception 'PROC_DUPLICATE: delivery reference already received for this order'using errcode='23505';end if;
   for x in select z from jsonb_array_elements(e.snapshot->'receiving_lines')z loop
    child:=private.pre_multi_command_procurement(cid,gen_random_uuid(),'SAVE',(e.snapshot-'receiving_lines')||x||jsonb_build_object('reference',(e.snapshot->>'reference')||' / line '||(x->>'line_number'),'id',gen_random_uuid(),'version',0,'kind','RECEIPT'));
    child:=private.pre_multi_command_procurement(cid,gen_random_uuid(),'REVIEW',jsonb_build_object('id',child->>'id','version',child->>'version'));
    child:=private.pre_multi_command_procurement(cid,gen_random_uuid(),'EXECUTE',jsonb_build_object('id',child->>'id','version',child->>'version'));
    position:=position+1;insert into private.procurement_group_lines values(cid,e.document_id,(child->>'id')::uuid,position);children:=children||jsonb_build_array(child);
   end loop;res:=jsonb_build_object('children',children,'value_minor',plan->>'value_minor');
  else res:=public.post_supplier_invoice(cid,gen_random_uuid(),plan->'canonical');end if;state:='EXECUTED';
 else
  if e.state<>'EXECUTED'or not public.has_company_role(cid,'ACCOUNTING_ADMIN')or coalesce(length(btrim(input->>'reason')),0)<5 then raise exception 'PROC_REVERSAL'using errcode='42501';end if;
  if e.kind='RECEIPT'then
   for x in select to_jsonb(g)from private.procurement_group_lines g where g.company_id=cid and g.parent_id=e.document_id order by g.position desc loop
    prior:=private.procurement_current(cid,(x->>'child_id')::uuid);perform private.pre_multi_command_procurement(cid,gen_random_uuid(),'REVERSE',jsonb_build_object('id',prior.document_id,'version',prior.version,'reason',input->>'reason'));
   end loop;
  else
   for inv in select distinct on(document_id)*from public.inventory_events i where i.company_id=cid and i.snapshot->>'expense_id'=e.result->>'id'and i.snapshot->>'kind'='MATCH'order by document_id,version desc loop
    if inv.state='POSTED'then perform public.command_inventory(cid,gen_random_uuid(),'REVERSE',jsonb_build_object('id',inv.document_id,'version',inv.version,'evidence',input->>'reason'));end if;
   end loop;perform public.reverse_expense(cid,(e.result->>'id')::uuid,current_date,input->>'reason',gen_random_uuid());
  end if;res:=e.result;state:='REVERSED';
 end if;
 insert into public.procurement_events(company_id,document_id,version,request_id,request_hash,kind,state,action,reference,snapshot,result,created_by)values(cid,e.document_id,e.version+1,request_id,h,e.kind,state,action,e.reference,e.snapshot||case when action='REVERSE'then jsonb_build_object('resolution_reason',input->>'reason')else'{}'::jsonb end,res,actor);
 return jsonb_build_object('id',e.document_id,'version',e.version+1,'state',state,'reference',e.reference,'result',res,'replayed',false);
end$$;
-- Keep fulfillment on canonical child receipt lines, while presenting one physical document.
do $$declare d text;old text;begin
 d:=pg_get_functiondef('private.pre_multi_read_procurement(uuid,integer,integer)'::regprocedure);
 old:='from latest)';d:=replace(d,old,'from latest z where not exists(select 1 from private.procurement_group_lines g where g.company_id=cid and g.child_id=z.document_id))');
 d:=replace(d,'from latest order by created_at desc,document_id offset','from latest z where not exists(select 1 from private.procurement_group_lines g where g.company_id=cid and g.child_id=z.document_id)order by created_at desc,document_id offset');
 execute d;
end$$;
create or replace function public.read_procurement(cid uuid,page_offset integer default 0,page_size integer default 50)returns jsonb language plpgsql stable security definer set search_path=''as $$
#variable_conflict use_column
declare result jsonb;x jsonb;documents jsonb:='[]';items jsonb:='[]';r public.inventory_events;b jsonb;begin
 result:=private.pre_multi_read_procurement(cid,page_offset,page_size);
 for x in select z from jsonb_array_elements(result->'documents')z loop
  if x->'snapshot' ?'receiving_lines'then
   x:=x||jsonb_build_object('effective_state',case when x->>'state'='EXECUTED'and not exists(select 1 from private.procurement_group_lines g where g.company_id=cid and g.parent_id=(x->>'document_id')::uuid and((private.procurement_current(cid,g.child_id)).state<>'EXECUTED'or(private.inventory_current(cid,((private.procurement_current(cid,g.child_id)).result->>'inventory_id')::uuid)).state<>'POSTED'))then'EXECUTED'when x->>'state'='EXECUTED'then'NEEDS_REVIEW'else x->>'state'end);
  elsif x->'snapshot' ?'invoice_lines'then
   x:=x||jsonb_build_object('effective_state',case when x->>'state'='EXECUTED'and exists(select 1 from public.expenses e where e.company_id=cid and e.id=(x->'result'->>'id')::uuid and e.status='REVERSED')then'REVERSED'when x->>'state'='EXECUTED'and exists(select 1 from public.procurement_invoice_lines a where a.company_id=cid and a.expense_id=(x->'result'->>'id')::uuid and(private.inventory_current(cid,a.match_id)).state<>'POSTED')then'NEEDS_REVIEW'else x->>'state'end);
  end if;documents:=documents||jsonb_build_array(x);
 end loop;
 for x in select z from jsonb_array_elements(result->'receipts')z loop
  r:=private.inventory_current(cid,(x->'result'->>'inventory_id')::uuid);
  b:=jsonb_build_object('inventory_id',r.document_id,'material_id',r.snapshot->>'material_id','unit',r.snapshot->>'unit','supplier_id',r.snapshot->>'supplier_id','project_id',r.snapshot->'computed'->>'project','value_minor',r.snapshot->'computed'->>'value','remaining_micros',((r.snapshot->'computed'->>'qty')::numeric-coalesce((select sum((m.snapshot->'computed'->>'qty')::numeric)from public.inventory_events m where m.company_id=cid and m.state='POSTED'and m.snapshot->>'origin_id'=r.document_id::text and m.snapshot->>'kind'='MATCH'and not exists(select 1 from public.inventory_events z where z.company_id=cid and z.document_id=m.document_id and z.state='REVERSED')),0))::bigint::text);
  items:=items||jsonb_build_array(x||jsonb_build_object('matching',b));
 end loop;
 result:=result||jsonb_build_object('supplier_history',(with latest as(select distinct on(document_id)*from public.procurement_events where company_id=cid order by document_id,version desc),orders as(select distinct on(document_id)*from public.purchase_order_events where company_id=cid order by document_id,version desc)select coalesce(jsonb_agg(to_jsonb(s)order by supplier_id),'[]')from(select o.snapshot->>'supplier_id'supplier_id,count(*)::integer recorded_receipts,count(*)filter(where nullif(o.snapshot->>'delivery_on','')is not null)::integer dated_receipts,count(*)filter(where nullif(o.snapshot->>'delivery_on','')is not null and(r.snapshot->>'date')::date<=(o.snapshot->>'delivery_on')::date)::integer on_time_receipts from latest r join orders o on o.document_id=(r.snapshot->>'po_id')::uuid where r.kind='RECEIPT'and r.state='EXECUTED'and not exists(select 1 from private.procurement_group_lines g where g.company_id=cid and g.child_id=r.document_id)and(case when r.snapshot ?'receiving_lines'then not exists(select 1 from private.procurement_group_lines g where g.company_id=cid and g.parent_id=r.document_id and(private.inventory_current(cid,((private.procurement_current(cid,g.child_id)).result->>'inventory_id')::uuid)).state<>'POSTED')else(private.inventory_current(cid,(r.result->>'inventory_id')::uuid)).state='POSTED'end)group by o.snapshot->>'supplier_id')s));
 return result||jsonb_build_object('documents',documents,'receipts',items,
 'posted_invoice_lines',(select coalesce(jsonb_agg(jsonb_build_object('invoice_id',a.expense_id,'receipt_id',a.receipt_id,'invoice_number',t.invoice_number,'date',ex.expense_date,'status',ex.status,'supplier_id',ex.supplier_id,'quantity_micros',a.quantity_micros::text,'net_minor',a.net_minor::text,'vat_minor',a.vat_minor::text,'clearing_minor',m.snapshot->'computed'->>'clearing_minor','unit',r.snapshot->>'unit','material_id',r.snapshot->>'material_id')order by ex.expense_date,t.invoice_number,a.receipt_id),'[]')from public.procurement_invoice_lines a join public.expenses ex on ex.company_id=a.company_id and ex.id=a.expense_id join public.supplier_invoice_terms t on t.company_id=a.company_id and t.expense_id=a.expense_id cross join lateral(select *from public.inventory_events e where e.company_id=a.company_id and e.document_id=a.match_id and e.state='POSTED'order by version limit 1)m cross join lateral(select *from public.inventory_events e where e.company_id=a.company_id and e.document_id=a.receipt_id and e.state='POSTED'order by version limit 1)r where a.company_id=cid));
end$$;
-- Private copies/primitives are never browser-callable; existing public grants/OIDs retained.
do $$declare p record;begin for p in select oid::regprocedure sig from pg_proc where pronamespace='private'::regnamespace and(proname like'pre_multi_%'or proname='multi_invoice_plan')loop execute format('revoke all on function %s from public,anon,authenticated,service_role',p.sig);end loop;end$$;
