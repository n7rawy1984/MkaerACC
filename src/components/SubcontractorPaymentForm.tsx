import { useMemo, useState } from "react";
import { useAppData, type NewSubcontractorPaymentInput } from "../state/AppDataContext";
import { Field, inputClassName } from "./ui/Field";
import { formatAED, subtractMoney } from "../domain/money";
import { certificatePaidAmount } from "../accounting/ledger";
import { useT } from "../i18n/I18nContext";
import type { SubcontractorCertificate, SubcontractorPaymentSourceType } from "../domain/types";

const today = () => new Date().toISOString().slice(0, 10);

export function SubcontractorPaymentForm({
  certificate,
  onDone,
}: {
  certificate: SubcontractorCertificate;
  onDone: () => void;
}) {
  const t = useT();
  const { parties, subcontractorPayments, treasuryAccounts, addSubcontractorPayment } = useAppData();
  const owners = useMemo(() => parties.filter((p) => p.type === "OWNER"), [parties]);
  const custodians = useMemo(() => parties.filter((p) => p.type === "CUSTODIAN"), [parties]);
  const eligibleTreasuryAccounts = useMemo(
    () =>
      treasuryAccounts.filter(
        (t) => t.status === "ACTIVE" && (!t.projectId || t.projectId === certificate.projectId),
      ),
    [treasuryAccounts, certificate.projectId],
  );

  const alreadyPaid = useMemo(
    () => certificatePaidAmount(subcontractorPayments, certificate.id),
    [subcontractorPayments, certificate.id],
  );
  const outstanding = subtractMoney(certificate.netPayable, alreadyPaid);

  const [date, setDate] = useState(today());
  const [amount, setAmount] = useState(outstanding.toFixed(2));
  const [sourceType, setSourceType] = useState<SubcontractorPaymentSourceType>("TREASURY");
  const [sourcePartyId, setSourcePartyId] = useState("");
  const [treasuryAccountId, setTreasuryAccountId] = useState(eligibleTreasuryAccounts[0]?.id ?? "");
  const [reference, setReference] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitError, setSubmitError] = useState("");

  const needsParty = sourceType === "OWNER" || sourceType === "CUSTODIAN";
  const needsTreasury = sourceType === "TREASURY";
  const partyOptions = sourceType === "OWNER" ? owners : custodians;

  function validate(): Record<string, string> {
    const e: Record<string, string> = {};
    const n = Number(amount);
    if (!Number.isFinite(n) || n <= 0) e.amount = t("common.enterAmountGreaterThanZero");
    else if (n > outstanding + 0.01)
      e.amount = t("subcontractorPaymentForm.cannotExceedOutstanding", { amount: formatAED(outstanding) });
    if (needsParty && !sourcePartyId) e.sourcePartyId = t("common.selectWhoPaid");
    if (needsTreasury && !treasuryAccountId) e.treasuryAccountId = t("common.selectCashBankAccount");
    return e;
  }

  function handleSubmit(ev: React.FormEvent) {
    ev.preventDefault();
    const validation = validate();
    setErrors(validation);
    setSubmitError("");
    if (Object.keys(validation).length > 0) return;

    const input: NewSubcontractorPaymentInput = {
      certificateId: certificate.id,
      date,
      amount: Number(amount),
      sourceType,
      sourcePartyId: needsParty ? sourcePartyId : undefined,
      treasuryAccountId: needsTreasury ? treasuryAccountId : undefined,
      reference: reference.trim() || undefined,
    };
    try {
      addSubcontractorPayment(input);
      onDone();
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : t("subcontractorPaymentForm.saveError"));
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="rounded-lg bg-slate-50 px-3 py-2 text-xs text-slate-500">
        {t("subcontractorPaymentForm.summaryLine", {
          net: formatAED(certificate.netPayable),
          paid: formatAED(alreadyPaid),
          outstanding: formatAED(outstanding),
        })}
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field label={t("common.date")} required>
          <input type="date" value={date} onChange={(e) => setDate(e.target.value)} className={inputClassName} />
        </Field>
        <Field label={t("common.amountAed")} required error={errors.amount}>
          <input
            type="number"
            min="0"
            step="0.01"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            className={inputClassName}
          />
        </Field>
      </div>

      <Field label={t("common.paidFrom")} required>
        <select
          value={sourceType}
          onChange={(e) => {
            setSourceType(e.target.value as SubcontractorPaymentSourceType);
            setSourcePartyId("");
          }}
          className={inputClassName}
        >
          <option value="TREASURY">{t("common.paidFromTreasury")}</option>
          <option value="OWNER">{t("common.ownerCurrentAccount")}</option>
          <option value="CUSTODIAN">{t("common.custodian")}</option>
        </select>
      </Field>

      {needsTreasury && (
        <Field label={t("common.cashBankAccount")} required error={errors.treasuryAccountId}>
          <select value={treasuryAccountId} onChange={(e) => setTreasuryAccountId(e.target.value)} className={inputClassName}>
            <option value="">{t("common.selectEllipsis")}</option>
            {eligibleTreasuryAccounts.map((account) => (
              <option key={account.id} value={account.id}>
                {account.name}
              </option>
            ))}
          </select>
        </Field>
      )}

      {needsParty && (
        <Field label={sourceType === "OWNER" ? t("common.owner") : t("common.custodian")} required error={errors.sourcePartyId}>
          <select value={sourcePartyId} onChange={(e) => setSourcePartyId(e.target.value)} className={inputClassName}>
            <option value="">{t("common.selectEllipsis")}</option>
            {partyOptions.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </select>
        </Field>
      )}

      <Field label={t("common.referenceOptional")}>
        <input value={reference} onChange={(e) => setReference(e.target.value)} className={inputClassName} />
      </Field>

      {submitError && <p className="text-xs text-rose-500">{submitError}</p>}

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
          className="rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800"
        >
          {t("supplierPaymentForm.saveButton")}
        </button>
      </div>
    </form>
  );
}
