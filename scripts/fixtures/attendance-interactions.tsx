// Isolated Attendance UI only: in-memory transport, no hosted Auth or credentials.
import {useEffect,useState} from 'react';
import {createRoot} from 'react-dom/client';
import {I18nProvider,useI18n} from '../../src/i18n/I18nContext';
import {AttendanceContent} from '../../src/attendance/AttendanceApplication';
import '../../src/index.css';
const id=(n:number)=>`93000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const company=id(1),user=id(2),employee=id(3),project=id(4);
const state={calls:[] as {name:string;args:Record<string,unknown>}[],entry:null as any,locked:false,revision:0,reviewed:null as number|null,lost:false,failDay:false,
 role:(_r:string)=>{},scope:(_s:string)=>{},locale:()=>{},client:{} as unknown};
state.client={auth:{getSession:async()=>({data:{session:{user:{id:user}}},error:null})},rpc:async(name:string,args:Record<string,any>)=>{
 state.calls.push({name,args});
 if(name==='attendance_context')return{data:{today:'2026-09-27',projects:[{id:project,name:'Site A'}],employees:[{id:employee,name:'Employee One'}]},error:null};
 if(name==='attendance_day')return state.failDay?{data:null,error:{message:'offline'}}:{data:{locked:state.locked,rows:[{employee_id:employee,employee_name:'Employee One',entry:state.entry}]},error:null};
 if(name==='save_attendance_exception'){
  state.entry={id:id(5),company_id:company,employee_id:employee,project_id:project,absence_date:args.target_date,kind:args.target_kind,note:args.target_note,
   voided:args.target_void,version:(state.entry?.version??0)+1,created_by:state.entry?.created_by??user,created_at:'2026-09-27T08:00:00Z',updated_by:user,updated_at:'2026-09-27T08:00:00Z',correction_reason:args.target_reason};
  state.revision++;state.reviewed=null;if(state.lost){state.lost=false;throw new Error('lost response');}return{data:id(5),error:null};
 }
 if(name==='attendance_month')return{data:{period:{revision:state.revision,reviewed_revision:state.reviewed,locked_at:state.locked?'2026-09-27':null},
  assignments:[{id:id(6),employee_id:employee,project_id:project,employee_name:'Employee One',project_name:'Site A',starts_on:'2026-09-01',ends_on:null,version:1}],
  exceptions:state.entry?[{...state.entry,employee_name:'Employee One',project_name:'Site A'}]:[]},error:null};
 if(name==='confirm_attendance_review'){state.reviewed=state.revision;return{data:null,error:null};}
 if(name==='save_employee_site_assignment')return{data:id(6),error:null};
 throw new Error(`Unexpected RPC ${name}`);
}};
Object.assign(window,{attendanceTest:state});
export default function Fixture(){const [role,setRole]=useState('FOREMAN'),[scope,setScope]=useState(company);const {setLocale}=useI18n();useEffect(()=>{state.role=setRole;state.scope=setScope;state.locale=()=>setLocale('ar');},[setLocale]);
 return <AttendanceContent key={`${role}:${scope}`} userId={user} companyId={scope} role={role}/>;
}
createRoot(document.getElementById('root')!).render(<I18nProvider><Fixture/></I18nProvider>);
