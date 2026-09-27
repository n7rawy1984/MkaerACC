// Isolated component fixture; no credentials or hosted Auth. Database arithmetic is tested separately in SQL.
import {useEffect,useState} from 'react';import {createRoot} from 'react-dom/client';import {BrowserRouter} from 'react-router-dom';
import {I18nProvider,useI18n} from '../../src/i18n/I18nContext';import {PayrollContent} from '../../src/payroll/PayrollApplication';import '../../src/index.css';
const id=(n:number)=>`94000000-0000-4000-8000-${String(n).padStart(12,'0')}`;const company=id(1),user=id(2),employee=id(3),project=id(4);
const state={calls:[] as {name:string;args:any}[],profile:null as any,row:null as any,period:null as any,adjustments:[] as any[],attendance:false,stale:false,reviewed:false,lost:false,readFail:false,role:(_r:string)=>{},scope:(_s:string)=>{},locale:()=>{},client:{} as unknown};
state.client={auth:{getSession:async()=>({data:{session:{user:{id:user}}},error:null})},rpc:async(name:string,args:any)=>{
 state.calls.push({name,args});
 if(name==='read_payroll_profiles')return state.readFail?{data:null,error:{code:'offline'}}:{data:{profiles:state.profile?[state.profile]:[],employees:[{id:employee,name:'Employee One'}],projects:[{id:project,name:'Site A'}]},error:null};
 if(name==='save_payroll_profile'){state.profile={id:id(5),company_id:company,employee_id:employee,employee_name:'Employee One',employee_status:'ACTIVE',payroll_id:args.target_payroll_id,payroll_type:args.target_payroll_type,profession:args.target_profession,work_station:args.target_work_station,default_project_id:args.target_project_id,monthly_salary_minor:args.target_salary_minor,payment_type:args.target_payment_type,status:args.target_status,version:(state.profile?.version??0)+1};state.stale=!!state.period;if(state.lost){state.lost=false;throw new Error('lost');}return{data:id(5),error:null};}
 if(name==='read_payroll_draft')return{data:{attendance_review_valid:state.attendance,stale:state.stale,review_valid:state.reviewed&&!state.stale,period:state.period,rows:state.row?[state.row]:[],adjustments:state.adjustments},error:null};
 if(name==='refresh_payroll_draft'){
  state.period={id:id(6),company_id:company,month:args.target_month,state:'DRAFT',version:(state.period?.version??0)+1,calendar_days:30,reviewed_by:null,reviewed_at:null};
  const add=state.adjustments.filter(a=>!a.voided&&a.kind==='ADDITION').reduce((v,a)=>v+BigInt(a.amount_minor),0n);const deduct=state.adjustments.filter(a=>!a.voided&&a.kind==='DEDUCTION').reduce((v,a)=>v+BigInt(a.amount_minor),0n);
  state.row={...state.profile,id:id(7),included:true,calendar_days:30,absence_half_units:0,absence_deduction_minor:'0',additions_minor:add.toString(),deductions_minor:deduct.toString(),gross_salary_minor:state.profile.monthly_salary_minor,net_salary_minor:(BigInt(state.profile.monthly_salary_minor)+add-deduct).toString()};state.stale=false;state.reviewed=false;return{data:id(6),error:null};}
 if(name==='save_payroll_draft_adjustment'){
  const old=state.adjustments.find(a=>a.id===args.target_id);const a={id:args.target_id,company_id:company,row_id:args.target_row_id,kind:args.target_kind,amount_minor:args.target_amount_minor,reason:args.target_reason,voided:args.target_void,version:(old?.version??0)+1,change_reason:args.target_change_reason,created_by:user,updated_by:user,created_at:'2026-09-28T08:00:00Z',updated_at:'2026-09-28T08:00:00Z'};
  state.adjustments=[...state.adjustments.filter(a=>a.id!==args.target_id),a];state.period.version++;state.stale=true;state.reviewed=false;if(state.lost){state.lost=false;throw new Error('lost');}return{data:a.id,error:null};}
 if(name==='review_payroll_draft'){state.reviewed=true;return{data:null,error:null};}
 throw new Error(`Unexpected RPC ${name}`);
}};
Object.assign(window,{payrollTest:state});
export default function Fixture(){const [role,setRole]=useState('ACCOUNTANT'),[scope,setScope]=useState(company);const {setLocale}=useI18n();useEffect(()=>{state.role=setRole;state.scope=setScope;state.locale=()=>setLocale('ar');},[setLocale]);return <PayrollContent key={`${role}:${scope}`} userId={user} companyId={scope} role={role}/>;}
createRoot(document.getElementById('root')!).render(<BrowserRouter><I18nProvider><Fixture/></I18nProvider></BrowserRouter>);
