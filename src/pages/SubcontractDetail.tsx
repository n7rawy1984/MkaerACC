import { useMemo, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { ArrowLeft, Pencil, Plus, Wallet } from "lucide-react";
import { useAppData } from "../state/AppDataContext";
import { PageHeader } from "../components/layout/AppShell";
import { Card, CardHeader } from "../components/ui/Card";
import { Badge } from "../components/ui/Badge";
import { StatCard } from "../components/ui/StatCard";
import { Modal } from "../components/ui/Modal";
import { CertificateForm } from "../components/CertificateForm";
import { SubcontractorAdvanceForm } from "../components/SubcontractorAdvanceForm";
import { SubcontractorPaymentForm } from "../components/SubcontractorPaymentForm";
import { SubcontractForm } from "../components/SubcontractForm";
import { formatAED } from "../domain/money";
import { formatDate } from "../domain/utils";
import { addMoney, subtractMoney } from "../domain/money";
import {
  certificatePaidAmount,
  contractAdvanceBalance,
  contractAdvancePaid,
  contractAdvanceRecovered,
  contractCertifiedCost,
  contractPayableBalance,
  contractPayableCreated,
  contractRetentionHeld,
} from "../accounting/ledger";
import { FileCheck2, Hash, Landmark, ListChecks, Receipt } from "lucide-react";
import type { CertificateStatus } from "../domain/types";

const CERT_STATUS_TONE: Record<CertificateStatus, "slate" | "blue" | "amber" | "green"> = {
  DRAFT: "slate",
  APPROVED: "blue",
  PARTIALLY_PAID: "amber",
  PAID: "green",
};

type ActivityKind = "ADVANCE" | "CERTIFICATE" | "PAYMENT";

interface ActivityRow {
  key: string;
  date: string;
  kind: ActivityKind;
  reference: string;
  amount: number;
  status: string;
  onClick?: () => void;
}

export function SubcontractDetail() {
  const { id } = useParams<{ id: string }>();
  const {
    subcontracts,
    subcontractorCertificates,
    subcontractorAdvances,
    subcontractorPayments,
    parties,
    projects,
    journalEntries,
  } = useAppData();
  const [showCertificateForm, setShowCertificateForm] = useState(false);
  const [showAdvanceForm, setShowAdvanceForm] = useState(false);
  const [showEditForm, setShowEditForm] = useState(false);
  const [editingCertificateId, setEditingCertificateId] = useState<string | null>(null);
  const [payingCertificateId, setPayingCertificateId] = useState<string | null>(null);
  const [showPaymentPicker, setShowPaymentPicker] = useState(false);

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
  const advances = useMemo(
    () => subcontractorAdvances.filter((a) => a.contractId === id),
    [subcontractorAdvances, id],
  );
  const payments = useMemo(
    () => subcontractorPayments.filter((p) => p.contractId === id),
    [subcontractorPayments, id],
  );

  const editingCertificate = certificates.find((c) => c.id === editingCertificateId);
  const payingCertificate = certificates.find((c) => c.id === payingCertificateId);

  const eligibleForPayment = useMemo(
    () =>
      certificates
        .filter((c) => c.status !== "DRAFT")
        .map((c) => ({ certificate: c, outstanding: subtractMoney(c.netPayable, certificatePaidAmount(payments, c.id)) }))
        .filter((row) => row.outstanding > 0.01),
    [certificates, payments],
  );

  const activity: ActivityRow[] = useMemo(() => {
    const rows: ActivityRow[] = [];
    for (const a of advances) {
      rows.push({ key: a.id, date: a.date, kind: "ADVANCE", reference: a.reference ?? "Subcontractor Advance", amount: a.amount, status: "POSTED" });
    }
    for (const c of certificates) {
      rows.push({
        key: c.id,
        date: c.certificateDate,
        kind: "CERTIFICATE",
        reference: c.certificateNumber,
        amount: c.netPayable,
        status: c.status,
        onClick: () => setEditingCertificateId(c.id),
      });
    }
    for (const p of payments) {
      rows.push({ key: p.id, date: p.date, kind: "PAYMENT", reference: p.reference ?? "Subcontractor Payment", amount: p.amount, status: "PAID" });
    }
    return rows.sort((x, y) => (x.date < y.date ? 1 : -1));
  }, [advances, certificates, payments]);

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

  const revisedValue = addMoney(contract.originalContractValue, contract.approvedVariations);
  const certifiedToDate = contractCertifiedCost(journalEntries, contract.id);
  const remainingValue = subtractMoney(revisedValue, certifiedToDate);
  const advancePaid = contractAdvancePaid(journalEntries, contract.id);
  const advanceRecovered = contractAdvanceRecovered(journalEntries, contract.id);
  const advanceBalance = contractAdvanceBalance(journalEntries, contract.id);
  const retentionHeld = contractRetentionHeld(journalEntries, contract.id);
  const payableCreated = contractPayableCreated(journalEntries, contract.id);
  const paymentsMade = payments.reduce((sum, p) => addMoney(sum, p.amount), 0);
  const outstandingPayable = contractPayableBalance(journalEntries, contract.id);

  const isClosed = contract.status === "CLOSED";
  const projectClosed = project?.status === "CLOSED";

  function handleRecordPaymentClick() {
    if (eligibleForPayment.length === 1) {
      setPayingCertificateId(eligibleForPayment[0].certificate.id);
    } else if (eligibleForPayment.length > 1) {
      setShowPaymentPicker(true);
    }
  }

  return (
    <div>
      <Link
        to={`/subcontractors/${subcontractor.id}`}
        className="mb-3 inline-flex items-center gap-1 text-sm text-slate-500 hover:text-slate-900"
      >
        <ArrowLeft size={14} /> Back to {subcontractor.name}
      </Link>
      <PageHeader
        title={`${contract.contractNumber} · ${subcontractor.name}`}
        subtitle={`${project?.name ?? "—"} · ${contract.scopeOfWork}`}
        action={
          <div className="flex flex-wrap gap-2">
            <button
              onClick={() => setShowEditForm(true)}
              className="flex items-center gap-2 rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50"
            >
              <Pencil size={15} /> Edit Contract
            </button>
            {eligibleForPayment.length > 0 && (
              <button
                onClick={handleRecordPaymentClick}
                className="flex items-center gap-2 rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50"
              >
                <Receipt size={16} /> Record Payment
              </button>
            )}
            <button
              onClick={() => setShowAdvanceForm(true)}
              disabled={isClosed || projectClosed}
              className="flex items-center gap-2 rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50 disabled:cursor-not-allowed disabled:opacity-40"
            >
              <Wallet size={16} /> New Advance
            </button>
            <button
              onClick={() => setShowCertificateForm(true)}
              disabled={isClosed || projectClosed}
              className="flex items-center gap-2 rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-40"
            >
              <Plus size={16} /> New Certificate
            </button>
          </div>
        }
      />

      {projectClosed && (
        <div className="mb-4 rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-800">
          {project?.name} is closed — new advances and certificates cannot be created against it until it's
          reopened. Historical activity below remains fully visible.
        </div>
      )}
      {!projectClosed && isClosed && (
        <div className="mb-4 rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-800">
          This subcontract is closed — new advances and certificates are blocked. Settling an existing
          payable via payment remains allowed. Historical activity below remains fully visible.
        </div>
      )}

      <div className="mb-1.5 text-xs font-medium uppercase tracking-wide text-slate-400">Contract Value</div>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <StatCard label="Revised Contract" value={revisedValue} icon={Hash} hint={`Original ${formatAED(contract.originalContractValue)} + Variations ${formatAED(contract.approvedVariations)}`} />
        <StatCard label="Certified To Date" value={certifiedToDate} icon={FileCheck2} />
        <StatCard label="Remaining Value" value={remainingValue} icon={Receipt} />
      </div>

      <div className="mt-5 mb-1.5 text-xs font-medium uppercase tracking-wide text-slate-400">Financial Position</div>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label="Advance Paid" value={advancePaid} icon={Wallet} hint={`Recovered ${formatAED(advanceRecovered)}`} />
        <StatCard label="Advance Balance" value={advanceBalance} icon={Wallet} hint="Unrecovered" />
        <StatCard label="Retention Held" value={retentionHeld} icon={Landmark} />
        <StatCard
          label="Outstanding Payable"
          value={outstandingPayable}
          icon={ListChecks}
          tone={outstandingPayable > 0 ? "warning" : "default"}
          hint={`Created ${formatAED(payableCreated)} − Paid ${formatAED(paymentsMade)}`}
        />
      </div>

      <Card className="mt-6">
        <CardHeader title="Contract Activity" subtitle={`${activity.length} entries — advances, certificates, and payments`} />
        <div className="divide-y divide-slate-100">
          {activity.length === 0 && (
            <p className="px-5 py-8 text-center text-sm text-slate-400">No activity recorded on this contract yet.</p>
          )}
          {activity.map((row) => (
            <div
              key={row.key}
              onClick={row.onClick}
              className={`flex w-full items-center justify-between px-5 py-3.5 text-left ${row.onClick ? "cursor-pointer hover:bg-slate-50" : ""}`}
            >
              <div className="flex items-center gap-3">
                <Badge tone={row.kind === "CERTIFICATE" ? "blue" : row.kind === "ADVANCE" ? "amber" : "green"}>
                  {row.kind === "CERTIFICATE" ? "Certificate" : row.kind === "ADVANCE" ? "Advance" : "Payment"}
                </Badge>
                <div>
                  <p className="text-sm font-medium text-slate-800">{row.reference}</p>
                  <p className="text-xs text-slate-400">{formatDate(row.date)}</p>
                </div>
              </div>
              <div className="text-right">
                <p className="text-sm font-semibold text-slate-900">{formatAED(row.amount)}</p>
                {row.kind === "CERTIFICATE" && (
                  <Badge tone={CERT_STATUS_TONE[row.status as CertificateStatus]}>{row.status.replace("_", " ")}</Badge>
                )}
              </div>
            </div>
          ))}
        </div>
      </Card>

      {showEditForm && (
        <Modal title="Edit Contract" onClose={() => setShowEditForm(false)} width="max-w-2xl">
          <SubcontractForm contract={contract} onDone={() => setShowEditForm(false)} />
        </Modal>
      )}

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

      {showPaymentPicker && (
        <Modal title="Select Certificate to Pay" onClose={() => setShowPaymentPicker(false)}>
          <div className="space-y-2">
            {eligibleForPayment.map(({ certificate, outstanding }) => (
              <button
                key={certificate.id}
                onClick={() => {
                  setShowPaymentPicker(false);
                  setPayingCertificateId(certificate.id);
                }}
                className="flex w-full items-center justify-between rounded-lg border border-slate-200 px-3 py-2.5 text-left hover:bg-slate-50"
              >
                <span className="text-sm font-medium text-slate-800">{certificate.certificateNumber}</span>
                <span className="text-sm font-semibold text-slate-900">{formatAED(outstanding)} outstanding</span>
              </button>
            ))}
          </div>
        </Modal>
      )}

      {payingCertificate && (
        <Modal title={`Record Payment · ${payingCertificate.certificateNumber}`} onClose={() => setPayingCertificateId(null)}>
          <SubcontractorPaymentForm certificate={payingCertificate} onDone={() => setPayingCertificateId(null)} />
        </Modal>
      )}
    </div>
  );
}
