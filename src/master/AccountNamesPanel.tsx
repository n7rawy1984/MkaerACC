import { AccountsList } from "./AccountMasterLists";
import { useLayoutEffect, useRef, useState } from "react";
import { useAuth } from "../auth/AuthContext";
import { useT } from "../i18n/I18nContext";
import { AccountNameForm } from "./AccountNameForm";
import { useProductionMasterData } from "./productionMasterDataContext";
import type { ProductionAccount } from "./masterTypes";

export function AccountNamesPanel() {
  const t = useT();
  const { state } = useAuth();
  const master = useProductionMasterData();
  const [editing, setEditing] = useState<ProductionAccount | null>(null);
  const [actionId, setActionId] = useState<string | null>(null);
  const origin = useRef<HTMLButtonElement | null>(null);
  const restoreFocus = useRef(false);
  const feedback = useRef<HTMLDivElement>(null);
  const phase = master.accountNameMutation.phase;
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
  const refresh = () => { close(); void master.refreshAccounts(); };
  const message = <div ref={feedback} tabIndex={-1} className="mt-3 text-sm">
    {phase === "PENDING" && <p role="status">{t("accountName.pending")}</p>}
    {phase === "SAVED" && <p role="status">{t("accountName.saved")}</p>}
    {phase === "ERROR" && <p role="alert">{t(`accountName.${master.accountNameMutation.error ?? "uncertain"}`)} {t("accountName.refreshRequired")}</p>}
    {phase === "REFRESH_ERROR" && <p role="alert">{t("accountName.refreshError")}</p>}
    {(phase === "ERROR" || phase === "REFRESH_ERROR") && <button type="button" onClick={refresh} className="underline">{t("accountName.refresh")}</button>}
  </div>;
  return <div>
    <button type="button" disabled={phase === "PENDING"} onClick={refresh} className="mt-4 rounded-lg border px-3 py-2 text-sm">{t("accountName.refresh")}</button>
    {!master.accounts.some(p => p.id === actionId) && message}
    <AccountsList accounts={master.accounts} renderAction={(account) => <>
        {canEdit && <button type="button" disabled={blocked || !!editing} onClick={event => { origin.current = event.currentTarget; setActionId(account.id); setEditing(account); }} className="mt-3 rounded-lg border px-3 py-2 text-sm disabled:opacity-50">{t("accountName.edit")}</button>}
        {editing?.id === account.id && canEdit && <AccountNameForm account={editing} disabled={blocked} onCancel={close} onSave={async input => { if (await master.saveAccountName({ account: editing, input })) close(); }} />}
        {actionId === account.id && message}
      </>} />
  </div>;
}
