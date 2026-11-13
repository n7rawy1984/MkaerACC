-- 93: Opt-in audited payment suggestions and exact imported source-set attestations.
-- No backfill, financial mutation, posting-function replacement or grant widening.
create table public.payment_workflow_preferences (
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),
 request_id uuid not null,request_hash text not null,scope_key text not null,version integer not null check(version>0),
 kind text not null check(kind in ('DEFAULT','SOURCE_SET')),mode text not null check(mode in ('NONE','TREASURY','CUSTODIAN')),
 treasury_id uuid,party_id uuid,source_file text,source_hash text,month_from text,month_through text,
 approval_reference text not null check(length(approval_reference) between 5 and 1000),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,request_id),unique(company_id,scope_key,version),
 foreign key(company_id,treasury_id) references public.treasury_accounts(company_id,id),
 foreign key(company_id,party_id) references public.parties(company_id,id),
 check((mode='NONE' and treasury_id is null and party_id is null)or(mode='TREASURY'and treasury_id is not null and party_id is null)or(mode='CUSTODIAN'and party_id is not null and treasury_id is null)),
 check((kind='DEFAULT'and source_file is null and source_hash is null and month_from is null and month_through is null)or(kind='SOURCE_SET'and source_file is not null and source_hash ~ '^[0-9a-f]{64}$'and month_from ~ '^\d{4}-(0[1-9]|1[0-2])$'and month_through ~ '^\d{4}-(0[1-9]|1[0-2])$'and month_from<=month_through))
);
alter table public.payment_workflow_preferences enable row level security;
alter table public.payment_workflow_preferences force row level security;
revoke all on public.payment_workflow_preferences from public,anon,authenticated,service_role;
grant select on public.payment_workflow_preferences to authenticated;
create policy payment_preferences_read on public.payment_workflow_preferences for select to authenticated
 using(public.has_company_role(company_id,'ACCOUNTING_ADMIN')or public.has_company_role(company_id,'ACCOUNTANT'));
create trigger payment_preferences_immutable before update or delete on public.payment_workflow_preferences for each row execute function private.financial_evidence_immutable();

