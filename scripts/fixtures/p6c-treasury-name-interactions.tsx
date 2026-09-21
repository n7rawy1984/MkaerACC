// Isolated transport: real Auth, settings, master providers, shell and profile form.
// Never connects to Supabase and never uses credentials.
import { createRoot } from 'react-dom/client';
import { BrowserRouter, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from '../../src/auth/AuthContext';
import { ProductionMasterDataProvider } from '../../src/master/ProductionMasterDataProvider';
import { SupabaseTenantSettingsProvider } from '../../src/tenant/SupabaseTenantSettingsProvider';
import { I18nProvider } from '../../src/i18n/I18nContext';
import TenantReadyApplication from '../../src/app/TenantReadyApplication';
import '/src/index.css';

const audit={created_at:'2000-01-01T00:00:00.123456+00:00',updated_at:'2000-01-01T00:00:00.123456+00:00',created_by:null,updated_by:null};
const companies=['company-a','company-b'].map((id,i)=>({...audit,id,code:`C${i}`,name:i?'Beta':'Alpha',legal_name:i?'Beta Legal':'Alpha Legal',trn:'00123',address:null,notes:null,status:'ACTIVE'}));
const accounts=Array.from({length:12},(_,i)=>({...audit,id:`gl-${i}`,company_id:'company-a',code:`GL${i}`,name:`GL ${i}`,account_type:'ASSET',parent_account_id:null,requires_party:false,system_key:null,status:'ACTIVE'}));
const treasuries=Array.from({length:12},(_,i)=>({...audit,id:`treasury-${i}`,company_id:'company-a',code:`00${i}`,name:`Treasury ${i}`,type:i===11?'BANK':'CASH',gl_account_id:`gl-${i}`,project_id:i===10?'project-a':null,bank_name:'Bank',account_reference:'000123',notes:'Notes',status:i===11?'INACTIVE':'ACTIVE'}));
treasuries.push({...treasuries[0],id:'treasury-b',company_id:'company-b',code:'B1',name:'Beta Treasury'});
let userId='user-a', role='ACCOUNTING_ADMIN', active=true, signedIn=true, serial=0;
let authListener;
let fault=null, gate=null, release=null;
const log=[];
const client={auth:{
  onAuthStateChange(callback) { authListener=callback; queueMicrotask(()=>callback('INITIAL_SESSION',{user:{id:userId}})); return {data:{subscription:{unsubscribe(){authListener=null;}}}}; },
  getSession:async()=>({data:{session:signedIn?{user:{id:userId}}:null},error:null}),
  getClaims:async()=>({data:{claims:{sub:userId}},error:null}),
  signOut:async()=>{signedIn=false;authListener?.('SIGNED_OUT',null);return {error:null};},
},from(table) {
  let kind='read',single=false,columns='',payload;
  const filters=[];
  const query={
    select(value){columns=value;return query;},order(){return query;},
    eq(key,value){filters.push([key,value]);return query;},in(key,value){filters.push([key,value]);return query;},
    maybeSingle(){single=true;return query;},update(value){kind='update';payload=value;return query;},
    then(done,failed){return (async()=>{
      const operation=kind==='read'&&table==='companies'&&!columns.includes('updated_at')?'authority':kind;
      log.push({table,kind,operation,columns,payload,filters:structuredClone(filters)});
      let rows=table==='treasury_accounts'?(role==='PROJECT_MANAGER'?treasuries.filter(t=>t.project_id==='project-a'):['ACCOUNTING_ADMIN','ACCOUNTANT','MANAGEMENT_VIEWER'].includes(role)?treasuries:[]):table==='accounts'?(['ACCOUNTING_ADMIN','ACCOUNTANT','MANAGEMENT_VIEWER'].includes(role)?accounts:[]):table==='companies'?companies:table==='profiles'?(active?[{user_id:userId,display_name:'Test',email_snapshot:null,locale:'en',status:'ACTIVE'}]:[]):table==='company_memberships'?(active?companies.map(c=>({id:c.id+'-membership',company_id:c.id,user_id:userId,role,status:'ACTIVE'})):[]):table==='company_settings'?companies.map(c=>({company_id:c.id,tenant_slug:c.id,app_display_name:c.name+' Brand',default_locale:'en',logo_url:null,favicon_url:null,primary_color:'#112233',accent_color:'#445566'})):[];
      rows=rows.filter(row=>filters.every(([key,value])=>Array.isArray(value)?value.includes(row[key]):row[key]===value));
      const snapshot=structuredClone(rows);
      if(gate===operation && table==='treasury_accounts'){gate=null;await new Promise(resolve=>{release=resolve;});}
      if(fault===operation && table==='treasury_accounts'){fault=null;return {data:null,error:{code:'network'}};}
      if(kind==='update') {
        if(!active||role!=='ACCOUNTING_ADMIN')return {data:[],error:null};
        rows=treasuries.filter(row=>filters.every(([key,value])=>row[key]===value));
        for(const row of rows)Object.assign(row,payload,{updated_at:`2026-09-17T00:00:00.${String(++serial).padStart(6,'0')}+00:00`,updated_by:userId});
        return {data:structuredClone(rows),error:null};
      }
      return {data:single?(snapshot[0]??null):snapshot,error:null};
    })().then(done,failed);},
  };return query;
}};
window.slice10={log,companies,accounts,treasuries,
  fail(kind){fault=kind;},hold(kind){gate=kind;},release(){release?.();release=null;},
  role(value){role=value;window.dispatchEvent(new Event('focus'));},
  revoke(){active=false;window.dispatchEvent(new Event('focus'));},
  restore(){active=true;window.dispatchEvent(new Event('focus'));},
  switchUser(){userId='user-b';authListener?.('SIGNED_IN',{user:{id:userId}});},
  logout(){void client.auth.signOut();},
  concurrent(){treasuries[11].name='Concurrent Treasury';treasuries[11].updated_at=`2026-09-17T00:00:00.${String(++serial).padStart(6,'0')}+00:00`;},
};
export function Scope() {
  const {state,syncCompanyLegalName,chooseCompany}=useAuth();
  if(state.phase!=='TENANT_READY')return <><p data-testid="auth-phase">{state.phase}</p>{state.phase==='SELECTING_COMPANY'&&<button type="button" onClick={()=>chooseCompany('company-a')}>Select fixture Alpha</button>}</>;
  return <>
    <output data-testid="auth-legal">{state.activeTenant.companyLegalName??'NULL'}</output>
    <button type="button" onClick={()=>chooseCompany(state.activeTenant.companyId==='company-a'?'company-b':'company-a')}>Switch fixture company</button>
    <SupabaseTenantSettingsProvider key={`${state.profile.userId}:${state.activeTenant.companyId}`} client={client} profile={state.profile} tenant={state.activeTenant}>
      <ProductionMasterDataProvider key={`${state.profile.userId}:${state.activeTenant.companyId}:${state.activeTenant.role}`} client={client} userId={state.profile.userId} activeCompanyId={state.activeTenant.companyId} role={state.activeTenant.role} onCompanyProfileRefreshed={syncCompanyLegalName}>
        <Routes><Route path="*" element={<TenantReadyApplication view="treasuryAccounts"/>}/></Routes>
      </ProductionMasterDataProvider>
    </SupabaseTenantSettingsProvider>
  </>;
}
localStorage.setItem('makeracc:p6a:active-company:user-a','company-a');
localStorage.setItem('cas:v1:locale','en');
createRoot(document.getElementById('root')).render(<I18nProvider><BrowserRouter><AuthProvider client={client}><Scope/></AuthProvider></BrowserRouter></I18nProvider>);
