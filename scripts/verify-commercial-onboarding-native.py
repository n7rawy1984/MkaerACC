"""Disposable native PostgreSQL only; explicit local socket/port, no hosted URLs."""
import os,pathlib,tempfile,subprocess,socket,json,re,uuid,time,shutil,concurrent.futures,hashlib
ROOT=pathlib.Path(__file__).resolve().parents[1];BIN=pathlib.Path(os.environ.get('COMMERCIAL_POSTGRES_BIN','/usr/lib/postgresql/17/bin'));WORK=pathlib.Path(tempfile.mkdtemp(prefix='narvo-commercial-native-'));sock=socket.socket();sock.bind(('127.0.0.1',0));port=sock.getsockname()[1];sock.close();started=False;connections=[];scenarios=[]
env={k:v for k,v in os.environ.items() if not k.startswith('PG')};env['PGAPPNAME']='narvo-commercial-observer'
env['LD_LIBRARY_PATH']=str(BIN.parent/'lib')+':'+env.get('LD_LIBRARY_PATH','')
args=[os.environ.get('COMMERCIAL_PSQL','/usr/bin/psql'),'-X','-qAt','-v','ON_ERROR_STOP=1','-v','VERBOSITY=verbose','-h',str(WORK),'-p',str(port),'-U','postgres','-d','postgres']
def sql(s):
 p=subprocess.run(args,input=s,text=True,capture_output=True,env=env,timeout=45)
 if p.returncode:raise RuntimeError('Local PostgreSQL verification failed: '+p.stderr[:600])
 return p.stdout.strip()
def quote(s):return "'"+str(s).replace("'","''")+"'"
ids={k:str(uuid.uuid4()) for k in ['owner','admin','owner_session','admin_session']}
def begin(actor='owner'):
 claims={'sub':ids[actor],'session_id':ids[actor+'_session'],'aal':'aal2','amr':[{'method':'totp','timestamp':int(time.time())}]}
 return 'begin;set local "request.jwt.claims"='+quote(json.dumps(claims))+';'
def rpc(name,p,command=None):
 if command:return 'select public.platform_admin_command('+quote(command)+','+quote(uuid.uuid4())+'::uuid,'+quote(json.dumps(p))+'::jsonb);'
 return 'select public.'+name+'('+quote(uuid.uuid4())+'::uuid,'+quote(json.dumps(p))+'::jsonb);'
def owner(s):return sql(begin()+'set local role authenticated;'+s+'commit;')
def subscription(cid,version,state='TRIAL'):
 return {'id':cid,'version':str(version),'plan_key':'TRIAL','subscription_state':state,'starts_on':'2020-01-01','ends_on':'2099-12-31','billing_method':'NONE','payment_status':'NOT_REQUIRED','reason':'Synthetic native lifecycle'}
def make(n,complete=True):
 c=json.loads(owner(rpc('',{'code':'NATIVE-'+str(n),'name':'Synthetic native Company','tenant_slug':'native-'+str(n),'locale':'en','entity_kind':'BUSINESS','customer_id':customer,'initial_admin_id':ids['admin']},'create_entity')))['id']
 owner(rpc('',{'id':c,'version':'1','state':'ACTIVE','reason':'Synthetic activation'},'set_lifecycle'))
 if complete:owner(rpc('provision_company_accounting',{'id':c,'version':'2','code':'NATIVE-'+str(n),'treasury_name':'Synthetic cash','treasury_type':'CASH','reason':'Synthetic foundation'}))
 return c

def hold(command):
 p=subprocess.Popen(args,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,bufsize=1,env={**env,'PGAPPNAME':'narvo-commercial-a'});connections.append(p)
 p.stdin.write(begin()+'set local role authenticated;'+command+"select 'READY';\n");p.stdin.flush()
 for _ in range(8):
  line=p.stdout.readline().strip()
  if line=='READY':return p
  if p.poll() is not None:raise RuntimeError('First local transaction failed')
 raise RuntimeError('First local transaction did not become ready')
def finish(p):p.stdin.write('commit;\n');p.stdin.flush();p.stdin.close();assert p.wait(timeout=15)==0

