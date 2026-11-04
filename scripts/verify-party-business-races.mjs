import assert from'node:assert/strict';import{writeFileSync,mkdtempSync}from'node:fs';import{rm}from'node:fs/promises';import{tmpdir}from'node:os';import{join}from'node:path';import{pathToFileURL}from'node:url';import{randomUUID}from'node:crypto';import{createServer}from'node:net';import{setTimeout as delay}from'node:timers/promises';import{partyBusinessFixture}from'./party-business-fixture.mjs';
const{default:EmbeddedPostgres}=await import(pathToFileURL('/tmp/narvo-project-native/node_modules/embedded-postgres/dist/index.js').href),root=mkdtempSync(join(tmpdir(),'narvo-party-business-races-')),socket=createServer();await new Promise(ok=>socket.listen(0,'127.0.0.1',ok));const port=socket.address().port;await new Promise(ok=>socket.close(ok));const server=new EmbeddedPostgres({databaseDir:join(root,'data'),user:'postgres',password:randomUUID(),port,persistent:false,createPostgresUser:false,initdbFlags:['--locale=C','--encoding=UTF8'],postgresFlags:['-h','127.0.0.1','-k',root],onLog:()=>{},onError:()=>{}}),clients=[],scenarios=[];let started=false;
const connect=async()=>{const c=server.getPgClient('postgres','127.0.0.1');await c.connect();await c.query("set statement_timeout='15s'");clients.push(c);return c;};

try{await server.initialise();await server.start();started=true;const observer=await connect(),adapter={query:(...args)=>observer.query(...args),exec:sql=>observer.query(sql),close:async()=>{},async transaction(fn){await observer.query('begin');try{const value=await fn(adapter);await observer.query('commit');return value;}catch(e){await observer.query('rollback');throw e;}}},f=await partyBusinessFixture(adapter);
const a=await connect(),b=await connect(),pid=(await b.query('select pg_backend_pid() pid')).rows[0].pid;
const begin=async c=>{await c.query('begin');await c.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:f.admin})]);await c.query('set local role authenticated');};
const command=(c,p,key,status=null,notes='Reviewed metadata')=>c.query('select public.update_party_business_master($1,$2,$3,$4,$5,$6,$7,false) r',[f.company,p.id,p.updated_at,key,status?{}:{notes},status,'Verified lifecycle reason']);
const bill=c=>c.query("select * from public.post_expense($1,current_date,$2,$3,'Synthetic bill',10000,'ZERO',null,'SUPPLIER_CREDIT',null,null,$4,'TRANSFER',false,null,null,$5)",[f.company,f.project,f.category,f.supplier,randomUUID()]);
async function wait(){for(let i=0;i<150;i++){if((await observer.query('select wait_event_type from pg_stat_activity where pid=$1',[pid])).rows[0]?.wait_event_type==='Lock')return;await delay(20);}throw Error('Actual lock wait required');}
for(const mode of ['same-key','different-key','changed-intent','rollback','edit-before-status','status-before-bill','bill-before-status','authority-revoked']){
 await observer.query("update public.parties set status='ACTIVE',notes=null where id=$1",[f.supplier]);const p=await f.row(),key=randomUUID();let first;
 await begin(a);
 if(mode==='status-before-bill')first=await command(a,p,key,'INACTIVE');
 else if(mode==='bill-before-status')first=await bill(a);
 else if(mode==='authority-revoked'){await a.query('reset role');await a.query("update public.company_memberships set status='INACTIVE' where company_id=$1 and user_id=$2",[f.company,f.admin]);}
 else first=await command(a,p,key);
 await begin(b);const pending=mode==='status-before-bill'?bill(b):command(b,p,['different-key','rollback','edit-before-status','bill-before-status'].includes(mode)?randomUUID():key,['edit-before-status','bill-before-status'].includes(mode)?'INACTIVE':null,mode==='changed-intent'?'Different intent':'Reviewed metadata');pending.catch(()=>{});await wait();await a.query(mode==='rollback'?'rollback':'commit');
 const failure=mode==='changed-intent'?'22023':mode==='authority-revoked'?'42501':['different-key','edit-before-status'].includes(mode)?'40001':mode==='status-before-bill'?'23514':null;
 console.log('VERIFY',mode,failure);if(failure){await assert.rejects(pending,e=>e.code===failure);await b.query('rollback');}else{const result=await pending;if(mode==='same-key')assert.deepEqual(result.rows[0].r,first.rows[0].r);await b.query('commit');}
 if(mode==='status-before-bill'||mode==='bill-before-status')assert.equal((await f.row()).status,'INACTIVE');
 scenarios.push({scenario:mode,status:'PASS',realLockWait:true});
}
assert.equal((await observer.query('select journal_entry_id from public.journal_lines group by journal_entry_id having sum(debit_minor-credit_minor)<>0')).rows.length,0);writeFileSync('/tmp/narvo-party-master-races.json',JSON.stringify({status:'PASS',scenarios,hosted:false},null,2));console.log('PASS eight native Party lifecycle/concurrency schedules');
}finally{for(const c of clients){try{await c.query('rollback');await c.end();}catch{}}if(started)await server.stop();await rm(root,{recursive:true,force:true});}
