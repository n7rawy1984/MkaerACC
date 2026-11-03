import {useEffect,useRef,useState} from 'react';
import {useAuth} from '../auth/AuthContext';
import {useI18n} from '../i18n/I18nContext';
import {getSupabaseClient} from '../lib/supabase';
import {Field,inputClassName} from '../components/ui/Field';
import {activateProject,readProjectActivation,type ActivationAttempt,type ActivationError,type ActivationEvent} from './projectActivationRepository';
import type {ProductionProjectSummary} from './masterTypes';
const text={
 en:{activate:'Activate project',reason:'Activation reason',confirm:'Confirm activation',cancel:'Cancel',help:'Change this project from Planning to Active. Existing records and financial balances are unchanged.',loading:'Checking activation history…',unavailable:'Project activation is unavailable. Refresh or contact your administrator.',pending:'Confirming activation…',confirmed:'Project activation confirmed.',refresh:'Refresh project',retry:'Check or retry this activation',conflict:'Project details or status changed. Refresh before continuing.',denied:'You no longer have permission to activate this project.',invalid:'Review the project details and enter a reason of 1–500 characters.',uncertain:'The result is not confirmed. Check the same activation request before starting another action.',history:'Activation history',on:'Activated on',by:'User reference',refreshNeeded:'Activation is confirmed, but the project list could not be refreshed.'},
 ar:{activate:'تفعيل المشروع',reason:'سبب التفعيل',confirm:'تأكيد التفعيل',cancel:'إلغاء',help:'تغيير حالة المشروع من التخطيط إلى نشط. لا تتغير السجلات القائمة أو الأرصدة المالية.',loading:'جارٍ التحقق من سجل التفعيل…',unavailable:'تفعيل المشروع غير متاح. حدّث البيانات أو تواصل مع المسؤول.',pending:'جارٍ تأكيد التفعيل…',confirmed:'تم تأكيد تفعيل المشروع.',refresh:'تحديث المشروع',retry:'التحقق من طلب التفعيل أو إعادة محاولته',conflict:'تغيرت تفاصيل المشروع أو حالته. حدّث البيانات قبل المتابعة.',denied:'لم تعد لديك صلاحية تفعيل هذا المشروع.',invalid:'راجع تفاصيل المشروع وأدخل سببًا من حرف واحد إلى 500 حرف.',uncertain:'لم تتأكد النتيجة. تحقق من طلب التفعيل نفسه قبل بدء إجراء آخر.',history:'سجل التفعيل',on:'تاريخ التفعيل',by:'مرجع المستخدم',refreshNeeded:'تم تأكيد التفعيل وتعذر تحديث قائمة المشروعات.'},
};
/** Mounted per actor/Company/Project. Commands derive authority again in PostgreSQL. */
export function ProjectActivation({project,onRefresh,disabled=false}:{project:ProductionProjectSummary;onRefresh:()=>Promise<boolean>;disabled?:boolean}){
 const {state}=useAuth(),{locale}=useI18n(),t=text[locale],client=getSupabaseClient();
 const actor=state.phase==='TENANT_READY'?state.profile.userId:'';
 const company=state.phase==='TENANT_READY'?state.activeTenant.companyId:'';
 const canActivate=state.phase==='TENANT_READY'&&state.activeTenant.role==='ACCOUNTING_ADMIN'&&company===project.companyId;
 const [historyRevision,setHistoryRevision]=useState(0);
 const [history,setHistory]=useState<ActivationEvent|null>(null),[loaded,setLoaded]=useState(false),[available,setAvailable]=useState(true),[open,setOpen]=useState(false),[reason,setReason]=useState(''),[attempt,setAttempt]=useState<ActivationAttempt|null>(null),[busy,setBusy]=useState(false),[error,setError]=useState<ActivationError|null>(null),[confirmed,setConfirmed]=useState(false),[refreshFailed,setRefreshFailed]=useState(false);
 const generation=useRef(0),lock=useRef(false),trigger=useRef<HTMLButtonElement>(null),input=useRef<HTMLTextAreaElement>(null),restoreFocus=useRef(false),feedback=useRef<HTMLParagraphElement>(null);
 useEffect(()=>{
  const invalidate=()=>{generation.current++;};
  invalidate();
  const {data}=client.auth.onAuthStateChange((_event,session)=>{if(!session||session.user.id!==actor){generation.current++;lock.current=false;setBusy(false);setAvailable(false);setError('denied');}});
  return()=>{invalidate();data.subscription.unsubscribe();};
 },[client,company,actor,project.id]);
 useEffect(()=>{const g=generation.current;let live=true;
  void readProjectActivation(client,company,project.id).then(r=>{if(live&&g===generation.current){setAvailable(r.ok);setLoaded(true);if(r.ok)setHistory(r.event);}});
  return()=>{live=false;};
 },[client,company,actor,project.id,project.updatedAt,historyRevision]);
 useEffect(()=>{if(open)input.current?.focus();else if(restoreFocus.current){trigger.current?.focus();restoreFocus.current=false;}},[open]);
 useEffect(()=>{if(error||confirmed)feedback.current?.focus();},[error,confirmed]);
 const close=()=>{restoreFocus.current=true;setOpen(false);};
 const refresh=async()=>{const g=generation.current;const ok=await onRefresh();if(g!==generation.current)return;if(ok){setRefreshFailed(false);setError(null);setHistoryRevision(v=>v+1);}else setRefreshFailed(true);};
 const send=async(request:ActivationAttempt)=>{
  if(lock.current||disabled||!canActivate)return;lock.current=true;setBusy(true);setError(null);const g=generation.current;
  const valid=async()=>{const {data,error}=await client.auth.getSession();return g===generation.current&&!error&&data.session?.user.id===actor;};
  try{
   if(!await valid()){if(g===generation.current){setError('denied');setAttempt(null);setAvailable(false);}return;}
   const result=await activateProject(client,request);if(!await valid())return;
   if(!result.ok){setError(result.error);if(result.error!=='uncertain')setAttempt(null);if(result.error==='unavailable'){setAvailable(false);setOpen(false);}return;}
   setConfirmed(true);setOpen(false);await refresh();
  }catch{if(g===generation.current)setError('uncertain');}
  finally{lock.current=false;if(g===generation.current)setBusy(false);}
 };
 if(!actor||company!==project.companyId)return null;
 return <div className="mt-3 space-y-3">
  {history&&<details><summary>{t.history}</summary><dl className="suite-detail-panel"><div><dt>{t.on}</dt><dd><time dateTime={history.activated_at}>{new Date(history.activated_at).toLocaleString(locale)}</time></dd></div><div><dt>{t.reason}</dt><dd className="whitespace-pre-wrap"><bdi>{history.reason}</bdi></dd></div><div><dt>{t.by}</dt><dd><bdi dir="ltr">{history.actor_id}</bdi></dd></div></dl></details>}
  {canActivate&&project.status==='PLANNING'&&!confirmed&&<>
   {!loaded&&<p role="status">{t.loading}</p>}
   {!available&&<p role="status">{t.unavailable}</p>}
   {!open&&!attempt&&<button ref={trigger} type="button" disabled={disabled||!loaded||!available||busy} onClick={()=>setOpen(true)}>{t.activate}</button>}
   {open&&<form aria-label={t.activate} onSubmit={e=>{e.preventDefault();const normalized=reason.trim();if(disabled||busy||attempt)return;if(!normalized||[...normalized].length>500){setError('invalid');return;}const request={companyId:company,projectId:project.id,expectedUpdatedAt:project.updatedAt,requestId:crypto.randomUUID(),reason:normalized};setAttempt(request);void send(request);}}>
    <p>{t.help}</p><Field label={t.reason}><textarea ref={input} className={inputClassName} required maxLength={500} value={reason} disabled={!!attempt||busy||disabled} onChange={e=>setReason(e.target.value)}/></Field>
    <button type="submit" disabled={disabled||busy||!!attempt}>{t.confirm}</button>{!attempt&&<button type="button" onClick={close}>{t.cancel}</button>}
   </form>}
  </>}
  {busy&&<p role="status">{t.pending}</p>}
  {confirmed&&<p ref={feedback} tabIndex={-1} role="status">{refreshFailed?t.refreshNeeded:t.confirmed}</p>}
  {error&&<p ref={feedback} tabIndex={-1} role="alert">{t[error]}</p>}
  {attempt&&!confirmed&&error==='uncertain'&&<button type="button" disabled={busy||disabled} onClick={()=>void send(attempt)}>{t.retry}</button>}
  {(refreshFailed||error==='conflict'||!available)&&canActivate&&<button type="button" disabled={busy||disabled} onClick={()=>void refresh()}>{t.refresh}</button>}
 </div>;
}
