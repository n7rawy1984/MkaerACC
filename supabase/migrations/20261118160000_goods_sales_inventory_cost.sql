-- 100: Reuse canonical Inventory ISSUE/RETURN for sales COGS; link AR without reposting stock cost.
-- One material issue per goods invoice, immutable source links; no Company seed or financial backfill.
alter table public.commercial_documents add column stock_event_id uuid,add column return_event_id uuid,
 add foreign key(company_id,stock_event_id)references public.inventory_events(company_id,id)on delete restrict,
 add foreign key(company_id,return_event_id)references public.inventory_events(company_id,id)on delete restrict;
create unique index commercial_stock_issue_once on public.commercial_documents(company_id,stock_event_id)where stock_event_id is not null;
create unique index commercial_stock_return_once on public.commercial_documents(company_id,return_event_id)where return_event_id is not null;
create or replace function private.commercial_control_type(k text)returns text language sql immutable set search_path='' as $$
 select case when k in('AR','ASSET_COST','ACCUMULATED_DEPRECIATION','PREPAYMENT')then 'ASSET'
 when k in('CUSTOMER_ADVANCE','OUTPUT_VAT','ACCRUED_LIABILITY')then 'LIABILITY'
 when k in('REVENUE','DISPOSAL_GAIN')then 'REVENUE'
 when k in('COGS','DEPRECIATION_EXPENSE','DISPOSAL_LOSS','ACCRUAL_EXPENSE')then 'EXPENSE'when k='RETAINED_EARNINGS'then 'EQUITY'end;
$$;
create or replace function private.inventory_plan(cid uuid,v jsonb)returns jsonb language plpgsql set search_path=''as $$
#variable_conflict use_column
declare cfg public.inventory_configuration;m public.inventory_materials;l public.inventory_locations;dest public.inventory_locations;
 origin public.inventory_events;origin_post public.inventory_events;ex public.expenses;qty numeric;amount numeric:=0;b jsonb;db jsonb;r numeric;n numeric;kind text:=v->>'kind';mode text;project uuid;cost uuid;cost_project uuid;returned numeric;original_qty numeric;original_value numeric;prior_value numeric;
