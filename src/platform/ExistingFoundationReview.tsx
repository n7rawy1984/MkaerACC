import { useEffect, useState } from "react";
import { useI18n } from "../i18n/I18nContext";
import { callPlatform, type AdminCommand, type PlatformRow, type PlatformTransport } from "./platformApi";

type Report = { company_id: string; eligible: boolean; failures: {code:string;reference:string}[]; accounts:number;journals:number; debit_minor:string;credit_minor:string;period_mode:string };
const messages: Record<string,[string,string]> = {
 COMPANY_ACTIVE:["Company must be active.","يجب أن تكون الشركة نشطة."],
 ENROLL_BUSINESS:["Associate the existing company as an active Business in Company settings first.","اربط الشركة القائمة ككيان أعمال نشط من إعدادات الشركة أولاً."],
 ACCOUNTING_ADMIN:["An active Accounting Admin is required.","يلزم مسؤول محاسبة نشط."],
 CONTROL_MAPPING:["Correct the missing or invalid control mapping.","استكمل أو صحح ربط حساب الرقابة."],
 TREASURY_REQUIRED:["Configure an active Treasury.","أعدّ خزينة نشطة."],
 TREASURY_MAPPING:["Review Treasury asset account, status and bank name.","راجع حساب أصل الخزينة وحالته واسم البنك."],
 TREASURY_BALANCE:["Treasury balance is negative with no supported overdraft policy. Resolve through evidenced canonical accounting; do not invent funding.","رصيد الخزينة سالب دون سياسة سحب على المكشوف مدعومة. عالجه محاسبياً بأدلة دون اختراع تمويل."],
 ACCOUNT_CYCLE:["Resolve circular account hierarchy without changing posted history.","عالج دورة تسلسل الحسابات دون تغيير التاريخ المرحّل."],
 OPENING_POSITION:["Certified opening positions disagree with GL at cutover.","الأرصدة الافتتاحية المعتمدة لا تتطابق مع الأستاذ عند بدء التشغيل."],
 ACCOUNT_PARENT:["Review account hierarchy and account types.","راجع تسلسل الحسابات وأنواعها."],
 JOURNAL_BALANCE:["Journal is unbalanced or incomplete; investigate without editing posted history.","القيد غير متوازن أو غير مكتمل؛ حقق دون تعديل التاريخ المرحّل."],
 LINE_DIMENSIONS:["Review journal dimensions and Company consistency.","راجع أبعاد القيد واتساق الشركة."],
 PERIOD_BOUNDS:["Review period boundaries within its fiscal year.","راجع حدود الفترة ضمن السنة المالية."],
 PERIOD_OVERLAP:["Resolve overlapping fiscal periods through authorized controls.","عالج تداخل الفترات المالية عبر الضوابط المعتمدة."],
 PERIOD_COVERAGE:["A historical journal is outside configured fiscal periods.","يوجد قيد تاريخي خارج الفترات المالية المعدّة."],
 OPENING_LINK:["Review the certified opening journal link.","راجع ربط قيد الأرصدة الافتتاحية المعتمدة."],
 IMMUTABILITY:["Journal immutability protection requires administrator investigation.","تتطلب حماية ثبات القيود تحقيق المسؤول."],
};
export function ExistingFoundationReview({api,row,busy,submit}:{api:PlatformTransport;row:PlatformRow;busy:boolean;submit:(c:AdminCommand)=>void}) {
 const {locale}=useI18n(),ar=locale==="ar",cid=String(row.id??""),[result,setResult]=useState<{key:string;report:Report|null;error:boolean}|null>(null),[revision,setRevision]=useState(0),[reason,setReason]=useState("");
 const requestKey=cid+":"+revision,report=result?.key===requestKey?result.report:null,error=result?.key===requestKey&&result.error;
 useEffect(()=>{let alive=true;const controller=new AbortController();
 void callPlatform(api,"review_existing_company_foundation",{target_company_id:cid},{signal:controller.signal}).then(v=>{
 const r=v as Report;if(!r||r.company_id!==cid||typeof r.eligible!=="boolean"||!Array.isArray(r.failures)||r.failures.some(f=>typeof f.code!=="string"||typeof f.reference!=="string")||!Number.isSafeInteger(r.accounts)||!Number.isSafeInteger(r.journals))throw Error("Invalid validation response");if(alive)setResult({key:requestKey,report:r,error:false});
 }).catch(()=>{if(alive)setResult({key:requestKey,report:null,error:true});});return()=>{alive=false;controller.abort();};},[api,cid,revision,requestKey]);
 return <form onSubmit={e=>{e.preventDefault();if(report?.eligible&&!busy&&reason.trim().length>=5)submit({name:"certify_foundation",input:{id:cid,version:String(row.version),reason:reason.trim()}});}}>
 <p><bdi>{String(row.name??"")} · {String(row.code??"")}</bdi></p>
 <p>{ar?"تحقق بنيوي للحسابات والقيود والأبعاد والأرصدة الافتتاحية المرتبطة والفترات المعدّة. لا يثبت الأدلة الاقتصادية التاريخية أو النقد الفعلي. لا ينشئ أو يعدّل حسابات أو قيوداً أو أرصدة.":"Structural validation of accounts, journals, dimensions, linked openings and configured periods. This does not verify historical economic evidence or physical cash. No accounts, journals or balances are created or changed."}</p>
 {error?<p role="alert">{ar?"تعذر التحقق. أعد المحاولة أو راجع صلاحية مالك المنصة والمصادقة المتعددة.":"Review unavailable. Retry or check Platform Owner access and MFA."}</p>:!report?<p role="status">{ar?"جارٍ التحقق…":"Validating…"}</p>:<>
 <p role="status">{ar?`الحسابات: ${report.accounts} · القيود: ${report.journals}`:`Accounts: ${report.accounts} · Journals: ${report.journals}`}</p>
 {report.period_mode==="EXISTING_UNCONFIGURED"&&<p>{ar?"لا توجد سنوات مالية معدّة؛ تُحفظ ضوابط الفترات القائمة دون اختراع سياسة مالية.":"No fiscal years configured; existing period controls are preserved without inventing fiscal policy."}</p>}
 {report.eligible?<p role="status">{ar?"اجتازت التحققات المحددة. يمكن اعتماد التأسيس القائم.":"The listed checks passed. The existing foundation can be certified."}</p>:<ul role="alert">{report.failures.map((f,i)=><li key={i}>{messages[f.code]?.[ar?1:0]??(ar?"راجع التحقق الفاشل.":"Review failed check.")} <bdi>{f.reference}</bdi></li>)}</ul>}
 </>}
 <button type="button" disabled={busy} onClick={()=>setRevision(v=>v+1)}>{ar?"تحديث التحقق":"Refresh validation"}</button>
 <label>{ar?"سبب الاعتماد المسجل":"Audited certification reason"}<textarea required minLength={5} maxLength={500} value={reason} disabled={busy} onChange={e=>setReason(e.target.value)}/></label>
 <button type="submit" disabled={busy||!report?.eligible||reason.trim().length<5}>{ar?"اعتماد التأسيس القائم":"Certify existing foundation"}</button>
 </form>;
}
