import {useCallback,useEffect,useRef,useState,type FormEvent} from 'react';
import {useAuth} from '../auth/AuthContext';
import {useI18n} from '../i18n/I18nContext';
import {getSupabaseClient} from '../lib/supabase';
import {useProductionMasterData} from './productionMasterDataContext';
import {controlDefinitions,controlState,readSetupIntent,setupSlot,uuid,type SetupIntent} from './companyAccountingSetup';
import {eligibleTreasuryAccounts} from './treasuryMasterRepository';
const field='mt-1 block w-full rounded-lg border border-slate-300 bg-white px-3 py-2 text-slate-900';
const button='rounded-lg border px-3 py-2 text-sm disabled:opacity-50';
export function CompanyAccountingSetup({mode='CONTROL'}:{mode?:'CONTROL'|'TREASURY'}) {
 const {state}=useAuth();
 if(state.phase!=='TENANT_READY'||!['ACCOUNTING_ADMIN','ACCOUNTANT','MANAGEMENT_VIEWER'].includes(state.activeTenant.role))return null;
 return <SetupPanel key={state.profile.userId+state.activeTenant.companyId+state.activeTenant.role+mode} mode={mode} user={state.profile.userId} company={state.activeTenant.companyId} writer={state.activeTenant.role==='ACCOUNTING_ADMIN'}/>;
}
function SetupPanel({mode,user,company,writer}:{mode:'CONTROL'|'TREASURY';user:string;company:string;writer:boolean}) {
 const {locale}=useI18n(),ar=locale==='ar',master=useProductionMasterData();
 const title=mode==='CONTROL'?(ar?'إعداد الحسابات الرقابية':'Control account setup'):(ar?'إضافة خزينة نقدية أو بنكية':'Additional Cash or Bank Treasury');
 const [initial]=useState(()=>{try{return {intent:readSetupIntent(sessionStorage,user,company,mode),recovery:false};}catch{return {intent:null,recovery:true};}});
 const [intent,setIntent]=useState<SetupIntent|null>(initial.intent),[message,setMessage]=useState(''),[busy,setBusy]=useState(false),recovery=initial.recovery;
 const [key,setKey]=useState('CUSTODY_ADVANCE'),[accountMode,setAccountMode]=useState('NEW'),[type,setType]=useState('CASH');
 const [events,setEvents]=useState<{id:string;action:string;approval_reference:string;created_at:string}[]>([]);
 const alive=useRef(true),lock=useRef(false);const slot=setupSlot(user,company,mode);
 const loadHistory=useCallback(async()=>{const r=await getSupabaseClient().from('company_accounting_setup_events' as never).select('id,action,approval_reference,created_at').eq('company_id',company).order('created_at',{ascending:false}).limit(20);if(alive.current){if(r.error)setMessage(ar?'تعذر تحميل سجل الإعداد؛ تحقق من تفعيل الإصدار.':'Setup history unavailable; check release activation.');else setEvents(r.data as unknown as typeof events);}},[ar,company]);
 useEffect(()=>{alive.current=true;queueMicrotask(()=>{if(alive.current)void loadHistory();});return()=>{alive.current=false;};},[loadHistory]); // Actor-scoped remount also clears all displayed setup state.
 const refresh=async()=>{if(!await master.refreshAccounts()||!await master.refreshTreasuryAccounts())throw Error('refresh');await loadHistory();};
 const send=async(a:SetupIntent,first:boolean)=>{
  if(lock.current)return;lock.current=true;setBusy(true);setMessage('');
  try {
   sessionStorage.setItem(slot,JSON.stringify(a));
   const c=getSupabaseClient(),s=await c.auth.getSession();if(!alive.current)return;if(s.error||s.data.session?.user.id!==user)throw Error('session');
   if(!a.receipt){
    const r=await c.rpc('configure_company_accounting' as never,{target_company_id:company,target_request_id:a.request,target_action:mode,business_input:a.input} as never);
    if(!alive.current)return;
    if(r.error){if(first&&['22023','23514','23505','23503','42501','40001'].includes(r.error.code)){sessionStorage.removeItem(slot);setIntent(null);throw Error('rejected');}throw Error('uncertain');}
    const result=r.data as unknown as {id:string;configured:boolean};if(!result||!uuid(result.id)||result.configured!==true)throw Error('uncertain');
    a={...a,receipt:result.id};sessionStorage.setItem(slot,JSON.stringify(a));setIntent(a);
   }
   await refresh();if(!alive.current)return;sessionStorage.removeItem(slot);setIntent(null);setMessage(ar?'تم اعتماد الإعداد دون إنشاء حركة مالية.':'Setup confirmed. No financial movement created.');
  }catch(e){if(alive.current)setMessage(e instanceof Error&&e.message==='rejected'?(ar?'رُفض الإعداد. تحقق من البيانات والصلاحية والحساب الحالي؛ حدّث قبل المحاولة.':'Setup rejected. Check inputs, authority and current account; refresh before retrying.'):ar?'النتيجة غير مؤكدة أو تعذر التحديث. أعد نفس الطلب؛ لا تنشئ طلبًا بديلًا.':'Outcome or refresh unresolved. Retry the same request; do not create a replacement.');}
  finally{lock.current=false;if(alive.current)setBusy(false);}
 };
 if(master.phase!=='READY')return null;
 const definition=controlDefinitions.find(d=>d[0]===key)!,state=controlState(master.accounts,definition);
 const candidates=mode==='TREASURY'?eligibleTreasuryAccounts(master.accounts,master.treasuryAccounts,company):master.accounts.filter(a=>a.companyId===company&&a.status==='ACTIVE'&&!a.systemKey&&a.accountType===definition[1]&&a.requiresParty===definition[2]);
 const label=(en:string,arabic:string)=>ar?arabic:en;
 const input=(name:string,en:string,arabic:string,max=200)=><label>{label(en,arabic)}<input aria-label={label(en,arabic)} className={field} name={name} required maxLength={max}/></label>;
 const submit=(e:FormEvent<HTMLFormElement>)=>{e.preventDefault();const input=Object.fromEntries([...new FormData(e.currentTarget)].map(([k,v])=>[k,String(v).trim()]).filter(([,v])=>v));const a:SetupIntent={user,company,action:mode,request:crypto.randomUUID(),input};setIntent(a);void send(a,true);};
 return <section className="my-4 min-w-0 space-y-3 rounded-lg border p-4" aria-label={title}>
  <h3 className="font-semibold">{title}</h3>
  <p className="text-sm">{label('Approve actual account purpose. Existing mappings and balances are preserved. Used accounts cannot be repurposed.','اعتمد الغرض الفعلي للحساب. تُحفظ الخرائط والأرصدة الحالية، ولا يُعاد تخصيص حساب مستخدم.')}</p>
  {mode==='CONTROL'&&<ul className="grid gap-2 text-sm sm:grid-cols-2">{controlDefinitions.map(d=><li key={d[0]}>{d[ar?4:3]}: {({READY:label('Ready','جاهز'),MISSING:label('Missing setup','إعداد ناقص'),INVALID:label('Invalid mapping — controlled review required','ربط غير صالح — يتطلب مراجعة مضبوطة')})[controlState(master.accounts,d)]}</li>)}</ul>}
  {recovery&&<p role="alert">{label('Saved request is invalid. Contact support to review it before making another setup request.','الطلب المحفوظ غير صالح. راجع الدعم قبل إنشاء طلب إعداد آخر.')}</p>}
  {message&&<p role="status">{message}</p>}
  {busy&&<p role="status">{label('Confirming setup…','جارٍ اعتماد الإعداد…')}</p>}
  {writer&&intent?<div className="space-y-2"><p>{label('Pending request','طلب قيد التأكيد')}: <bdi>{intent.request}</bdi> · {intent.input.name||intent.input.key}</p><button className={button} disabled={busy} onClick={()=>void send(intent,false)}>{label('Retry / refresh same request','إعادة الطلب نفسه / تحديث')}</button></div>:writer&&!recovery&&<form onSubmit={submit}><fieldset disabled={busy} className="grid min-w-0 gap-3 sm:grid-cols-2">
   {mode==='CONTROL'?<label>{label('Control account','الحساب الرقابي')}<select aria-label={label("Control account","الحساب الرقابي")} className={field} name="key" value={key} onChange={e=>setKey(e.target.value)}>{controlDefinitions.map(d=><option value={d[0]} key={d[0]}>{d[ar?4:3]}</option>)}</select></label>:<><label>{label('Treasury type','نوع الخزينة')}<select aria-label={label("Treasury type","نوع الخزينة")} className={field} name="type" value={type} onChange={e=>setType(e.target.value)}><option value="CASH">{label('Cash','نقدية')}</option><option value="BANK">{label('Bank','بنكية')}</option></select></label>{input('code','Treasury code','رمز الخزينة',50)}{input('name','Treasury name','اسم الخزينة')}{type==='BANK'&&<>{input('bank_name','Bank name','اسم البنك')}{input('account_reference','Bank account reference','مرجع الحساب البنكي')}</>}</>}
   <label>{label('GL account selection','اختيار حساب الأستاذ')}<select aria-label={label("GL account selection","اختيار حساب الأستاذ")} className={field} value={accountMode} onChange={e=>setAccountMode(e.target.value)}><option value="NEW">{label('Create approved account','إنشاء حساب معتمد')}</option><option value="EXISTING">{label('Adopt unused eligible account','اعتماد حساب مؤهل غير مستخدم')}</option></select></label>
   {accountMode==='NEW'?<>{input(mode==='CONTROL'?'code':'gl_code','GL account code','رمز حساب الأستاذ',50)}{input(mode==='CONTROL'?'name':'gl_name','GL account name','اسم حساب الأستاذ')}</>:<label>{label('Eligible account — usage checked on confirmation','الحساب المؤهل — يُفحص استخدامه عند الاعتماد')}<select aria-label={label("Eligible account — usage checked on confirmation","الحساب المؤهل — يُفحص استخدامه عند الاعتماد")} required className={field} name={mode==='CONTROL'?'account_id':'gl_account_id'} defaultValue=""><option value="">—</option>{candidates.map(a=><option key={a.id} value={a.id}>{a.code} · {a.name}</option>)}</select></label>}
   {input('approval','Approval / evidence reference','مرجع الاعتماد / الإثبات',1000)}
   <label className="flex items-start gap-2 sm:col-span-2"><input type="checkbox" required/>{label('I approve this purpose and confirm no opening balance or money transfer is requested.','أعتمد الغرض وأؤكد عدم طلب رصيد افتتاحي أو تحويل مالي.')}</label>
   <button className={button} disabled={mode==='CONTROL'&&state!=='MISSING'}>{label('Confirm setup','اعتماد الإعداد')}</button>
  </fieldset></form>}
  <button className={button} disabled={busy||!!intent} onClick={()=>void refresh().catch(()=>setMessage(label('Refresh failed.','تعذر التحديث.')))}>{label('Refresh configuration','تحديث الإعداد')}</button>
  {!!events.length&&<details><summary>{label('Setup audit history','سجل تدقيق الإعداد')}</summary><ul className="space-y-2 break-words text-sm">{events.map(e=><li key={e.id}><bdi>{e.created_at}</bdi> · {e.action==='CONTROL'?label('Control mapping','ربط حساب رقابي'):label('Treasury','خزينة')} · {e.approval_reference} · <bdi>{e.id}</bdi></li>)}</ul></details>}
 </section>;
}
