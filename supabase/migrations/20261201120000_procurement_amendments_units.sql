--113: issued order revisions and approved purchase/base quantity conversion.
-- No backfill, financial invocation or Company setup changes.
create function private.uom_kind(u text)returns text language sql immutable set search_path=''as $$select case lower(btrim(u))
 when 'unit'then 'COUNT' when 'piece'then 'COUNT' when 'pieces'then 'COUNT' when 'pcs'then 'COUNT' when 'pack'then 'COUNT' when 'ea'then 'COUNT' when 'box'then 'COUNT' when 'carton'then 'COUNT' when 'علبة'then 'COUNT' when 'كرتون'then 'COUNT' when 'قطعة'then 'COUNT'
 when 'm'then 'LENGTH' when 'meter'then 'LENGTH' when 'metre'then 'LENGTH' when 'cm'then 'LENGTH' when 'centimeter'then 'LENGTH' when 'mm'then 'LENGTH' when 'متر'then 'LENGTH' when 'سم'then 'LENGTH'
 when 'kg'then 'MASS' when 'kilogram'then 'MASS' when 'ton'then 'MASS' when 'tonne'then 'MASS' when 'g'then 'MASS' when 'كيلوغرام'then 'MASS' when 'طن'then 'MASS'
 when 'l'then 'VOLUME' when 'liter'then 'VOLUME' when 'ml'then 'VOLUME' when 'لتر'then 'VOLUME' else null end$$;
create function private.uom_scale(u text)returns bigint language sql immutable set search_path=''as $$select case lower(btrim(u))when 'unit'then 1 when 'piece'then 1 when 'pieces'then 1 when 'pcs'then 1 when 'ea'then 1 when 'قطعة'then 1 when 'm'then 1000 when 'meter'then 1000 when 'metre'then 1000 when 'متر'then 1000 when 'cm'then 10 when 'centimeter'then 10 when 'سم'then 10 when 'mm'then 1 when 'kg'then 1000 when 'kilogram'then 1000 when 'كيلوغرام'then 1000 when 'ton'then 1000000 when 'tonne'then 1000000 when 'طن'then 1000000 when 'g'then 1 when 'l'then 1000 when 'liter'then 1000 when 'لتر'then 1000 when 'ml'then 1 else null end$$;
create function private.uom_quantity(cid uuid,mid uuid,u text,q text)returns bigint language plpgsql stable set search_path=''as $$
declare m public.inventory_materials;n numeric;ratio jsonb;begin
 select *into m from public.inventory_materials where company_id=cid and id=mid;
 if m.id is null or coalesce(q,'')!~'^[0-9]{1,16}$'then raise exception 'UOM_QUANTITY: select material and exact quantity'using errcode='23514';end if;n:=q::numeric;
 if u is distinct from m.base_unit then
 ratio:=m.conversions->u;
 if ratio is null then raise exception 'UOM_APPROVAL: select an approved material unit'using errcode='23514';end if;
 n:=n*(ratio->>'numerator')::numeric/(ratio->>'denominator')::numeric;
 end if;
 if n<>trunc(n)or n<0 or n>9000000000000000 then raise exception 'UOM_PRECISION: quantity must convert exactly to base micro-units'using errcode='23514';end if;return n::bigint;
end$$;
-- Validate new ratios without changing historical definitions. Additions are safe; old ratios stay immutable.
create function private.guard_material_units()returns trigger language plpgsql security definer set search_path=''as $$
declare k text;r jsonb;dim text;begin
 if tg_op='UPDATE'and exists(select 1 from public.purchase_order_events e cross join lateral jsonb_array_elements(e.snapshot->'lines')l where e.company_id=old.company_id and l->>'material_id'=old.id::text)and(new.base_unit<>old.base_unit or new.code<>old.code or not(new.conversions @> old.conversions))then raise exception 'UOM_HISTORY: ordered units cannot be redefined'using errcode='23514';end if;
 for k,r in select *from jsonb_each(new.conversions)loop
 if tg_op='UPDATE'and old.conversions->k=r then continue;end if;
 dim:=private.uom_kind(new.base_unit);
 if dim is null or dim is distinct from private.uom_kind(k)then raise exception 'UOM_DIMENSION: incompatible or unrecognized units'using errcode='23514';end if;
 if (dim<>'COUNT'or(private.uom_scale(new.base_unit)=1 and private.uom_scale(k)=1))and (r->>'numerator')::numeric*private.uom_scale(new.base_unit)<>(r->>'denominator')::numeric*private.uom_scale(k)then raise exception 'UOM_RATIO: metric ratio must match physical units'using errcode='23514';end if;
 end loop;return new;
