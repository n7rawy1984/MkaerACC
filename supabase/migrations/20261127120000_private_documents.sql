--109: private evidence only. No financial backfill, configuration or journal commands.
-- Storage changes are canonical and require separate hosted activation approval.
create table public.private_documents(
 id uuid primary key,company_id uuid not null references public.companies(id)on delete restrict,
 entity_kind text not null,entity_id uuid not null,confidential boolean not null default false,title text not null check(length(btrim(title))between 1 and 200),
 revision integer not null check(revision>0),current_file uuid,removed boolean not null default false,
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id));
create table public.private_document_files(
 id uuid primary key,company_id uuid not null,document_id uuid not null,version integer not null check(version>0),
 object_path text not null unique,original_name text not null check(length(original_name)between 1 and 200),
 mime text not null check(mime in('application/pdf','image/png','image/jpeg','image/webp','text/plain','text/csv','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')),
 bytes bigint not null check(bytes between 1 and 10485760),sha256 text not null check(sha256~'^[a-f0-9]{64}$'),
 state text not null check(state in('UPLOADING','READY','ABANDONED')),created_by uuid not null references auth.users(id),
 created_at timestamptz not null default clock_timestamp(),unique(company_id,id),unique(company_id,document_id,version),
 foreign key(company_id,document_id)references public.private_documents(company_id,id)on delete restrict);
create unique index document_one_pending on public.private_document_files(company_id,document_id)where state='UPLOADING';
alter table public.private_documents add foreign key(company_id,current_file)references public.private_document_files(company_id,id)on delete restrict;
create table public.private_document_events(
 id uuid primary key default gen_random_uuid(),company_id uuid not null,document_id uuid not null,
 revision integer not null,request_id uuid not null,request_hash text not null,action text not null,
 actor uuid not null references auth.users(id),at timestamptz not null default clock_timestamp(),snapshot jsonb not null,result jsonb not null,
 unique(company_id,request_id),unique(company_id,document_id,revision),
 foreign key(company_id,document_id)references public.private_documents(company_id,id)on delete restrict);
create trigger private_document_events_immutable before update or delete on public.private_document_events for each row execute function private.financial_evidence_immutable();

