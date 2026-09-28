import React,{useState} from 'react';
import {createRoot} from 'react-dom/client';
import {I18nProvider,useI18n} from '../../src/i18n/I18nContext';
import Output from '../../src/payroll/PayrollRegisterOutput';
import {makeRegister} from '../../src/payroll/payrollRegister';
import {readPayrollRegister} from '../../src/payroll/payrollRegisterRepository';
const context={userId:'user',companyId:'company',companyName:'شركة الاختبار Test Company',role:'ACCOUNTANT',month:'2026-09-01'};
const row={id:'row',company_id:'company',employee_id:'employee',included:true,employee_name:'موظف Frozen Employee',payroll_id:'0007',payroll_type:'Monthly',profession:'Engineer',work_station:'Site A',default_project_id:null,payment_type:'Cash',monthly_salary_minor:'8999999999999999',calendar_days:30,absence_half_units:3,absence_deduction_minor:'17',additions_minor:'123',deductions_minor:'23',gross_salary_minor:'8999999999999982',net_salary_minor:'8999999999999982'};
const draft={attendance_review_valid:true,stale:false,review_valid:true,period:{id:'period',company_id:'company',month:'2026-09-01',state:'DRAFT',version:3,calendar_days:30},rows:[row,{...row,id:'row2',employee_id:'employee2',employee_name:'=HYPERLINK("bad")'},{...row,id:'excluded',included:false}],adjustments:[]};
const posted={postings:[{id:'posted',company_id:'company',month:'2026-09-01',period_id:'period',draft_version:3,reversed:false,snapshot:structuredClone(draft)}]};
const fixture={context,draft,posted,calls:[] as string[],denied:false,session:'user',prints:0,client:{auth:{getSession:async()=>({data:{session:{user:{id:fixture.session}}},error:null})},rpc:async(name:string)=>{fixture.calls.push(name);return {data:name==='read_payroll_draft'?fixture.draft:fixture.posted,error:fixture.denied?{code:'42501'}:null};}},makeRegister,readPayrollRegister};
Object.assign(window,{payrollStep3:fixture});window.print=()=>{fixture.prints++;};
export default function App(){const [role,setRole]=useState('ACCOUNTANT'),[source,setSource]=useState<'DRAFT'|'POSTED'>('DRAFT');const {setLocale}=useI18n();return <><nav>Application navigation<button onClick={()=>setLocale('ar')}>Arabic</button><button onClick={()=>setRole('FOREMAN')}>Foreman</button><button onClick={()=>setSource('POSTED')}>Posted</button></nav><Output {...context} role={role} source={source==='DRAFT'?{kind:'DRAFT',id:'period',version:3}:{kind:'POSTED',id:'posted'}}/></>;}
createRoot(document.getElementById('root')!).render(<I18nProvider><App/></I18nProvider>);
