// Isolated canonical SQL only; no hosted connection accepted.
import{partyStatementFixture}from'./party-statement-fixture.mjs';import{readFileSync}from'node:fs';import{randomUUID}from'node:crypto';
export async function projectLifecycleFixture({apply=true}={}){const f=await partyStatementFixture(),{db,id,as,admin,company}=f;
await db.query("insert into private.company_legacy_eligibility(company_id,reason) values($1,'Disposable foreign fixture')",[f.other]);
const project=id(200),planning=id(201),closed=id(202),foreignProject=id(203);
for(const[pid,cid,status]of[[project,company,'ACTIVE'],[planning,company,'PLANNING'],[closed,company,'CLOSED'],[foreignProject,f.other,'ACTIVE']])await db.query('insert into public.projects(id,company_id,code,name,status) values($1,$2,$3,$3,$4)',[pid,cid,'LIFE-'+pid.slice(-3),status]);
// Existing financial Project remains ACTIVE for lifecycle checks; fixture previously closed it.
await db.query("update public.projects set status='ACTIVE' where id=$1",[f.project]);
const row=async pid=>(await db.query('select *,updated_at::text updated_at from public.projects where id=$1',[pid])).rows[0];
const preview=async(pid,target,actor=admin,stamp)=>(await as(actor,'select public.preview_project_lifecycle($1,$2,$3,$4) r',[company,pid,stamp??(await row(pid)).updated_at,target]))[0].r;
const transition=async(pid,target,options={})=>{const p=options.preview??await preview(pid,target,options.actor),key=options.key??randomUUID();return(await as(options.actor??admin,'select public.transition_project($1,$2,$3,$4,$5,$6,$7,$8,$9) r',[company,pid,options.stamp??p.updated_at,target,options.date??p.effective_date,options.reason??'Approved operational change',key,options.hash??p.review_hash,options.ack??true]))[0].r;};
if(apply)await db.exec(readFileSync('supabase/migrations/20261104150000_project_lifecycle.sql','utf8'));
return{...f,project,financialProject:f.project,planning,closed,foreignProject,row,preview,transition};}
