"""Authorized R0 hosted SELECT/GET assessment. No DDL/DML, Auth login or deployments."""
import os,json,base64,datetime,hashlib,re,urllib.request,urllib.error
from pathlib import Path
import dbus
os.umask(0o077)
REF='eqnzueginpkskbnqvgoc';OUT=Path('docs/release/r0-production-impact');OUT.mkdir(exist_ok=True,parents=True)
bus=dbus.SessionBus();service=dbus.Interface(bus.get_object('org.freedesktop.secrets','/org/freedesktop/secrets'),'org.freedesktop.Secret.Service');items,_=service.SearchItems({'service':'Supabase CLI','username':'supabase'});assert items,'Existing unlocked Supabase CLI credential unavailable'
_,session=service.OpenSession('plain',dbus.String('',variant_level=1))
try:credential=bytes(dbus.Interface(bus.get_object('org.freedesktop.secrets',items[0]),'org.freedesktop.Secret.Item').GetSecret(session)[2]).decode()
finally:dbus.Interface(bus.get_object('org.freedesktop.secrets',session),'org.freedesktop.Secret.Session').Close()
if credential.startswith('go-keyring-base64:'):credential=base64.b64decode(credential.split(':',1)[1]).decode()
def request(path,sql=None):
 data=None if sql is None else json.dumps({'query':'begin transaction isolation level repeatable read read only;set local statement_timeout=45000;'+sql+';commit;'}).encode()
 req=urllib.request.Request('https://api.supabase.com/v1/projects/'+REF+path,data=data,headers={'Authorization':'Bearer '+credential,'Content-Type':'application/json'},method='GET' if sql is None else 'POST')
 with urllib.request.urlopen(req,timeout=60) as res:return json.load(res)
def query(sql):return next(x['evidence'] for x in request('/database/query',sql) if 'evidence' in x)
def save(name,value):(OUT/name).write_text(json.dumps(value,indent=2,ensure_ascii=False)+'\n')
if '--postflight' in __import__('sys').argv:
 catalog=json.loads((OUT/'catalog.json').read_text());tables=catalog['company_tables']
 pairs=["'"+t+"',(select jsonb_build_object('rows',count(*),'sha256',encode(sha256(convert_to(coalesce(string_agg(to_jsonb(t)::text,E'\\n' order by to_jsonb(t)::text),''),'UTF8')),'hex')) from public."+t+" t)" for t in tables]
 after=query("select jsonb_build_object('as_of',statement_timestamp(),'public_company_owned',jsonb_build_object("+','.join(pairs)+"),'companies',(select encode(sha256(convert_to(coalesce(jsonb_agg(to_jsonb(c) order by id)::text,''),'UTF8')),'hex') from public.companies c),'private_platform_entities',(select encode(sha256(convert_to(coalesce(jsonb_agg(to_jsonb(e) order by company_id)::text,''),'UTF8')),'hex') from private.platform_entities e),'subscriptions',(select encode(sha256(convert_to(coalesce(jsonb_agg(to_jsonb(s) order by company_id)::text,''),'UTF8')),'hex') from private.company_subscriptions s)) evidence")
 before=json.loads((OUT/'read-only-baseline.json').read_text());keys=[k for k in before if k!='as_of'];comparison={k:before[k]==after[k] for k in keys}
 save('read-only-postflight.json',{'baseline_as_of':before['as_of'],'postflight':after,'unchanged':comparison,'all_unchanged':all(comparison.values())})
 details=query("""select jsonb_build_object('transaction_read_only',current_setting('transaction_read_only'),
 'footprints',(select jsonb_agg(jsonb_build_object('company_id',c.id,'accounts',(select count(*) from public.accounts a where a.company_id=c.id),'projects',(select count(*) from public.projects a where a.company_id=c.id),'expenses',(select count(*) from public.expenses a where a.company_id=c.id),'journals',(select count(*) from public.journal_entries a where a.company_id=c.id)) order by c.code) from public.companies c),
 'dependencies',(select jsonb_agg(jsonb_build_object('name',n,'present',to_regprocedure(n) is not null)) from unnest(array['private.lock_platform_authorization()','private.platform_actor(boolean)','private.platform_read_actor()','public.is_company_member(uuid)','private.platform_text(jsonb,text,integer,boolean)','private.subscription_effective_state(private.company_subscriptions,date)','public.provision_company_accounting(uuid,jsonb)','public.get_my_company_subscription(uuid)','public.list_company_subscriptions(integer,integer,text)','private.guard_subscription_new_business()']) n),
 'actor_default',(select pg_get_function_arguments('private.platform_actor(boolean)'::regprocedure)),
 'enum_labels',(select jsonb_object_agg(typname,labels) from (select t.typname,jsonb_agg(e.enumlabel order by e.enumsortorder) labels from pg_type t join pg_namespace n on n.oid=t.typnamespace join pg_enum e on e.enumtypid=t.oid where n.nspname='public' and t.typname in ('account_type','system_account_key','treasury_account_type') group by t.typname) x),
 'relations',(select jsonb_agg(jsonb_build_object('name',x,'present',to_regclass(x) is not null)) from unnest(array['public.companies','public.company_memberships','public.profiles','public.accounts','public.treasury_accounts','private.platform_entities','private.platform_customers','private.platform_events','private.platform_requests','private.company_subscriptions','private.company_accounting_provisions','private.reference_counters']) x),
 'function_hashes',(select jsonb_agg(jsonb_build_object('schema',n.nspname,'name',p.proname,'signature',pg_get_function_identity_arguments(p.oid),'sha256',encode(sha256(convert_to(pg_get_functiondef(p.oid),'UTF8')),'hex')) order by n.nspname,p.proname,pg_get_function_identity_arguments(p.oid)) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') and p.prokind='f'),
 'migration_count',(select count(*) from supabase_migrations.schema_migrations),
 'new_objects_absent',to_regclass('private.company_legacy_eligibility') is null and to_regclass('private.company_initialization_scope') is null and to_regprocedure('private.company_commercial_readiness(uuid)') is null and to_regprocedure('public.get_platform_onboarding(uuid,uuid,integer,integer,text)') is null) evidence""")
 details['function_definitions_unchanged']=sorted((x['schema'],x['name'],x['signature'],x['sha256']) for x in catalog['functions'])==sorted((x['schema'],x['name'],x['signature'],x['sha256']) for x in details.pop('function_hashes'));save('dependency-postflight.json',details);print('READ ONLY POSTFLIGHT',comparison,'history',details['migration_count']);raise SystemExit(0)