begin
 select *into cfg from public.inventory_configuration where company_id=cid;if not found then raise exception 'Inventory accounting setup required'using errcode='23514';end if;
 if kind is null or kind not in('RECEIPT','ISSUE','TRANSFER','RETURN','COUNT','ADJUSTMENT','OPENING','MATCH','INVOICE')or coalesce(length(btrim(v->>'source_reference')),0)not between 1 and 200 or coalesce(length(btrim(v->>'evidence')),0)not between 5 and 1000 then raise exception 'Document type, actual source and receiving/consumption/valuation evidence required'using errcode='23514';end if;
 if coalesce(v->>'date','')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'or(v->>'date')::date>current_date or date_trunc('month',(v->>'date')::date)<>date_trunc('month',current_date)then raise exception 'Current-period chronological document date required'using errcode='23514';end if;
 perform private.check_source_allocation_period(cid,(v->>'date')::date);
 select *into m from public.inventory_materials where company_id=cid and id=(v->>'material_id')::uuid;
 select *into l from public.inventory_locations where company_id=cid and id=(v->>'location_id')::uuid;
 if m.id is null or l.id is null or(kind not in('RETURN','COUNT','ADJUSTMENT','MATCH','INVOICE')and(not m.active or not l.active))then raise exception 'Available same-Company material and warehouse required'using errcode='23514';end if;
 if l.project_id is not null then perform 1 from public.projects where company_id=cid and id=l.project_id for share;end if;
 if l.project_id is not null and kind in('RECEIPT','ISSUE','OPENING')and not exists(select 1 from public.projects where company_id=cid and id=l.project_id and status='ACTIVE')then raise exception 'Active warehouse Project required for new movements'using errcode='23514';end if;
 if coalesce(v->>'qty_micros','')!~'^[0-9]{1,16}$'then raise exception 'Exact positive quantity required'using errcode='22023';end if;qty:=(v->>'qty_micros')::numeric;
 if coalesce(v->>'unit',m.base_unit)<>m.base_unit then
  if m.conversions->(v->>'unit')is null then raise exception 'Approved unit conversion required'using errcode='23514';end if;
  qty:=qty*(m.conversions->(v->>'unit')->>'numerator')::numeric/(m.conversions->(v->>'unit')->>'denominator')::numeric;
 end if;
 if qty<>trunc(qty)or qty<0 or qty>9000000000000000 or(qty=0 and kind not in('COUNT','MATCH','INVOICE','ADJUSTMENT'))then raise exception 'Quantity must convert exactly to base micro-units'using errcode='23514';end if;
 b:=private.inventory_balance(cid,m.id,l.id);if(b->>'qty')::numeric<0 or(b->>'value')::numeric<0 then raise exception 'Inventory reconciliation required'using errcode='23514';end if;
 if kind<>'MATCH'and(b->>'last_date')::date>(v->>'date')::date then raise exception 'Backdated valuation would rewrite moving-average history'using errcode='23514';end if;
 project:=nullif(v->>'project_id','')::uuid;
 if kind='ISSUE'then
  if(project is not null and not exists(select 1 from public.projects where company_id=cid and id=project and status='ACTIVE'))or(l.project_id is not null and l.project_id is distinct from project)then raise exception 'Active consistent consumption Project required'using errcode='23514';end if;
  if not exists(select 1 from public.parties where company_id=cid and id=(v->>'recipient_id')::uuid and status='ACTIVE')then raise exception 'Actual same-Company recipient required; recipient receives no posting permission'using errcode='23514';end if;
 end if;
 if kind in('ISSUE','TRANSFER')then
  if qty>(b->>'qty')::numeric then raise exception 'Insufficient available stock'using errcode='23514';end if;
  amount:=case when qty=(b->>'qty')::numeric then(b->>'value')::numeric else round((b->>'value')::numeric*qty/(b->>'qty')::numeric)end;
 elsif kind in('RECEIPT','OPENING')then
  if coalesce(v->>'value_minor','')!~'^[0-9]{1,16}$'then raise exception 'Supported exact net stock valuation required'using errcode='23514';end if;amount:=(v->>'value_minor')::numeric;
  mode:=v->>'recognition';
  if kind='OPENING'then
   if(b->>'revision')::bigint<>0 or v->>'physically_counted' is distinct from 'true'or v->>'not_previously_recognized' is distinct from 'true'or nullif(v->>'expense_id','')is not null or nullif(v->>'source_id','')is not null then raise exception 'Opening requires initial physical count, independently supported value and explicitly unrecognized stock; posted historical costs cannot be opened again'using errcode='23514';end if;
  elsif mode not in('GRNI','EXISTING_EXPENSE')or mode is null then raise exception 'Select accrued receipt or explicitly approved current Expense capitalization'using errcode='23514';end if;
  if kind='RECEIPT'and mode='GRNI'and not exists(select 1 from public.parties where company_id=cid and id=(v->>'supplier_id')::uuid and type='SUPPLIER'and status='ACTIVE')then raise exception 'Same-Company actual Supplier required'using errcode='23514';end if;
 end if;
 if nullif(v->>'source_id','')is not null then
  if not exists(select 1 from public.historical_source_records where company_id=cid and id=(v->>'source_id')::uuid)then raise exception 'Same-Company original source required'using errcode='42501';end if;
  if kind='RECEIPT'and mode='GRNI'and exists(select 1 from public.historical_source_records where company_id=cid and id=(v->>'source_id')::uuid and(expense_id is not null or payroll_entitlement_id is not null or expense_allocation_id is not null or private.reclassification_origin(cid,id)is not null or exists(select 1 from private.financial_command_requests q where q.company_id=cid and q.idempotency_key=historical_source_records.id and q.command_type='POST_EXPENSE'and q.status='COMPLETED')))then raise exception 'Posted source cannot create another accrued receipt; link history or use eligible explicit capitalization'using errcode='23514';end if;
  if kind='RECEIPT'and exists(select 1 from public.inventory_events e where e.company_id=cid and e.state='POSTED'and e.snapshot->>'kind'='RECEIPT'and e.snapshot->>'source_id'=v->>'source_id'and not exists(select 1 from public.inventory_events r where r.company_id=cid and r.document_id=e.document_id and r.state='REVERSED'))then raise exception 'Original purchase source already received; reference changes cannot duplicate stock'using errcode='23505';end if;
  if nullif(v->>'expense_id','')is not null and not exists(select 1 from public.historical_source_records where company_id=cid and id=(v->>'source_id')::uuid and expense_id=(v->>'expense_id')::uuid)then raise exception 'Source and canonical Expense linkage differ'using errcode='23514';end if;
 end if;
 if kind='RECEIPT'and mode='GRNI'and(v->>'not_previously_recognized' is distinct from 'true'or nullif(v->>'expense_id','')is not null)then raise exception 'Confirm independently unrecognized receipt; do not duplicate an existing invoice/asset'using errcode='23514';end if;
 if kind='TRANSFER'then
  select *into dest from public.inventory_locations where company_id=cid and id=(v->>'destination_id')::uuid and active;
  if dest.id is null or dest.id=l.id or(dest.project_id is not null and not exists(select 1 from public.projects where company_id=cid and id=dest.project_id and status='ACTIVE'))then raise exception 'Different authorized active destination required'using errcode='23514';end if;
  if dest.project_id is not null then perform 1 from public.projects where company_id=cid and id=dest.project_id for share;end if;
  db:=private.inventory_balance(cid,m.id,dest.id);if(db->>'last_date')::date>(v->>'date')::date then raise exception 'Chronological destination required'using errcode='23514';end if;
 end if;
 if kind in('RETURN','ADJUSTMENT','MATCH','INVOICE')then
  origin:=private.inventory_current(cid,(v->>'origin_id')::uuid);
  if origin.state<>'POSTED'or origin.id is null or origin.snapshot->>'material_id'<>m.id::text or origin.snapshot->>'location_id'<>l.id::text or(origin.snapshot->>'date')::date>(v->>'date')::date then raise exception 'Active matching original document required'using errcode='23514';end if;
  if kind='RETURN'then
   if origin.snapshot->>'kind'<>'ISSUE'then raise exception 'Return must reference original Project issue'using errcode='23514';end if;
   select coalesce(sum((e.snapshot->'computed'->>'qty')::numeric),0),coalesce(sum((e.snapshot->'computed'->>'value')::numeric),0)into returned,prior_value from public.inventory_events e where e.company_id=cid and e.state='POSTED'and e.snapshot->>'kind'='RETURN'and e.snapshot->>'origin_id'=origin.document_id::text and not exists(select 1 from public.inventory_events r where r.company_id=cid and r.document_id=e.document_id and r.state='REVERSED');
   original_qty:=(origin.snapshot->'computed'->>'qty')::numeric;original_value:=(origin.snapshot->'computed'->>'value')::numeric;
   if returned+qty>original_qty then raise exception 'Return exceeds unreturned original issue'using errcode='23514';end if;
   amount:=(case when returned+qty=original_qty then original_value else round(original_value*(returned+qty)/original_qty)end)-prior_value;
   project:=(origin.snapshot->'computed'->>'project')::uuid;cost:=(origin.snapshot->'computed'->>'cost')::uuid;
  elsif kind='ADJUSTMENT'then
   if origin.snapshot->>'kind'<>'COUNT'or origin.snapshot->'computed'->'balance'<>b then raise exception 'Fresh unchanged physical count required'using errcode='40001';end if;
   qty:=(origin.snapshot->'computed'->>'qty')::numeric-(b->>'qty')::numeric;
   if qty=0 or((b->>'qty')::numeric=0 and qty>0)then raise exception 'No difference or no supported average valuation; use evidenced receiving/opening'using errcode='23514';end if;
   amount:=case when -qty=(b->>'qty')::numeric then-(b->>'value')::numeric else sign(qty)*round((b->>'value')::numeric*abs(qty)/(b->>'qty')::numeric)end;
  else
   if origin.snapshot->>'kind'<>'RECEIPT'or origin.snapshot->>'recognition'<>'GRNI'then raise exception 'Unmatched accrued receipt required'using errcode='23514';end if;
   if exists(select 1 from public.inventory_events e where e.company_id=cid and e.state='POSTED'and e.snapshot->>'kind'in('MATCH','INVOICE')and e.snapshot->>'origin_id'=origin.document_id::text and not exists(select 1 from public.inventory_events r where r.company_id=cid and r.document_id=e.document_id and r.state='REVERSED'))then raise exception 'Receipt already matched'using errcode='23505';end if;
   qty:=(origin.snapshot->'computed'->>'qty')::numeric;amount:=(origin.snapshot->'computed'->>'value')::numeric;
  end if;
 end if;
 if kind='INVOICE'then
  if nullif(v->>'supplier_id','')is not null and (v->>'supplier_id')::uuid is distinct from (origin.snapshot->>'supplier_id')::uuid then raise exception 'Invoice Supplier is derived from original receiving'using errcode='23514';end if;
  v:=v||jsonb_build_object('supplier_id',origin.snapshot->>'supplier_id');
  if coalesce(length(v->>'invoice_number'),0)not between 1 and 100 or v->>'original_invoice' is distinct from 'true'or coalesce(v->>'vat_mode','')not in('ZERO','AUTO_5','MANUAL')then raise exception 'Original invoice number, verified invoice and actual VAT treatment required'using errcode='23514';end if;
  if not exists(select 1 from public.expense_categories where company_id=cid and id=(v->>'expense_category_id')::uuid and status='ACTIVE')then raise exception 'Existing Company purchase category required'using errcode='23514';end if;
  if v->>'vat_mode'='MANUAL'and coalesce(v->>'manual_vat_minor','')!~'^[0-9]{1,16}$'then raise exception 'Exact actual invoice VAT required'using errcode='23514';end if;
  project:=coalesce(project,l.project_id);
  if l.project_id is not null and l.project_id is distinct from project then raise exception 'Invoice Project differs from receiving location'using errcode='23514';end if;
 end if;
 if(kind='RECEIPT'and mode='EXISTING_EXPENSE')or kind='MATCH'then
  select *into ex from public.expenses where company_id=cid and id=(v->>'expense_id')::uuid;
  if ex.id is null or ex.status<>'POSTED' or ex.net_amount_minor<>amount or ex.allocation_plan is not null or date_trunc('month',ex.expense_date)<>date_trunc('month',(v->>'date')::date)or ex.expense_date>(v->>'date')::date then raise exception 'Verified current-period unsplit Expense of exact net value required; existing canonical VAT remains unchanged; historical/unsupported valuation stays reference-only'using errcode='23514';end if;
  if kind='MATCH'and ex.supplier_id::text is distinct from origin.snapshot->>'supplier_id'then raise exception 'Invoice Supplier differs from accrued receiving Supplier'using errcode='23514';end if;
  if exists(select 1 from public.project_cost_corrections c where c.company_id=cid and c.expense_id=ex.id)or exists(select 1 from public.source_reclassification_events e where e.company_id=cid and e.state='POSTED'and(e.origin->>'id'=ex.id::text or e.replacement->>'id'=ex.id::text))then raise exception 'Already-corrected Expense requires specialized valuation review'using errcode='23514';end if;
  select l.account_id,l.project_id into cost,cost_project from public.journal_lines l join public.accounts a on a.company_id=l.company_id and a.id=l.account_id where l.company_id=cid and l.journal_entry_id=ex.posted_journal_entry_id and a.account_type='EXPENSE'and l.debit_minor=amount and l.credit_minor=0;
  if cost is null or(select count(*)from public.journal_lines l join public.accounts a on a.company_id=l.company_id and a.id=l.account_id where l.company_id=cid and l.journal_entry_id=ex.posted_journal_entry_id and a.account_type='EXPENSE')<>1 then raise exception 'Original exact cost journal required'using errcode='23514';end if;
  if exists(select 1 from public.inventory_events e where e.company_id=cid and e.state='POSTED'and e.snapshot->>'expense_id'=ex.id::text and e.snapshot->>'kind'in('RECEIPT','MATCH','INVOICE')and not exists(select 1 from public.inventory_events r where r.company_id=cid and r.document_id=e.document_id and r.state='REVERSED'))then raise exception 'Invoice cost already capitalized; no duplicate recognition'using errcode='23505';end if;
 end if;
 if amount<0 and kind<>'ADJUSTMENT'or abs(amount)>9000000000000000 or(kind in('RECEIPT','OPENING','MATCH','INVOICE')and amount<1)then raise exception 'Supported positive stock value required'using errcode='23514';end if;
 if v?'cost_purpose'and(kind<>'ISSUE'or v->>'cost_purpose'not in('SALE','CONSUMPTION'))then raise exception 'Supported stock cost purpose required'using errcode='22023';end if;
 if kind='ISSUE'and v->>'cost_purpose'='SALE'then
 if project is not null or l.project_id is not null or not exists(select 1 from public.customer_accounts where company_id=cid and party_id=(v->>'recipient_id')::uuid)then raise exception 'Company warehouse and verified customer recipient required for goods sale'using errcode='23514';end if;
 cost:=private.commercial_account(cid,'COGS');
 elsif kind='ISSUE'then select id into cost from public.accounts where company_id=cid and system_key=(case when project is null then 'COMPANY_EXPENSE'else 'PROJECT_COST'end)::public.system_account_key and account_type='EXPENSE'and status='ACTIVE';if cost is null then raise exception 'Canonical Project cost mapping required'using errcode='23514';end if;end if;
 return(v-'computed')||jsonb_build_object('computed',jsonb_build_object('qty',qty::bigint::text,'value',amount::bigint::text,'balance',b,'destination_balance',db,'material_version',m.version,'location_version',l.version,'destination_version',dest.version,'project',project,'cost',cost,'cost_project',cost_project));
end$$;

create or replace function public.command_inventory(cid uuid,request_id uuid,action text,input jsonb)returns jsonb
language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_variable
declare actor uuid;admin boolean;h text;k text;v jsonb:=input;old public.inventory_events;e public.inventory_events;cfg public.inventory_configuration;m public.inventory_materials;l public.inventory_locations;
 did uuid;version integer;state text;ref text;j uuid;lines jsonb:='[]';qty bigint;amount bigint;mid uuid;lid uuid;other uuid;cost uuid;project uuid;original public.inventory_events;x record;aid uuid;typ public.account_type;party boolean;ids uuid[]:='{}';conv jsonb;ratio jsonb;existing_qty numeric;value_now numeric;expected numeric;sum_value numeric;