def race(label,command,cid,allowed=False):
 a=hold(command)
 b=subprocess.Popen(args,stdin=subprocess.PIPE,stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,env={**env,'PGAPPNAME':'narvo-commercial-b'});connections.append(b)
 with concurrent.futures.ThreadPoolExecutor(max_workers=1) as pool:
  future=pool.submit(b.communicate,begin('admin')+"set local statement_timeout='12s';insert into public.expense_categories(company_id,code,name) values("+quote(cid)+",'NATIVE-RACE','Synthetic category');commit;",timeout=20)
  waiting=None
  for _ in range(100):
   v=sql("select pid||':'||wait_event_type from pg_stat_activity where application_name='narvo-commercial-b' and wait_event_type='Lock';")
   if v:waiting=v;break
   time.sleep(.03)
  assert waiting,'Expected independent connection lock wait absent'
  finish(a);out,err=future.result()
  if allowed:assert b.returncode==0,err[:300]
  else:assert b.returncode!=0 and '42501' in err,err[:300]
  count=int(sql('select count(*) from public.expense_categories where company_id='+quote(cid)+" and code='NATIVE-RACE';"));assert count==(1 if allowed else 0)
  scenarios.append({'name':label,'result':'PASS','independent_waiting_backend':waiting,'new_master_allowed':allowed,'inserted_rows':count})
try:
 subprocess.run([str(BIN/'initdb'),'-D',str(WORK/'data'),'-U','postgres','--auth=trust','--no-instructions','--locale=C','--encoding=UTF8'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,env=env)
 subprocess.run([str(BIN/'pg_ctl'),'-D',str(WORK/'data'),'-l',str(WORK/'server.log'),'-o',f'-h 127.0.0.1 -p {port} -k {WORK} -c max_connections=10','-w','start'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,env=env);started=True
 scaffold=re.search(r'await db.exec\(`(.*?)`\);', (ROOT/'scripts/verify-platform-database.mjs').read_text(),re.S).group(1)
 sql(scaffold)
 files=sorted((ROOT/'supabase/migrations').glob('*.sql'));assert len(files)==65
 for f in files:sql(f.read_text())
 for role in ['owner','admin']:
  sql('insert into auth.users(id,email,email_confirmed_at,encrypted_password) values('+quote(ids[role])+','+quote(role+'@example.invalid')+",now(),'synthetic-only');insert into auth.sessions(id,user_id) values("+quote(ids[role+'_session'])+','+quote(ids[role])+');')
 sql('insert into private.system_administrators(user_id) values('+quote(ids['owner'])+');insert into auth.mfa_factors(user_id,factor_type,status) values('+quote(ids['owner'])+",'totp','verified');update auth.sessions set factor_id=(select id from auth.mfa_factors where user_id="+quote(ids['owner'])+') where user_id='+quote(ids['owner'])+';')
 customer=json.loads(owner(rpc('',{'code':'NATIVE','name':'Synthetic native Customer'},'create_customer')))['id']
 c=make(1);owner(rpc('set_company_subscription',subscription(c,0)))
 race('Cancellation commits before waiting new business',rpc('set_company_subscription',subscription(c,1,'CANCELLED')),c)
 c=make(2);owner(rpc('set_company_subscription',subscription(c,0)))
 version=sql('select version from private.platform_entities where company_id='+quote(c)+';')
 race('Customer unlink commits before waiting new business',rpc('',{'id':c,'version':version,'name':'Synthetic native Company','entity_kind':'BUSINESS','plan_key':'TRIAL'},'update_entity'),c)
 c=make(3);owner(rpc('set_company_subscription',subscription(c,0,'CANCELLED')))
 race('Renewal commits before waiting new business',rpc('set_company_subscription',subscription(c,1)),c,True)
 c=make(4,False)
 race('Protected provisioning scope does not authorize another connection',rpc('provision_company_accounting',{'id':c,'version':'2','code':'NATIVE-4','treasury_name':'Synthetic cash','treasury_type':'CASH','reason':'Synthetic foundation'}),c)
 assert sql('select count(*) from private.company_initialization_scope;')=='0'
 assert sql('select count(*) from public.journal_entries;')=='0'
 result={'status':'PASS','method':'Owned disposable native PostgreSQL; independent psql connections and observed lock waits','server_version':sql('show server_version;'),'scenarios':scenarios,'canonical_migrations':len(files),'financial_postings':0,'hosted_connections':False,'cleanup':'pending','migration_sha256':hashlib.sha256(files[-1].read_bytes()).hexdigest()}
finally:
 for p in connections:
  if p.poll() is None:p.kill();p.wait()
 if started:subprocess.run([str(BIN/'pg_ctl'),'-D',str(WORK/'data'),'-m','immediate','-w','stop'],check=True,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,env=env)
 shutil.rmtree(WORK)
if 'result' in globals():
 result['cleanup']='Owned server stopped; clients closed; disposable data directory removed';(ROOT/'docs/release/local-commercial-onboarding-native-result.json').write_text(json.dumps(result,indent=2)+'\n');print('PASS: four focused independent native readiness/provisioning concurrency scenarios; local resources cleaned up.')
