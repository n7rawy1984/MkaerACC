// Actual PostgREST + disposable native PostgreSQL. Synthetic users/data only.
// Runtime credentials/JWTs stay in memory; no hosted URL or credential is accepted.
import assert from 'node:assert/strict';
import {mkdtempSync,writeFileSync,readFileSync} from 'node:fs';
import {rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join} from 'node:path';
import {randomUUID,randomBytes,createHmac,createHash} from 'node:crypto';
import {createServer} from 'node:net';
import {spawn} from 'node:child_process';
import {setTimeout as delay} from 'node:timers/promises';
import {hrOperationalFixture} from './hr-operational-fixture.mjs';
import {seedHrCase} from './hr-operational-case.mjs';
const {default:EmbeddedPostgres}=await import('/tmp/narvo-priority-native/node_modules/embedded-postgres/dist/index.js');
async function freePort(){const s=createServer();await new Promise(ok=>s.listen(0,'127.0.0.1',ok));const p=s.address().port;await new Promise(ok=>s.close(ok));return p}
const root=mkdtempSync(join(tmpdir(),'narvo-hr-readonly-')),port=await freePort(),http=await freePort(),jwtSecret=randomBytes(64).toString('hex'),dbPassword=randomUUID();
const server=new EmbeddedPostgres({databaseDir:join(root,'data'),user:'postgres',password:randomUUID(),port,persistent:false,createPostgresUser:false,initdbFlags:['--locale=C','--encoding=UTF8'],postgresFlags:['-h','127.0.0.1','-k',root,'-c','max_connections=20'],onLog:()=>{},onError:()=>{}});
const clients=[],checks=[];let started=false,rest;let restLog='';
const check=(v,m)=>{assert(v,m);checks.push(m);console.log('PASS',checks.length,m)};
async function connection(){const c=server.getPgClient('postgres','127.0.0.1');await c.connect();clients.push(c);await c.query("set statement_timeout='15s'");return c}
function token(actor){const enc=x=>Buffer.from(JSON.stringify(x)).toString('base64url'),header=enc({alg:'HS256',typ:'JWT'}),body=enc({role:'authenticated',sub:actor,aal:'aal2',exp:Math.floor(Date.now()/1000)+300});return header+'.'+body+'.'+createHmac('sha256',jwtSecret).update(header+'.'+body).digest('base64url')}
async function api(actor,path,body){const response=await fetch('http://127.0.0.1:'+http+path,{method:body===undefined?'GET':'POST',headers:{...(actor?{Authorization:'Bearer '+token(actor)}:{}),'Content-Type':'application/json'},...(body===undefined?{}:{body:JSON.stringify(body)})});return{status:response.status,data:await response.json()}}
try{
 await server.initialise();await server.start();started=true;const o=await connection();const q=(s,a=[])=>o.query(s,a.map(v=>v&&typeof v==='object'?JSON.stringify(v):v));
 const db={query:q,exec:s=>q(s),close:async()=>{},transaction:async fn=>{await q('begin');try{const r=await fn({query:q,exec:s=>q(s)});await q('commit');return r}catch(e){await q('rollback');throw e}}};
 const f=await seedHrCase(await hrOperationalFixture(db),{post:true});
 // Seed confidential source + audit through existing local fixture authority.
 const sid=randomUUID();await q("insert into public.historical_source_records(id,company_id,source_file,source_hash,source_reference,record_type,source_month,description,payroll_net_minor,raw_source,classification,created_by) values($1,$2,'synthetic-only',repeat('a',64),'READONLY-PRIVACY','PAYROLL','2026-09','Synthetic confidential payroll',1000,'{}','{}',$3)",[sid,f.company,f.admin]);
 const stamp=(await q('select updated_at::text stamp from public.historical_source_records where id=$1',[sid])).rows[0].stamp;await f.as(f.admin,"select public.complete_historical_source($1,$2,$3,'{\"reason\":\"Synthetic review\"}','PENDING')",[f.company,sid,stamp]);
 await q('create role hr_rpc_authenticator login noinherit password '+"'"+dbPassword+"'");await q('grant anon,authenticated to hr_rpc_authenticator');await q('grant connect on database postgres to hr_rpc_authenticator');
 rest=spawn(process.env.HR_POSTGREST_BIN??'/tmp/narvo-postgrest/postgrest',[],{env:{PATH:process.env.PATH,PGRST_DB_URI:`postgresql://hr_rpc_authenticator:${dbPassword}@127.0.0.1:${port}/postgres`,PGRST_DB_SCHEMAS:'public',PGRST_DB_ANON_ROLE:'anon',PGRST_JWT_SECRET:jwtSecret,PGRST_SERVER_HOST:'127.0.0.1',PGRST_SERVER_PORT:String(http),PGRST_DB_POOL:'4'},stdio:['ignore','pipe','pipe']});rest.on('error',e=>{restLog=e.message});rest.stdout.on('data',b=>restLog+=b);rest.stderr.on('data',b=>restLog+=b);
 let ready=false;for(let n=0;n<150;n++){try{const r=await fetch('http://127.0.0.1:'+http+'/');if(r.ok){ready=true;break}}catch{}await delay(100)}assert(ready,'Local PostgREST failed to start: '+restLog.slice(-1000));
 const fingerprints=async()=>JSON.stringify((await q("select jsonb_object_agg(name,hash) r from (select 'journal_lines' name,md5(coalesce(jsonb_agg(to_jsonb(t) order by id)::text,'')) hash from public.journal_lines t union all select 'postings',md5(coalesce(jsonb_agg(to_jsonb(t) order by id)::text,'')) from public.payroll_postings t union all select 'payments',md5(coalesce(jsonb_agg(to_jsonb(t) order by id)::text,'')) from public.salary_payments t) x")).rows[0].r);
 const before=await fingerprints();
 for(const actor of[f.admin,f.accountant]){
  const r=await api(actor,'/rpc/read_hr_workspace',{cid:f.company,m:f.month});check(r.status===200&&r.data.company_id===f.company,'Real PostgREST POST reads HR for '+(actor===f.admin?'Accounting Admin':'Accountant')+' without25006');
 }
 const get=await api(f.accountant,`/rpc/read_hr_workspace?cid=${f.company}&m=${f.month}`);check(get.status===200,'Real PostgREST GET supports STABLE HR read');
 for(const actor of[f.viewer,f.foreign,f.procurement,f.system]){const r=await api(actor,'/rpc/read_hr_workspace',{cid:f.company,m:f.month});check(r.status===403&&r.data.code==='42501','Unauthorized role/tenant cannot invoke HR projection')}
 check((await api(null,'/rpc/read_hr_workspace',{cid:f.company,m:f.month})).status===401,'Anonymous HR execution denied');
 for(const table of['hr_term_events','historical_source_records','historical_source_audit']){const r=await api(f.viewer,'/'+table+'?company_id=eq.'+f.company);check(r.status===200&&r.data.length===0,'Management Viewer reads no confidential '+table)}
 const a=await api(f.accountant,'/historical_source_records?company_id=eq.'+f.company),b=await api(f.accountant,'/historical_source_audit?company_id=eq.'+f.company);check(a.data.length===1&&b.data.length===1,'Accountant retains historical payroll source/audit visibility');
 const lite=await api(f.accountant,'/rpc/read_payroll_draft',{target_company_id:f.company,target_month:'2026-09-01'});check(lite.status===200&&lite.data.rows.length===0,'Pre-cutover Payroll Lite remains readable through actual RPC');
 check(before===await fingerprints(),'HR and Lite read RPCs change no journals, payroll postings or payments');
 // Revoked active-state access is not replaced by JWT/display role claims.
 await q("update public.profiles set status='INACTIVE' where user_id=$1",[f.accountant]);check((await api(f.accountant,'/rpc/read_hr_workspace',{cid:f.company,m:f.month})).status===403,'Inactive profile denied despite valid JWT');await q("update public.profiles set status='ACTIVE' where user_id=$1",[f.accountant]);
 await q("update public.company_memberships set status='INACTIVE' where company_id=$1 and user_id=$2",[f.company,f.accountant]);check((await api(f.accountant,'/rpc/read_hr_workspace',{cid:f.company,m:f.month})).status===403,'Inactive membership denied despite valid JWT');await q("update public.company_memberships set status='ACTIVE' where company_id=$1 and user_id=$2",[f.company,f.accountant]);
 const config=(await q("select p.proname,p.provolatile,has_function_privilege('authenticated',p.oid,'execute') auth_exec,p.prosrc from pg_proc p join pg_namespace n on n.oid=p.pronamespace where (n.nspname,p.proname) in (('private','hr_read_actor'),('private','operational_finance_actor'),('public','read_hr_workspace'))")).rows;
 check(config.find(x=>x.proname==='hr_read_actor').provolatile==='s'&&!config.find(x=>x.proname==='hr_read_actor').auth_exec&&config.find(x=>x.proname==='read_hr_workspace').provolatile==='s','Read authorization remains private and STABLE');
 check((config.find(x=>x.proname==='operational_finance_actor').prosrc.match(/for share/g)??[]).length===3,'Financial authorization retains all three master/profile/membership row locks');
 const c1=await connection(),c2=await connection();await c1.query('begin');await c1.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:f.admin})]);await c1.query("select private.operational_finance_actor($1,'payroll.manage')",[f.company]);await c2.query('begin');const pid=(await c2.query('select pg_backend_pid() id')).rows[0].id;const pending=c2.query('select 1 from public.companies where id=$1 for update',[f.company]);pending.catch(()=>{});let blocked=false;for(let n=0;n<100;n++){if((await q('select wait_event_type from pg_stat_activity where pid=$1',[pid])).rows[0]?.wait_event_type==='Lock'){blocked=true;break}await delay(20)}assert(blocked);await c1.query('commit');await pending;await c2.query('rollback');check(true,'Financial helper still holds an actual row lock until transaction end');
 const post=await f.sql('select public.post_payroll($1,$2,$3,$4) r',[f.company,f.period,f.draft.period.version,f.postKey]),ent=(await q('select * from public.payroll_entitlements where payroll_id=$1',[post])).rows[0];
 const pay=await f.sql("select public.pay_salary($1,$2,$3,'2026-11-05',100,'Actual synthetic partial payment',$4) r",[f.company,ent.id,f.bank,randomUUID()]);await f.sql("select public.reverse_salary_payment($1,$2,'2026-11-05','Synthetic correction',$3) r",[f.company,pay,randomUUID()]);await f.sql("select public.reverse_payroll($1,$2,'2026-11-05','Synthetic correction',$3) r",[f.company,post,randomUUID()]);
 check(String((await q('select private.hr_recovery_balance($1,$2) n',[f.company,f.loan.id])).rows[0].n)==='1000','Posting/payment/reversals preserve original advance and recovery balances');
 check(Number((await q('select count(*) n from (select journal_entry_id from public.journal_lines group by journal_entry_id having sum(debit_minor::numeric-credit_minor::numeric)<>0) x')).rows[0].n)===0,'Focused payroll lifecycle leaves every journal balanced');
 const migration=readFileSync('supabase/migrations/20261105120000_hr_operational_foundation.sql');writeFileSync('/tmp/narvo-hr-readonly-rpc.json',JSON.stringify({status:'PASS',checks,passed:checks.length,transport:'Actual local PostgREST GET/POST with signed synthetic JWTs and native PostgreSQL',migration_sha256:createHash('sha256').update(migration).digest('hex'),hosted:false},null,2));
 console.log('ALL PASS',checks.length);
}catch(e){console.error('FAIL',e.message,e.code,e.where??'');process.exitCode=1}finally{if(rest){rest.kill('SIGTERM');await new Promise(ok=>rest.once('exit',ok))}for(const c of clients){try{await c.query('rollback');await c.end()}catch{}}if(started)await server.stop();await rm(root,{recursive:true,force:true})}
