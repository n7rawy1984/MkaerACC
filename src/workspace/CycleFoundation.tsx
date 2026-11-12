import {AccountingOverview} from '../dashboard/AccountingOverview';
import {MonthlyFinancialActivity} from '../dashboard/MonthlyFinancialActivity';
import {useEffect,useMemo,useState,type ReactNode} from 'react';
import {Link} from 'react-router-dom';
import {Building2,BookOpen,Landmark,HardHat,FolderKanban,Users,FileSignature,ContactRound,CalendarDays,Receipt,Wallet,Settings2,CheckCircle2,Database,ChartColumn,ClipboardCheck,LockKeyhole,Files,ArrowRight,RefreshCw,TriangleAlert,type LucideIcon} from 'lucide-react';
import {useAuth} from '../auth/AuthContext';
import {useI18n} from '../i18n/I18nContext';
import {useProductionMasterData} from '../master/productionMasterDataContext';
import {getSupabaseClient} from '../lib/supabase';
import {useDashboardRead} from '../dashboard/useDashboardRead';
import {summarizeDashboard,dashboardAED} from '../dashboard/dashboardSummary';
import {useHistoricalSources} from '../historical/useHistoricalSources';
import {WorkspaceQuickActions} from './WorkspaceQuickActions';
import {useWorkspaceText} from './useWorkspaceText';
import {isAccountingReader} from './workspaceNavigation';
import {moduleForRole} from './moduleRegistry';
import {moneyMetric,type Metric} from './metricState';
import {cycleText,type CycleKey} from './cycleText';
import './cycleFoundation.css';
type Text=(key:CycleKey)=>string;
export function WorkflowStage({number,title,note,children}:{number:number;title:string;note:string;children:ReactNode}){
 return <section className={'cycle-stage cycle-stage-'+number} aria-labelledby={'cycle-stage-'+number}><header className="cycle-stage-heading"><span className="cycle-stage-number" aria-hidden="true">{number}</span><h2 id={'cycle-stage-'+number}>{title}</h2><p>{note}</p></header><div className="cycle-stage-body">{children}</div></section>;
}
export function MetricValue({metric,t,explanation}:{metric:Metric;t:Text;explanation:string}){
 const value=metric.state==='AVAILABLE'||metric.state==='VERIFIED_ZERO'?dashboardAED(metric.minor!):metric.state==='LOADING'?t('loading'):'—';
 return <span className={'cycle-metric cycle-metric-'+metric.state.toLowerCase()} data-metric-state={metric.state}><bdi dir="ltr">{value}</bdi>{['UNAVAILABLE','ERROR'].includes(metric.state)&&<small>{metric.state==='ERROR'?t('error'):explanation}</small>}{metric.state==='VERIFIED_ZERO'&&<small>{t('zero')}</small>}</span>;
}
export function CapabilityBadge({status,t}:{status:'available'|'planned'|'verification'|'restricted';t:Text}){return <span className={'cycle-capability cycle-capability-'+status}>{t(status)}</span>;}
export function FinancialMetricCard({label,metric,t,explanation}:{label:string;metric:Metric;t:Text;explanation:string}){return <div className="cycle-financial-metric-card"><dt>{label}</dt><dd><MetricValue metric={metric} t={t} explanation={explanation}/></dd></div>;}
export function MonthlyActivityColumn({title,index,rows,t}:{title:string;index:number;rows:{label:string;icon:LucideIcon;metric:Metric;explanation:string}[];t:Text}){
 return <article className={'cycle-month cycle-month-'+index}><h3><CalendarDays size={20} aria-hidden="true"/>{title}</h3><dl>{rows.map((row,j)=><div key={row.label}><dt><span className={'cycle-row-icon cycle-tone-'+j}><row.icon size={24} aria-hidden="true"/></span><span>{row.label}</span></dt><dd><MetricValue metric={row.metric} t={t} explanation={row.explanation}/></dd></div>)}</dl></article>;
}
function WorkflowCard({moduleId,label,icon:Icon,role,t,tone=0}:{moduleId:string;label:string;icon:LucideIcon;role:string;t:Text;tone?:number}){
 const module=moduleForRole(moduleId,role),status=module.canNavigate?'available':module.status==='REQUIRES_VERIFICATION'?'verification':module.route?'restricted':'planned';
 const body=<><span className={'cycle-icon cycle-tone-'+tone}><Icon size={31} strokeWidth={1.8} aria-hidden="true"/></span><strong>{label}</strong><CapabilityBadge status={status} t={t}/></>;
 return module.canNavigate?<Link className="cycle-workflow-card" to={module.route!}>{body}</Link>:<div className="cycle-workflow-card cycle-workflow-unavailable">{body}</div>;
}
export function ProcessDiagram({items,role,t}:{items:{module:string;label:string;icon:LucideIcon}[];role:string;t:Text}){
 return <ol className="cycle-process">{items.map((item,i)=><li key={item.module+item.label}><WorkflowCard moduleId={item.module} label={item.label} icon={item.icon} role={role} t={t} tone={i%6}/>{i<items.length-1&&<ArrowRight className="cycle-connector" size={19} aria-hidden="true"/>}</li>)}</ol>;
}
export function CycleFoundation({details}:{details?:ReactNode}){const {state}=useAuth();if(state.phase!=='TENANT_READY')return null;return <CycleData key={`${state.profile.userId}:${state.activeTenant.companyId}:${state.activeTenant.role}`} userId={state.profile.userId} companyId={state.activeTenant.companyId} role={state.activeTenant.role} details={details}/>;}
export function DashboardFoundation(){const {state}=useAuth();if(state.phase!=='TENANT_READY')return null;return <OverviewWorkspace key={`${state.profile.userId}:${state.activeTenant.companyId}:${state.activeTenant.role}`} userId={state.profile.userId} companyId={state.activeTenant.companyId} role={state.activeTenant.role}/>;}
function OverviewWorkspace({userId,companyId,role}:{userId:string;companyId:string;role:string}){
 const {locale}=useI18n(),master=useProductionMasterData(),[revision,setRevision]=useState(0);
 useEffect(()=>{const update=(event:Event)=>{if((event as CustomEvent).detail?.companyId===companyId)setRevision(n=>n+1);};window.addEventListener('historical-source-changed',update);return()=>window.removeEventListener('historical-source-changed',update);},[companyId]);
 if(master.phase!=='READY')return <p role={master.phase==='ERROR'?'alert':'status'}>{locale==='ar'?'بيانات الشركة غير متاحة بعد':'Company data is not yet available'}</p>;
 if(master.company.id!==companyId||[...master.projects,...master.accounts,...master.parties,...master.treasuryAccounts].some(p=>p.companyId!==companyId))return <p role="alert">{locale==='ar'?'تعذر التحقق من نطاق الشركة':'Company scope could not be verified'}</p>;
 return <div className="integrated-cycle"><AccountingOverview user={userId} company={companyId} companyName={master.company.name} role={role} locale={locale} revision={revision} accounts={master.accounts} parties={master.parties} treasuries={master.treasuryAccounts}/></div>;
}
function CycleData({userId,companyId,role,details}:{userId:string;companyId:string;role:string;details?:ReactNode}){
 const {locale,t:globalText}=useI18n(),w=useWorkspaceText(),master=useProductionMasterData();const ar=locale==='ar',t:Text=key=>cycleText[ar?'ar':'en'][key];
 const [revision,setRevision]=useState(0),[expanded,setExpanded]=useState(false);
 useEffect(()=>{const update=(event:Event)=>{if((event as CustomEvent).detail?.companyId===companyId)setRevision(n=>n+1);};window.addEventListener('historical-source-changed',update);return()=>window.removeEventListener('historical-source-changed',update);},[companyId]);
 const masterReady=master.phase==='READY'&&master.company.id===companyId&&[...master.projects,...master.parties,...master.expenseCategories].every(r=>r.companyId===companyId);
 const financial=useDashboardRead(getSupabaseClient(),userId,companyId,role,revision,masterReady);
 const summary=useMemo(()=>{if(!masterReady||master.phase!=='READY'||financial.phase!=='READY')return null;try{return summarizeDashboard(master,financial.data,globalText('executiveDashboard.companyOverhead'));}catch{return null;}},[masterReady,master,financial,globalText]);
 const allowed=isAccountingReader(role),source=useHistoricalSources(companyId,allowed,undefined,revision,['ACCOUNTING_ADMIN','ACCOUNTANT'].includes(role));
 const phase=!allowed?'DENIED':master.phase==='LOADING'?'LOADING':!masterReady?'ERROR':financial.phase==='READY'?(summary?'READY':'ERROR'):financial.phase;
 const postedMetrics=[['posted',summary?.postedExpenseNet],['supplier',summary?.supplierOutstanding],['subcontractor',summary?.subcontractorOutstanding],['retention',summary?.retentionHeld]] as const;
 const setup=[['/company-profile','company',Building2],['/accounts','coa',BookOpen],['/treasury-accounts','treasury',Landmark],['assets','assets',HardHat],['/projects','projectMaster',FolderKanban],['/parties','contractors',Users],['/subcontracts','contracts',FileSignature],['/employees','employees',ContactRound]] as const;
 const retry=()=>{setRevision(n=>n+1);source.refresh();};
 return <div className="integrated-cycle" data-reference="NARVO_DASHBOARD_REFERENCE.jpeg"><header className="cycle-title"><span className="cycle-wordmark"><Building2 size={26} aria-hidden="true"/>NARVO <small>ERP</small></span><div><h2>{t('title')}</h2><p>{t('intro')}</p></div><button type="button" onClick={retry} aria-label={t('retry')}><RefreshCw size={16} aria-hidden="true"/>{t('retry')}</button></header>
 <WorkspaceQuickActions compact/>
 {(source.error||phase==='ERROR')&&<div className="cycle-read-error" role="alert"><TriangleAlert size={18} aria-hidden="true"/>{t('errorHelp')}</div>}
 <WorkflowStage number={1} title={t('setup')} note={t('setupNote')}><div className="cycle-setup">{setup.map(([id,label,Icon],i)=><WorkflowCard key={id} moduleId={id} label={t(label)} icon={Icon} tone={i%6} role={role} t={t}/>)}</div></WorkflowStage>
 <WorkflowStage number={2} title={ar?'الحركة المالية الشهرية':'Monthly financial activity'} note={ar?'المصادر المستوردة والمحاسبة المرحلة منفصلتان':'Imported sources and posted accounting shown separately'}><MonthlyFinancialActivity user={userId} company={companyId} companyName={masterReady&&master.phase==='READY'?master.company.name:''} role={role} locale={locale} revision={revision} sources={source.rows} sourceLoading={source.loading} sourceError={source.error}/></WorkflowStage>
 <WorkflowStage number={3} title={t('posting')} note={t('postingNote')}><ProcessDiagram role={role} t={t} items={[{module:'/expenses',label:t('entry'),icon:Receipt},{module:'rules',label:t('rules'),icon:Settings2},{module:'/expenses',label:t('review'),icon:CheckCircle2},{module:'/accounting-reports',label:t('ledger'),icon:Database}]}/><p className="cycle-evidence-note">{ar?"صدّر القيود اليومية المرحلة للمراجعة. تُرحّل المعاملات من مستنداتها؛ استعراض الأستاذ العام وتعديل قواعد الترحيل غير متاحين هنا.":"Export posted journal entries for review. Post transactions from their documents; a separate general ledger browser and posting-rule editor are not available."}</p></WorkflowStage>
 <WorkflowStage number={4} title={t('reports')} note={t('reportsNote')}><div className="cycle-report-grid">{['trialBalance','income','balance'].map((id,i)=>{const m=moduleForRole(id,role);return <ReportPreview key={id} title={m.name[ar?1:0]} icon={[BookOpen,ChartColumn,Landmark][i]} t={t}/>;})}<article className="cycle-report-panel cycle-supported-reports"><h3><Files size={20} aria-hidden="true"/>{t('details')}</h3><dl>{postedMetrics.map(([key,value])=><FinancialMetricCard key={key} label={t(key)} metric={moneyMetric(value,phase)} t={t} explanation={allowed?t('empty'):t('scopeDenied')}/>)}</dl>{moduleForRole('/accounting-reports',role).canNavigate&&<Link className="cycle-report-link" to="/accounting-reports">{w('reports')}<ArrowRight size={14} aria-hidden="true"/></Link>}</article></div><p className="cycle-evidence-note">{t('metricScope')}</p></WorkflowStage>
 <WorkflowStage number={5} title={t('projects')} note={t('projectsNote')}><ProcessDiagram role={role} t={t} items={[{module:'/subcontracts',label:t('contract'),icon:FileSignature},{module:'execution',label:t('execution'),icon:HardHat},{module:'/subcontractor-certificates',label:t('certificates'),icon:ClipboardCheck},{module:'/subcontractor-payments',label:t('payments'),icon:Wallet},{module:'cost',label:t('cost'),icon:ChartColumn},{module:'projectReports',label:t('projectReports'),icon:BookOpen}]}/></WorkflowStage>
 <WorkflowStage number={6} title={t('closing')} note={t('closingNote')}><ProcessDiagram role={role} t={t} items={[{module:'/expenses',label:t('reviewTransactions'),icon:CalendarDays},{module:'reconciliation',label:t('reconcile'),icon:CheckCircle2},{module:'closing',label:t('close'),icon:LockKeyhole},{module:'finalReports',label:t('final'),icon:Files},{module:'nextPeriod',label:t('next'),icon:ChartColumn}]}/></WorkflowStage>
 {details&&<details className="cycle-existing-details" open={expanded} onToggle={e=>setExpanded(e.currentTarget.open)}><summary>{t('legacy')}</summary>{expanded&&details}</details>}
 </div>;
}
export function ReportPreview({title,icon:Icon,t}:{title:string;icon:LucideIcon;t:Text}){
 return <article className="cycle-report-panel cycle-report-unavailable"><h3><Icon size={20} aria-hidden="true"/>{title}</h3><div className="cycle-statement-preview" aria-hidden="true"><span/><span/><span/><span/></div><MetricValue metric={{state:'UNAVAILABLE'}} t={t} explanation={t('statementReason')}/><CapabilityBadge status="planned" t={t}/></article>;
}