end$$;
create trigger inventory_material_units before insert or update on public.inventory_materials for each row execute function private.guard_material_units();
do $$declare d text;begin
 d:=pg_get_functiondef('private.guard_inventory_master_history()'::regprocedure);d:=replace(d,'new.conversions<>old.conversions','not(new.conversions @> old.conversions)');execute d;
 d:=pg_get_functiondef('public.command_inventory(uuid,uuid,text,jsonb)'::regprocedure);d:=replace(d,'m.conversions<>conv','not(conv @> m.conversions)');execute d;
end$$;
-- Keep the original canonical validator; purchase quantities/prices remain visible alongside base quantities.
do $$declare d text;begin d:=pg_get_functiondef('private.purchase_order_snapshot(uuid,jsonb,boolean)'::regprocedure);execute replace(d,'private.purchase_order_snapshot(','private.pre113_purchase_order_snapshot(');end$$;
create or replace function private.purchase_order_snapshot(cid uuid,v jsonb,complete boolean)returns jsonb language plpgsql stable security definer set search_path=''as $$
declare l jsonb;items jsonb:='[]';originals jsonb:='[]';result jsonb;m public.inventory_materials;q bigint;amount numeric;total numeric:=0;i integer:=0;pu text;pq text;begin
 for l in select value from jsonb_array_elements(v->'lines')loop
 if l-array['number','amount_minor','material_id','description','unit','quantity_micros','unit_price_minor','purchase_unit','purchase_quantity_micros','conversion_numerator','conversion_denominator','cancelled','cancelled_quantity_micros']<>'{}'::jsonb then raise exception 'PO_LINES'using errcode='23514';end if;
 if coalesce(l->>'cancelled','false')not in('true','false')then raise exception 'PO_LINES'using errcode='23514';end if;pu:=coalesce(l->>'purchase_unit',l->>'unit');pq:=coalesce(l->>'purchase_quantity_micros',l->>'quantity_micros');
 if nullif(l->>'material_id','')is not null then
 select *into m from public.inventory_materials where company_id=cid and id=(l->>'material_id')::uuid and active;
 if not found then raise exception 'PO_MATERIAL'using errcode='23514';end if;
 q:=private.uom_quantity(cid,m.id,pu,pq);
 else q:=pq::bigint;end if;
 if coalesce(l->>'unit_price_minor','')!~'^[0-9]{1,16}$'or(l->>'unit_price_minor')::numeric>9000000000000000 then raise exception 'PO_AMOUNT'using errcode='23514';end if;items:=items||jsonb_build_array(jsonb_build_object('material_id',coalesce(l->>'material_id',''),'description',l->>'description','unit',case when nullif(l->>'material_id','')is not null then m.base_unit else pu end,'quantity_micros',q::text,'unit_price_minor','0'));
 originals:=originals||jsonb_build_array(jsonb_build_object('purchase_unit',pu,'purchase_quantity_micros',pq,'unit_price_minor',l->>'unit_price_minor','cancelled',coalesce(l->>'cancelled','false')));
 end loop;
 result:=private.pre113_purchase_order_snapshot(cid,v||jsonb_build_object('lines',items),false);items:='[]';
 for l in select value from jsonb_array_elements(result->'lines')loop
 amount:=round((originals->i->>'purchase_quantity_micros')::numeric*(originals->i->>'unit_price_minor')::numeric/1000000);total:=total+amount;
 if complete and((l->>'quantity_micros')::numeric<=0 and originals->i->>'cancelled'<>'true'or btrim(l->>'description')=''or btrim(l->>'unit')='')then raise exception 'PO_INCOMPLETE'using errcode='23514';end if;
 l:=l||(originals->i)||jsonb_build_object('amount_minor',amount::bigint::text);
 if l->>'material_id'is not null then select *into m from public.inventory_materials where company_id=cid and id=(l->>'material_id')::uuid;l:=l||jsonb_build_object('conversion_numerator',coalesce(m.conversions->(l->>'purchase_unit')->>'numerator','1'),'conversion_denominator',coalesce(m.conversions->(l->>'purchase_unit')->>'denominator','1'));end if;
 items:=items||jsonb_build_array(l);i:=i+1;
 end loop;
 if total>9000000000000000 or(complete and(result->>'supplier_id'is null or i=0 or(total<=0 and exists(select 1 from jsonb_array_elements(items) z where z->>'cancelled'<>'true'))))then raise exception 'PO_INCOMPLETE'using errcode='23514';end if;
 return result||jsonb_build_object('lines',items,'total_minor',total::bigint::text);
