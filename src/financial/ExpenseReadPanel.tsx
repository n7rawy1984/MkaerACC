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
import { useState } from "react";
import { useAuth } from "../auth/AuthContext";
import { useI18n, useT } from "../i18n/I18nContext";
import { getSupabaseClient } from "../lib/supabase";
import {dashboardAED} from '../dashboard/dashboardSummary';
import {sourceDatePresentation} from '../historical/sourceDatePresentation';
import {ContentSection,DataTable,StatusBadge,FinancialSummaryCard,LoadingState,ErrorState,EmptyState,ExpandableText} from '../workspace/workspaceUi';
import {useWorkspaceUiText} from '../workspace/useWorkspaceUiText';
import {expensePageSummary} from '../workspace/expensePagePresentation';
import { useExpenseRead } from "./useExpenseRead";

export function ExpenseReadPanel() {
  const { state } = useAuth();
  if (state.phase !== "TENANT_READY") return null;
  return <ExpenseReadContent key={`${state.profile.userId}:${state.activeTenant.companyId}:${state.activeTenant.role}`} userId={state.profile.userId} companyId={state.activeTenant.companyId} role={state.activeTenant.role} />;
}
export function ExpenseReadContent({ userId, companyId, role }: { userId: string; companyId: string; role: string }) {
  const auth=useAuth();const companyName=auth.state.phase==="TENANT_READY"?auth.state.activeTenant.companyName:"";
  const t = useT(); const {locale}=useI18n();const u=useWorkspaceUiText();const businessAccess=workspaceBusinessAccess(useWorkspaceSubscription(),companyId);
  const [page, setPage] = useState(0);
  const [revision, setRevision] = useState(0);
  const state = useExpenseRead(getSupabaseClient(), userId, companyId, role, page, revision);
  const refresh = () => { setPage(0); setRevision(value => value + 1); };
  const summary=state.phase==='READY'?expensePageSummary(state.rows):null;
  const amountState=state.phase==='LOADING'?'LOADING':state.phase==='ERROR'?'ERROR':null;
  const columns=[{key:'reference',title:u('reference')},{key:'date',title:u('date')},{key:'description',title:u('description')},{key:'status',title:t('common.status')},...(['net_amount_minor','vat_amount_minor','gross_amount_minor'] as const).map(key=>({key,title:t(`expenseRead.${key}`),numeric:true})),{key:'actions',title:u('viewDetails')}];
  return <section className="expenses-workspace">
    <nav className="suite-view-switch" aria-label={locale==='ar'?'أقسام المصروفات':'Expense sections'}><a href="#expense-source-review">{u('sources')}</a><a href="#expense-posted-register">{u('posted')}</a>{canPostExpense(role)&&businessAccess==='FULL'&&<a href="#new-expense" onClick={()=>{const d=document.getElementById('new-expense');if(d instanceof HTMLDetailsElement)d.open=true;}}>{u('entry')}</a>}</nav>
    {canPostExpense(role)&&businessAccess!=='FULL'&&<p role="status" className="suite-scope-note">{u(businessAccess==='UNKNOWN'?'unverified':'renew')}</p>}
    {canPostExpense(role)&&businessAccess==='FULL'&&<ContentSection title={u('entry')} className="expense-entry-forms">
    {canPostExpense(role) && <details open={window.location.hash==="#new-expense"} id="new-expense" className="mt-6 rounded-xl border p-4"><summary className="cursor-pointer font-semibold">{locale==="ar"?"مصروف جديد / بديل مصحح":"New Expense / corrected replacement"}</summary><p className="mt-3 text-sm text-slate-500">{locale==="ar"?"للتصحيح، اعكس المستند الأصلي أولاً ثم أدخل البديل بعد مراجعة الأثر النقدي والضريبي.":"For a correction, reverse the original document first, then enter its replacement after reviewing cash and VAT effects."}</p><TreasuryExpensePost userId={userId} companyId={companyId} role={role} onPosted={refresh} /></details>}
    {canPostExpense(role) && <details id="supplier-credit" open={window.location.hash==="#supplier-credit"} className="mt-4 rounded-xl border p-4"><summary className="cursor-pointer font-semibold">{locale==="ar"?"مصروف آجل على مورد":"New Supplier Credit Expense"}</summary><SupplierCreditExpensePost userId={userId} companyId={companyId} role={role} onPosted={refresh} /></details>}
    </ContentSection>}
    <ContentSection id="expense-source-review"><HistoricalImports recordType="GENERAL" onPosted={refresh}/></ContentSection>
    <ContentSection id="expense-posted-register" title={locale==='ar'?'المصروفات المرحلة والتصحيح':'Posted Expenses & corrections'} description={u('registerNote')} actions={<><ReportExport build={()=>postedExpenseReport(companyId,companyName,locale)}/><button type="button" onClick={refresh} disabled={state.phase==='LOADING'}>{t('expenseRead.refresh')}</button></>}>
    <div role="group" className="expense-page-summary" aria-label={u('pageScope')}>
      <FinancialSummaryCard label={u('postedCount')} value={summary?String(summary.count):state.phase==='LOADING'?t('expenseRead.loading'):'—'} state={amountState??(summary?.count===0?'VERIFIED_ZERO':'AVAILABLE')} description={u('pageScope')}/>
      <FinancialSummaryCard label={u('net')} value={summary?dashboardAED(summary.net):state.phase==='LOADING'?t('expenseRead.loading'):'—'} state={amountState??(summary?.net==='0'?'VERIFIED_ZERO':'AVAILABLE')} description={u('pageScope')}/>
      <FinancialSummaryCard label={u('gross')} value={summary?dashboardAED(summary.gross):state.phase==='LOADING'?t('expenseRead.loading'):'—'} state={amountState??(summary?.gross==='0'?'VERIFIED_ZERO':'AVAILABLE')} description={u('pageScope')}/>
    </div><p className="suite-scope-note">{u('pageHint')}</p>
    {state.phase==='LOADING'&&<LoadingState>{t('expenseRead.loading')}</LoadingState>}
    {state.phase==='ERROR'&&<ErrorState onRetry={refresh} retryLabel={t('expenseRead.refresh')}>{t('expenseRead.error')}</ErrorState>}
    {state.phase==='READY'&&<>
     {state.rows.length===0&&<EmptyState>{t('expenseRead.empty')}</EmptyState>}
     <DataTable label={t('expenseRead.title')} className="expense-posted-table" columns={columns}>{state.rows.map(row=><tr key={row.id}>
      <td className="suite-reference"><bdi dir="ltr">{row.expense_reference}</bdi></td><td className="suite-date"><bdi>{sourceDatePresentation(row.expense_date,locale).label}</bdi></td><td className="suite-description"><ExpandableText text={row.description} label={u('expandDescription')}/></td><td><StatusBadge status={row.status}>{t(`expenseRead.${row.status}`)}</StatusBadge></td>
      {(['net_amount_minor','vat_amount_minor','gross_amount_minor'] as const).map(field=><td key={field} className="suite-numeric"><bdi dir="ltr">{dashboardAED(row[field])}</bdi></td>)}
      <td className="suite-row-actions">
        <details className="mt-3"><summary className="cursor-pointer">{t("expenseRead.details")}</summary><dl className="mt-2 space-y-2 text-sm">
          {(["id", "company_id", "project_id", "expense_category_id", "supplier_id", "treasury_account_id", "paid_by_party_id", "posted_journal_entry_id", "reversal_journal_entry_id", "invoice_number", "notes", "created_at", "created_by", "updated_at", "updated_by", "posted_at", "posted_by", "reversed_at", "reversed_by"] as const).map(field => <div key={field}><dt className="font-medium">{t(`expenseRead.${field}`)}</dt><dd className="whitespace-pre-wrap break-words"><bdi>{row[field] ?? t("expenseRead.absent")}</bdi></dd></div>)}
          <div><dt>{t("expenseRead.funding")}</dt><dd>{t(`expenseRead.${row.funding_mode}`)}</dd></div>
          <div><dt>{t("expenseRead.vat")}</dt><dd>{t(`expenseRead.${row.vat_mode}`)}</dd></div>
          <div><dt>{t("expenseRead.method")}</dt><dd>{t(`expenseRead.${row.payment_method}`)}</dd></div>
          <div><dt>{t("expenseRead.invoice")}</dt><dd>{t(row.has_tax_invoice ? "expenseRead.yes" : "expenseRead.no")}</dd></div>
        </dl></details>        {row.status==="REVERSED"&&canPostExpense(role)&&businessAccess==='FULL'&&<a className="mt-3 inline-flex rounded-lg border px-3 py-2 text-sm" href="#new-expense" onClick={()=>{const form=document.getElementById("new-expense");if(form instanceof HTMLDetailsElement)form.open=true;}}>{locale==="ar"?"إنشاء البديل المصحح":"Create corrected replacement"}</a>}
        {(canReverseExpense(role, row.status) || role === "ACCOUNTING_ADMIN") && <><div className="mt-3 flex flex-wrap gap-2">{row.status==="POSTED"&&[locale==="ar"?"تصحيح":"Correct",locale==="ar"?"عكس / إلغاء":"Reverse / Cancel"].map(label=><button key={label} className="rounded-lg border border-slate-300 px-3 py-2 text-sm" onClick={()=>{const target=document.getElementById(`expense-correction-${row.id}`);if(target instanceof HTMLDetailsElement){target.open=true;target.scrollIntoView({block:"nearest"});}}}>{label}</button>)}</div><details id={`expense-correction-${row.id}`} className="mt-3"><summary className="cursor-pointer text-sm font-medium">{locale==="ar"?"خطوات التصحيح والعكس":"Correction & reversal steps"}</summary>{role==="ACCOUNTING_ADMIN"&&row.status==="POSTED"&&<p className="mt-3 text-sm text-blue-800">{locale==="ar"?"للتصحيح: اعكس أدناه، ثم أنشئ المصروف البديل من نموذج مصروف جديد.":"To correct: reverse below, then create the replacement using New Expense."}</p>}<p className="mt-2 text-sm text-slate-500">{locale==="ar"?"أكد العكس مع التاريخ والسبب. بعد نجاح العكس، أنشئ البديل المصحح عند الحاجة؛ يبقى المستند الأصلي محفوظاً.":"Confirm reversal with its date and reason. After confirmed reversal, create a corrected replacement when needed; the original document remains preserved."}</p><ExpenseReverseAction userId={userId} companyId={companyId} role={role} expense={row} onRefresh={refresh} /></details></> }      </td></tr>)}</DataTable>
      <nav className="suite-pagination" aria-label={t('expenseRead.pages')}><button type="button" disabled={page===0} onClick={()=>setPage(value=>value-1)}>{t('expenseRead.previous')}</button><span>{t('expenseRead.page',{page:page+1})}</span><button type="button" disabled={!state.hasNext} onClick={()=>setPage(value=>value+1)}>{t('expenseRead.next')}</button></nav>
    </>}
    </ContentSection>
  </section>;
}
