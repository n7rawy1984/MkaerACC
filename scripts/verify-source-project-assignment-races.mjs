// Native local PostgreSQL only. Never accepts a hosted database URL or credentials.
import assert from'node:assert/strict';import{readFileSync,writeFileSync,mkdtempSync}from'node:fs';import{rm}from'node:fs/promises';import{tmpdir}from'node:os';import{join,resolve}from'node:path';import{pathToFileURL}from'node:url';import{randomUUID}from'node:crypto';import{createServer}from'node:net';import{setTimeout as delay}from'node:timers/promises';import{assignmentFixture}from'./source-project-assignment-fixture.mjs';
const runner=process.env.PROJECT_POSTGRES_RUNNER??'/tmp/narvo-project-native/node_modules/embedded-postgres/dist/index.js';const{default:EmbeddedPostgres}=await import(pathToFileURL(runner).href);
const root=mkdtempSync(join(tmpdir(),'narvo-project-races-')),socket=createServer();await new Promise((ok,fail)=>{socket.once('error',fail);socket.listen(0,'127.0.0.1',ok)});const port=socket.address().port;await new Promise(ok=>socket.close(ok));
const server=new EmbeddedPostgres({databaseDir:join(root,'data'),user:'postgres',password:randomUUID(),port,persistent:false,createPostgresUser:false,initdbFlags:['--locale=C','--encoding=UTF8'],postgresFlags:['-h','127.0.0.1','-k',root,'-c','max_connections=10'],onLog:()=>{},onError:()=>{}});
const clients=new Set(),scenarios=[];let started=false,fixture,actor,company;
async function connect(){const c=server.getPgClient('postgres','127.0.0.1');await c.connect();clients.add(c);await c.query("set statement_timeout='15s'");return c;}
const as=async c=>{await c.query('begin');await c.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:actor})]);await c.query('set local role authenticated');};
const rpc=(c,items,key,reason='Verified source attribution')=>c.query('select public.assign_source_projects($1,$2,$3,$4) r',[company,key,JSON.stringify(items),reason]);
async function wait(observer,pid){for(let i=0;i<150;i++){if((await observer.query('select wait_event_type from pg_stat_activity where pid=$1',[pid])).rows[0]?.wait_event_type==='Lock')return;await delay(20)}throw Error('Independent lock wait not observed');}
try{
 await server.initialise();await server.start();started=true;const observer=await connect();
 fixture=await assignmentFixture({query:(...a)=>observer.query(...a),exec:s=>observer.query(s),close:async()=>{}});actor=fixture.admin;company=fixture.company;
 await observer.query(readFileSync(resolve('supabase/migrations/20261103130000_source_project_assignment.sql'),'utf8'));
 const a=await connect(),b=await connect(),pid=(await b.query('select pg_backend_pid() pid')).rows[0].pid;
 for(const[index,mode]of['same-request','different-request','changed-intent','first-rolls-back','source-edit-wins','membership-revocation-wins','project-closure-wins','overlapping-batches'].entries()){
  const source=fixture.id(40+index),stamp=(await observer.query('select updated_at::text stamp from public.historical_source_records where id=$1',[source])).rows[0].stamp,key=randomUUID(),item={source_id:source,expected_updated_at:stamp,scope:'PROJECT',project_id:fixture.project};let first;
  if(mode==='source-edit-wins'){await a.query('begin');await a.query("update public.historical_source_records set completion=jsonb_build_object('notes','Concurrent edit'),updated_at=clock_timestamp(),updated_by=$2 where id=$1",[source,actor]);}
  else if(mode==='membership-revocation-wins'){await a.query('begin');await a.query("update public.company_memberships set status='INACTIVE' where company_id=$1 and user_id=$2",[company,actor]);}
  else if(mode==='project-closure-wins'){await a.query('begin');await a.query("update public.projects set status='CLOSED' where id=$1",[fixture.project]);}
  else{await as(a);first=await rpc(a,[item],key);}
  await as(b);const secondItems=mode==='overlapping-batches'?[item,{...item,source_id:fixture.id(49),expected_updated_at:(await observer.query('select updated_at::text stamp from public.historical_source_records where id=$1',[fixture.id(49)])).rows[0].stamp}]:[item];
  const second=rpc(b,secondItems,['different-request','first-rolls-back','overlapping-batches'].includes(mode)?randomUUID():key,mode==='changed-intent'?'Different reason':'Verified source attribution');second.catch(()=>{});await wait(observer,pid);await a.query(mode==='first-rolls-back'?'rollback':'commit');
  const error=['different-request','source-edit-wins','overlapping-batches'].includes(mode)?'40001':mode==='changed-intent'?'22023':mode==='membership-revocation-wins'?'42501':mode==='project-closure-wins'?'23514':null;
  if(error){await assert.rejects(second,e=>e.code===error);await b.query('rollback');}else{const r=await second;if(mode==='same-request')assert.deepEqual(r.rows[0].r,first.rows[0].r);await b.query('commit');}
  const count=(await observer.query("select count(*)::int n from public.source_project_assignment_events e where e.changes @> jsonb_build_array(jsonb_build_object('source_id',$1::text))",[source])).rows[0].n;assert.equal(count,['source-edit-wins','membership-revocation-wins','project-closure-wins'].includes(mode)?0:1);
  if(mode==='overlapping-batches')assert.equal((await observer.query('select allocation_scope from public.historical_source_records where id=$1',[fixture.id(49)])).rows[0].allocation_scope,null);
  scenarios.push({scenario:mode,status:'PASS',independentWaitingBackend:pid,auditEvents:count});
  if(mode==='membership-revocation-wins')await observer.query("update public.company_memberships set status='ACTIVE' where company_id=$1 and user_id=$2",[company,actor]);
  if(mode==='project-closure-wins')await observer.query("update public.projects set status='ACTIVE' where id=$1",[fixture.project]);
 }
 for(const [index,mode] of ['assignment-before-posting','posting-before-assignment'].entries()){
  const source=fixture.id(48+index),stamp=(await observer.query('select updated_at::text stamp from public.historical_source_records where id=$1',[source])).rows[0].stamp;
  const item={source_id:source,expected_updated_at:stamp,scope:'PROJECT',project_id:fixture.project};
  const post=c=>c.query('select * from public.post_historical_expense($1,$2,$3)',[company,source,JSON.stringify({target_expense_date:'2026-09-20',target_description:'SYN-'+(48+index),target_project_id:null,target_treasury_account_id:fixture.treasury,target_funding_mode:'TREASURY',target_payment_method:'CASH',target_net_amount_minor:'12550',target_vat_mode:'ZERO',target_has_tax_invoice:false,target_expense_category_id:fixture.category})]);
  await as(a);if(index===0)await rpc(a,[item],randomUUID());else await post(a);
  await as(b);const waiting=index===0?post(b):rpc(b,[item],randomUUID());waiting.catch(()=>{});await wait(observer,pid);await a.query('commit');await assert.rejects(waiting,e=>e.code===(index===0?'23514':'40001'));await b.query('rollback');
  scenarios.push({scenario:mode,status:'PASS',independentWaitingBackend:pid});
 }
 assert.equal((await observer.query('select count(*)::int n from public.journal_entries')).rows[0].n,1);
 assert.equal((await observer.query('select journal_entry_id from public.journal_lines group by journal_entry_id having sum(debit_minor-credit_minor)<>0')).rows.length,0);
 writeFileSync('/tmp/narvo-source-assignment-races.json',JSON.stringify({status:'PASS',scenarios,hosted:false},null,2));console.log('PASS: 10 native independent-backend assignment/posting races; real lock waits observed; one balanced expected expense journal');
}finally{for(const c of clients){try{await c.query('rollback');await c.end()}catch{}}if(started)await server.stop();await rm(root,{recursive:true,force:true});}