end$$;
-- Use canonical receipt quantities for history; only future receipts use amended prices.
do $$declare d text;begin
 d:=pg_get_functiondef('private.pre_multi_procurement_plan(uuid,text,jsonb,boolean)'::regprocedure);
 d:=replace(d,$text$'line_number','location_id','quantity_micros','reference'$text$,$text$'line_number','location_id','quantity_micros','unit','reference'$text$);
 d:=replace(d,$text$'receipt_id','quantity_micros','net_minor'$text$,$text$'receipt_id','quantity_micros','unit','net_minor'$text$);
 d:=replace(d,$text$qty:=(v->>'quantity_micros')::numeric;$text$,$text$qty:=private.uom_quantity(cid,(po_line->>'material_id')::uuid,coalesce(v->>'unit',po_line->>'unit'),v->>'quantity_micros');$text$);
 d:=replace(d,$text$sum((e.snapshot->>'quantity_micros')::numeric)$text$,$text$sum(((private.inventory_current(cid,(e.result->>'inventory_id')::uuid)).snapshot->'computed'->>'qty')::numeric)$text$);
 d:=replace(d,$text$'receipt_qty_micros',v->>'quantity_micros'$text$,$text$'receipt_qty_micros',private.uom_quantity(cid,(r.snapshot->>'material_id')::uuid,coalesce(v->>'unit',r.snapshot->>'unit'),v->>'quantity_micros')::text$text$);
 execute d;
 d:=pg_get_functiondef('private.procurement_plan(uuid,text,jsonb,boolean)'::regprocedure);d:=replace(d,$text$'line_number','location_id','quantity_micros'$text$,$text$'line_number','location_id','quantity_micros','unit'$text$);d:=replace(d,$text$'receipt_id','quantity_micros','net_minor'$text$,$text$'receipt_id','quantity_micros','unit','net_minor'$text$);execute d;
 d:=pg_get_functiondef('private.multi_invoice_plan(uuid,jsonb)'::regprocedure);d:=replace(d,$text$'receipt_id','quantity_micros','net_minor'$text$,$text$'receipt_id','quantity_micros','unit','net_minor'$text$);d:=replace(d,$text$x->>'quantity_micros',(v->>'date')::date$text$,$text$private.uom_quantity(cid,(r.snapshot->>'material_id')::uuid,coalesce(x->>'unit',r.snapshot->>'unit'),x->>'quantity_micros')::text,(v->>'date')::date$text$);execute d;
 d:=pg_get_functiondef('private.pre_multi_read_procurement(uuid,integer,integer)'::regprocedure);d:=replace(d,$text$sum((r.snapshot->>'quantity_micros')::numeric)$text$,$text$sum(((private.inventory_current(cid,(r.result->>'inventory_id')::uuid)).snapshot->'computed'->>'qty')::numeric)$text$);execute d;
