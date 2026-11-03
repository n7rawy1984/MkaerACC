import { useEffect, useState, type ReactNode } from "react";
import { Link, useLocation } from "react-router-dom";
import { Check, Circle, RefreshCw } from "lucide-react";
import { useI18n } from "../i18n/I18nContext";
import { LoadingState, StatusBadge } from "./platformUi";
import { isUuid, PlatformError, readOnboarding, type AdminCommand, type OnboardingCompany, type PlatformRow, type PlatformTransport } from "./platformApi";

const text = {
 en:{customer:"Customer",company:"Company",administrator:"Accounting Administrator",foundation:"Initial accounting setup",subscription:"Subscription",readiness:"Commercial Readiness",complete:"Complete",pending:"Pending",ready:"Ready for ordinary accounting operations",notReady:"Setup pending · permitted viewing, settlements and reversals remain available",legacy:"Internal company",legacyHelp:"This internal company does not require customer linking or initial accounting setup. A subscription applies if assigned. Internal access does not indicate paid customer status.",createCustomer:"New customer",createCompany:"New company",associate:"Associate customer",activate:"Activate company",invite:"Invite administrator",waiting:"Administrator invitation awaiting acceptance",review:"Review invitations / delivery",provision:"Set up accounting",subscribe:"Assign / renew subscription",refresh:"Refresh progress",search:"Search companies",empty:"No linked companies. Create a company or link an eligible existing company from Companies.",error:"Progress could not be verified. Refresh to retry; no change was submitted.",previous:"Previous",next:"Next",all:"All onboarding",setup:"Activation is a setup step. Provision the foundation before ordinary operations. Subscription payment status is recorded manually; no accounting revenue or cash entry is created.",manage:"Review company",done:"All required commercial steps are complete.",customerHelp:"One Customer can have multiple independently authorized and subscribed Companies. Contact details grant no workspace access.",blocked:"Resolve the preceding steps to continue.",suspended:"Suspended / archived: review the Company lifecycle before continuing.",lifecycle:"Company status",period:"Service period (inclusive)",unknown:"Not verified",missing:"Missing",unenrolled:"Not enrolled",resume:"Confirmed steps are saved. You can return through Customer onboarding or this Customer’s portfolio; pending invitations remain available for follow-up.",nextAction:"Next step",nextCustomer:"Associate this Company with its Customer.",nextAdmin:"Invite the person who will administer this Company’s accounting workspace.",nextWaiting:"Wait for the administrator to accept. Review the invitation to check delivery or follow up.",nextActivate:"The administrator is ready. Activate this Company before setting up its accounting foundation.",nextFoundation:"Set up the accounting foundation for this Company.",nextSubscription:"Assign or renew this Company’s subscription to enable ordinary operations.",activationRequired:"Activate company first",noMatches:"No companies match this search. Clear the search to see this portfolio."},
 ar:{customer:"العميل",company:"الشركة",administrator:"مسؤول المحاسبة",foundation:"الإعداد المحاسبي الأولي",subscription:"الاشتراك",readiness:"الجاهزية التجارية",complete:"مكتمل",pending:"قيد الاستكمال",ready:"جاهز للعمليات المحاسبية المعتادة",notReady:"الإعداد قيد الاستكمال · يتاح عرض السجلات والتسويات وقيود العكس المسموح بها",legacy:"شركة داخلية",legacyHelp:"لا تتطلب هذه الشركة الداخلية ربط عميل أو إعدادًا محاسبيًا أوليًا. يُطبّق الاشتراك عند تعيينه. لا تعني صلاحية الشركة الداخلية أنها عميل مدفوع.",createCustomer:"عميل جديد",createCompany:"شركة جديدة",associate:"ربط العميل",activate:"تفعيل الشركة",invite:"دعوة مسؤول المحاسبة",waiting:"دعوة المسؤول في انتظار القبول",review:"مراجعة الدعوات والإرسال",provision:"إعداد الحسابات",subscribe:"تعيين أو تجديد الاشتراك",refresh:"تحديث التقدم",search:"البحث عن الشركات",empty:"لا توجد شركات مرتبطة. أنشئ شركة أو اربط شركة مؤهلة من صفحة الشركات.",error:"تعذر التحقق من التقدم. أعد التحديث؛ لم ينفذ أي تغيير.",previous:"السابق",next:"التالي",all:"جميع عمليات التهيئة",setup:"التفعيل خطوة إعداد. استكمل التأسيس قبل العمليات المعتادة. حالة الدفع تسجل يدويًا دون إنشاء إيراد أو حركة نقدية.",manage:"مراجعة الشركة",done:"اكتملت متطلبات التشغيل التجاري.",customerHelp:"يمكن ربط عدة شركات بالعميل، ولكل شركة صلاحيات واشتراك مستقلان. معلومات الاتصال لا تمنح وصولًا محاسبيًا.",blocked:"استكمل الخطوات السابقة للمتابعة.",suspended:"الشركة معلقة أو مؤرشفة؛ راجع حالتها قبل المتابعة.",lifecycle:"حالة الشركة",period:"فترة الخدمة (شاملة)",unknown:"غير متحقق",missing:"غير موجود",unenrolled:"غير مسجل",resume:"تم حفظ الخطوات المؤكدة. يمكنك العودة من تهيئة العملاء أو محفظة هذا العميل؛ تبقى الدعوات المعلقة متاحة للمتابعة.",nextAction:"الخطوة التالية",nextCustomer:"اربط هذه الشركة بالعميل التابع لها.",nextAdmin:"ادعُ المسؤول الذي سيدير مساحة العمل المحاسبية لهذه الشركة.",nextWaiting:"انتظر قبول المسؤول. راجع الدعوة للتحقق من الإرسال أو المتابعة.",nextActivate:"المسؤول جاهز. فعّل الشركة قبل تأسيس حساباتها.",nextFoundation:"استكمل التأسيس المحاسبي لهذه الشركة.",nextSubscription:"عيّن اشتراك هذه الشركة أو جدده لتمكين العمليات المعتادة.",activationRequired:"فعّل الشركة أولاً",noMatches:"لا توجد شركات تطابق البحث. امسح البحث لعرض المحفظة."}
};
const stateLabels: Record<"en"|"ar",Record<string,string>> = {
 en:{DRAFT:"Draft",ACTIVE:"Active",SUSPENDED:"Suspended",ARCHIVED:"Archived",TRIAL:"Trial",EXPIRED:"Expired",CANCELLED:"Cancelled",SCHEDULED:"Not started"},
 ar:{DRAFT:"مسودة",ACTIVE:"نشط",SUSPENDED:"معلق",ARCHIVED:"مؤرشف",TRIAL:"تجريبي",EXPIRED:"منتهٍ",CANCELLED:"ملغى",SCHEDULED:"لم يبدأ"}
};
type Props={customerSelector:ReactNode;api:PlatformTransport;generation:number;disabled:boolean;open:(kind:AdminCommand["name"],row?:PlatformRow)=>void;denied:()=>void};
export function CommercialOnboarding({customerSelector,api,generation,disabled,open,denied}:Props){
 const {locale}=useI18n(),t=text[locale],location=useLocation();
 const params=new URLSearchParams(location.search),customer=params.get("customer"),company=params.get("company");
 const [revision,setRevision]=useState(0),[search,setSearch]=useState(""),[page,setPage]=useState(0);
 const requestKey=JSON.stringify([customer,company,page,search,generation,revision]);
 const [result,setResult]=useState<{key:string;rows:OnboardingCompany[]|null;more:boolean;error:boolean}|null>(null);
 const current=result?.key===requestKey?result:null,rows=current?.rows??null,error=current?.error??false,more=current?.more??false;
 useEffect(()=>{let alive=true;const controller=new AbortController();
  const timer=setTimeout(()=>{void readOnboarding(api,{...(customer&&isUuid(customer)?{target_customer_id:customer}:{}),...(company&&isUuid(company)?{target_company_id:company}:{}),page_offset:page*25,search}, {signal:controller.signal}).then(d=>{if(alive)setResult({key:requestKey,rows:d.items,more:d.has_more,error:false});},e=>{if(alive){setResult({key:requestKey,rows:null,more:false,error:true});if(e instanceof PlatformError&&["denied","mfa"].includes(e.kind))denied();}});},150);
  return()=>{alive=false;controller.abort();clearTimeout(timer);};
 },[api,customer,company,page,search,generation,revision,denied,requestKey]);
 useEffect(()=>{const refresh=()=>setRevision(n=>n+1);window.addEventListener("focus",refresh);const timer=window.setInterval(refresh,60000);return()=>{window.removeEventListener("focus",refresh);window.clearInterval(timer);};},[]);
 return <section className="commercial-onboarding" aria-label={locale==="ar"?"مسار تهيئة العميل":"Customer onboarding workspace"}>
  <div className="platform-panel">{!customer&&!company&&customerSelector}<p>{t.customerHelp}</p><p>{t.setup}</p><p className="commercial-resume">{t.resume}</p><div className="platform-row-actions">
   <button disabled={disabled} onClick={()=>open("create_customer")}>{t.createCustomer}</button>
   <button disabled={disabled} onClick={()=>open("create_entity",customer&&isUuid(customer)?{customer_id:customer}:undefined)}>{t.createCompany}</button>
   {(customer||company)&&<Link to="/platform/onboarding">{t.all}</Link>}
  </div></div>
  <div className="platform-toolbar"><label className="platform-search">{t.search}<input maxLength={100} value={search} onChange={e=>{setSearch(e.target.value);setPage(0);}}/></label><button onClick={()=>setRevision(n=>n+1)}><RefreshCw size={16} aria-hidden="true"/>{t.refresh}</button></div>
  {error?<p role="alert" className="platform-error">{t.error}</p>:!rows?<LoadingState/>:!rows.length?<p className="platform-panel">{search?t.noMatches:t.empty}</p>:rows.map(row=>{
   const r=row.readiness,legacy=r.legacy_eligible;
   const lifecycle=typeof row.lifecycle==="string"?row.lifecycle:"";
   const subscriptionState=typeof r.subscription_state==="string"?r.subscription_state:"";
   const subscriptionLabel=subscriptionState==="UNMANAGED"?(legacy?t.unenrolled:t.missing):(stateLabels[locale][subscriptionState]??t.unknown);
   const next=r.ready?t.done:!r.active&&lifecycle!=="DRAFT"?t.suspended:!r.customer?t.nextCustomer:!r.administrator?(row.pending_admin_invitations>0?t.nextWaiting:t.nextAdmin):!r.active?t.nextActivate:!r.foundation?t.nextFoundation:!r.subscription?t.nextSubscription:t.blocked;
   const steps=[{label:t.customer,ok:r.customer},{label:t.company,ok:true},{label:t.administrator,ok:r.administrator},{label:t.foundation,ok:r.foundation},{label:t.subscription,ok:r.subscription},{label:t.readiness,ok:r.ready}];
   const edit=()=>open("update_entity",row);
   return <article key={row.id} className="platform-panel commercial-company" data-company-id={row.id}>
    <header><div><h2>{row.name}</h2><p><bdi>{row.code}</bdi> · {row.customer_name?String(row.customer_name):t.pending}</p></div><StatusBadge status={legacy?"LEGACY":r.ready?"COMPLETE":"INCOMPLETE"}>{legacy?t.legacy:r.ready?t.complete:t.pending}</StatusBadge></header>
    <dl className="commercial-state-summary">
     <div><dt>{t.lifecycle}</dt><dd><StatusBadge status={lifecycle}>{stateLabels[locale][lifecycle]??t.unknown}</StatusBadge></dd></div>
     <div className="commercial-subscription"><dt>{t.subscription}</dt><dd><StatusBadge status={subscriptionState}>{subscriptionLabel}</StatusBadge>
      {typeof row.starts_on==="string"&&typeof row.ends_on==="string"&&<span className="commercial-service-period">{t.period}: <bdi><time dateTime={row.starts_on}>{row.starts_on}</time> – <time dateTime={row.ends_on}>{row.ends_on}</time></bdi></span>}
     </dd></div>
    </dl>
    {legacy?<p>{t.legacyHelp}</p>:<ol className="commercial-steps" aria-label={t.readiness}>{steps.map((step,i)=><li key={step.label} data-complete={step.ok} aria-current={!step.ok&&steps.findIndex(s=>!s.ok)===i?"step":undefined}><span>{step.ok?<Check size={18} aria-hidden="true"/>:<Circle size={18} aria-hidden="true"/>}{step.label}</span><small>{step.ok?t.complete:i===3&&!r.active?t.activationRequired:t.pending}</small></li>)}</ol>}
    <p role="status">{r.ready?t.ready:t.notReady}</p>
    {!legacy&&<p className="commercial-next"><strong>{t.nextAction}: </strong>{next}</p>}
    <div className="platform-row-actions">
     {!legacy&&!r.customer&&<button disabled={disabled} onClick={edit}>{t.associate}</button>}
     {!legacy&&!r.administrator&&(row.pending_admin_invitations>0?<><span>{t.waiting}</span><Link to="/platform/invitations">{t.review}</Link></>:<button disabled={disabled} onClick={()=>open("invite",{company_id:row.id,role:"ACCOUNTING_ADMIN"})}>{t.invite}</button>)}
     {!r.active&&r.administrator&&row.lifecycle==="DRAFT"&&<button disabled={disabled} onClick={()=>open("set_lifecycle",{...row,state:"ACTIVE"})}>{t.activate}</button>}
     {!legacy&&r.active&&r.administrator&&!r.foundation&&row.accounting_setup==="INCOMPLETE"&&<button disabled={disabled} onClick={()=>open("provision_accounting",row)}>{t.provision}</button>}
     {!legacy&&r.customer&&r.active&&r.administrator&&r.foundation&&!r.subscription&&<button disabled={disabled} onClick={()=>open("set_subscription",{...row,version:row.subscription_version??0})}>{t.subscribe}</button>}
     <Link to={`/platform/entities/${row.id}`}>{t.manage}</Link>
    </div>
    {!r.active&&row.lifecycle!=="DRAFT"&&<p>{t.suspended}</p>}
    {r.ready&&!legacy&&<p>{t.done}</p>}
   </article>;
  })}
  <div className="platform-pager"><button disabled={!page} onClick={()=>setPage(n=>n-1)}>{t.previous}</button><button disabled={!more||!rows} onClick={()=>setPage(n=>n+1)}>{t.next}</button></div>
 </section>;
}