-- Explicit target allowlist: Company existence and real entity are always established in DB.
-- Project-assignment and confidential HR checks reuse existing canonical authorities.
create function private.document_target(cid uuid,target_kind text,eid uuid,writing boolean default false)returns jsonb
language plpgsql stable security definer set search_path=''as $$
declare present boolean:=false;posted boolean:=false;allowed boolean;proc boolean;label text;journal uuid;
begin
 if auth.uid()is null or not public.is_company_member(cid)then raise exception 'DOC_DENIED'using errcode='42501';end if;
 allowed:=public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or(not writing and public.has_company_role(cid,'MANAGEMENT_VIEWER'));
 proc:=public.has_company_role(cid,'PROCUREMENT');
 case target_kind
 when 'EXPENSE','SUPPLIER_INVOICE'then select true,e.status<>'DRAFT',e.expense_reference,e.posted_journal_entry_id into present,posted,label,journal from public.expenses e where company_id=cid and id=eid and(target_kind='EXPENSE'or e.funding_mode='SUPPLIER_CREDIT');
 when 'CUSTOMER_INVOICE'then select true,true,c.reference,c.journal_id into present,posted,label,journal from public.commercial_documents c where c.company_id=cid and c.id=eid and c.kind in('AR_INVOICE','AR_CASH_SALE');
 when 'PURCHASE_ORDER'then select true,state not in('DRAFT','REVIEWED'),reference into present,posted,label from public.purchase_order_events where company_id=cid and document_id=eid order by version desc limit 1;allowed:=allowed or proc;
 when 'REQUISITION','RFQ','GOODS_RECEIPT','PROCUREMENT_INVOICE'then select true,state not in('DRAFT','SUBMITTED','REVIEWED'),reference into present,posted,label from public.procurement_events e where company_id=cid and document_id=eid and e.kind=case target_kind when 'GOODS_RECEIPT'then'RECEIPT'when 'PROCUREMENT_INVOICE'then'INVOICE'else target_kind end order by version desc limit 1;allowed:=allowed or(proc and target_kind<>'PROCUREMENT_INVOICE');
 when 'PROJECT'then select true,false,name into present,posted,label from public.projects where company_id=cid and id=eid;allowed:=public.can_access_project(cid,eid)and(not writing or not public.has_company_role(cid,'MANAGEMENT_VIEWER'));
 when 'SUBCONTRACT'then select true,true,contract_number into present,posted,label from public.subcontracts where company_id=cid and id=eid;
 when 'CONSTRUCTION_CONTRACT'then select true,true,reference into present,posted,label from public.construction_contracts where company_id=cid and id=eid;
 when 'CERTIFICATE'then select true,status<>'DRAFT',certificate_reference,posted_journal_entry_id into present,posted,label,journal from public.subcontractor_certificates where company_id=cid and id=eid;
 when 'TREASURY_TRANSACTION','CUSTODY_TRANSACTION'then select true,true,j.journal_reference,j.id into present,posted,label,journal from public.journal_entries j where j.company_id=cid and j.id=eid and exists(select 1 from public.journal_lines l join public.accounts a on a.company_id=l.company_id and a.id=l.account_id where l.company_id=cid and l.journal_entry_id=j.id and(case target_kind when 'TREASURY_TRANSACTION'then l.treasury_account_id is not null else a.system_key='CUSTODY_ADVANCE'end));
 when 'CUSTODY_SETTLEMENT'then select true,status='FINALIZED',settlement_reference into present,posted,label from public.custody_settlements where company_id=cid and id=eid;allowed:=allowed and public.has_permission(cid,'payroll.manage');
 when 'EMPLOYEE'then select true,false,name into present,posted,label from public.parties where company_id=cid and id=eid and private.party_has_person_role(cid,eid,'EMPLOYEE');allowed:=public.has_permission(cid,'payroll.manage');
 else raise exception 'DOC_TARGET: unsupported association'using errcode='22023';end case;
 if journal is not null then allowed:=allowed and public.payroll_journal_visible(cid,journal)and public.construction_journal_visible(cid,journal)and public.can_read_annual_journal(cid,journal);end if;
 if not coalesce(allowed,false)or not coalesce(present,false)then raise exception 'DOC_DENIED: unavailable entity'using errcode='42501';end if;
 return jsonb_build_object('posted',coalesce(posted,true),'label',label);
end$$;
revoke all on function private.document_target(uuid,text,uuid,boolean)from public,anon,authenticated,service_role;

create function public.can_access_private_document(path text,operation text)returns boolean
language plpgsql stable security definer set search_path=''as $$
declare f public.private_document_files;d public.private_documents;
begin
 if auth.uid()is null or operation not in('READ','UPLOAD')then return false;end if;
 select *into f from public.private_document_files where object_path=path;if not found then return false;end if;
 select *into d from public.private_documents where company_id=f.company_id and id=f.document_id;
 perform private.document_target(d.company_id,d.entity_kind,d.entity_id,operation='UPLOAD');
 if d.confidential and not public.has_permission(d.company_id,'payroll.manage')then return false;end if;
 if operation='UPLOAD'then return f.state='UPLOADING'and f.created_by=auth.uid()and not d.removed and f.created_at>clock_timestamp()-interval '24 hours';end if;
 return f.state='READY'or(f.state='UPLOADING'and f.created_by=auth.uid());
 exception when insufficient_privilege then return false;
end$$;
revoke all on function public.can_access_private_document(text,text)from public,anon,authenticated,service_role;
grant execute on function public.can_access_private_document(text,text)to anon,authenticated;

-- No public URLs, overwrite or physical-delete path, even if another permissive Storage policy exists.
do $$begin
 if exists(select 1 from storage.buckets where id='narvo-private-documents')then raise exception 'Document bucket already exists; inspect before canonical activation';end if;
