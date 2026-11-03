"""Authorized R0 hosted SELECT/GET assessment. No DDL/DML, Auth login or deployments."""
import os,json,base64,datetime,hashlib,re,urllib.request,urllib.error
from pathlib import Path
import dbus
os.umask(0o077)
REF='eqnzueginpkskbnqvgoc';OUT=Path('/tmp/narvo-cleanup-assessment-20261102');OUT.mkdir(exist_ok=True,mode=0o700);OUT.chmod(0o700)
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
def save(name,value):
 p=OUT/name;p.write_text(json.dumps(value,indent=2,ensure_ascii=False)+'\n');p.chmod(0o600)
identity=request('');assert identity['id']==REF and identity['name']=='MakerACC-Development' and identity['status']=='ACTIVE_HEALTHY'
import sys
if '--catalog' in sys.argv:
 catalog=query("""select jsonb_build_object('as_of',statement_timestamp(),'read_only',current_setting('transaction_read_only'),
 'columns',(select jsonb_agg(jsonb_build_object('schema',table_schema,'table',table_name,'column',column_name,'type',data_type) order by table_schema,table_name,ordinal_position) from information_schema.columns where table_schema in ('public','private','auth','storage')),
 'tables',(select jsonb_agg(jsonb_build_object('schema',n.nspname,'table',c.relname,'rls',c.relrowsecurity,'force_rls',c.relforcerowsecurity) order by n.nspname,c.relname) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private','auth','storage') and c.relkind in ('r','p')),
 'foreign_keys',(select jsonb_agg(jsonb_build_object('schema',n.nspname,'table',c.relname,'constraint',co.conname,'target_schema',rn.nspname,'target_table',rc.relname,'definition',pg_get_constraintdef(co.oid),'delete_action',co.confdeltype,'deferrable',co.condeferrable) order by n.nspname,c.relname,co.conname) from pg_constraint co join pg_class c on c.oid=co.conrelid join pg_namespace n on n.oid=c.relnamespace join pg_class rc on rc.oid=co.confrelid join pg_namespace rn on rn.oid=rc.relnamespace where co.contype='f' and (n.nspname in ('public','private','auth','storage') or rn.nspname in ('public','private','auth','storage'))),
 'triggers',(select jsonb_agg(jsonb_build_object('schema',n.nspname,'table',c.relname,'name',t.tgname,'enabled',t.tgenabled,'definition',pg_get_triggerdef(t.oid)) order by n.nspname,c.relname,t.tgname) from pg_trigger t join pg_class c on c.oid=t.tgrelid join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('public','private','auth','storage') and not t.tgisinternal),
 'functions',(select jsonb_agg(jsonb_build_object('schema',n.nspname,'name',p.proname,'signature',pg_get_function_identity_arguments(p.oid),'sha256',encode(sha256(convert_to(pg_get_functiondef(p.oid),'UTF8')),'hex'),'auth_execute',has_function_privilege('authenticated',p.oid,'execute'))) from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') and p.prokind='f'),
 'history',(select jsonb_agg(jsonb_build_object('version',version,'name',name) order by version) from supabase_migrations.schema_migrations)) evidence""")
 save('catalog.json',catalog);save('identity.json',{'project':{k:identity.get(k)for k in ['id','name','status','region']},'checked_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'hosted_writes':False});print('CATALOG',len(catalog['tables']),'tables;',len(catalog['foreign_keys']),'foreign keys; read-only',catalog['read_only'])
if '--inventory' in sys.argv or '--postflight' in sys.argv:
 catalog=json.loads((OUT/'catalog.json').read_text());cols={}
 for c in catalog['columns']:cols.setdefault((c['schema'],c['table']),set()).add(c['column'])
 inventory=query("""select jsonb_build_object('as_of',statement_timestamp(),'read_only',current_setting('transaction_read_only'),
 'companies',(select jsonb_agg(jsonb_build_object('id',id,'code',code,'name',name,'status',status,'created_by',created_by,'updated_by',updated_by,'created_at',created_at) order by code) from public.companies),
 'users',(select jsonb_agg(jsonb_build_object('id',u.id,'created_at',u.created_at,'last_sign_in_at',u.last_sign_in_at,'deleted_at',u.deleted_at,'banned_until',u.banned_until,'is_super_admin',u.is_super_admin,'is_anonymous',u.is_anonymous,'auth_role',u.role,'confirmed',u.confirmed_at is not null,'providers',(select jsonb_agg(provider order by provider) from auth.identities i where i.user_id=u.id),'has_profile',exists(select 1 from public.profiles p where p.user_id=u.id),'fixture_email_hint',u.email ~* '(test|synthetic|fixture|race|example\\.com|example\\.test|\\.invalid$)') order by u.id) from auth.users u),
 'profiles',(select jsonb_agg(jsonb_build_object('user_id',user_id,'status',status,'locale',locale,'created_at',created_at,'updated_at',updated_at,'platform_access_epoch',platform_access_epoch) order by user_id) from public.profiles),
 'memberships',(select jsonb_agg(to_jsonb(m) order by company_id,user_id) from public.company_memberships m),
 'administrators',(select jsonb_agg(to_jsonb(a) order by user_id) from private.system_administrators a),
 'entities',(select jsonb_agg(to_jsonb(e) order by company_id) from private.platform_entities e),
 'customers',(select jsonb_agg(jsonb_build_object('id',c.id,'code',c.code,'name',c.name,'version',c.version,'created_at',c.created_at,'contact_present',c.contact_email is not null,'contact_matches_auth',(select jsonb_agg(u.id) from auth.users u where lower(u.email)=lower(c.contact_email))) order by c.id) from private.platform_customers c),
 'invitations',(select jsonb_agg((to_jsonb(i)-'email')||jsonb_build_object('matching_auth_ids',(select jsonb_agg(u.id) from auth.users u where lower(u.email)=lower(i.email))) order by i.id) from private.platform_invitations i),
 'delivery_jobs',(select jsonb_agg(to_jsonb(j)-array['lease_id','leased_until'] order by invitation_id) from private.platform_delivery_jobs j),
 'subscriptions',(select jsonb_agg(to_jsonb(s)-'payment_reference' order by company_id) from private.company_subscriptions s),
 'provisions',(select jsonb_agg(to_jsonb(p)-'intent_hash' order by company_id) from private.company_accounting_provisions p),
 'platform_events',(select jsonb_agg(jsonb_build_object('id',id,'actor_id',actor_id,'action',action,'target_id',target_id,'request_id',request_id,'created_at',created_at,'metadata_keys',(select jsonb_agg(key) from jsonb_object_keys(metadata) key)) order by created_at,id) from private.platform_events),
 'platform_requests',(select jsonb_agg(jsonb_build_object('actor_id',actor_id,'request_id',request_id,'command_name',command_name,'receipt_id',receipt->>'id','receipt_present',receipt is not null,'created_at',created_at) order by actor_id,request_id) from private.platform_requests),
 'mfa_factors',(select jsonb_agg(jsonb_build_object('id',id,'user_id',user_id,'factor_type',factor_type,'status',status,'created_at',created_at,'updated_at',updated_at) order by user_id,id) from auth.mfa_factors),
 'storage_buckets',(select jsonb_agg(jsonb_build_object('id',id,'public',public,'owner',owner,'owner_id',owner_id,'created_at',created_at) order by id) from storage.buckets),
 'storage_objects',(select jsonb_agg(jsonb_build_object('id',id,'bucket_id',bucket_id,'owner',owner,'owner_id',owner_id,'created_at',created_at,'path_sha256',encode(sha256(convert_to(name,'UTF8')),'hex'),'uuid_path_components',(select jsonb_agg(x) from unnest(string_to_array(name,'/')) x where x ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')) order by id) from storage.objects),
 'auth_audit',(select jsonb_build_object('rows',count(*),'earliest',min(created_at),'latest',max(created_at),'actor_ids',(select jsonb_agg(distinct payload->>'actor_id') from auth.audit_log_entries where payload->>'actor_id' ~ '^[0-9a-fA-F-]{36}$')) from auth.audit_log_entries),
 'sessions',(select jsonb_agg(jsonb_build_object('user_id',user_id,'count',n,'latest_created_at',latest) order by user_id) from (select user_id,count(*) n,max(created_at) latest from auth.sessions group by user_id) x)) evidence""")
 save('inventory-postflight.json' if '--postflight' in sys.argv else 'inventory.json',inventory)
 table_evidence={};company_counts={}
 for offset in range(0,len(catalog['tables']),15):
  tables=catalog['tables'][offset:offset+15];pairs=[]
  for t in tables:
   ns=t['schema'];name=t['table'];assert re.fullmatch('[a-z_][a-z0-9_]*',ns) and re.fullmatch('[a-z_][a-z0-9_]*',name)
   # Hash application data server-side; Auth secrets are never selected or transferred.
   fingerprint=",'sha256',encode(sha256(convert_to(coalesce(string_agg(to_jsonb(t)::text,E'\\n' order by to_jsonb(t)::text),''),'UTF8')),'hex')" if ns in ('public','private') else ''
   pairs.append("'"+ns+'.'+name+"',(select jsonb_build_object('rows',count(*)"+fingerprint+") from "+ns+'.'+name+" t)")
  table_evidence.update(query('select jsonb_build_object('+','.join(pairs)+') evidence'))
 for (ns,name),fields in cols.items():
  if ns in ('public','private') and 'company_id' in fields:
   company_counts[ns+'.'+name]=query('select coalesce(jsonb_agg(x order by company_id),\'[]\') evidence from (select company_id,count(*) rows from '+ns+'.'+name+' group by company_id)x')
 save('table-evidence-postflight.json' if '--postflight' in sys.argv else 'table-evidence.json',table_evidence)
 save('company-counts-postflight.json' if '--postflight' in sys.argv else 'company-counts.json',company_counts)
 if '--postflight' not in sys.argv:
  references={}
  for fk in catalog['foreign_keys']:
   if (fk['target_schema'],fk['target_table']) not in [('auth','users'),('public','profiles')]:continue
   ns=fk['schema'];name=fk['table'];column=re.search(r'FOREIGN KEY \(([^,)]+)\)',fk['definition'])
   if not column:continue
   column=column[1].strip('"');assert re.fullmatch('[a-z_][a-z0-9_]*',column)
   group=',company_id' if 'company_id' in cols.get((ns,name),set()) else ''
   key=ns+'.'+name+'.'+column
   references[key]=query('select coalesce(jsonb_agg(x),\'[]\') evidence from (select '+column+' user_id'+group+',count(*) rows from '+ns+'.'+name+' where '+column+' is not null group by '+column+group+')x')
  save('user-reference-counts.json',references)
  # Audit payload contains IP/email/session data; retain only attribution counts.
  save('auth-audit-attribution.json',query("select coalesce(jsonb_agg(x),'[]') evidence from (select payload->>'actor_id' actor_id,payload->>'action' action,count(*) rows from auth.audit_log_entries group by payload->>'actor_id',payload->>'action')x"))
  funcs=query("select jsonb_object_agg(p.proname,pg_get_functiondef(p.oid)) evidence from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('public','private') and p.proname in ('platform_admin_command','platform_member','invalidate_platform_invitations','reject_platform_audit_mutation')")
  save('admin-operation-flags.json',{'definitions_sha256':{k:hashlib.sha256(v.encode()).hexdigest()for k,v in funcs.items()},'set_lifecycle_supported':"command_name='set_lifecycle'" in funcs['platform_admin_command'],'set_user_status_supported':"command_name='set_user_status'" in funcs['platform_admin_command'],'member_revoke_supported':"REVOKED" in funcs['platform_member'],'delete_company_operation_present':"'delete_company'" in funcs['platform_admin_command'],'delete_user_operation_present':"'delete_user'" in funcs['platform_admin_command'],'archive_freezes_access':"'ARCHIVED'" in funcs['platform_admin_command'],'auth_session_revocation_on_inactive':"delete from auth.sessions" in funcs['platform_admin_command'].lower()})
  backups=request('/database/backups');save('backup-metadata.json',{k:backups.get(k)for k in ['region','pitr_enabled','walg_enabled']}|{'available_backups':[{k:b.get(k)for k in ['id','status','inserted_at','updated_at','is_physical_backup']}for b in backups.get('backups',[])],'restore_window':{k:v for k,v in (backups.get('physical_backup_data')or{}).items()if k in ['earliest_restore_time','latest_restore_time','earliest_physical_backup_time','latest_physical_backup_time']}})
 print('INVENTORY READ ONLY:',len(inventory['companies']or[]),'Companies,',len(inventory['users']or[]),'Auth users;',len(table_evidence),'table counts;',len(company_counts),'Company dimensions')

if '--provenance' in sys.argv:
 # In-memory correlation only; never persist email values.
 raw=query("select coalesce(jsonb_agg(jsonb_build_object('id',id,'email',email)),'[]') evidence from auth.users")
 domains={};prefixes={}
 for u in raw:
  email=u['email']or'';local,_,domain=email.partition('@');safe_domain=domain if domain.endswith(('.invalid','.test')) or domain in ('example.com','example.org') else 'NON_RESERVED'
  prefix=re.sub(r'[0-9]+','N',local).split('-N')[0] if safe_domain!='NON_RESERVED' else 'NON_RESERVED'
  domains[safe_domain]=domains.get(safe_domain,0)+1;prefixes[prefix]=prefixes.get(prefix,0)+1
 save('fixture-domain-summary.json',{'domains':domains,'synthetic_prefixes':prefixes})
 save('user-fixture-provenance.json',[{'id':u['id'],'reserved_test_domain':bool(re.search(r'@(example\.invalid|[^@]+\.invalid|example\.test|example\.com)$',u['email']or'',re.I)),'fixture_prefix':next((v for pat,v in [(r'^maker-p2v-','P2_VERIFICATION'),(r'^maker-p3-','P3_VERIFICATION'),(r'^maker-p4-','P4_VERIFICATION'),(r'^maker-p5a-','P5A_VERIFICATION'),(r'^p5a','P5A_VERIFICATION'),(r'^p[345][-_]','PHASE_VERIFICATION'),(r'^maker-p2-','P2_DIAGNOSTIC')] if re.search(pat,u['email']or'',re.I)),None)}for u in raw])
 print('SANITIZED PROVENANCE',domains)
if '--dependencies' in sys.argv:
 out={}
 for schema,table,column in [('auth','refresh_tokens','user_id'),('auth','flow_state','user_id'),('private','platform_invitations','recipient_user_id'),('storage','objects','owner_id'),('storage','buckets','owner_id'),('storage','s3_multipart_uploads','owner_id'),('storage','s3_multipart_uploads_parts','owner_id')]:
  out[schema+'.'+table+'.'+column]=query('select coalesce(jsonb_agg(x),\'[]\') evidence from (select t.'+column+'::text user_id,count(*) rows from '+schema+'.'+table+' t join auth.users u on u.id::text=t.'+column+'::text group by t.'+column+')x')
 save('non-fk-identity-counts.json',out)
 save('event-uuid-relationships.json',query("select coalesce(jsonb_agg(x),'[]') evidence from (select id,target_id,(select coalesce(jsonb_object_agg(key,value),'{}') from jsonb_each_text(metadata) where value ~ '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$') uuid_fields from private.platform_events)x"))
 flags=json.loads((OUT/'admin-operation-flags.json').read_text());flags['set_lifecycle_supported']=any(x['name']=='platform_admin_command'for x in json.loads((OUT/'catalog.json').read_text())['functions']) and "when 'set_lifecycle'" in query("select pg_get_functiondef('public.platform_admin_command(text,uuid,jsonb)'::regprocedure) evidence");save('admin-operation-flags.json',flags)
 print('NON-FK AND AUDIT RELATIONSHIPS CAPTURED READ ONLY')
if '--financial' in sys.argv:
 save('financial-summary.json',query("""select jsonb_build_object('as_of',statement_timestamp(),'read_only',current_setting('transaction_read_only'),
 'journal_totals',(select jsonb_agg(x order by company_id) from (select company_id,count(*) journals from public.journal_entries group by company_id)x),
 'unbalanced_journals',(select count(*) from (select j.id from public.journal_entries j left join public.journal_lines l on l.journal_entry_id=j.id group by j.id having count(l.id)<2 or coalesce(sum(l.debit_minor),0)<>coalesce(sum(l.credit_minor),0))x),
 'expense_states',(select jsonb_agg(x order by company_id,status) from (select company_id,status,count(*) rows from public.expenses group by company_id,status)x),
 'source_states',(select jsonb_agg(x order by company_id,review_status) from (select company_id,review_status,count(*) rows from public.historical_source_records group by company_id,review_status)x),
 'browser_delete_privileges',(select jsonb_agg(jsonb_build_object('table',t,'authenticated',has_table_privilege('authenticated',t,'delete'),'anon',has_table_privilege('anon',t,'delete'),'service_role',has_table_privilege('service_role',t,'delete'))) from unnest(array['public.companies','public.company_memberships','public.profiles','public.journal_entries','private.platform_events'])t)) evidence"""));print('FINANCIAL COUNTS/INTEGRITY AND DELETE-GRANT REVIEW READ ONLY')
if '--candidate-provenance' in sys.argv:
 save('company-fixture-provenance.json',query("""select coalesce(jsonb_agg(x order by code),'[]') evidence from (
 select c.id,c.code,substring(c.code from '([0-9]{13}-[0-9a-f]{6})$') run_marker,
 count(m.id) memberships,count(m.id) filter(where u.email like '%'||substring(c.code from '([0-9]{13}-[0-9a-f]{6})$')||'%') same_run_auth_memberships,
 bool_and(u.email ~* '^maker-p(2v|3|4)-[^@]+@example\\.invalid$') all_member_auths_have_verified_phase_pattern
 from public.companies c left join public.company_memberships m on m.company_id=c.id left join auth.users u on u.id=m.user_id
 where c.code ~ '^P(2V[AB]|[34]-[AB])-' group by c.id,c.code)x"""));print('COMPANY RUN-MARKER/AUTH RELATIONSHIPS CHECKED READ ONLY')
if '--activity' in sys.argv:
 cutoff=json.loads((OUT/'inventory.json').read_text())['as_of'];assert re.fullmatch('[0-9T:+. -]+',cutoff)
 save('concurrent-auth-activity.json',query("select jsonb_build_object('as_of',statement_timestamp(),'read_only',current_setting('transaction_read_only'),'current_refresh_rows',(select count(*) from auth.refresh_tokens),'refresh_rows_created_since_inventory',(select coalesce(jsonb_agg(x),'[]') from (select user_id,count(*) rows,min(created_at) earliest,max(created_at) latest from auth.refresh_tokens where created_at>='"+cutoff+"'::timestamptz group by user_id)x)) evidence"));print('TOKEN COUNTS/UUID ATTRIBUTION ONLY; NO TOKEN VALUES READ')
if '--protected-snapshot' in sys.argv:
 deny=json.loads((OUT/'protected-denylist.immutable.v1.json').read_text());ids=deny['protected_company_ids'];assert all(re.fullmatch('[0-9a-f-]{36}',x)for x in ids);literal=','.join("'"+x+"'::uuid"for x in ids)
 counts=json.loads((OUT/'company-counts.json').read_text());parts=[]
 for key in counts:
  assert re.fullmatch('(public|private)\\.[a-z_]+',key)
  parts.append("'"+key+"',(select coalesce(jsonb_agg(x order by company_id),'[]') from (select company_id,count(*) rows,encode(sha256(convert_to(coalesce(string_agg(to_jsonb(t)::text,E'\\n' order by to_jsonb(t)::text),''),'UTF8')),'hex') sha256 from "+key+" t where company_id in ("+literal+") group by company_id)x)")
 users=','.join("'"+u+"'::uuid"for u in deny['protected_auth_user_ids'])
 for key,table,condition in [('__protected_company_rows','public.companies','id in ('+literal+')'),('__protected_profiles','public.profiles','user_id in ('+users+')'),('__administrators','private.system_administrators','true'),('__permissions','public.permissions','true'),('__role_permissions','public.role_permissions','true')]:
  parts.append("'"+key+"',(select jsonb_build_object('rows',count(*),'sha256',encode(sha256(convert_to(coalesce(string_agg(to_jsonb(t)::text,E'\\n' order by to_jsonb(t)::text),''),'UTF8')),'hex')) from "+table+" t where "+condition+")")
 sql='select '+' || '.join('jsonb_build_object('+','.join(parts[i:i+20])+')'for i in range(0,len(parts),20))+' evidence'
 save('protected-company-fingerprints.json',query(sql));(OUT/'protected-company-validation-query.sql').write_text('-- READ ONLY. Compare every table/Company count and SHA256 to protected-company-fingerprints.json.\nbegin transaction isolation level repeatable read read only;\nset local statement_timeout=45000;\n'+sql+';\ncommit;\n');(OUT/'protected-company-validation-query.sql').chmod(0o600)
 print('PROTECTED COMPANY BASELINES',len(ids),'Companies across',len(counts),'tables; SELECT-only independent query saved')
if '--auth-candidate-dependencies' in sys.argv:
 ids=json.loads((OUT/'candidate-allowlist.json').read_text())['auth_candidate_ids'];assert len(ids)==9 and all(re.fullmatch('[0-9a-f-]{36}',u)for u in ids);literal=','.join("'"+u+"'::uuid"for u in ids)
 save('auth-candidate-dependencies.json',query("select jsonb_agg(x order by id) evidence from (select u.id,(select count(*) from public.profiles p where p.user_id=u.id) profiles,(select count(*) from public.company_memberships m where m.user_id=u.id) memberships,(select count(*) from auth.identities i where i.user_id=u.id) identities,(select count(*) from auth.sessions s where s.user_id=u.id) sessions,(select count(*) from auth.refresh_tokens r where r.user_id=u.id::text) refresh_rows,(select count(*) from auth.mfa_amr_claims a join auth.sessions s on s.id=a.session_id where s.user_id=u.id) amr_claims,(select count(*) from auth.mfa_factors f where f.user_id=u.id) mfa_factors,(select count(*) from storage.objects o where o.owner=u.id or o.owner_id=u.id::text) storage_owned_objects from auth.users u where u.id in ("+literal+"))x"));print('NINE AUTH CANDIDATE DEPENDENCY COUNTS; NO SECRET FIELDS')
if '--verify-validation' in sys.argv:
 path=OUT/'post-cleanup-validation.sql';text=path.read_text();body='\n'.join(line for line in text.splitlines()if not line.lstrip().startswith('--'));statements=[x.strip()for x in body.split(';')if x.strip()];selects=[x for x in statements if x.lower().startswith('select ')];assert len(selects)>15 and all(x.lower().startswith(('select ','begin transaction ','set local ','commit'))for x in statements)
 result=query(';'.join('explain (format json) '+x for x in selects)+";select jsonb_build_object('read_only',current_setting('transaction_read_only'),'planned_selects',"+str(len(selects))+") evidence")
 save('validation-query-review.json',result|{'sql_file_sha256':hashlib.sha256(path.read_bytes()).hexdigest(),'method':'PostgreSQL EXPLAIN only, no ANALYZE; post-cleanup expected outcomes not claimed before cleanup','no_cleanup_execution':True});print('SELECT-ONLY VALIDATION QUERIES PLAN',len(selects),'PASS')
