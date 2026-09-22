import { OtherPartyNameControl } from "./OtherPartyNameControl";
import { useLayoutEffect, useRef, useState } from "react";
import { useAuth } from "../auth/AuthContext";
import { useT } from "../i18n/I18nContext";
import { useProductionMasterData } from "./productionMasterDataContext";
import { SupplierPartyForm } from "./SupplierPartyForm";
import type { ProductionParty } from "./masterTypes";

export function PartiesList() {
  const t = useT();
  const { state } = useAuth();
  const master = useProductionMasterData();
  const [editing, setEditing] = useState<ProductionParty | "new" | null>(null);
  const [otherActionId, setOtherActionId] = useState<string | null>(null);
  const [statusTarget, setStatusTarget] = useState<ProductionParty | null>(null);
  const confirmation = useRef<HTMLDivElement>(null);
  const feedbackPanel = useRef<HTMLDivElement>(null);
  const returnFocus = useRef<HTMLButtonElement | null>(null);
  useLayoutEffect(() => {
    if (statusTarget && confirmation.current) {
      confirmation.current.focus({ preventScroll: true });
      confirmation.current.scrollIntoView({ block: "nearest" });
    } else if (!editing && !statusTarget && returnFocus.current?.isConnected) {
      returnFocus.current.focus({ preventScroll: true });
      returnFocus.current.scrollIntoView({ block: "nearest" });
      returnFocus.current = null;
    }
  }, [editing, statusTarget]);
  useLayoutEffect(() => {
    if (master.supplierMutation.phase === "ERROR" || master.supplierMutation.phase === "REFRESH_ERROR") {
      feedbackPanel.current?.focus({ preventScroll: true });
      feedbackPanel.current?.scrollIntoView({ block: "nearest" });
    }
  }, [master.supplierMutation.phase]);
  if (master.phase !== "READY" || state.phase !== "TENANT_READY") return null;
  const canManage = state.activeTenant.role === "ACCOUNTING_ADMIN" || state.activeTenant.role === "PROCUREMENT";
  const phase = master.supplierMutation.phase;
  const blocked = master.otherPartyNameMutation.phase === "PENDING" || phase === "PENDING" || phase === "ERROR" || phase === "REFRESH_ERROR";
  const button = "rounded-lg border border-slate-300 px-3 py-2 text-sm disabled:opacity-50";
  const refreshParties = () => { setEditing(null); setStatusTarget(null); setOtherActionId(null); void (master.otherPartyNameMutation.phase === "ERROR" || master.otherPartyNameMutation.phase === "REFRESH_ERROR" ? master.refreshOtherPartyNames() : master.refreshParties()); };
  const feedback = <div ref={feedbackPanel} tabIndex={-1}>
    {phase === "PENDING" && <p role="status" className="mt-3 text-sm">{t("supplierMutation.pending")}</p>}
    {phase === "SAVED" && <p role="status" className="mt-3 text-sm text-green-800">{t("supplierMutation.saved")}</p>}
    {phase === "ERROR" && <p role="alert" className="mt-3 text-sm text-red-700">{t(`supplierMutation.${master.supplierMutation.error ?? "uncertain"}`)} {t("supplierMutation.refreshRequired")}</p>}
    {phase === "REFRESH_ERROR" && <p role="alert" className="mt-3 text-sm text-red-700">{t("supplierMutation.refreshError")}</p>}
    {(phase === "ERROR" || phase === "REFRESH_ERROR") && (editing || statusTarget) && <button type="button" className={button} onClick={refreshParties}>{t("supplierMutation.refresh")}</button>}
  </div>;
  return <>
    <div className="mt-4 flex flex-wrap gap-2">
      {canManage && <button type="button" className={button} disabled={blocked} onClick={(event) => { returnFocus.current = event.currentTarget; setStatusTarget(null); setEditing("new"); }}>{t("supplierMutation.create")}</button>}
      <button type="button" className={button} disabled={phase === "PENDING" || master.otherPartyNameMutation.phase === "PENDING"} onClick={refreshParties}>{t("supplierMutation.refresh")}</button>
    </div>
    {!otherActionId && master.otherPartyNameMutation.phase === "ERROR" && <p role="alert" className="mt-3 text-sm">{t(`otherPartyName.${master.otherPartyNameMutation.error ?? "uncertain"}`)} {t("otherPartyName.refreshRequired")}</p>}
    {!otherActionId && master.otherPartyNameMutation.phase === "REFRESH_ERROR" && <p role="alert" className="mt-3 text-sm">{t("otherPartyName.refreshError")}</p>}
    {(!editing && !statusTarget || editing === "new") && feedback}
    {canManage && editing === "new" && <SupplierPartyForm supplier={null} disabled={blocked} onCancel={() => setEditing(null)} onSave={async (input) => {
      if (await master.saveSupplierParty({ kind: "create", input })) setEditing(null);
    }} />}
    <p className="mt-3 text-sm text-slate-500">{t("productionMaster.partyVisibility")}</p>
    {master.parties.length === 0 ? <p role="status" className="mt-4 text-sm text-slate-500">{t("productionMaster.partiesEmpty")}</p> : (
      <ul className="mt-5 divide-y divide-slate-200" aria-label={t("productionMaster.parties")}>
        {master.parties.map((party) => (
          <li key={party.id} className="py-4 first:pt-0 last:pb-0">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <p className="min-w-0 [overflow-wrap:anywhere] font-medium text-slate-900">{party.code ? `${party.code} · ` : ""}{party.name}</p>
              <span className="text-sm text-slate-600">{t(`productionMaster.type.${party.type}`)} · {t(`partyStatus.${party.status}`)}</span>
            </div>
            <dl className="mt-2 space-y-1 break-words text-sm text-slate-500">
              {([
                ["trn", party.taxRegistrationNumber], ["contact", party.contactPerson],
                ["phone", party.phone], ["email", party.email], ["address", party.address], ["notes", party.notes],
              ] as const).map(([field, value]) => value !== null && (
                <div key={field}><dt className="inline font-medium">{t(`productionMaster.${field}`)}: </dt><dd className="inline"><bdi>{value}</bdi></dd></div>
              ))}
            </dl>
            {party.type === "OTHER" && <OtherPartyNameControl party={party} selected={otherActionId === party.id} onSelect={() => setOtherActionId(party.id)} />}
            {canManage && party.type === "SUPPLIER" && <div className="mt-3 flex flex-wrap gap-2">
              <button type="button" className={button} disabled={blocked} onClick={(event) => { returnFocus.current = event.currentTarget; setStatusTarget(null); setEditing(party); }}>{t("supplierMutation.edit")}</button>
              <button type="button" className={button} disabled={blocked} onClick={(event) => { returnFocus.current = event.currentTarget; setEditing(null); setStatusTarget(party); }}>{t(party.status === "ACTIVE" ? "supplierMutation.deactivate" : "supplierMutation.reactivate")}</button>
            </div>}
            {canManage && party.type === "SUPPLIER" && editing && editing !== "new" && editing.id === party.id && <>
              {feedback}
              <SupplierPartyForm key={editing.id} supplier={editing} disabled={blocked} onCancel={() => setEditing(null)} onSave={async (input) => {
                if (await master.saveSupplierParty({ kind: "edit", supplier: editing, input })) setEditing(null);
              }} />
            </>}
            {canManage && statusTarget?.id === party.id && <div ref={confirmation} tabIndex={-1} role="region" aria-label={t(statusTarget.status === "ACTIVE" ? "supplierMutation.deactivateConfirm" : "supplierMutation.reactivateConfirm")} className="mt-4 rounded-lg border border-amber-300 p-4">
              {feedback}
              <p className="break-words"><bdi>{statusTarget.code ? `${statusTarget.code} · ` : ""}{statusTarget.name}</bdi></p>
              <p className="my-2 text-sm">{t(statusTarget.status === "ACTIVE" ? "supplierMutation.deactivateConfirm" : "supplierMutation.reactivateConfirm")}</p>
              <div className="flex flex-wrap gap-2"><button type="button" disabled={blocked} className={button} onClick={() => {
                void master.saveSupplierParty({ kind: "status", supplier: statusTarget, status: statusTarget.status === "ACTIVE" ? "INACTIVE" : "ACTIVE" }).then((ok) => { if (ok) setStatusTarget(null); });
              }}>{t("supplierMutation.confirm")}</button><button type="button" className={button} onClick={() => setStatusTarget(null)}>{t("supplierMutation.close")}</button></div>
            </div>}
          </li>
        ))}
      </ul>
    )}
  </>;
}
