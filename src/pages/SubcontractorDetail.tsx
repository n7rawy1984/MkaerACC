import { useMemo, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { ArrowLeft, ArrowRight, HardHat, Pencil, Plus } from "lucide-react";
import { useAppData } from "../state/AppDataContext";
import { PageHeader } from "../components/layout/AppShell";
import { Card, CardHeader } from "../components/ui/Card";
import { Badge } from "../components/ui/Badge";
import { StatCard } from "../components/ui/StatCard";
import { Modal } from "../components/ui/Modal";
import { SubcontractorForm } from "../components/SubcontractorForm";
import { SubcontractForm } from "../components/SubcontractForm";
import { formatAED } from "../domain/money";
import { indexById } from "../domain/utils";
import {
  contractCertifiedCost,
  contractPayableBalance,
  contractRetentionHeld,
  subcontractorAdvanceBalance,
  subcontractorPayableBalance,
  subcontractorRetentionHeld,
} from "../accounting/ledger";
import { FileCheck2, Landmark, ListChecks, Wallet } from "lucide-react";
import { useT } from "../i18n/I18nContext";
import type { TranslationKey } from "../i18n/en";
import type { SubcontractStatus } from "../domain/types";

const STATUS_TONE: Record<SubcontractStatus, "green" | "slate" | "amber"> = {
  ACTIVE: "green",
  COMPLETED: "slate",
  CLOSED: "slate",
};

const STATUS_KEY: Record<SubcontractStatus, TranslationKey> = {
  ACTIVE: "subcontractStatus.ACTIVE",
  COMPLETED: "subcontractStatus.COMPLETED",
  CLOSED: "subcontractStatus.CLOSED",
};

export function SubcontractorDetail() {
  const t = useT();
  const { id } = useParams<{ id: string }>();
  const { parties, subcontracts, projects, journalEntries } = useAppData();
  const navigate = useNavigate();
  const [showEditForm, setShowEditForm] = useState(false);
  const [showContractForm, setShowContractForm] = useState(false);

  const subcontractor = parties.find((p) => p.id === id && p.type === "SUBCONTRACTOR");
  const projectsById = useMemo(() => indexById(projects), [projects]);

  const contracts = useMemo(
    () => subcontracts.filter((c) => c.subcontractorId === id),
    [subcontracts, id],
  );

  if (!subcontractor) {
    return (
      <div>
        <Link to="/subcontractors" className="text-sm text-slate-500 hover:text-slate-900">
          &larr; {t("subcontractorDetail.backToSubcontractors")}
        </Link>
        <p className="mt-4 text-sm text-slate-500">{t("subcontractorDetail.notFound")}</p>
      </div>
    );
  }

  const payable = subcontractorPayableBalance(journalEntries, subcontractor.id);
  const retention = subcontractorRetentionHeld(journalEntries, subcontractor.id);
  const advanceBalance = subcontractorAdvanceBalance(journalEntries, subcontractor.id);
  const certifiedToDate = contracts.reduce((sum, c) => sum + contractCertifiedCost(journalEntries, c.id), 0);

  return (
    <div>
      <Link
        to="/subcontractors"
        className="mb-3 inline-flex items-center gap-1 text-sm text-slate-500 hover:text-slate-900"
      >
        <ArrowLeft size={14} className="rtl:-scale-x-100" /> {t("subcontractorDetail.backToSubcontractors")}
      </Link>
      <PageHeader
        title={subcontractor.name}
        subtitle={[
          subcontractor.code,
          subcontractor.contactPerson,
          subcontractor.phone,
          subcontractor.taxRegistrationNumber
            ? t("company.trn", { trn: subcontractor.taxRegistrationNumber })
            : undefined,
        ]
          .filter(Boolean)
          .join(" · ") || "—"}
        action={
          <div className="flex gap-2">
            <button
              onClick={() => setShowEditForm(true)}
              className="flex items-center gap-2 rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50"
            >
              <Pencil size={15} /> {t("subcontractorDetail.editSubcontractor")}
            </button>
            <button
              onClick={() => setShowContractForm(true)}
              disabled={subcontractor.status === "INACTIVE"}
              className="flex items-center gap-2 rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800 disabled:cursor-not-allowed disabled:opacity-40"
            >
              <Plus size={16} /> {t("subcontractorDetail.newSubcontract")}
            </button>
          </div>
        }
      />

      {subcontractor.status === "INACTIVE" && (
        <div className="mb-4 rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-800">
          {t("subcontractorDetail.inactiveBanner")}
        </div>
      )}

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <StatCard label={t("dashboard.totalCertified")} value={certifiedToDate} icon={FileCheck2} />
        <StatCard
          label={t("dashboard.outstandingPayable")}
          value={payable}
          icon={ListChecks}
          tone={payable > 0 ? "warning" : "default"}
        />
        <StatCard label={t("dashboard.retentionHeld")} value={retention} icon={Landmark} />
        <StatCard
          label={t("subcontractors.colAdvanceBalance")}
          value={advanceBalance}
          icon={Wallet}
          hint={t("subcontractorDetail.advanceBalanceHint")}
        />
      </div>

      <Card className="mt-6">
        <CardHeader
          title={t("subcontractorDetail.contractsTitle")}
          subtitle={t("subcontractorDetail.contractCount", { count: contracts.length })}
        />
        <div className="divide-y divide-slate-100">
          {contracts.length === 0 && (
            <p className="px-5 py-8 text-center text-sm text-slate-400">{t("subcontractorDetail.noContractsYet")}</p>
          )}
          {contracts.map((c) => (
            <button
              key={c.id}
              onClick={() => navigate(`/subcontracts/${c.id}`)}
              className="flex w-full items-center justify-between px-5 py-3.5 text-left hover:bg-slate-50"
            >
              <div className="flex items-center gap-3">
                <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-slate-100 text-slate-500">
                  <HardHat size={16} />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <p className="text-sm font-medium text-slate-800">{c.contractNumber}</p>
                    <Badge tone={STATUS_TONE[c.status]}>{t(STATUS_KEY[c.status])}</Badge>
                  </div>
                  <p className="text-xs text-slate-400">
                    {projectsById[c.projectId]?.name ?? "—"} · {c.scopeOfWork}
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-6">
                <div className="text-right">
                  <p className="text-sm font-semibold text-slate-900">
                    {formatAED(c.originalContractValue + c.approvedVariations)}
                  </p>
                  <p className="text-xs text-slate-400">
                    {t("subcontractorDetail.payableRetentionLine", {
                      payable: formatAED(contractPayableBalance(journalEntries, c.id)),
                      retention: formatAED(contractRetentionHeld(journalEntries, c.id)),
                    })}
                  </p>
                </div>
                <ArrowRight size={14} className="text-slate-300 rtl:-scale-x-100" />
              </div>
            </button>
          ))}
        </div>
      </Card>

      {showEditForm && (
        <Modal title={t("subcontractorDetail.editSubcontractorModalTitle")} onClose={() => setShowEditForm(false)}>
          <SubcontractorForm subcontractor={subcontractor} onDone={() => setShowEditForm(false)} />
        </Modal>
      )}

      {showContractForm && (
        <Modal
          title={t("subcontractorDetail.newSubcontractModalTitle")}
          onClose={() => setShowContractForm(false)}
          width="max-w-2xl"
        >
          <SubcontractForm defaultSubcontractorId={subcontractor.id} onDone={() => setShowContractForm(false)} />
        </Modal>
      )}
    </div>
  );
}