begin
 actor:=private.operational_finance_actor(cid,'accounting.post');admin:=public.has_company_role(cid,'ACCOUNTING_ADMIN');
 perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');perform pg_advisory_xact_lock(hashtextextended('inventory:'||cid::text,0));
 if request_id is null or action is null or action not in('SETUP','MATERIAL','LOCATION','SAVE','REVIEW','POST','REVERSE','CANCEL','LINK_PURCHASE')or jsonb_typeof(v)is distinct from 'object'or octet_length(v::text)>16000 then raise exception 'Supported inventory command and bounded business inputs required'using errcode='22023';end if;
 for k in select jsonb_object_keys(v)loop
  if k<>all(array['cost_purpose','id','version','code','name','category','base_unit','conversions','active','reorder_micros','project_id','inventory_account_id','grni_account_id','variance_account_id','opening_account_id','inventory_code','inventory_name','grni_code','grni_name','variance_code','variance_name','opening_code','opening_name','evidence','kind','date','material_id','location_id','destination_id','recipient_id','supplier_id','expense_id','source_id','origin_id','qty_micros','unit','value_minor','recognition','source_reference','physically_counted','not_previously_recognized','invoice_number','original_invoice','vat_mode','manual_vat_minor','expense_category_id'])then raise exception 'Unsupported input; callers cannot supply journal lines or GL accounts in documents'using errcode='22023';end if;
  if jsonb_typeof(v->k)='string'then v:=jsonb_set(v,array[k],to_jsonb(btrim(v->>k)));end if;
  if k in('id','material_id','location_id','destination_id','recipient_id','supplier_id','expense_id','source_id','origin_id','project_id','inventory_account_id','grni_account_id','variance_account_id','opening_account_id','expense_category_id')and nullif(v->>k,'')is not null then
   if k like '%account_id'and upper(v->>k)='NEW'then v:=jsonb_set(v,array[k],'"NEW"'::jsonb);else v:=jsonb_set(v,array[k],to_jsonb((v->>k)::uuid::text));end if;
  end if;
  if k in('qty_micros','value_minor','reorder_micros','version','manual_vat_minor')and v->>k ~ '^[0-9]{1,16}$'then v:=jsonb_set(v,array[k],to_jsonb((v->>k)::bigint::text));end if;
 end loop;
 if action<>'SETUP'and exists(select 1 from jsonb_object_keys(v)key where key like '%\_account_id' escape '\'or key in('inventory_code','inventory_name','grni_code','grni_name','variance_code','variance_name','opening_code','opening_name'))then raise exception 'GL setup inputs are not document inputs'using errcode='22023';end if;
 if action in('REVIEW','POST','REVERSE','CANCEL')and(v-array['id','version','evidence'])<>'{}'::jsonb then raise exception 'Actions cannot replace saved business inputs'using errcode='22023';end if;
 h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'action',action,'input',v)::text,'UTF8'),'sha256'),'hex');
 select *into old from public.inventory_events z where z.company_id=cid and z.request_id=command_inventory.request_id;
 if old.id is not null then if old.request_hash<>h then raise exception 'Changed inventory retry intent'using errcode='22023';end if;return to_jsonb(old)||jsonb_build_object('replayed',true);end if;
 if action in('SETUP','MATERIAL','LOCATION')and(not admin or not public.has_permission(cid,'account.manage'))then raise exception 'Accounting Admin master/configuration approval required'using errcode='42501';end if;
 if coalesce(length(v->>'evidence'),0)not between 5 and 1000 then raise exception 'Documented approval/evidence required'using errcode='23514';end if;
 if action in('SETUP','MATERIAL','LOCATION','SAVE','REVIEW','POST')and not(private.company_commercial_readiness(cid)->>'ready')::boolean then
  if action not in('SAVE','REVIEW','POST')or coalesce(v->>'kind',(private.inventory_current(cid,(v->>'id')::uuid)).snapshot->>'kind')not in('RETURN','COUNT','ADJUSTMENT','MATCH','INVOICE')then raise exception 'Commercial readiness required for new stock business'using errcode='42501';end if;
 end if;
 if action='SETUP'then
  if exists(select 1 from public.inventory_configuration where company_id=cid)then raise exception 'Inventory configuration is immutable; use a forward approved change'using errcode='23514';end if;
  foreach k in array array['inventory','grni','variance','opening']loop
   typ:=case k when 'inventory'then 'ASSET'when 'grni'then 'LIABILITY'when 'variance'then 'EXPENSE'else 'EQUITY'end;party:=k='grni';
   if v->>(k||'_account_id')='NEW'then
    if coalesce(length(v->>(k||'_code')),0)not between 1 and 50 or coalesce(length(v->>(k||'_name')),0)not between 1 and 200 then raise exception 'Explicit new control code/name required'using errcode='23514';end if;
    insert into public.accounts(company_id,code,name,account_type,requires_party)values(cid,v->>(k||'_code'),v->>(k||'_name'),typ,party)returning id into aid;
   else select a.id into aid from public.accounts a where a.company_id=cid and a.id=(v->>(k||'_account_id'))::uuid and a.account_type=typ and a.requires_party=party and a.status='ACTIVE'and a.system_key is null;end if;
   if aid is null or aid=any(ids)or exists(select 1 from public.journal_lines where company_id=cid and account_id=aid)then raise exception 'Separate unused approved inventory control accounts required; existing asset balances cannot be imported twice'using errcode='23514';end if;
   ids:=array_append(ids,aid);
  end loop;
  insert into public.inventory_configuration values(cid,'MOVING_AVERAGE_LOCATION',ids[1],ids[2],ids[3],ids[4],v->>'evidence',actor,clock_timestamp());
  did:=cid;version:=1;state:='RECORDED';v:=to_jsonb((select c from public.inventory_configuration c where c.company_id=cid));
 elsif action in('MATERIAL','LOCATION')then
  if coalesce(length(v->>'code'),0)not between 1 and 50 or coalesce(length(v->>'name'),0)not between 1 and 200 then raise exception 'Code/name required'using errcode='23514';end if;
  did:=coalesce(nullif(v->>'id','')::uuid,gen_random_uuid());
  if action='MATERIAL'then
   select *into m from public.inventory_materials where company_id=cid and id=did;
   if coalesce(m.version,0)<>coalesce((v->>'version')::integer,0)then raise exception 'Material changed'using errcode='40001';end if;
   if coalesce(length(v->>'base_unit'),0)not between 1 and 30 or coalesce(length(v->>'category'),0)not between 1 and 100 then raise exception 'Category and base unit required'using errcode='23514';end if;
   conv:=coalesce(v->'conversions','{}');if jsonb_typeof(conv)<>'object'or (select count(*)from jsonb_object_keys(conv))>12 then raise exception 'Bounded controlled conversions required'using errcode='22023';end if;
   for k,ratio in select key,value from jsonb_each(conv)loop
    if length(k)not between 1 and 30 or k=v->>'base_unit'or jsonb_typeof(ratio)<>'object'or coalesce(ratio->>'numerator','')!~'^[1-9][0-9]{0,8}$'or coalesce(ratio->>'denominator','')!~'^[1-9][0-9]{0,8}$'then raise exception 'Positive integer unit conversion ratio required'using errcode='23514';end if;
   end loop;
   if m.id is not null and exists(select 1 from public.inventory_movements where company_id=cid and material_id=did)and(m.base_unit is distinct from v->>'base_unit'or m.conversions<>conv or m.code<>v->>'code')then raise exception 'Used material code/units cannot be redefined'using errcode='23514';end if;
   version:=coalesce(m.version,0)+1;
   insert into public.inventory_materials(id,company_id,code,name,category,base_unit,conversions,active,reorder_micros,version)values(did,cid,v->>'code',v->>'name',v->>'category',v->>'base_unit',conv,coalesce((v->>'active')::boolean,true),coalesce((v->>'reorder_micros')::bigint,0),version)
    on conflict(id)do update set name=excluded.name,category=excluded.category,code=excluded.code,base_unit=excluded.base_unit,conversions=excluded.conversions,active=excluded.active,reorder_micros=excluded.reorder_micros,version=excluded.version where inventory_materials.company_id=cid;
   v:=to_jsonb((select a from public.inventory_materials a where a.company_id=cid and a.id=did))||jsonb_build_object('evidence',input->>'evidence');
  else
   select *into l from public.inventory_locations where company_id=cid and id=did;
   if coalesce(l.version,0)<>coalesce((v->>'version')::integer,0)then raise exception 'Warehouse changed'using errcode='40001';end if;
   if nullif(v->>'project_id','')is not null and not exists(select 1 from public.projects where company_id=cid and id=(v->>'project_id')::uuid and status='ACTIVE')then raise exception 'Active Company Project required'using errcode='23514';end if;
   if l.id is not null and exists(select 1 from public.inventory_movements where company_id=cid and location_id=did)and(l.project_id is distinct from nullif(v->>'project_id','')::uuid or l.code<>v->>'code')then raise exception 'Used warehouse identity/Project cannot change'using errcode='23514';end if;
   version:=coalesce(l.version,0)+1;
   insert into public.inventory_locations(id,company_id,code,name,project_id,active,version)values(did,cid,v->>'code',v->>'name',nullif(v->>'project_id','')::uuid,coalesce((v->>'active')::boolean,true),version)
    on conflict(id)do update set code=excluded.code,name=excluded.name,project_id=excluded.project_id,active=excluded.active,version=excluded.version where inventory_locations.company_id=cid;
   v:=to_jsonb((select a from public.inventory_locations a where a.company_id=cid and a.id=did))||jsonb_build_object('evidence',input->>'evidence');
  end if;state:='RECORDED';
 elsif action='LINK_PURCHASE'then
  if not exists(select 1 from public.inventory_materials where company_id=cid and id=(v->>'material_id')::uuid)then raise exception 'Company material required'using errcode='42501';end if;
  if nullif(v->>'source_id','')is not null and not exists(select 1 from public.historical_source_records where company_id=cid and id=(v->>'source_id')::uuid)then raise exception 'Company source required'using errcode='42501';end if;
  if nullif(v->>'expense_id','')is not null and not exists(select 1 from public.expenses where company_id=cid and id=(v->>'expense_id')::uuid)then raise exception 'Company Expense required'using errcode='42501';end if;
  did:=gen_random_uuid();version:=1;state:='RECORDED';
  insert into public.inventory_purchase_links(company_id,material_id,source_id,expense_id,reference,evidence,created_by)values(cid,(v->>'material_id')::uuid,nullif(v->>'source_id','')::uuid,nullif(v->>'expense_id','')::uuid,v->>'source_reference',v->>'evidence',actor);
 else
  did:=(v->>'id')::uuid;if did is null or coalesce(v->>'version','')!~'^[0-9]+$'then raise exception 'Document ID/current version required'using errcode='22023';end if;
  old:=private.inventory_current(cid,did);version:=coalesce(old.version,0)+1;
  if coalesce(old.version,0)<>(v->>'version')::integer then raise exception 'Inventory document changed'using errcode='40001';end if;
  if old.state in('REVERSED','CANCELLED','RECORDED')or(old.state='POSTED'and action<>'REVERSE')then raise exception 'Final document is immutable; use controlled reversal'using errcode='23514';end if;
  select *into cfg from public.inventory_configuration where company_id=cid;
  if action='SAVE'then v:=v-array['id','version'];state:='DRAFT';
  elsif action='CANCEL'then v:=old.snapshot;state:='CANCELLED';
  elsif action='REVIEW'then
   if old.state not in('DRAFT','REVIEWED')then raise exception 'Save document first'using errcode='23514';end if;
   v:=private.inventory_plan(cid,old.snapshot-'computed');state:='REVIEWED';
  elsif action='POST'then
   if old.state<>'REVIEWED'then raise exception 'Review current document first'using errcode='23514';end if;
   v:=private.inventory_plan(cid,old.snapshot-'computed');if v<>old.snapshot then raise exception 'Stock/master/valuation changed; review current balances again'using errcode='40001';end if;
   if v->>'kind'in('OPENING','ADJUSTMENT','MATCH','INVOICE')or v->>'recognition'='EXISTING_EXPENSE'then if not admin or not public.has_permission(cid,'accounting.reverse')then raise exception 'Accounting Admin approval required for stock/cost adjustments'using errcode='42501';end if;end if;
   qty:=(v->'computed'->>'qty')::bigint;amount:=(v->'computed'->>'value')::bigint;mid:=(v->>'material_id')::uuid;lid:=(v->>'location_id')::uuid;cost:=(v->'computed'->>'cost')::uuid;project:=(v->'computed'->>'project')::uuid;
   if v->>'kind'='INVOICE'then
    original:=private.inventory_current(cid,(v->>'origin_id')::uuid);
    select *into x from public.post_expense(cid,(v->>'date')::date,project,(v->>'expense_category_id')::uuid,'Inventory Supplier invoice '||(v->>'invoice_number'),amount,(v->>'vat_mode')::public.expense_vat_mode,nullif(v->>'manual_vat_minor','')::bigint,'SUPPLIER_CREDIT',null,null,(original.snapshot->>'supplier_id')::uuid,'BANK',true,v->>'invoice_number',v->>'evidence',request_id);
    v:=(private.inventory_plan(cid,(v-'computed')||jsonb_build_object('kind','MATCH','expense_id',x.expense_id))||jsonb_build_object('kind','INVOICE','auto_invoice_reference',x.expense_reference,'auto_invoice_journal',x.journal_entry_id));
    cost:=(v->'computed'->>'cost')::uuid;
   end if;
   if v->>'kind'='RECEIPT'then
    lines:=jsonb_build_array(jsonb_build_object('account_id',cfg.inventory_account_id,'debit_minor',amount,'credit_minor',0),jsonb_build_object('account_id',case when v->>'recognition'='EXISTING_EXPENSE'then cost else cfg.grni_account_id end,'debit_minor',0,'credit_minor',amount,'project_id',case when v->>'recognition'='EXISTING_EXPENSE'then v->'computed'->>'cost_project'end,'party_id',case when v->>'recognition'='GRNI'then v->>'supplier_id'end));
   elsif v->>'kind'='OPENING'then lines:=jsonb_build_array(jsonb_build_object('account_id',cfg.inventory_account_id,'debit_minor',amount,'credit_minor',0),jsonb_build_object('account_id',cfg.opening_account_id,'debit_minor',0,'credit_minor',amount));
   elsif v->>'kind'in('ISSUE','RETURN')and amount>0 then
    lines:=jsonb_build_array(jsonb_build_object('account_id',cost,'debit_minor',case when v->>'kind'='ISSUE'then amount else 0 end,'credit_minor',case when v->>'kind'='RETURN'then amount else 0 end,'project_id',project),jsonb_build_object('account_id',cfg.inventory_account_id,'debit_minor',case when v->>'kind'='RETURN'then amount else 0 end,'credit_minor',case when v->>'kind'='ISSUE'then amount else 0 end));
   elsif v->>'kind'='ADJUSTMENT'and amount<>0 then lines:=jsonb_build_array(jsonb_build_object('account_id',cfg.inventory_account_id,'debit_minor',greatest(amount,0),'credit_minor',greatest(-amount,0)),jsonb_build_object('account_id',cfg.variance_account_id,'debit_minor',greatest(-amount,0),'credit_minor',greatest(amount,0)));
   elsif v->>'kind'in('MATCH','INVOICE')then
    original:=private.inventory_current(cid,(v->>'origin_id')::uuid);
    lines:=jsonb_build_array(jsonb_build_object('account_id',cfg.grni_account_id,'debit_minor',amount,'credit_minor',0,'party_id',original.snapshot->>'supplier_id'),jsonb_build_object('account_id',cost,'debit_minor',0,'credit_minor',amount,'project_id',v->'computed'->>'cost_project'));
   end if;
   ref:=private.allocate_reference(cid,'INV',extract(year from(v->>'date')::date)::integer);
   if jsonb_array_length(lines)>0 then j:=private.create_journal(cid,(v->>'date')::date,ref||' '||(v->>'source_reference'),'INVENTORY_'||(v->>'kind'),did,'ORIGINAL',lines,actor,null);end if;
   state:='POSTED';
  else
   if exists(select 1 from public.commercial_documents c where c.company_id=cid and(c.stock_event_id=old.id or c.return_event_id=old.id))then raise exception 'Stock event linked to an immutable sales document; use evidenced return/credit workflows'using errcode='23514';end if;
   if old.state<>'POSTED'or not admin or not public.has_permission(cid,'accounting.reverse')then raise exception 'Authorized posted inventory reversal required'using errcode='42501';end if;
   perform private.check_source_allocation_period(cid,current_date);
   v:=old.snapshot||jsonb_build_object('reversal_evidence',input->>'evidence');ref:=old.reference;
   if exists(select 1 from public.inventory_events z where z.company_id=cid and z.state='POSTED'and z.snapshot->>'origin_id'=did::text and not exists(select 1 from public.inventory_events r where r.company_id=cid and r.document_id=z.document_id and r.state='REVERSED'))then raise exception 'Reverse dependent returns/adjustments/matches first'using errcode='23514';end if;
   for x in select *from public.inventory_movements where company_id=cid and event_id=old.id loop
    select coalesce(sum(quantity_micros::numeric),0),coalesce(sum(value_minor::numeric),0)into existing_qty,value_now from public.inventory_movements where company_id=cid and material_id=x.material_id and location_id=x.location_id;
    conv:=case when x.location_id::text=v->>'location_id'then v->'computed'->'balance'else v->'computed'->'destination_balance'end;
    if existing_qty<>(conv->>'qty')::numeric+x.quantity_micros or value_now<>(conv->>'value')::numeric+x.value_minor
     or exists(select 1 from public.inventory_movements sm join public.inventory_events se on se.company_id=sm.company_id and se.id=sm.event_id where sm.company_id=cid and sm.material_id=x.material_id and sm.location_id=x.location_id and se.state='POSTED'and(se.created_at,se.id)>(old.created_at,old.id)and not exists(select 1 from public.inventory_events rr where rr.company_id=cid and rr.document_id=se.document_id and rr.state='REVERSED'))
    then raise exception 'Later dependent stock valuation exists; reverse in dependency order'using errcode='23514';end if;
   end loop;
   if old.journal_id is not null then j:=private.reverse_journal(old.journal_id,current_date,input->>'evidence',actor);end if;state:='REVERSED';
  end if;
 end if;
 insert into public.inventory_events(company_id,document_id,version,request_id,request_hash,action,state,snapshot,reference,journal_id,created_by)values(cid,did,version,request_id,h,action,state,v,ref,j,actor)returning *into e;
 if state='POSTED'and v->>'kind'not in('COUNT','MATCH','INVOICE')then
  if v->>'kind'in('ISSUE','TRANSFER')then qty:=-qty;amount:=-amount;end if;
  insert into public.inventory_movements(company_id,event_id,material_id,location_id,quantity_micros,value_minor,movement_date)values(cid,e.id,mid,lid,qty,amount,(v->>'date')::date);
  if v->>'kind'='TRANSFER'then insert into public.inventory_movements(company_id,event_id,material_id,location_id,quantity_micros,value_minor,movement_date)values(cid,e.id,mid,(v->>'destination_id')::uuid,-qty,-amount,(v->>'date')::date);end if;
 elsif state='REVERSED'then
  insert into public.inventory_movements(company_id,event_id,material_id,location_id,quantity_micros,value_minor,movement_date)select cid,e.id,material_id,location_id,-quantity_micros,-value_minor,current_date from public.inventory_movements where company_id=cid and event_id=old.id;
 end if;
 if state='POSTED'and v->>'kind'in('RECEIPT','MATCH','INVOICE')and(nullif(v->>'source_id','')is not null or nullif(v->>'expense_id','')is not null)then
  insert into public.inventory_purchase_links(company_id,material_id,source_id,expense_id,reference,evidence,created_by)values(cid,(v->>'material_id')::uuid,nullif(v->>'source_id','')::uuid,nullif(v->>'expense_id','')::uuid,v->>'source_reference',v->>'evidence',actor)on conflict do nothing;
 end if;
 if state='REVERSED'and v->>'kind'='INVOICE'then
  perform public.reverse_expense(cid,(v->>'expense_id')::uuid,current_date,input->>'evidence',request_id);
 end if;
 -- Reconcile the stock asset to the canonical GL before committing any command.
 select coalesce(sum(value_minor::numeric),0)into sum_value from public.inventory_movements where company_id=cid;
 select inventory_account_id into aid from public.inventory_configuration where company_id=cid;
 if aid is not null and sum_value<>(select coalesce(sum(debit_minor::numeric-credit_minor::numeric),0)from public.journal_lines where company_id=cid and account_id=aid)then raise exception 'Stock value does not reconcile to canonical inventory GL; transaction rolled back'using errcode='23514';end if;
 return to_jsonb(e)||jsonb_build_object('replayed',false);
