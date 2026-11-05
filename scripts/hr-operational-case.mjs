import {randomUUID} from 'node:crypto';
// Explicit synthetic evidence only. Used by browser/concurrency fixtures, never production.
export async function seedHrCase(f,{post=false,cutover='2026-10-01',effective='2026-10-01'}={}){
 const month='2026-10-01',sql=async(q,a=[])=>(await f.as(f.admin,q,a))[0]?.r;
 const command=(action,input)=>sql('select public.command_hr($1,$2,$3,$4) r',[f.company,randomUUID(),action,{evidence:'Approved synthetic fixture',...input}]);
 await command('POLICY',{effective_month:cutover,method:'SCHEDULED_MINUTES',timezone:'Asia/Dubai',approved:true,version:0});
 await command('TERMS',{employee_id:f.person,effective_on:effective,employed_from:month,basic_minor:'31000',allowances:[{name:'Transport',amount_minor:'3100'}],weekdays:[1,2,3,4,5,6,7],start_minute:480,end_minute:1020,break_minutes:60,project_id:f.p2,status:'ACTIVE',version:0});
 await command('SETUP',{version:0,SALARY_PAYABLE:'NEW',SALARY_PAYABLE_code:'SAL-AP',SALARY_PAYABLE_name:'Salary payable',PROJECT_COST:'NEW',PROJECT_COST_code:'LABOR',PROJECT_COST_name:'Project labor',COMPANY_EXPENSE:'NEW',COMPANY_EXPENSE_code:'STAFF',COMPANY_EXPENSE_name:'Staff overhead',advance_account_id:'NEW',advance_code:'EMP-ADV',advance_name:'Employee advances'});
 await sql("select public.save_payroll_profile($1,$2,0,'EMP-HR','STAFF','Engineer','Synthetic Site',$3,1,'BANK','ACTIVE') r",[f.company,f.person,f.p2]);
 if(!post)return{...f,month};
 const w=await sql('select public.read_hr_workspace($1,$2) r',[f.company,month]);
 await sql('select public.bulk_hr_attendance($1,$2,$3) r',[f.company,randomUUID(),w.days.map((d,i)=>({employee_id:f.person,day:d.day,version:0,status:'PRESENT',project_id:i===0?'':f.p2,start_minute:480,end_minute:1020,break_minutes:60,paid_leave_minutes:0,overtime_earned_minor:'0',evidence:'Actual synthetic attendance'}))]);
 const loan=await command('ADVANCE',{employee_id:f.person,treasury_id:f.bank,date:month,amount_minor:'1000',monthly_limit_minor:'500'});
 await command('RECOVERY',{month,advance_id:loan.id,amount_minor:'500',version:0});
 const state=await sql('select public.read_hr_workspace($1,$2) r',[f.company,month]);await command('REVIEW',{month,version:state.period.revision});
 const period=await sql('select public.refresh_payroll_draft($1,$2,0) r',[f.company,month]);let draft=await sql('select public.read_payroll_draft($1,$2) r',[f.company,month]);
 await sql('select public.prepare_payroll_accounting($1,$2,$3,$4,$5) r',[f.company,period,draft.period.version,{[draft.rows[0].id]:draft.rows[0].default_project_id},{}]);
 draft=await sql('select public.read_payroll_draft($1,$2) r',[f.company,month]);await sql('select public.review_payroll_draft($1,$2,$3) r',[f.company,period,draft.period.version]);
 return{...f,month,period,draft,loan,postKey:randomUUID(),sql};
}
