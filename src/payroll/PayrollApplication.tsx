import PayrollRegisterOutput from './PayrollRegisterOutput';
import PayrollPosting from './PayrollPosting';
import {useEffect,useRef,useState} from 'react';
import {Link} from 'react-router-dom';
import {useAuth} from '../auth/AuthContext';
import {LanguageButton} from '../auth/AuthFrame';
import {useI18n} from '../i18n/I18nContext';
import {getSupabaseClient} from '../lib/supabase';
import {payrollText,type PayrollLabels} from './payrollText';
import {payrollAllowed,payrollRequest,decodeDraft,decodeProfiles,displayPayrollMoney,displayDailySalary,parsePayrollMoney,
 type PayrollProfile,type PayrollProfiles,type PayrollDraft,type PayrollRow,type PayrollAdjustment} from './payrollRepository';
const field='block w-full min-w-0 rounded border border-slate-300 bg-white p-2';
const button='rounded border border-slate-300 px-3 py-2 disabled:opacity-50';
function failure(error:unknown,t:PayrollLabels){return error instanceof Error&&error.message==='STALE'?t.staleError:error instanceof Error&&error.message==='POLICY'?t.policy:t.error;}
export default function PayrollApplication(){
 const {state,signOut,showCompanySelector}=useAuth();const {locale}=useI18n();const t=payrollText[locale];
 if(state.phase!=='TENANT_READY')return null;
 return <div className="min-h-screen bg-slate-50 p-4 sm:p-6"><header className="mx-auto mb-5 flex max-w-6xl flex-wrap items-center justify-between gap-3"><h1 className="text-xl font-semibold">{state.activeTenant.companyName} · {t.title}</h1>
 <div className="flex flex-wrap gap-2"><Link className={button} to="/">{t.back}</Link>{state.memberships.length>1&&<button className={button} onClick={showCompanySelector}>{t.switchCompany}</button>}<LanguageButton/><button className={button} onClick={()=>void signOut()}>{t.signOut}</button></div></header>
 <PayrollContent key={`${state.profile.userId}:${state.activeTenant.companyId}:${state.activeTenant.role}`} userId={state.profile.userId} companyId={state.activeTenant.companyId} role={state.activeTenant.role} companyName={state.activeTenant.companyName}/></div>;
}
export function PayrollContent({userId,companyId,companyName=companyId,role}:{userId:string;companyId:string;companyName?:string;role:string}){
 const {locale}=useI18n();const t=payrollText[locale];const [tab,setTab]=useState<'profiles'|'draft'>('profiles');
 if(!payrollAllowed(role))return <p role="alert">{t.denied}</p>;
 return <main className="mx-auto max-w-6xl space-y-4 rounded-xl border bg-white p-4 sm:p-6"><p>{t.scope}</p><div className="flex gap-2"><button className={button} onClick={()=>setTab('profiles')}>{t.profiles}</button><button className={button} onClick={()=>setTab('draft')}>{t.register}</button></div>
 {tab==='profiles'?<Profiles userId={userId} companyId={companyId} t={t}/>:<Draft userId={userId} companyName={companyName} companyId={companyId} role={role} t={t}/>}</main>;
}
function Profiles({userId,companyId,t}:{userId:string;companyId:string;t:PayrollLabels}){
 const [revision,setRevision]=useState(0);const [load,setLoad]=useState<{revision:number;data?:PayrollProfiles;error?:boolean}|null>(null);
 const data=load?.revision===revision?load.data:undefined;const error=load?.revision===revision&&load.error;
 useEffect(()=>{let current=true;payrollRequest(getSupabaseClient(),userId,'read_payroll_profiles',{target_company_id:companyId},()=>current)
  .then(result=>{const value=decodeProfiles(result,companyId);if(current)setLoad({revision,data:value});}).catch(()=>{if(current)setLoad({revision,error:true});});return()=>{current=false;};},[userId,companyId,revision]);
 const reload=()=>setRevision(v=>v+1);
 return <section className="space-y-4"><p>{t.fullMonth}</p><button className={button} onClick={reload}>{t.reload}</button>{error&&<p role="alert">{t.error}</p>}{!data&&!error&&<p role="status">{t.loading}</p>}
 {data&&<><ProfileForm key={`new:${revision}`} userId={userId} companyId={companyId} data={data} t={t} done={reload}/>{!data.profiles.length&&<p>{t.emptyProfiles}</p>}
 {data.profiles.map(p=><article key={`${p.id}:${p.version}`} className="min-w-0 rounded border p-3"><h2 className="font-semibold"><bdi>{p.payroll_id} · {p.employee_name}</bdi></h2><p><bdi>{displayPayrollMoney(p.monthly_salary_minor)}</bdi> · {p.status==='ACTIVE'?t.active:t.inactive}{p.employee_status!=='ACTIVE'?` · ${t.employeeInactive}`:''}</p><p><bdi>{p.profession} · {p.work_station} · {p.payroll_type} · {p.payment_type}</bdi></p><ProfileForm userId={userId} companyId={companyId} data={data} profile={p} t={t} done={reload}/></article>)}</>}
 </section>;
}
function ProfileForm({userId,companyId,data,profile,t,done}:{userId:string;companyId:string;data:PayrollProfiles;profile?:PayrollProfile;t:PayrollLabels;done:()=>void}){
 const [busy,setBusy]=useState(false);const [error,setError]=useState<string|null>(null);const live=useRef(true);const sending=useRef(false);
 useEffect(()=>{live.current=true;return()=>{live.current=false;};},[]);
 async function save(form:HTMLFormElement){if(sending.current||error)return;const f=new FormData(form);sending.current=true;setBusy(true);
  try{await payrollRequest(getSupabaseClient(),userId,'save_payroll_profile',{target_company_id:companyId,target_employee_id:profile?.employee_id??String(f.get('employee')),
   target_version:profile?.version??0,target_payroll_id:String(f.get('payrollId')).trim(),target_payroll_type:String(f.get('type')).trim(),target_profession:String(f.get('profession')).trim(),
   target_work_station:String(f.get('station')).trim(),target_project_id:String(f.get('project'))||null,target_salary_minor:parsePayrollMoney(String(f.get('salary'))),target_payment_type:String(f.get('payment')).trim(),target_status:String(f.get('status')) as 'ACTIVE'|'INACTIVE'},()=>live.current);if(live.current)done();
  }catch(e){if(live.current)setError(failure(e,t));}finally{sending.current=false;if(live.current)setBusy(false);}}
 return <details><summary>{profile?t.edit:t.create}</summary><form className="mt-3" onSubmit={e=>{e.preventDefault();void save(e.currentTarget);}}><fieldset disabled={busy||!!error} className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
 {!profile&&<label>{t.employee}<select className={field} name="employee" required><option value="">{t.select}</option>{data.employees.filter(e=>!data.profiles.some(p=>p.employee_id===e.id)).map(e=><option key={e.id} value={e.id}>{e.name}</option>)}</select></label>}
 {([['payrollId',t.payrollId,profile?.payroll_id,80],['type',t.type,profile?.payroll_type,100],['profession',t.profession,profile?.profession,200],['station',t.station,profile?.work_station,200],['payment',t.payment,profile?.payment_type,100]] as const).map(([name,label,value,max])=><label key={name}>{label}<input className={field} name={name} defaultValue={value??''} maxLength={max} required/></label>)}
 <label>{t.project}<select className={field} name="project" defaultValue={profile?.default_project_id??''}><option value="">{t.none}</option>{data.projects.map(p=><option key={p.id} value={p.id}>{p.name}</option>)}</select></label>
 <label>{t.salary}<input className={field} name="salary" inputMode="decimal" defaultValue={profile?displayPayrollMoney(profile.monthly_salary_minor):''} required pattern="[0-9]+(\.[0-9]{1,2})?"/></label>
 <label>{t.status}<select className={field} name="status" defaultValue={profile?.status??'ACTIVE'}><option value="ACTIVE">{t.active}</option><option value="INACTIVE">{t.inactive}</option></select></label><button className={button}>{t.save}</button></fieldset>
 {error&&<><p role="alert">{error}</p><button type="button" className={button} onClick={done}>{t.reload}</button></>}</form></details>;
}
function Draft({userId,companyId,companyName,role,t}:{userId:string;companyId:string;companyName:string;role:string;t:PayrollLabels}){
 const [month,setMonth]=useState(()=>new Date().toISOString().slice(0,7));return <section className="space-y-4"><label className="block max-w-xs">{t.month}<input className={field} type="month" value={month} onChange={e=>setMonth(e.target.value)}/></label>
 {/^\d{4}-\d{2}$/.test(month)&&<DraftMonth companyName={companyName} key={month} userId={userId} companyId={companyId} month={`${month}-01`} role={role} t={t}/>}</section>;
}
function DraftMonth({userId,companyId,companyName,month,role,t}:{userId:string;companyId:string;companyName:string;month:string;role:string;t:PayrollLabels}){
 const [revision,setRevision]=useState(0);const [load,setLoad]=useState<{revision:number;data?:PayrollDraft;error?:boolean}|null>(null);
 const [locked,setLocked]=useState(true);const [error,setError]=useState<string|null>(null);const [busy,setBusy]=useState(false);const [checked,setChecked]=useState<number|null>(null);const live=useRef(true);const sending=useRef(false);
 useEffect(()=>{live.current=true;return()=>{live.current=false;};},[]);
 const data=load?.revision===revision?load.data:undefined;const readError=load?.revision===revision&&load.error;
 const reload=()=>{if(live.current){setError(null);setRevision(v=>v+1);}};
 useEffect(()=>{let current=true;payrollRequest(getSupabaseClient(),userId,'read_payroll_draft',{target_company_id:companyId,target_month:month},()=>current)
  .then(result=>{const value=decodeDraft(result,companyId);if(current)setLoad({revision,data:value});}).catch(()=>{if(current)setLoad({revision,error:true});});return()=>{current=false;};},[userId,companyId,month,revision]);
 async function action(review:boolean){if(!data||sending.current||error)return;sending.current=true;setBusy(true);
  try{if(review){if(!data.period||checked!==revision)return;await payrollRequest(getSupabaseClient(),userId,'review_payroll_draft',{target_company_id:companyId,target_period_id:data.period.id,target_version:data.period.version},()=>live.current);}
   else await payrollRequest(getSupabaseClient(),userId,'refresh_payroll_draft',{target_company_id:companyId,target_month:month,target_version:data.period?.version??0},()=>live.current);
   reload();}catch(e){if(live.current)setError(failure(e,t));}finally{sending.current=false;if(live.current)setBusy(false);}}
 return <div className="space-y-4"><button className={button} onClick={reload}>{t.reload}</button>{(error||readError)&&<p role="alert">{error??t.error}</p>}{!data&&!readError&&<p role="status">{t.loading}</p>}
 {data&&<><fieldset disabled={locked} hidden={locked} className="space-y-4"><p role="status">{data.attendance_review_valid?t.attendanceValid:t.attendanceRequired}</p><Link className="underline" to="/attendance">{t.attendance}</Link><p>{t.refreshHint}</p>
 <button className={button} disabled={busy||!!error||!data.attendance_review_valid} onClick={()=>void action(false)}>{t.generate}</button>
 {!data.period?<p>{t.noDraft}</p>:<><p role="status" className={data.stale?'font-semibold text-amber-900':''}>{data.stale?t.stale:data.review_valid?t.reviewed:t.fresh}</p><p>{t.calendar}: {data.period.calendar_days} · DRAFT</p>
 <PayrollRegisterOutput userId={userId} companyId={companyId} companyName={companyName} role={role} month={month} source={{kind:"DRAFT",id:data.period.id,version:data.period.version}} disabled={data.stale||!data.review_valid||!data.attendance_review_valid}/>
 {!data.rows.some(r=>r.included)&&<p>{t.emptyRows}</p>}
 {data.rows.map(row=><DraftRow key={`${row.id}:${revision}`} userId={userId} companyId={companyId} row={row} adjustments={data.adjustments.filter(a=>a.row_id===row.id)} t={t} done={reload}/>)}
 <label className="flex gap-2"><input type="checkbox" checked={checked===revision} disabled={data.stale||!data.attendance_review_valid} onChange={e=>setChecked(e.target.checked?revision:null)}/>{t.reviewConfirm}</label>
 <button className={button} disabled={busy||!!error||checked!==revision||data.stale||!data.attendance_review_valid} onClick={()=>void action(true)}>{t.review}</button>
 {data.review_valid&&data.period.reviewed_by&&<p className="break-all">{t.provenance}: {data.period.reviewed_by} · {data.period.reviewed_at}</p>}</>}
 </fieldset><PayrollPosting companyName={companyName} onLocked={setLocked} key={revision} userId={userId} companyId={companyId} month={month} role={role} draft={data} done={reload}/>
 </>}
 </div>;
}
function DraftRow({userId,companyId,row,adjustments,t,done}:{userId:string;companyId:string;row:PayrollRow;adjustments:PayrollAdjustment[];t:PayrollLabels;done:()=>void}){
 return <article className="min-w-0 space-y-3 rounded border p-4"><h2 className="font-semibold"><bdi>{row.payroll_id} · {row.employee_name}</bdi>{!row.included&&` · ${t.excluded}`}</h2>
 <p><bdi>{row.payroll_type} · {row.profession} · {row.work_station} · {row.payment_type}</bdi></p>
 <dl className="grid min-w-0 grid-cols-2 gap-3 lg:grid-cols-4">{([
 [t.salary,displayPayrollMoney(row.monthly_salary_minor)],[t.daily,`≈ ${displayDailySalary(row.monthly_salary_minor,row.calendar_days)}`],
 [t.units,String(row.absence_half_units)],[t.absenceDays,String(row.absence_half_units/2)],[t.payableDays,String(row.calendar_days-row.absence_half_units/2)],
 [t.absenceDeduction,displayPayrollMoney(row.absence_deduction_minor)],[t.additions,displayPayrollMoney(row.additions_minor)],[t.deductions,displayPayrollMoney(row.deductions_minor)],
 [t.gross,displayPayrollMoney(row.gross_salary_minor)],[t.net,displayPayrollMoney(row.net_salary_minor)]
 ]).map(([label,value])=><div key={label} className="min-w-0"><dt className="text-sm text-slate-500">{label}</dt><dd className="break-all font-medium"><bdi>{value}</bdi></dd></div>)}</dl>
 <details><summary>{t.adjustments}</summary><p>{t.adjustmentHint}</p>{adjustments.map(a=><div key={`${a.id}:${a.version}`} className="my-3 rounded border p-3"><p><bdi>{displayPayrollMoney(a.amount_minor)} · {a.reason}</bdi> · {a.kind==='ADDITION'?t.addition:t.deduction} · {a.voided?t.voided:''}</p><p className="break-all text-xs">{t.provenance}: {a.created_by} · {a.created_at} / {a.updated_by} · {a.updated_at}</p>{a.change_reason&&<p>{a.change_reason}</p>}
 <AdjustmentForm userId={userId} companyId={companyId} row={row} adjustment={a} t={t} done={done}/></div>)}
 {row.included&&<AdjustmentForm userId={userId} companyId={companyId} row={row} t={t} done={done}/>}</details></article>;
}
function AdjustmentForm({userId,companyId,row,adjustment,t,done}:{userId:string;companyId:string;row:PayrollRow;adjustment?:PayrollAdjustment;t:PayrollLabels;done:()=>void}){
 const [id]=useState(()=>adjustment?.id??crypto.randomUUID());const [busy,setBusy]=useState(false);const [error,setError]=useState<string|null>(null);const live=useRef(true);const sending=useRef(false);const formRef=useRef<HTMLFormElement>(null);
 useEffect(()=>{live.current=true;return()=>{live.current=false;};},[]);
 async function save(form:HTMLFormElement,voided:boolean){if(sending.current||error||!form.reportValidity())return;const f=new FormData(form);sending.current=true;setBusy(true);
  try{const amount=parsePayrollMoney(String(f.get('amount')));if(BigInt(amount)===0n)throw new Error('POLICY');await payrollRequest(getSupabaseClient(),userId,'save_payroll_draft_adjustment',{
   target_company_id:companyId,target_row_id:row.id,target_id:id,target_version:adjustment?.version??0,target_kind:String(f.get('kind')),target_amount_minor:amount,
   target_reason:String(f.get('reason')).trim(),target_void:voided,target_change_reason:String(f.get('changeReason')??'').trim()||null},()=>live.current);if(live.current)done();
  }catch(e){if(live.current)setError(failure(e,t));}finally{sending.current=false;if(live.current)setBusy(false);}}
 return <form ref={formRef} className="mt-3" onSubmit={e=>{e.preventDefault();void save(e.currentTarget,false);}}><fieldset disabled={busy||!!error} className="grid gap-3 sm:grid-cols-2">
 <label>{t.adjustments}<select className={field} name="kind" defaultValue={adjustment?.kind??'ADDITION'}><option value="ADDITION">{t.addition}</option><option value="DEDUCTION">{t.deduction}</option></select></label>
 <label>{t.amount}<input className={field} name="amount" inputMode="decimal" required defaultValue={adjustment?displayPayrollMoney(adjustment.amount_minor):''} pattern="[0-9]+(\.[0-9]{1,2})?"/></label>
 <label>{t.reason}<input className={field} name="reason" required maxLength={1000} defaultValue={adjustment?.reason??''}/></label>
 {adjustment&&<label>{t.changeReason}<input className={field} name="changeReason" required maxLength={1000}/></label>}
 <button className={button}>{adjustment?t.saveAdjustment:t.add}</button>{adjustment&&!adjustment.voided&&<button className={button} type="button" onClick={()=>{if(formRef.current)void save(formRef.current,true);}}>{t.void}</button>}</fieldset>
 {error&&<><p role="alert">{error}</p><button type="button" className={button} onClick={done}>{t.reload}</button></>}</form>;
}