end$$;

create or replace function private.customer_plan(cid uuid,kind text,v jsonb)returns jsonb language plpgsql volatile set search_path='' as $$
#variable_conflict use_variable
declare n bigint:=(v->>'amount_minor')::bigint;tax bigint:=coalesce((v->>'vat_minor')::bigint,0);d date:=(v->>'date')::date;p uuid:=nullif(v->>'party_id','')::uuid;project uuid:=nullif(v->>'project_id','')::uuid;t uuid:=nullif(v->>'treasury_id','')::uuid;
 stock public.inventory_events;returned public.inventory_events;parent public.commercial_documents;adv public.commercial_documents;used numeric;available numeric;lines jsonb;bank uuid;reduction bigint:=0;credit_balance bigint:=0;remaining_net bigint;remaining_tax bigint;expected_tax bigint;
begin
 if kind not in('AR_INVOICE','AR_CASH_SALE','AR_RECEIPT','AR_ADVANCE','AR_APPLY','AR_CREDIT','AR_REFUND')then raise exception 'Unsupported customer event'using errcode='22023';end if;
 if exists(select 1 from jsonb_object_keys(v)x where x<>all(array['stock_event_id','return_event_id','credit_reason','economic_kind','date','party_id','project_id','treasury_id','parent_id','related_id','reference','amount_minor','vat_minor','vat_rate_bps','tax_evidence','evidence','due_date','recognition_confirmed']))or n is null or n<=0 or n>9000000000000000 or tax<0 or d is null or d>current_date or coalesce(length(btrim(v->>'reference')),0)not between 1 and 120 or coalesce(length(btrim(v->>'evidence')),0)not between 5 and 1000 then raise exception 'Check customer amount, date, evidence and reference'using errcode='23514';end if;
 if kind in('AR_INVOICE','AR_CASH_SALE','AR_ADVANCE')and(v?'parent_id'or v?'related_id')or kind<>'AR_APPLY'and v?'related_id'or kind not in('AR_CASH_SALE','AR_RECEIPT','AR_ADVANCE','AR_REFUND')and v?'treasury_id'or kind not in('AR_INVOICE','AR_CASH_SALE')and(v?'economic_kind'or v?'recognition_confirmed'or v?'due_date'or v?'vat_rate_bps'or v?'tax_evidence')then raise exception 'Fields do not belong to this customer event'using errcode='22023';end if;
 if kind not in('AR_INVOICE','AR_CASH_SALE')and v?'stock_event_id'or kind<>'AR_CREDIT'and(v?'return_event_id'or v?'credit_reason')then raise exception 'Stock links do not belong to this customer event'using errcode='22023';end if;
 if not exists(select 1 from public.customer_accounts where company_id=cid and party_id=p)then raise exception 'Company customer relationship required'using errcode='23514';end if;
 if project is not null and not exists(select 1 from public.projects where company_id=cid and id=project)then raise exception 'Company Project required'using errcode='23514';end if;
 perform private.opening_period(cid,d);
 if kind in('AR_INVOICE','AR_CASH_SALE','AR_ADVANCE')and not exists(select 1 from public.parties where company_id=cid and id=p and status::text='ACTIVE')then raise exception 'Active customer required for new business'using errcode='23514';end if;
 if kind in('AR_INVOICE','AR_CASH_SALE')then
 if v->>'economic_kind'is null or v->>'economic_kind'not in('EARNED_SERVICE','DELIVERED_GOODS')then raise exception 'Select earned services or evidenced delivered goods; construction progress requires approved recognition'using errcode='23514';end if;
 if v->>'economic_kind'='DELIVERED_GOODS'then
 select *into stock from public.inventory_events where company_id=cid and id=(v->>'stock_event_id')::uuid;
 if stock.id is null or stock.state<>'POSTED'or stock.snapshot->>'kind'<>'ISSUE'or stock.snapshot->>'cost_purpose'is distinct from 'SALE'or stock.snapshot->>'recipient_id'<>p::text or (stock.snapshot->>'date')::date<>d or project is not null or (private.inventory_current(cid,stock.document_id)).id<>stock.id then raise exception 'Current posted same-customer sales issue on the recognition date required; no repeated stock/COGS'using errcode='23514';end if;
 else if v?'stock_event_id'then raise exception 'Service invoice cannot consume stock issue'using errcode='22023';end if;end if;
 if (v->>'recognition_confirmed')::boolean is distinct from true or (v->>'due_date')::date<d or v->>'due_date'is null then raise exception 'Earned/delivered evidence and valid due date required'using errcode='23514';end if;
 if tax>0 and(coalesce(length(btrim(v->>'tax_evidence')),0)<5 or (v->>'vat_rate_bps')::integer is null or (v->>'vat_rate_bps')::integer not between 1 and 10000 or tax<>round(n::numeric*(v->>'vat_rate_bps')::integer/10000))then raise exception 'Explicit supported output tax rate and evidence required'using errcode='23514';end if;
 if kind='AR_CASH_SALE'then bank:=private.commercial_bank(cid,t,d,n+tax,false,project);end if;
 lines:=jsonb_build_array(case when kind='AR_CASH_SALE'then private.commercial_line(bank,n+tax,false,null,project,t)else private.commercial_line(private.commercial_account(cid,'AR'),n+tax,false,p,project)end,private.commercial_line(private.commercial_account(cid,'REVENUE'),n,true,null,project));
 if tax>0 then lines:=lines||jsonb_build_array(private.commercial_line(private.commercial_account(cid,'OUTPUT_VAT'),tax,true));end if;
 elsif kind='AR_ADVANCE'then
 if tax<>0 then raise exception 'Taxable customer deposits require a supported tax-point workflow; not zero-rated by assumption'using errcode='23514';end if;
 bank:=private.commercial_bank(cid,t,d,n,false,project);lines:=jsonb_build_array(private.commercial_line(bank,n,false,null,project,t),private.commercial_line(private.commercial_account(cid,'CUSTOMER_ADVANCE'),n,true,p,project));
 elsif kind='AR_REFUND'then
 select *into adv from public.commercial_documents where company_id=cid and id=(v->>'parent_id')::uuid for update;
 if adv.id is null or adv.kind not in('AR_ADVANCE','AR_CREDIT')or adv.party_id<>p or adv.date>d or tax<>0 or project is distinct from adv.project_id then raise exception 'Same-customer refundable deposit/credit required'using errcode='23514';end if;
 available:=(case when adv.kind='AR_ADVANCE'then adv.amount_minor else adv.customer_credit_minor end)-coalesce((select sum(s.amount_minor)from public.commercial_documents s where s.company_id=cid and(s.related_id=adv.id or s.parent_id=adv.id)),0);
 if n>available then raise exception 'Refund exceeds available customer credit'using errcode='23514';end if;
 bank:=private.commercial_bank(cid,t,d,n,true,project);lines:=jsonb_build_array(private.commercial_line(private.commercial_account(cid,'CUSTOMER_ADVANCE'),n,false,p,project),private.commercial_line(bank,n,true,null,project,t));
 else
 select *into parent from public.commercial_documents where company_id=cid and id=(v->>'parent_id')::uuid for update;
 if parent.id is null or (parent.kind<>'AR_INVOICE'and not(kind='AR_CREDIT'and parent.kind='AR_CASH_SALE'))or parent.party_id<>p or parent.date>d or project is distinct from parent.project_id then raise exception 'Same customer invoice, Project and chronological allocation required'using errcode='23514';end if;
 select coalesce(sum(ar_reduction_minor),0)into used from public.commercial_documents where company_id=cid and parent_id=parent.id;
 available:=case when parent.kind='AR_CASH_SALE'then 0 else parent.amount_minor-used end;
 if kind<>'AR_CREDIT'and n>available then raise exception 'Amount exceeds invoice outstanding; paid credits require refund/credit-liability workflow'using errcode='23514';end if;
 if kind='AR_CREDIT'then
 select (parent.input->>'amount_minor')::bigint-coalesce(sum((x.input->>'amount_minor')::bigint),0),(parent.input->>'vat_minor')::bigint-coalesce(sum((x.input->>'vat_minor')::bigint),0)into remaining_net,remaining_tax from public.commercial_documents x where x.company_id=cid and x.parent_id=parent.id and x.kind='AR_CREDIT';
 remaining_tax:=coalesce(remaining_tax,0);
 expected_tax:=case when n=remaining_net then remaining_tax when coalesce((parent.input->>'vat_minor')::bigint,0)>0 then round(n::numeric*(parent.input->>'vat_rate_bps')::integer/10000)::bigint else 0 end;
 if parent.input->>'economic_kind'='DELIVERED_GOODS'then
 if v->>'credit_reason'is null or v->>'credit_reason'not in('PRICE_ADJUSTMENT','GOODS_RETURN')then raise exception 'Distinguish actual goods return from price credit'using errcode='23514';end if;
 if v->>'credit_reason'='GOODS_RETURN'then
 select *into stock from public.inventory_events where company_id=cid and id=parent.stock_event_id;
 select *into returned from public.inventory_events where company_id=cid and id=(v->>'return_event_id')::uuid;
 if returned.id is null or returned.state<>'POSTED'or returned.snapshot->>'kind'<>'RETURN'or returned.snapshot->>'origin_id'<>stock.document_id::text or (returned.snapshot->>'date')::date>d or (private.inventory_current(cid,returned.document_id)).id<>returned.id or n>round((parent.input->>'amount_minor')::numeric*(returned.snapshot->'computed'->>'qty')::numeric/(stock.snapshot->'computed'->>'qty')::numeric)then raise exception 'Matching actual posted physical return and supported credit amount required'using errcode='23514';end if;
 elsif v?'return_event_id'then raise exception 'Price adjustment does not represent a physical stock return'using errcode='22023';end if;
 elsif v?'return_event_id'or v?'credit_reason'then raise exception 'Service credit has no stock return'using errcode='22023';end if;
 if n>remaining_net or tax>remaining_tax or tax<>expected_tax then raise exception 'Credit exceeds original revenue/tax or does not match final rounded tax remainder'using errcode='23514';end if;
 reduction:=least(n+tax,available);credit_balance:=n+tax-reduction;
 lines:=jsonb_build_array(private.commercial_line(private.commercial_account(cid,'REVENUE'),n,false,null,project));
 if reduction>0 then lines:=lines||jsonb_build_array(private.commercial_line(private.commercial_account(cid,'AR'),reduction,true,p,project));end if;
 if credit_balance>0 then lines:=lines||jsonb_build_array(private.commercial_line(private.commercial_account(cid,'CUSTOMER_ADVANCE'),credit_balance,true,p,project));end if;
 if tax>0 then lines:=lines||jsonb_build_array(private.commercial_line(private.commercial_account(cid,'OUTPUT_VAT'),tax));end if;
 elsif kind='AR_RECEIPT'then
 if tax<>0 then raise exception 'Receipt cannot recreate tax'using errcode='23514';end if;
 reduction:=n;bank:=private.commercial_bank(cid,t,d,n,false,project);lines:=jsonb_build_array(private.commercial_line(bank,n,false,null,project,t),private.commercial_line(private.commercial_account(cid,'AR'),n,true,p,project));
 else
 if tax<>0 then raise exception 'Allocation cannot recreate tax'using errcode='23514';end if;
 select *into adv from public.commercial_documents where company_id=cid and id=(v->>'related_id')::uuid for update;
 if adv.id is null or adv.kind not in('AR_ADVANCE','AR_CREDIT')or adv.party_id<>p or adv.date>d or adv.project_id is not null and adv.project_id is distinct from project or n>(case when adv.kind='AR_ADVANCE'then adv.amount_minor else adv.customer_credit_minor end)-coalesce((select sum(s.amount_minor)from public.commercial_documents s where s.company_id=cid and(s.related_id=adv.id or s.parent_id=adv.id)),0)then raise exception 'Available same-customer advance required'using errcode='23514';end if;
 reduction:=n;lines:=jsonb_build_array(private.commercial_line(private.commercial_account(cid,'CUSTOMER_ADVANCE'),n,false,p,adv.project_id),private.commercial_line(private.commercial_account(cid,'AR'),n,true,p,project));end if;end if;
 return jsonb_build_object('lines',lines,'ar_reduction',reduction,'customer_credit',credit_balance,'amount',case when kind in('AR_INVOICE','AR_CASH_SALE','AR_CREDIT')then n+tax else n end);
