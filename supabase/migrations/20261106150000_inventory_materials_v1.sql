-- 88: perpetual moving-average stock subledger; canonical GL commands only. No backfill.
create table public.inventory_configuration(
 company_id uuid primary key references public.companies(id),method text not null check(method='MOVING_AVERAGE_LOCATION'),
 inventory_account_id uuid not null,grni_account_id uuid not null,variance_account_id uuid not null,opening_account_id uuid not null,
 evidence text not null,created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 foreign key(company_id,inventory_account_id)references public.accounts(company_id,id),foreign key(company_id,grni_account_id)references public.accounts(company_id,id),
 foreign key(company_id,variance_account_id)references public.accounts(company_id,id),foreign key(company_id,opening_account_id)references public.accounts(company_id,id)
);
create table public.inventory_materials(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),code text not null,name text not null,category text not null,
 base_unit text not null,conversions jsonb not null default '{}',active boolean not null default true,reorder_micros bigint not null default 0 check(reorder_micros>=0),version integer not null default 1,
 unique(company_id,id),unique(company_id,code)
);
create table public.inventory_locations(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),code text not null,name text not null,project_id uuid,active boolean not null default true,version integer not null default 1,
 unique(company_id,id),unique(company_id,code),foreign key(company_id,project_id)references public.projects(company_id,id)
);
create table public.inventory_events(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),document_id uuid not null,version integer not null,
 request_id uuid not null,request_hash text not null,action text not null,state text not null check(state in('DRAFT','REVIEWED','POSTED','REVERSED','CANCELLED','RECORDED')),
 snapshot jsonb not null,reference text,journal_id uuid,created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id),unique(company_id,document_id,version),unique(company_id,request_id),foreign key(company_id,journal_id)references public.journal_entries(company_id,id)
);
create table public.inventory_movements(
 id uuid primary key default gen_random_uuid(),company_id uuid not null,event_id uuid not null,material_id uuid not null,location_id uuid not null,
 quantity_micros bigint not null,value_minor bigint not null,movement_date date not null,
 foreign key(company_id,event_id)references public.inventory_events(company_id,id),foreign key(company_id,material_id)references public.inventory_materials(company_id,id),foreign key(company_id,location_id)references public.inventory_locations(company_id,id),
 check(quantity_micros<>0),check((quantity_micros>0 and value_minor>=0)or(quantity_micros<0 and value_minor<=0))
);
create index inventory_stock_lookup on public.inventory_movements(company_id,material_id,location_id);
create unique index inventory_receiving_reference on public.inventory_events(company_id,lower(btrim(snapshot->>'source_reference')))where state='POSTED'and snapshot->>'kind'in('RECEIPT','OPENING');
create table public.inventory_purchase_links(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),material_id uuid not null,source_id uuid,expense_id uuid,
 reference text not null,evidence text not null,created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 foreign key(company_id,material_id)references public.inventory_materials(company_id,id),foreign key(company_id,source_id)references public.historical_source_records(company_id,id),foreign key(company_id,expense_id)references public.expenses(company_id,id),check(source_id is not null or expense_id is not null)
);
create function private.inventory_reader(cid uuid)returns boolean language sql stable security definer set search_path=''as $$
 select auth.uid()is not null and(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'MANAGEMENT_VIEWER')or public.has_company_role(cid,'PROCUREMENT'))
$$;
revoke all on function private.inventory_reader(uuid)from public,anon,authenticated,service_role;
-- Policies use existing public membership helpers; the private helper remains uncallable by browsers.
do $$declare t text;begin foreach t in array array['inventory_configuration','inventory_materials','inventory_locations','inventory_events','inventory_movements','inventory_purchase_links']loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);execute format('grant select on public.%I to authenticated',t);
 execute format('create policy inventory_read on public.%I for select to authenticated using(public.has_company_role(company_id,''ACCOUNTING_ADMIN'')or public.has_company_role(company_id,''ACCOUNTANT'')or public.has_company_role(company_id,''MANAGEMENT_VIEWER'')or public.has_company_role(company_id,''PROCUREMENT''))',t);
 if t not in('inventory_materials','inventory_locations')then execute format('create trigger inventory_immutable before update or delete on public.%I for each row execute function private.financial_evidence_immutable()',t);end if;