create function public.configure_payment_preferences(cid uuid,request_id uuid,expected_version integer,input jsonb)returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();v jsonb:='{}';k text;x jsonb;p public.payment_workflow_preferences;scope text;h text;last_version integer;
begin
 if actor is null or not public.has_permission(cid,'account.manage')then raise exception 'Company accounting setup permission required'using errcode='42501';end if;
 if request_id is null or jsonb_typeof(input)is distinct from 'object'or octet_length(input::text)>6000 then raise exception 'Invalid preferences'using errcode='22023';end if;
 for k,x in select * from jsonb_each(input)loop
  if k<>all(array['kind','mode','treasury_id','party_id','source_file','source_hash','month_from','month_through','approval_reference'])or jsonb_typeof(x)not in('string','null')then raise exception 'Unsupported preference field'using errcode='22023';end if;
  if nullif(btrim(x#>>'{}'),'')is not null and x<>'null'::jsonb then v:=v||jsonb_build_object(k,btrim(x#>>'{}'));end if;
 end loop;
 if v->>'kind'not in('DEFAULT','SOURCE_SET')or v->>'mode'not in('NONE','TREASURY','CUSTODIAN')or coalesce(length(v->>'approval_reference'),0)not between 5 and 1000 then raise exception 'Choose scope, payment mode and approval reference'using errcode='23514';end if;
 if v->>'kind'='DEFAULT'and v ?| array['source_file','source_hash','month_from','month_through']then raise exception 'A future default has no historical scope'using errcode='23514';end if;
 if v->>'kind'='SOURCE_SET'and not exists(select 1 from public.historical_source_records s where s.company_id=cid and s.source_file=v->>'source_file'and s.source_hash=v->>'source_hash'and s.source_month between v->>'month_from'and v->>'month_through'and s.record_type='GENERAL'and s.outflow_minor>0 and coalesce(s.funding_minor,0)=0)then raise exception 'Exact existing Company outgoing source set required'using errcode='23514';end if;
 perform pg_advisory_xact_lock(hashtextextended('payment_preferences:'||cid::text,0));

 scope:=case when v->>'kind'='DEFAULT'then 'DEFAULT'else 'SOURCE_SET:'||encode(extensions.digest(convert_to(jsonb_build_array(v->>'source_file',v->>'source_hash',v->>'month_from',v->>'month_through')::text,'UTF8'),'sha256'),'hex')end;
 h:=encode(extensions.digest(convert_to(jsonb_build_array(actor,cid,expected_version,v)::text,'UTF8'),'sha256'),'hex');

 select * into p from public.payment_workflow_preferences e where e.company_id=cid and e.request_id=configure_payment_preferences.request_id;
 if found then if p.request_hash<>h then raise exception 'Request key reused with different preferences'using errcode='22023';end if;return to_jsonb(p);end if;
 if v->>'kind'='SOURCE_SET'and v->>'mode'<>'NONE'and exists(select 1 from public.payment_workflow_preferences e where e.company_id=cid and e.kind='SOURCE_SET'and e.mode<>'NONE'and e.source_file=v->>'source_file'and e.source_hash=v->>'source_hash'and (e.month_from,e.month_through)is distinct from(v->>'month_from',v->>'month_through')and e.month_from<=v->>'month_through'and e.month_through>=v->>'month_from'and not exists(select 1 from public.payment_workflow_preferences n where n.company_id=cid and n.scope_key=e.scope_key and n.version>e.version))then raise exception 'Overlapping source confirmation; disable the previous scope before changing it'using errcode='23514';end if;
 select coalesce(max(e.version),0)into last_version from public.payment_workflow_preferences e where e.company_id=cid and e.scope_key=scope;
 if expected_version is distinct from last_version then raise exception 'Preferences changed; refresh before saving'using errcode='40001';end if;
 if v->>'mode'='TREASURY'and not exists(select 1 from public.treasury_accounts t join public.accounts a on a.company_id=t.company_id and a.id=t.gl_account_id where t.company_id=cid and t.id=nullif(v->>'treasury_id','')::uuid and t.status='ACTIVE'and a.status='ACTIVE'and a.account_type='ASSET')then raise exception 'Active same-Company Treasury required'using errcode='23514';end if;
 if v->>'mode'='CUSTODIAN'and not exists(select 1 from public.parties t where t.company_id=cid and t.id=nullif(v->>'party_id','')::uuid and t.status='ACTIVE'and private.party_has_person_role(cid,t.id,'CUSTODIAN'))then raise exception 'Active same-Company Custodian required'using errcode='23514';end if;
 insert into public.payment_workflow_preferences(company_id,request_id,request_hash,scope_key,version,kind,mode,treasury_id,party_id,source_file,source_hash,month_from,month_through,approval_reference,created_by)
 values(cid,request_id,h,scope,last_version+1,v->>'kind',v->>'mode',nullif(v->>'treasury_id','')::uuid,nullif(v->>'party_id','')::uuid,v->>'source_file',v->>'source_hash',v->>'month_from',v->>'month_through',v->>'approval_reference',actor)returning * into p;
 return to_jsonb(p);
end $$;

create function public.read_payment_preferences(cid uuid)returns jsonb language plpgsql stable security definer set search_path=''as $$
begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT'))then raise exception 'Company accountant access required'using errcode='42501';end if;
 return coalesce((select jsonb_agg(to_jsonb(p))from(select distinct on(scope_key)* from public.payment_workflow_preferences where company_id=cid order by scope_key,version desc)p),'[]');
end $$;

create function public.read_source_payment_policies(cid uuid,source_ids uuid[])returns jsonb language plpgsql stable security definer set search_path=''as $$
begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT'))then raise exception 'Company accountant access required'using errcode='42501';end if;
 if source_ids is null or cardinality(source_ids)>500 then raise exception 'Bounded source page required'using errcode='22023';end if;
 return coalesce((select jsonb_agg(jsonb_build_object('source_id',s.id,'company_id',cid,'policy_id',p.id,'mode',p.mode,'party_id',p.party_id,'treasury_id',p.treasury_id,'reference',p.approval_reference,
 'contradicted',coalesce((s.completion->>'funding_mode'in('TREASURY','CUSTODIAN')and s.completion->>'funding_mode'<>p.mode),false)or(nullif(s.completion->>'treasury_id','')is not null and s.completion->>'treasury_id'is distinct from p.treasury_id::text)or coalesce(s.completion->>'funding_contradiction'='true',false)or(s.cash_treasury_id is not null and s.cash_treasury_id is distinct from p.treasury_id)or(nullif(s.completion->>'funding_confirmation_party_id','')is not null and s.completion->>'funding_confirmation_party_id'is distinct from p.party_id::text)or(nullif(s.completion->>'custodian_id','')is not null and s.completion->>'custodian_id'is distinct from p.party_id::text)))
 from public.historical_source_records s join lateral(select e.*from public.payment_workflow_preferences e where e.company_id=cid and e.kind='SOURCE_SET'and e.source_file=s.source_file and e.source_hash=s.source_hash and s.source_month between e.month_from and e.month_through and not exists(select 1 from public.payment_workflow_preferences newer where newer.company_id=cid and newer.scope_key=e.scope_key and newer.version>e.version)order by e.created_at desc,e.id desc limit 1)p on p.mode<>'NONE'
 where s.company_id=cid and s.id=any(source_ids)and s.record_type='GENERAL'and s.outflow_minor>0 and coalesce(s.funding_minor,0)=0),'[]');
end $$;
revoke all on function public.configure_payment_preferences(uuid,uuid,integer,jsonb),public.read_payment_preferences(uuid),public.read_source_payment_policies(uuid,uuid[])from public,anon,authenticated,service_role;
grant execute on function public.configure_payment_preferences(uuid,uuid,integer,jsonb),public.read_payment_preferences(uuid),public.read_source_payment_policies(uuid,uuid[])to authenticated;

-- Descriptive enrichment appends to existing audit history; source/document/journal rows are not edited.
create function public.append_source_note(cid uuid,source_id uuid,request_id uuid,note text,supporting_reference text)returns jsonb
language plpgsql security definer set search_path=''as $$
declare actor uuid:=auth.uid();h text;prior public.historical_source_audit;result_id uuid;
begin
 if actor is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT'))then raise exception 'Company accountant access required'using errcode='42501';end if;
 if request_id is null or coalesce(length(btrim(note)),0)not between 1 and 2000 or length(coalesce(supporting_reference,''))>1000 then raise exception 'Note and optional supporting reference required'using errcode='22023';end if;
 if not exists(select 1 from public.historical_source_records s where s.company_id=cid and s.id=source_id and s.record_type='GENERAL')then raise exception 'Company financial source required'using errcode='42501';end if;
 h:=encode(extensions.digest(convert_to(jsonb_build_array(actor,cid,source_id,btrim(note),btrim(coalesce(supporting_reference,'')))::text,'UTF8'),'sha256'),'hex');
 perform pg_advisory_xact_lock(hashtextextended('source_note:'||cid::text||request_id::text,0));
 select *into prior from public.historical_source_audit a where a.company_id=cid and a.action='NOTE_ADDED'and a.after_state->>'request_id'=request_id::text;
 if found then if prior.after_state->>'request_hash'<>h then raise exception 'Request key reused with different note'using errcode='22023';end if;return jsonb_build_object('id',prior.id,'company_id',cid,'source_id',source_id);end if;
 insert into public.historical_source_audit(company_id,source_id,actor_id,action,before_state,after_state)values(cid,source_id,actor,'NOTE_ADDED','{}',jsonb_build_object('request_id',request_id,'request_hash',h,'note',btrim(note),'supporting_reference',btrim(coalesce(supporting_reference,''))))returning id into result_id;
 return jsonb_build_object('id',result_id,'company_id',cid,'source_id',source_id);
end $$;
revoke all on function public.append_source_note(uuid,uuid,uuid,text,text)from public,anon,authenticated,service_role;
grant execute on function public.append_source_note(uuid,uuid,uuid,text,text)to authenticated;
