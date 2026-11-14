// Synthetic presentation transport only; no database or real authenticated session.
import React from 'react';
import {createRoot} from 'react-dom/client';
import {BrowserRouter} from 'react-router-dom';
import {I18nProvider} from '../../src/i18n/I18nContext';
import ProtectedApplication from '../../src/auth/ProtectedApplication';
import '../../src/index.css';
declare global{interface Window{navigationFixture:any;navigationClient:any;}}
const root=createRoot(document.getElementById('root')!);
const f=window.navigationFixture={role:'ACCOUNTANT',cid:'00000000-0000-4000-8000-000000000094',actor:'00000000-0000-4000-8000-000000000095',calls:[]as any[],render:()=>root.render(<BrowserRouter><I18nProvider><ProtectedApplication/></I18nProvider></BrowserRouter>),master:{}as any};
f.master={phase:'READY',company:{id:f.cid,name:'Synthetic Company',legalName:null},parties:[{id:'00000000-0000-4000-8000-000000000096',companyId:f.cid,name:'Synthetic Supplier',type:'SUPPLIER',status:'ACTIVE'}],projects:[],accounts:[],expenseCategories:[],treasuryAccounts:[]};
window.navigationClient={auth:{getSession:async()=>({data:{session:{user:{id:f.actor}}},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},async rpc(name:string,args:any){f.calls.push({name,args});if(name==='read_payment_preferences')return{data:[],error:null};if(name==='read_inventory')return{data:{company_id:f.cid,documents:[]},error:null};if(name==='read_supplier_accounts')return{data:{company_id:f.cid,as_of:'2026-11-14',today:'2026-11-14',advance_account_id:null,invoices:[],payments:[],adjustments:[],allocations:[],gl:[]},error:null};throw Error('Unexpected command in read-only navigation fixture: '+name);}};
f.render();
