import { useMemo, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { ArrowLeft, Plus, Wallet } from "lucide-react";
import { useAppData } from "../state/AppDataContext";
import { PageHeader } from "../components/layout/AppShell";
import { Card, CardHeader } from "../components/ui/Card";
import { Badge } from "../components/ui/Badge";
import { StatCard } from "../components/ui/StatCard";
import { Modal } from "../components/ui/Modal";
import { CertificateForm } from "../components/CertificateForm";
import { SubcontractorAdvanceForm } from "../components/SubcontractorAdvanceForm";
import { formatAED } from "../domain/money";
import { formatDate } from "../domain/utils";
import {
  subcontractorAdvanceBalance,
  subcontractorPayableBalance,
  subcontractorRetentionHeld,
} from "../accounting/ledger";
import { FileCheck2, Hash, Landmark, ListChecks, Receipt } from "lucide-react";
import type { CertificateStatus } from "../domain/types";

const STATUS_TONE: Record<CertificateStatus, "slate" | "blue" | "amber" | "green"> = {
  DRAFT: "slate",
  APPROVED: "blue",
  PARTIALLY_PAID: "amber",
  PAID: "green",
};

export function SubcontractDetail() {
  const { id } = useParams<{ id: string }>();
  const { subcontracts, subcontractorCertificates, parties, projects, journalEntries } = useAppData();
  const [showCertificateForm, setShowCertificateForm] = useState(false);
  const [showAdvanceForm, setShowAdvanceForm] = useState(false);
  const [editingCertificateId, setEditingCertificateId] = useState<string | null>(null);

  const contract = subcontracts.find((c) => c.id === id);
  const subcontractor = parties.find((p) => p.id === contract?.subcontractorId);
  const project = projects.find((p) => p.id === contract?.projectId);

  const certificates = useMemo(
    () =>
      subcontractorCertificates
        .filter((c) => c.contractId === id)
        .sort((a, b) => (a.certificateDate < b.certificateDate ? 1 : -1)),
    [subcontractorCertificates, id],
  );

  const editingCertificate = certificates.find((c) => c.id === editingCertificateId);

  if (!contract || !subcontractor) {
    return (
      <div>
        <Link to="/subcontractors" className="text-sm text-slate-500 hover:text-slate-900">
          &larr; Back to subcontractors
        </Link>
        <p className="mt-4 text-sm text-slate-500">Contract not found.</p>
      </div>
    );
  }

  const revisedValue = contract.originalContractValue + contract.approvedVariations;
  const certifiedToDate = certificates
    .filter((c) => c.status !== "DRAFT")
    .reduce((sum, c) => sum + c.grossCurrentValue, 0);
  const remainingValue = revisedValue - certifiedToDate;
  const advanceBalance = subcontractorAdvanceBalance(journalEntries, contract.subcontractorId, contract.projectId);
  const retentionHeld = subcontractorRetentionHeld(journalEntries, contract.subcontractorId, contract.projectId);
  const payable = subcontractorPayableBalance(journalEntries, contract.subcontractorId);

  return (
    <div>
      <Link
        to="/subcontractors"
        className="mb-3 inline-flex items-center gap-1 text-sm text-slate-500 hover:text-slate-900"
      >
        <ArrowLeft size={14} /> Back to subcontractors
      </Link>
      <PageHeader
        title={`${subcontractor.name} · ${contract.contractNumber}`}
        subtitle={`${project?.name ?? "—"} · ${contract.scopeOfWork}`}
        action={
          <div className="flex gap-2">
            <button
              onClick={() => setShowAdvanceForm(true)}
              className="flex items-center gap-2 rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50"
            >
              <Wallet size={16} /> New Advance
            </button>
            <button
              onClick={() => setShowCertificateForm(true)}
              className="flex items-center gap-2 rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800"
            >
              <Plus size={16} /> New Certificate
            </button>
          </div>
        }
      />

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <StatCard label="Revised Contract" value={revisedValue} icon={Hash} hint={`Original ${formatAED(contract.originalContractValue)}`} />
        <StatCard label="Certified To Date" value={certifiedToDate} icon={FileCheck2} />
        <StatCard label="Remaining Value" value={remainingValue} icon={Receipt} />
        <StatCard label="Advance Balance" value={advanceBalance} icon={Wallet} hint="Recoverable" />
        <StatCard label="Retention Held" value={retentionHeld} icon={Landmark} />
        <StatCard label="Outstanding Payable" value={payable} icon={ListChecks} tone={payable > 0 ? "warning" : "default"} />
      </div>

      <Card className="mt-6">
        <CardHeader title="Certificate History" subtitle={`${certificates.length} certificates`} />
        <div className="divide-y divide-slate-100">
          {certificates.length === 0 && (
            <p className="px-5 py-8 text-center text-sm text-slate-400">No certificates raised yet.</p>
          )}
          {certificates.map((c) => (
            <button
              key={c.id}
              onClick={() => setEditingCertificateId(c.id)}
              className="flex w-full items-center justify-between px-5 py-3.5 text-left hover:bg-slate-50"
            >
              <div className="flex items-center gap-3">
                <div>
                  <div className="flex items-center gap-2">
                    <p className="text-sm font-medium text-slate-800">{c.certificateNumber}</p>
                    <Badge tone={STATUS_TONE[c.status]}>{c.status.replace("_", " ")}</Badge>
                  </div>
                  <p className="text-xs text-slate-400">{formatDate(c.certificateDate)}</p>
                </div>
              </div>
              <div className="text-right">
                <p className="text-sm font-semibold text-slate-900">{formatAED(c.netPayable)}</p>
                <p className="text-xs text-slate-400">Gross {formatAED(c.grossCurrentValue)}</p>
              </div>
            </button>
          ))}
        </div>
      </Card>

      {showCertificateForm && (
        <Modal title="New Progress Certificate" onClose={() => setShowCertificateForm(false)} width="max-w-2xl">
          <CertificateForm contractId={contract.id} onDone={() => setShowCertificateForm(false)} />
        </Modal>
      )}

      {editingCertificate && (
        <Modal
          title={`Certificate ${editingCertificate.certificateNumber}`}
          onClose={() => setEditingCertificateId(null)}
          width="max-w-2xl"
        >
          <CertificateForm
            contractId={contract.id}
            certificate={editingCertificate}
            onDone={() => setEditingCertificateId(null)}
          />
        </Modal>
      )}

      {showAdvanceForm && (
        <Modal title="New Subcontractor Advance" onClose={() => setShowAdvanceForm(false)}>
          <SubcontractorAdvanceForm contractId={contract.id} onDone={() => setShowAdvanceForm(false)} />
        </Modal>
      )}
    </div>
  );
}
