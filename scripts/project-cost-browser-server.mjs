import{createServer}from'vite';import react from'@vitejs/plugin-react';import{resolve}from'node:path';import{projectCostFixture}from'./project-cost-fixture.mjs';
export async function startProjectCostBrowser(){
 const f=await projectCostFixture(),root=resolve('.');const server=await createServer({root,configFile:false,cacheDir:'/tmp/narvo-project-cost-vite-'+process.pid,logLevel:'error',plugins:[{name:'project-cost-fixture',load(path){
 if(path===resolve('src/lib/supabase.ts'))return 'export const getSupabaseClient=()=>window.fixtureClient;';
 if(path===resolve('src/auth/AuthContext.tsx'))return 'export const useAuth=()=>({state:{phase:"TENANT_READY",profile:{userId:window.costFixture.actor},activeTenant:{companyId:window.costFixture.company,companyName:"Synthetic cost Company",role:window.costFixture.role}}});';
 if(path===resolve('src/i18n/I18nContext.tsx'))return 'export const useI18n=()=>({locale:window.costFixture.locale});export const useT=()=>k=>k;';
 if(path===resolve('src/master/productionMasterDataContext.ts'))return 'export const useProductionMasterData=()=>({phase:"READY",company:{id:window.costFixture.company},projects:window.costFixture.projects});';
 },configureServer(s){s.middlewares.use(async(req,res,next)=>{try{
 if(req.url==='/__cost_boot'){res.setHeader('Content-Type','application/json');res.end(JSON.stringify(await f.as(f.admin,'select id,company_id as "companyId",code,name,status from public.projects where company_id=$1',[f.company])));return;}
 if(req.url==='/__cost_read'){let raw='';for await(const c of req)raw+=c;const input=JSON.parse(raw),data=await f.read(input.actor,input.table,input.columns,input.filters,input.limit);res.setHeader('Content-Type','application/json');res.end(JSON.stringify({data,error:null}));return;}
 const path=new URL(req.url,'http://localhost').pathname;if(!path.includes('.')&&!path.startsWith('/@')&&!path.startsWith('/node_modules')){res.setHeader('Content-Type','text/html');res.end(await s.transformIndexHtml(req.url,'<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body><div id="root"></div><script type="module" src="/scripts/fixtures/project-cost-ledger.tsx"></script></body></html>'));return;}next();
 }catch(e){res.setHeader('Content-Type','application/json');res.end(JSON.stringify({data:null,error:{code:e.code??'FIXTURE'}}));}});}},react()],server:{host:'127.0.0.1',port:0,hmr:false}});await server.listen();return{...f,server,base:`http://127.0.0.1:${server.httpServer.address().port}`};
}
