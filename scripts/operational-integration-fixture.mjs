import {sourceReclassificationFixture} from './verify-source-reclassification.mjs';
import {readFileSync,existsSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
export async function operationalIntegrationFixture({activate=true}={}){
 const f=await sourceReclassificationFixture();
 const file='supabase/migrations/20261106140000_operational_financial_integration.sql';
 if(activate&&existsSync(file))await f.db.exec(readFileSync(file,'utf8'));
 const allowed=new Set((await f.db.query("select table_name from information_schema.tables where table_schema='public'")).rows.map(r=>r.table_name));
 const quote=k=>{if(!/^[a-z_][a-z_0-9]*$/.test(k))throw Error('Identifier');return '"'+k+'"'};
 async function read(actor,table,columns,filters=[],limit=500){
  if(!allowed.has(table)||!filters.some(([op,k,v])=>op==='eq'&&k==='company_id'&&v===f.company))throw Error('Unscoped fixture read');
  const args=[],where=filters.map(([op,k,v])=>{if(op==='in')return quote(k)+' in ('+v.map(x=>{args.push(x);return '$'+args.length}).join(',')+')';const operator={eq:'=',gt:'>',gte:'>=',lte:'<='}[op];if(!operator)throw Error('Operator');args.push(v);return quote(k)+operator+'$'+args.length});
  const cols=columns==='*'?'*':columns.split(',').map(c=>{const name=c.replace(/::text$/,'');return quote(name)+(c.endsWith('::text')||name.endsWith('_date')?'::text as '+quote(name):'')}).join(',');
  return f.as(actor,'select '+cols+' from public.'+quote(table)+' where '+where.join(' and ')+(table==='party_person_roles'?' order by party_id,role':' order by id')+' limit '+Math.min(limit,500),args);
 }
 async function rpc(actor,name,args){
  if(name==='read_operational_correction_movements')return(await f.as(actor,'select public.read_operational_correction_movements($1,$2)r',[args.cid,args.journal_ids]))[0].r;
  return f.rpc(actor,name,args);
 }
 function client(actor=f.admin){return{auth:{getSession:async()=>({data:{session:{user:{id:actor}}},error:null})},async rpc(n,a){try{return{data:await rpc(actor,n,a),error:null}}catch(e){return{data:null,error:{code:e.code??'FIXTURE',message:e.message}}}},from(t){const filters=[];let columns='',limit=500;const q={select(c){columns=c;return q},eq(k,v){filters.push(['eq',k,v]);return q},in(k,v){filters.push(['in',k,v]);return q},gte(k,v){filters.push(['gte',k,v]);return q},lte(k,v){filters.push(['lte',k,v]);return q},gt(k,v){filters.push(['gt',k,v]);return q},order(){return q},limit(n){limit=n;return q},then(done){return read(actor,t,columns,filters,limit).then(data=>({data,error:null}),e=>({data:null,error:{code:e.code??'FIXTURE',message:e.message}})).then(done)}};return q}}}
 async function evidence(patch={}){const e=await f.rpc(f.admin,'submit_financial_operation_evidence',{target_company_id:f.company,target_request_key:randomUUID(),business_input:{kind:'PERSONAL_EXPENSE',event_date:f.today,counterparty_id:f.custodian,amount_minor:'1000',source_reference:'INT-'+randomUUID(),classification:'PERSONAL_FUNDS',destination:'PERSONAL_FUNDS',recipient_id:null,treasury_id:null,project_id:f.p2,description:'Isolated operational integration',supporting_reference:'Synthetic verified original evidence',...patch}});await f.rpc(f.admin,'review_financial_operation_evidence',{target_company_id:f.company,target_request_key:randomUUID(),target_evidence_id:e.id,target_decision:'REVIEWED',target_reason:'Original synthetic event and dimensions checked'});return e.id;}
 const post=(e,input,key=randomUUID(),actor=f.admin)=>f.rpc(actor,'post_reviewed_financial_operation',{target_company_id:f.company,target_request_key:key,target_evidence_id:e,business_input:input});
 return{...f,read,rpc,client,evidence,post};
}
