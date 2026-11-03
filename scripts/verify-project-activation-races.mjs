// Native local PostgreSQL only. Never accepts a hosted database URL or credentials.
import assert from'node:assert/strict';import{readFileSync,writeFileSync,mkdtempSync}from'node:fs';import{rm}from'node:fs/promises';import{tmpdir}from'node:os';import{join,resolve}from'node:path';import{pathToFileURL}from'node:url';import{randomUUID}from'node:crypto';import{createServer}from'node:net';import{setTimeout as delay}from'node:timers/promises';import{platformTestDatabase}from'./verify-platform-database.mjs';
const runner=process.env.PROJECT_POSTGRES_RUNNER??'/tmp/narvo-project-native/node_modules/embedded-postgres/dist/index.js';const{default:EmbeddedPostgres}=await import(pathToFileURL(runner).href);
const root=mkdtempSync(join(tmpdir(),'narvo-project-races-')),socket=createServer();await new Promise((ok,fail)=>{socket.once('error',fail);socket.listen(0,'127.0.0.1',ok)});const port=socket.address().port;await new Promise(ok=>socket.close(ok));
const server=new EmbeddedPostgres({databaseDir:join(root,'data'),user:'postgres',password:randomUUID(),port,persistent:false,createPostgresUser:false,initdbFlags:['--locale=C','--encoding=UTF8'],postgresFlags:['-h','127.0.0.1','-k',root,'-c','max_connections=10'],onLog:()=>{},onError:()=>{}});
const clients=new Set(),scenarios=[],actor=randomUUID(),company=randomUUID(),projects=Array.from({length:7},()=>randomUUID());let started=false;
async function connect(){const c=server.getPgClient('postgres','127.0.0.1');await c.connect();clients.add(c);await c.query("set statement_timeout='15s'");return c;}
const as=async c=>{await c.query('begin');await c.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:actor})]);await c.query('set local role authenticated');};
const rpc=(c,p,stamp,key,reason='Approved project start')=>c.query('select public.activate_project($1,$2,$3,$4,$5) r',[company,p,stamp,key,reason]);
async function wait(observer,pid){for(let i=0;i<150;i++){if((await observer.query('select wait_event_type from pg_stat_activity where pid=$1',[pid])).rows[0]?.wait_event_type==='Lock')return;await delay(20)}throw Error('Independent lock wait not observed');}
try{
 await server.initialise();await server.start();started=true;const observer=await connect();await platformTestDatabase({query:(...a)=>observer.query(...a),exec:s=>observer.query(s),close:async()=>{}},{through:'20261101130000'});
 await observer.query("insert into auth.users(id,email) values($1,'project-race@example.invalid')",[actor]);await observer.query("insert into public.companies(id,code,name) values($1,'PROJECT-RACE','Synthetic project race')",[company]);await observer.query("insert into public.company_memberships(company_id,user_id,role) values($1,$2,'ACCOUNTING_ADMIN')",[company,actor]);
 for(const p of projects)await observer.query("insert into public.projects(id,company_id,code,name,status) values($1,$2,$3,'Synthetic planning project','PLANNING')",[p,company,p]);
 for(const m of['20261102120000_commercial_company_onboarding.sql','20261103120000_project_activation.sql'])await observer.query(readFileSync(resolve('supabase/migrations',m),'utf8'));
 const a=await connect(),b=await connect(),pid=(await b.query('select pg_backend_pid() pid')).rows[0].pid;
 for(const[index,mode]of['same-request','different-request','changed-intent','first-rolls-back','metadata-wins','membership-revocation-wins','company-suspension-wins'].entries()){
  const p=projects[index],stamp=(await observer.query('select updated_at::text stamp from public.projects where id=$1',[p])).rows[0].stamp,key=randomUUID();let first;
  if(mode==='metadata-wins'){await a.query('begin');await a.query("update public.projects set notes='Concurrent metadata' where id=$1",[p]);}
  else if(mode==='membership-revocation-wins'){await a.query('begin');await a.query("update public.company_memberships set status='INACTIVE' where company_id=$1 and user_id=$2",[company,actor]);}
  else if(mode==='company-suspension-wins'){await a.query('begin');await a.query("update public.companies set status='INACTIVE' where id=$1",[company]);}
  else{await as(a);first=await rpc(a,p,stamp,key);}
  await as(b);const second=rpc(b,p,stamp,mode==='different-request'||mode==='first-rolls-back'?randomUUID():key,mode==='changed-intent'?'Different activation reason':'Approved project start');second.catch(()=>{});await wait(observer,pid);await a.query(mode==='first-rolls-back'?'rollback':'commit');
  const error=mode==='different-request'||mode==='metadata-wins'?'40001':mode==='changed-intent'?'22023':mode==='membership-revocation-wins'||mode==='company-suspension-wins'?'42501':null;
  if(error){await assert.rejects(second,e=>e.code===error);await b.query('rollback');}else{const r=await second;if(mode==='same-request')assert.deepEqual(r.rows[0].r,first.rows[0].r);await b.query('commit');}
  const count=(await observer.query('select count(*)::int n from public.project_activation_events where project_id=$1',[p])).rows[0].n;assert.equal(count,['metadata-wins','membership-revocation-wins','company-suspension-wins'].includes(mode)?0:1);
  scenarios.push({scenario:mode,status:'PASS',independentWaitingBackend:pid,auditEvents:count});
  if(mode==='membership-revocation-wins')await observer.query("update public.company_memberships set status='ACTIVE' where company_id=$1 and user_id=$2",[company,actor]);
 }
 assert.equal((await observer.query('select count(*)::int n from public.journal_entries')).rows[0].n,0);writeFileSync('/tmp/narvo-project-activation-races.json',JSON.stringify({status:'PASS',scenarios,hosted:false},null,2));console.log('PASS: 7 native independent-backend activation races; real lock waits observed; zero journals');
}finally{for(const c of clients){try{await c.query('rollback');await c.end()}catch{}}if(started)await server.stop();await rm(root,{recursive:true,force:true});}