end$$;
-- Append-only amendment drafts. Approved revisions become the next ISSUED event, never an update.
create table public.purchase_order_amendments(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),document_id uuid not null,po_id uuid not null,base_version integer not null,version integer not null,
 request_id uuid not null,request_hash text not null,state text not null check(state in('DRAFT','REVIEWED','APPROVED','CANCELLED')),reason text not null,snapshot jsonb not null,created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,document_id,version),unique(company_id,request_id));
alter table public.purchase_order_amendments enable row level security;
alter table public.purchase_order_amendments force row level security;
revoke all on public.purchase_order_amendments from public,anon,authenticated,service_role;
grant select on public.purchase_order_amendments to authenticated;
create policy po_amendment_read on public.purchase_order_amendments for select to authenticated using(public.has_company_role(company_id,'ACCOUNTING_ADMIN')or public.has_company_role(company_id,'ACCOUNTANT')or public.has_company_role(company_id,'PROCUREMENT')or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create trigger po_amendment_immutable before update or delete on public.purchase_order_amendments for each row execute function private.financial_evidence_immutable();
create function private.po_received(cid uuid,pid uuid,line_no integer)returns bigint language sql stable set search_path=''as $$
 select coalesce(sum(((private.inventory_current(cid,(x.result->>'inventory_id')::uuid)).snapshot->'computed'->>'qty')::numeric),0)::bigint from(select distinct on(document_id)*from public.procurement_events where company_id=cid order by document_id,version desc)x where x.kind='RECEIPT'and x.state='EXECUTED'and x.snapshot->>'po_id'=pid::text and x.snapshot->>'line_number'=line_no::text and(private.inventory_current(cid,(x.result->>'inventory_id')::uuid)).state='POSTED'
$$;
create function private.po_amendment_validate(cid uuid,o public.purchase_order_events,v jsonb)returns void language plpgsql set search_path=''as $$
declare l jsonb;prior jsonb;received bigint;reserved numeric;i integer:=0;e record;x jsonb;begin
 if v->>'supplier_id'is distinct from o.snapshot->>'supplier_id'or v->>'project_id'is distinct from o.snapshot->>'project_id'or v->>'date'is distinct from o.snapshot->>'date'or jsonb_array_length(v->'lines')<jsonb_array_length(o.snapshot->'lines')then raise exception 'PO_AMEND_IDENTITY: preserve supplier, Project, original date and line positions'using errcode='23514';end if;
 for l in select value from jsonb_array_elements(v->'lines')loop
 i:=i+1;prior:=o.snapshot->'lines'->(i-1);
 if prior is not null and(l->>'material_id'is distinct from prior->>'material_id'or l->>'unit'is distinct from prior->>'unit'or l->>'purchase_unit'is distinct from coalesce(prior->>'purchase_unit',prior->>'unit'))then raise exception 'PO_AMEND_IDENTITY: existing line material and units are fixed'using errcode='23514';end if;
 received:=private.po_received(cid,o.document_id,i);reserved:=0;
 -- Count every independent incomplete receipt, including grouped physical documents. Their execution revalidates after approval.
 for e in select *from(select distinct on(document_id)*from public.procurement_events where company_id=cid order by document_id,version desc)s where s.kind='RECEIPT'and s.state in('DRAFT','REVIEWED')and s.snapshot->>'po_id'=o.document_id::text loop
 if e.snapshot ?'receiving_lines'then
 for x in select value from jsonb_array_elements(e.snapshot->'receiving_lines')loop if x->>'line_number'=i::text then reserved:=reserved+private.uom_quantity(cid,(l->>'material_id')::uuid,coalesce(x->>'unit',l->>'unit'),x->>'quantity_micros');end if;end loop;
 elsif e.snapshot->>'line_number'=i::text then reserved:=reserved+private.uom_quantity(cid,(l->>'material_id')::uuid,coalesce(e.snapshot->>'unit',l->>'unit'),e.snapshot->>'quantity_micros');end if;
 end loop;
 if(l->>'quantity_micros')::numeric<received+reserved then raise exception 'PO_AMEND_QUANTITY: below received or reserved delivery quantities'using errcode='23514';end if;
 if l->>'cancelled'='true'and(l->>'quantity_micros')::bigint<>received then raise exception 'PO_AMEND_CANCEL: retain received quantity and cancel only the remaining balance'using errcode='23514';end if;
 end loop;
end$$;
-- Cancellation consumes no new quantity: preserve purchase-unit evidence and use exact received base units.
create function private.po_amendment_finish(cid uuid,o public.purchase_order_events,v jsonb)returns jsonb language plpgsql set search_path=''as $$
declare l jsonb;prior jsonb;items jsonb:='[]';i integer:=0;q bigint;n numeric;total numeric:=0;begin
 for l in select value from jsonb_array_elements(v->'lines')loop
 prior:=o.snapshot->'lines'->i;
 if l->>'cancelled'='true'then
 q:=private.po_received(cid,o.document_id,i+1);
 n:=round(q::numeric*(l->>'unit_price_minor')::numeric*coalesce((l->>'conversion_denominator')::numeric,1)/coalesce((l->>'conversion_numerator')::numeric,1)/1000000);
 l:=l||jsonb_build_object('quantity_micros',q::text,'purchase_quantity_micros',coalesce(prior->>'purchase_quantity_micros',prior->>'quantity_micros',l->>'purchase_quantity_micros'),'cancelled_quantity_micros',greatest(coalesce((prior->>'quantity_micros')::bigint,0)+coalesce((prior->>'cancelled_quantity_micros')::bigint,0)-q,0)::text,'amount_minor',n::bigint::text);
 end if;
 total:=total+(l->>'amount_minor')::numeric;items:=items||jsonb_build_array(l);i:=i+1;
 end loop;
 if total>9000000000000000 then raise exception 'PO_AMOUNT'using errcode='23514';end if;
 return v||jsonb_build_object('lines',items,'total_minor',total::bigint::text);
end$$;
create function public.command_purchase_order_amendment(cid uuid,request_id uuid,action text,input jsonb)returns jsonb language plpgsql security definer set search_path=''as $$
#variable_conflict use_variable
declare actor uuid:=auth.uid();o public.purchase_order_events;old public.purchase_order_amendments;prior public.purchase_order_amendments;did uuid;expected integer;h text;v jsonb;reason text;state text;base integer;pid uuid;begin
 if actor is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'PROCUREMENT'))then raise exception 'PO_DENIED'using errcode='42501';end if;
 if request_id is null or action is null or action not in('SAVE','REVIEW','APPROVE','CANCEL')or jsonb_typeof(input)is distinct from'object'or octet_length(input::text)>55000 then raise exception 'PO_INPUT'using errcode='22023';end if;
 perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 perform 1 from public.company_memberships m join public.profiles p on p.user_id=m.user_id join public.companies c on c.id=m.company_id where m.company_id=cid and m.user_id=actor and m.status='ACTIVE'and p.status='ACTIVE'and c.status='ACTIVE'and m.role in('ACCOUNTING_ADMIN','ACCOUNTANT','PROCUREMENT')for share of m,p,c;if not found then raise exception 'PO_DENIED'using errcode='42501';end if;
 did:=(input->>'id')::uuid;expected:=(input->>'version')::integer;if did is null or expected is null or expected<0 then raise exception 'PO_INPUT'using errcode='22023';end if;
 h:=encode(sha256(convert_to(jsonb_build_array(actor,action,input)::text,'UTF8')),'hex');select *into prior from public.purchase_order_amendments e where e.company_id=cid and e.request_id=command_purchase_order_amendment.request_id;
 if found then if prior.request_hash<>h then raise exception 'PO_REPLAY'using errcode='22023';end if;return jsonb_build_object('id',did,'version',prior.version,'state',prior.state,'replayed',true);end if;
 select *into old from public.purchase_order_amendments e where e.company_id=cid and e.document_id=did order by version desc limit 1;
 if coalesce(old.version,0)<>expected then raise exception 'PO_STALE'using errcode='40001';end if;
 if old.state in('APPROVED','CANCELLED')then raise exception 'PO_IMMUTABLE'using errcode='23514';end if;
 pid:=coalesce(old.po_id,(input->>'po_id')::uuid);select *into o from public.purchase_order_events where company_id=cid and document_id=pid order by version desc limit 1;base:=coalesce(old.base_version,(input->>'base_version')::integer);
 if action<>'CANCEL'and(o.id is null or o.state<>'ISSUED'or base is distinct from o.version)then raise exception 'PO_STALE'using errcode='40001';end if;
 if not(private.company_commercial_readiness(cid)->>'ready')::boolean then raise exception 'PO_SETUP'using errcode='42501';end if;
 if action='SAVE'then
 if input-array['id','version','po_id','base_version','reason','order']<>'{}'::jsonb then raise exception 'PO_INPUT'using errcode='22023';end if;
 reason:=btrim(input->>'reason');if coalesce(length(reason),0)not between 5 and 1000 then raise exception 'PO_REASON'using errcode='23514';end if;
 v:=private.po_amendment_finish(cid,o,private.purchase_order_snapshot(cid,input->'order',false));state:='DRAFT';
 else
 if input-array['id','version']<>'{}'::jsonb or old.id is null then raise exception 'PO_INPUT'using errcode='22023';end if;
 reason:=old.reason;v:=old.snapshot;
 if action='CANCEL'then state:='CANCELLED';
 else
 if(action='REVIEW'and old.state<>'DRAFT')or(action='APPROVE'and old.state<>'REVIEWED')then raise exception 'PO_STATE'using errcode='23514';end if;
 if action='APPROVE'and not((public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT'))and public.has_permission(cid,'accounting.post'))then raise exception 'PO_APPROVAL'using errcode='42501';end if;
 v:=private.po_amendment_finish(cid,o,private.purchase_order_snapshot(cid,(v-array['supplier_name','project_name','total_minor','currency','amount_basis']),true));state:=case action when 'REVIEW'then'REVIEWED'else'APPROVED'end;
 end if;end if;
 if state<>'CANCELLED'then perform private.po_amendment_validate(cid,o,v);end if;
 if state='APPROVED'then
 v:=v||jsonb_build_object('amendment_id',did,'amendment_reason',reason,'previous_version',o.version,'amendment_summary',jsonb_build_object('previous_delivery',o.snapshot->>'delivery_on','delivery',v->>'delivery_on','lines',(select jsonb_agg(jsonb_build_object('number',ord,'before',o.snapshot->'lines'->(ord::integer-1),'after',l)order by ord)from jsonb_array_elements(v->'lines')with ordinality x(l,ord))));
 insert into public.purchase_order_events(company_id,document_id,version,request_id,request_hash,action,state,reference,supplier_id,project_id,total_minor,snapshot,created_by)values(cid,pid,o.version+1,request_id,h,'ISSUE','ISSUED',o.reference,o.supplier_id,o.project_id,(v->>'total_minor')::bigint,v,actor);
 end if;
 insert into public.purchase_order_amendments(company_id,document_id,po_id,base_version,version,request_id,request_hash,state,reason,snapshot,created_by)values(cid,did,pid,base,expected+1,request_id,h,state,reason,v,actor);
 return jsonb_build_object('id',did,'version',expected+1,'state',state,'reference',o.reference,'replayed',false);
end$$;
create function public.read_purchase_order_amendments(cid uuid,pid uuid)returns jsonb language plpgsql stable security definer set search_path=''as $$begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'PROCUREMENT')or public.has_company_role(cid,'MANAGEMENT_VIEWER'))then raise exception 'PO_DENIED'using errcode='42501';end if;
 return(select coalesce(jsonb_agg(to_jsonb(e)order by created_at,version),'[]')from public.purchase_order_amendments e where company_id=cid and po_id=pid);
