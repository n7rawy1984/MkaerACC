import type {SourceRecord} from '../historical/sourceModel';
export type PaymentPreference={id:string;company_id:string;scope_key:string;version:number;kind:'DEFAULT'|'SOURCE_SET';mode:'NONE'|'TREASURY'|'CUSTODIAN';treasury_id:string|null;party_id:string|null;source_file:string|null;source_hash:string|null;month_from:string|null;month_through:string|null;approval_reference:string;created_by:string;created_at:string};
export type SourcePaymentPolicy={source_id:string;company_id:string;policy_id:string;mode:'TREASURY'|'CUSTODIAN';treasury_id:string|null;party_id:string|null;reference:string;contradicted:boolean};
export function confirmedSourcePayment(row:SourceRecord):{mode:'TREASURY'|'CUSTODIAN';party_id:string|null;treasury_id:string|null;reference:string}|null{
 const p=row.payment_policy;
 if(row.completion.funding_contradiction==='true'||p?.contradicted||row.record_type!=='GENERAL'||BigInt(row.outflow_minor??'0')<=0n)return null;
 if(p&&(row.completion.custodian_id&&row.completion.custodian_id!==p.party_id||row.completion.funding_confirmation_party_id&&row.completion.funding_confirmation_party_id!==p.party_id))return null;
 if(p&&p.company_id===row.company_id&&p.source_id===row.id&&p.reference.trim()&&(!row.cash_treasury_id||p.mode==='TREASURY'&&p.treasury_id===row.cash_treasury_id))return p;
 const c=row.completion;
 if(!row.cash_treasury_id&&c.funding_confirmation_status==='OWNER_CONFIRMED_DEFAULT'&&c.funding_confirmation_mode==='CUSTODIAN'&&c.funding_confirmation_scope==='VERIFIED_COMPANY_OUTGOINGS'&&typeof c.funding_confirmation_party_id==='string'&&/^[0-9a-f-]{36}$/i.test(c.funding_confirmation_party_id)&&typeof c.funding_confirmation_reference==='string'&&c.funding_confirmation_reference.trim())return{mode:'CUSTODIAN',party_id:c.funding_confirmation_party_id,treasury_id:null,reference:c.funding_confirmation_reference};
 return null;
}
export function paymentFields(p:{mode:string;party_id:string|null;treasury_id:string|null}|null):Record<string,string>{return p&&p.mode!=='NONE'?{funding_mode:p.mode,paid_by_id:p.party_id??'',treasury_id:p.treasury_id??''}:{};}
export function sourcePaymentMatches(row:SourceRecord,input:Record<string,string|boolean|null>){const p=confirmedSourcePayment(row);return !!p&&input.funding_mode===p.mode&&(p.mode==='CUSTODIAN'?input.paid_by_id===p.party_id&&!input.treasury_id:input.treasury_id===p.treasury_id&&!input.paid_by_id);}
