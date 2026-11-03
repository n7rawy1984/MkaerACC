import{readFileSync}from'node:fs';import{randomUUID}from'node:crypto';import{projectCostFixture}from'./project-cost-fixture.mjs';
export async function correctionExecutionFixture(database){const f=await projectCostFixture(database),{db}=f;
for(const name of['20261102120000_commercial_company_onboarding.sql','20261103120000_project_activation.sql','20261103130000_source_project_assignment.sql','20261103140000_expense_correction_reviews.sql'])await db.exec(readFileSync('supabase/migrations/'+name,'utf8'));
await db.query("insert into private.company_legacy_eligibility(company_id,reason) values($1,'Disposable local correction fixture')",[f.company]);await db.query("update public.projects set status='ACTIVE' where company_id=$1",[f.company]);
const today=(await db.query("select (statement_timestamp() at time zone 'UTC')::date::text d")).rows[0].d;
async function expense(project=f.project,date=today){const r=(await f.as(f.admin,"select * from public.post_expense($1,$2,$3,$4,'Synthetic current cost',10000,'ZERO',null,'TREASURY',$5,null,null,'CASH',false,null,null,$6)",[f.company,date,project,f.id(36),f.id(35),randomUUID()]))[0];return(await db.query('select *,expense_date::text expense_date,updated_at::text updated_at from public.expenses where id=$1',[r.expense_id])).rows[0];}
async function review(e,target=f.project2,date=today){return(await f.as(f.admin,"select public.record_expense_correction_review($1,$2,$3,null,$4,'PROJECT',$5,$6,'Verified allocation correction') r",[f.company,e.id,e.updated_at,randomUUID(),target,date]))[0].r;}
return{...f,today,expense,review};}