identity=request('');assert identity['id']==REF and identity['name']=='MakerACC-Development' and identity['status']=='ACTIVE_HEALTHY'
save('identity.json',{'checked_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'identity':{k:identity.get(k) for k in ['id','name','status','region','created_at']},'sql_transaction':'REPEATABLE READ READ ONLY','hosted_writes':False})
catalog=query("""select jsonb_build_object('transaction_read_only',current_setting('transaction_read_only'),'database_version',version(),
'migrations',(select jsonb_agg(jsonb_build_object('version',version,'name',name,'statements_sha256',encode(sha256(convert_to(array_to_string(statements,E'\n'),'UTF8')),'hex')) order by version) from supabase_migrations.schema_migrations),
'columns',(select jsonb_agg(jsonb_build_object('schema',table_schema,'table',table_name,'column',column_name,'type',data_type)) from information_schema.columns where table_schema='private' and table_name in ('platform_entities','platform_customers','company_subscriptions','company_accounting_provisions','platform_events')),
'new_objects',jsonb_build_object('legacy_registry',to_regclass('private.company_legacy_eligibility'),'initialization_scope',to_regclass('private.company_initialization_scope'),'readiness',to_regprocedure('private.company_commercial_readiness(uuid)'),'onboarding',to_regprocedure('public.get_platform_onboarding(uuid,uuid,integer,integer,text)')),
'functions',(select jsonb_agg(jsonb_build_object('schema',n.nspname,'name',p.proname,'signature',pg_get_function_identity_arguments(p.oid),'sha256',encode(sha256(convert_to(pg_get_functiondef(p.oid),'UTF8')),'hex'),'security_definer',p.prosecdef,'config',p.proconfig,'auth_execute',has_function_privilege('authenticated',p.oid,'execute'),'anon_execute',has_function_privilege('anon',p.oid,'execute'))) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') and p.prokind='f'),
'guard_triggers',(select jsonb_agg(jsonb_build_object('schema',n.nspname,'table',c.relname,'name',t.tgname,'enabled',t.tgenabled,'definition',pg_get_triggerdef(t.oid))) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where t.tgfoid='private.guard_subscription_new_business()'::regprocedure and not t.tgisinternal),
'company_tables',(select jsonb_agg(c.relname order by c.relname) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname='public' and c.relkind in ('r','p') and exists(select 1 from pg_attribute a where a.attrelid=c.oid and a.attname='company_id' and not a.attisdropped))) evidence""")
save('catalog.json',catalog)
# Definitions are inspected in memory, not persisted; never invoke privileged commands.
defs=query("select jsonb_object_agg(n.nspname||'.'||p.proname,pg_get_functiondef(p.oid)) evidence from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('private','public') and p.proname in ('subscription_effective_state','guard_subscription_new_business','get_my_company_subscription','list_company_subscriptions','provision_company_accounting')")
save('existing-contract-flags.json',{'guard_mentions_readiness':'company_commercial_readiness' in defs['private.guard_subscription_new_business'],'member_has_commercial_readiness':'commercial_readiness' in defs['public.get_my_company_subscription'],'member_unmanaged_compatibility':'UNMANAGED' in defs['public.get_my_company_subscription'],'effective_state_definition_sha256':hashlib.sha256(defs['private.subscription_effective_state'].encode()).hexdigest()})
print('IDENTITY/CATALOG CAPTURED READ ONLY; migrations',len(catalog['migrations']),'triggers',len(catalog['guard_triggers']))
try:
 backups=request('/database/backups');safe={k:backups.get(k) for k in ['region','pitr_enabled','walg_enabled']};safe['top_level_fields']=list(backups);safe['backups']=[{k:x.get(k) for k in ['id','inserted_at','updated_at','status','is_physical_backup','size']} for x in backups.get('backups',[])];safe['physical_backup_data']={k:v for k,v in (backups.get('physical_backup_data') or {}).items() if isinstance(v,(bool,int,float)) or k in ['earliest_restore_time','latest_restore_time','earliest_physical_backup_time','latest_physical_backup_time']};save('backup-metadata.json',safe);print('BACKUP METADATA CAPTURED')
except urllib.error.HTTPError as e:save('backup-metadata.json',{'status':'UNAVAILABLE','http_status':e.code});print('BACKUP METADATA HTTP',e.code)
# Expose only safe request outcomes; no bearer material is logged or written.
if '--impact' in __import__('sys').argv:
 assert 'select case when s.company_id is null' in defs['private.subscription_effective_state'].lower()
 impact=query("""with raw as (
 select c.id,c.code,c.name,c.status company_status,e.lifecycle,e.accounting_setup,e.customer_id,cu.name customer_name,
 exists(select 1 from private.platform_events ev where ev.target_id=c.id and ev.action='create_entity') platform_created,
 (e.customer_id is not null and cu.id is not null) customer_ok,
 (select count(*) from public.company_memberships m join public.profiles p on p.user_id=m.user_id where m.company_id=c.id and m.role='ACCOUNTING_ADMIN' and m.status='ACTIVE' and p.status='ACTIVE') active_accounting_admins,
 (select count(*) from public.company_memberships m where m.company_id=c.id and m.status='ACTIVE') active_memberships,
 exists(select 1 from private.company_accounting_provisions p where p.company_id=c.id) provision_evidence,
 s.company_id is not null has_subscription,s.state subscription_stored_state,s.plan_key,s.starts_on,s.ends_on,s.payment_status,
 private.subscription_effective_state(s,(statement_timestamp() at time zone 'Asia/Dubai')::date) effective_subscription
 from public.companies c left join private.platform_entities e on e.company_id=c.id
 left join private.platform_customers cu on cu.id=e.customer_id left join private.company_subscriptions s on s.company_id=c.id
 ), flags as(select *,code='MAKER' and not platform_created legacy_seed_eligible,
 coalesce(company_status='ACTIVE' and (lifecycle='ACTIVE' or (code='MAKER' and not platform_created and lifecycle is null)),false) active_ok,
 coalesce(accounting_setup='COMPLETE' and provision_evidence,false) foundation_ok,
 effective_subscription in ('TRIAL','ACTIVE') subscription_ok from raw),ready as(select *,
 active_ok and ((legacy_seed_eligible and (not has_subscription or subscription_ok)) or (customer_ok and active_accounting_admins>0 and foundation_ok and subscription_ok)) ready_after,
 case when effective_subscription in ('UNMANAGED','TRIAL','ACTIVE') then 'FULL' else 'LIMITED' end access_before
 from flags)
 select jsonb_build_object('as_of_utc',statement_timestamp(),'as_of_dubai',(statement_timestamp() at time zone 'Asia/Dubai')::date,'transaction_read_only',current_setting('transaction_read_only'),
 'companies',(select jsonb_agg(to_jsonb(ready)||jsonb_build_object('access_after',case when ready_after then 'FULL' else 'LIMITED' end,'newly_limited',access_before='FULL' and not ready_after) order by code) from ready),
 'company_code_constraints',(select jsonb_agg(pg_get_constraintdef(oid)) from pg_constraint where conrelid='public.companies'::regclass and contype in ('p','u'))) evidence""")
 save('company-impact.json',impact)
 local=sorted(Path('supabase/migrations').glob('*.sql'));remote=catalog['migrations'];expected='76aef69124d8eccc6b7df8f6152fcddf5f37b7a17934fe3926b674f71d395f67';sqlhash=hashlib.sha256(local[-1].read_bytes()).hexdigest();assert sqlhash==expected
 versions=[p.name[:14] for p in local];assert [x['version'] for x in remote]==versions[:-1],'Unexpected history divergence: stop'
 # Only SELECT migration history text in memory; persist hashes/comparison, no SQL bodies.
 statement_rows=query("select jsonb_agg(jsonb_build_object('version',version,'name',name,'statements',statements) order by version) evidence from supabase_migrations.schema_migrations")
 alignment=[]
 def normalized(s):return re.sub(r'\s+','',s).rstrip(';')
 for p,row in zip(local[:-1],statement_rows):
  text=p.read_text();joined=';\n'.join(row['statements'] or []);alignment.append({'version':row['version'],'name_matches':p.stem[15:]==row['name'],'file_sha256':hashlib.sha256(p.read_bytes()).hexdigest(),'history_join_sha256':hashlib.sha256(joined.encode()).hexdigest(),'whitespace_semicolon_normalized_match':normalized(text)==normalized(joined)})
 save('migration-alignment.json',{'local_count':len(local),'hosted_count':len(remote),'versions_exact_prefix':True,'pending':[local[-1].name],'pending_sha256':sqlhash,'expected_sha256':expected,'pending_hash_match':True,'applied_statement_comparisons':alignment,'note':'Whitespace/semicolon comparison is evidence, not a SQL semantic parser; mismatch requires inspection.'})
 tables=catalog['company_tables'];assert all(re.fullmatch('[a-z_]+',t) for t in tables)
 pairs=["'"+t+"',(select jsonb_build_object('rows',count(*),'sha256',encode(sha256(convert_to(coalesce(string_agg(to_jsonb(t)::text,E'\\n' order by to_jsonb(t)::text),''),'UTF8')),'hex')) from public."+t+" t)" for t in tables]
 baseline=query("select jsonb_build_object('as_of',statement_timestamp(),'public_company_owned',jsonb_build_object("+','.join(pairs)+"),'companies',(select encode(sha256(convert_to(coalesce(jsonb_agg(to_jsonb(c) order by id)::text,''),'UTF8')),'hex') from public.companies c),'private_platform_entities',(select encode(sha256(convert_to(coalesce(jsonb_agg(to_jsonb(e) order by company_id)::text,''),'UTF8')),'hex') from private.platform_entities e),'subscriptions',(select encode(sha256(convert_to(coalesce(jsonb_agg(to_jsonb(s) order by company_id)::text,''),'UTF8')),'hex') from private.company_subscriptions s)) evidence")
 save('read-only-baseline.json',baseline)
 print('COMPANY IMPACT CAPTURED',len(impact['companies']),'Companies; newly LIMITED',sum(c['newly_limited'] for c in impact['companies']))
