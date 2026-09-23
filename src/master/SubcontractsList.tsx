import { useLayoutEffect, useRef, useState } from "react";
import { useAuth } from "../auth/AuthContext";
import { useT } from "../i18n/I18nContext";
import { SubcontractMetadataForm } from "./SubcontractMetadataForm";
import { useProductionMasterData } from "./productionMasterDataContext";
import type { ProductionSubcontract } from "./masterTypes";

export function SubcontractsList() {
  const t = useT();
  const { state } = useAuth();
  const master = useProductionMasterData();
  const [editing, setEditing] = useState<ProductionSubcontract | null>(null);
  const [actionId, setActionId] = useState<string | null>(null);
  const origin = useRef<HTMLButtonElement | null>(null);
  const restoreFocus = useRef(false);
  const feedback = useRef<HTMLDivElement>(null);
  const phase = master.subcontractMetadataMutation.phase;
  useLayoutEffect(() => {
    if (!editing && restoreFocus.current && origin.current?.isConnected && !origin.current.disabled) { origin.current.focus(); restoreFocus.current = false; }
  });
  useLayoutEffect(() => {
    if (phase === "ERROR" || phase === "REFRESH_ERROR") { feedback.current?.focus(); feedback.current?.scrollIntoView({ block: "nearest" }); }
  }, [phase]);
  if (master.phase !== "READY" || state.phase !== "TENANT_READY") return null;
  const canEdit = ["ACCOUNTING_ADMIN", "PROCUREMENT"].includes(state.activeTenant.role);
  const blocked = phase === "PENDING" || phase === "ERROR" || phase === "REFRESH_ERROR";
  const close = () => { restoreFocus.current = true; setEditing(null); };
  const refresh = () => { close(); void master.refreshSubcontracts(); };
  const message = <div ref={feedback} tabIndex={-1} className="mt-3 text-sm">
    {phase === "PENDING" && <p role="status">{t("subcontractMetadata.pending")}</p>}
    {phase === "SAVED" && <p role="status">{t("subcontractMetadata.saved")}</p>}
    {phase === "ERROR" && <p role="alert">{t(`subcontractMetadata.${master.subcontractMetadataMutation.error ?? "uncertain"}`)} {t("subcontractMetadata.refreshRequired")}</p>}
    {phase === "REFRESH_ERROR" && <p role="alert">{t("subcontractMetadata.refreshError")}</p>}
    {(phase === "ERROR" || phase === "REFRESH_ERROR") && <button type="button" onClick={refresh} className="underline">{t("subcontractMetadata.refresh")}</button>}
  </div>;
  return <div className="min-w-0">
    <button type="button" disabled={phase === "PENDING"} onClick={refresh} className="mt-4 rounded-lg border px-3 py-2 text-sm">{t("subcontractMetadata.refresh")}</button>
    {!master.subcontracts.some(row => row.id === actionId) && message}
    {master.subcontracts.length === 0 && <p role="status" className="mt-4 text-sm text-slate-500">{t("productionMaster.subcontractsEmpty")}</p>}
    <ul className="mt-5 min-w-0 divide-y divide-slate-200" aria-label={t("productionMaster.subcontracts")}>{master.subcontracts.map(contract => {
      const project = master.projects.find(row => row.companyId === contract.companyId && row.id === contract.projectId);
      const party = master.parties.find(row => row.companyId === contract.companyId && row.id === contract.subcontractorId);
      return <li key={contract.id} className="min-w-0 break-words py-4 first:pt-0 last:pb-0">
        <div className="flex min-w-0 flex-wrap items-start justify-between gap-3"><p className="min-w-0 font-medium text-slate-900"><bdi className="break-words">{contract.contractNumber}</bdi></p><span className="text-sm text-slate-600">{t(`productionMaster.subcontractStatus.${contract.status}`)}</span></div>
        <dl className="mt-2 min-w-0 space-y-2 text-sm text-slate-500">
          <div className="min-w-0"><dt className="font-medium">{t("productionMaster.scopeOfWork")}</dt><dd className="min-w-0 whitespace-pre-wrap break-words"><bdi>{contract.scopeOfWork}</bdi></dd></div>
          <div><dt className="font-medium">{t("productionMaster.projectId")}</dt><dd><bdi>{contract.projectId}</bdi><span className="block">{project ? <bdi>{project.code} · {project.name}</bdi> : t("productionMaster.projectDetailsUnavailable")}</span></dd></div>
          <div><dt className="font-medium">{t("productionMaster.subcontractorId")}</dt><dd><bdi>{contract.subcontractorId}</bdi><span className="block">{party ? <bdi>{party.code !== null ? `${party.code} · ` : ""}{party.name}</bdi> : t("productionMaster.partyDetailsUnavailable")}</span></dd></div>
          {([ ["originalContractValueMinor", contract.originalContractValueMinor], ["approvedVariationsMinor", contract.approvedVariationsMinor], ["startDate", contract.startDate], ["expectedEndDate", contract.expectedEndDate], ["notes", contract.notes] ] as const).map(([field, value]) => value !== null && <div className="min-w-0" key={field}><dt className="inline font-medium">{t(`productionMaster.${field}`)}: </dt><dd className="inline min-w-0 whitespace-pre-wrap break-words"><bdi>{value}</bdi></dd></div>)}
          <div><dt className="inline font-medium">{t("productionMaster.retentionRate")}: </dt><dd className="inline"><bdi>{Math.floor(contract.retentionBps / 100)}.{String(contract.retentionBps % 100).padStart(2, "0")}%</bdi></dd></div>
        </dl>
        {canEdit && <button type="button" disabled={blocked || !!editing} onClick={event => { origin.current = event.currentTarget; setActionId(contract.id); setEditing(contract); }} className="mt-3 rounded-lg border px-3 py-2 text-sm disabled:opacity-50">{t("subcontractMetadata.edit")}</button>}
        {editing?.id === contract.id && canEdit && <SubcontractMetadataForm subcontract={editing} disabled={blocked} onCancel={close} onSave={async input => { if (await master.saveSubcontractMetadata({ subcontract: editing, input })) close(); }} />}
        {actionId === contract.id && message}
      </li>;
    })}</ul>
  </div>;
}
