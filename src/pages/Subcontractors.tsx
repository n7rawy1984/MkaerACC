import { useMemo, useState } from "react";
import { useNavigate } from "react-router-dom";
import { HardHat, Plus } from "lucide-react";
import { useAppData } from "../state/AppDataContext";
import { PageHeader } from "../components/layout/AppShell";
import { Card } from "../components/ui/Card";
import { Badge } from "../components/ui/Badge";
import { Modal } from "../components/ui/Modal";
import { SubcontractorForm } from "../components/SubcontractorForm";
import { formatAED } from "../domain/money";
import {
  contractCertifiedCost,
  subcontractorAdvanceBalance,
  subcontractorPayableBalance,
  subcontractorRetentionHeld,
} from "../accounting/ledger";

export function Subcontractors() {
  const { parties, subcontracts, journalEntries } = useAppData();
  const navigate = useNavigate();
  const [showForm, setShowForm] = useState(false);

  const subcontractors = useMemo(() => parties.filter((p) => p.type === "SUBCONTRACTOR"), [parties]);

  const rows = useMemo(
    () =>
      subcontractors
        .map((s) => {
          const contracts = subcontracts.filter((c) => c.subcontractorId === s.id);
          return {
            subcontractor: s,
            contractCount: contracts.length,
            activeContracts: contracts.filter((c) => c.status === "ACTIVE").length,
            projectCount: new Set(contracts.map((c) => c.projectId)).size,
            certifiedToDate: contracts.reduce((sum, c) => sum + contractCertifiedCost(journalEntries, c.id), 0),
            payable: subcontractorPayableBalance(journalEntries, s.id),
            retention: subcontractorRetentionHeld(journalEntries, s.id),
            advanceBalance: subcontractorAdvanceBalance(journalEntries, s.id),
          };
        })
        .sort((a, b) => a.subcontractor.name.localeCompare(b.subcontractor.name)),
    [subcontractors, subcontracts, journalEntries],
  );

  return (
    <div>
      <PageHeader
        title="Subcontractors"
        subtitle={`${subcontractors.length} subcontractors across ${subcontracts.length} contracts`}
        action={
          <button
            onClick={() => setShowForm(true)}
            className="flex items-center gap-2 rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800"
          >
            <Plus size={16} /> New Subcontractor
          </button>
        }
      />

      <Card>
        <div className="overflow-x-auto">
          <table className="w-full text-sm">
            <thead>
              <tr className="border-b border-slate-100 text-left text-xs font-medium uppercase tracking-wide text-slate-400">
                <th className="px-5 py-2.5 font-medium">Subcontractor</th>
                <th className="px-3 py-2.5 text-right font-medium">Active Contracts</th>
                <th className="px-3 py-2.5 text-right font-medium">Projects</th>
                <th className="px-3 py-2.5 text-right font-medium">Certified To Date</th>
                <th className="px-3 py-2.5 text-right font-medium">Outstanding Payable</th>
                <th className="px-3 py-2.5 text-right font-medium">Retention Held</th>
                <th className="px-5 py-2.5 text-right font-medium">Advance Balance</th>
              </tr>
            </thead>
            <tbody>
              {rows.length === 0 && (
                <tr>
                  <td colSpan={7} className="px-5 py-8 text-center text-sm text-slate-400">
                    No subcontractors yet.
                  </td>
                </tr>
              )}
              {rows.map((row) => (
                <tr
                  key={row.subcontractor.id}
                  onClick={() => navigate(`/subcontractors/${row.subcontractor.id}`)}
                  className="cursor-pointer border-b border-slate-50 last:border-b-0 hover:bg-slate-50"
                >
                  <td className="px-5 py-3.5">
                    <div className="flex items-center gap-3">
                      <div className="flex h-10 w-10 shrink-0 items-center justify-center rounded-lg bg-slate-100 text-slate-500">
                        <HardHat size={18} />
                      </div>
                      <div>
                        <div className="flex items-center gap-2">
                          <p className="font-semibold text-slate-900">{row.subcontractor.name}</p>
                          <Badge tone={row.subcontractor.status === "INACTIVE" ? "slate" : "green"}>
                            {row.subcontractor.status ?? "ACTIVE"}
                          </Badge>
                        </div>
                        {row.subcontractor.contactPerson && (
                          <p className="text-xs text-slate-400">{row.subcontractor.contactPerson}</p>
                        )}
                      </div>
                    </div>
                  </td>
                  <td className="px-3 py-3.5 text-right text-slate-700">
                    {row.activeContracts} / {row.contractCount}
                  </td>
                  <td className="px-3 py-3.5 text-right text-slate-700">{row.projectCount}</td>
                  <td className="px-3 py-3.5 whitespace-nowrap text-right font-medium text-slate-900">
                    {formatAED(row.certifiedToDate)}
                  </td>
                  <td className="px-3 py-3.5 whitespace-nowrap text-right font-medium text-slate-900">
                    {formatAED(row.payable)}
                  </td>
                  <td className="px-3 py-3.5 whitespace-nowrap text-right font-medium text-slate-600">
                    {formatAED(row.retention)}
                  </td>
                  <td className="px-5 py-3.5 whitespace-nowrap text-right font-medium text-slate-600">
                    {formatAED(row.advanceBalance)}
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </Card>

      {showForm && (
        <Modal title="New Subcontractor" onClose={() => setShowForm(false)}>
          <SubcontractorForm onDone={() => setShowForm(false)} />
        </Modal>
      )}
    </div>
  );
}
