import {createServer} from 'vite';import react from '@vitejs/plugin-react';import{resolve}from'node:path';import{readFileSync}from'node:fs';
import{assignmentFixture}from'./source-project-assignment-fixture.mjs';
export async function startAssignmentBrowser(){
 const f=await assignmentFixture(),{db}=f,root=resolve('.');await db.exec(readFileSync('supabase/migrations/20261103130000_source_project_assignment.sql','utf8'));
 const server=await createServer({root,configFile:false,cacheDir:'/tmp/narvo-source-assignment-vite-'+process.pid,logLevel:'error',plugins:[{name:'assignment-fixture',load(path){
 if(path===resolve('src/lib/supabase.ts'))return 'export const getSupabaseClient=()=>window.fixtureClient;';
 if(path===resolve('src/auth/AuthContext.tsx'))return 'export const useAuth=()=>({state:{phase:"TENANT_READY",profile:{userId:window.assignmentFixture.actor},activeTenant:{companyId:window.assignmentFixture.company,companyName:"Synthetic assignment Company",role:window.assignmentFixture.role}}});';
 if(path===resolve('src/i18n/I18nContext.tsx'))return 'export const useI18n=()=>({locale:window.assignmentFixture.locale});export const useT=()=>k=>k;';
 if(path===resolve('src/master/productionMasterDataContext.ts'))return 'export const useProductionMasterData=()=>({phase:"READY",projects:window.assignmentFixture.projects,company:{id:window.assignmentFixture.company},treasuryAccounts:[{id:"e4000000-0000-4000-8000-000000000033",companyId:window.assignmentFixture.company,status:"ACTIVE",projectId:null,code:"CASH",name:"Synthetic cash"}],expenseCategories:[{id:"e4000000-0000-4000-8000-000000000034",companyId:window.assignmentFixture.company,status:"ACTIVE",code:"COST",name:"Synthetic cost"}],parties:[]});';
 },configureServer(s){s.middlewares.use(async(req,res,next)=>{try{
 if(req.url==='/__sources'){res.setHeader('Content-Type','application/json');const rows=(await f.as(f.admin,'select *,source_date::text source_date,updated_at::text updated_at,outflow_minor::text outflow_minor,funding_minor::text funding_minor,payroll_net_minor::text payroll_net_minor from public.historical_source_records where company_id=$1 order by source_reference',[f.company]));const projects=(await f.as(f.admin,'select id,company_id as "companyId",code,name,status from public.projects where company_id=$1',[f.company]));res.end(JSON.stringify({rows,projects}));return;}
 if(req.url==='/__read'||req.url==='/__assign'){let raw='';for await(const chunk of req)raw+=chunk;const input=JSON.parse(raw);let data;
 if(req.url==='/__read'){
 if(input.missing){res.end(JSON.stringify({data:null,error:{code:'PGRST205'}}));return;}
 if(input.table!=='source_project_assignment_events'||!input.filters.some(([k,v])=>k==='company_id'&&v===f.company))throw Error('Unscoped read');
 data=await f.as(input.actor,'select * from public.source_project_assignment_events where company_id=$1 order by created_at desc,id limit 50',[f.company]);
 }else{if(input.name!=='assign_source_projects')throw Error('Mutation forbidden');const a=input.args;data=(await f.as(input.actor,'select public.assign_source_projects($1,$2,$3,$4) r',[a.target_company_id,a.request_id,a.items,a.reason]))[0].r;}
 res.setHeader('Content-Type','application/json');res.end(JSON.stringify({data,error:null}));return;}
 const path=new URL(req.url,'http://localhost').pathname;if(!path.includes('.')&&!path.startsWith('/@')&&!path.startsWith('/node_modules')){res.setHeader('Content-Type','text/html');res.end(await s.transformIndexHtml(req.url,'<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body><div id="root"></div><script type="module" src="/scripts/fixtures/source-project-assignment.tsx"></script></body></html>'));return;}next();
 }catch(e){res.setHeader('Content-Type','application/json');res.end(JSON.stringify({data:null,error:{code:e.code??'FIXTURE',message:e.message}}));}});}},react()],server:{host:'127.0.0.1',port:0,hmr:false}});
 await server.listen();return{...f,server,base:`http://127.0.0.1:${server.httpServer.address().port}`};
}
