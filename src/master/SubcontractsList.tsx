import{DataWorkspace,TextCell,MoneyCell}from'../workspace/data/DataWorkspace';
import type{ContractRegister}from'../financial/operationalContracts';
import {RecordIdentity} from '../components/ui/RecordIdentity';
import {OperationalContracts} from '../financial/OperationalContracts';
import {StatusBadge} from '../workspace/workspaceUi';
import { SubcontractCreationPanel } from "./SubcontractCreationPanel";
import { useLayoutEffect, useRef, useState } from "react";
import { useAuth } from "../auth/AuthContext";
import { useT,useI18n } from "../i18n/I18nContext";
import { SubcontractMetadataForm } from "./SubcontractMetadataForm";
import { useProductionMasterData } from "./productionMasterDataContext";
import type { ProductionSubcontract } from "./masterTypes";
import { dashboardAED } from "../dashboard/dashboardSummary";

export function SubcontractsList() {
  const t = useT();const{locale}=useI18n(),ar=locale==='ar';
  const [register,setRegister]=useState<ContractRegister|null>(null);
  const [contractModes,setContractModes]=useState<Record<string,string>>({});
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
    <details className="dw-setup"><summary>{t("productionMaster.subcontracts")} · {"إعداد / Setup"}</summary><OperationalContracts onModes={setContractModes} onRegister={setRegister}/></details>
    <SubcontractCreationPanel kind="subcontract" />
    <button type="button" disabled={phase === "PENDING"} onClick={refresh} className="mt-4 rounded-lg border px-3 py-2 text-sm">{t("subcontractMetadata.refresh")}</button>
    {!master.subcontracts.some(row => row.id === actionId) && message}
    {master.subcontracts.length === 0 && <p role="status" className="mt-4 text-sm text-slate-500">{t("productionMaster.subcontractsEmpty")}</p>}
    <DataWorkspace label={t("productionMaster.subcontracts")} rows={master.subcontracts} titleOf={c=>c.contractNumber} search={c=>[c.contractNumber,c.scopeOfWork,master.projects.find(p=>p.id===c.projectId)?.name,master.parties.find(p=>p.id===c.subcontractorId)?.name].join(' ')} statusOf={c=>t(`productionMaster.subcontractStatus.${c.status}`)} projectOf={c=>master.projects.find(p=>p.id===c.projectId)?.name??t('productionMaster.projectDetailsUnavailable')} onClose={close} columns={[
 {key:'number',label:t('subcontractForm.contractNumber'),value:c=>c.contractNumber,render:c=><bdi dir="ltr" className="dw-reference">{c.contractNumber}</bdi>},
 {key:'party',label:ar?'المقاول':'Contractor',render:c=><TextCell value={master.parties.find(p=>p.id===c.subcontractorId)?.name??t('productionMaster.partyDetailsUnavailable')}/>},
 {key:'project',label:ar?'المشروع':'Project',render:c=><TextCell value={master.projects.find(p=>p.id===c.projectId)?.name??t('productionMaster.projectDetailsUnavailable')}/>},
 {key:'scope',label:t('productionMaster.scopeOfWork'),render:c=><TextCell value={c.scopeOfWork}/>},
 {key:'value',label:ar?'قيمة العقد':'Contract value',value:c=>BigInt(register?.summaries.find(x=>x.id===c.id)?.contract_value_minor??c.originalContractValueMinor),numeric:true,render:c=>register?.summaries.find(x=>x.id===c.id)?.mode==='UNIT_RATE_UNCAPPED'?<span>غير محدد / Uncapped</span>:<MoneyCell minor={register?.summaries.find(x=>x.id===c.id)?.contract_value_minor}/>},
 {key:'certified',label:ar?'الأعمال المعتمدة':'Certified',numeric:true,render:c=><MoneyCell minor={register?.summaries.find(x=>x.id===c.id)?.certified_work_minor}/>},
 {key:'advances',label:ar?'المقدم المتبقي':'Advance outstanding',numeric:true,render:c=><MoneyCell minor={register?.summaries.find(x=>x.id===c.id)?.advance_outstanding_minor}/>},
 {key:'paid',label:ar?'تسويات المستخلصات':'Settlements',numeric:true,render:c=><MoneyCell minor={register?.summaries.find(x=>x.id===c.id)?.actual_payment_minor}/>},
 {key:'status',label:t('common.status'),render:c=><StatusBadge status={c.status}>{t(`productionMaster.subcontractStatus.${c.status}`)}</StatusBadge>}
 ]} renderDetails={contract=>{
      const project = master.projects.find(row => row.companyId === contract.companyId && row.id === contract.projectId);
      const party = master.parties.find(row => row.companyId === contract.companyId && row.id === contract.subcontractorId);
      return <>
        <RecordIdentity name={contract.contractNumber} status={<StatusBadge status={contract.status}>{t(`productionMaster.subcontractStatus.${contract.status}`)}</StatusBadge>}/>
        <dl className="mt-2 min-w-0 space-y-2 text-sm text-slate-500">
          <div className="min-w-0"><dt className="font-medium">{t("productionMaster.scopeOfWork")}</dt><dd className="min-w-0 whitespace-pre-wrap break-words"><bdi>{contract.scopeOfWork}</bdi></dd></div>
          <div><dt className="font-medium">{t("productionMaster.projectId")}</dt><dd><bdi dir="ltr">{contract.projectId}</bdi><span className="block">{project ? <><bdi dir="ltr">{project.code}</bdi> · <bdi>{project.name}</bdi></> : t("productionMaster.projectDetailsUnavailable")}</span></dd></div>
          <div><dt className="font-medium">{t("productionMaster.subcontractorId")}</dt><dd><bdi dir="ltr">{contract.subcontractorId}</bdi><span className="block">{party ? <bdi>{party.code !== null ? `${party.code} · ` : ""}{party.name}</bdi> : t("productionMaster.partyDetailsUnavailable")}</span></dd></div>
          {([ ["originalContractValueMinor", contract.originalContractValueMinor], ["approvedVariationsMinor", contract.approvedVariationsMinor], ["startDate", contract.startDate], ["expectedEndDate", contract.expectedEndDate], ["notes", contract.notes] ] as const).map(([field, value]) => value !== null && <div className="min-w-0" key={field}><dt className="inline font-medium">{t(`productionMaster.${field}`)}: </dt><dd className="inline min-w-0 whitespace-pre-wrap break-words"><bdi dir={field === "notes" ? "auto" : "ltr"}>{field === "originalContractValueMinor" || field === "approvedVariationsMinor" ? contractModes[contract.id]==="UNIT_RATE_UNCAPPED" ? "—" : dashboardAED(value) : value}</bdi></dd></div>)}
          <div><dt className="inline font-medium">{t("productionMaster.retentionRate")}: </dt><dd className="inline"><bdi dir="ltr">{Math.floor(contract.retentionBps / 100)}.{String(contract.retentionBps % 100).padStart(2, "0")}%</bdi></dd></div>
        </dl>
        {canEdit && <button type="button" disabled={blocked || !!editing} onClick={event => { origin.current = event.currentTarget; setActionId(contract.id); setEditing(contract); }} className="mt-3 rounded-lg border px-3 py-2 text-sm disabled:opacity-50">{t("subcontractMetadata.edit")}</button>}
        {editing?.id === contract.id && canEdit && <SubcontractMetadataForm subcontract={editing} disabled={blocked} onCancel={close} onSave={async input => { if (await master.saveSubcontractMetadata({ subcontract: editing, input })) close(); }} />}
        {actionId === contract.id && message}
      <OperationalContracts initialContract={contract.id} onRegister={setRegister} onModes={setContractModes}/></>;
    }}/>
  </div>;
}
