import { useLayoutEffect, useRef, useState } from "react";
import { useAuth } from "../auth/AuthContext";
import { useT } from "../i18n/I18nContext";
import { ProjectMetadataForm } from "./ProjectMetadataForm";
import { useProductionMasterData } from "./productionMasterDataContext";
import type { ProductionProjectSummary } from "./masterTypes";

export function ProjectsList() {
  const t = useT();
  const { state } = useAuth();
  const master = useProductionMasterData();
  const [editing, setEditing] = useState<ProductionProjectSummary | null>(null);
  const [actionId, setActionId] = useState<string | null>(null);
  const origin = useRef<HTMLButtonElement | null>(null);
  const restoreFocus = useRef(false);
  const feedback = useRef<HTMLDivElement>(null);
  const phase = master.projectMetadataMutation.phase;
  useLayoutEffect(() => {
    if (!editing && restoreFocus.current && origin.current?.isConnected && !origin.current.disabled) {
      origin.current.focus(); restoreFocus.current = false;
    }
  });
  useLayoutEffect(() => {
    if (phase === "ERROR" || phase === "REFRESH_ERROR") { feedback.current?.focus(); feedback.current?.scrollIntoView({ block: "nearest" }); }
  }, [phase]);
  if (master.phase !== "READY" || state.phase !== "TENANT_READY") return null;
  // Project Manager rows are assignment-filtered by the authoritative SELECT policy.
  // A revoked snapshot may remain until refresh; UPDATE RLS always rechecks assignment.
  const canEdit = ["ACCOUNTING_ADMIN", "PROJECT_MANAGER"].includes(state.activeTenant.role);
  const blocked = phase === "PENDING" || phase === "ERROR" || phase === "REFRESH_ERROR";
  const close = () => { restoreFocus.current = true; setEditing(null); };
  const refresh = () => { close(); void master.refreshProjects(); };
  const message = <div ref={feedback} tabIndex={-1} className="mt-3 text-sm">
    {phase === "PENDING" && <p role="status">{t("projectMetadata.pending")}</p>}
    {phase === "SAVED" && <p role="status">{t("projectMetadata.saved")}</p>}
    {phase === "ERROR" && <p role="alert">{t(`projectMetadata.${master.projectMetadataMutation.error ?? "uncertain"}`)} {t("projectMetadata.refreshRequired")}</p>}
    {phase === "REFRESH_ERROR" && <p role="alert">{t("projectMetadata.refreshError")}</p>}
    {(phase === "ERROR" || phase === "REFRESH_ERROR") && <button type="button" onClick={refresh} className="underline">{t("projectMetadata.refresh")}</button>}
  </div>;
  return <div>
    <button type="button" disabled={phase === "PENDING"} onClick={refresh} className="mt-4 rounded-lg border px-3 py-2 text-sm">{t("projectMetadata.refresh")}</button>
    {!master.projects.some(p => p.id === actionId) && message}
    {master.projects.length === 0 && <p className="mt-4 text-sm">{t("productionProjects.empty")}</p>}
    <ul className="mt-5 divide-y divide-slate-200" aria-label={t("productionProjects.title")}>
      {master.projects.map(project => <li key={project.id} className="min-w-0 break-words py-4">
        <p className="font-medium">{project.code} · {project.name}</p>
        <p className="text-sm">{t(`projectStatus.${project.status}`)}</p>
        <dl className="mt-2 space-y-2 text-sm">
          {(["client_name", "location", "contract_number", "notes"] as const).map(field => <div key={field}><dt className="text-slate-500">{t(`projectMetadata.${field}`)}</dt><dd className="whitespace-pre-wrap">{(field === "client_name" ? project.clientName : field === "contract_number" ? project.contractNumber : project[field]) ?? t("projectMetadata.empty")}</dd></div>)}
        </dl>
        {canEdit && <button type="button" disabled={blocked || !!editing} onClick={event => { origin.current = event.currentTarget; setActionId(project.id); setEditing(project); }} className="mt-3 rounded-lg border px-3 py-2 text-sm disabled:opacity-50">{t("projectMetadata.edit")}</button>}
        {editing?.id === project.id && canEdit && <ProjectMetadataForm project={editing} disabled={blocked} onCancel={close} onSave={async input => { if (await master.saveProjectMetadata({ project: editing, input })) close(); }} />}
        {actionId === project.id && message}
      </li>)}
    </ul>
  </div>;
}
