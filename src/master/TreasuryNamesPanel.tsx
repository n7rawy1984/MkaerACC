import { TreasuryAccountsList } from "./AccountMasterLists";
import { useLayoutEffect, useRef, useState } from "react";
import { useAuth } from "../auth/AuthContext";
import { useT } from "../i18n/I18nContext";
import { TreasuryNameForm } from "./TreasuryNameForm";
import { useProductionMasterData } from "./productionMasterDataContext";
import type { ProductionTreasuryAccount } from "./masterTypes";

export function TreasuryNamesPanel() {
  const t = useT();
  const { state } = useAuth();
  const master = useProductionMasterData();
  const [editing, setEditing] = useState<ProductionTreasuryAccount | null>(null);
  const [actionId, setActionId] = useState<string | null>(null);
  const origin = useRef<HTMLButtonElement | null>(null);
  const restoreFocus = useRef(false);
  const feedback = useRef<HTMLDivElement>(null);
  const phase = master.treasuryNameMutation.phase;
  useLayoutEffect(() => {
    if (!editing && restoreFocus.current && origin.current?.isConnected && !origin.current.disabled) {
      origin.current.focus(); restoreFocus.current = false;
    }
  });
  useLayoutEffect(() => {
    if (phase === "ERROR" || phase === "REFRESH_ERROR") { feedback.current?.focus(); feedback.current?.scrollIntoView({ block: "nearest" }); }
  }, [phase]);
  if (master.phase !== "READY" || state.phase !== "TENANT_READY") return null;
  const canEdit = state.activeTenant.role === "ACCOUNTING_ADMIN";
  const blocked = phase === "PENDING" || phase === "ERROR" || phase === "REFRESH_ERROR";
  const close = () => { restoreFocus.current = true; setEditing(null); };
  const refresh = () => { close(); void master.refreshTreasuryAccounts(); };
  const message = <div ref={feedback} tabIndex={-1} className="mt-3 text-sm">
    {phase === "PENDING" && <p role="status">{t("treasuryName.pending")}</p>}
    {phase === "SAVED" && <p role="status">{t("treasuryName.saved")}</p>}
    {phase === "ERROR" && <p role="alert">{t(`treasuryName.${master.treasuryNameMutation.error ?? "uncertain"}`)} {t("treasuryName.refreshRequired")}</p>}
    {phase === "REFRESH_ERROR" && <p role="alert">{t("treasuryName.refreshError")}</p>}
    {(phase === "ERROR" || phase === "REFRESH_ERROR") && <button type="button" onClick={refresh} className="underline">{t("treasuryName.refresh")}</button>}
  </div>;
  return <div>
    <button type="button" disabled={phase === "PENDING"} onClick={refresh} className="mt-4 rounded-lg border px-3 py-2 text-sm">{t("treasuryName.refresh")}</button>
    {!master.treasuryAccounts.some(p => p.id === actionId) && message}
    <TreasuryAccountsList treasuryAccounts={master.treasuryAccounts} accounts={master.accounts} renderAction={(treasury) => <>
        {canEdit && <button type="button" disabled={blocked || !!editing} onClick={event => { origin.current = event.currentTarget; setActionId(treasury.id); setEditing(treasury); }} className="mt-3 rounded-lg border px-3 py-2 text-sm disabled:opacity-50">{t("treasuryName.edit")}</button>}
        {editing?.id === treasury.id && canEdit && <TreasuryNameForm treasury={editing} disabled={blocked} onCancel={close} onSave={async input => { if (await master.saveTreasuryName({ treasury: editing, input })) close(); }} />}
        {actionId === treasury.id && message}
      </>} />
  </div>;
}