end$$;
insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)values('narvo-private-documents','narvo-private-documents',false,10485760,array['application/pdf','image/png','image/jpeg','image/webp','text/plain','text/csv','application/vnd.openxmlformats-officedocument.wordprocessingml.document','application/vnd.openxmlformats-officedocument.spreadsheetml.sheet']);
create policy narvo_document_read on storage.objects for select to authenticated using(bucket_id='narvo-private-documents'and public.can_access_private_document(name,'READ'));
create policy narvo_document_upload on storage.objects for insert to authenticated with check(bucket_id='narvo-private-documents'and public.can_access_private_document(name,'UPLOAD'));
create policy narvo_document_read_boundary on storage.objects as restrictive for select to public using(bucket_id<>'narvo-private-documents'or public.can_access_private_document(name,'READ'));
create policy narvo_document_upload_boundary on storage.objects as restrictive for insert to public with check(bucket_id<>'narvo-private-documents'or public.can_access_private_document(name,'UPLOAD'));
create policy narvo_document_no_overwrite on storage.objects as restrictive for update to public using(bucket_id<>'narvo-private-documents')with check(bucket_id<>'narvo-private-documents');
create policy narvo_document_no_delete on storage.objects as restrictive for delete to public using(bucket_id<>'narvo-private-documents');

