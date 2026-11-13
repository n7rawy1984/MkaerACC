import {usePaymentPreferences} from './paymentPreferences';
import{RecordDetailDrawer,TextCell}from'../workspace/data/DataWorkspace';
import{useProductionMasterData}from'../master/productionMasterDataContext';
import type{ExpenseRead}from'./expenseRepository';
import {ExpenseDraftWorkspace} from './ExpenseDraftWorkspace';
import {CustodyWorkspace} from './CustodyWorkspace';
import {ExpenseCorrectionReview} from './ExpenseCorrectionReview';
import {useWorkspaceSubscription} from '../workspace/workspaceSubscriptionContext';
import {workspaceBusinessAccess} from '../workspace/workspaceBusinessAccess';
import {ReportExport} from '../reports/ReportExport';
import {postedExpenseReport} from '../reports/postedExpenseReport';
import HistoricalImports from "../historical/HistoricalImports";
import { TreasuryExpensePost } from "./TreasuryExpensePost";
import { SupplierCreditExpensePost } from "./SupplierCreditExpensePost";
import { canPostExpense } from "./expensePostRepository";
import { ExpenseReverseAction } from "./ExpenseReverseAction";
import { canReverseExpense } from "./expenseReverseRepository";
import { useState,useEffect } from "react";
import { useAuth } from "../auth/AuthContext";
import { useI18n, useT } from "../i18n/I18nContext";
import { getSupabaseClient } from "../lib/supabase";
import {dashboardAED} from '../dashboard/dashboardSummary';
import {sourceDatePresentation} from '../historical/sourceDatePresentation';
import {ContentSection,DataTable,StatusBadge,LoadingState,ErrorState,EmptyState} from '../workspace/workspaceUi';
import {useWorkspaceUiText} from '../workspace/useWorkspaceUiText';
import { useExpenseRead } from "./useExpenseRead";

