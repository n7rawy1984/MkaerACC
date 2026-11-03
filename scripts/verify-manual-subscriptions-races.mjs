// Native, independent PostgreSQL connections. Disposable synthetic LOCAL data only.
// No hosted DATABASE_URL accepted; no journal/payment/financial transaction is posted.
// PLATFORM_POSTGRES_RUNNER=/tmp/narvo-subscription-postgres-runner/node_modules/embedded-postgres/dist/index.js node scripts/verify-manual-subscriptions-races.mjs
import assert from 'node:assert/strict';
import {mkdtemp,rm,readFile,writeFile} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {join,resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {createServer} from 'node:net';
import {randomUUID,createHash} from 'node:crypto';
import {setTimeout as delay} from 'node:timers/promises';
import {platformTestDatabase} from './verify-platform-database.mjs';
const runner=process.env.PLATFORM_POSTGRES_RUNNER ?? resolve('node_modules/embedded-postgres/dist/index.js');
const {default:EmbeddedPostgres}=await import(pathToFileURL(runner).href);
const root=await mkdtemp(join(tmpdir(),'narvo-subscription-races-'));
const listener=createServer();await new Promise((ok,fail)=>{listener.once('error',fail);listener.listen(0,'127.0.0.1',ok);});
const port=listener.address().port;await new Promise(ok=>listener.close(ok));
const server=new EmbeddedPostgres({databaseDir:join(root,'data'),user:'postgres',password:randomUUID(),port,persistent:false,createPostgresUser:false,
 initdbFlags:['--locale=C','--encoding=UTF8'],postgresFlags:['-h','127.0.0.1','-k',root,'-c','max_connections=10'],onLog:()=>{},onError:()=>{}});
const clients=new Set(),scenarios=[],waits=[];
const owner=randomUUID(),admin=randomUUID(),ownerSession=randomUUID(),adminSession=randomUUID();let number=0;
const startedAt=new Date().toISOString();
const pinnedPaths=['supabase/migrations/20261101130000_manual_company_subscriptions.sql','src/platform/PlatformApplication.tsx','src/platform/platformApi.ts','src/platform/platformRecovery.ts','src/platform/platformText.ts','src/master/CompanySubscriptionStatus.tsx','src/auth/ProtectedApplication.tsx'];
const hashes=async()=>Object.fromEntries(await Promise.all(pinnedPaths.map(async p=>[p,createHash('sha256').update(await readFile(p)).digest('hex')])));
const beforeHashes=await hashes();
const q=async(c,sql,args=[])=>(await c.query(sql,args)).rows;
async function connect(){const c=server.getPgClient('postgres','127.0.0.1');await c.connect();clients.add(c);await c.query("set statement_timeout='15s'");return c;}
async function begin(c,member=false){await c.query('begin');await c.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:member?admin:owner,session_id:member?adminSession:ownerSession,aal:'aal2',amr:[{method:'totp',timestamp:Math.floor(Date.now()/1000)}]})]);await c.query('set local role authenticated');}
const command=(c,name,input)=>q(c,'select public.platform_admin_command($1,$2,$3::jsonb) r',[name,randomUUID(),JSON.stringify(input)]).then(r=>r[0].r);
const assign=(c,input,key=randomUUID())=>q(c,'select public.set_company_subscription($1,$2::jsonb) r',[key,JSON.stringify(input)]).then(r=>r[0].r);
async function committed(c,input){await begin(c);const r=await assign(c,input);await c.query('commit');return r;}
async function blocked(observer,pid,label){const deadline=Date.now()+5000;while(Date.now()<deadline){const r=(await q(observer,'select wait_event_type,wait_event from pg_stat_activity where pid=$1',[pid]))[0];if(r?.wait_event_type==='Lock'){waits.push({scenario:label,backend_pid:pid,...r});return;}await delay(20);}throw new Error(`No actual lock wait: ${label}`);}
const errorCode=async(p,code)=>{await assert.rejects(p,e=>e.code===code);return code;};
let dates;
async function entity(c,observer){await begin(c);const code=`SUB-RACE-${++number}`;
 const id=(await command(c,'create_entity',{code,name:code,tenant_slug:`subscription-race-${number}`,locale:'en',entity_kind:'BUSINESS',initial_admin_id:admin})).id;
 await command(c,'set_lifecycle',{id,version:'1',state:'ACTIVE',reason:'Disposable synthetic activation'});await c.query('commit');
 await observer.query("insert into public.expense_categories(company_id,code,name) values($1,'READ-MASTER','Synthetic readable master')",[id]);
 return {id,version:'0',plan_key:'STANDARD',subscription_state:'ACTIVE',starts_on:dates.today,ends_on:dates.tomorrow,billing_method:'MANUAL_BANK_TRANSFER',payment_status:'PAID',payment_reference:'SYNTHETIC-REFERENCE',reason:'Disposable native concurrency verification'};
}
async function state(observer,cid,expectedVersion,expectedState){
 const r=(await q(observer,`select s.version,s.state,s.payment_reference,c.status company_status,e.plan_key entity_plan,s.plan_key,
 (select count(*)::int from private.company_subscriptions where company_id=$1) subscriptions,
 (select count(*)::int from private.platform_events where target_id=$1 and action='set_subscription') audit,
 (select count(*)::int from private.platform_requests where command_name='set_subscription' and receipt->>'id'=$1::text) receipts
 from private.company_subscriptions s join public.companies c on c.id=s.company_id join private.platform_entities e on e.company_id=c.id where s.company_id=$1`,[cid]))[0];
 assert(r);assert.equal(r.version,expectedVersion);assert.equal(r.state,expectedState);assert.equal(r.subscriptions,1);assert.equal(r.audit,expectedVersion);assert.equal(r.receipts,expectedVersion);assert.equal(r.entity_plan,r.plan_key);
 return r;
}
async function probe(c,sql,args,code){await c.query('savepoint nonposting_probe');await errorCode(c.query(sql,args),code);await c.query('rollback to savepoint nonposting_probe');await c.query('release savepoint nonposting_probe');}
const reverse=(c,cid)=>c.query("select * from public.reverse_expense($1,$2,current_date,'Nonposting missing-source concurrency probe',$3)",[cid,randomUUID(),randomUUID()]);
const settleSql="select * from public.post_supplier_payment($1,current_date,$2,$3,1,'CASH',null,'Nonposting missing-source concurrency probe',$4::jsonb,$5)";
const settleArgs=cid=>[cid,randomUUID(),randomUUID(),JSON.stringify([{expense_id:randomUUID(),amount_minor:1}]),randomUUID()];
let evidence,failed;
try{
 await server.initialise();await server.start();const observer=await connect();
 const adapter={query:(...a)=>observer.query(...a),exec:s=>observer.query(s),close:async()=>{}};
 const {files}=await platformTestDatabase(adapter);assert.equal(files.length,64);
 for(const [uid,email] of [[owner,'owner@example.invalid'],[admin,'member@example.invalid']])await observer.query('insert into auth.users(id,email,email_confirmed_at) values($1,$2,now())',[uid,email]);
 await observer.query('insert into auth.sessions(id,user_id) values($1,$2),($3,$4)',[ownerSession,owner,adminSession,admin]);
 await observer.query('insert into private.system_administrators(user_id) values($1)',[owner]);
 await observer.query("insert into auth.mfa_factors(user_id,factor_type,status) values($1,'totp','verified')",[owner]);
 await observer.query('update auth.sessions set factor_id=(select id from auth.mfa_factors where user_id=$1) where user_id=$1',[owner]);
 dates=(await q(observer,"select ((statement_timestamp() at time zone 'Asia/Dubai')::date)::text today,(((statement_timestamp() at time zone 'Asia/Dubai')::date)+1)::text tomorrow,(((statement_timestamp() at time zone 'Asia/Dubai')::date)-1)::text yesterday"))[0];
 const a=await connect(),b=await connect();const apid=(await q(a,'select pg_backend_pid() pid'))[0].pid,bpid=(await q(b,'select pg_backend_pid() pid'))[0].pid;assert.notEqual(apid,bpid);
 const run=async(name,fn)=>{const start=waits.length;const detail=await fn();scenarios.push({name,result:'PASS',observed_lock_waits:waits.slice(start),...detail});console.log(`PASS: ${name}`);};
 const race=async(label,first,second,{code,rollback=false}={})=>{
  await begin(a);const one=await first(a);await begin(b);const pending=second(b);pending.catch(()=>{});
  await blocked(observer,bpid,label);await a.query(rollback?'rollback':'commit');
  if(code){await errorCode(pending,code);await b.query('rollback');return{first:one,second_sqlstate:code};}
  const two=await pending;await b.query('commit');return{first:one,second:two};
 };
 await run('Simultaneous creation / distinct keys',async()=>{const p=await entity(a,observer);const r=await race('creation',c=>assign(c,p),c=>assign(c,p),{code:'40001'});return{winner:await state(observer,p.id,1,'ACTIVE'),loser_sqlstate:r.second_sqlstate};});
 await run('Concurrent renewals / same expected version',async()=>{const p=await entity(a,observer);await committed(a,p);const next={...p,version:'1'};const r=await race('renewals',c=>assign(c,{...next,payment_reference:'RENEW-A'}),c=>assign(c,{...next,payment_reference:'RENEW-B'}),{code:'40001'});const winner=await state(observer,p.id,2,'ACTIVE');assert.equal(winner.payment_reference,'RENEW-A');return{winner,loser_sqlstate:r.second_sqlstate};});
 await run('Duplicate same request / normalized intent',async()=>{const p=await entity(a,observer),key=randomUUID();const r=await race('same-key',c=>assign(c,p,key),c=>assign(c,{...p,reason:` ${p.reason} `},key));assert.deepEqual(r.first,r.second);return{identical_receipts:true,winner:await state(observer,p.id,1,'ACTIVE')};});
 await run('Duplicate key / conflicting intent',async()=>{const p=await entity(a,observer),key=randomUUID();const r=await race('changed-intent',c=>assign(c,p,key),c=>assign(c,{...p,payment_reference:'DIFFERENT'},key),{code:'22023'});return{winner:await state(observer,p.id,1,'ACTIVE'),loser_sqlstate:r.second_sqlstate};});
 await run('First creator rolls back / waiter wins',async()=>{const p=await entity(a,observer);await race('rollback',c=>assign(c,p),c=>assign(c,p),{rollback:true});return{winner:await state(observer,p.id,1,'ACTIVE'),first_rolled_back:true};});
 for(const cancelFirst of [true,false])await run(cancelFirst?'Cancellation wins versus renewal':'Renewal wins versus cancellation',async()=>{
  const p=await entity(a,observer);await committed(a,p);const cancel={...p,version:'1',subscription_state:'CANCELLED'},renew={...p,version:'1',payment_reference:'RENEWED'};
  const r=await race(cancelFirst?'cancel-first':'renew-first',c=>assign(c,cancelFirst?cancel:renew),c=>assign(c,cancelFirst?renew:cancel),{code:'40001'});
  return{winner:await state(observer,p.id,2,cancelFirst?'CANCELLED':'ACTIVE'),loser_sqlstate:r.second_sqlstate};
 });
 for(const cancelled of [false,true])await run(cancelled?'Cancellation versus reads and nonposting settlement/reversal':'Date expiry versus reads and nonposting settlement/reversal',async()=>{
  const p=await entity(a,observer);await committed(a,p);const membersBefore=JSON.stringify(await q(observer,'select * from public.company_memberships where company_id=$1 order by id',[p.id]));
  await begin(a);await assign(a,{...p,version:'1',...(cancelled?{subscription_state:'CANCELLED'}:{starts_on:dates.yesterday,ends_on:dates.yesterday})});
  await begin(b,true);const prior=(await q(b,'select public.get_my_company_subscription($1) r',[p.id]))[0].r;assert.equal(prior.state,'ACTIVE');
  // Member reads and source validation proceed against committed MVCC state while owner mutation is open.
  await probe(b,settleSql,settleArgs(p.id),'23503');
  const pending=reverse(b,p.id);pending.catch(()=>{});await blocked(observer,bpid,cancelled?'cancel/reversal':'expiry/reversal');
  await a.query('commit');await errorCode(pending,'23503');await b.query('rollback');
  await begin(b,true);const after=(await q(b,'select public.get_my_company_subscription($1) r',[p.id]))[0].r;assert.equal(after.state,cancelled?'CANCELLED':'EXPIRED');assert.equal(after.access,'LIMITED');
  assert.equal((await q(b,'select count(*)::int n from public.expense_categories where company_id=$1',[p.id]))[0].n,1);
  await probe(b,settleSql,settleArgs(p.id),'23503');
  await b.query('savepoint missing_reversal');await errorCode(reverse(b,p.id),'23503');await b.query('rollback to savepoint missing_reversal');
  await b.query('commit');
  assert.equal(JSON.stringify(await q(observer,'select * from public.company_memberships where company_id=$1 order by id',[p.id])),membersBefore);
  return{member_read_before_commit:prior.state,member_read_after_commit:after.state,access:after.access,settlement_and_reversal_sqlstate:'23503 (missing synthetic source, not authorization denial)',financial_posting_executed:false};
 });
 await run('Subscription change rejects stale Company lifecycle version',async()=>{const p=await entity(a,observer);const r=await race('stale-company',c=>assign(c,p),c=>command(c,'set_lifecycle',{id:p.id,version:'2',state:'SUSPENDED',reason:'Synthetic stale company version'}),{code:'40001'});const winner=await state(observer,p.id,1,'ACTIVE');assert.equal(winner.company_status,'ACTIVE');return{winner,loser_sqlstate:r.second_sqlstate};});
 await run('Company suspension first / independent subscription metadata cannot grant access',async()=>{const p=await entity(a,observer);await race('company-first',c=>command(c,'set_lifecycle',{id:p.id,version:'2',state:'SUSPENDED',reason:'Synthetic independent Company suspension'}),c=>assign(c,p));const winner=await state(observer,p.id,1,'ACTIVE');assert.equal(winner.company_status,'INACTIVE');await begin(b,true);await errorCode(b.query('select public.get_my_company_subscription($1)',[p.id]),'42501');await b.query('rollback');return{winner,member_access_denied_sqlstate:'42501',contract:'Subscription version and Company lifecycle version are separate; ACTIVE subscription does not reactivate Company.'};});
 await run('Expiry wins / queued new master denied',async()=>{const p=await entity(a,observer);await committed(a,p);await begin(a);await assign(a,{...p,version:'1',starts_on:dates.yesterday,ends_on:dates.yesterday});await begin(b);await b.query('reset role');const pending=b.query("insert into public.expense_categories(company_id,code,name) values($1,'DENIED','Synthetic blocked category')",[p.id]);pending.catch(()=>{});await blocked(observer,bpid,'expiry/new-master');await a.query('commit');await errorCode(pending,'42501');await b.query('rollback');assert.equal((await q(observer,'select count(*)::int n from public.expense_categories where company_id=$1',[p.id]))[0].n,1);return{new_master_sqlstate:'42501',no_partial_master:true};});
 await run('New master wins / expiry waits then commits',async()=>{const p=await entity(a,observer);await committed(a,p);await begin(a);await a.query('reset role');await a.query("insert into public.expense_categories(company_id,code,name) values($1,'BEFORE-EXPIRY','Synthetic category before boundary')",[p.id]);await begin(b);const pending=assign(b,{...p,version:'1',starts_on:dates.yesterday,ends_on:dates.yesterday});pending.catch(()=>{});await blocked(observer,bpid,'master-first/expiry');await a.query('commit');await pending;await b.query('commit');assert.equal((await q(observer,'select count(*)::int n from public.expense_categories where company_id=$1',[p.id]))[0].n,2);await state(observer,p.id,2,'ACTIVE');return{ordered_before_expiry:true,new_master_count:2};});
 const zeroTables=['journal_entries','journal_lines','supplier_payments','supplier_payment_allocations','expenses','custody_advances','custody_settlements','custody_cash_returns','subcontractor_advances','subcontractor_certificates','subcontractor_payments','subcontractor_retention_releases','subcontractor_retention_payments','payroll_postings','salary_payments'];
 const financialCounts={};for(const t of zeroTables){financialCounts[t]=(await q(observer,`select count(*)::int n from public.${t}`))[0].n;assert.equal(financialCounts[t],0);}
 for(const t of ['financial_command_requests','reference_counters']){financialCounts[`private.${t}`]=(await q(observer,`select count(*)::int n from private.${t}`))[0].n;assert.equal(financialCounts[`private.${t}`],0);}
 assert.deepEqual(await hashes(),beforeHashes);
 evidence={stage:'Manual subscriptions final local concurrency gate',result:'PASS',started_at_utc:startedAt,finished_at_utc:new Date().toISOString(),method:{runner:'embedded-postgres@18.4.0-beta.17',postgresql_version:(await q(observer,'show server_version'))[0].server_version,independent_backend_pids:[apid,bpid],canonical_migrations:files.length,server_host:'127.0.0.1',dynamically_allocated_port:true,synthetic_auth:true,statement_timeout:'15s',lock_observation_timeout:'5s'},scenario_count:scenarios.length,scenarios,financial_counts:financialCounts,source_hashes:beforeHashes,source_unchanged:true,fixes_required:false,hosted_connections:false,existing_databases_touched:false,limitations:['Controlled schedules, not an unbounded stress test; synthetic Auth, no hosted runtime/MFA assertion.','Expiry uses past-end subscription periods, not a changed system clock or a real midnight rollover.','Settlement/reversal probes reach missing-source validation with SQLSTATE23503 and leave zero financial/request rows; they do not post transactions. Earlier successful disposable-engine settlement/reversal evidence remains separate.','Company version protects lifecycle commands; subscription version protects subscription mutations. Company suspension remains authoritative even with ACTIVE subscription metadata.','Payment reference/status are one current operator metadata record, not a separate payment ledger or proof of funds.'],cleanup:{clients_closed:false,disposable_server_stopped:false,data_directory_removed:false}};
}catch(e){failed=e;}
finally{
 for(const c of clients){try{await c.query('rollback');await c.end();}catch{/* continue cleanup of this disposable server */}}
 try{await server.stop();if(evidence)evidence.cleanup.disposable_server_stopped=true;}finally{await rm(root,{recursive:true,force:true});}
 if(evidence){evidence.cleanup.clients_closed=true;evidence.cleanup.data_directory_removed=true;evidence.harness_sha256=createHash('sha256').update(await readFile('scripts/verify-manual-subscriptions-races.mjs')).digest('hex');await writeFile('docs/release/local-manual-subscriptions-races-result.json',JSON.stringify(evidence,null,2)+'\n');}
}
if(failed){console.error(`FAIL: ${failed.message} (SQLSTATE ${failed.code??'none'})`);process.exit(1);}
else console.log(`PASS: ${scenarios.length}/${scenarios.length} native independent subscription scenarios; zero financial transactions; own server/data cleaned up.`);