end loop;end$$;
create function private.inventory_balance(cid uuid,mid uuid,lid uuid)returns jsonb language sql stable set search_path=''as $$
 select jsonb_build_object('qty',coalesce(sum(quantity_micros::numeric),0)::text,'value',coalesce(sum(value_minor::numeric),0)::text,'revision',count(*),'last_date',max(movement_date))from public.inventory_movements where company_id=cid and material_id=mid and location_id=lid
$$;
revoke all on function private.inventory_balance(uuid,uuid,uuid)from public,anon,authenticated,service_role;
create function private.inventory_current(cid uuid,did uuid)returns public.inventory_events language sql stable set search_path=''as $$
 select e from public.inventory_events e where e.company_id=cid and e.document_id=did order by version desc limit 1
$$;
revoke all on function private.inventory_current(uuid,uuid)from public,anon,authenticated,service_role;

create function private.inventory_plan(cid uuid,v jsonb)returns jsonb language plpgsql set search_path=''as $$
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
 if kind='ISSUE'then select id into cost from public.accounts where company_id=cid and system_key=(case when project is null then 'COMPANY_EXPENSE'else 'PROJECT_COST'end)::public.system_account_key and account_type='EXPENSE'and status='ACTIVE';if cost is null then raise exception 'Canonical Project cost mapping required'using errcode='23514';end if;end if;
 return(v-'computed')||jsonb_build_object('computed',jsonb_build_object('qty',qty::bigint::text,'value',amount::bigint::text,'balance',b,'destination_balance',db,'material_version',m.version,'location_version',l.version,'destination_version',dest.version,'project',project,'cost',cost,'cost_project',cost_project));
end$$;
revoke all on function private.inventory_plan(uuid,jsonb)from public,anon,authenticated,service_role;

create function public.command_inventory(cid uuid,request_id uuid,action text,input jsonb)returns jsonb
language plpgsql volatile security definer set search_path=''as $$
#variable_conflict use_variable
declare actor uuid;admin boolean;h text;k text;v jsonb:=input;old public.inventory_events;e public.inventory_events;cfg public.inventory_configuration;m public.inventory_materials;l public.inventory_locations;
 did uuid;version integer;state text;ref text;j uuid;lines jsonb:='[]';qty bigint;amount bigint;mid uuid;lid uuid;other uuid;cost uuid;project uuid;original public.inventory_events;x record;aid uuid;typ public.account_type;party boolean;ids uuid[]:='{}';conv jsonb;ratio jsonb;existing_qty numeric;value_now numeric;expected numeric;sum_value numeric;
begin
 actor:=private.operational_finance_actor(cid,'accounting.post');admin:=public.has_company_role(cid,'ACCOUNTING_ADMIN');
 perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');perform pg_advisory_xact_lock(hashtextextended('inventory:'||cid::text,0));
 if request_id is null or action is null or action not in('SETUP','MATERIAL','LOCATION','SAVE','REVIEW','POST','REVERSE','CANCEL','LINK_PURCHASE')or jsonb_typeof(v)is distinct from 'object'or octet_length(v::text)>16000 then raise exception 'Supported inventory command and bounded business inputs required'using errcode='22023';end if;
 for k in select jsonb_object_keys(v)loop
  if k<>all(array['id','version','code','name','category','base_unit','conversions','active','reorder_micros','project_id','inventory_account_id','grni_account_id','variance_account_id','opening_account_id','inventory_code','inventory_name','grni_code','grni_name','variance_code','variance_name','opening_code','opening_name','evidence','kind','date','material_id','location_id','destination_id','recipient_id','supplier_id','expense_id','source_id','origin_id','qty_micros','unit','value_minor','recognition','source_reference','physically_counted','not_previously_recognized','invoice_number','original_invoice','vat_mode','manual_vat_minor','expense_category_id'])then raise exception 'Unsupported input; callers cannot supply journal lines or GL accounts in documents'using errcode='22023';end if;
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
revoke all on function public.command_inventory(uuid,uuid,text,jsonb)from public,anon,authenticated,service_role;
grant execute on function public.command_inventory(uuid,uuid,text,jsonb)to authenticated;

