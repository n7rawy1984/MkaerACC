// Test/preview host only. Synthetic Auth, in-memory PostgreSQL, loopback binding.
import assert from 'node:assert/strict';
import {resolve} from 'node:path';
import {createServer} from 'vite';
import react from '@vitejs/plugin-react';
import {platformTestDatabase} from './verify-platform-database.mjs';
export async function startPlatformFixtureServer(port=0) {
const {db}=await platformTestDatabase();
const id=n=>`b0000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
for(const [n,email] of [[1,'owner@example.invalid'],[2,'admin@example.invalid'],[3,'recipient@example.invalid']]){
 await db.query('insert into auth.users(id,email,email_confirmed_at) values($1,$2,now())',[id(n),email]);
 await db.query('insert into auth.sessions(id,user_id) values($1,$2)',[id(n+100),id(n)]);
}
await db.exec("update auth.users set encrypted_password='synthetic-existing-password'");
await db.query('insert into private.system_administrators(user_id) values($1)',[id(1)]);
await db.query("insert into auth.mfa_factors(user_id,factor_type,status) values($1,'totp','verified')",[id(1)]);
await db.query('update auth.sessions set factor_id=(select id from auth.mfa_factors where user_id=$1 limit 1) where user_id=$1',[id(1)]);
const root=resolve('.');
const rpcNames=new Set(['get_platform_onboarding','set_company_subscription','list_company_subscriptions','get_my_company_subscription','provision_company_accounting','get_company_accounting_setup','get_platform_context','get_platform_overview','list_platform_entities','platform_directory','list_platform_invitations','platform_admin_command','platform_invitation_command','accept_platform_invitation','get_my_platform_invitation']);
 const server=await createServer({root,configFile:false,plugins:[{name:'isolated-platform',load(path){if(path===resolve(root,'src/lib/supabase.ts'))return 'export const getSupabaseClient=()=>window.platformFixture.client;';},configureServer(s){s.middlewares.use(async(req,res,next)=>{
  if(req.url==='/__platform_password') {
   let raw='';for await(const chunk of req)raw+=chunk;const {actor}=JSON.parse(raw);
   assert(actor===id(3));await db.query("update auth.users set encrypted_password='synthetic-password-established' where id=$1",[actor]);res.end('{}');return;
  }
  if(req.url==='/__platform_identity') {
   let raw='';for await(const chunk of req)raw+=chunk;const {table,actor,filters,one}=JSON.parse(raw);
   const allowed=new Set(['profiles','company_memberships','companies','company_settings']);
   let data=one?null:[];
   if(allowed.has(table)) data=await db.transaction(async tx=>{
    await tx.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:actor,session_id:id(100+Number(actor.slice(-4)))})]);await tx.exec('set local role authenticated');
    const values=[];const conditions=Object.entries(filters).map(([key,value])=>{assert(/^[a-z_]+$/.test(key));values.push(value);return key+(Array.isArray(value)?'=any($'+values.length+')':'=$'+values.length);});
    const rows=(await tx.query('select * from public.'+table+(conditions.length?' where '+conditions.join(' and '):''),values)).rows;return one?(rows[0]??null):rows;
   });
   res.setHeader('Content-Type','application/json');res.end(JSON.stringify({data,error:null}));return;
  }
  if(req.url==='/__platform_rpc'){
   let raw='';for await(const chunk of req)raw+=chunk;
   const {name,args,actor,aal,totpAgeSeconds=0,uncertain}=JSON.parse(raw);assert(Number.isInteger(totpAgeSeconds)&&totpAgeSeconds>=0&&totpAgeSeconds<=1000000);assert(rpcNames.has(name));
   const keys=Object.keys(args);assert(keys.every(k=>/^[a-z_]+$/.test(k)));
   let result;try{result=await db.transaction(async tx=>{
    await tx.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:actor,session_id:id(100+Number(actor.slice(-4))),aal,amr:[{method:'totp',timestamp:Math.floor(Date.now()/1000)-totpAgeSeconds}]})]);
    await tx.exec('set local role authenticated');
    return (await tx.query(`select public.${name}(${keys.map((k,i)=>`${k} => $${i+1}`).join(',')}) result`,keys.map(k=>typeof args[k]==='object'?JSON.stringify(args[k]):args[k]))).rows[0].result;
   });res.setHeader('Content-Type','application/json');res.end(JSON.stringify(uncertain?{data:null,error:{code:'NETWORK_UNCERTAIN'}}:{data:result,error:null}));}
   catch(e){res.setHeader('Content-Type','application/json');res.end(JSON.stringify({data:null,error:{code:e.code,message:e.message}}));}return;
  }
  if(req.url.startsWith('/platform')||req.url.startsWith('/auth/')||req.url==='/'){
   res.setHeader('Content-Type','text/html');res.end(await s.transformIndexHtml(req.url,'<!doctype html><html lang="en"><head><title>NARVO ERP — Local verification</title><meta name="viewport" content="width=device-width, initial-scale=1"/></head><body><div id="root"></div><script type="module" src="/scripts/fixtures/platform-console.tsx"></script></body></html>'));return;
  }next();
 });}},react()],server:{host:'127.0.0.1',port,hmr:false},logLevel:'error'});

 try { await server.listen(); } catch(error) { await db.close(); throw error; }
 return {db,server,base:`http://127.0.0.1:${server.httpServer.address().port}`};
}