end;$$;

create or replace function public.command_customer_accounting(cid uuid,request_id uuid,kind text,input jsonb)returns jsonb language plpgsql volatile security definer set search_path='' as $$
#variable_conflict use_variable
declare actor uuid;req private.financial_command_requests;h text;prior public.commercial_documents;plan jsonb;doc uuid:=gen_random_uuid();j uuid;begin
 actor:=private.operational_finance_actor(cid,'accounting.post');if request_id is null or jsonb_typeof(input)is distinct from 'object'or octet_length(input::text)>16000 then raise exception 'Invalid customer command'using errcode='22023';end if;
 input:=private.normalize_commercial_input(input);
 perform private.serialize_operational_finance(cid,'OPERATIONS');h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'kind',kind,'input',input)::text,'UTF8'),'sha256'),'hex');
 select *into prior from public.commercial_documents where company_id=cid and commercial_documents.request_id=command_customer_accounting.request_id;
 if prior.id is not null then if prior.request_hash<>h then raise exception 'Changed customer request'using errcode='23505';end if;return jsonb_build_object('id',prior.id,'journal_id',prior.journal_id);end if;
 req:=private.reserve_financial_command(cid,'COMMERCIAL_'||kind,request_id,h,actor);
 plan:=private.customer_plan(cid,kind,input);
 j:=private.create_journal(cid,(input->>'date')::date,btrim(input->>'reference')||' '||btrim(input->>'evidence'),kind,doc,'ORIGINAL',plan->'lines',actor);
 insert into public.commercial_documents(id,company_id,kind,date,party_id,project_id,treasury_id,parent_id,related_id,reference,amount_minor,journal_id,ar_reduction_minor,customer_credit_minor,stock_event_id,return_event_id,input,request_id,request_hash,created_by)values(doc,cid,kind,(input->>'date')::date,(input->>'party_id')::uuid,nullif(input->>'project_id','')::uuid,nullif(input->>'treasury_id','')::uuid,nullif(input->>'parent_id','')::uuid,nullif(input->>'related_id','')::uuid,btrim(input->>'reference'),(plan->>'amount')::bigint,j,(plan->>'ar_reduction')::bigint,(plan->>'customer_credit')::bigint,nullif(input->>'stock_event_id','')::uuid,nullif(input->>'return_event_id','')::uuid,input,request_id,h,actor);
 perform private.complete_financial_command(req.id,j);return jsonb_build_object('id',doc,'journal_id',j);end;$$;

