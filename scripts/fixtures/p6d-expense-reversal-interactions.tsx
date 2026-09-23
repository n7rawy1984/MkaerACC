// Actual reversal component with isolated in-memory transport; no hosted Auth fixture or credentials.
import { useEffect, useState } from 'react';
import { createRoot } from 'react-dom/client';
import { I18nProvider, useI18n } from '../../src/i18n/I18nContext';
import { ExpenseReverseAction } from '../../src/financial/ExpenseReverseAction';
import type { ExpenseRead } from '../../src/financial/expenseRepository';
import '../../src/index.css';
const id=(n:number)=>`92000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const company=id(1),user=id(2),expenseId=id(3),postedJournal=id(4),reversalJournal=id(5);
const posted:ExpenseRead={id:expenseId,company_id:company,expense_reference:'EXP-TEST',expense_date:'2026-09-23',project_id:null,expense_category_id:id(6),supplier_id:null,description:'Exact Expense',net_amount_minor:'9007199254740993',vat_mode:'ZERO',vat_amount_minor:'0',gross_amount_minor:'9007199254740993',funding_mode:'TREASURY',treasury_account_id:id(7),paid_by_party_id:null,payment_method:'BANK',has_tax_invoice:false,invoice_number:null,notes:null,status:'POSTED',posted_journal_entry_id:postedJournal,reversal_journal_entry_id:null,created_at:'2026-09-23T00:00:00Z',created_by:user,updated_at:'2026-09-23T00:00:00Z',updated_by:user,posted_at:'2026-09-23T00:00:00Z',posted_by:user,reversed_at:null,reversed_by:null};
let serverRow:ExpenseRead={...posted};
const state={calls:[] as unknown[],reads:0,refreshes:0,readFail:true,role:(_r:string)=>{},locale:()=>{},reset:()=>{},client:{} as unknown};
state.client={auth:{getSession:async()=>({data:{session:{user:{id:user}}},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},rpc:async(name:string,args:unknown)=>{state.calls.push({name,args});serverRow={...serverRow,status:'REVERSED',reversal_journal_entry_id:reversalJournal,reversed_at:'2026-09-23T01:00:00Z',reversed_by:user};return{data:[{expense_id:expenseId,expense_reference:'EXP-TEST',reversal_journal_entry_id:reversalJournal,replayed:false}],error:null};},from:()=>{const q={select:()=>q,eq:()=>q,maybeSingle:async()=>{state.reads++;return state.readFail?{data:null,error:{message:'offline'}}:{data:serverRow,error:null};}};return q;}};
Object.assign(window,{expenseReverseTest:state});
export default function Fixture(){const [role,setRole]=useState('ACCOUNTING_ADMIN'),[row,setRow]=useState<ExpenseRead>(posted);const {setLocale}=useI18n();useEffect(()=>{state.role=setRole;state.locale=()=>setLocale('ar');state.reset=()=>{sessionStorage.clear();serverRow={...posted};state.calls.length=0;state.reads=0;state.readFail=true;setRow({...posted});setRole('ACCOUNTING_ADMIN');};},[setLocale]);return <main className="p-3"><p>Role: {role}</p><p>Status: {row.status}</p><ExpenseReverseAction key={`${role}:${row.id}`} userId={user} companyId={company} role={role} expense={row} onRefresh={()=>{state.refreshes++;setRow({...serverRow});}} /></main>;}
createRoot(document.getElementById('root')!).render(<I18nProvider><Fixture/></I18nProvider>);
