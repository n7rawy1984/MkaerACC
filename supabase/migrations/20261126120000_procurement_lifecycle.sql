--108: receipt-first procurement, composed with canonical Inventory and Supplier AP.
-- No seeds/backfill. PR/RFQ/PO commitments create no journal. Invoice price differences
-- use the existing Inventory variance control (same policy as purchase returns).
create table public.procurement_events(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id)on delete restrict,
 document_id uuid not null,version integer not null check(version>0),request_id uuid not null,request_hash text not null,
 kind text not null check(kind in('REQUISITION','RFQ','RECEIPT','INVOICE')),
 state text not null check(state in('DRAFT','SUBMITTED','REVIEWED','APPROVED','REJECTED','CANCELLED','EXECUTED','REVERSED')),
 action text not null,reference text not null,snapshot jsonb not null,result jsonb,
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,document_id,version),unique(company_id,request_id));
alter table public.procurement_events enable row level security;
alter table public.procurement_events force row level security;
revoke all on public.procurement_events from public,anon,authenticated,service_role;
grant select on public.procurement_events to authenticated;
create policy procurement_read on public.procurement_events for select to authenticated using(public.has_company_role(company_id,'ACCOUNTING_ADMIN')or public.has_company_role(company_id,'ACCOUNTANT')or public.has_company_role(company_id,'PROCUREMENT')or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create trigger procurement_immutable before update or delete on public.procurement_events for each row execute function private.financial_evidence_immutable();

-- Compute exact cumulative clearing, leaving the rounding remainder to the last match.
create function private.inventory_match_basis(cid uuid,receipt_id uuid,qtext text,d date)returns jsonb
language plpgsql stable set search_path=''as $$
declare r public.inventory_events;q numeric;used numeric;cleared numeric;totalq numeric;totalv numeric;carrying numeric;
begin
 r:=private.inventory_current(cid,receipt_id);
 if r.id is null or r.state<>'POSTED'or r.snapshot->>'kind'<>'RECEIPT'or r.snapshot->>'recognition'<>'GRNI'or(r.snapshot->>'date')::date>d then raise exception 'PROC_RECEIPT: select a live earlier GRNI receipt'using errcode='23514';end if;
 if coalesce(qtext,'')!~'^[0-9]{1,16}$'then raise exception 'PROC_QUANTITY: exact base quantity required'using errcode='23514';end if;
 q:=qtext::numeric;totalq:=(r.snapshot->'computed'->>'qty')::numeric;totalv:=(r.snapshot->'computed'->>'value')::numeric;
 select coalesce(sum((e.snapshot->'computed'->>'qty')::numeric),0),coalesce(sum(coalesce(e.snapshot->'computed'->>'clearing_minor',e.snapshot->'computed'->>'value')::numeric),0)into used,cleared
 from public.inventory_events e where e.company_id=cid and e.state='POSTED'and e.snapshot->>'kind'in('MATCH','INVOICE')and e.snapshot->>'origin_id'=receipt_id::text and not exists(select 1 from public.inventory_events z where z.company_id=cid and z.document_id=e.document_id and z.state='REVERSED');
 if q<=0 or q+used>totalq then raise exception 'PROC_QUANTITY: exceeds uninvoiced received quantity'using errcode='23514';end if;
 carrying:=round(totalv*(used+q)/totalq)-cleared;
 if carrying<0 then raise exception 'PROC_VALUE: receipt clearing requires reconciliation'using errcode='23514';end if;
 return jsonb_build_object('qty',q::bigint::text,'clearing_minor',carrying::bigint::text,'remaining_micros',(totalq-used-q)::bigint::text);
end$$;
revoke all on function private.inventory_match_basis(uuid,uuid,text,date)from public,anon,authenticated,service_role;

-- Exact guarded forward edits to the existing canonical functions; preserve prior fiscal,
-- authorization, reversal, source, immutable-history and costing guards.
do $patch$
declare d text;old text;replacement text;
begin
 d:=pg_get_functiondef('private.inventory_plan(uuid,jsonb)'::regprocedure);
 old:='if exists(select 1 from public.inventory_events e where e.company_id=cid and e.state=''POSTED''and e.snapshot->>''kind''in(''MATCH'',''INVOICE'')and e.snapshot->>''origin_id''=origin.document_id::text and not exists(select 1 from public.inventory_events r where r.company_id=cid and r.document_id=e.document_id and r.state=''REVERSED''))then';
 if position(old in d)=0 then raise exception 'Unexpected canonical Inventory matching guard';end if;
 d:=replace(d,old,'if not(v ? ''match_quantity_micros'')and exists(select 1 from public.inventory_events e where e.company_id=cid and e.state=''POSTED''and e.snapshot->>''kind''in(''MATCH'',''INVOICE'')and e.snapshot->>''origin_id''=origin.document_id::text and not exists(select 1 from public.inventory_events r where r.company_id=cid and r.document_id=e.document_id and r.state=''REVERSED''))then');
 old:='qty:=(origin.snapshot->''computed''->>''qty'')::numeric;amount:=(origin.snapshot->''computed''->>''value'')::numeric;';
 if position(old in d)=0 then raise exception 'Unexpected receipt valuation';end if;
 d:=replace(d,old,old||'
   if v ? ''match_quantity_micros''then
    if kind<>''MATCH''then raise exception ''Partial quantity supported only for explicit invoice matching''using errcode=''23514'';end if;
    db:=private.inventory_match_basis(cid,origin.document_id,v->>''match_quantity_micros'',(v->>''date'')::date);
    qty:=(db->>''qty'')::numeric;
    if coalesce(v->>''value_minor'','''')!~''^[0-9]{1,16}$''then raise exception ''Exact invoice net required''using errcode=''23514'';end if;
    amount:=(v->>''value_minor'')::numeric;
    if amount<>(db->>''clearing_minor'')::numeric and (not public.has_company_role(cid,''ACCOUNTING_ADMIN'')or coalesce(length(btrim(v->>''variance_reason'')),0)<5)then raise exception ''PROC_VARIANCE: Accounting Admin reviewed reason required''using errcode=''42501'';end if;
   end if;');
 old:='''cost_project'',cost_project));';
 if position(old in d)=0 then raise exception 'Unexpected Inventory computed snapshot';end if;
 d:=replace(d,old,'''cost_project'',cost_project)||case when v ? ''match_quantity_micros''then jsonb_build_object(''clearing_minor'',db->>''clearing_minor'')else ''{}''::jsonb end);');
 execute d;
 d:=pg_get_functiondef('public.command_inventory(uuid,uuid,text,jsonb)'::regprocedure);
 old:='array[''cost_purpose'',''id''';if position(old in d)=0 then raise exception 'Unexpected Inventory input boundary';end if;
 d:=replace(d,old,'array[''match_quantity_micros'',''variance_reason'',''cost_purpose'',''id''');
 old:='if action in(''REVIEW'',''POST'',''REVERSE'',''CANCEL'')and';
 if position(old in d)=0 then raise exception 'Unexpected Inventory action boundary';end if;
 d:=replace(d,old,'if action=''SAVE''and(v ? ''match_quantity_micros''or v ? ''variance_reason'')and v->>''kind''is distinct from ''MATCH''then raise exception ''Invoice match fields require MATCH''using errcode=''22023'';end if;
 '||old);
 old:='lines:=jsonb_build_array(jsonb_build_object(''account_id'',cfg.grni_account_id,''debit_minor'',amount,''credit_minor'',0,''party_id'',original.snapshot->>''supplier_id''),jsonb_build_object(''account_id'',cost,''debit_minor'',0,''credit_minor'',amount,''project_id'',v->''computed''->>''cost_project''));';
 if position(old in d)=0 then raise exception 'Unexpected canonical matching journal';end if;
 replacement:='lines:=jsonb_build_array(jsonb_build_object(''account_id'',cfg.grni_account_id,''debit_minor'',coalesce(v->''computed''->>''clearing_minor'',amount::text),''credit_minor'',0,''party_id'',original.snapshot->>''supplier_id''),jsonb_build_object(''account_id'',cost,''debit_minor'',0,''credit_minor'',amount,''project_id'',v->''computed''->>''cost_project''));
    if v ? ''match_quantity_micros''and amount<>(v->''computed''->>''clearing_minor'')::bigint then
     lines:=lines||jsonb_build_array(jsonb_build_object(''account_id'',cfg.variance_account_id,''debit_minor'',greatest(amount-(v->''computed''->>''clearing_minor'')::bigint,0),''credit_minor'',greatest((v->''computed''->>''clearing_minor'')::bigint-amount,0)));
    end if;';
 d:=replace(d,old,replacement);execute d;
 d:=pg_get_functiondef('private.supplier_invoice_plan(uuid,jsonb)'::regprocedure);
 d:=replace(d,'array[''date'',''due_date''','array[''receipt_qty_micros'',''variance_reason'',''date'',''due_date''');
 old:='or(receipt.snapshot->''computed''->>''value'')::bigint<>net';
 if position(old in d)=0 then raise exception 'Unexpected AP receiving check';end if;
 d:=replace(d,old,'or(not(v ? ''receipt_qty_micros'')and(receipt.snapshot->''computed''->>''value'')::bigint<>net)');
 old:='select *into cfg from public.inventory_configuration where company_id=cid;cost:=cfg.grni_account_id;';
 d:=replace(d,old,old||'
 summary:=summary||private.inventory_match_basis(cid,receipt.document_id,coalesce(v->>''receipt_qty_micros'',receipt.snapshot->''computed''->>''qty''),d);
 if (summary->>''clearing_minor'')::bigint<>net and (not public.has_company_role(cid,''ACCOUNTING_ADMIN'')or coalesce(length(btrim(v->>''variance_reason'')),0)<5)then raise exception ''PROC_VARIANCE: Accounting Admin reviewed reason required''using errcode=''42501'';end if;');
 old:='''debit_minor'',net::text,''credit_minor'',''0''));';
 if position(old in d)=0 then raise exception 'Unexpected AP preview';end if;
 d:=replace(d,old,'''debit_minor'',coalesce(summary->>''clearing_minor'',net::text),''credit_minor'',''0''));
 if summary ? ''clearing_minor''and (summary->>''clearing_minor'')::bigint<>net then lines:=lines||jsonb_build_array(jsonb_build_object(''account_id'',cfg.variance_account_id,''debit_minor'',greatest(net-(summary->>''clearing_minor'')::bigint,0)::text,''credit_minor'',greatest((summary->>''clearing_minor'')::bigint-net,0)::text));end if;');
 execute d;
 d:=pg_get_functiondef('public.post_supplier_invoice(uuid,uuid,jsonb)'::regprocedure);
 old:='''qty_micros'',''0'',''unit'',old.snapshot->>''unit''';
 if position(old in d)=0 then raise exception 'Unexpected AP canonical match composition';end if;
 d:=replace(d,old,'''match_quantity_micros'',plan->>''qty'',''variance_reason'',coalesce(v->>''variance_reason'',''''),''qty_micros'',''0'',''unit'',old.snapshot->>''unit''');execute d;
end$patch$;

create function private.procurement_current(cid uuid,did uuid)returns public.procurement_events language sql stable set search_path=''as $$select e from public.procurement_events e where company_id=cid and document_id=did order by version desc limit 1$$;
create function private.procurement_plan(cid uuid,kind text,v jsonb,complete boolean)returns jsonb
language plpgsql set search_path=''as $$
declare p public.procurement_events;o public.purchase_order_events;ln jsonb;normalized jsonb;q jsonb;quotes jsonb:='[]';qs jsonb;doc jsonb;canonical jsonb;r public.inventory_events;
 used numeric;qty numeric;amount numeric;po_line jsonb;reqline jsonb;i integer;seen uuid[]:='{}';sid uuid;receipt_qty numeric;returned numeric;
begin
 if jsonb_typeof(v)is distinct from 'object'or octet_length(v::text)>55000 or coalesce(v->>'date','')!~'^\d{4}-\d{2}-\d{2}$'or(v->>'date')::date>current_date or coalesce(length(btrim(v->>'evidence')),0)not between 5 and 1000 then raise exception 'PROC_INPUT: actual date and supporting reference required'using errcode='23514';end if;
 if kind='REQUISITION'then
  if v-array['date','required_on','project_id','notes','lines','evidence']<>'{}'::jsonb then raise exception 'PROC_INPUT'using errcode='22023';end if;
  if jsonb_typeof(v->'lines')is distinct from 'array'then raise exception 'PROC_LINES'using errcode='23514';end if;
  select coalesce(jsonb_agg(x||jsonb_build_object('unit_price_minor','0')),'[]')into ln from jsonb_array_elements(v->'lines')x;
  normalized:=private.purchase_order_snapshot(cid,jsonb_build_object('date',v->>'date','delivery_on',v->>'required_on','project_id',v->>'project_id','notes',v->>'notes','lines',ln),false);
  if complete and(jsonb_array_length(ln)=0 or exists(select 1 from jsonb_array_elements(ln)x where coalesce(x->>'quantity_micros','0')::numeric<=0 or btrim(coalesce(x->>'description',''))=''or btrim(coalesce(x->>'unit',''))=''))then raise exception 'PROC_LINES: complete requested materials/quantities/units'using errcode='23514';end if;
  return jsonb_build_object('date',normalized->>'date','required_on',normalized->>'delivery_on','project_id',normalized->>'project_id','project_name',normalized->>'project_name','notes',normalized->>'notes','lines',normalized->'lines','evidence',v->>'evidence');
 elsif kind='RFQ'then
  if v-array['date','requisition_id','quotes','evidence']<>'{}'::jsonb then raise exception 'PROC_INPUT'using errcode='22023';end if;
  p:=private.procurement_current(cid,(v->>'requisition_id')::uuid);
  if p.id is null or p.kind<>'REQUISITION'or p.state<>'APPROVED'or(p.snapshot->>'date')::date>(v->>'date')::date then raise exception 'PROC_REQUISITION: approved same-Company requisition required'using errcode='23514';end if;
  if jsonb_typeof(v->'quotes')is distinct from 'array'or jsonb_array_length(v->'quotes')>20 or(complete and jsonb_array_length(v->'quotes')=0)then raise exception 'PROC_QUOTES: record actual quotations before review'using errcode='23514';end if;
  for q in select value from jsonb_array_elements(v->'quotes')loop
   if q-array['supplier_id','unit_prices','vat_bps','delivery_on','payment_terms','reference']<>'{}'::jsonb or jsonb_typeof(q->'unit_prices')is distinct from 'array'or jsonb_array_length(q->'unit_prices')<>jsonb_array_length(p.snapshot->'lines')or coalesce(q->>'vat_bps','')!~'^\d{1,5}$'or(q->>'vat_bps')::integer not between 0 and 10000 or coalesce(length(btrim(q->>'reference')),0)not between 1 and 100 or coalesce(length(btrim(q->>'payment_terms')),0)not between 1 and 1000 then raise exception 'PROC_QUOTES: comparable quantities, actual quote reference, tax and terms required'using errcode='23514';end if;
   sid:=(q->>'supplier_id')::uuid;if sid=any(seen)then raise exception 'PROC_DUPLICATE: one current quotation per Supplier'using errcode='23505';end if;seen:=array_append(seen,sid);
   select jsonb_agg((x-array['number','amount_minor'])||jsonb_build_object('material_id',coalesce(x->>'material_id',''),'unit_price_minor',q->'unit_prices'->>(ord-1)::integer)order by ord)into ln from jsonb_array_elements(p.snapshot->'lines')with ordinality a(x,ord);
   qs:=private.purchase_order_snapshot(cid,jsonb_build_object('date',v->>'date','delivery_on',q->>'delivery_on','supplier_id',sid,'project_id',p.snapshot->>'project_id','notes',q->>'payment_terms','lines',ln),complete);
   quotes:=quotes||jsonb_build_array(q||jsonb_build_object('supplier_name',qs->>'supplier_name','order',qs,'net_minor',qs->>'total_minor','quoted_vat_minor',round((qs->>'total_minor')::numeric*(q->>'vat_bps')::integer/10000)::bigint::text));
  end loop;
  return v||jsonb_build_object('quotes',quotes,'project_id',p.snapshot->>'project_id');
 elsif kind='RECEIPT'then
  if v-array['date','po_id','line_number','location_id','quantity_micros','reference','evidence']<>'{}'::jsonb then raise exception 'PROC_INPUT'using errcode='22023';end if;
  select *into o from public.purchase_order_events where company_id=cid and document_id=(v->>'po_id')::uuid order by version desc limit 1;
  if o.id is null or o.state<>'ISSUED'or(v->>'date')::date<(o.snapshot->>'date')::date then raise exception 'PROC_ORDER: issued same-Company order required'using errcode='23514';end if;
  if coalesce(length(btrim(v->>'reference')),0)not between 1 and 100 then raise exception 'PROC_REFERENCE: actual delivery reference required'using errcode='23514';end if;
  if coalesce(v->>'line_number','')!~'^\d{1,2}$'or coalesce(v->>'quantity_micros','')!~'^\d{1,16}$'then raise exception 'PROC_QUANTITY'using errcode='23514';end if;
  po_line:=o.snapshot->'lines'->((v->>'line_number')::integer-1);qty:=(v->>'quantity_micros')::numeric;
  if po_line is null or nullif(po_line->>'material_id','')is null or qty<=0 then raise exception 'PROC_MATERIAL: goods receipts require an ordered catalog Material'using errcode='23514';end if;
  select coalesce(sum((e.snapshot->>'quantity_micros')::numeric),0)into used from public.procurement_events e where e.company_id=cid and e.kind='RECEIPT'and e.state='EXECUTED'and e.snapshot->>'po_id'=o.document_id::text and e.snapshot->>'line_number'=v->>'line_number'and(private.inventory_current(cid,(e.result->>'inventory_id')::uuid)).state='POSTED';
  if used+qty>(po_line->>'quantity_micros')::numeric then raise exception 'PROC_QUANTITY: receipt exceeds outstanding ordered quantity'using errcode='23514';end if;
  amount:=round((po_line->>'amount_minor')::numeric*(used+qty)/(po_line->>'quantity_micros')::numeric)-round((po_line->>'amount_minor')::numeric*used/(po_line->>'quantity_micros')::numeric);
  canonical:=jsonb_build_object('kind','RECEIPT','date',v->>'date','material_id',po_line->>'material_id','location_id',v->>'location_id','qty_micros',qty::bigint::text,'unit',po_line->>'unit','value_minor',amount::bigint::text,'recognition','GRNI','supplier_id',o.snapshot->>'supplier_id','project_id',o.snapshot->>'project_id','not_previously_recognized',true,'source_reference',btrim(v->>'reference'),'evidence',v->>'evidence');
  doc:=private.inventory_plan(cid,canonical);
  if nullif(o.snapshot->>'project_id','')::uuid is distinct from nullif(doc->'computed'->>'project','')::uuid then raise exception 'PROC_PROJECT: receipt warehouse must agree with order Project'using errcode='23514';end if;
  return v||jsonb_build_object('canonical',canonical,'value_minor',amount::bigint::text,'supplier_id',o.snapshot->>'supplier_id','project_id',o.snapshot->>'project_id','material_name',po_line->>'description','unit',po_line->>'unit');
 elsif kind='INVOICE'then
  if v-array['date','receipt_id','quantity_micros','net_minor','vat_mode','vat_minor','has_tax_invoice','invoice_number','category_id','due_date','variance_reason','evidence']<>'{}'::jsonb then raise exception 'PROC_INPUT'using errcode='22023';end if;
  p:=private.procurement_current(cid,(v->>'receipt_id')::uuid);
  if p.id is null or p.kind<>'RECEIPT'or p.state<>'EXECUTED'then raise exception 'PROC_RECEIPT: receipt-first policy requires an executed procurement receipt'using errcode='23514';end if;
  r:=private.inventory_current(cid,(p.result->>'inventory_id')::uuid);
  canonical:=jsonb_build_object('date',v->>'date','due_date',v->>'due_date','supplier_id',r.snapshot->>'supplier_id','project_id',p.snapshot->>'project_id','category_id',v->>'category_id','description',v->>'evidence','net_minor',v->>'net_minor','vat_mode',v->>'vat_mode','vat_minor',coalesce(v->>'vat_minor','0'),'has_tax_invoice',coalesce((v->>'has_tax_invoice')::boolean,false),'invoice_number',v->>'invoice_number','funding_mode','SUPPLIER_CREDIT','receipt_id',r.document_id,'receipt_qty_micros',v->>'quantity_micros','variance_reason',coalesce(v->>'variance_reason',''),'purchase_kind','INVENTORY','notes','Procurement '||p.reference);
  -- Canonical AP validation authorizes, checks tax, duplicate invoice, periods and qty.
  doc:=private.supplier_invoice_plan(cid,canonical);
  return v||jsonb_build_object('canonical',canonical,'preview',doc,'po_id',p.snapshot->>'po_id','line_number',p.snapshot->>'line_number','supplier_id',r.snapshot->>'supplier_id');
 end if;
 raise exception 'PROC_KIND'using errcode='22023';
end$$;

create function public.command_procurement(cid uuid,request_id uuid,action text,input jsonb)returns jsonb
language plpgsql security definer set search_path=''as $$
#variable_conflict use_variable
declare actor uuid:=auth.uid();old public.procurement_events;prior public.procurement_events;kind text;did uuid;expected integer;h text;v jsonb;plan jsonb;next_state text;ref text;res jsonb;r jsonb;q jsonb;po jsonb;lines jsonb;approver boolean;reqid uuid;inv public.inventory_events;ex public.expenses;
begin
 if actor is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'PROCUREMENT'))then raise exception 'PROC_DENIED'using errcode='42501';end if;
 if request_id is null or action is null or action not in('SAVE','SUBMIT','REVIEW','APPROVE','REJECT','CANCEL','SELECT','ORDER','EXECUTE','REVERSE')or jsonb_typeof(input)is distinct from 'object'or octet_length(input::text)>60000 then raise exception 'PROC_INPUT'using errcode='22023';end if;
 perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 perform 1 from public.company_memberships m join public.profiles p on p.user_id=m.user_id join public.companies c on c.id=m.company_id where m.company_id=cid and m.user_id=actor and m.status='ACTIVE'and p.status='ACTIVE'and c.status='ACTIVE'and m.role in('ACCOUNTING_ADMIN','ACCOUNTANT','PROCUREMENT')for share of m,p,c;
 if not found then raise exception 'PROC_DENIED'using errcode='42501';end if;
 h:=encode(sha256(convert_to(jsonb_build_array(actor,action,input)::text,'UTF8')),'hex');
 select *into prior from public.procurement_events e where e.company_id=cid and e.request_id=command_procurement.request_id;
 if found then if prior.request_hash<>h then raise exception 'PROC_REPLAY'using errcode='22023';end if;return jsonb_build_object('id',prior.document_id,'version',prior.version,'state',prior.state,'reference',prior.reference,'result',prior.result,'replayed',true);end if;
 did:=(input->>'id')::uuid;expected:=(input->>'version')::integer;
 if did is null or expected is null or expected<0 then raise exception 'PROC_VERSION'using errcode='22023';end if;
 old:=private.procurement_current(cid,did);
 if expected<>coalesce(old.version,0)then raise exception 'PROC_STALE'using errcode='40001';end if;
 kind:=coalesce(old.kind,input->>'kind');
 if kind not in('REQUISITION','RFQ','RECEIPT','INVOICE')or kind is null or(input ? 'kind'and input->>'kind'<>kind)then raise exception 'PROC_KIND'using errcode='22023';end if;
 approver:=(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT'))and public.has_permission(cid,'accounting.post');
 if kind='INVOICE'and not approver then raise exception 'PROC_DENIED'using errcode='42501';end if;
 if action in('APPROVE','SELECT','ORDER','EXECUTE','REJECT','CANCEL','REVERSE')and not approver then raise exception 'PROC_APPROVAL'using errcode='42501';end if;
 if old.state in('CANCELLED','REJECTED','REVERSED')or(old.state='EXECUTED'and action<>'REVERSE')then raise exception 'PROC_IMMUTABLE'using errcode='23514';end if;
 if action<>'SAVE'and input-array['id','version','reason','supplier_id','unit_prices']<>'{}'::jsonb then raise exception 'PROC_INPUT'using errcode='22023';end if;
 if action='SAVE'then
  if old.state is not null and old.state not in('DRAFT','SUBMITTED','REVIEWED')then raise exception 'PROC_STATE'using errcode='23514';end if;
  if not(private.company_commercial_readiness(cid)->>'ready')::boolean then raise exception 'PROC_SETUP'using errcode='42501';end if;
  v:=input-array['id','version','kind'];plan:=private.procurement_plan(cid,kind,v,false);
  if kind='RFQ'and exists(select 1 from public.procurement_events e where e.company_id=cid and e.kind='RFQ'and e.document_id<>did and e.snapshot->>'requisition_id'=v->>'requisition_id'and(private.procurement_current(cid,e.document_id)).state not in('CANCELLED','REJECTED'))then raise exception 'PROC_DUPLICATE: requisition already has an RFQ'using errcode='23505';end if;
  next_state:='DRAFT';
 else
  if old.id is null then raise exception 'PROC_STATE'using errcode='23514';end if;v:=old.snapshot;ref:=old.reference;
  if action in('CANCEL','REJECT')then
   if old.state in('EXECUTED','APPROVED')and(kind<>'REQUISITION'or exists(select 1 from public.procurement_events e where e.company_id=cid and e.snapshot->>'requisition_id'=did::text and(private.procurement_current(cid,e.document_id)).state not in('CANCELLED','REJECTED')))then raise exception 'PROC_DEPENDENCY: dependent procurement exists'using errcode='23514';end if;
   if coalesce(length(btrim(input->>'reason')),0)not between 5 and 1000 then raise exception 'PROC_REASON'using errcode='23514';end if;
   v:=v||jsonb_build_object('resolution_reason',input->>'reason');next_state:=case action when 'CANCEL'then 'CANCELLED'else 'REJECTED'end;
  elsif action='REVERSE'then
   if old.state<>'EXECUTED'or kind not in('RECEIPT','INVOICE')or not public.has_company_role(cid,'ACCOUNTING_ADMIN')or coalesce(length(btrim(input->>'reason')),0)<5 then raise exception 'PROC_REVERSAL'using errcode='42501';end if;
   if kind='RECEIPT'then
    inv:=private.inventory_current(cid,(old.result->>'inventory_id')::uuid);
    r:=public.command_inventory(cid,gen_random_uuid(),'REVERSE',jsonb_build_object('id',inv.document_id,'version',inv.version,'evidence',input->>'reason'));
   else
    inv:=private.inventory_current(cid,(old.result->>'inventory_document')::uuid);
    r:=public.command_inventory(cid,gen_random_uuid(),'REVERSE',jsonb_build_object('id',inv.document_id,'version',inv.version,'evidence',input->>'reason'));
    select *into ex from public.expenses where company_id=cid and id=(old.result->>'id')::uuid;
    -- Canonical expense reversal enforces AP allocations, credits and fiscal dependencies.
    perform public.reverse_expense(cid,ex.id,current_date,input->>'reason',gen_random_uuid());
   end if;
   v:=v||jsonb_build_object('resolution_reason',input->>'reason');res:=old.result;next_state:='REVERSED';
  else
   plan:=private.procurement_plan(cid,kind,v,true);
   if action='SUBMIT'then
    if kind<>'REQUISITION'or old.state<>'DRAFT'then raise exception 'PROC_STATE'using errcode='23514';end if;next_state:='SUBMITTED';
   elsif action='REVIEW'then
    if old.state is distinct from (case when kind='REQUISITION'then 'SUBMITTED'else 'DRAFT'end)then raise exception 'PROC_STATE'using errcode='23514';end if;next_state:='REVIEWED';
   elsif action='APPROVE'then
    if kind<>'REQUISITION'or old.state<>'REVIEWED'then raise exception 'PROC_STATE'using errcode='23514';end if;next_state:='APPROVED';
   elsif action in('SELECT','ORDER')then
    if(action='SELECT'and(kind<>'RFQ'or old.state<>'REVIEWED'))or(action='ORDER'and(kind<>'REQUISITION'or old.state<>'APPROVED'))then raise exception 'PROC_STATE'using errcode='23514';end if;
    reqid:=case when kind='RFQ'then(v->>'requisition_id')::uuid else did end;
    if exists(select 1 from public.procurement_events e where e.company_id=cid and e.result->>'requisition_id'=reqid::text and e.result ? 'po_id')then raise exception 'PROC_DUPLICATE: requisition already converted'using errcode='23505';end if;
    if kind='RFQ'then
     if coalesce(length(btrim(input->>'reason')),0)<5 then raise exception 'PROC_REASON: document Supplier selection'using errcode='23514';end if;
     select x into q from jsonb_array_elements(plan->'quotes')x where x->>'supplier_id'=input->>'supplier_id';
     if q is null then raise exception 'PROC_QUOTES: select a reviewed Supplier quotation'using errcode='23514';end if;
     po:=q->'order';res:=jsonb_build_object('selected_supplier_id',input->>'supplier_id','selection_reason',input->>'reason','quoted_vat_bps',q->>'vat_bps','quotation_reference',q->>'reference');
    else
     if jsonb_typeof(input->'unit_prices')is distinct from 'array'or jsonb_array_length(input->'unit_prices')<>jsonb_array_length(v->'lines')then raise exception 'PROC_LINES'using errcode='23514';end if;
     select jsonb_agg((x-array['number','amount_minor'])||jsonb_build_object('material_id',coalesce(x->>'material_id',''),'unit_price_minor',input->'unit_prices'->>(ord-1)::integer)order by ord)into lines from jsonb_array_elements(v->'lines')with ordinality a(x,ord);
     po:=private.purchase_order_snapshot(cid,jsonb_build_object('date',v->>'date','delivery_on',v->>'required_on','supplier_id',input->>'supplier_id','project_id',v->>'project_id','notes',v->>'notes','lines',lines),true);
    end if;
    select jsonb_agg((x-array['number','amount_minor'])||jsonb_build_object('material_id',coalesce(x->>'material_id','')))into lines from jsonb_array_elements(po->'lines')x;
    r:=public.command_purchase_order(cid,gen_random_uuid(),'SAVE',(po-array['supplier_name','project_name','total_minor','currency','amount_basis'])||jsonb_build_object('id',gen_random_uuid(),'version','0','lines',lines));
    res:=coalesce(res,'{}')||jsonb_build_object('po_id',r->>'id','po_reference',r->>'reference','requisition_id',reqid);next_state:='EXECUTED';
   elsif action='EXECUTE'then
    if old.state<>'REVIEWED'or kind not in('RECEIPT','INVOICE')then raise exception 'PROC_STATE'using errcode='23514';end if;
    if kind='RECEIPT'then
     r:=public.command_inventory(cid,gen_random_uuid(),'SAVE',(plan->'canonical')||jsonb_build_object('id',gen_random_uuid(),'version','0'));
     r:=public.command_inventory(cid,gen_random_uuid(),'REVIEW',jsonb_build_object('id',r->>'document_id','version',r->>'version','evidence',v->>'evidence'));
     r:=public.command_inventory(cid,gen_random_uuid(),'POST',jsonb_build_object('id',r->>'document_id','version',r->>'version','evidence',v->>'evidence'));
     res:=jsonb_build_object('inventory_id',r->>'document_id','journal_id',r->>'journal_id');
    else
     res:=public.post_supplier_invoice(cid,gen_random_uuid(),plan->'canonical');
    end if;next_state:='EXECUTED';
   else raise exception 'PROC_STATE'using errcode='23514';end if;
  end if;
 end if;
 ref:=coalesce(ref,private.allocate_reference(cid,case kind when 'REQUISITION'then 'PR'when 'RFQ'then 'RFQ'when 'RECEIPT'then 'GR'else 'PI'end,extract(year from(v->>'date')::date)::integer));
 insert into public.procurement_events(company_id,document_id,version,request_id,request_hash,kind,state,action,reference,snapshot,result,created_by)values(cid,did,expected+1,request_id,h,kind,next_state,action,ref,v,res,actor);
 return jsonb_build_object('id',did,'version',expected+1,'state',next_state,'reference',ref,'result',res,'replayed',false);
end$$;

-- Existing purchase returns must credit only the invoice's matched quantity, rather
-- than treating each partial invoice as covering the entire original receiving.
do $patch$declare d text;old text;begin
 d:=pg_get_functiondef('private.supplier_return_plan(uuid,text,jsonb)'::regprocedure);
 old:='q:=(v->>''qty_micros'')::bigint;origq:=(r.snapshot->''computed''->>''qty'')::bigint;';
 if position(old in d)=0 then raise exception 'Unexpected physical return quantity guard';end if;
 d:=replace(d,old,old||'
 if r.snapshot->>''recognition''=''GRNI''and q+coalesce((select sum((rt.snapshot->>''qty_micros'')::numeric)from public.inventory_events rt where rt.company_id=cid and rt.state=''POSTED''and rt.snapshot->>''kind''=''PURCHASE_RETURN''and rt.snapshot->>''origin_id''=r.document_id::text and rt.snapshot->>''expense_id''=ex.id::text and not exists(select 1 from public.inventory_events z where z.company_id=cid and z.document_id=rt.document_id and z.state=''REVERSED'')),0)>(select coalesce(sum((m.snapshot->''computed''->>''qty'')::numeric),0)from public.inventory_events m where m.company_id=cid and m.state=''POSTED''and m.snapshot->>''kind''in(''MATCH'',''INVOICE'')and m.snapshot->>''origin_id''=r.document_id::text and m.snapshot->>''expense_id''=ex.id::text and not exists(select 1 from public.inventory_events z where z.company_id=cid and z.document_id=m.document_id and z.state=''REVERSED''))then raise exception ''Return exceeds quantity matched to selected Supplier invoice''using errcode=''23514'';end if;');
 old:='origq:=(r.snapshot->''computed''->>''qty'')::bigint;q:=(e.snapshot->>''qty_micros'')::bigint;';
 if position(old in d)=0 then raise exception 'Unexpected credit quantity basis';end if;
 d:=replace(d,old,'origq:=case when r.snapshot->>''recognition''=''GRNI''then(select sum((m.snapshot->''computed''->>''qty'')::bigint)from public.inventory_events m where m.company_id=cid and m.state=''POSTED''and m.snapshot->>''kind''in(''MATCH'',''INVOICE'')and m.snapshot->>''origin_id''=r.document_id::text and m.snapshot->>''expense_id''=ex.id::text and not exists(select 1 from public.inventory_events z where z.company_id=cid and z.document_id=m.document_id and z.state=''REVERSED''))else(r.snapshot->''computed''->>''qty'')::bigint end;q:=(e.snapshot->>''qty_micros'')::bigint;');
 old:='and p.snapshot->>''origin_id''=r.document_id::text and d.status=''POSTED''';
 if position(old in d)=0 then raise exception 'Unexpected cumulative credit basis';end if;
 d:=replace(d,old,old||'and p.snapshot->>''expense_id''=ex.id::text');execute d;
 -- Include every partial invoice as a selectable canonical return basis.
 d:=pg_get_functiondef('public.read_supplier_returns(uuid)'::regprocedure);
 d:=replace(d,'order by m.created_at limit 1','order by m.created_at');execute d;
end$patch$;
create function private.guard_procurement_order()returns trigger language plpgsql security definer set search_path=''as $$begin
 if new.state='CANCELLED'and exists(select 1 from public.procurement_events e where e.company_id=new.company_id and e.kind='RECEIPT'and e.state='EXECUTED'and e.snapshot->>'po_id'=new.document_id::text and(private.inventory_current(new.company_id,(e.result->>'inventory_id')::uuid)).state='POSTED')then raise exception 'PROC_DEPENDENCY: reverse live receipts before cancelling order'using errcode='23514';end if;return new;
end$$;
create trigger purchase_order_fulfillment_guard before insert on public.purchase_order_events for each row execute function private.guard_procurement_order();

create function public.preview_procurement(cid uuid,kind text,input jsonb)returns jsonb language plpgsql security definer set search_path=''as $$
declare plan jsonb;cfg public.inventory_configuration;begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'PROCUREMENT'))or(kind='INVOICE'and not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')))then raise exception 'PROC_DENIED'using errcode='42501';end if;
 perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 plan:=private.procurement_plan(cid,kind,input,true);
 if kind='RECEIPT'then select *into cfg from public.inventory_configuration where company_id=cid;plan:=plan||jsonb_build_object('preview',jsonb_build_object('lines',jsonb_build_array(jsonb_build_object('account_id',cfg.inventory_account_id,'debit_minor',plan->>'value_minor','credit_minor','0'),jsonb_build_object('account_id',cfg.grni_account_id,'debit_minor','0','credit_minor',plan->>'value_minor'))));end if;
 return jsonb_build_object('company_id',cid)||plan;end$$;

create function public.read_procurement(cid uuid,page_offset integer default 0,page_size integer default 50)returns jsonb language plpgsql stable security definer set search_path=''as $$
declare result jsonb;begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'PROCUREMENT')or public.has_company_role(cid,'MANAGEMENT_VIEWER'))then raise exception 'PROC_DENIED'using errcode='42501';end if;
 if page_offset is null or page_offset<0 or page_size is null or page_size not between 1 and 100 then raise exception 'PROC_PAGE'using errcode='22023';end if;
 with latest as(select distinct on(document_id)*from public.procurement_events where company_id=cid order by document_id,version desc),
 orders as(select distinct on(document_id)*from public.purchase_order_events where company_id=cid order by document_id,version desc),
 progress as(select o.document_id po_id,o.reference,o.snapshot->>'supplier_id'supplier_id,o.snapshot->>'supplier_name'supplier_name,(x.ord)::text line_number,x.l->>'description'description,x.l->>'unit'unit,x.l->>'quantity_micros'ordered_micros,x.l->>'amount_minor'ordered_minor,
 coalesce(sum((r.snapshot->>'quantity_micros')::numeric),0)::text received_micros,
 coalesce(sum((select coalesce(sum((m.snapshot->'computed'->>'qty')::numeric),0)from public.inventory_events m where m.company_id=cid and m.state='POSTED'and m.snapshot->>'kind'in('MATCH','INVOICE')and m.snapshot->>'origin_id'=r.result->>'inventory_id'and not exists(select 1 from public.inventory_events z where z.company_id=cid and z.document_id=m.document_id and z.state='REVERSED'))),0)::text invoiced_micros,
 coalesce(sum((select coalesce(sum((m.snapshot->>'qty_micros')::numeric),0)from public.inventory_events m where m.company_id=cid and m.state='POSTED'and m.snapshot->>'kind'='PURCHASE_RETURN'and m.snapshot->>'origin_id'=r.result->>'inventory_id'and not exists(select 1 from public.inventory_events z where z.company_id=cid and z.document_id=m.document_id and z.state='REVERSED'))),0)::text returned_micros
 from orders o cross join lateral jsonb_array_elements(o.snapshot->'lines')with ordinality x(l,ord)
 left join latest r on r.kind='RECEIPT'and r.state='EXECUTED'and r.snapshot->>'po_id'=o.document_id::text and r.snapshot->>'line_number'=x.ord::text and(private.inventory_current(cid,(r.result->>'inventory_id')::uuid)).state='POSTED'
 where o.state='ISSUED'group by o.document_id,o.reference,o.snapshot,x.ord,x.l)
 select jsonb_build_object('company_id',cid,'today',current_date,'can_edit',not public.has_company_role(cid,'MANAGEMENT_VIEWER'),'can_approve',(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT'))and public.has_permission(cid,'accounting.post'),'can_reverse',public.has_company_role(cid,'ACCOUNTING_ADMIN')and public.has_permission(cid,'accounting.reverse'),
 'count',(select count(*)from latest),'documents',(select coalesce(jsonb_agg(to_jsonb(d)||jsonb_build_object('effective_state',case
 when d.state='EXECUTED'and d.kind='RECEIPT'then case when(private.inventory_current(cid,(d.result->>'inventory_id')::uuid)).state='POSTED'then 'EXECUTED'else 'REVERSED'end
 when d.state='EXECUTED'and d.kind='INVOICE'then case when exists(select 1 from public.expenses x where x.company_id=cid and x.id=(d.result->>'id')::uuid and x.status='REVERSED')then 'REVERSED'when(private.inventory_current(cid,(d.result->>'inventory_document')::uuid)).state='POSTED'then 'EXECUTED'else 'NEEDS_REVIEW'end else d.state end)order by created_at desc,document_id),'[]')from(select *from latest order by created_at desc,document_id offset page_offset limit page_size)d),
 'requisitions',(select coalesce(jsonb_agg(to_jsonb(d)order by reference),'[]')from latest d where kind='REQUISITION'and state='APPROVED'and not exists(select 1 from public.procurement_events e where e.company_id=cid and e.result->>'requisition_id'=d.document_id::text and e.result ? 'po_id')),
 'orders',(select coalesce(jsonb_agg(to_jsonb(o)order by reference),'[]')from orders o where state='ISSUED'),
 'receipts',(select coalesce(jsonb_agg(to_jsonb(d)order by reference),'[]')from latest d where kind='RECEIPT'and state='EXECUTED'and(private.inventory_current(cid,(d.result->>'inventory_id')::uuid)).state='POSTED'),
 'progress',(select coalesce(jsonb_agg(to_jsonb(p)||jsonb_build_object('remaining_receive_micros',((ordered_micros::numeric)-(received_micros::numeric))::text,'remaining_invoice_micros',((received_micros::numeric)-(invoiced_micros::numeric))::text,'remaining_commitment_minor',round(ordered_minor::numeric*(ordered_micros::numeric-received_micros::numeric)/ordered_micros::numeric)::text)order by reference,line_number),'[]')from progress p),
 'requisition_progress',(select coalesce(jsonb_agg(jsonb_build_object('reference',r.reference,'state',r.state,'description',x.l->>'description','unit',x.l->>'unit','requested_micros',x.l->>'quantity_micros','approved_micros',case when r.state in('APPROVED','EXECUTED')then x.l->>'quantity_micros'else '0'end)order by r.reference,x.ord),'[]')from latest r cross join lateral jsonb_array_elements(r.snapshot->'lines')with ordinality x(l,ord)where r.kind='REQUISITION'),
 'supplier_history',(select coalesce(jsonb_agg(to_jsonb(s)order by supplier_id),'[]')from(select o.snapshot->>'supplier_id'supplier_id,count(*)::integer recorded_receipts,count(*)filter(where o.snapshot->>'delivery_on'is not null)::integer dated_receipts,count(*)filter(where o.snapshot->>'delivery_on'is not null and(r.snapshot->>'date')::date<=(o.snapshot->>'delivery_on')::date)::integer on_time_receipts from latest r join orders o on o.document_id=(r.snapshot->>'po_id')::uuid where r.kind='RECEIPT'and r.state='EXECUTED'and(private.inventory_current(cid,(r.result->>'inventory_id')::uuid)).state='POSTED'group by o.snapshot->>'supplier_id')s),
 'suppliers',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name)order by name),'[]')from public.parties where company_id=cid and type='SUPPLIER'and status='ACTIVE'),
 'projects',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name)order by name),'[]')from public.projects where company_id=cid and status='ACTIVE'),
 'materials',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'unit',base_unit)order by name),'[]')from public.inventory_materials where company_id=cid and active),
 'locations',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'project_id',project_id)order by name),'[]')from public.inventory_locations where company_id=cid and active),
 'categories',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name)order by name),'[]')from public.expense_categories where company_id=cid and status='ACTIVE'),
 'accounts',case when public.has_company_role(cid,'PROCUREMENT')then '[]'::jsonb else(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'code',code)order by code),'[]')from public.accounts where company_id=cid)end)into result;
 return result;
end$$;
create function public.read_procurement_history(cid uuid,did uuid)returns jsonb language plpgsql stable security definer set search_path=''as $$begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'PROCUREMENT')or public.has_company_role(cid,'MANAGEMENT_VIEWER'))then raise exception 'PROC_DENIED'using errcode='42501';end if;
 return(select coalesce(jsonb_agg(jsonb_build_object('version',version,'state',state,'action',action,'actor',created_by,'at',created_at,'reason',coalesce(result->>'selection_reason',snapshot->>'resolution_reason'))order by version),'[]')from public.procurement_events where company_id=cid and document_id=did);
end$$;
revoke all on function private.procurement_current(uuid,uuid),private.procurement_plan(uuid,text,jsonb,boolean),private.guard_procurement_order(),public.command_procurement(uuid,uuid,text,jsonb),public.preview_procurement(uuid,text,jsonb),public.read_procurement(uuid,integer,integer),public.read_procurement_history(uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.command_procurement(uuid,uuid,text,jsonb),public.preview_procurement(uuid,text,jsonb),public.read_procurement(uuid,integer,integer),public.read_procurement_history(uuid,uuid)to authenticated;