create or replace function public.read_commercial_workspace(cid uuid)returns jsonb language plpgsql stable security invoker set search_path='' as $$
begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'MANAGEMENT_VIEWER'))then raise exception 'Commercial workspace access denied'using errcode='42501';end if;
 return jsonb_build_object(
 'year_events',coalesce((select jsonb_agg(jsonb_build_object('id',id,'year_id',year_id,'action',action,'reason',reason,'reconciliation_reference',reconciliation_reference,'journal_id',journal_id,'created_at',created_at)order by created_at,id)from public.accounting_year_events where company_id=cid),'[]'::jsonb),
 'stock_events',coalesce((select jsonb_agg(jsonb_build_object('id',e.id,'document_id',e.document_id,'kind',e.snapshot->>'kind','date',e.snapshot->>'date','recipient_id',e.snapshot->>'recipient_id','origin_id',e.snapshot->>'origin_id','qty_micros',e.snapshot->'computed'->>'qty','value_minor',e.snapshot->'computed'->>'value','reference',e.reference,'journal_id',e.journal_id,'linked',exists(select 1 from public.commercial_documents c where c.company_id=cid and(c.stock_event_id=e.id or c.return_event_id=e.id))))from public.inventory_events e where e.company_id=cid and e.state='POSTED'and not exists(select 1 from public.inventory_events newer where newer.company_id=e.company_id and newer.document_id=e.document_id and newer.version>e.version) and(e.snapshot->>'cost_purpose'='SALE'or e.snapshot->>'kind'='RETURN')),'[]'::jsonb),
 'accounts',coalesce((select jsonb_agg(jsonb_build_object('id',id,'code',code,'name',name,'type',account_type,'requires_party',requires_party,'active',status::text='ACTIVE')order by code)from public.accounts where company_id=cid),'[]'::jsonb),
 'parties',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'active',status::text='ACTIVE'))from public.parties where company_id=cid),'[]'::jsonb),
 'projects',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name))from public.projects where company_id=cid),'[]'::jsonb),
 'treasuries',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'account_id',gl_account_id))from public.treasury_accounts where company_id=cid and status::text='ACTIVE'),'[]'::jsonb),
 'controls',coalesce((select jsonb_object_agg(key,account_id)from public.commercial_controls where company_id=cid),'{}'::jsonb),
 'years',coalesce((select jsonb_agg(to_jsonb(y)||jsonb_build_object('state',coalesce(c.state,'OPEN'),'version',coalesce(c.version,0)))from public.accounting_fiscal_years y left join public.accounting_year_closures c on c.company_id=y.company_id and c.year_id=y.id where y.company_id=cid),'[]'::jsonb));end;$$;

