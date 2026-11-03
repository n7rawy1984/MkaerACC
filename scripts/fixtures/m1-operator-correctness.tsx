// Synthetic UI transport only. No hosted access or real identity.
import {createRoot} from 'react-dom/client';
import {useEffect} from 'react';
import {BrowserRouter} from 'react-router-dom';
import {I18nProvider,useI18n} from '../../src/i18n/I18nContext';
import {SubcontractsList} from '../../src/master/SubcontractsList';
import {SourceEditor} from '../../src/historical/SourceEditor';
import {TreasuryExpensePost} from '../../src/financial/TreasuryExpensePost';
import '../../src/index.css';
const id=(n:number)=>`90000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const base={companyId:id(1),status:'ACTIVE',code:'TEST',name:'Synthetic'};
const row={id:id(5),company_id:id(1),source_reference:'SYN-M1',source_file:'synthetic.xlsx',source_month:'2026-08',source_date:'2026-08-01',description:'Synthetic historical expense',outflow_minor:'6000',funding_minor:null,payroll_net_minor:null,record_type:'GENERAL',raw_source:{'Original workbook date':'08/01/2026'},classification:{nature:'EXPENSE'},completion:{},review_status:'PENDING',updated_at:'2026-10-08T00:00:00Z',expense_id:null,payroll_entitlement_id:null,cash_treasury_id:id(4),payroll_profile_id:null};
const master={phase:'READY',subcontractMetadataMutation:{phase:'IDLE'},projects:[{...base,id:id(10)}],parties:[],expenseCategories:[{...base,id:id(3)}],treasuryAccounts:[{...base,id:id(4),projectId:null}],subcontracts:[{companyId:id(1),id:id(11),projectId:id(10),subcontractorId:id(12),contractNumber:'SYN-M1',scopeOfWork:'Synthetic scope',originalContractValueMinor:'6500000',approvedVariationsMinor:'-105',retentionBps:1000,startDate:null,expectedEndDate:null,notes:null,status:'ACTIVE'}]};
const fixture={row,master,user:id(2),company:id(1),role:'ACCOUNTING_ADMIN',view:'edit',calls:[] as {name:string;args:Record<string,unknown>}[],failure:false,hold:false,release:null as null|(()=>void),closed:false,render:()=>{},locale:(_l:string)=>{}};
const client={auth:{getSession:async()=>({data:{session:{user:{id:id(2)}}},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},from:()=>{const q={select:()=>q,eq:()=>q,order:()=>q,then:(r:(x:unknown)=>unknown)=>Promise.resolve({data:[],error:null}).then(r)};return q;},rpc:async(name:string,args:Record<string,unknown>)=>{fixture.calls.push({name,args});if(fixture.hold)await new Promise<void>(r=>{fixture.release=r;});return fixture.failure?{data:null,error:{code:'SYNTHETIC_FAILURE'}}:{data:{},error:null};}};
Object.assign(window,{m1:{...fixture,client}});
const f=(window as unknown as {m1:typeof fixture&{client:typeof client}}).m1;
// Closures use the same fixture object as the browser controls.
Object.defineProperties(f,{calls:{get:()=>fixture.calls},failure:{get:()=>fixture.failure,set:v=>{fixture.failure=v;}},hold:{get:()=>fixture.hold,set:v=>{fixture.hold=v;}},release:{get:()=>fixture.release}});
export default function View(){const {setLocale}=useI18n();useEffect(()=>{f.locale=l=>setLocale(l==='ar'?'ar':'en');},[setLocale]);if(f.view==='subcontracts')return <SubcontractsList/>;if(f.view==='expense')return <TreasuryExpensePost userId={f.user} companyId={f.company} role={f.role} onPosted={()=>{}}/>;return <SourceEditor row={f.row} mode="edit" companyId={f.company} userId={f.user} role={f.role} close={()=>{f.closed=true;f.view='closed';f.render();}}/>;}
const root=createRoot(document.getElementById('root')!);f.render=()=>root.render(<I18nProvider><BrowserRouter>{f.view==='closed'?<p>Closed</p>:<View key={f.view+':'+f.role}/>}</BrowserRouter></I18nProvider>);f.render();