export function ExpenseReadPanel() {
  const { state } = useAuth();
  if (state.phase !== "TENANT_READY") return null;
  return <ExpenseReadContent key={`${state.profile.userId}:${state.activeTenant.companyId}:${state.activeTenant.role}`} userId={state.profile.userId} companyId={state.activeTenant.companyId} role={state.activeTenant.role} />;
}
export function ExpenseReadContent({ userId, companyId, role }: { userId: string; companyId: string; role: string }) {
  const auth=useAuth();const companyName=auth.state.phase==="TENANT_READY"?auth.state.activeTenant.companyName:"";
  const t = useT(); const {locale}=useI18n();const u=useWorkspaceUiText();const businessAccess=workspaceBusinessAccess(useWorkspaceSubscription(),companyId);
  const master=useProductionMasterData();const[opened,setOpened]=useState<ExpenseRead|null>(null);const[view,setView]=useState(()=>window.location.hash==='#new-expense'||window.location.hash==='#supplier-credit'?'entry':'sources');
  useEffect(()=>{const sync=()=>{const h=window.location.hash;if(h==='#new-expense'||h==='#supplier-credit')setView('entry');else if(h==='#expense-posted-register')setView('posted');else if(h==='#expense-drafts')setView('drafts');else if(h==='#expense-source-review')setView('sources');};window.addEventListener('hashchange',sync);return()=>window.removeEventListener('hashchange',sync);},[]);
  const partyName=(id:string|null)=>master.phase==='READY'?master.parties.find(p=>p.id===id)?.name??'—':'—',projectName=(id:string|null)=>master.phase==='READY'?master.projects.find(p=>p.id===id)?.name??(locale==='ar'?'الشركة':'Company overhead'):'—';
  const preferences=usePaymentPreferences();const suggestion=preferences.rows.find(p=>p.kind==="DEFAULT");
  const [paymentSource,setPaymentSource]=useState('TREASURY');
  const [paymentChosen,setPaymentChosen]=useState(false);useEffect(()=>{if(!paymentChosen&&suggestion&&suggestion.mode!=='NONE')setPaymentSource(suggestion.mode);},[suggestion,paymentChosen]);
  const [page, setPage] = useState(0);
  const [revision, setRevision] = useState(0);
  const state = useExpenseRead(getSupabaseClient(), userId, companyId, role, page, revision);
  const refresh = () => { setPage(0); setRevision(value => value + 1); };
  const columns=[{key:'date',title:u('date')},{key:'description',title:u('description')},{key:'type',title:locale==='ar'?'التصنيف':'Classification'},{key:'party',title:locale==='ar'?'الطرف':'Counterparty'},{key:'project',title:locale==='ar'?'المشروع':'Project'},{key:'amount',title:locale==='ar'?'المبلغ':'Amount',numeric:true},{key:'status',title:t('common.status')},{key:'actions',title:u('viewDetails')}];

  return <section className="expenses-workspace dw-expenses">
    <nav className="suite-view-switch" aria-label={locale==='ar'?'أقسام المصروفات':'Expense sections'}><a href="#expense-source-review" aria-current={view==='sources'?'page':undefined} onClick={()=>setView('sources')}>{u('sources')}</a><a href="#expense-drafts" aria-current={view==='drafts'?'page':undefined} onClick={()=>setView('drafts')}>{locale==='ar'?'المسودات والمراجعة':'Drafts & review'}</a><a href="#expense-posted-register" aria-current={view==='posted'?'page':undefined} onClick={()=>setView('posted')}>{u('posted')}</a>{canPostExpense(role)&&businessAccess==='FULL'&&<a href="#new-expense" onClick={()=>{setView('entry');const d=document.getElementById('new-expense');if(d instanceof HTMLDetailsElement)d.open=true;}}>{u('entry')}</a>}</nav>
    {canPostExpense(role)&&businessAccess!=='FULL'&&<p role="status" className="suite-scope-note">{u(businessAccess==='UNKNOWN'?'unverified':'renew')}</p>}
    {canPostExpense(role)&&businessAccess==='FULL'&&<div className="dw-view-panel" hidden={view!=='entry'}><ContentSection title={u('entry')} className="expense-entry-forms">
    {canPostExpense(role) && <details open={window.location.hash==="#new-expense"} id="new-expense" className="mt-6 rounded-xl border p-4"><summary className="cursor-pointer font-semibold">{locale==="ar"?"مصروف جديد / بديل مصحح":"New Expense / corrected replacement"}</summary><p className="mt-3 text-sm text-slate-500">{locale==="ar"?"لتصحيح المستند بالكامل، تحقق من آثار النقد والضريبة والتسوية قبل العكس والاستبدال. تغييرات المشروع أو التصنيف تستخدم مراجعة التصحيح.":"For full document corrections, verify cash, VAT and settlement effects before reversal/replacement. Project or classification changes use correction review."}</p><label className="mt-3 block text-sm">{locale==='ar'?'مصدر دفع المصروف':'Expense payment source'}<select aria-label={locale==='ar'?'مصدر دفع المصروف':'Expense payment source'} className="mt-1 block w-full rounded-lg border border-slate-300 bg-white px-3 py-2" value={paymentSource} onChange={e=>{setPaymentChosen(true);setPaymentSource(e.target.value);}}><option value="TREASURY">{locale==='ar'?'خزينة نقدية / بنكية':'Cash / Bank Treasury'}</option><option value="CUSTODIAN">{locale==='ar'?'صاحب عهدة — أموال الشركة':'Custody holder — Company funds'}</option></select></label>{paymentSource==='TREASURY'?<TreasuryExpensePost userId={userId} companyId={companyId} role={role} onPosted={refresh}/>:<CustodyWorkspace expenseOnly suggestedHolder={suggestion?.mode==="CUSTODIAN"?suggestion.party_id??"":""} onPosted={refresh}/>}</details>}
    {canPostExpense(role) && <details id="supplier-credit" open={window.location.hash==="#supplier-credit"} className="mt-4 rounded-xl border p-4"><summary className="cursor-pointer font-semibold">{locale==="ar"?"مصروف آجل على مورد":"New Supplier Credit Expense"}</summary><SupplierCreditExpensePost userId={userId} companyId={companyId} role={role} onPosted={refresh} /></details>}
    </ContentSection></div>}
    <div className="dw-view-panel" hidden={view!=='drafts'}><ExpenseDraftWorkspace onPosted={refresh} canWrite={businessAccess==='FULL'}/></div><div className="dw-view-panel" hidden={view!=='sources'}><ContentSection id="expense-source-review"><HistoricalImports recordType="GENERAL" showReference={false} onPosted={refresh}/></ContentSection></div>
    <div className="dw-view-panel" hidden={view!=='posted'}><ContentSection id="expense-posted-register" title={locale==='ar'?'المصروفات المرحلة والتصحيح':'Posted Expenses & corrections'} description={u('registerNote')} actions={<><ReportExport build={()=>postedExpenseReport(companyId,companyName,locale)}/><button type="button" onClick={refresh} disabled={state.phase==='LOADING'}>{t('expenseRead.refresh')}</button></>}>
    <p className="suite-scope-note">{locale==='ar'?'تعرض القائمة صفحة مستندات، وليست إجماليات مالية للشركة. تصدير التقرير يشمل جميع الصفحات وفق نطاقه المحاسبي.':'This list is a document page, not Company financial totals. The complete report export includes all pages within its accounting scope.'}</p>
    {state.phase==='LOADING'&&<LoadingState>{t('expenseRead.loading')}</LoadingState>}
    {state.phase==='ERROR'&&<ErrorState onRetry={refresh} retryLabel={t('expenseRead.refresh')}>{t('expenseRead.error')}</ErrorState>}
    {state.phase==='READY'&&<>
     {state.rows.length===0&&<EmptyState>{t('expenseRead.empty')}</EmptyState>}
     <DataTable label={t('expenseRead.title')} className="expense-posted-table" columns={columns}>{state.rows.map(row=><tr key={row.id}>
      <td className="suite-date"><bdi>{sourceDatePresentation(row.expense_date,locale).label}</bdi></td><td className="suite-description"><TextCell value={row.description}/></td><td>{row.allocation_plan?(locale==='ar'?'تكلفة موزعة':'Allocated cost'):locale==='ar'?(row.project_id?'تكلفة مشروع':'مصروف تشغيلي'):(row.project_id?'Project cost':'Operating Expense')}</td><td><TextCell value={partyName(row.supplier_id)}/></td><td><TextCell value={row.allocation_plan?(locale==='ar'?'راجع التوزيعات':'See allocations'):projectName(row.project_id)}/></td><td className="suite-numeric"><bdi dir="ltr">{dashboardAED(row.gross_amount_minor)}</bdi></td><td className="expense-status"><StatusBadge status={row.status}>{t(`expenseRead.${row.status}`)}</StatusBadge></td><td className="suite-row-actions"><button type="button" onClick={()=>setOpened(row)}>{locale==='ar'?'التفاصيل والإجراءات':'Details & actions'}</button></td></tr>)}</DataTable>
      <nav className="suite-pagination" aria-label={t('expenseRead.pages')}><button type="button" disabled={page===0} onClick={()=>setPage(value=>value-1)}>{t('expenseRead.previous')}</button><span>{t('expenseRead.page',{page:page+1})}</span><button type="button" disabled={!state.hasNext} onClick={()=>setPage(value=>value+1)}>{t('expenseRead.next')}</button></nav>
    </>}
    </ContentSection></div>
    {opened&&<RecordDetailDrawer title={opened.description} onClose={()=>setOpened(null)}><section className="dw-record-section"><h3>{locale==='ar'?'المبلغ والدفع':'Amount and payment'}</h3><dl>{[[locale==='ar'?'مصدر الدفع الفعلي':'Actual payment source',opened.funding_mode==='CUSTODIAN'?partyName(opened.paid_by_party_id):master.phase==='READY'?master.treasuryAccounts.find(t=>t.id===opened.treasury_account_id)?.name??'—':'—'],[locale==='ar'?'الصافي':'Net',dashboardAED(opened.net_amount_minor)],[locale==='ar'?'الضريبة':'VAT',dashboardAED(opened.vat_amount_minor)],[locale==='ar'?'الإجمالي':'Gross',dashboardAED(opened.gross_amount_minor)]].map(([label,value])=><div key={label}><dt>{label}</dt><dd>{value}</dd></div>)}</dl></section>{(()=>{const row=state.phase==='READY'?state.rows.find(r=>r.id===opened.id)??opened:opened;return<>
        {row.status!=='DRAFT'&&<ExpenseCorrectionReview key={userId+companyId+role+row.id} expense={row} userId={userId} companyId={companyId} company={companyName} role={role}/>}<details className="mt-3"><summary className="cursor-pointer">{t("expenseRead.details")}</summary><dl className="mt-2 space-y-2 text-sm">
          {row.allocation_plan&&<div><dt>{"Shared allocation / تخصيص مشترك"}</dt><dd>{row.allocation_plan.destinations.map(d=><p key={d.project_id??'COMPANY'}><bdi>{d.project_id??'Company overhead / مصروفات الشركة'}</bdi> · {dashboardAED(d.amount_minor)} AED</p>)}</dd></div>}{(["id", "company_id", "project_id", "expense_category_id", "supplier_id", "treasury_account_id", "paid_by_party_id", "posted_journal_entry_id", "reversal_journal_entry_id", "invoice_number", "notes", "created_at", "created_by", "updated_at", "updated_by", "posted_at", "posted_by", "reversed_at", "reversed_by"] as const).map(field => <div key={field}><dt className="font-medium">{t(`expenseRead.${field}`)}</dt><dd className="whitespace-pre-wrap break-words"><bdi>{row[field] ?? t("expenseRead.absent")}</bdi></dd></div>)}
          <div><dt>{t("expenseRead.funding")}</dt><dd>{t(`expenseRead.${row.funding_mode}`)}</dd></div>
          <div><dt>{t("expenseRead.vat")}</dt><dd>{t(`expenseRead.${row.vat_mode}`)}</dd></div>
          <div><dt>{t("expenseRead.method")}</dt><dd>{t(`expenseRead.${row.payment_method}`)}</dd></div>
          <div><dt>{t("expenseRead.invoice")}</dt><dd>{t(row.has_tax_invoice ? "expenseRead.yes" : "expenseRead.no")}</dd></div>
        </dl></details>        {row.status==="REVERSED"&&canPostExpense(role)&&businessAccess==='FULL'&&<a className="mt-3 inline-flex rounded-lg border px-3 py-2 text-sm" href="#new-expense" onClick={()=>{const form=document.getElementById("new-expense");if(form instanceof HTMLDetailsElement)form.open=true;}}>{locale==="ar"?"إنشاء البديل المصحح":"Create corrected replacement"}</a>}
        {(canReverseExpense(role, row.status) || role === "ACCOUNTING_ADMIN") && <><div className="mt-3 flex flex-wrap gap-2">{row.status==="POSTED"&&[locale==="ar"?"تصحيح":"Correct",locale==="ar"?"عكس / إلغاء":"Reverse / Cancel"].map(label=><button key={label} className="rounded-lg border border-slate-300 px-3 py-2 text-sm" onClick={()=>{const target=document.getElementById(label===(locale==="ar"?"تصحيح":"Correct")?`expense-allocation-review-${row.id}`:`expense-correction-${row.id}`);if(target instanceof HTMLDetailsElement){target.open=true;target.scrollIntoView({block:"nearest"});}}}>{label}</button>)}</div><details id={`expense-correction-${row.id}`} className="mt-3"><summary className="cursor-pointer text-sm font-medium">{locale==="ar"?"خطوات التصحيح والعكس":"Correction & reversal steps"}</summary>{role==="ACCOUNTING_ADMIN"&&row.status==="POSTED"&&<p className="mt-3 text-sm text-blue-800">{locale==="ar"?"تغييرات المشروع أو التصنيف تتطلب مراجعة التصحيح. استخدم العكس بعد التحقق من المستند الأصلي وآثار النقد والضريبة والتسوية.":"Project or classification changes require correction review. Use reversal only after checking the original document, cash, VAT and settlement effects."}</p>}<p className="mt-2 text-sm text-slate-500">{locale==="ar"?"أكد العكس مع التاريخ والسبب. بعد نجاح العكس، أنشئ البديل المصحح عند الحاجة؛ يبقى المستند الأصلي محفوظاً.":"Confirm reversal with its date and reason. After confirmed reversal, create a corrected replacement when needed; the original document remains preserved."}</p><ExpenseReverseAction userId={userId} companyId={companyId} role={role} expense={row} onRefresh={refresh} /></details></> }      </>;})()}</RecordDetailDrawer>}
  </section>;
}
