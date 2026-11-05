// Regression: a corrected employment start excludes an old draft row, not its audit history.
import assert from 'node:assert/strict';import{randomUUID}from'node:crypto';import{writeFileSync}from'node:fs';import{hrOperationalFixture}from'./hr-operational-fixture.mjs';import{seedHrCase}from'./hr-operational-case.mjs';
const f=await seedHrCase(await hrOperationalFixture(),{post:true,cutover:'2026-09-01',effective:'2026-09-01'}),checks=[],employee=randomUUID();
const command=(action,input)=>f.sql('select public.command_hr($1,$2,$3,$4) r',[f.company,randomUUID(),action,{evidence:'Signed synthetic correction',...input}]);
try{
 await command('TERMS',{employee_id:f.person,effective_on:'2026-10-01',employed_from:'2026-09-01',employed_until:'2026-09-30',basic_minor:'31000',allowances:[],weekdays:[1,2,3,4,5,6,7],start_minute:480,end_minute:1020,break_minutes:60,project_id:f.p2,status:'ENDED',version:1});
 await f.db.query("insert into public.parties(id,company_id,code,name,type) values($1,$2,'EMP-B','Synthetic Employee B','EMPLOYEE')",[employee,f.company]);
 await command('TERMS',{employee_id:employee,effective_on:'2026-10-01',employed_from:'2026-10-31',employed_until:'2026-10-31',basic_minor:'31000',allowances:[],weekdays:[1,2,3,4,5,6,7],start_minute:480,end_minute:1020,break_minutes:60,project_id:f.p2,status:'ACTIVE',version:0});
 await f.sql("select public.save_payroll_profile($1,$2,0,'EMP-B','STAFF','Engineer','Site',$3,1,'BANK','ACTIVE') r",[f.company,employee,f.p2]);
 await command('ATTENDANCE',{employee_id:employee,day:'2026-10-31',version:0,status:'PRESENT',project_id:f.p2,start_minute:480,end_minute:1020,break_minutes:60,paid_leave_minutes:0,overtime_earned_minor:'0'});
 const w=await f.sql('select public.read_hr_workspace($1,$2) r',[f.company,f.month]);await command('REVIEW',{month:f.month,version:w.period.revision});
 await f.sql('select public.refresh_payroll_draft($1,$2,$3) r',[f.company,f.month,f.draft.period.version]);let d=await f.sql('select public.read_payroll_draft($1,$2) r',[f.company,f.month]);
 assert(d.rows.some(r=>r.employee_id===f.person&&!r.included&&r.hr_basis.recovery_minor==='500'));checks.push('Corrected employment preserves the excluded row and its old recovery evidence');
 const live=d.rows.filter(r=>r.included);assert.equal(live.length,1);assert.equal(live[0].gross_salary_minor,'1000');checks.push('Join/exit proration includes only the one actually employed day');
 await f.sql('select public.prepare_payroll_accounting($1,$2,$3,$4,$5) r',[f.company,f.period,d.period.version,{[live[0].id]:f.p2},{}]);d=await f.sql('select public.read_payroll_draft($1,$2) r',[f.company,f.month]);await f.sql('select public.review_payroll_draft($1,$2,$3) r',[f.company,f.period,d.period.version]);
 const posting=await f.sql('select public.post_payroll($1,$2,$3,$4) r',[f.company,f.period,d.period.version,randomUUID()]);assert(posting);assert.equal(Number((await f.db.query('select count(*) n from public.hr_recovery_postings')).rows[0].n),0);checks.push('Excluded employee recovery cannot affect the replacement payroll');
 assert.equal(String((await f.db.query('select private.hr_recovery_balance($1,$2) n',[f.company,f.loan.id])).rows[0].n),'1000');checks.push('Exclusion preserves the outstanding advance without fabricated recovery');
 writeFileSync('/tmp/narvo-hr-excluded-recovery.json',JSON.stringify({status:'PASS',checks,hosted:false},null,2));console.log('PASS',checks.length,checks);
}catch(e){console.error('FAIL',e.message,e.code,e.where??'');process.exitCode=1}finally{await f.db.close()}
