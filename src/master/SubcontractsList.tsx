import { useT } from "../i18n/I18nContext";
import type { ProductionParty, ProductionProjectSummary, ProductionSubcontract } from "./masterTypes";

export function SubcontractsList({ subcontracts, projects, parties }: {
  subcontracts: ProductionSubcontract[];
  projects: ProductionProjectSummary[];
  parties: ProductionParty[];
}) {
  const t = useT();
  if (subcontracts.length === 0) return <p role="status" className="mt-4 text-sm text-slate-500">{t("productionMaster.subcontractsEmpty")}</p>;
  return (
    <ul className="mt-5 divide-y divide-slate-200" aria-label={t("productionMaster.subcontracts")}>
      {subcontracts.map((contract) => {
        // References do not authorize another fetch: use only this scoped snapshot.
        const project = projects.find((row) => row.companyId === contract.companyId && row.id === contract.projectId);
        const party = parties.find((row) => row.companyId === contract.companyId && row.id === contract.subcontractorId);
        return (
          <li key={contract.id} className="break-words py-4 first:pt-0 last:pb-0">
            <div className="flex flex-wrap items-start justify-between gap-3">
              <p className="font-medium text-slate-900"><bdi>{contract.contractNumber}</bdi></p>
              <span className="text-sm text-slate-600">{t(`productionMaster.subcontractStatus.${contract.status}`)}</span>
            </div>
            <dl className="mt-2 space-y-2 text-sm text-slate-500">
              <div><dt className="font-medium">{t("productionMaster.scopeOfWork")}</dt><dd className="whitespace-pre-wrap"><bdi>{contract.scopeOfWork}</bdi></dd></div>
              <div><dt className="font-medium">{t("productionMaster.projectId")}</dt><dd><bdi>{contract.projectId}</bdi><span className="block">{project ? <bdi>{project.code} · {project.name}</bdi> : t("productionMaster.projectDetailsUnavailable")}</span></dd></div>
              <div><dt className="font-medium">{t("productionMaster.subcontractorId")}</dt><dd><bdi>{contract.subcontractorId}</bdi><span className="block">{party ? <bdi>{party.code !== null ? `${party.code} · ` : ""}{party.name}</bdi> : t("productionMaster.partyDetailsUnavailable")}</span></dd></div>
              {([
                ["originalContractValueMinor", contract.originalContractValueMinor],
                ["approvedVariationsMinor", contract.approvedVariationsMinor],
                ["startDate", contract.startDate], ["expectedEndDate", contract.expectedEndDate], ["notes", contract.notes],
              ] as const).map(([field, value]) => value !== null && <div key={field}><dt className="inline font-medium">{t(`productionMaster.${field}`)}: </dt><dd className="inline"><bdi>{value}</bdi></dd></div>)}
              <div><dt className="inline font-medium">{t("productionMaster.retentionRate")}: </dt><dd className="inline"><bdi>{Math.floor(contract.retentionBps / 100)}.{String(contract.retentionBps % 100).padStart(2, "0")}%</bdi></dd></div>
            </dl>
          </li>
        );
      })}
    </ul>
  );
}