create unique index inventory_purchase_reference_once on public.inventory_purchase_links(company_id,material_id,coalesce(source_id::text,''),coalesce(expense_id::text,''));
create function private.guard_inventory_cost_dependency()returns trigger language plpgsql security definer set search_path=''as $$
declare expense uuid;begin
 if tg_table_name='expenses'then
  if new.status=old.status then return new;end if;expense:=old.id;
 else expense:=new.expense_id;end if;
 perform private.serialize_operational_finance(new.company_id,'OPERATIONS');perform pg_advisory_xact_lock(hashtextextended('inventory:'||new.company_id::text,0));
 if exists(select 1 from public.inventory_events e where e.company_id=new.company_id and e.state='POSTED'and e.snapshot->>'expense_id'=expense::text and e.snapshot->>'kind'in('RECEIPT','MATCH','INVOICE')and not exists(select 1 from public.inventory_events r where r.company_id=e.company_id and r.document_id=e.document_id and r.state='REVERSED'))then raise exception 'Inventory capitalization depends on this cost; reverse dependent stock/invoice match first'using errcode='23514';end if;
 return new;
end$$;
revoke all on function private.guard_inventory_cost_dependency()from public,anon,authenticated,service_role;
create trigger inventory_expense_dependency before update of status on public.expenses for each row execute function private.guard_inventory_cost_dependency();
create trigger inventory_allocation_dependency before insert on public.project_cost_corrections for each row execute function private.guard_inventory_cost_dependency();
create function private.guard_inventory_project_close()returns trigger language plpgsql security definer set search_path=''as $$
begin
 if new.status='CLOSED'and old.status<>'CLOSED'and exists(select 1 from public.inventory_movements s join public.inventory_locations l on l.company_id=s.company_id and l.id=s.location_id where s.company_id=new.company_id and l.project_id=new.id group by s.material_id,s.location_id having sum(s.quantity_micros::numeric)<>0)then raise exception 'Transfer remaining Project-store stock before administrative Project closure'using errcode='23514';end if;return new;
end$$;
revoke all on function private.guard_inventory_project_close()from public,anon,authenticated,service_role;
create trigger inventory_project_close before update of status on public.projects for each row execute function private.guard_inventory_project_close();

