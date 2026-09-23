import { TreasuryExpensePost } from "./TreasuryExpensePost";
import { canPostExpense } from "./expensePostRepository";
import { ExpenseReverseAction } from "./ExpenseReverseAction";
import { canReverseExpense } from "./expenseReverseRepository";
import { useState } from "react";
import { useAuth } from "../auth/AuthContext";
import { useT } from "../i18n/I18nContext";
import { getSupabaseClient } from "../lib/supabase";
import { displayMinor } from "./expenseRepository";
import { useExpenseRead } from "./useExpenseRead";

export function ExpenseReadPanel() {
  const { state } = useAuth();
  if (state.phase !== "TENANT_READY") return null;
  return <ExpenseReadContent key={`${state.profile.userId}:${state.activeTenant.companyId}:${state.activeTenant.role}`} userId={state.profile.userId} companyId={state.activeTenant.companyId} role={state.activeTenant.role} />;
}
export function ExpenseReadContent({ userId, companyId, role }: { userId: string; companyId: string; role: string }) {
  const t = useT();
  const [page, setPage] = useState(0);
  const [revision, setRevision] = useState(0);
  const state = useExpenseRead(getSupabaseClient(), userId, companyId, role, page, revision);
  const refresh = () => { setPage(0); setRevision(value => value + 1); };
  return <section className="min-w-0 rounded-2xl border border-slate-200 bg-white p-6 shadow-sm">
    <h2 className="text-2xl font-semibold">{t("expenseRead.title")}</h2>
    <p className="mt-3 text-sm text-slate-500">{t("expenseRead.scope")}</p>
    {canPostExpense(role) && <TreasuryExpensePost userId={userId} companyId={companyId} role={role} onPosted={refresh} />}
    <button type="button" onClick={refresh} disabled={state.phase === "LOADING"} className="mt-4 rounded-lg border px-3 py-2 disabled:opacity-50">{t("expenseRead.refresh")}</button>
    {state.phase === "LOADING" && <p role="status" className="mt-4">{t("expenseRead.loading")}</p>}
    {state.phase === "ERROR" && <p role="alert" className="mt-4 text-red-800">{t("expenseRead.error")}</p>}
    {state.phase === "READY" && <>
      {state.rows.length === 0 && <p role="status" className="mt-4">{t("expenseRead.empty")}</p>}
      <ul className="mt-5 divide-y divide-slate-200" aria-label={t("expenseRead.title")}>{state.rows.map(row => <li key={row.id} className="min-w-0 break-words py-4">
        <div className="flex flex-wrap justify-between gap-3"><h3 className="font-semibold"><bdi>{row.expense_reference}</bdi></h3><span>{t(`expenseRead.${row.status}`)}</span></div>
        <p><bdi>{row.expense_date}</bdi></p><p className="whitespace-pre-wrap"><bdi>{row.description}</bdi></p>
        <dl className="mt-3 grid gap-3 sm:grid-cols-3">{(["net_amount_minor", "vat_amount_minor", "gross_amount_minor"] as const).map(field => <div key={field}><dt>{t(`expenseRead.${field}`)}</dt><dd><bdi>{displayMinor(row[field])} AED</bdi></dd></div>)}</dl>
        <details className="mt-3"><summary className="cursor-pointer">{t("expenseRead.details")}</summary><dl className="mt-2 space-y-2 text-sm">
          {(["id", "company_id", "project_id", "expense_category_id", "supplier_id", "treasury_account_id", "paid_by_party_id", "posted_journal_entry_id", "reversal_journal_entry_id", "invoice_number", "notes", "created_at", "created_by", "updated_at", "updated_by", "posted_at", "posted_by", "reversed_at", "reversed_by"] as const).map(field => <div key={field}><dt className="font-medium">{t(`expenseRead.${field}`)}</dt><dd className="whitespace-pre-wrap break-words"><bdi>{row[field] ?? t("expenseRead.absent")}</bdi></dd></div>)}
          <div><dt>{t("expenseRead.funding")}</dt><dd>{t(`expenseRead.${row.funding_mode}`)}</dd></div>
          <div><dt>{t("expenseRead.vat")}</dt><dd>{t(`expenseRead.${row.vat_mode}`)}</dd></div>
          <div><dt>{t("expenseRead.method")}</dt><dd>{t(`expenseRead.${row.payment_method}`)}</dd></div>
          <div><dt>{t("expenseRead.invoice")}</dt><dd>{t(row.has_tax_invoice ? "expenseRead.yes" : "expenseRead.no")}</dd></div>
        </dl></details>
        {(canReverseExpense(role, row.status) || role === "ACCOUNTING_ADMIN") && <ExpenseReverseAction userId={userId} companyId={companyId} role={role} expense={row} onRefresh={refresh} />}
      </li>)}</ul>
      <nav className="mt-4 flex flex-wrap gap-3" aria-label={t("expenseRead.pages")}>
        <button type="button" disabled={page === 0} onClick={() => setPage(value => value - 1)} className="rounded-lg border px-3 py-2 disabled:opacity-50">{t("expenseRead.previous")}</button>
        <span className="p-2">{t("expenseRead.page", { page: page + 1 })}</span>
        <button type="button" disabled={!state.hasNext} onClick={() => setPage(value => value + 1)} className="rounded-lg border px-3 py-2 disabled:opacity-50">{t("expenseRead.next")}</button>
      </nav>
    </>}
  </section>;
}
