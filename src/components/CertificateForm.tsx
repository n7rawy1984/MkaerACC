import { useMemo, useState } from "react";
import { Plus, Trash2 } from "lucide-react";
import { useAppData } from "../state/AppDataContext";
import { Field, inputClassName } from "./ui/Field";
import { Badge } from "../components/ui/Badge";
import { formatAED } from "../domain/money";
import { formatDate } from "../domain/utils";
import { calcCertificate, validateCertificate } from "../accounting/certificateCalc";
import { certificatePaidAmount, contractAdvanceBalance } from "../accounting/ledger";
import { ACCOUNTS, DEDUCTION_ACCOUNT_IDS } from "../accounting/chartOfAccounts";
import { SubcontractorPaymentForm } from "./SubcontractorPaymentForm";
import { useT } from "../i18n/I18nContext";
import type { TranslationKey } from "../i18n/en";
import type { CertificateDeduction, DeductionType, SubcontractorCertificate, VatMode } from "../domain/types";

const today = () => new Date().toISOString().slice(0, 10);

const DEDUCTION_TYPE_DEFAULT_ACCOUNT: Record<DeductionType, string> = {
  COMPANY_MATERIALS: ACCOUNTS.DEDUCTION_COMPANY_MATERIALS,
  BACKCHARGE: ACCOUNTS.DEDUCTION_BACKCHARGE,
  OTHER: ACCOUNTS.DEDUCTION_OTHER,
};

const DEDUCTION_TYPE_KEY: Record<DeductionType, TranslationKey> = {
  COMPANY_MATERIALS: "certificateForm.deductionType.COMPANY_MATERIALS",
  BACKCHARGE: "certificateForm.deductionType.BACKCHARGE",
  OTHER: "certificateForm.deductionType.OTHER",
};

const CERT_STATUS_KEY: Record<string, TranslationKey> = {
  DRAFT: "certificateStatus.DRAFT",
  APPROVED: "certificateStatus.APPROVED",
  PARTIALLY_PAID: "certificateStatus.PARTIALLY_PAID",
  PAID: "certificateStatus.PAID",
};

let deductionCounter = 0;
function newDeductionId(): string {
  deductionCounter += 1;
  return `ded_new_${deductionCounter}`;
}

