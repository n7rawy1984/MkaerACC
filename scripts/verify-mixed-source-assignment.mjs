// Focused expansion: real canonical assignment -> review -> expense posting; local only.
import assert from'node:assert/strict';import{readFileSync,writeFileSync}from'node:fs';import{randomUUID}from'node:crypto';import{assignmentFixture}from'./source-project-assignment-fixture.mjs';
const f=await assignmentFixture(),{db,as,company,admin,id}=f,checks=[],check=(ok,s)=>{assert(ok,s);checks.push(s);};
try{
for(const file of ['20261103130000_source_project_assignment.sql','20261103140000_expense_correction_reviews.sql','20261103150000_project_cost_correction_execution.sql'])await db.exec(readFileSync('supabase/migrations/'+file,'utf8'));
const p2=id(23);await db.query("insert into public.projects(id,company_id,code,name,status) values($1,$2,'P-TWO','Second Project','ACTIVE')",[p2,company]);
const rows=await f.sources(),item=(n,p)=>({source_id:id(n),expected_updated_at:rows.find(r=>r.id===id(n)).updated_at,scope:p?'PROJECT':'COMPANY',project_id:p}),items=[item(40,f.project),item(41,p2),item(42,null)],key=randomUUID();
const assign=(input,request=key)=>as(admin,'select public.assign_source_projects($1,$2,$3,$4) r',[company,request,input,'Verified distinct source destinations']).then(r=>r[0].r);
await assert.rejects(()=>assign([items[0],{...items[1],expected_updated_at:'2000-01-01T00:00:00Z'},items[2]],randomUUID()),e=>e.code==='40001');check((await f.sources()).slice(0,3).every(r=>!r.allocation_scope),'One stale member rolls back the entire mixed-destination batch');
const receipt=await assign(items);assert.deepEqual(await assign([...items].reverse()),receipt);check(true,'Reordered same-key mixed batch returns the same receipt');
await assert.rejects(()=>assign([items[0],{...items[1],project_id:f.project},items[2]]),e=>e.code==='22023');check(true,'Changing one destination cannot reuse the request');
const assigned=(await f.sources()).slice(0,3);check(assigned.map(r=>r.assigned_project_id).join('|')===[f.project,p2,null].join('|')&&assigned.every(r=>r.review_status==='PENDING'),'Each source retains its distinct Project/overhead and needs fresh review');
const event=(await as(admin,'select * from public.source_project_assignment_events where id=$1',[receipt.id]))[0];check(event.changes.length===3&&event.changes.every(c=>c.previous_scope===null)&&event.changes[2].scope==='COMPANY','One immutable event contains exact per-source before/after evidence');
check((await db.query('select count(*)::int n from public.journal_entries')).rows[0].n===0,'Assignment produces no financial recognition');
const post=(n,p)=>as(admin,'select * from public.post_historical_expense($1,$2,$3)',[company,id(n),{target_expense_date:'2026-09-20',target_description:'SYN-'+n,target_project_id:p,target_treasury_account_id:f.treasury,target_funding_mode:'TREASURY',target_payment_method:'CASH',target_net_amount_minor:'12550',target_vat_mode:'ZERO',target_has_tax_invoice:false,target_expense_category_id:f.category}]);
await assert.rejects(()=>post(40,f.project),e=>e.code==='23514');check(true,'Mixed assignment cannot skip source review');
for(const [n,p] of [[40,f.project],[41,p2],[42,null]]){const source=(await f.sources()).find(r=>r.id===id(n));await as(admin,'select public.complete_historical_source($1,$2,$3,$4,$5)',[company,source.id,source.updated_at,source.completion,'REVIEWED']);await assert.rejects(()=>post(n,p===f.project?null:f.project),e=>e.code==='23514');const result=(await post(n,p))[0];assert.equal((await post(n,p))[0].expense_id,result.expense_id);}
check((await db.query('select count(*)::int n from public.expenses')).rows[0].n===3,'Three reviewed sources recognize exactly three Expenses despite replay');
const costs=(await db.query("select project_id,sum(debit_minor-credit_minor)::text amount from public.journal_lines l join public.accounts a on a.company_id=l.company_id and a.id=l.account_id where a.account_type='EXPENSE' group by project_id order by project_id nulls last")).rows;
check(costs.length===3&&costs.every(r=>r.amount==='12550')&&costs.some(r=>r.project_id===null),'Project A/Project B/overhead reconcile exactly to one source cost each');
check(costs.reduce((n,r)=>n+BigInt(r.amount),0n)===37650n,'Company-wide cost equals originating source total, without duplicate payment cost');
check((await db.query('select journal_entry_id from public.journal_lines group by journal_entry_id having sum(debit_minor-credit_minor)<>0')).rows.length===0,'Every originating journal balances');
await assert.rejects(()=>assign(items,randomUUID()),e=>e.code==='40001');check((await db.query('select count(*)::int n from public.expenses')).rows[0].n===3,'Posted sources cannot be reassigned; financial history preserved');
check((await as(f.foreign,'select * from public.source_project_assignment_events')).length===0,'Mixed-destination evidence retains Company RLS');
writeFileSync('/tmp/narvo-mixed-assignment-db.json',JSON.stringify({status:'PASS',checks:checks.length,details:checks,hosted:false},null,2));console.log('PASS',checks.length,'mixed-source accounting checks');
}finally{await db.close();}
