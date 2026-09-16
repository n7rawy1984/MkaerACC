import { useLayoutEffect, useRef, useState } from "react";
import { useAuth } from "../auth/AuthContext";
import { useT } from "../i18n/I18nContext";
import { CompanyProfileForm } from "./CompanyProfileForm";
import { useProductionMasterData } from "./productionMasterDataContext";
import type { ProductionCompanyProfile } from "./masterTypes";

export function CompanyProfilePanel() {
  const t = useT();
  const { state } = useAuth();
  const master = useProductionMasterData();
  const [editing, setEditing] = useState<ProductionCompanyProfile | null>(null);
  const editButton = useRef<HTMLButtonElement>(null);
  const restoreFocus = useRef(false);
  useLayoutEffect(() => {
    if (!editing && restoreFocus.current && editButton.current && !editButton.current.disabled) {
      editButton.current.focus();
      restoreFocus.current = false;
    }
  });
  if (master.phase !== "READY" || state.phase !== "TENANT_READY") return null;
  const canEdit = master.company.status === "ACTIVE"
    && (state.activeTenant.role === "ACCOUNTING_ADMIN" || state.activeTenant.role === "SYSTEM_ADMIN");
  const { phase, error } = master.companyProfileMutation;
  const blocked = phase === "PENDING" || phase === "ERROR" || phase === "REFRESH_ERROR";
  const close = () => { restoreFocus.current = true; setEditing(null); };
  return <div className="mt-4">
    <p className="font-medium">{master.company.code} · {master.company.name}</p>
    <dl className="mt-3 space-y-3">
      {(["legal_name", "trn", "address", "notes"] as const).map((field) => <div key={field}>
        <dt className="text-sm text-slate-500">{t(`companyProfile.${field}`)}</dt>
        <dd className="whitespace-pre-wrap break-words text-sm">{(field === "legal_name" ? master.company.legalName : master.company[field]) ?? t("companyProfile.empty")}</dd>
      </div>)}
    </dl>
    <div className="mt-4 flex flex-wrap gap-3">
      {canEdit && <button ref={editButton} type="button" disabled={blocked || !!editing} onClick={() => setEditing(master.company)} className="rounded-lg border border-slate-300 px-3 py-2 text-sm disabled:opacity-50">{t("companyProfile.edit")}</button>}
      <button type="button" disabled={phase === "PENDING"} onClick={() => { setEditing(null); void master.refreshCompanyProfile(); }} className="rounded-lg border border-slate-300 px-3 py-2 text-sm disabled:opacity-50">{t("companyProfile.refresh")}</button>
    </div>
    {phase === "PENDING" && <p role="status" className="mt-3 text-sm">{t("companyProfile.pending")}</p>}
    {phase === "SAVED" && <p role="status" className="mt-3 text-sm text-green-700">{t("companyProfile.saved")}</p>}
    {phase === "ERROR" && <p role="alert" className="mt-3 text-sm text-red-700">{t(`companyProfile.${error ?? "uncertain"}`)} {t("companyProfile.refreshRequired")}</p>}
    {phase === "REFRESH_ERROR" && <p role="alert" className="mt-3 text-sm text-red-700">{t("companyProfile.refreshError")}</p>}
    {canEdit && editing && <CompanyProfileForm company={editing} disabled={blocked} onCancel={close} onSave={async (input) => {
      if (await master.saveCompanyProfile({ company: editing, input })) close();
    }} />}
  </div>;
}