create function public.read_inventory(cid uuid)returns jsonb language plpgsql stable security definer set search_path=''as $$
declare r jsonb;stock_value numeric;gl_value numeric;begin
 if not private.inventory_reader(cid)then raise exception 'Company inventory read denied'using errcode='42501';end if;
 select coalesce(sum(value_minor::numeric),0)into stock_value from public.inventory_movements where company_id=cid;
 select coalesce(sum(l.debit_minor::numeric-l.credit_minor::numeric),0)into gl_value from public.journal_lines l join public.inventory_configuration c on c.company_id=l.company_id and c.inventory_account_id=l.account_id where l.company_id=cid;
 if stock_value<>gl_value or exists(select 1 from public.inventory_movements where company_id=cid group by material_id,location_id having sum(quantity_micros::numeric)<0 or sum(value_minor::numeric)<0)then raise exception 'Inventory GL/quantity reconciliation failed; no balance assumed'using errcode='23514';end if;
 select jsonb_build_object('company_id',cid,'today',current_date,'valuation_method','MOVING_AVERAGE_LOCATION','configuration',(select to_jsonb(c)from public.inventory_configuration c where company_id=cid),
 'period_open',exists(select 1 from public.project_correction_period_events where company_id=cid and month=date_trunc('month',current_date)::date and state='OPEN')and not exists(select 1 from public.project_correction_period_events where company_id=cid and month=date_trunc('month',current_date)::date and state='CLOSED'),
 'materials',(select coalesce(jsonb_agg(to_jsonb(m)||jsonb_build_object('reorder_micros',m.reorder_micros::text)order by code),'[]')from public.inventory_materials m where company_id=cid),
 'locations',(select coalesce(jsonb_agg(to_jsonb(l)order by code),'[]')from public.inventory_locations l where company_id=cid),
 'events',(select coalesce(jsonb_agg(to_jsonb(e)order by created_at,id),'[]')from public.inventory_events e where company_id=cid),
 'documents',(select coalesce(jsonb_agg(to_jsonb(e)||case when e.snapshot->>'kind'='INVOICE'then jsonb_build_object('invoice',(select jsonb_build_object('id',x.id,'reference',x.expense_reference,'journal_id',x.posted_journal_entry_id,'reversal_journal_id',x.reversal_journal_entry_id,'status',x.status)from public.expenses x where x.company_id=cid and x.id=nullif(e.snapshot->>'expense_id','')::uuid))else '{}'::jsonb end order by e.created_at,e.id),'[]')from(select distinct on(document_id)*from public.inventory_events where company_id=cid and state<>'RECORDED'order by document_id,version desc)e),
 'movements',(select coalesce(jsonb_agg(to_jsonb(m)||jsonb_build_object('quantity_micros',m.quantity_micros::text,'value_minor',m.value_minor::text)order by m.created_at,m.id),'[]')from(select s.*,e.created_at from public.inventory_movements s join public.inventory_events e on e.company_id=s.company_id and e.id=s.event_id where s.company_id=cid)m),
 'links',(select coalesce(jsonb_agg(to_jsonb(l)order by created_at,id),'[]')from public.inventory_purchase_links l where company_id=cid),
 'balances',(select coalesce(jsonb_agg(to_jsonb(b)order by material_id,location_id),'[]')from(select material_id,location_id,sum(quantity_micros::numeric)::text quantity_micros,sum(value_minor::numeric)::text value_minor,count(*) revision from public.inventory_movements where company_id=cid group by material_id,location_id)b),
 'purchase_sources',case when public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')then(select coalesce(jsonb_agg(jsonb_build_object('id',s.id,'company_id',s.company_id,'reference',s.source_reference,'date',s.source_date,'description',s.description,'status',s.review_status,'expense_id',s.expense_id)order by s.source_date,s.id),'[]')from public.historical_source_records s where s.company_id=cid and s.record_type='GENERAL'and coalesce(s.completion->>'nature',s.classification->>'nature','NEEDS_REVIEW')in('EXPENSE','SUPPLIER_INVOICE_OR_COMMITMENT','NEEDS_REVIEW'))else '[]'::jsonb end,
 'purchase_expenses',case when public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')then(select coalesce(jsonb_agg(jsonb_build_object('id',x.id,'company_id',x.company_id,'reference',x.expense_reference,'date',x.expense_date,'status',x.status,'net_minor',x.net_amount_minor::text)order by x.expense_date,x.id),'[]')from public.expenses x where x.company_id=cid)else '[]'::jsonb end,
 'stock_value_minor',stock_value::text,'gl_value_minor',gl_value::text)into r;return r;
end$$;
revoke all on function public.read_inventory(uuid)from public,anon,authenticated,service_role;
grant execute on function public.read_inventory(uuid)to authenticated;

create function private.guard_inventory_master_history()returns trigger language plpgsql security definer set search_path=''as $$
begin
 if tg_table_name='inventory_materials'then
  if exists(select 1 from public.inventory_movements where company_id=old.company_id and material_id=old.id)and(new.company_id<>old.company_id or new.code<>old.code or new.base_unit<>old.base_unit or new.conversions<>old.conversions)then raise exception 'Used stock identity/unit history is immutable'using errcode='23514';end if;
 else
  if exists(select 1 from public.inventory_movements where company_id=old.company_id and location_id=old.id)and(new.company_id<>old.company_id or new.code<>old.code or new.project_id is distinct from old.project_id)then raise exception 'Used warehouse Company/Project identity is immutable'using errcode='23514';end if;
 end if;return new;
end$$;
revoke all on function private.guard_inventory_master_history()from public,anon,authenticated,service_role;
create trigger inventory_material_history before update on public.inventory_materials for each row execute function private.guard_inventory_master_history();
create trigger inventory_location_history before update on public.inventory_locations for each row execute function private.guard_inventory_master_history();