create function public.read_statement_controls(cid uuid)returns jsonb language plpgsql stable security invoker set search_path='' as $$
begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'MANAGEMENT_VIEWER'))then raise exception 'Statement control access denied'using errcode='42501';end if;
 return jsonb_build_object('sales',(select account_id from public.commercial_controls where company_id=cid and key='REVENUE'),'cost_of_sales',(select account_id from public.commercial_controls where company_id=cid and key='COGS'));end;$$;
revoke all on function public.read_statement_controls(uuid)from public,anon,authenticated,service_role;
grant execute on function public.read_statement_controls(uuid)to authenticated;

create or replace function private.normalize_commercial_input(v jsonb)returns jsonb language plpgsql immutable set search_path='' as $$
declare k text;s text;begin
 if jsonb_typeof(v)is distinct from 'object'then raise exception 'Object input required'using errcode='22023';end if;
 for k in select jsonb_object_keys(v)loop
 if jsonb_typeof(v->k)='string'then v:=jsonb_set(v,array[k],to_jsonb(btrim(v->>k)));end if;
 if k in('amount_minor','vat_minor','residual_minor','proceeds_minor')then v:=jsonb_set(v,array[k],to_jsonb((v->>k)::bigint::text));
 elsif k in('life_months','vat_rate_bps')then v:=jsonb_set(v,array[k],to_jsonb((v->>k)::integer));
 elsif k in('stock_event_id','return_event_id','party_id','project_id','treasury_id','parent_id','related_id')then s:=nullif(v->>k,'');if s is null then v:=v-k;else v:=jsonb_set(v,array[k],to_jsonb(s::uuid::text));end if;
 elsif k in('date','due_date','service_date')then if coalesce(v->>k,'')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'then raise exception 'Unambiguous ISO calendar date required'using errcode='22023';end if;v:=jsonb_set(v,array[k],to_jsonb((v->>k)::date::text));
 elsif k='recognition_confirmed'then v:=jsonb_set(v,array[k],to_jsonb((v->>k)::boolean));end if;end loop;return v;end;$$;


create or replace function public.command_annual_closing(cid uuid,request_id uuid,action text,input jsonb)returns jsonb language plpgsql volatile security definer set search_path='' as $$
#variable_conflict use_variable
declare actor uuid;h text;prior public.accounting_year_events;y public.accounting_fiscal_years;c public.accounting_year_closures;p public.accounting_fiscal_periods;
 r record;lines jsonb:='[]';net numeric:=0;n bigint;j uuid;did uuid:=gen_random_uuid();retained uuid;result jsonb;begin
 actor:=private.operational_finance_actor(cid,'account.manage');
 if not public.has_company_role(cid,'ACCOUNTING_ADMIN')or not public.has_permission(cid,'payroll.manage')then raise exception 'Accounting Admin with full ledger access required'using errcode='42501';end if;
 if action='REOPEN'then perform private.operational_finance_actor(cid,'accounting.reverse');end if;
 if request_id is null or action is null or action not in('FINALIZE','REOPEN')or jsonb_typeof(input)is distinct from 'object'or octet_length(input::text)>10000 or exists(select 1 from jsonb_object_keys(input)x where x not in('year_id','version','reason','reconciliation_reference','confirm_reconciled'))or coalesce(length(btrim(input->>'reason')),0)not between 5 and 1000 or coalesce(length(btrim(input->>'reconciliation_reference')),0)not between 5 and 1000 or (input->>'confirm_reconciled')::boolean is distinct from true then raise exception 'Audited year action and full reconciliation evidence required'using errcode='23514';end if;
 perform private.fiscal_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'action',action,'input',input)::text,'UTF8'),'sha256'),'hex');
 select *into prior from public.accounting_year_events where company_id=cid and accounting_year_events.request_id=command_annual_closing.request_id;
 if prior.id is not null then if prior.request_hash<>h then raise exception 'Changed annual request'using errcode='23505';end if;return prior.result;end if;
 select *into y from public.accounting_fiscal_years where company_id=cid and id=(input->>'year_id')::uuid for update;
 if y.id is null or y.through_date>current_date then raise exception 'Completed configured fiscal year required'using errcode='23514';end if;
 select *into c from public.accounting_year_closures where company_id=cid and year_id=y.id for update;
 if coalesce(c.version,0)is distinct from(input->>'version')::integer then raise exception 'Year version changed; refresh'using errcode='40001';end if;
 select *into p from public.accounting_fiscal_periods where company_id=cid and year_id=y.id and through_date=y.through_date for update;
 if p.id is null then raise exception 'Final period missing'using errcode='23514';end if;
 if action='FINALIZE'then
 if exists(select 1 from public.inventory_events e where e.company_id=cid and e.state='POSTED'and e.snapshot->>'kind'='ISSUE'and e.snapshot->>'cost_purpose'='SALE'and(e.snapshot->>'date')::date<=y.through_date and(private.inventory_current(cid,e.document_id)).id=e.id and not exists(select 1 from public.commercial_documents d where d.company_id=cid and d.stock_event_id=e.id)and coalesce((select sum((return_event.snapshot->'computed'->>'qty')::numeric)from public.inventory_events return_event where return_event.company_id=cid and return_event.state='POSTED'and return_event.snapshot->>'kind'='RETURN'and return_event.snapshot->>'origin_id'=e.document_id::text and(private.inventory_current(cid,return_event.document_id)).id=return_event.id),0)<(e.snapshot->'computed'->>'qty')::numeric)then raise exception 'Unbilled sales delivery remains: link the actual customer invoice or resolve the physical event before year finalization'using errcode='23514';end if;
 if c.state='FINAL'or exists(select 1 from public.accounting_fiscal_periods where company_id=cid and year_id=y.id and state<>'CLOSED')then raise exception 'Reconcile and close all periods before finalizing the year'using errcode='23514';end if;
 if exists(select 1 from public.journal_lines l join public.journal_entries e on e.company_id=l.company_id and e.id=l.journal_entry_id join public.accounts a on a.company_id=l.company_id and a.id=l.account_id where l.company_id=cid and e.posting_date<y.from_date and a.account_type::text in('REVENUE','EXPENSE')group by l.account_id having sum(l.debit_minor-l.credit_minor)<>0)then raise exception 'Close prior unclosed results before this fiscal year'using errcode='23514';end if;
 if exists(select 1 from public.accounting_fiscal_years yy join public.accounting_year_closures cc on cc.company_id=yy.company_id and cc.year_id=yy.id where yy.company_id=cid and yy.from_date>y.through_date and cc.state='FINAL')then raise exception 'Later year already final; reopen later years first'using errcode='23514';end if;
 lines:=private.annual_close_plan(cid,y.id);
 -- A zero-turnover year has no invented zero journal; the audited lock still applies.
 if jsonb_array_length(lines)>0 then
 update public.accounting_fiscal_periods set state='OPEN'where company_id=cid and id=p.id;
 j:=private.create_journal(cid,y.through_date,'Annual closing — '||y.label,'ANNUAL_CLOSE',did,'CLOSING',lines,actor);
 update public.accounting_fiscal_periods set state='CLOSED'where company_id=cid and id=p.id;end if;
 insert into public.accounting_year_closures(company_id,year_id,state,journal_id,version)values(cid,y.id,'FINAL',j,1)on conflict(company_id,year_id)do update set state='FINAL',journal_id=excluded.journal_id,version=accounting_year_closures.version+1;
 else
 if c.state is distinct from 'FINAL'then raise exception 'Year is not final'using errcode='23514';end if;
 -- Reopening prior balances after later-year posting is deliberately not implicit.
 if exists(select 1 from public.journal_entries where company_id=cid and posting_date>y.through_date)then raise exception 'Later-year financial activity exists; controlled subsequent-year correction required'using errcode='23514';end if;
 update public.accounting_year_closures set state='OPEN',version=version+1 where company_id=cid and year_id=y.id;
 update public.accounting_fiscal_periods set state='OPEN',version=version+1 where company_id=cid and id=p.id;
 if c.journal_id is not null then j:=private.reverse_journal(c.journal_id,y.through_date,btrim(input->>'reason'),actor);end if;
 end if;
 result:=jsonb_build_object('year_id',y.id,'state',case when action='FINALIZE'then 'FINAL'else 'OPEN'end,'journal_id',j,'version',coalesce(c.version,0)+1);
 insert into public.accounting_year_events(id,company_id,year_id,request_id,action,request_hash,reason,reconciliation_reference,journal_id,result,actor)values(did,cid,y.id,request_id,action,h,btrim(input->>'reason'),btrim(input->>'reconciliation_reference'),j,result,actor);return result;