end$$;
-- Extend existing master lists; no tenant/global defaults are introduced.
do $$declare d text;begin
 d:=pg_get_functiondef('public.read_purchase_orders(uuid,integer,integer)'::regprocedure);d:=replace(d,$text$'unit',base_unit)$text$,$text$'unit',base_unit,'conversions',conversions)$text$);execute d;
 d:=pg_get_functiondef('private.pre_multi_read_procurement(uuid,integer,integer)'::regprocedure);d:=replace(d,$text$'unit',base_unit)$text$,$text$'unit',base_unit,'conversions',conversions)$text$);execute d;
end$$;
revoke all on function public.command_purchase_order_amendment(uuid,uuid,text,jsonb),public.read_purchase_order_amendments(uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.command_purchase_order_amendment(uuid,uuid,text,jsonb),public.read_purchase_order_amendments(uuid,uuid)to authenticated;
do $$declare p record;begin for p in select oid::regprocedure sig from pg_proc where pronamespace='private'::regnamespace and(proname like'uom_%'or proname like'po_amendment_%'or proname in('po_received','po_committed','guard_material_units','pre113_purchase_order_snapshot'))loop execute format('revoke all on function %s from public,anon,authenticated,service_role',p.sig);end loop;end$$;
-- Bind newly prepared receiving reviews to their issued revision. Save/review again after amendment.
do $$declare d text;begin
 d:=pg_get_functiondef('private.pre_multi_command_procurement(uuid,uuid,text,jsonb)'::regprocedure);
 d:=replace(d,$t$v:=input-array['id','version','kind'];plan:=$t$,$t$v:=input-array['id','version','kind'];if kind='RECEIPT'then v:=v||jsonb_build_object('po_version',(select version from public.purchase_order_events where company_id=cid and document_id=(v->>'po_id')::uuid order by version desc limit 1));end if;plan:=$t$);execute d;
 d:=pg_get_functiondef('private.pre_multi_procurement_plan(uuid,text,jsonb,boolean)'::regprocedure);
 d:=replace(d,$t$'line_number','location_id','quantity_micros','unit','reference'$t$,$t$'line_number','location_id','quantity_micros','unit','po_version','reference'$t$);
 d:=replace(d,$t$if o.id is null or o.state<>'ISSUED'$t$,$t$if v ?'po_version'and(v->>'po_version')::integer is distinct from o.version then raise exception 'PROC_STALE: order amended; save and review receiving again'using errcode='40001';end if; if o.id is null or o.state<>'ISSUED'$t$);execute d;
 d:=pg_get_functiondef('private.procurement_plan(uuid,text,jsonb,boolean)'::regprocedure);d:=replace(d,$t$'date','po_id','reference','evidence','receiving_lines'$t$,$t$'date','po_id','po_version','reference','evidence','receiving_lines'$t$);execute d;
end$$;
-- Supplier physical returns retain entered-unit evidence while canonical quantities remain base units.
do $$declare d text;begin
 d:=pg_get_functiondef('public.command_supplier_return(uuid,uuid,text,jsonb)'::regprocedure);d:=replace(d,$t$'qty_micros','date'$t$,$t$'qty_micros','purchase_unit','date'$t$);execute d;
 d:=pg_get_functiondef('private.supplier_return_plan(uuid,text,jsonb)'::regprocedure);d:=replace(d,$t$'qty_micros','date'$t$,$t$'qty_micros','purchase_unit','entered_quantity_micros','date'$t$);
 d:=replace(d,$t$q:=(v->>'qty_micros')::bigint;$t$,$t$if v ?'purchase_unit'then q:=private.uom_quantity(cid,(r.snapshot->>'material_id')::uuid,v->>'purchase_unit',coalesce(v->>'entered_quantity_micros',v->>'qty_micros'));v:=v||jsonb_build_object('entered_quantity_micros',coalesce(v->>'entered_quantity_micros',v->>'qty_micros'),'qty_micros',q::text);else q:=(v->>'qty_micros')::bigint;end if;$t$);execute d;
 d:=pg_get_functiondef('public.read_supplier_returns(uuid)'::regprocedure);d:=replace(d,$t$'material_id',e.snapshot->>'material_id'$t$,$t$'base_unit',(select base_unit from public.inventory_materials where company_id=cid and id=(e.snapshot->>'material_id')::uuid),'conversions',(select conversions from public.inventory_materials where company_id=cid and id=(e.snapshot->>'material_id')::uuid),'material_id',e.snapshot->>'material_id'$t$);execute d;
end$$;
-- A cancelled never-received line has zero quantity and zero remaining commitment.
do $$declare d text;begin
 d:=pg_get_functiondef('private.pre_multi_read_procurement(uuid,integer,integer)'::regprocedure);
 d:=replace(d,$t$round(ordered_minor::numeric*(ordered_micros::numeric-received_micros::numeric)/ordered_micros::numeric)::text$t$,$t$coalesce(round(ordered_minor::numeric*(ordered_micros::numeric-received_micros::numeric)/nullif(ordered_micros::numeric,0)),0)::text$t$);execute d;
 d:=pg_get_functiondef('public.read_purchase_order_history(uuid,uuid)'::regprocedure);d:=replace(d,$t$snapshot->>'cancellation_reason'$t$,$t$coalesce(snapshot->>'amendment_reason',snapshot->>'cancellation_reason')$t$);execute d;
end$$;
-- Previews explicitly identify the entered quantity and the canonical base quantity.
do $$declare d text;begin
 d:=pg_get_functiondef('private.pre_multi_procurement_plan(uuid,text,jsonb,boolean)'::regprocedure);d:=replace(d,$t$'material_name',po_line->>'description','unit',po_line->>'unit'$t$,$t$'material_name',po_line->>'description','unit',po_line->>'unit','quantity_micros',qty::bigint::text,'entered_unit',coalesce(v->>'unit',po_line->>'unit'),'entered_quantity_micros',v->>'quantity_micros'$t$);execute d;
 d:=pg_get_functiondef('private.multi_invoice_plan(uuid,jsonb)'::regprocedure);d:=replace(d,$t$'net_minor',ln::text,'vat_minor',lt::text,'material_id'$t$,$t$'quantity_micros',b->>'qty','entered_quantity_micros',x->>'quantity_micros','entered_unit',coalesce(x->>'unit',r.snapshot->>'unit'),'net_minor',ln::text,'vat_minor',lt::text,'material_id'$t$);execute d;
end$$;

-- A cancellation is never an implicit permission to receive again after a later correction.
do $$declare d text;begin
 d:=pg_get_functiondef('private.pre_multi_procurement_plan(uuid,text,jsonb,boolean)'::regprocedure);d:=replace(d,$t$if po_line is null or nullif(po_line->>'material_id','')is null$t$,$t$if po_line is null or po_line->>'cancelled'='true'or nullif(po_line->>'material_id','')is null$t$);execute d;
 d:=pg_get_functiondef('private.pre_multi_read_procurement(uuid,integer,integer)'::regprocedure);d:=replace(d,$t$x.l->>'quantity_micros'ordered_micros$t$,$t$(case when x.l->>'cancelled'='true'then private.po_received(cid,o.document_id,x.ord::integer)::text else x.l->>'quantity_micros'end)ordered_micros$t$);execute d;
end$$;

-- Verify the forward extensions were applied to the expected canonical dependencies.
do $$begin
 if position('private.uom_quantity' in pg_get_functiondef('private.pre_multi_procurement_plan(uuid,text,jsonb,boolean)'::regprocedure))=0
 or position('po_version' in pg_get_functiondef('private.pre_multi_command_procurement(uuid,uuid,text,jsonb)'::regprocedure))=0
 or position('private.uom_quantity' in pg_get_functiondef('private.multi_invoice_plan(uuid,jsonb)'::regprocedure))=0
 or position('entered_quantity_micros' in pg_get_functiondef('private.supplier_return_plan(uuid,text,jsonb)'::regprocedure))=0
 or position('not(conv @> m.conversions)' in pg_get_functiondef('public.command_inventory(uuid,uuid,text,jsonb)'::regprocedure))=0
 then raise exception 'Migration113 canonical dependency mismatch';end if;
end$$;
