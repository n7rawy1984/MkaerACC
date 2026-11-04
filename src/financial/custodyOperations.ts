import type {SupabaseClient} from '@supabase/supabase-js';
import {custodyRows} from './custodyRead';
import {parseAED,normalizeExpenseInput,expensePayload} from './expensePostRepository';
import {validCostDate} from '../reports/projectCostLedger';
export type CustodyOperation='ADVANCE'|'EXPENSE'|'RETURN'|'SETTLEMENT'|'REVERSE_ADVANCE'|'REVERSE_RETURN'|'REVERSE_EXPENSE';
export type CustodyInput={supplier?:string|null;operation:CustodyOperation;holder:string;date:string;project:string|null;treasury:string|null;amount:string;method:string;reference:string;notes:string;description:string;category:string;vat:'ZERO'|'AUTO_5'|'MANUAL';manualVat:string;invoice:boolean;invoiceNumber:string;expenses:string[];document:string;reason:string};
export type CustodyReceipt={id:string;reference:string;journal:string|null;replayed:boolean};
export type CustodyAttempt={version:1;user:string;company:string;key:string;input:CustodyInput;receipt?:CustodyReceipt};
export const custodyWriter=(role:string)=>role==='ACCOUNTING_ADMIN'||role==='ACCOUNTANT';
export const custodyUUID=(s:unknown):s is string=>typeof s==='string'&&/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(s);
export function normalizeCustodyInput(raw:CustodyInput):CustodyInput{
 const i={...raw,reference:raw.reference?.trim(),notes:raw.notes?.trim(),description:raw.description?.trim(),reason:raw.reason?.trim(),invoiceNumber:raw.invoiceNumber?.trim(),expenses:[...raw.expenses].sort()};
 if(!['ADVANCE','EXPENSE','RETURN','SETTLEMENT','REVERSE_ADVANCE','REVERSE_RETURN','REVERSE_EXPENSE'].includes(i.operation)||!custodyUUID(i.holder)||!validCostDate(i.date)||typeof i.reference!=='string'||i.reference.length>200||typeof i.notes!=='string'||i.notes.length>2000)throw Error('invalid');
 const reverse=i.operation.startsWith('REVERSE');
 if(reverse){if(!custodyUUID(i.document)||!i.reason||i.reason.length>1000)throw Error('invalid');}
 else if(i.operation==='SETTLEMENT'){if(!i.expenses.length||i.expenses.length>999||new Set(i.expenses).size!==i.expenses.length||i.expenses.some(id=>!custodyUUID(id))||!/^\d+$/.test(i.amount)||BigInt(i.amount)<1n||BigInt(i.amount)>9000000000000000n)throw Error('invalid');i.amount=BigInt(i.amount).toString();}
 else {if(!['CASH','BANK','TRANSFER','CHEQUE','OTHER'].includes(i.method))throw Error('invalid');i.amount=parseAED(i.amount);if(i.operation==='ADVANCE'&&i.project!==null&&!custodyUUID(i.project)||i.operation!=='EXPENSE'&&!custodyUUID(i.treasury))throw Error('invalid');
 if(i.operation==='EXPENSE'){
  // Reuse the established Expense VAT/invoice/description validation; the dummy
  // validation Treasury is the authenticated holder UUID, never sent as Treasury.
  const normalized=normalizeExpenseInput({date:i.date,projectId:i.project,categoryId:i.category,supplierId:i.supplier??null,treasuryId:i.holder,description:i.description,netMinor:i.amount,vatMode:i.vat,manualVatMinor:i.vat==='MANUAL'?parseAED(i.manualVat):null,paymentMethod:i.method as 'CASH',hasInvoice:i.invoice,invoiceNumber:i.invoice?i.invoiceNumber:null,notes:i.notes||null});
  i.description=normalized.description;i.invoiceNumber=normalized.invoiceNumber??'';i.manualVat=normalized.manualVatMinor??'';
 }}return i;
}
// Stored inputs contain normalized minor units. Revalidate without multiplying
// minor units a second time on restoration/retry.
export function custodyCommand(company:string,key:string,i:CustodyInput){
 if(!custodyUUID(company)||!custodyUUID(key))throw Error('invalid');
 const base={target_company_id:company,target_idempotency_key:key},common={...base,target_custodian_id:i.holder,target_amount_minor:i.amount,target_treasury_account_id:i.treasury,target_payment_method:i.method,target_external_reference:i.reference||null,target_notes:i.notes||null};
 switch(i.operation){
 case 'ADVANCE':return{name:'post_custody_advance',args:{...common,target_advance_date:i.date,target_project_id:i.project}};
 case 'RETURN':return{name:'post_custody_cash_return',args:{...common,target_return_date:i.date}};
 case 'SETTLEMENT':return{name:'finalize_custody_settlement',args:{target_company_id:company,target_settlement_date:i.date,target_custodian_id:i.holder,target_expense_ids:i.expenses,target_expected_total_minor:i.amount,target_notes:i.notes||null}};
 case 'EXPENSE':return{name:'post_expense',args:{...expensePayload(company,key,{date:i.date,projectId:i.project,categoryId:i.category,supplierId:i.supplier??null,treasuryId:i.holder,description:i.description,netMinor:i.amount,vatMode:i.vat,manualVatMinor:i.vat==='MANUAL'?i.manualVat:null,paymentMethod:i.method as 'CASH',hasInvoice:i.invoice,invoiceNumber:i.invoice?i.invoiceNumber:null,notes:[i.reference,i.notes].filter(Boolean).join('\n')||null}),target_funding_mode:'CUSTODIAN',target_treasury_account_id:null,target_paid_by_party_id:i.holder}};
 default:{const name=i.operation==='REVERSE_ADVANCE'?'reverse_custody_advance':i.operation==='REVERSE_RETURN'?'reverse_custody_cash_return':'reverse_expense',id=i.operation==='REVERSE_ADVANCE'?'target_custody_advance_id':i.operation==='REVERSE_RETURN'?'target_custody_cash_return_id':'target_expense_id';return{name,args:{...base,[id]:i.document,target_reversal_date:i.date,target_reason:i.reason}};}
 }
}
export function custodyStorageKey(user:string,company:string){return 'narvo:custody-command:'+user+':'+company;}
function validReceipt(r:CustodyReceipt){return r&&custodyUUID(r.id)&&typeof r.reference==='string'&&!!r.reference&&(r.journal===null||custodyUUID(r.journal))&&typeof r.replayed==='boolean';}
export function loadCustodyAttempt(storage:Storage,user:string,company:string):CustodyAttempt|null{
 const raw=storage.getItem(custodyStorageKey(user,company));if(!raw)return null;const a=JSON.parse(raw) as CustodyAttempt;
 if(a.version!==1||a.user!==user||a.company!==company||!custodyUUID(a.key)||a.receipt&&!validReceipt(a.receipt))throw Error('recovery');
 const i=a.input,reverse=i.operation.startsWith('REVERSE'),minorAED=(s:string)=>{if(!/^\d+$/.test(s))throw Error('recovery');return (BigInt(s)/100n).toString()+'.'+(BigInt(s)%100n).toString().padStart(2,'0');};
 const normalized=normalizeCustodyInput({...i,amount:reverse||i.operation==='SETTLEMENT'?i.amount:minorAED(i.amount),manualVat:i.operation==='EXPENSE'&&i.vat==='MANUAL'?minorAED(i.manualVat):i.manualVat});
 if(JSON.stringify(normalized)!==JSON.stringify(i))throw Error('recovery');custodyCommand(company,a.key,i);return a;
}
export function saveCustodyAttempt(storage:Storage,a:CustodyAttempt){storage.setItem(custodyStorageKey(a.user,a.company),JSON.stringify(a));}
async function session(client:SupabaseClient,user:string){const r=await client.auth.getSession();if(r.error||r.data.session?.user.id!==user)throw Error('denied');}
async function settlementReceipt(client:SupabaseClient,a:CustodyAttempt):Promise<CustodyReceipt|null>{
 const i=a.input,items=await custodyRows(client,a.company,'custody_settlement_items','id,company_id,settlement_id,expense_id,expense_amount_minor::text',q=>q.in('expense_id',i.expenses));
if(!items.length)return null;
 if(items.length!==i.expenses.length||items.some(r=>r.company_id!==a.company||!i.expenses.includes(r.expense_id))||new Set(items.map(r=>r.settlement_id)).size!==1)throw Error('settlement-conflict');
 const id=items[0].settlement_id;
 const all=await custodyRows(client,a.company,'custody_settlement_items','id,company_id,expense_id',q=>q.eq('settlement_id',id)),headers=await custodyRows(client,a.company,'custody_settlements','id,company_id,custodian_id,settlement_date,settlement_reference,status,created_by,notes,total_expenses_minor::text',q=>q.eq('id',id));
 if(headers.length!==1)throw Error('unresolved');const h=headers[0];
 if(all.length!==i.expenses.length||all.some(r=>!i.expenses.includes(r.expense_id))||h.created_by!==a.user||h.custodian_id!==i.holder||h.settlement_date!==i.date||h.status!=='FINALIZED'||(h.notes??'')!==i.notes||String(h.total_expenses_minor)!==i.amount)throw Error('settlement-conflict');
 return{id,reference:h.settlement_reference,journal:null,replayed:true};
}
const flights=new Map<string,{signature:string;promise:Promise<CustodyAttempt>}>();
export function sendCustodyAttempt(client:SupabaseClient,storage:Storage,a:CustodyAttempt,first=false,valid:()=>boolean=()=>true):Promise<CustodyAttempt>{
 if(a.receipt)return Promise.resolve(a);const slot=custodyStorageKey(a.user,a.company),signature=JSON.stringify([a.key,a.input]),running=flights.get(slot);if(running)return running.signature===signature?running.promise:Promise.reject(Error('unresolved'));
 const promise=(async()=>{try{saveCustodyAttempt(storage,a);}catch{throw Error('storage');}await session(client,a.user);if(!valid())throw Error('denied');const required_permission=a.input.operation.startsWith('REVERSE')?'accounting.reverse':'accounting.post',permission=await client.rpc('has_permission',{target_company_id:a.company,required_permission});if(!valid()||permission.error||permission.data!==true)throw Error('denied');
 const command=custodyCommand(a.company,a.key,a.input);let receipt:CustodyReceipt|null=null;
 if(a.input.operation==='SETTLEMENT')receipt=await settlementReceipt(client,a);
 if(!receipt){if(!valid())throw Error('denied');const {data,error}=await client.rpc(command.name,command.args);
 if(error){if(a.input.operation==='SETTLEMENT')receipt=await settlementReceipt(client,a);if(!receipt){if(first&&['22003','22023','23503','23514','42501','40001','22P02','22007'].includes(error.code)){storage.removeItem(slot);throw Error('rejected');}throw Error('unresolved');}}
 else{const r=Array.isArray(data)&&data.length===1?data[0]:null;if(!r)throw Error('unresolved');receipt={id:r.custody_advance_id??r.custody_cash_return_id??r.expense_id??r.custody_settlement_id,reference:r.advance_reference??r.return_reference??r.expense_reference??r.settlement_reference,journal:r.journal_entry_id??r.reversal_journal_entry_id??null,replayed:r.replayed??false};if(!validReceipt(receipt)||a.input.operation!=='SETTLEMENT'&&!receipt.journal)throw Error('unresolved');}}
 const done={...a,receipt};try{saveCustodyAttempt(storage,done);}catch{/* Keep the frozen request if receipt persistence is unavailable. */}return done;
 })();flights.set(slot,{signature,promise});void promise.finally(()=>{if(flights.get(slot)?.promise===promise)flights.delete(slot);}).catch(()=>{});return promise;
}

export function custodyExpenseTotals(i:CustodyInput){const net=BigInt(i.amount),vat=i.vat==='ZERO'?0n:i.vat==='MANUAL'?BigInt(i.manualVat):(net*5n+50n)/100n;return{net:String(net),vat:String(vat),gross:String(net+vat)};}