end;$$;


create or replace function public.configure_commercial_accounting(cid uuid,request_id uuid,input jsonb)returns jsonb language plpgsql volatile security definer set search_path='' as $$
#variable_conflict use_variable
declare actor uuid;h text;r public.commercial_setup_events;k text;a public.accounts;p uuid;result jsonb;begin
 actor:=private.operational_finance_actor(cid,'account.manage');if not public.has_company_role(cid,'ACCOUNTING_ADMIN')then raise exception 'Accounting Admin required'using errcode='42501';end if;
 if request_id is null or jsonb_typeof(input)is distinct from 'object'or octet_length(input::text)>10000 or coalesce(length(btrim(input->>'evidence')),0)not between 5 and 1000 or exists(select 1 from jsonb_object_keys(input)x where x not in('controls','customer_id','evidence'))then raise exception 'Invalid audited setup'using errcode='22023';end if;
 perform private.serialize_operational_finance(cid,'OPERATIONS');h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'input',input)::text,'UTF8'),'sha256'),'hex');
 select *into r from public.commercial_setup_events where company_id=cid and commercial_setup_events.request_id=configure_commercial_accounting.request_id;
 if r.id is not null then if r.request_hash<>h then raise exception 'Changed setup request'using errcode='23505';end if;return r.result;end if;
 if input?'controls'then
 if jsonb_typeof(input->'controls')is distinct from 'object'then raise exception 'Invalid controls'using errcode='22023';end if;
 for k in select jsonb_object_keys(input->'controls')loop
 if private.commercial_control_type(k)is null then raise exception 'Unsupported control %',k using errcode='22023';end if;
 select *into a from public.accounts where company_id=cid and id=(input->'controls'->>k)::uuid;
 if a.id is null or a.status::text<>'ACTIVE'or a.account_type::text<>private.commercial_control_type(k)or a.requires_party<>(k in('AR','CUSTOMER_ADVANCE'))then raise exception 'Invalid typed control %',k using errcode='23514';end if;
 if exists(select 1 from public.commercial_controls where company_id=cid and key=k and account_id<>a.id)then raise exception 'Control already mapped; explicit accounting migration required'using errcode='23514';end if;
 -- No adopting an unexplained historical balance into a new subledger.
 if k in('AR','CUSTOMER_ADVANCE')and not exists(select 1 from public.commercial_controls where company_id=cid and key=k)and exists(select 1 from public.journal_lines where company_id=cid and account_id=a.id)then raise exception 'Historical control requires reconciled opening workflow'using errcode='23514';end if;
 if not exists(select 1 from public.commercial_controls where company_id=cid and key=k)and(a.system_key is not null or exists(select 1 from public.journal_lines where company_id=cid and account_id=a.id)or exists(select 1 from public.treasury_accounts where company_id=cid and gl_account_id=a.id)or exists(select 1 from public.inventory_configuration where company_id=cid and a.id in(inventory_account_id,grni_account_id,variance_account_id,opening_account_id))or exists(select 1 from public.supplier_advance_configuration where company_id=cid and account_id=a.id)or exists(select 1 from public.hr_payroll_setup_events where company_id=cid and advance_account_id=a.id)or exists(select 1 from public.operational_liability_configuration where company_id=cid and account_id=a.id))then raise exception 'Dedicated unused unreserved control required; historical adoption needs a separately reviewed accounting cutover'using errcode='23514';end if;
 insert into public.commercial_controls values(cid,k,a.id)on conflict(company_id,key)do nothing;
 end loop;end if;
 if input?'customer_id'then p:=(input->>'customer_id')::uuid;
 if not exists(select 1 from public.parties where company_id=cid and id=p and status::text='ACTIVE')then raise exception 'Active existing Company Party required; reuse the identity when enabling a customer role'using errcode='23514';end if;
 insert into public.customer_accounts values(cid,p,actor,input->>'evidence')on conflict do nothing;end if;
 result:=jsonb_build_object('configured',true);insert into public.commercial_setup_events(company_id,request_id,request_hash,input,result,actor)values(cid,request_id,h,input,result,actor);return result;
end;$$;


-- Cash scope is real Treasury GL accounts, with Custody eligible only by explicit physical-cash policy.
create function public.read_cash_flow_controls(cid uuid)returns jsonb language plpgsql stable security invoker set search_path='' as $$
begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'MANAGEMENT_VIEWER'))then raise exception 'Cash-flow control access denied'using errcode='42501';end if;
 return jsonb_build_object('treasury_accounts',coalesce((select jsonb_agg(gl_account_id)from public.treasury_accounts where company_id=cid),'[]'::jsonb),'custody_account',(select id from public.accounts where company_id=cid and system_key='CUSTODY_ADVANCE'));
end;$$;
revoke all on function public.read_cash_flow_controls(uuid)from public,anon,authenticated,service_role;
grant execute on function public.read_cash_flow_controls(uuid)to authenticated;

create function private.commercial_bank(cid uuid,t uuid,d date,n bigint,outflow boolean,expected_project uuid)returns uuid language plpgsql volatile set search_path='' as $$
declare aid uuid;begin
 aid:=private.commercial_bank(cid,t,d,n,outflow);
 if exists(select 1 from public.treasury_accounts where company_id=cid and id=t and project_id is not null and project_id is distinct from expected_project)then raise exception 'Project Treasury must match the business document Project'using errcode='23514';end if;return aid;end;$$;
revoke all on function private.commercial_bank(uuid,uuid,date,bigint,boolean,uuid)from public,anon,authenticated,service_role;

create or replace function private.recognition_plan(cid uuid,kind text,v jsonb)returns jsonb language plpgsql volatile set search_path='' as $$
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
 bank:=private.commercial_bank(cid,t,d,n,true,project);
 lines:=jsonb_build_array(private.commercial_line(private.commercial_account(cid,case when kind='ASSET_CAPITALIZE'then 'ASSET_COST'else 'PREPAYMENT'end),n,false,null,project),private.commercial_line(bank,n,true,null,project,t));
 elsif kind='ACCRUAL_RECOGNIZE'then
 lines:=jsonb_build_array(private.commercial_line(private.commercial_account(cid,'ACCRUAL_EXPENSE'),n,false,null,project),private.commercial_line(private.commercial_account(cid,'ACCRUED_LIABILITY'),n,true,null,project));
 else
 select *into parent from public.commercial_documents where company_id=cid and id=(v->>'parent_id')::uuid for update;
 if parent.id is null or parent.date>d or parent.project_id is distinct from project or exists(select 1 from public.commercial_documents where company_id=cid and parent_id=parent.id and commercial_documents.kind='ASSET_DISPOSE')then raise exception 'Available same-Project original document required'using errcode='23514';end if;
 select coalesce(sum(amount_minor),0)::bigint,count(*)::integer into used,sequence from public.commercial_documents where company_id=cid and parent_id=parent.id;
 if kind='ACCRUAL_SETTLE'then
 if parent.kind<>'ACCRUAL_RECOGNIZE'or n>parent.amount_minor-used then raise exception 'Settlement exceeds accrued liability'using errcode='23514';end if;
 bank:=private.commercial_bank(cid,t,d,n,true,project);lines:=jsonb_build_array(private.commercial_line(private.commercial_account(cid,'ACCRUED_LIABILITY'),n,false,null,project),private.commercial_line(bank,n,true,null,project,t));
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
 if proceeds>0 then bank:=private.commercial_bank(cid,t,d,proceeds,false,project);lines:=lines||jsonb_build_array(private.commercial_line(bank,proceeds,false,null,project,t));end if;
 if proceeds>parent.amount_minor-used then lines:=lines||jsonb_build_array(private.commercial_line(private.commercial_account(cid,'DISPOSAL_GAIN'),proceeds-parent.amount_minor+used,true,null,project));
 elsif proceeds<parent.amount_minor-used then lines:=lines||jsonb_build_array(private.commercial_line(private.commercial_account(cid,'DISPOSAL_LOSS'),parent.amount_minor-used-proceeds,false,null,project));end if;
 end if;end if;
 return jsonb_build_object('lines',lines,'amount',n);
end;$$;
