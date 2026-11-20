-- 107: purchasing commitments only. No receipt, liability, VAT or GL recognition.
create table public.purchase_order_events(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id)on delete restrict,
 document_id uuid not null,version integer not null check(version>0),request_id uuid not null,request_hash text not null,
 action text not null check(action in('SAVE','REVIEW','ISSUE','CANCEL')),state text not null check(state in('DRAFT','REVIEWED','ISSUED','CANCELLED')),
 reference text not null,supplier_id uuid,project_id uuid,total_minor bigint not null check(total_minor between 0 and 9000000000000000),snapshot jsonb not null,
 check(total_minor is not distinct from(snapshot->>'total_minor')::bigint),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,document_id,version),unique(company_id,request_id),
 foreign key(company_id,supplier_id)references public.parties(company_id,id),foreign key(company_id,project_id)references public.projects(company_id,id)
);
alter table public.purchase_order_events enable row level security;
alter table public.purchase_order_events force row level security;
revoke all on public.purchase_order_events from public,anon,authenticated,service_role;
grant select on public.purchase_order_events to authenticated;
create policy purchase_order_read on public.purchase_order_events for select to authenticated using(
 public.has_company_role(company_id,'ACCOUNTING_ADMIN')or public.has_company_role(company_id,'ACCOUNTANT')or public.has_company_role(company_id,'PROCUREMENT')or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create trigger purchase_order_immutable before update or delete on public.purchase_order_events for each row execute function private.financial_evidence_immutable();

create function private.purchase_order_snapshot(cid uuid,v jsonb,complete boolean)returns jsonb
language plpgsql stable security definer set search_path=''as $$
declare sid uuid;pid uuid;d date;delivery date;line jsonb;lines jsonb:='[]';m public.inventory_materials;qty numeric;price numeric;amount numeric;total numeric:=0;description text;unit text;mid uuid;ordinal integer:=0;
begin
 if jsonb_typeof(v)is distinct from 'object'or octet_length(v::text)>50000 or exists(select 1 from jsonb_each(v)where key<>all(array['id','version','date','delivery_on','supplier_id','project_id','notes','lines','reason']))then raise exception 'PO_INPUT'using errcode='22023';end if;
 if exists(select 1 from jsonb_each(v)where key<>'lines'and jsonb_typeof(value)not in('string','null'))then raise exception 'PO_INPUT'using errcode='22023';end if;
 if coalesce(v->>'date','')!~'^\d{4}-\d{2}-\d{2}$'then raise exception 'PO_DATE'using errcode='23514';end if;
 d:=(v->>'date')::date;if d>(statement_timestamp()at time zone 'Asia/Dubai')::date or d<'2000-01-01'then raise exception 'PO_DATE'using errcode='23514';end if;
 if nullif(v->>'delivery_on','')is not null and(v->>'delivery_on')!~'^\d{4}-\d{2}-\d{2}$'then raise exception 'PO_DELIVERY'using errcode='23514';end if;
 delivery:=nullif(v->>'delivery_on','')::date;if delivery<d then raise exception 'PO_DELIVERY'using errcode='23514';end if;
 sid:=nullif(v->>'supplier_id','')::uuid;pid:=nullif(v->>'project_id','')::uuid;
 if sid is not null and not exists(select 1 from public.parties where company_id=cid and id=sid and type='SUPPLIER'and status='ACTIVE')then raise exception 'PO_SUPPLIER'using errcode='23514';end if;
 if pid is not null and not exists(select 1 from public.projects where company_id=cid and id=pid and status<>'CLOSED')then raise exception 'PO_PROJECT'using errcode='23514';end if;
 if length(coalesce(v->>'notes',''))>2000 or jsonb_typeof(v->'lines')is distinct from 'array'or jsonb_array_length(v->'lines')>50 then raise exception 'PO_LINES'using errcode='23514';end if;
 for line in select value from jsonb_array_elements(v->'lines')loop
  ordinal:=ordinal+1;
  if jsonb_typeof(line)is distinct from 'object'or exists(select 1 from jsonb_each(line)where key<>all(array['material_id','description','unit','quantity_micros','unit_price_minor'])or jsonb_typeof(value)<>'string')then raise exception 'PO_LINES'using errcode='23514';end if;
  if coalesce(line->>'quantity_micros','')!~'^\d{1,16}$'or coalesce(line->>'unit_price_minor','')!~'^\d{1,16}$'then raise exception 'PO_AMOUNT'using errcode='23514';end if;
  qty:=(line->>'quantity_micros')::numeric;price:=(line->>'unit_price_minor')::numeric;
  if qty>9000000000000000 or price>9000000000000000 then raise exception 'PO_AMOUNT'using errcode='23514';end if;
  description:=btrim(coalesce(line->>'description',''));unit:=btrim(coalesce(line->>'unit',''));mid:=nullif(line->>'material_id','')::uuid;
  if length(description)>500 or length(unit)>50 then raise exception 'PO_LINES'using errcode='23514';end if;
  if mid is not null then
   select *into m from public.inventory_materials where company_id=cid and id=mid and active;
   if not found or unit<>m.base_unit then raise exception 'PO_MATERIAL'using errcode='23514';end if;
  end if;
  if complete and(qty<=0 or description=''or unit='')then raise exception 'PO_INCOMPLETE'using errcode='23514';end if;
  amount:=round(qty*price/1000000);total:=total+amount;
  if total>9000000000000000 then raise exception 'PO_AMOUNT'using errcode='23514';end if;
  lines:=lines||jsonb_build_array(jsonb_build_object('number',ordinal,'material_id',mid,'description',description,'unit',unit,'quantity_micros',qty::bigint::text,'unit_price_minor',price::bigint::text,'amount_minor',amount::bigint::text));
 end loop;
 if complete and(sid is null or ordinal=0 or total<=0)then raise exception 'PO_INCOMPLETE'using errcode='23514';end if;
 return jsonb_build_object('date',d,'delivery_on',delivery,'supplier_id',sid,'project_id',pid,'supplier_name',(select name from public.parties where company_id=cid and id=sid),'project_name',(select name from public.projects where company_id=cid and id=pid),'notes',btrim(coalesce(v->>'notes','')),'lines',lines,'total_minor',total::bigint::text,'currency','AED','amount_basis','EXCLUDING_TAX');
end$$;
revoke all on function private.purchase_order_snapshot(uuid,jsonb,boolean)from public,anon,authenticated,service_role;

create function public.command_purchase_order(cid uuid,request_id uuid,action text,input jsonb)returns jsonb
language plpgsql security definer set search_path=''as $$
#variable_conflict use_variable
declare actor uuid:=auth.uid();old public.purchase_order_events;prior public.purchase_order_events;did uuid;expected integer;h text;v jsonb;next_state text;ref text;reason text;approver boolean;
begin
 if actor is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'PROCUREMENT'))then raise exception 'PO_DENIED'using errcode='42501';end if;
 if request_id is null or action is null or action not in('SAVE','REVIEW','ISSUE','CANCEL')or jsonb_typeof(input)is distinct from 'object'or octet_length(input::text)>50000 then raise exception 'PO_INPUT'using errcode='22023';end if;
 if exists(select 1 from jsonb_each(input)where key<>'lines'and jsonb_typeof(value)not in('string','null'))then raise exception 'PO_INPUT'using errcode='22023';end if;
 did:=(input->>'id')::uuid;expected:=(input->>'version')::integer;if did is null or expected is null or expected<0 then raise exception 'PO_VERSION'using errcode='22023';end if;
 -- One Company serialization boundary protects references, replay and state transitions.
 perform private.serialize_operational_finance(cid,'OPERATIONS');
 perform 1 from public.company_memberships m join public.profiles p on p.user_id=m.user_id join public.companies c on c.id=m.company_id where m.company_id=cid and m.user_id=actor and m.status='ACTIVE'and p.status='ACTIVE'and c.status='ACTIVE'and m.role in('ACCOUNTING_ADMIN','ACCOUNTANT','PROCUREMENT')for share of m,p,c;
 if not found then raise exception 'PO_DENIED'using errcode='42501';end if;
 approver:=(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT'))and public.has_permission(cid,'accounting.post');
 h:=encode(sha256(convert_to(jsonb_build_object('actor',actor,'action',action,'input',input)::text,'UTF8')),'hex');
 select *into prior from public.purchase_order_events e where e.company_id=cid and e.request_id=command_purchase_order.request_id;
 if found then
  if prior.request_hash<>h then raise exception 'PO_REPLAY'using errcode='22023';end if;
  return jsonb_build_object('id',did,'version',prior.version,'state',prior.state,'reference',prior.reference,'replayed',true);
 end if;
 select *into old from public.purchase_order_events e where e.company_id=cid and e.document_id=did order by e.version desc limit 1;
 if coalesce(old.version,0)<>expected then raise exception 'PO_STALE'using errcode='40001';end if;
 if old.state='CANCELLED'or(action<>'CANCEL'and old.state='ISSUED')then raise exception 'PO_IMMUTABLE'using errcode='23514';end if;
 if action='ISSUE'or(action='CANCEL'and old.state='ISSUED')then if not approver then raise exception 'PO_APPROVAL'using errcode='42501';end if;end if;
 if action in('SAVE','REVIEW','ISSUE')then
  if not exists(select 1 from public.companies where id=cid and status='ACTIVE')or not(private.company_commercial_readiness(cid)->>'ready')::boolean then raise exception 'PO_SETUP'using errcode='42501';end if;
 end if;
 if action='SAVE'then
  if old.state is not null and old.state not in('DRAFT','REVIEWED')then raise exception 'PO_STATE'using errcode='23514';end if;
  v:=private.purchase_order_snapshot(cid,input,false);next_state:='DRAFT';
 else
  if expected=0 or exists(select 1 from jsonb_each(input)where key<>all(array['id','version','reason']))then raise exception 'PO_INPUT'using errcode='22023';end if;
  if action='CANCEL'then
   reason:=btrim(coalesce(input->>'reason',''));if length(reason)not between 5 and 1000 then raise exception 'PO_REASON'using errcode='23514';end if;
   v:=old.snapshot||jsonb_build_object('cancellation_reason',reason);next_state:='CANCELLED';
  else
   if(action='REVIEW'and old.state<>'DRAFT')or(action='ISSUE'and old.state<>'REVIEWED')then raise exception 'PO_STATE'using errcode='23514';end if;
   -- Revalidate masters and exact totals at review AND approval; never trust UI totals.
   v:=private.purchase_order_snapshot(cid,(old.snapshot-array['supplier_name','project_name','total_minor','currency','amount_basis'])||jsonb_build_object('lines',(select jsonb_agg((x-array['number','amount_minor'])||jsonb_build_object('material_id',coalesce(x->>'material_id','')))from jsonb_array_elements(old.snapshot->'lines')x)),true);
   next_state:=case action when 'REVIEW'then 'REVIEWED'else 'ISSUED'end;
  end if;
 end if;
 ref:=coalesce(old.reference,private.allocate_reference(cid,'PO',extract(year from(v->>'date')::date)::integer));
 insert into public.purchase_order_events(company_id,document_id,version,request_id,request_hash,action,state,reference,supplier_id,project_id,total_minor,snapshot,created_by)
 values(cid,did,expected+1,request_id,h,action,next_state,ref,(v->>'supplier_id')::uuid,(v->>'project_id')::uuid,(v->>'total_minor')::bigint,v,actor);
 return jsonb_build_object('id',did,'version',expected+1,'state',next_state,'reference',ref,'replayed',false);
end$$;
revoke all on function public.command_purchase_order(uuid,uuid,text,jsonb)from public,anon,authenticated,service_role;
grant execute on function public.command_purchase_order(uuid,uuid,text,jsonb)to authenticated;

create function public.read_purchase_orders(cid uuid,page_offset integer default 0,page_size integer default 25)returns jsonb
language plpgsql stable security definer set search_path=''as $$
declare result jsonb;
begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'PROCUREMENT')or public.has_company_role(cid,'MANAGEMENT_VIEWER'))then raise exception 'PO_DENIED'using errcode='42501';end if;
 if page_offset is null or page_offset<0 or page_size is null or page_size not between 1 and 100 then raise exception 'PO_INPUT'using errcode='22023';end if;
 with latest as(select distinct on(document_id)*from public.purchase_order_events where company_id=cid order by document_id,version desc)
 select jsonb_build_object('company_id',cid,'today',(statement_timestamp()at time zone 'Asia/Dubai')::date,
 'can_edit',public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'PROCUREMENT'),
 'can_approve',(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT'))and public.has_permission(cid,'accounting.post'),
 'count',(select count(*)from latest),'issued_commitment_minor',(select coalesce(sum(total_minor::numeric),0)::text from latest where state='ISSUED'),
 'documents',(select coalesce(jsonb_agg(to_jsonb(q)order by q.created_at desc,q.document_id),'[]')from(select *from latest order by created_at desc,document_id offset page_offset limit page_size)q),
 'suppliers',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name)order by name,id),'[]')from public.parties where company_id=cid and type='SUPPLIER'and status='ACTIVE'),
 'projects',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name)order by name,id),'[]')from public.projects where company_id=cid and status<>'CLOSED'),
 'materials',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name,'unit',base_unit)order by name,id),'[]')from public.inventory_materials where company_id=cid and active))into result;
 return result;
end$$;
revoke all on function public.read_purchase_orders(uuid,integer,integer)from public,anon,authenticated,service_role;
grant execute on function public.read_purchase_orders(uuid,integer,integer)to authenticated;

create function public.read_purchase_order_history(cid uuid,did uuid)returns jsonb
language plpgsql stable security definer set search_path=''as $$
begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'PROCUREMENT')or public.has_company_role(cid,'MANAGEMENT_VIEWER'))then raise exception 'PO_DENIED'using errcode='42501';end if;
 return(select coalesce(jsonb_agg(jsonb_build_object('version',version,'state',state,'actor',created_by,'at',created_at,'reason',snapshot->>'cancellation_reason')order by version),'[]')from public.purchase_order_events where company_id=cid and document_id=did);
end$$;
revoke all on function public.read_purchase_order_history(uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.read_purchase_order_history(uuid,uuid)to authenticated;
