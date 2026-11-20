import {documentsFixture} from './private-documents-fixture.mjs';
import {readFileSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
import assert from 'node:assert/strict';
export async function hrCommercialFixture(database){
 const f=await documentsFixture(database),before=await f.fingerprint();
 await f.db.exec(readFileSync('supabase/migrations/20261128120000_hr_payroll_commercial.sql','utf8'));assert.equal(await f.fingerprint(),before,'Migration110 preserves all financial/master/access fingerprints');
 const call=(action,input,key=randomUUID(),actor=f.admin,cid=f.company)=>f.as(actor,'select public.command_hr_commercial($1,$2,$3,$4)r',[cid,key,action,{reason:'Isolated fictional evidence; no hosted requests',...input}]).then(r=>r[0].r);
 const read=(actor=f.admin,cid=f.company)=>f.as(actor,"select public.read_hr_commercial($1,date_trunc('month',current_date)::date)r",[cid]).then(r=>r[0].r);
 const expense=randomUUID(),payable=randomUUID();await f.db.query("insert into public.accounts(id,company_id,code,name,account_type,requires_party)values($1,$3,'EOS-EXP','Fictional gratuity expense','EXPENSE',false),($2,$3,'EOS-PAY','Fictional gratuity payable','LIABILITY',true)",[expense,payable,f.company]);
 const day=(await f.db.query('select current_date::text d')).rows[0].d;
 await f.as(f.admin,"select public.command_hr($1,$2,'POLICY',$3)",[f.company,randomUUID(),{version:0,effective_month:'2020-01-01',method:'SCHEDULED_MINUTES',timezone:'Asia/Dubai',approved:true,evidence:'Fictional policy'}]);
 const terms={employee_id:f.employee,version:0,effective_on:'2020-01-01',employed_from:'2020-01-01',employed_until:day,basic_minor:'300000',allowances:[],weekdays:[1,2,3,4,5],start_minute:480,end_minute:1020,break_minutes:60,status:'ACTIVE',evidence:'Fictional signed employment and termination'};
 await f.as(f.admin,"select public.command_hr($1,$2,'TERMS',$3)",[f.company,randomUUID(),terms]);
 const input={id:randomUUID(),employee_id:f.employee,last_day:day,unpaid_days:'0',scheme:'FOREIGN_FULL_TIME_TRADITIONAL',basis:'ACTUAL_365',no_prior_provision:true};
 return {...f,call,read,expense,payable,day,input};
}
export async function seedPayroll(f,{recovery=false}={}){
 const month=(await f.db.query("select (date_trunc('month',current_date)-interval'1 month')::date::text m")).rows[0].m;
 const rpc=(name,args)=>f.as(f.admin,'select public.'+name+'('+Object.keys(args).map((k,i)=>k+'=> $'+(i+1)).join(',')+')r',Object.values(args)).then(r=>r[0].r);
 const hr=(action,input)=>rpc('command_hr',{cid:f.company,request_id:randomUUID(),action,input:{evidence:'Fictional approved HR event',...input}});
 const receivable=randomUUID();if(recovery)await f.db.query("insert into public.accounts(id,company_id,code,name,account_type,requires_party)values($1,$2,'HR110-ADV','Fictional employee receivable','ASSET',true)",[receivable,f.company]);
 await hr('SETUP',{version:0,advance_account_id:recovery?receivable:null,SALARY_PAYABLE:f.accounts.SALARY_PAYABLE,PROJECT_COST:f.accounts.PROJECT_COST,COMPANY_EXPENSE:f.accounts.COMPANY_EXPENSE});
 await rpc('save_payroll_profile',{target_company_id:f.company,target_employee_id:f.employee,target_version:0,target_payroll_id:'HR110-E1',target_payroll_type:'STAFF',target_profession:'Operator',target_work_station:'Office',target_project_id:null,target_salary_minor:'300000',target_payment_type:'BANK',target_status:'ACTIVE'});
 if(recovery){await f.db.transaction(async tx=>{await tx.query("select private.create_journal($1,$2,'Fictional prior-month advance funding','TEST',$3,'POST',$4,$5)",[f.company,month,randomUUID(),[{account_id:f.accounts.CASH,treasury_account_id:f.treasury,debit_minor:'10000',credit_minor:'0'},{account_id:f.accounts.EQUITY,debit_minor:'0',credit_minor:'10000'}],f.admin])});const a=await hr('ADVANCE',{employee_id:f.employee,date:month,amount_minor:'5000',monthly_limit_minor:'1000',treasury_id:f.treasury});await hr('RECOVERY',{advance_id:a.id,month,version:0,amount_minor:'1000'})}
 let h=await rpc('read_hr_workspace',{cid:f.company,m:month});
 await rpc('bulk_hr_attendance',{cid:f.company,request_id:randomUUID(),entries:h.days.map(d=>({employee_id:d.employee_id,day:d.day,version:0,status:d.expected_minutes?'PRESENT':'REST',start_minute:d.expected_minutes?480:null,end_minute:d.expected_minutes?1020:null,break_minutes:d.expected_minutes?60:0,paid_leave_minutes:0,overtime_earned_minor:'0',evidence:'Fictional completed scheduled attendance'}))});
 h=await rpc('read_hr_workspace',{cid:f.company,m:month});await hr('REVIEW',{month,version:h.period.revision});
 const id=await rpc('refresh_payroll_draft',{target_company_id:f.company,target_month:month,target_version:0});let draft=await rpc('read_payroll_draft',{target_company_id:f.company,target_month:month});
 await rpc('prepare_payroll_accounting',{target_company_id:f.company,target_period_id:id,target_version:draft.period.version,target_allocations:Object.fromEntries(draft.rows.map(r=>[r.id,null])),target_classifications:{}});draft=await rpc('read_payroll_draft',{target_company_id:f.company,target_month:month});
 await rpc('review_payroll_draft',{target_company_id:f.company,target_period_id:id,target_version:draft.period.version});const payroll=await rpc('post_payroll',{target_company_id:f.company,target_period_id:id,target_version:draft.period.version,target_idempotency_key:randomUUID()});
 return {rpc,hr,month,payroll};
}