export function CertificateForm({
  contractId,
  certificate,
  onDone,
}: {
  contractId: string;
  certificate?: SubcontractorCertificate;
  onDone: () => void;
}) {
  const t = useT();
  const {
    subcontracts,
    subcontractorCertificates,
    subcontractorPayments,
    journalEntries,
    accounts,
    addCertificateDraft,
    updateCertificateDraft,
    approveCertificate,
  } = useAppData();

  const contract = subcontracts.find((c) => c.id === contractId);
  const accountsById = useMemo(() => Object.fromEntries(accounts.map((a) => [a.id, a])), [accounts]);

  const isEditing = Boolean(certificate);
  const isLocked = certificate ? certificate.status !== "DRAFT" : false;

  const priorCertificates = useMemo(
    () =>
      subcontractorCertificates
        .filter((c) => c.contractId === contractId && c.id !== certificate?.id)
        .sort((a, b) => (a.certificateDate < b.certificateDate ? 1 : -1)),
    [subcontractorCertificates, contractId, certificate?.id],
  );

  const defaultPreviousCertified = priorCertificates[0]?.workValueToDate ?? 0;
  const contractSuffix = contract?.contractNumber.replace(/^SC-/, "") ?? "";
  const defaultCertificateNumber = `PC-${contractSuffix}-${String(
    subcontractorCertificates.filter((c) => c.contractId === contractId).length + 1,
  ).padStart(2, "0")}`;

  const [certificateNumber, setCertificateNumber] = useState(certificate?.certificateNumber ?? defaultCertificateNumber);
  const [certificateDate, setCertificateDate] = useState(certificate?.certificateDate ?? today());
  const [workValueToDate, setWorkValueToDate] = useState(String(certificate?.workValueToDate ?? ""));
  const [previousCertifiedWork, setPreviousCertifiedWork] = useState(
    String(certificate?.previousCertifiedWork ?? defaultPreviousCertified),
  );
  const [currentVariationAmount, setCurrentVariationAmount] = useState(
    String(certificate?.currentVariationAmount ?? 0),
  );
  const [retentionPercent, setRetentionPercent] = useState(
    String(certificate?.retentionPercent ?? contract?.retentionPercent ?? 0),
  );
  const [advanceRecovery, setAdvanceRecovery] = useState(String(certificate?.advanceRecovery ?? 0));
  const [deductionLines, setDeductionLines] = useState<CertificateDeduction[]>(certificate?.deductionLines ?? []);
  const [vatMode, setVatMode] = useState<VatMode>(certificate?.vatMode ?? "ZERO");
  const [manualVatAmount, setManualVatAmount] = useState(
    certificate?.vatMode === "MANUAL" ? String(certificate.vatAmount) : "",
  );
  const [taxInvoiceReceived, setTaxInvoiceReceived] = useState(certificate?.taxInvoiceReceived ?? false);
  const [taxInvoiceNumber, setTaxInvoiceNumber] = useState(certificate?.taxInvoiceNumber ?? "");
  const [taxInvoiceDate, setTaxInvoiceDate] = useState(certificate?.taxInvoiceDate ?? "");
  const [notes, setNotes] = useState(certificate?.notes ?? "");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [actionError, setActionError] = useState("");
  const [showPaymentForm, setShowPaymentForm] = useState(false);

  const parsedDeductionAmounts = deductionLines.map((d) => d.amount);

  const calc = useMemo(
    () =>
      calcCertificate({
        workValueToDate: Number(workValueToDate) || 0,
        previousCertifiedWork: Number(previousCertifiedWork) || 0,
        currentVariationAmount: Number(currentVariationAmount) || 0,
        retentionPercent: Number(retentionPercent) || 0,
        advanceRecovery: Number(advanceRecovery) || 0,
        deductionAmounts: parsedDeductionAmounts,
        vatMode,
        manualVatAmount: Number(manualVatAmount) || 0,
      }),
    // eslint-disable-next-line react-hooks/exhaustive-deps
    [workValueToDate, previousCertifiedWork, currentVariationAmount, retentionPercent, advanceRecovery, JSON.stringify(parsedDeductionAmounts), vatMode, manualVatAmount],
  );

  const availableAdvanceBalance = contract ? contractAdvanceBalance(journalEntries, contract.id) : 0;
  const revisedContractValue = contract ? contract.originalContractValue + contract.approvedVariations : 0;

  const alreadyPaid = certificate ? certificatePaidAmount(subcontractorPayments, certificate.id) : 0;
  const outstanding = certificate ? certificate.netPayable - alreadyPaid : 0;

  function addDeductionLine() {
    setDeductionLines((prev) => [
      ...prev,
      { id: newDeductionId(), description: "", amount: 0, type: "OTHER", accountId: ACCOUNTS.DEDUCTION_OTHER },
    ]);
  }

  function updateDeductionLine(id: string, patch: Partial<CertificateDeduction>) {
    setDeductionLines((prev) => prev.map((d) => (d.id === id ? { ...d, ...patch } : d)));
  }

  function removeDeductionLine(id: string) {
    setDeductionLines((prev) => prev.filter((d) => d.id !== id));
  }

  function runValidation(): Record<string, string> {
    return validateCertificate(
      {
        workValueToDate: Number(workValueToDate) || 0,
        previousCertifiedWork: Number(previousCertifiedWork) || 0,
        currentVariationAmount: Number(currentVariationAmount) || 0,
        retentionPercent: Number(retentionPercent) || 0,
        advanceRecovery: Number(advanceRecovery) || 0,
        deductionAmounts: parsedDeductionAmounts,
        vatMode,
      },
      calc,
      {
        revisedContractValue,
        availableAdvanceBalance,
        deductionAmounts: parsedDeductionAmounts,
        taxInvoiceReceived,
        taxInvoiceNumber,
        taxInvoiceDate,
      },
    );
  }

  function buildInput() {
    return {
      contractId,
      certificateNumber: certificateNumber.trim(),
      certificateDate,
      workValueToDate: Number(workValueToDate) || 0,
      previousCertifiedWork: Number(previousCertifiedWork) || 0,
      currentVariationAmount: Number(currentVariationAmount) || 0,
      retentionPercent: Number(retentionPercent) || 0,
      advanceRecovery: Number(advanceRecovery) || 0,
      deductionLines,
      vatMode,
      manualVatAmount: vatMode === "MANUAL" ? Number(manualVatAmount) || 0 : undefined,
      taxInvoiceReceived,
      taxInvoiceNumber: taxInvoiceNumber.trim() || undefined,
      taxInvoiceDate: taxInvoiceDate || undefined,
      notes: notes.trim() || undefined,
    };
  }

  function handleSaveDraft(ev: React.FormEvent) {
    ev.preventDefault();
    if (!certificateNumber.trim() || !workValueToDate) {
      setErrors({
        certificateNumber: !certificateNumber.trim() ? t("common.required") : "",
        workValueToDate: !workValueToDate ? t("common.required") : "",
      });
      return;
    }
    setErrors({});
    setActionError("");
    try {
      if (isEditing && certificate) {
        updateCertificateDraft(certificate.id, buildInput());
      } else {
        addCertificateDraft(buildInput());
      }
      onDone();
    } catch (err) {
      setActionError(err instanceof Error ? err.message : t("certificateForm.saveError"));
    }
  }

  function handleApprove() {
    if (!certificate) return;
    const validation = runValidation();
    setErrors(validation);
    if (Object.keys(validation).length > 0) return;
    setActionError("");
    try {
      updateCertificateDraft(certificate.id, buildInput());
      approveCertificate(certificate.id);
      onDone();
    } catch (err) {
      setActionError(err instanceof Error ? err.message : t("certificateForm.approveError"));
    }
  }

  if (!contract) return <p className="text-sm text-slate-400">{t("certificateForm.contractNotFound")}</p>;

  return (
    <div className="space-y-4">
      {isLocked && (
        <div className="flex items-center justify-between rounded-lg bg-slate-50 px-3 py-2">
          <div className="flex items-center gap-2 text-xs text-slate-500">
            <Badge tone={certificate?.status === "PAID" ? "green" : certificate?.status === "PARTIALLY_PAID" ? "amber" : "blue"}>
              {certificate ? t(CERT_STATUS_KEY[certificate.status]) : ""}
            </Badge>
            {t("certificateForm.approvedOnLocked", {
              date: certificate?.approvedAt ? formatDate(certificate.approvedAt) : "",
            })}
          </div>
        </div>
      )}

      <form onSubmit={handleSaveDraft} className="space-y-4">
        <div className="grid grid-cols-2 gap-4">
          <Field label={t("certificateForm.certificateNumber")} required error={errors.certificateNumber}>
            <input
              value={certificateNumber}
              onChange={(e) => setCertificateNumber(e.target.value)}
              className={inputClassName}
              disabled={isLocked}
            />
          </Field>
          <Field label={t("certificateForm.certificateDate")} required>
            <input
              type="date"
              value={certificateDate}
              onChange={(e) => setCertificateDate(e.target.value)}
              className={inputClassName}
              disabled={isLocked}
            />
          </Field>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <Field label={t("certificateForm.workValueToDateAed")} required error={errors.workValueToDate}>
            <input
              type="number"
              min="0"
              step="0.01"
              value={workValueToDate}
              onChange={(e) => setWorkValueToDate(e.target.value)}
              className={inputClassName}
              disabled={isLocked}
            />
          </Field>
          <Field label={t("certificateForm.previousCertifiedWorkAed")}>
            <input
              type="number"
              min="0"
              step="0.01"
              value={previousCertifiedWork}
              onChange={(e) => setPreviousCertifiedWork(e.target.value)}
              className={inputClassName}
              disabled={isLocked}
            />
          </Field>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <Field label={t("certificateForm.currentVariationsAed")} error={errors.currentVariationAmount}>
            <input
              type="number"
              step="0.01"
              value={currentVariationAmount}
              onChange={(e) => setCurrentVariationAmount(e.target.value)}
              className={inputClassName}
              disabled={isLocked}
            />
          </Field>
          <Field label={t("certificateForm.retentionPercent")} error={errors.retentionPercent}>
            <input
              type="number"
              min="0"
              max="100"
              step="0.1"
              value={retentionPercent}
              onChange={(e) => setRetentionPercent(e.target.value)}
              className={inputClassName}
              disabled={isLocked}
            />
          </Field>
        </div>

        <Field label={t("certificateForm.advanceRecoveryAed")} error={errors.advanceRecovery}>
          <input
            type="number"
            min="0"
            step="0.01"
            value={advanceRecovery}
            onChange={(e) => setAdvanceRecovery(e.target.value)}
            className={inputClassName}
            disabled={isLocked}
          />
        </Field>
        <p className="-mt-2 text-xs text-slate-400">
          {t("certificateForm.availableAdvanceBalanceHint", { amount: formatAED(availableAdvanceBalance) })}
        </p>

        <div>
          <div className="mb-1.5 flex items-center justify-between">
            <p className="text-xs font-medium text-slate-600">{t("certificateForm.deductionsTitle")}</p>
            {!isLocked && (
              <button
                type="button"
                onClick={addDeductionLine}
                className="flex items-center gap-1 text-xs font-medium text-slate-500 hover:text-slate-900"
              >
                <Plus size={13} /> {t("certificateForm.addLine")}
              </button>
            )}
          </div>
          {deductionLines.length === 0 && (
            <p className="text-xs text-slate-400">{t("certificateForm.noDeductions")}</p>
          )}
          <div className="space-y-2">
            {deductionLines.map((d) => (
              <div key={d.id} className="grid grid-cols-12 gap-2 rounded-lg border border-slate-200 p-2">
                <input
                  value={d.description}
                  onChange={(e) => updateDeductionLine(d.id, { description: e.target.value })}
                  placeholder={t("certificateForm.deductionDescriptionPlaceholder")}
                  className={`${inputClassName} col-span-5`}
                  disabled={isLocked}
                />
                <select
                  value={d.type}
                  onChange={(e) => {
                    const type = e.target.value as DeductionType;
                    updateDeductionLine(d.id, { type, accountId: DEDUCTION_TYPE_DEFAULT_ACCOUNT[type] });
                  }}
                  className={`${inputClassName} col-span-3`}
                  disabled={isLocked}
                >
                  {(Object.keys(DEDUCTION_TYPE_KEY) as DeductionType[]).map((type) => (
                    <option key={type} value={type}>
                      {t(DEDUCTION_TYPE_KEY[type])}
                    </option>
                  ))}
                </select>
                <select
                  value={d.accountId}
                  onChange={(e) => updateDeductionLine(d.id, { accountId: e.target.value })}
                  className={`${inputClassName} col-span-3`}
                  disabled={isLocked}
                  title={t("certificateForm.deductionsTitle")}
                >
                  {DEDUCTION_ACCOUNT_IDS.map((id) => (
                    <option key={id} value={id}>
                      {accountsById[id]?.name ?? id}
                    </option>
                  ))}
                </select>
                <input
                  type="number"
                  min="0"
                  step="0.01"
                  value={d.amount}
                  onChange={(e) => updateDeductionLine(d.id, { amount: Number(e.target.value) || 0 })}
                  placeholder="0.00"
                  className={`${inputClassName} col-span-1`}
                  disabled={isLocked}
                />
                {!isLocked && (
                  <button
                    type="button"
                    onClick={() => removeDeductionLine(d.id)}
                    className="col-span-12 flex items-center justify-end gap-1 text-xs text-rose-500 hover:text-rose-700"
                  >
                    <Trash2 size={12} /> {t("certificateForm.remove")}
                  </button>
                )}
              </div>
            ))}
          </div>
        </div>

        <div className="grid grid-cols-2 gap-4">
          <Field label={t("field.vat")}>
            <select
              value={vatMode}
              onChange={(e) => setVatMode(e.target.value as VatMode)}
              className={inputClassName}
              disabled={isLocked}
            >
              <option value="ZERO">{t("vatMode.ZERO")}</option>
              <option value="AUTO_5">{t("vatMode.AUTO_5")}</option>
              <option value="MANUAL">{t("vatMode.MANUAL")}</option>
            </select>
          </Field>
          {vatMode === "MANUAL" && (
            <Field label={t("field.vatAmountAed")}>
              <input
                type="number"
                min="0"
                step="0.01"
                value={manualVatAmount}
                onChange={(e) => setManualVatAmount(e.target.value)}
                className={inputClassName}
                disabled={isLocked}
              />
            </Field>
          )}
        </div>

        {calc.vatAmount > 0 && (
          <div className="space-y-3 rounded-lg border border-amber-200 bg-amber-50 p-3">
            <p className="text-xs font-medium text-amber-800">{t("certificateForm.vatRequiresInvoice")}</p>
            <label className="flex items-center gap-2 text-sm text-slate-700">
              <input
                type="checkbox"
                checked={taxInvoiceReceived}
                onChange={(e) => setTaxInvoiceReceived(e.target.checked)}
                className="h-4 w-4 rounded border-slate-300"
                disabled={isLocked}
              />
              {t("certificateForm.taxInvoiceReceived")}
            </label>
            {errors.taxInvoiceReceived && <p className="text-xs text-rose-500">{errors.taxInvoiceReceived}</p>}
            <div className="grid grid-cols-2 gap-3">
              <Field label={t("certificateForm.taxInvoiceNumber")} error={errors.taxInvoiceNumber}>
                <input
                  value={taxInvoiceNumber}
                  onChange={(e) => setTaxInvoiceNumber(e.target.value)}
                  className={inputClassName}
                  disabled={isLocked}
                />
              </Field>
              <Field label={t("certificateForm.taxInvoiceDate")} error={errors.taxInvoiceDate}>
                <input
                  type="date"
                  value={taxInvoiceDate}
                  onChange={(e) => setTaxInvoiceDate(e.target.value)}
                  className={inputClassName}
                  disabled={isLocked}
                />
              </Field>
            </div>
          </div>
        )}

        <Field label={t("common.notesOptional")}>
          <textarea
            value={notes}
            onChange={(e) => setNotes(e.target.value)}
            className={inputClassName}
            rows={2}
            disabled={isLocked}
          />
        </Field>

        {/* Calculation waterfall — always visible, never hidden */}
        <div className="space-y-1 rounded-lg border border-slate-200 bg-slate-50 p-4 text-sm">
          <Row label={t("certificateForm.rowWorkValueToDate")} value={Number(workValueToDate) || 0} />
          <Row label={t("certificateForm.rowPreviousCertified")} value={-(Number(previousCertifiedWork) || 0)} />
          <Row label={t("certificateForm.rowCurrentWork")} value={calc.currentWorkValue} bold />
          <Row label={t("certificateForm.rowCurrentVariations")} value={Number(currentVariationAmount) || 0} prefix="+" />
          <Row label={t("certificateForm.rowGrossCurrentCertificate")} value={calc.grossCurrentValue} bold divider />
          <Row label={t("certificateForm.rowRetention")} value={-calc.retentionAmount} />
          <Row label={t("certificateForm.rowAdvanceRecovery")} value={-(Number(advanceRecovery) || 0)} />
          <Row label={t("certificateForm.rowOtherDeductions")} value={-calc.totalDeductions} />
          <Row label={t("certificateForm.rowNetBeforeVat")} value={calc.netBeforeVat} bold divider />
          <Row label={t("certificateForm.rowVat")} value={calc.vatAmount} prefix="+" />
          <Row label={t("certificateForm.rowNetPayable")} value={calc.netPayable} bold big divider />
        </div>

        {errors.netPayable && <p className="text-xs text-rose-500">{errors.netPayable}</p>}
        {errors.deductionLines && <p className="text-xs text-rose-500">{errors.deductionLines}</p>}
        {actionError && <p className="text-xs text-rose-500">{actionError}</p>}

        {!isLocked && (
          <div className="flex justify-end gap-2 pt-2">
            <button
              type="button"
              onClick={onDone}
              className="rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50"
            >
              {t("common.cancel")}
            </button>
            <button
              type="submit"
              className="rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50"
            >
              {t("certificateForm.saveDraft")}
            </button>
            {isEditing && (
              <button
                type="button"
                onClick={handleApprove}
                className="rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800"
              >
                {t("certificateForm.approve")}
              </button>
            )}
          </div>
        )}
      </form>

      {isLocked && certificate && (
        <div className="border-t border-slate-100 pt-4">
          <div className="mb-2 flex items-center justify-between">
            <p className="text-sm font-semibold text-slate-900">{t("certificateForm.paymentsTitle")}</p>
            {outstanding > 0.01 && !showPaymentForm && (
              <button
                type="button"
                onClick={() => setShowPaymentForm(true)}
                className="rounded-lg bg-slate-900 px-3 py-1.5 text-xs font-medium text-white hover:bg-slate-800"
              >
                {t("contractWorkspace.recordPayment")}
              </button>
            )}
          </div>
          {showPaymentForm ? (
            <SubcontractorPaymentForm certificate={certificate} onDone={() => setShowPaymentForm(false)} />
          ) : (
            <div className="space-y-1 text-sm">
              {subcontractorPayments
                .filter((p) => p.certificateId === certificate.id)
                .map((p) => (
                  <div key={p.id} className="flex items-center justify-between">
                    <span className="text-slate-600">
                      {formatDate(p.date)} {p.reference ? `· ${p.reference}` : ""}
                    </span>
                    <span className="font-medium text-slate-900">{formatAED(p.amount)}</span>
                  </div>
                ))}
              {subcontractorPayments.filter((p) => p.certificateId === certificate.id).length === 0 && (
                <p className="text-xs text-slate-400">{t("certificateForm.noPaymentsYet")}</p>
              )}
              <div className="mt-2 flex items-center justify-between border-t border-slate-100 pt-2 font-semibold">
                <span className="text-slate-600">{t("certificateForm.outstanding")}</span>
                <span className="text-slate-900">{formatAED(Math.max(0, outstanding))}</span>
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

function Row({
  label,
  value,
  bold,
  big,
  divider,
  prefix,
}: {
  label: string;
  value: number;
  bold?: boolean;
  big?: boolean;
  divider?: boolean;
  prefix?: string;
}) {
  return (
    <div
      className={`flex items-center justify-between ${divider ? "border-t border-slate-200 pt-1.5 mt-1.5" : ""} ${
        bold ? "font-semibold text-slate-900" : "text-slate-500"
      } ${big ? "text-base" : ""}`}
    >
      <span>{label}</span>
      <span>
        {prefix ?? (value < 0 ? "" : "")}
        {formatAED(value)}
      </span>
    </div>
  );
}
