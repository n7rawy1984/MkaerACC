import React,{useState} from 'react';import {createRoot} from 'react-dom/client';import {BrowserRouter,Link} from 'react-router-dom';
import {AuthProvider,useAuth} from '../../src/auth/AuthContext';import {AuthErrorPage} from '../../src/auth/AuthErrorPage';import {I18nProvider,useI18n} from '../../src/i18n/I18nContext';
import {ProductionMasterDataProvider} from '../../src/master/ProductionMasterDataProvider';import {useProductionMasterData} from '../../src/master/productionMasterDataContext';
import {savePayrollAttempt,loadPayrollAttempt} from '../../src/payroll/payrollPostingAttempt';
let listener:any;
const f={user:'user-a',company:'company-a',active:true,profileActive:true,companyActive:true,fail:'',delay:false,pending:[] as (()=>void)[],reads:[] as string[],rounds:0,
 emit:(event='SIGNED_IN')=>listener(event,event==='SIGNED_OUT'?null:{user:{id:f.user}}),
 client:{auth:{onAuthStateChange:(cb:any)=>{listener=cb;queueMicrotask(()=>f.emit('INITIAL_SESSION'));return {data:{subscription:{unsubscribe(){}}}};},getClaims:async()=>({data:{claims:{sub:f.user}},error:null}),getSession:async()=>({data:{session:{user:{id:f.user}}},error:null}),signOut:async()=>f.emit('SIGNED_OUT')},
 from:(table:string)=>{f.reads.push(table);const user=f.user,company=f.company;let data:any=[];if(table==='profiles')data=f.profileActive?{user_id:user,display_name:user,email_snapshot:null,locale:'en',status:'ACTIVE'}:null;
 if(table==='company_memberships'){f.rounds++;data=f.active?[{id:'membership-'+user,user_id:user,company_id:company,role:'ACCOUNTANT',status:'ACTIVE'}]:[];}
 if(table==='companies')data=f.companyActive?[{id:company,code:company,name:'DATABASE '+company,legal_name:null,status:'ACTIVE'}]:[];
 if(table==='projects')data=[{id:'project',company_id:company,code:'P1',name:'DATABASE PROJECT',status:'ACTIVE'}];
 const error=f.fail===table?{message:'Synthetic DB read failure'}:null;
 const q:any={select:()=>q,eq:()=>q,in:()=>q,order:()=>q,maybeSingle:()=>{if(Array.isArray(data))data=data[0]??null;return q;},then:(done:any)=>{const finish=()=>done({data,error});if(f.delay&&table==='company_memberships')f.pending.push(finish);else queueMicrotask(finish);}};return q;
 }}};
Object.assign(window,{p6e:f});
function Business(){const data=useProductionMasterData(),[draft,setDraft]=useState('');return <><p data-testid="data">{data.phase==='READY'?data.company.name+' / '+data.projects.map(p=>p.name).join(','):data.phase}</p>{data.phase==='READY'&&<><input aria-label="User draft" value={draft} onChange={e=>setDraft(e.target.value)}/><button>Protected action</button></>}</>;}
function Session(){const {state,retry,signOut}=useAuth();const {locale,setLocale}=useI18n();return <><p data-testid="phase">{state.phase}</p><button onClick={()=>setLocale(locale==='en'?'ar':'en')}>Locale</button><button onClick={retry}>Revalidate</button><button onClick={()=>void signOut()}>Logout</button><Link to="/other">Navigate</Link>{state.phase==='IDENTITY_LOAD_ERROR'?<AuthErrorPage/>:state.phase==='TENANT_READY'?<ProductionMasterDataProvider key={`${state.profile.userId}:${state.activeTenant.companyId}:${state.activeTenant.role}`} client={f.client as any} userId={state.profile.userId} activeCompanyId={state.activeTenant.companyId} role={state.activeTenant.role}><Business/></ProductionMasterDataProvider>:null}</>;}
// Recovery records remain request envelopes only; never source the displayed business state.
Object.assign(f,{saveRecovery:()=>savePayrollAttempt(sessionStorage,'user-a','company-a',{name:'pay_salary',args:{target_company_id:'company-a',target_amount_minor:'123',target_idempotency_key:'10000000-0000-4000-8000-000000000001'}}),readRecovery:(u='user-a',c='company-a')=>loadPayrollAttempt(sessionStorage,u,c)});
export default function Fixture(){return <I18nProvider><BrowserRouter><AuthProvider client={f.client as any}><Session/></AuthProvider></BrowserRouter></I18nProvider>;}
createRoot(document.getElementById('root')!).render(<Fixture/>);