create function public.command_private_document(cid uuid,request_id uuid,action text,input jsonb)returns jsonb
language plpgsql security definer set search_path=''as $$
declare d public.private_documents;f public.private_document_files;e public.private_document_events;target jsonb;h text;result jsonb;fid uuid;ext text;n integer;obj storage.objects;v jsonb:=input;
begin
 if auth.uid()is null or not public.is_company_member(cid)then raise exception 'DOC_DENIED'using errcode='42501';end if;
 if request_id is null or action not in('RESERVE','COMPLETE','RENAME','REMOVE','ABANDON')or jsonb_typeof(v)is distinct from'object'then raise exception 'DOC_INPUT'using errcode='22023';end if;
 if exists(select 1 from jsonb_object_keys(v)k where k<>all(array['id','revision','entity_kind','entity_id','title','name','mime','bytes','sha256','file_id','reason','confidential']))then raise exception 'DOC_INPUT: unsupported fields'using errcode='22023';end if;
 if v ? 'confidential'and jsonb_typeof(v->'confidential')is distinct from'boolean'then raise exception 'DOC_INPUT'using errcode='22023';end if;
 perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',auth.uid(),'action',action,'input',v)::text,'UTF8'),'sha256'),'hex');
 select *into e from public.private_document_events where company_id=cid and private_document_events.request_id=command_private_document.request_id;
 if found then
  perform private.document_target(cid,e.snapshot->>'entity_kind',(e.snapshot->>'entity_id')::uuid,true);
  if(e.snapshot->>'confidential')::boolean and not public.has_permission(cid,'payroll.manage')then raise exception 'DOC_DENIED'using errcode='42501';end if;
  if e.request_hash<>h then raise exception 'DOC_REPLAY: request changed'using errcode='22023';end if;return e.result||jsonb_build_object('replayed',true);
 end if;
 select *into d from public.private_documents where company_id=cid and id=(v->>'id')::uuid for update;
 if d.id is null then
  if action<>'RESERVE'or v->>'revision'is distinct from'0'then raise exception 'DOC_STALE'using errcode='40001';end if;
  target:=private.document_target(cid,v->>'entity_kind',(v->>'entity_id')::uuid,true);
  d.id:=(v->>'id')::uuid;d.company_id:=cid;d.entity_kind:=v->>'entity_kind';d.entity_id:=(v->>'entity_id')::uuid;d.title:=btrim(v->>'title');d.revision:=1;d.created_by:=auth.uid();d.confidential:=d.entity_kind='EMPLOYEE'or coalesce((v->>'confidential')::boolean,false);
  if d.confidential and not public.has_permission(cid,'payroll.manage')then raise exception 'DOC_DENIED'using errcode='42501';end if;
  insert into public.private_documents(id,company_id,entity_kind,entity_id,confidential,title,revision,created_by)values(d.id,cid,d.entity_kind,d.entity_id,d.confidential,d.title,1,auth.uid());
 else
  target:=private.document_target(cid,d.entity_kind,d.entity_id,true);
  if d.confidential and not public.has_permission(cid,'payroll.manage')then raise exception 'DOC_DENIED'using errcode='42501';end if;
  if v ? 'confidential'and(v->>'confidential')::boolean is distinct from d.confidential then raise exception 'DOC_TARGET: confidentiality immutable'using errcode='22023';end if;
  if v->>'entity_kind'is not null and(v->>'entity_kind'is distinct from d.entity_kind or v->>'entity_id'is distinct from d.entity_id::text)then raise exception 'DOC_TARGET: association immutable'using errcode='22023';end if;
  if d.revision::text is distinct from v->>'revision'or d.removed then raise exception 'DOC_STALE'using errcode='40001';end if;d.revision:=d.revision+1;
 end if;
 if d.title is null or length(btrim(d.title))not between 1 and 200 then raise exception 'DOC_TITLE'using errcode='22023';end if;
 if action='RESERVE'then
  if exists(select 1 from public.private_document_files where company_id=cid and document_id=d.id and state='UPLOADING')then raise exception 'DOC_PENDING: finish or abandon pending upload'using errcode='23514';end if;
  if v->>'name'is null or length(v->>'name')not between 1 and 200 or v->>'name'~'[[:cntrl:]/\\]'or v->>'bytes'!~'^[0-9]{1,8}$'or v->>'sha256'!~'^[a-f0-9]{64}$'then raise exception 'DOC_FILE: invalid file'using errcode='22023';end if;
  ext:=case v->>'mime' when'application/pdf'then'pdf'when'image/png'then'png'when'image/jpeg'then'jpg'when'image/webp'then'webp'when'text/plain'then'txt'when'text/csv'then'csv'when'application/vnd.openxmlformats-officedocument.wordprocessingml.document'then'docx'when'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'then'xlsx'end;
  if ext is null or lower(v->>'name')!~('\.'||case ext when'jpg'then'jpe?g'else ext end||'$')then raise exception 'DOC_FILE: supported type and extension required'using errcode='22023';end if;
  fid:=gen_random_uuid();select coalesce(max(version),0)+1 into n from public.private_document_files where company_id=cid and document_id=d.id;
  insert into public.private_document_files(id,company_id,document_id,version,object_path,original_name,mime,bytes,sha256,state,created_by)values(fid,cid,d.id,n,cid::text||'/'||d.id::text||'/'||fid::text||'.'||ext,v->>'name',v->>'mime',(v->>'bytes')::bigint,v->>'sha256','UPLOADING',auth.uid())returning *into f;
 elsif action in('COMPLETE','ABANDON')then
  select *into f from public.private_document_files where company_id=cid and document_id=d.id and id=(v->>'file_id')::uuid for update;
  if f.id is null or f.state<>'UPLOADING'or f.created_by<>auth.uid()then raise exception 'DOC_PENDING'using errcode='23514';end if;
  if action='COMPLETE'then
   select *into obj from storage.objects where bucket_id='narvo-private-documents'and name=f.object_path;
   if obj.id is null or obj.owner_id is distinct from auth.uid()::text or obj.metadata->>'size'is distinct from f.bytes::text or obj.metadata->>'mimetype'is distinct from f.mime then raise exception 'DOC_UPLOAD: upload missing or size/type mismatch'using errcode='23514';end if;
   update public.private_document_files set state='READY'where company_id=cid and id=f.id;d.current_file:=f.id;
  else update public.private_document_files set state='ABANDONED'where company_id=cid and id=f.id;end if;
 else
  if length(btrim(coalesce(v->>'reason','')))not between 3 and 1000 then raise exception 'DOC_REASON'using errcode='22023';end if;
  if action='RENAME'then d.title:=btrim(v->>'title');if d.title is null or length(d.title)not between 1 and 200 then raise exception 'DOC_TITLE'using errcode='22023';end if;
  else
   if(target->>'posted')::boolean then raise exception 'DOC_RETAINED: posted evidence cannot be detached'using errcode='23514';end if;
   if exists(select 1 from public.private_document_files where company_id=cid and document_id=d.id and state='UPLOADING')then raise exception 'DOC_PENDING'using errcode='23514';end if;d.removed:=true;
  end if;
 end if;
 update public.private_documents set revision=d.revision,title=d.title,current_file=d.current_file,removed=coalesce(d.removed,false)where company_id=cid and id=d.id;
 result:=jsonb_build_object('id',d.id,'revision',d.revision,'file_id',f.id,'path',f.object_path,'version',f.version,'state',case when action='COMPLETE'then'READY'else f.state end);
 insert into public.private_document_events(company_id,document_id,revision,request_id,request_hash,action,actor,snapshot,result)values(cid,d.id,d.revision,request_id,h,action,auth.uid(),jsonb_build_object('entity_kind',d.entity_kind,'entity_id',d.entity_id,'title',d.title,'confidential',d.confidential,'current_file',d.current_file,'removed',coalesce(d.removed,false),'reason',v->>'reason'),result);
 return result;
