import { useState } from "react";
import { useAuth } from "../auth/AuthContext";
import { useT } from "../i18n/I18nContext";
import { useProductionMasterData } from "./productionMasterDataContext";
import { ExpenseCategoryForm } from "./ExpenseCategoryForm";
import type { ProductionExpenseCategory } from "./masterTypes";

export function ExpenseCategoriesList() {
  const t = useT();
  const { state } = useAuth();
  const master = useProductionMasterData();
  const [editing, setEditing] = useState<ProductionExpenseCategory | "new" | null>(null);
  const [statusTarget, setStatusTarget] = useState<ProductionExpenseCategory | null>(null);
  if (master.phase !== "READY" || state.phase !== "TENANT_READY") return null;
  const canManage = state.activeTenant.role === "ACCOUNTING_ADMIN";
  const phase = master.categoryMutation.phase;
  const blocked = phase === "PENDING" || phase === "ERROR" || phase === "REFRESH_ERROR";
  const button = "rounded-lg border border-slate-300 px-3 py-2 text-sm disabled:opacity-50";
  return <>
    <div className="mt-4 flex flex-wrap gap-2">
      {canManage && <button type="button" className={button} disabled={blocked} onClick={() => { setStatusTarget(null); setEditing("new"); }}>{t("categoryMutation.create")}</button>}
      <button type="button" className={button} disabled={phase === "PENDING"} onClick={() => { setEditing(null); setStatusTarget(null); void master.refreshExpenseCategories(); }}>{t("categoryMutation.refresh")}</button>
    </div>
    {phase === "PENDING" && <p role="status" className="mt-3 text-sm">{t("categoryMutation.pending")}</p>}
    {phase === "SAVED" && <p role="status" className="mt-3 text-sm text-green-800">{t("categoryMutation.saved")}</p>}
    {phase === "ERROR" && <p role="alert" className="mt-3 text-sm text-red-700">{t(`categoryMutation.${master.categoryMutation.error ?? "uncertain"}`)} {t("categoryMutation.refreshRequired")}</p>}
    {phase === "REFRESH_ERROR" && <p role="alert" className="mt-3 text-sm text-red-700">{t("categoryMutation.refreshError")}</p>}
    {canManage && editing && <ExpenseCategoryForm key={editing === "new" ? "new" : editing.id} category={editing === "new" ? null : editing} disabled={blocked} onCancel={() => setEditing(null)} onSave={async (input) => {
      const command = editing === "new" ? { kind: "create" as const, input } : { kind: "edit" as const, category: editing, input };
      if (await master.saveExpenseCategory(command)) setEditing(null);
    }} />}
    {canManage && statusTarget && <div className="mt-4 rounded-lg border border-amber-300 p-4">
      <p className="break-words">{statusTarget.code} · {statusTarget.name}</p>
      <p className="my-2 text-sm">{t(statusTarget.status === "ACTIVE" ? "categoryMutation.deactivateConfirm" : "categoryMutation.reactivateConfirm")}</p>
      <div className="flex gap-2"><button type="button" disabled={blocked} className={button} onClick={() => {
        void master.saveExpenseCategory({ kind: "status", category: statusTarget, status: statusTarget.status === "ACTIVE" ? "INACTIVE" : "ACTIVE" }).then((ok) => { if (ok) setStatusTarget(null); });
      }}>{t("categoryMutation.confirm")}</button><button type="button" className={button} onClick={() => setStatusTarget(null)}>{t("categoryMutation.close")}</button></div>
    </div>}
    {master.expenseCategories.length === 0 ? <p role="status" className="mt-4 text-sm text-slate-500">{t("productionMaster.categoriesEmpty")}</p> :
      <ul className="mt-5 divide-y divide-slate-200" aria-label={t("productionMaster.expenseCategories")}>
        {master.expenseCategories.map((category) => <li key={category.id} className="flex flex-wrap items-start justify-between gap-3 py-4">
          <div className="min-w-0 break-words"><p className="font-medium"><bdi>{category.code} · {category.name}</bdi></p>{category.description !== null && <p className="text-sm text-slate-500">{category.description}</p>}</div>
          <span className="text-sm">{t(`partyStatus.${category.status}`)}</span>
          {canManage && <div className="flex flex-wrap gap-2">
            <button type="button" className={button} disabled={blocked} onClick={() => { setStatusTarget(null); setEditing(category); }}>{t("categoryMutation.edit")}</button>
            <button type="button" className={button} disabled={blocked} onClick={() => { setEditing(null); setStatusTarget(category); }}>{t(category.status === "ACTIVE" ? "categoryMutation.deactivate" : "categoryMutation.reactivate")}</button>
          </div>}
        </li>)}
      </ul>}
  </>;
}
