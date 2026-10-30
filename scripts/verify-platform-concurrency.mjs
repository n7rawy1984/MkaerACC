// Real PostgreSQL processes/connections, loopback only. No DATABASE_URL accepted.
// Optional test tool: npm install --prefix /tmp/narvo-postgres-runner embedded-postgres@18.4.0-beta.17
// PLATFORM_POSTGRES_RUNNER=/tmp/narvo-postgres-runner/node_modules/embedded-postgres/dist/index.js node scripts/verify-platform-concurrency.mjs
import assert from 'node:assert/strict';
import {mkdtemp,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {createServer} from 'node:net';
import {randomUUID} from 'node:crypto';
import {setTimeout as delay} from 'node:timers/promises';
import {platformTestDatabase} from './verify-platform-database.mjs';
import {platformRevocationFixture,verifyPlatformRevocation} from './verify-platform-revocation.mjs';
const runner=process.env.PLATFORM_POSTGRES_RUNNER ?? resolve('node_modules/embedded-postgres/dist/index.js');
const {default:EmbeddedPostgres}=await import(pathToFileURL(runner).href);
const root=await mkdtemp(join(tmpdir(),'narvo-p0-pg-'));
const socket=createServer();await new Promise((ok,fail)=>{socket.once('error',fail);socket.listen(0,'127.0.0.1',ok);});
const port=socket.address().port;await new Promise(ok=>socket.close(ok));
const server=new EmbeddedPostgres({databaseDir:join(root,'data'),user:'postgres',password:randomUUID(),port,persistent:false,
 createPostgresUser:false,initdbFlags:['--locale=C','--encoding=UTF8'],
 postgresFlags:['-h','127.0.0.1','-k',root,'-c','max_connections=20'],onLog:()=>{},onError:()=>{}});
const clients=new Set();
async function connect() {const c=server.getPgClient('postgres','127.0.0.1');await c.connect();clients.add(c);await c.query("set statement_timeout='15s'");return c;}
function adapter(c) {return {query:(...args)=>c.query(...args),exec:sql=>c.query(sql),close:()=>Promise.resolve(),transaction:async fn=>{
 const t=await connect();try{await t.query('begin');const r=await fn(adapter(t));await t.query('commit');return r;}catch(e){await t.query('rollback');throw e;}finally{clients.delete(t);await t.end();}
 }};}
try {
 await server.initialise();await server.start();const observer=await connect();
 const {db,files}=await platformTestDatabase(adapter(observer));
 console.log(`Real local PostgreSQL ${(await db.query('show server_version')).rows[0].server_version}; ${files.length} migrations replayed.`);
 await verifyPlatformRevocation(db);
 const f=await platformRevocationFixture(db);const {owner,member,claims,entity,version,membership,invite,accept,permissions,cmd,status,sessions,q}=f;
 const a=await connect(),b=await connect();
 assert.notEqual((await a.query('select pg_backend_pid() p')).rows[0].p,(await b.query('select pg_backend_pid() p')).rows[0].p);
 async function begin(c,uid) {await c.query('begin');await c.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify(claims(uid))]);await c.query('set local role authenticated');}
 async function waitBlocked(c) {
  const pid=(await c.query('select pg_backend_pid() p')).rows[0].p;return pid;
 }
 async function blocked(pid) {
  const deadline=Date.now()+5000;
  while(Date.now()<deadline) {const r=await observer.query("select wait_event_type,wait_event from pg_stat_activity where pid=$1",[pid]);
   if(r.rows[0]?.wait_event_type==='Lock') return;await delay(10);}
  throw new Error('Expected genuine blocked independent backend');
 }
 const bpid=await waitBlocked(b);
 async function revokeQuery(c,cid,v) {return c.query('select public.platform_admin_command($1,$2,$3::jsonb)',[
  'set_membership',randomUUID(),JSON.stringify({company_id:cid,user_id:member,role:'REVOKED',version:v,reason:'Controlled concurrent revocation'})]);}
 async function pending(call) {const p=call();p.catch(()=>{});await blocked(bpid);return {p};}
 let races=0;
 // Revoke holds the gate, acceptance genuinely blocks, then rejects after commit.
 {
  const cid=await entity();await membership(cid,'ACCOUNTANT');const old=await invite(cid);
  await begin(a,owner);await revokeQuery(a,cid,await version(cid));await begin(b,member);
  const {p}=await pending(()=>b.query('select public.accept_platform_invitation($1)',[old.id]));
  await a.query('commit');await assert.rejects(p,e=>e.code==='42501');await b.query('rollback');
  assert.deepEqual(await permissions(cid),{member:false,view:false,post:false});races++;
 }
 // Acceptance commits first; later successful revocation wins and replay fails.
 {
  const cid=await entity();const old=await invite(cid);const next=String(Number(await version(cid))+1);
  await begin(a,member);await a.query('select public.accept_platform_invitation($1)',[old.id]);await begin(b,owner);
  const {p}=await pending(()=>revokeQuery(b,cid,next));await a.query('commit');await p;await b.query('commit');
  await assert.rejects(()=>accept(old.id),e=>e.code==='42501');assert.deepEqual(await permissions(cid),{member:false,view:false,post:false});races++;
 }
 // Creation preceding revoke is invalidated, including a creation in flight.
 {
  const cid=await entity();await membership(cid,'ACCOUNTANT');const v=await version(cid);
  await begin(a,owner);const old=(await a.query("select public.platform_invitation_command('invite',$1,$2::jsonb) r",[randomUUID(),JSON.stringify({company_id:cid,email:f.email,role:'ACCOUNTANT'})])).rows[0].r;
  await begin(b,owner);const {p}=await pending(()=>revokeQuery(b,cid,v));await a.query('commit');await p;await b.query('commit');
  await assert.rejects(()=>accept(old.id),e=>e.code==='42501');races++;
 }
 // New creation ordered after a committed revocation is intentional reauthorization.
 {
  const cid=await entity();await membership(cid,'ACCOUNTANT');await begin(a,owner);await revokeQuery(a,cid,await version(cid));await begin(b,owner);
  const {p}=await pending(()=>b.query("select public.platform_invitation_command('invite',$1,$2::jsonb) r",[randomUUID(),JSON.stringify({company_id:cid,email:f.email,role:'ACCOUNTANT'})]));
  await a.query('commit');const old=(await p).rows[0].r;await b.query('commit');await accept(old.id);assert.equal((await permissions(cid)).post,true);races++;
 }
 // Global deactivation commits before waiting acceptance; even fresh sessions after reenable cannot revive it.
 {
  const cid=await entity();const old=await invite(cid);const pv=(await q('select updated_at::text v from public.profiles where user_id=$1',[member]))[0].v;
  await begin(a,owner);await a.query("select public.platform_admin_command('set_user_status',$1,$2::jsonb)",[randomUUID(),JSON.stringify({id:member,version:pv,status:'INACTIVE',reason:'Concurrent disable'})]);
  await begin(b,member);const {p}=await pending(()=>b.query('select public.accept_platform_invitation($1)',[old.id]));await a.query('commit');await assert.rejects(p,e=>e.code==='42501');await b.query('rollback');
  await status('ACTIVE');await q('insert into auth.sessions(id,user_id) values($1,$2)',[sessions.get(member),member]);await assert.rejects(()=>accept(old.id),e=>e.code==='42501');races++;
 }
 // Suspension wins over an in-flight recipient; reactivation preserves the denial.
 {
  const cid=await entity();const old=await invite(cid);await begin(a,owner);
  await a.query("select public.platform_admin_command('set_lifecycle',$1,$2::jsonb)",[randomUUID(),JSON.stringify({id:cid,version:await version(cid),state:'SUSPENDED',reason:'Concurrent suspension'})]);
  await begin(b,member);const {p}=await pending(()=>b.query('select public.accept_platform_invitation($1)',[old.id]));await a.query('commit');await assert.rejects(p,e=>e.code==='42501');await b.query('rollback');
  await cmd('set_lifecycle',{id:cid,version:await version(cid),state:'ACTIVE',reason:'Synthetic reopen'});await assert.rejects(()=>accept(old.id),e=>e.code==='42501');races++;
 }
 // An old stronger invitation cannot race past a successful explicit downgrade.
 {
  const cid=await entity();await membership(cid,'ACCOUNTANT');const old=await invite(cid,'ACCOUNTING_ADMIN');await begin(a,owner);
  await a.query("select public.platform_admin_command('set_membership',$1,$2::jsonb)",[randomUUID(),JSON.stringify({company_id:cid,user_id:member,role:'MANAGEMENT_VIEWER',version:await version(cid),reason:'Concurrent downgrade'})]);
  await begin(b,member);const {p}=await pending(()=>b.query('select public.accept_platform_invitation($1)',[old.id]));await a.query('commit');await assert.rejects(p,e=>e.code==='42501');await b.query('rollback');
  assert.equal((await permissions(cid)).post,false);races++;
 }
 // Service acknowledgement genuinely overlaps revocation but cannot reinstate delivery or acceptance.
 {
  const cid=await entity();await membership(cid,'ACCOUNTANT');const old=await invite(cid);
  const lease=(await f.as(owner,'select public.claim_platform_delivery($1) r',[old.id]))[0].r;
  await begin(a,owner);await revokeQuery(a,cid,await version(cid));await b.query('begin');await b.query('set local role service_role');
  const {p}=await pending(()=>b.query("select public.finish_platform_delivery($1,$2,'DELIVERED')",[old.id,lease.lease_id]));
  await a.query('commit');await assert.rejects(p,e=>['42501','40001'].includes(e.code));await b.query('rollback');await assert.rejects(()=>accept(old.id),e=>e.code==='42501');races++;
 }
 console.log(`PASS: T08 ${races} controlled, genuinely overlapping independent-session orderings; observed PostgreSQL lock waits, no deadlocks, no stale restoration. Local synthetic server only.`);
} finally {
 for(const c of clients){try{await c.query('rollback');await c.end();}catch{/* already closed */}}
 await server.stop();await rm(root,{recursive:true,force:true});
}