end$$;

create function public.read_private_documents(cid uuid,kind text,eid uuid)returns jsonb
language plpgsql stable security definer set search_path=''as $$
declare target jsonb;editable boolean:=false;
begin
 target:=private.document_target(cid,kind,eid,false);
 begin perform private.document_target(cid,kind,eid,true);editable:=true;exception when insufficient_privilege then editable:=false;end;
 return jsonb_build_object('company_id',cid,'entity_id',eid,'entity_kind',kind,'can_edit',editable,'can_confidential',public.has_permission(cid,'payroll.manage'),'retained',(target->>'posted')::boolean,'documents',coalesce((select jsonb_agg(to_jsonb(d)||jsonb_build_object('files',coalesce((select jsonb_agg(to_jsonb(f)order by version desc)from public.private_document_files f where f.company_id=cid and f.document_id=d.id and(f.state='READY'or(editable and f.created_by=auth.uid()))),'[]'::jsonb),'history',coalesce((select jsonb_agg(jsonb_build_object('action',e.action,'revision',e.revision,'actor',e.actor,'at',e.at,'snapshot',e.snapshot)order by e.revision desc)from public.private_document_events e where e.company_id=cid and e.document_id=d.id),'[]'::jsonb))order by d.created_at desc)from public.private_documents d where d.company_id=cid and(not d.confidential or public.has_permission(cid,'payroll.manage'))and((d.entity_id=eid and(d.entity_kind=kind or(kind in('EXPENSE','SUPPLIER_INVOICE')and d.entity_kind in('EXPENSE','SUPPLIER_INVOICE'))))or(kind in('EXPENSE','SUPPLIER_INVOICE')and d.entity_kind='PROCUREMENT_INVOICE'and exists(select 1 from public.procurement_events p where p.company_id=cid and p.document_id=d.entity_id and p.kind='INVOICE'and p.state='EXECUTED'and p.result->>'id'=eid::text)))),'[]'::jsonb));
end$$;
revoke all on function public.command_private_document(uuid,uuid,text,jsonb),public.read_private_documents(uuid,text,uuid)from public,anon,authenticated,service_role;
grant execute on function public.command_private_document(uuid,uuid,text,jsonb),public.read_private_documents(uuid,text,uuid)to authenticated;

-- Metadata direct writes are closed; reads pass identical live target checks.
create function public.can_read_private_document_record(cid uuid,did uuid)returns boolean
language plpgsql stable security definer set search_path=''as $$declare d public.private_documents;begin
 select *into d from public.private_documents where company_id=cid and id=did;if not found then return false;end if;
 perform private.document_target(cid,d.entity_kind,d.entity_id,false);return not d.confidential or public.has_permission(cid,'payroll.manage');
 exception when insufficient_privilege then return false;end$$;
revoke all on function public.can_read_private_document_record(uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.can_read_private_document_record(uuid,uuid)to authenticated;
do $$declare t text;begin foreach t in array array['private_documents','private_document_files','private_document_events']loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);execute format('grant select on public.%I to authenticated',t);
 execute format('create policy document_record_read on public.%I for select to authenticated using(public.can_read_private_document_record(company_id,%s))',t,case t when'private_documents'then'id'else'document_id'end);
 end loop;end$$;
