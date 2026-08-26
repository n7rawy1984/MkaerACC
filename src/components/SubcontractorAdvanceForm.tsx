import { useMemo, useState } from "react";
import { useAppData, type NewSubcontractorAdvanceInput } from "../state/AppDataContext";
import { Field, inputClassName } from "./ui/Field";
import { useT } from "../i18n/I18nContext";
import type { PaymentMethod, SubcontractorFundingSourceType } from "../domain/types";

const today = () => new Date().toISOString().slice(0, 10);

export function SubcontractorAdvanceForm({
  contractId,
  onDone,
}: {
  contractId: string;
  onDone: () => void;
}) {
  const t = useT();
  const { parties, subcontracts, treasuryAccounts, addSubcontractorAdvance } = useAppData();
  const owners = useMemo(() => parties.filter((p) => p.type === "OWNER"), [parties]);
  const custodians = useMemo(() => parties.filter((p) => p.type === "CUSTODIAN"), [parties]);
  const contract = subcontracts.find((c) => c.id === contractId);

  const eligibleTreasuryAccounts = useMemo(
    () => treasuryAccounts.filter((t) => t.status === "ACTIVE" && (!t.projectId || t.projectId === contract?.projectId)),
    [treasuryAccounts, contract?.projectId],
  );

  const [date, setDate] = useState(today());
  const [amount, setAmount] = useState("");
  const [paymentSourceType, setPaymentSourceType] = useState<SubcontractorFundingSourceType>("TREASURY");
  const [paymentSourcePartyId, setPaymentSourcePartyId] = useState("");
  const [treasuryAccountId, setTreasuryAccountId] = useState(eligibleTreasuryAccounts[0]?.id ?? "");
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>("TRANSFER");
  const [reference, setReference] = useState("");
  const [notes, setNotes] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitError, setSubmitError] = useState("");

  const needsParty = paymentSourceType === "OWNER" || paymentSourceType === "CUSTODIAN";
  const needsTreasury = paymentSourceType === "TREASURY";
  const partyOptions = paymentSourceType === "OWNER" ? owners : custodians;

  function validate(): Record<string, string> {
    const e: Record<string, string> = {};
    const n = Number(amount);
    if (!Number.isFinite(n) || n <= 0) e.amount = t("common.enterAmountGreaterThanZero");
    if (needsParty && !paymentSourcePartyId) e.paymentSourcePartyId = t("subcontractorAdvanceForm.selectSource");
    if (needsTreasury && !treasuryAccountId) e.treasuryAccountId = t("common.selectCashBankAccount");
    return e;
  }

  function handleSubmit(ev: React.FormEvent) {
    ev.preventDefault();
    const validation = validate();
    setErrors(validation);
    setSubmitError("");
    if (Object.keys(validation).length > 0) return;

    const input: NewSubcontractorAdvanceInput = {
      contractId,
      date,
      amount: Number(amount),
      paymentSourceType,
      paymentSourcePartyId: needsParty ? paymentSourcePartyId : undefined,
      treasuryAccountId: needsTreasury ? treasuryAccountId : undefined,
      paymentMethod,
      reference: reference.trim() || undefined,
      notes: notes.trim() || undefined,
    };
    try {
      addSubcontractorAdvance(input);
      onDone();
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : t("subcontractorAdvanceForm.saveError"));
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
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
            placeholder="0.00"
          />
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field label={t("common.paidFrom")} required>
          <select
            value={paymentSourceType}
            onChange={(e) => {
              setPaymentSourceType(e.target.value as SubcontractorFundingSourceType);
              setPaymentSourcePartyId("");
            }}
            className={inputClassName}
          >
            <option value="TREASURY">{t("common.paidFromTreasury")}</option>
            <option value="OWNER">{t("common.ownerCurrentAccount")}</option>
            <option value="CUSTODIAN">{t("common.custodian")}</option>
          </select>
        </Field>
        {needsTreasury ? (
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
        ) : needsParty ? (
          <Field
            label={paymentSourceType === "OWNER" ? t("common.owner") : t("common.custodian")}
            required
            error={errors.paymentSourcePartyId}
          >
            <select
              value={paymentSourcePartyId}
              onChange={(e) => setPaymentSourcePartyId(e.target.value)}
              className={inputClassName}
            >
              <option value="">{t("common.selectEllipsis")}</option>
              {partyOptions.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
          </Field>
        ) : (
          <Field label={t("advanceForm.paymentMethod")}>
            <select
              value={paymentMethod}
              onChange={(e) => setPaymentMethod(e.target.value as PaymentMethod)}
              className={inputClassName}
            >
              <option value="CASH">{t("paymentMethod.CASH")}</option>
              <option value="BANK">{t("paymentMethod.BANK")}</option>
              <option value="TRANSFER">{t("paymentMethod.TRANSFER")}</option>
              <option value="CHEQUE">{t("paymentMethod.CHEQUE")}</option>
              <option value="OTHER">{t("paymentMethod.OTHER")}</option>
            </select>
          </Field>
        )}
      </div>

      <Field label={t("common.referenceOptional")}>
        <input value={reference} onChange={(e) => setReference(e.target.value)} className={inputClassName} />
      </Field>

      <Field label={t("common.notesOptional")}>
        <textarea value={notes} onChange={(e) => setNotes(e.target.value)} className={inputClassName} rows={2} />
      </Field>

      <div className="rounded-lg bg-slate-50 px-3 py-2 text-xs text-slate-500">
        {t("subcontractorAdvanceForm.recoverableHint")}
      </div>

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
          {t("subcontractorAdvanceForm.saveButton")}
        </button>
      </div>
    </form>
  );
}
