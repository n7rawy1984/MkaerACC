import {useEffect,useState} from 'react';
import type {SupabaseClient} from '@supabase/supabase-js';
import {useAuth} from '../auth/AuthContext';
import {getSupabaseClient} from '../lib/supabase';
export {confirmedSourcePayment,paymentFields,sourcePaymentMatches} from './paymentPolicy';
export type {PaymentPreference,SourcePaymentPolicy} from './paymentPolicy';
import type {PaymentPreference} from './paymentPolicy';
export async function readPaymentPreferences(client:SupabaseClient,cid:string){const r=await client.rpc('read_payment_preferences',{cid});if(r.error||!Array.isArray(r.data)||r.data.some((p:PaymentPreference)=>p.company_id!==cid))throw Error('Payment preferences unavailable');return r.data as PaymentPreference[];}
export function usePaymentPreferences(){const {state}=useAuth(),cid=state.phase==='TENANT_READY'?state.activeTenant.companyId:'',user=state.phase==='TENANT_READY'?state.profile.userId:'',role=state.phase==='TENANT_READY'?state.activeTenant.role:'';const key=cid+user+role;const [read,setRead]=useState<{key:string;rows:PaymentPreference[];available:boolean}>({key:'',rows:[],available:false});
 useEffect(()=>{if(!['ACCOUNTANT','ACCOUNTING_ADMIN'].includes(role))return;let live=true;const c=getSupabaseClient(),{data}=c.auth.onAuthStateChange((_e,s)=>{if(!s||s.user.id!==user){live=false;setRead({key,rows:[],available:false});}});void readPaymentPreferences(c as unknown as SupabaseClient,cid).then(rows=>{if(live)setRead({key,rows,available:true});}).catch(()=>{if(live)setRead({key,rows:[],available:false});});return()=>{live=false;data.subscription.unsubscribe();};},[key,cid,user,role]);return read.key===key?read:{key,rows:[],available:false};}
