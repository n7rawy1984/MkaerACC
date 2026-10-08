import {useEffect,useRef,useState} from 'react';
import {createPortal,flushSync} from 'react-dom';
import {useAuth} from '../auth/AuthContext';
import {useI18n} from '../i18n/I18nContext';
import {getSupabaseClient} from '../lib/supabase';
import {financialWorkbook,displayReportCell,type FinancialReport} from './reportExport';
import './financialReport.css';
export function ReportExport({build,disabled=false}:{build:()=>FinancialReport|Promise<FinancialReport>;disabled?:boolean}){
 const {state}=useAuth(),{locale}=useI18n(),ar=locale==='ar';const [report,setReport]=useState<FinancialReport|null>(null),[busy,setBusy]=useState(false),[error,setError]=useState('');const live=useRef(true),lock=useRef(false);
 const user=state.phase==='TENANT_READY'?state.profile.userId:'',company=state.phase==='TENANT_READY'?state.activeTenant.companyId:'';
 const context=useRef('');context.current=user+':'+company+':'+locale;
 useEffect(()=>{live.current=true;setReport(null);return()=>{live.current=false;};},[user,company,locale]);
 async function act(kind:'excel'|'pdf'){
  if(lock.current||disabled||!user)return;const started=context.current,valid=()=>live.current&&context.current===started;lock.current=true;setBusy(true);setError('');
  try{const before=await getSupabaseClient().auth.getSession();if(!valid()||before.error||before.data.session?.user.id!==user)throw Error('Session changed');const next=await build();if(!valid())return;
   if(kind==='excel'){const blob=await financialWorkbook(next);const after=await getSupabaseClient().auth.getSession();if(!valid()||after.error||after.data.session?.user.id!==user)throw Error('Session changed');const url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download=next.filename+'.xlsx';a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);}
   else{const after=await getSupabaseClient().auth.getSession();if(!valid()||after.error||after.data.session?.user.id!==user)throw Error('Session changed');flushSync(()=>setReport(next));await document.fonts.ready;}
  }catch(e){if(valid())setError(ar?'تعذر التصدير. تحقق من الصلاحية وحدّث السجلات.':e instanceof Error?e.message:'Export failed. Refresh the records and try again.');}
  finally{lock.current=false;if(valid())setBusy(false);}
 }
 const button='inline-flex min-h-10 items-center justify-center rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm font-medium disabled:opacity-50';
 return <div className="flex min-w-0 flex-wrap items-center gap-2"><button className={button} disabled={disabled||busy} onClick={()=>void act('excel')}>{ar?'تصدير Excel':'Export Excel'}</button><button className={button} disabled={disabled||busy} onClick={()=>void act('pdf')}>{ar?'تصدير PDF':'Export PDF'}</button>{error&&<p role="alert" className="text-sm text-red-800">{error}</p>}
 {report&&createPortal(<div className="financial-report-output" dir={report.locale==='ar'?'rtl':'ltr'} role="dialog" aria-modal="true" aria-label={report.title}><div className="financial-report-controls"><p>{ar?'اختر حفظ بصيغة PDF في مربع الطباعة.':'Choose Save as PDF in the print dialog.'}</p><button onClick={()=>void document.fonts.ready.then(()=>{if(live.current)window.print();})}>{ar?'طباعة / حفظ PDF':'Print / Save PDF'}</button><button onClick={()=>setReport(null)}>{ar?'إغلاق':'Close'}</button></div><article className="financial-report-print"><header><h1>{report.company}</h1><h2>{report.title}</h2><p>{report.period}</p><p>{ar?'تاريخ الإنشاء':'Generated'}: <bdi dir="ltr">{report.generated}</bdi></p></header><p className="financial-report-note">{report.note}</p>{report.sections.map((section,i)=><section key={i}><h3>{section.title}</h3><table><thead><tr>{section.headers.map((h,j)=><th key={j}>{h}</th>)}</tr></thead><tbody>{section.rows.map((row,j)=><tr key={j}>{row.map((cell,k)=><td key={k} className={typeof cell==='object'&&cell!==null?'money':''}><bdi dir={typeof cell==='object'||typeof cell==='number'?'ltr':'auto'}>{displayReportCell(cell)}</bdi></td>)}</tr>)}</tbody></table></section>)}<footer>{report.company} · {report.title} · AED</footer></article></div>,document.body)}
 </div>;
}
