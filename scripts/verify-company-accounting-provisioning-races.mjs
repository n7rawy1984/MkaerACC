// PREPARED ONLY: genuine independent PostgreSQL backends; disposable local fixtures.
// Never accepts a hosted DATABASE_URL. Requires an installed optional native runner.
// PLATFORM_POSTGRES_RUNNER=/tmp/narvo-postgres-runner/node_modules/embedded-postgres/dist/index.js node scripts/verify-company-accounting-provisioning-races.mjs
import assert from 'node:assert/strict';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {createServer} from 'node:net';
import {randomUUID} from 'node:crypto';
import {setTimeout as delay} from 'node:timers/promises';
import {platformTestDatabase} from './verify-platform-database.mjs';
const runner=process.env.PLATFORM_POSTGRES_RUNNER ?? resolve('node_modules/embedded-postgres/dist/index.js');
const {default:EmbeddedPostgres}=await import(pathToFileURL(runner).href);
const root=await mkdtemp(join(tmpdir(),'narvo-accounting-races-'));
const socket=createServer();await new Promise((ok,fail)=>{socket.once('error',fail);socket.listen(0,'127.0.0.1',ok);});
const port=socket.address().port;await new Promise(ok=>socket.close(ok));
const server=new EmbeddedPostgres({databaseDir:join(root,'data'),user:'postgres',password:randomUUID(),port,persistent:false,
 createPostgresUser:false,initdbFlags:['--locale=C','--encoding=UTF8'],postgresFlags:['-h','127.0.0.1','-k',root,'-c','max_connections=10'],onLog:()=>{},onError:()=>{}});
const clients=new Set();
async function connect(){const c=server.getPgClient('postgres','127.0.0.1');await c.connect();clients.add(c);await c.query("set statement_timeout='15s'");return c;}
const adapter=c=>({query:(...args)=>c.query(...args),exec:sql=>c.query(sql),close:async()=>{}});
const owner=randomUUID(),admin=randomUUID(),session=randomUUID();let number=0;
const claims=()=>JSON.stringify({sub:owner,session_id:session,aal:'aal2',amr:[{method:'totp',timestamp:Math.floor(Date.now()/1000)}]});
async function begin(c){await c.query('begin');await c.query("select set_config('request.jwt.claims',$1,true)",[claims()]);await c.query('set local role authenticated');}
const rpc=(c,p,key=randomUUID())=>c.query('select public.provision_company_accounting($1,$2::jsonb) receipt',[key,JSON.stringify(p)]);
const command=(c,name,input)=>c.query('select public.platform_admin_command($1,$2,$3::jsonb) receipt',[name,randomUUID(),JSON.stringify(input)]);
async function entity(c){await begin(c);const code=`RACE-${++number}`;const id=(await command(c,'create_entity',{code,name:code,tenant_slug:`accounting-race-${number}`,locale:'en',entity_kind:'BUSINESS',initial_admin_id:admin})).rows[0].receipt.id;
 await command(c,'set_lifecycle',{id,version:'1',state:'ACTIVE',reason:'Disposable local race fixture'});await c.query('commit');
 return {id,version:'2',code,treasury_name:'Explicit synthetic cash location',treasury_type:'CASH',reason:'Disposable local race test'};}
async function assertBlocked(observer,pid){const deadline=Date.now()+5000;while(Date.now()<deadline){const r=await observer.query('select wait_event_type from pg_stat_activity where pid=$1',[pid]);if(r.rows[0]?.wait_event_type==='Lock')return;await delay(20);}throw new Error('No genuine overlapping PostgreSQL lock wait observed');}
async function foundation(observer,cid,exists=true){const r=(await observer.query("select (select count(*)::int from public.accounts where company_id=$1) accounts,(select count(*)::int from public.treasury_accounts where company_id=$1) treasury,(select count(*)::int from private.company_accounting_provisions where company_id=$1) provisions,(select count(*)::int from private.platform_events where target_id=$1 and action='provision_accounting') audit",[cid])).rows[0];assert.deepEqual(r,exists?{accounts:11,treasury:1,provisions:1,audit:1}:{accounts:0,treasury:0,provisions:0,audit:0});}
try{
 await server.initialise();await server.start();const observer=await connect();await platformTestDatabase(adapter(observer));
 for(const [uid,email] of [[owner,'race-owner@example.invalid'],[admin,'race-admin@example.invalid']])await observer.query('insert into auth.users(id,email,email_confirmed_at) values($1,$2,now())',[uid,email]);
 await observer.query('insert into auth.sessions(id,user_id) values($1,$2)',[session,owner]);
 await observer.query('insert into private.system_administrators(user_id) values($1)',[owner]);
 await observer.query("insert into auth.mfa_factors(user_id,factor_type,status) values($1,'totp','verified')",[owner]);
 await observer.query('update auth.sessions set factor_id=(select id from auth.mfa_factors where user_id=$1) where user_id=$1',[owner]);
 const a=await connect(),b=await connect();const apid=(await a.query('select pg_backend_pid() pid')).rows[0].pid,bpid=(await b.query('select pg_backend_pid() pid')).rows[0].pid;assert.notEqual(apid,bpid);
 for(const mode of ['same-key','equivalent-new-key','changed-intent','first-rolls-back']){
  const p=await entity(a),key=randomUUID();await begin(a);const first=await rpc(a,p,key);await begin(b);
  const next=rpc(b,mode==='changed-intent'?{...p,treasury_name:'Different unapproved location'}:p,mode==='same-key'?key:randomUUID());next.catch(()=>{});
  await assertBlocked(observer,bpid);await a.query(mode==='first-rolls-back'?'rollback':'commit');
  if(mode==='changed-intent'){await assert.rejects(next,e=>e.code==='22023');await b.query('rollback');}
  else{const second=await next;assert.equal(second.rows[0].receipt.id,p.id);if(mode==='same-key')assert.deepEqual(second.rows[0].receipt,first.rows[0].receipt);await b.query('commit');}
  await foundation(observer,p.id);
 }
 // Suspension wins the gate: waiting initialization must reject, creating nothing.
 {const p=await entity(a);await begin(a);await command(a,'set_lifecycle',{id:p.id,version:'2',state:'SUSPENDED',reason:'Synthetic concurrent freeze'});await begin(b);const next=rpc(b,p);next.catch(()=>{});await assertBlocked(observer,bpid);await a.query('commit');await assert.rejects(next,e=>e.code==='42501');await b.query('rollback');await foundation(observer,p.id,false);}
 // Initialization wins: concurrent lifecycle command cannot apply its stale entity version.
 {const p=await entity(a);await begin(a);await rpc(a,p);await begin(b);const next=command(b,'set_lifecycle',{id:p.id,version:'2',state:'SUSPENDED',reason:'Synthetic stale freeze'});next.catch(()=>{});await assertBlocked(observer,bpid);await a.query('commit');await assert.rejects(next,e=>e.code==='40001');await b.query('rollback');await foundation(observer,p.id);}
 const totals=(await observer.query('select (select count(*)::int from public.journal_entries) journals,(select count(*)::int from private.reference_counters) counters')).rows[0];assert.deepEqual(totals,{journals:0,counters:0});
 console.log('PASS: 6 independent two-backend accounting provisioning races; lock waits observed, one foundation per winner, zero journals/reference counters. Local synthetic server only.');
}finally{
 for(const c of clients){try{await c.query('rollback');await c.end();}catch{/* close best effort */}}
 try{await server.stop();}finally{await rm(root,{recursive:true,force:true});}
}
