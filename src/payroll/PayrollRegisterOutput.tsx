import { useTenantSettings } from "../tenant/TenantSettingsContext";
import { TenantBrandMark } from "../tenant/TenantBrandMark";
import {useEffect,useRef,useState} from 'react';
import {createPortal,flushSync} from 'react-dom';
import {useI18n} from '../i18n/I18nContext';
import {payrollAllowed} from './payrollRepository';
import {readPayrollRegister} from './payrollRegisterRepository';
import {registerText,type PayrollRegister,type RegisterContext,type RegisterSource} from './payrollRegister';
import {registerWorkbook} from './payrollRegisterXlsx';
import './payrollRegister.css';
export default function PayrollRegisterOutput(props:RegisterContext&{source:RegisterSource;disabled?:boolean}){
 const {locale}=useI18n();
 return <Output key={`${props.userId}:${props.companyId}:${props.role}:${props.month}:${props.source.kind}:${props.source.id}:${props.source.kind==='DRAFT'?props.source.version:''}:${locale}`} {...props} locale={locale}/>;
}
function Output({source,disabled,locale,...context}:RegisterContext&{source:RegisterSource;disabled?:boolean;locale:'en'|'ar'}){
 const branding = useTenantSettings();
 const [register,setRegister]=useState<PayrollRegister|null>(null),[busy,setBusy]=useState(false),[error,setError]=useState(false);
 const live=useRef(false),sending=useRef(false);const t=registerText[locale];
 useEffect(()=>{live.current=true;return()=>{live.current=false;};},[]);
 if(!payrollAllowed(context.role))return null;
 async function act(action:'excel'|'preview'|'print'){
  if(sending.current||disabled)return;sending.current=true;setBusy(true);setError(false);
  try{
   const fresh=await readPayrollRegister(context,source,locale,()=>live.current);
   if(action==='excel'){
    const blob=await registerWorkbook(fresh);if(!live.current)return;
    const url=URL.createObjectURL(blob),a=document.createElement('a');a.href=url;a.download=fresh.filename;a.click();setTimeout(()=>URL.revokeObjectURL(url),1000);
   }else{
    flushSync(()=>setRegister(fresh));
    if(action==='print'){await document.fonts.ready;if(live.current)window.print();}
   }
  }catch{if(live.current){setRegister(null);setError(true);}}
  finally{sending.current=false;if(live.current)setBusy(false);}
 }
 return <div className="flex flex-wrap gap-2"><button type="button" className="rounded border px-3 py-2 disabled:opacity-50" disabled={busy||disabled} onClick={()=>void act('excel')}>{t.excel}</button><button type="button" className="rounded border px-3 py-2 disabled:opacity-50" disabled={busy||disabled} onClick={()=>void act('preview')}>{t.preview}</button>{error&&<p role="alert">{t.error}</p>}
 {register&&createPortal(<div className="payroll-register-output" dir={locale==='ar'?'rtl':'ltr'} role="dialog" aria-modal="true" aria-label={t.title}><div className="payroll-register-controls"><button disabled={busy} onClick={()=>void act('print')}>{t.print}</button><button disabled={busy} onClick={()=>setRegister(null)}>{t.close}</button></div><article className="payroll-register-print"><div className="payroll-register-brand">{branding.phase === "READY" && <><TenantBrandMark logoUrl={branding.settings.logoUrl} className="h-10 w-16"/><bdi>{branding.settings.effectiveDisplayName}</bdi></>}<h1>{t.title}</h1></div><p><bdi>{register.company}</bdi> · <bdi dir="ltr">{register.month}</bdi> · {register.status}</p><p className="payroll-register-reference"><bdi dir="ltr">{register.id}</bdi></p><table><thead><tr>{t.columns.map(c=><th key={c} scope="col">{c}</th>)}</tr></thead><tbody>{register.rows.map((r,i)=><tr key={i}>{r.map((v,j)=><td key={j}><bdi dir={j===1||j>=5?'ltr':'auto'}>{v}</bdi></td>)}</tr>)}</tbody><tfoot><tr>{register.totals.map((v,i)=><th key={i}><bdi dir={i>=5?'ltr':'auto'}>{v}</bdi></th>)}</tr></tfoot></table><p className="payroll-register-note">{t.note}</p></article></div>,document.body)}
 </div>;
}
