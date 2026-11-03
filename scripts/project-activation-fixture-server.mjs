// Loopback synthetic PostgreSQL + real workspace UI. No hosted transport or credentials.
import{createServer}from'vite';import react from'@vitejs/plugin-react';import{resolve}from'node:path';import{readFileSync}from'node:fs';import{platformTestDatabase}from'./verify-platform-database.mjs';
export async function startProjectActivationFixture(){
 const{db}=await platformTestDatabase(undefined,{through:'20261101130000'}),root=resolve('.');const id=n=>`98000000-0000-4000-8000-${String(n).padStart(12,'0')}`,actor=id(1),company=id(2);
 await db.query("insert into auth.users(id,email) values($1,'project-admin@example.invalid')",[actor]);await db.query("insert into public.companies(id,code,name) values($1,'SYNTHETIC-ACTIVATION','Synthetic activation company')",[company]);await db.query("insert into public.company_memberships(company_id,user_id,role) values($1,$2,'ACCOUNTING_ADMIN')",[company,actor]);
 for(const[n,name]of[[4,'Activation EN'],[30,'Activation AR'],[31,'Stale activation'],[32,'Uncertain activation'],[33,'Session protection']])await db.query("insert into public.projects(id,company_id,code,name,status,location) values($1,$2,$3,$4,'PLANNING','Synthetic location')",[id(n),company,'P-'+n,name]);
 await db.exec(readFileSync('supabase/migrations/20261102120000_commercial_company_onboarding.sql','utf8'));await db.exec(readFileSync('supabase/migrations/20261103120000_project_activation.sql','utf8'));
 const requests=[];const server=await createServer({root,cacheDir:'/tmp/narvo-project-activation-vite-'+process.pid,configFile:false,plugins:[{name:'project-activation-fixture',load(path){
  if(path===resolve('src/lib/supabase.ts'))return 'export const getSupabaseClient=()=>window.dashboardTest.client;';
  if(path===resolve('scripts/fixtures/company-workspace.tsx'))return readFileSync(path,'utf8').replace('then:(done:any)=>{',`then:(done:any)=>{if(table==='projects'||table==='project_activation_events'){fetch('/__project_read',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({table,filters,single})}).then(r=>r.json()).then(done);return;}`).replace('f.rpcReads.push(name);',`f.rpcReads.push(name);if(name==='activate_project')return fetch('/__project_activate',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify(args)}).then(r=>r.json());`);
 },configureServer(s){s.middlewares.use(async(req,res,next)=>{
  if(req.url==='/__project_read'||req.url==='/__project_activate'){
   let raw='';for await(const c of req)raw+=c;const input=JSON.parse(raw);res.setHeader('Content-Type','application/json');
   try{const data=await db.transaction(async t=>{await t.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:actor})]);await t.exec('set local role authenticated');
    if(req.url==='/__project_activate'){requests.push(input);return(await t.query('select public.activate_project($1,$2,$3,$4,$5) r',[input.target_company_id,input.target_project_id,input.expected_updated_at,input.request_id,input.reason])).rows[0].r;}
    if(!['projects','project_activation_events'].includes(input.table))throw Error('Table rejected');
    const values=[],clauses=[];for(const[key,v]of input.filters){if(!['company_id','id','project_id'].includes(key))throw Error('Filter rejected');values.push(v);clauses.push(key+'=$'+values.length);}
    if(input.table==='projects')return(await t.query('select *,updated_at::text updated_at,created_at::text created_at from public.projects where '+clauses.join(' and '),values)).rows;
    const events=(await t.query('select * from public.project_activation_events where '+clauses.join(' and '),values)).rows;return input.single?events[0]??null:events;
   });res.end(JSON.stringify({data,error:null}));}catch(e){res.end(JSON.stringify({data:null,error:{code:e.code??'FIXTURE_ERROR',message:e.message}}));}return;
  }
  const path=new URL(req.url,'http://localhost').pathname;if(!path.includes('.')&&!path.startsWith('/@')&&!path.startsWith('/node_modules')){res.setHeader('Content-Type','text/html');res.end(await s.transformIndexHtml(req.url,'<!doctype html><html lang="en"><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Local project activation</title></head><body><div id="root"></div><script type="module" src="/scripts/fixtures/company-workspace.tsx"></script></body></html>'));return;}next();
 });}},react()],server:{host:'127.0.0.1',port:0,hmr:false},logLevel:'error'});
 await server.listen();return{db,server,requests,base:`http://127.0.0.1:${server.httpServer.address().port}`,id};
}
