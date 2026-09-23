// Isolated transport only: no Supabase credentials or hosted/Auth fixture.
import { useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { I18nProvider, useI18n } from '../../src/i18n/I18nContext';
import { ProductionMasterDataContext } from '../../src/master/productionMasterDataContext';
import type { ProductionMasterDataContextValue } from '../../src/master/masterTypes';
import { TreasuryExpensePost } from '../../src/financial/TreasuryExpensePost';
import '../../src/index.css';
const id=(n:number)=>`90000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const company=id(1),user=id(2);
const state={calls:[] as unknown[],reads:[] as unknown[],refreshes:0,mode:'ok',readFail:false,role:(_r:string)=>{},company:(_c:string)=>{},locale:()=>{},client:{} as unknown};
const row={id:id(6),company_id:company,expense_reference:'EXP-TEST',expense_date:'2026-09-23',net_amount_minor:'101',vat_amount_minor:'5',gross_amount_minor:'106',status:'POSTED',funding_mode:'TREASURY',posted_journal_entry_id:id(7)};
state.client={auth:{getSession:async()=>({data:{session:{user:{id:user}}},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},rpc:async(name:string,args:unknown)=>{state.calls.push({name,args});if(state.mode==='lost'){state.mode='ok';throw new Error('lost response');}return {data:[{expense_id:id(6),expense_reference:'EXP-TEST',journal_entry_id:id(7),replayed:state.calls.length>1}],error:null};},from:(table:string)=>{const filters:unknown[]=[];const q={select:(projection:string)=>{state.reads.push({table,projection,filters});return q;},eq:(key:string,value:string)=>{filters.push([key,value]);return q;},maybeSingle:async()=>state.readFail?{data:null,error:{message:'offline'}}:{data:row,error:null}};return q;}};
Object.assign(window,{expensePostTest:state});
export default function Fixture(){const [role,setRole]=useState('ACCOUNTANT'),[scope,setScope]=useState(company);const {setLocale}=useI18n();useEffect(()=>{state.role=setRole;state.company=setScope;state.locale=()=>setLocale('ar');},[setLocale]);const base={companyId:company,status:'ACTIVE',code:'TEST',name:'Test'};const master={phase:'READY',expenseCategories:[{...base,id:id(3)},{...base,id:id(30),companyId:id(99)}],projects:[{...base,id:id(10)},{...base,id:id(11),status:'CLOSED'}],treasuryAccounts:[{...base,id:id(4),projectId:null},{...base,id:id(5),projectId:id(10)}],parties:[{...base,id:id(8),type:'SUPPLIER'},{...base,id:id(9),type:'OWNER'}]} as unknown as ProductionMasterDataContextValue;return <ProductionMasterDataContext.Provider value={master}><TreasuryExpensePost key={`${scope}:${role}`} userId={user} companyId={scope} role={role} onPosted={()=>state.refreshes++}/></ProductionMasterDataContext.Provider>;}
createRoot(document.getElementById('root')!).render(<I18nProvider><Fixture/></I18nProvider>);
