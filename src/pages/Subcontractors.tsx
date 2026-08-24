import { useMemo } from "react";
import { useNavigate } from "react-router-dom";
import { HardHat } from "lucide-react";
import { useAppData } from "../state/AppDataContext";
import { PageHeader } from "../components/layout/AppShell";
import { Card } from "../components/ui/Card";
import { Badge } from "../components/ui/Badge";
import { formatAED } from "../domain/money";
import { indexById } from "../domain/utils";
import { subcontractorPayableBalance, subcontractorRetentionHeld } from "../accounting/ledger";
import type { SubcontractStatus } from "../domain/types";

const STATUS_TONE: Record<SubcontractStatus, "green" | "slate" | "amber"> = {
  ACTIVE: "green",
  COMPLETED: "slate",
  CLOSED: "slate",
};

export function Subcontractors() {
  const { subcontracts, subcontractorCertificates, parties, projects, journalEntries } = useAppData();
  const navigate = useNavigate();

  const partiesById = useMemo(() => indexById(parties), [parties]);
  const projectsById = useMemo(() => indexById(projects), [projects]);

  const rows = useMemo(
    () =>
      subcontracts.map((contract) => {
        const revisedValue = contract.originalContractValue + contract.approvedVariations;
        const certifiedToDate = subcontractorCertificates
          .filter((c) => c.contractId === contract.id && c.status !== "DRAFT")
          .reduce((sum, c) => sum + c.grossCurrentValue, 0);
        return {
          contract,
          subcontractor: partiesById[contract.subcontractorId],
          project: projectsById[contract.projectId],
          revisedValue,
          certifiedToDate,
          payable: subcontractorPayableBalance(journalEntries, contract.subcontractorId),
          retention: subcontractorRetentionHeld(journalEntries, contract.subcontractorId, contract.projectId),
        };
      }),
    [subcontracts, subcontractorCertificates, partiesById, projectsById, journalEntries],
  );

  return (
    <div>
      <PageHeader
        title="Subcontractors"
        subtitle={`${subcontracts.length} contracts across ${new Set(subcontracts.map((c) => c.subcontractorId)).size} subcontractors`}
      />

      <Card>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-100 text-left text-xs font-medium uppercase tracking-wide text-slate-400">
                <th className="px-5 py-2.5 font-medium">Subcontractor</th>
                <th className="px-3 py-2.5 font-medium">Contract / Project</th>
                <th className="px-3 py-2.5 text-right font-medium">Revised Value</th>
                <th className="px-3 py-2.5 text-right font-medium">Certified To Date</th>
                <th className="px-3 py-2.5 text-right font-medium">Outstanding Payable</th>
                <th className="px-5 py-2.5 text-right font-medium">Retention</th>
              </tr>
            </thead>
            <tbody>
              {rows.length === 0 && (
                <tr>
                  <td colSpan={6} className="px-5 py-8 text-center text-sm text-slate-400">
                    No subcontracts recorded yet.
                  </td>
                </tr>
              )}
              {rows.map(({ contract, subcontractor, project, revisedValue, certifiedToDate, payable, retention }) => (
                <tr
                  key={contract.id}
                  onClick={() => navigate(`/subcontractors/${contract.id}`)}
                  className="cursor-pointer border-b border-slate-50 last:border-b-0 hover:bg-slate-50"
                >
                  <td className="px-5 py-3.5">
                    <div className="flex items-center gap-3">
                      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-slate-100 text-slate-500">
                        <HardHat size={18} />
                      </div>
                      <div>
                        <p className="font-semibold text-slate-900">{subcontractor?.name ?? "—"}</p>
                        <Badge tone={STATUS_TONE[contract.status]}>{contract.status}</Badge>
                      </div>
                    </div>
                  </td>
                  <td className="px-3 py-3.5 whitespace-nowrap">
                    <p className="text-slate-700">{contract.contractNumber}</p>
                    <p className="text-xs text-slate-400">{project?.name ?? "—"}</p>
                  </td>
                  <td className="px-3 py-3.5 whitespace-nowrap text-right font-medium text-slate-900">
                    {formatAED(revisedValue)}
                  </td>
                  <td className="px-3 py-3.5 whitespace-nowrap text-right font-medium text-slate-900">
                    {formatAED(certifiedToDate)}
                  </td>
                  <td className="px-3 py-3.5 whitespace-nowrap text-right font-medium text-slate-900">
                    {formatAED(payable)}
                  </td>
                  <td className="px-5 py-3.5 whitespace-nowrap text-right font-medium text-slate-600">
                    {formatAED(retention)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  );
}
