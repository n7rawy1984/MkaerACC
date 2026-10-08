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
import { displayMinor } from "./expenseRepository";
import { useExpenseRead } from "./useExpenseRead";

export function ExpenseReadPanel() {
  const { state } = useAuth();
  if (state.phase !== "TENANT_READY") return null;
  return <ExpenseReadContent key={`${state.profile.userId}:${state.activeTenant.companyId}:${state.activeTenant.role}`} userId={state.profile.userId} companyId={state.activeTenant.companyId} role={state.activeTenant.role} />;
}
export function ExpenseReadContent({ userId, companyId, role }: { userId: string; companyId: string; role: string }) {
  const auth=useAuth();const companyName=auth.state.phase==="TENANT_READY"?auth.state.activeTenant.companyName:"";
  const t = useT(); const {locale}=useI18n();
  const [page, setPage] = useState(0);
  const [revision, setRevision] = useState(0);
  const state = useExpenseRead(getSupabaseClient(), userId, companyId, role, page, revision);
  const refresh = () => { setPage(0); setRevision(value => value + 1); };
  return <section className="min-w-0 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
    <h2 className="text-2xl font-semibold">{locale==="ar"?"المصروفات والحركات المالية":"Expenses & Financial Transactions"}</h2>
    <p className="mt-3 text-sm text-slate-500">{t("expenseRead.scope")}</p><HistoricalImports recordType="GENERAL" onPosted={refresh}/>
    {canPostExpense(role) && <details open={window.location.hash==="#new-expense"} id="new-expense" className="mt-6 rounded-xl border p-4"><summary className="cursor-pointer font-semibold">{locale==="ar"?"مصروف جديد / بديل مصحح":"New Expense / corrected replacement"}</summary><p className="mt-3 text-sm text-slate-500">{locale==="ar"?"للتصحيح، اعكس المستند الأصلي أولاً ثم أدخل البديل بعد مراجعة الأثر النقدي والضريبي.":"For a correction, reverse the original document first, then enter its replacement after reviewing cash and VAT effects."}</p><TreasuryExpensePost userId={userId} companyId={companyId} role={role} onPosted={refresh} /></details>}
    {canPostExpense(role) && <details id="supplier-credit" open={window.location.hash==="#supplier-credit"} className="mt-4 rounded-xl border p-4"><summary className="cursor-pointer font-semibold">{locale==="ar"?"مصروف آجل على مورد":"New Supplier Credit Expense"}</summary><SupplierCreditExpensePost userId={userId} companyId={companyId} role={role} onPosted={refresh} /></details>}
    <h2 className="mt-8 text-xl font-semibold">{locale==="ar"?"المصروفات المرحلة والتصحيح":"Posted Expenses & corrections"}</h2>
    <ReportExport build={()=>postedExpenseReport(companyId,companyName,locale)}/>
    <button type="button" onClick={refresh} disabled={state.phase === "LOADING"} className="mt-4 rounded-lg border px-3 py-2 disabled:opacity-50">{t("expenseRead.refresh")}</button>
    {state.phase === "LOADING" && <p role="status" className="mt-4">{t("expenseRead.loading")}</p>}
    {state.phase === "ERROR" && <p role="alert" className="mt-4 text-red-800">{t("expenseRead.error")}</p>}
    {state.phase === "READY" && <>
      {state.rows.length === 0 && <p role="status" className="mt-4">{t("expenseRead.empty")}</p>}
      <ul className="mt-5 divide-y divide-slate-200" aria-label={t("expenseRead.title")}>{state.rows.map(row => <li key={row.id} className="min-w-0 break-words py-4">
        <div className="flex flex-wrap justify-between gap-3"><h3 className="font-semibold"><bdi dir="ltr">{row.expense_reference}</bdi></h3><span>{t(`expenseRead.${row.status}`)}</span></div>
        <p><bdi dir="ltr">{row.expense_date}</bdi></p><p className="whitespace-pre-wrap"><bdi>{row.description}</bdi></p>
        <dl className="mt-3 grid gap-3 sm:grid-cols-3">{(["net_amount_minor", "vat_amount_minor", "gross_amount_minor"] as const).map(field => <div key={field}><dt>{t(`expenseRead.${field}`)}</dt><dd><bdi>{displayMinor(row[field])} AED</bdi></dd></div>)}</dl>
        <details className="mt-3"><summary className="cursor-pointer">{t("expenseRead.details")}</summary><dl className="mt-2 space-y-2 text-sm">
          {(["id", "company_id", "project_id", "expense_category_id", "supplier_id", "treasury_account_id", "paid_by_party_id", "posted_journal_entry_id", "reversal_journal_entry_id", "invoice_number", "notes", "created_at", "created_by", "updated_at", "updated_by", "posted_at", "posted_by", "reversed_at", "reversed_by"] as const).map(field => <div key={field}><dt className="font-medium">{t(`expenseRead.${field}`)}</dt><dd className="whitespace-pre-wrap break-words"><bdi>{row[field] ?? t("expenseRead.absent")}</bdi></dd></div>)}
          <div><dt>{t("expenseRead.funding")}</dt><dd>{t(`expenseRead.${row.funding_mode}`)}</dd></div>
          <div><dt>{t("expenseRead.vat")}</dt><dd>{t(`expenseRead.${row.vat_mode}`)}</dd></div>
          <div><dt>{t("expenseRead.method")}</dt><dd>{t(`expenseRead.${row.payment_method}`)}</dd></div>
          <div><dt>{t("expenseRead.invoice")}</dt><dd>{t(row.has_tax_invoice ? "expenseRead.yes" : "expenseRead.no")}</dd></div>
        </dl></details>
        {role==="ACCOUNTING_ADMIN"&&row.status==="POSTED"&&<p className="mt-3 text-sm text-blue-800">{locale==="ar"?"للتصحيح: اعكس أدناه، ثم أنشئ المصروف البديل من نموذج مصروف جديد.":"To correct: reverse below, then create the replacement using New Expense."}</p>}{row.status==="REVERSED"&&canPostExpense(role)&&<a className="mt-3 inline-flex rounded-lg border px-3 py-2 text-sm" href="#new-expense" onClick={()=>{const form=document.getElementById("new-expense");if(form instanceof HTMLDetailsElement)form.open=true;}}>{locale==="ar"?"إنشاء البديل المصحح":"Create corrected replacement"}</a>}
        {(canReverseExpense(role, row.status) || role === "ACCOUNTING_ADMIN") && <><div className="mt-3 flex flex-wrap gap-2">{row.status==="POSTED"&&[locale==="ar"?"تصحيح":"Correct",locale==="ar"?"عكس / إلغاء":"Reverse / Cancel"].map(label=><button key={label} className="rounded-lg border border-slate-300 px-3 py-2 text-sm" onClick={()=>{const target=document.getElementById(`expense-correction-${row.id}`);if(target instanceof HTMLDetailsElement){target.open=true;target.scrollIntoView({block:"nearest"});}}}>{label}</button>)}</div><details id={`expense-correction-${row.id}`} className="mt-3"><summary className="cursor-pointer text-sm font-medium">{locale==="ar"?"خطوات التصحيح والعكس":"Correction & reversal steps"}</summary><p className="mt-2 text-sm text-slate-500">{locale==="ar"?"أكد العكس مع التاريخ والسبب. بعد نجاح العكس، أنشئ البديل المصحح عند الحاجة؛ يبقى المستند الأصلي محفوظاً.":"Confirm reversal with its date and reason. After confirmed reversal, create a corrected replacement when needed; the original document remains preserved."}</p><ExpenseReverseAction userId={userId} companyId={companyId} role={role} expense={row} onRefresh={refresh} /></details></> }
      </li>)}</ul>
      <nav className="mt-4 flex flex-wrap gap-3" aria-label={t("expenseRead.pages")}>
        <button type="button" disabled={page === 0} onClick={() => setPage(value => value - 1)} className="rounded-lg border px-3 py-2 disabled:opacity-50">{t("expenseRead.previous")}</button>
        <span className="p-2">{t("expenseRead.page", { page: page + 1 })}</span>
        <button type="button" disabled={!state.hasNext} onClick={() => setPage(value => value + 1)} className="rounded-lg border px-3 py-2 disabled:opacity-50">{t("expenseRead.next")}</button>
      </nav>
    </>}
  </section>;
}
