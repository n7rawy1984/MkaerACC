// Disposable synthetic Company only. No hosted connections accepted.
import{readFileSync}from'node:fs';import{randomUUID}from'node:crypto';import{prepostingFixture}from'./preposting-allocation-fixture.mjs';
export async function postedSplitFixture(database,{apply=true}={}){
 const f=await prepostingFixture(database);await f.db.exec(readFileSync('supabase/migrations/20261104120000_preposting_shared_cost.sql','utf8'));
 if(apply)await f.db.exec(readFileSync('supabase/migrations/20261104130000_posted_split_cost_corrections.sql','utf8'));
 await f.as(f.admin,"select public.set_project_correction_period($1,$2,'OPEN','Verified Company books open')",[f.company,randomUUID()]);
 async function expense(n=40,plan=f.plan){await f.confirm(n,randomUUID(),plan);await f.review(n);const posted=(await f.post(n))[0];return(await f.db.query('select *,updated_at::text updated_at,expense_date::text expense_date from public.expenses where id=$1',[posted.expense_id])).rows[0];}
 async function proposal(e,anchor=f.project,previous=null,date=f.today){return(await f.as(f.admin,"select public.record_expense_correction_review($1,$2,$3,$4,$5,'PROJECT',$6,$7,'Verified split cost correction') r",[f.company,e.id,e.updated_at,previous,randomUUID(),anchor,date]))[0].r;}
 const corrected={...f.plan,destinations:[{project_id:f.project,weight:'2000'},{project_id:f.project2,weight:'8000'}]};
 const execute=(r,key=randomUUID(),plan=corrected,actor=f.admin,evidence='Verified unreconciled cash voucher')=>f.as(actor,'select public.execute_posted_split_cost_correction($1,$2,$3,$4,true,true,$5) r',[f.company,r.id,key,plan,evidence]);
 const eligible=r=>f.as(f.admin,'select public.get_project_correction_eligibility($1,$2) r',[f.company,r.id]);
 const reverse=(c,key=randomUUID())=>f.as(f.admin,"select public.reverse_project_cost_correction($1,$2,$3,'Reverse incorrect cost transfer') r",[f.company,c.id,key]);
 
 const allowed=new Set(['projects','accounts','journal_entries','journal_lines','expenses','subcontractor_certificates','expense_correction_reviews','project_cost_corrections','project_cost_correction_reversals']);
 async function read(actor,table,columns,filters=[],limit=500){
  if(!allowed.has(table)||!filters.some(([op,k,v])=>op==='eq'&&k==='company_id'&&v===f.company))throw Error('Unscoped fixture read');
  const quote=k=>{if(!/^\w+$/.test(k))throw Error('Identifier');return '"'+k+'"';},values=[];
  const projection=columns.split(',').map(c=>{if(c==='*')return '*';const m=c.match(/^(\w+)(::text)?$/);if(!m)throw Error('Projection');return quote(m[1])+(m[2]||['posting_date','correction_date','reversal_date','month'].includes(m[1])?'::text as '+quote(m[1]):'');}).join(',');
  const conditions=filters.map(([op,k,v])=>{if(op==='in')return quote(k)+' in ('+v.map(item=>{values.push(item);return '$'+values.length;}).join(',')+')';const operator={eq:'=',gt:'>',gte:'>=',lte:'<='}[op];if(!operator)throw Error('Operator');values.push(v);return quote(k)+operator+'$'+values.length;});
  return f.as(actor,'select '+projection+' from public.'+quote(table)+' where '+conditions.join(' and ')+' order by id limit '+Math.min(limit,500),values);
 }
 return{...f,expense,proposal,corrected,execute,eligible,reverse,read};
}
