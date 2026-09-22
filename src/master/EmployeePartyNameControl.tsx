import { useLayoutEffect, useRef, useState } from "react";
import { useAuth } from "../auth/AuthContext";
import { useT } from "../i18n/I18nContext";
import { EmployeePartyNameForm } from "./EmployeePartyNameForm";
import { useProductionMasterData } from "./productionMasterDataContext";
import type { ProductionParty } from "./masterTypes";

export function EmployeePartyNameControl({ party, selected, onSelect }: { party: ProductionParty; selected: boolean; onSelect: () => void }) {
  const t = useT();
  const { state } = useAuth();
  const master = useProductionMasterData();
  const [editing, setEditing] = useState<ProductionParty | null>(null);
  const origin = useRef<HTMLButtonElement | null>(null);
  const restoreFocus = useRef(false);
  const feedback = useRef<HTMLDivElement>(null);
  const phase = master.employeePartyNameMutation.phase;
  useLayoutEffect(() => {
    if (!editing && restoreFocus.current && origin.current?.isConnected && !origin.current.disabled) {
      origin.current.focus(); restoreFocus.current = false;
    }
  });
  useLayoutEffect(() => {
    if (selected && (phase === "ERROR" || phase === "REFRESH_ERROR")) { feedback.current?.focus(); feedback.current?.scrollIntoView({ block: "nearest" }); }
  }, [phase, selected]);
  if (master.phase !== "READY" || state.phase !== "TENANT_READY") return null;
  const canEdit = party.type === "EMPLOYEE" && state.activeTenant.role === "ACCOUNTING_ADMIN";
  const blocked = master.subcontractorPartyNameMutation.phase === "PENDING" || master.supplierMutation.phase === "PENDING" || master.ownerPartyNameMutation.phase === "PENDING" || master.custodianPartyNameMutation.phase === "PENDING" || master.otherPartyNameMutation.phase === "PENDING" || phase === "PENDING" || phase === "ERROR" || phase === "REFRESH_ERROR";
  const close = () => { restoreFocus.current = true; setEditing(null); };
  const refresh = () => { close(); void master.refreshEmployeePartyNames(); };
  const message = <div ref={feedback} tabIndex={-1} className="mt-3 text-sm">
    {phase === "PENDING" && <p role="status">{t("employeePartyName.pending")}</p>}
    {phase === "SAVED" && <p role="status">{t("employeePartyName.saved")}</p>}
    {phase === "ERROR" && <p role="alert">{t(`employeePartyName.${master.employeePartyNameMutation.error ?? "uncertain"}`)} {t("employeePartyName.refreshRequired")}</p>}
    {phase === "REFRESH_ERROR" && <p role="alert">{t("employeePartyName.refreshError")}</p>}
    {(phase === "ERROR" || phase === "REFRESH_ERROR") && <button type="button" onClick={refresh} className="underline">{t("employeePartyName.refresh")}</button>}
  </div>;
  if (!canEdit) return null;
  return <div>
    <button type="button" disabled={blocked || (selected && !!editing)} onClick={event => { origin.current = event.currentTarget; onSelect(); setEditing(party); }} className="mt-3 rounded-lg border px-3 py-2 text-sm disabled:opacity-50">{t("employeePartyName.edit")}</button>
    {selected && editing && <EmployeePartyNameForm party={editing} disabled={blocked} onCancel={close} onSave={async input => { if (await master.saveEmployeePartyName({ party: editing, input })) close(); }} />}
    {selected && message}
  </div>;
}