/** Lazy company portfolio on the Customers directory; all progress comes from the same RPC. */
export function CustomerPortfolio({api,customerId,generation}:{api:PlatformTransport;customerId:string;generation:number}){
 const {locale}=useI18n(),t=text[locale];const [expanded,setExpanded]=useState(false);
 const key=customerId+":"+generation;
 const [result,setResult]=useState<{key:string;data:OnboardingCompany[]|null;error:boolean}|null>(null);
 const current=result?.key===key?result:null,data=current?.data??null,error=current?.error??false;
 useEffect(()=>{if(!expanded)return;let alive=true;const c=new AbortController();
  void readOnboarding(api,{target_customer_id:customerId,page_offset:0,search:""},{signal:c.signal}).then(r=>{if(alive)setResult({key,data:r.items,error:false});},()=>{if(alive)setResult({key,data:null,error:true});});return()=>{alive=false;c.abort();};
 },[api,customerId,expanded,generation,key]);
 return <details onToggle={e=>setExpanded(e.currentTarget.open)}><summary>{locale==="ar"?"الشركات المرتبطة وتقدم التهيئة":"Linked companies & onboarding progress"}</summary>
  {expanded&&(error?<p role="alert">{t.error}</p>:!data?<LoadingState/>:!data.length?<p>{t.empty}</p>:<ul>{data.map(c=><li key={c.id}><Link to={`/platform/onboarding?company=${c.id}`}>{c.name}</Link> · {c.readiness.legacy_eligible?t.legacy:c.readiness.ready?t.complete:t.pending}</li>)}</ul>)}
  <Link to={`/platform/onboarding?customer=${customerId}`}>{locale==="ar"?"فتح المحفظة الكاملة":"Open full portfolio"}</Link>
 </details>;
}
