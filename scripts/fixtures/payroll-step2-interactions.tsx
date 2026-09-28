// Isolated actual Step 2 component; fake transport only, no credentials or hosted Auth.
import {useEffect,useState} from 'react';import {createRoot} from 'react-dom/client';
import {I18nProvider,useI18n} from '../../src/i18n/I18nContext';import PayrollPosting from '../../src/payroll/PayrollPosting';import '../../src/index.css';
const id=(n:number)=>`95620000-0000-4000-8000-${String(n).padStart(12,'0')}`;const company=id(1),user=id(2),row=id(3),employee=id(4),period=id(5);
const draft:any={period:{id:period,company_id:company,month:'2026-08-01',version:1},stale:false,review_valid:true,attendance_review_valid:true,rows:[{id:row,company_id:company,employee_id:employee,employee_name:'Employee One',included:true,default_project_id:null}],adjustments:[{id:id(11),kind:'ADDITION',amount_minor:'100',reason:'Bonus',voided:false}]};
const data:any={accounting:null,postings:[],entitlements:[],payments:[],treasuries:[{id:id(6),name:'Bank',project_id:null}]};
const receipts=new Map();const state={draft,data,calls:[] as any[],lost:false,remount:()=>{},locale:()=>{},review:()=>{},role:(_r:string)=>{},client:{} as any};
state.client={auth:{getSession:async()=>({data:{session:{user:{id:user}}},error:null})},rpc:async(name:string,args:any)=>{
 state.calls.push({name,args});if(name==='read_payroll_profiles')return{data:{profiles:[],employees:[],projects:[]},error:null};if(name==='read_payroll_postings')return{data:structuredClone(data),error:null};
 if(receipts.has(args.target_idempotency_key))return {data:receipts.get(args.target_idempotency_key),error:null};
 let result=id(20+state.calls.length);
 if(name==='prepare_payroll_accounting'){data.accounting={version:++draft.period.version};draft.review_valid=false;}
 else if(name==='post_payroll'){data.postings.push({id:result,company_id:company,month:'2026-08-01',reversed:false});data.entitlements.push({id:id(7),company_id:company,payroll_id:result,employee_name:'Employee One',project_id:null,amount_minor:'10000',unpaid_minor:'10000'});}
 else if(name==='pay_salary'){data.payments.push({id:result,company_id:company,entitlement_id:id(7),amount_minor:args.target_amount_minor,payment_date:args.target_date,reference:args.target_reference,reversed:false});data.entitlements[0].unpaid_minor=(BigInt(data.entitlements[0].unpaid_minor)-BigInt(args.target_amount_minor)).toString();}
 else if(name==='reverse_salary_payment'){const p=data.payments.find((p:any)=>p.id===args.target_payment_id);p.reversed=true;data.entitlements[0].unpaid_minor=(BigInt(data.entitlements[0].unpaid_minor)+BigInt(p.amount_minor)).toString();}
 else if(name==='reverse_payroll'){data.postings[0].reversed=true;draft.stale=true;draft.review_valid=false;}
 else throw Error('Unexpected command');
 if(args.target_idempotency_key)receipts.set(args.target_idempotency_key,result);if(state.lost){state.lost=false;throw Error('Lost response');}return{data:result,error:null};
}};Object.assign(window,{payrollStep2:state});
export default function Fixture(){const [revision,setRevision]=useState(0),[role,setRole]=useState('ACCOUNTING_ADMIN');const {setLocale}=useI18n();useEffect(()=>{state.remount=()=>setRevision(r=>r+1);state.role=setRole;state.locale=()=>setLocale('ar');state.review=()=>{draft.review_valid=true;setRevision(r=>r+1);};},[setLocale]);return <div className="p-4"><PayrollPosting key={`${revision}:${role}`} userId={user} companyId={company} role={role} month="2026-08-01" draft={draft} onLocked={()=>{}} done={()=>setRevision(r=>r+1)}/></div>;}
createRoot(document.getElementById('root')!).render(<I18nProvider><Fixture/></I18nProvider>);
