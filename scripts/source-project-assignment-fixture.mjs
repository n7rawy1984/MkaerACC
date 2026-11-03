// Disposable synthetic PostgreSQL only. No hosted configuration accepted.
import {readFileSync} from 'node:fs';
import {platformTestDatabase} from './verify-platform-database.mjs';
export const assignmentId=n=>`e4000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
export async function assignmentFixture(database){
 const {db}=await platformTestDatabase(database,{through:'20261101130000'}),id=assignmentId;
 const admin=id(1),accountant=id(2),viewer=id(3),foreign=id(4),company=id(10),other=id(11),project=id(20),closed=id(21),foreignProject=id(22),cash=id(30),cost=id(31),overhead=id(32),treasury=id(33),category=id(34);
 for(const uid of[admin,accountant,viewer,foreign])await db.query('insert into auth.users(id,email) values($1,$2)',[uid,uid+'@example.invalid']);
 for(const cid of[company,other])await db.query("insert into public.companies(id,code,name) values($1,$2,'Synthetic assignment Company')",[cid,cid]);
 for(const [uid,cid,role]of[[admin,company,'ACCOUNTING_ADMIN'],[accountant,company,'ACCOUNTANT'],[viewer,company,'MANAGEMENT_VIEWER'],[foreign,other,'ACCOUNTING_ADMIN']])await db.query('insert into public.company_memberships(company_id,user_id,role) values($1,$2,$3)',[cid,uid,role]);
 for(const[pid,cid,status]of[[project,company,'ACTIVE'],[closed,company,'CLOSED'],[foreignProject,other,'ACTIVE']])await db.query('insert into public.projects(id,company_id,code,name,status) values($1,$2,$1::uuid::text,$1::uuid::text,$3)',[pid,cid,status]);
 for(const[aid,kind,key]of[[cash,'ASSET',null],[cost,'EXPENSE','PROJECT_COST'],[overhead,'EXPENSE','COMPANY_EXPENSE']])await db.query('insert into public.accounts(id,company_id,code,name,account_type,system_key) values($1,$2,$1::uuid::text,$1::uuid::text,$3,$4)',[aid,company,kind,key]);
 await db.query("insert into public.treasury_accounts(id,company_id,code,name,type,gl_account_id) values($1,$2,'SYN-CASH','Synthetic cash','CASH',$3)",[treasury,company,cash]);
 await db.query("insert into public.expense_categories(id,company_id,code,name) values($1,$2,'SYN-COST','Synthetic cost')",[category,company]);
 for(let n=40;n<=49;n++)await db.query("insert into public.historical_source_records(id,company_id,source_file,source_hash,source_reference,record_type,source_month,source_date,description,outflow_minor,raw_source,classification,created_by,cash_treasury_id,review_status) values($1,$2,'synthetic.xlsx',repeat('a',64),$3,'GENERAL','2026-09','2026-09-20',$3,12550,'{\"Project\":\"Unverified worksheet label\"}','{\"nature\":\"EXPENSE\"}',$4,$5,'REVIEWED')",[id(n),company,'SYN-'+n,admin,treasury]);
 await db.exec(readFileSync('supabase/migrations/20261102120000_commercial_company_onboarding.sql','utf8'));
 // Synthetic legacy eligibility only: exercise preexisting accounting commands under
 // FULL access without changing any production identity or bypassing their guards.
 await db.query("insert into private.company_legacy_eligibility(company_id,reason) values($1,'Disposable local accounting integration fixture')",[company]);
 await db.exec(readFileSync('supabase/migrations/20261103120000_project_activation.sql','utf8'));
 const as=(actor,sql,args=[])=>db.transaction(async t=>{await t.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:actor})]);await t.exec('set local role authenticated');return(await t.query(sql,args)).rows});
 const sources=async()=>(await db.query('select *,updated_at::text updated_at,outflow_minor::text outflow_minor,funding_minor::text funding_minor,payroll_net_minor::text payroll_net_minor from public.historical_source_records order by id')).rows;
 return {db,id,admin,accountant,viewer,foreign,company,other,project,closed,foreignProject,cash,cost,overhead,treasury,category,as,sources};
}
