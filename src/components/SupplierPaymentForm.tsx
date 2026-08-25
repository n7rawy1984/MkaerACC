import { useMemo, useState } from "react";
import { useAppData, type NewSupplierPaymentInput } from "../state/AppDataContext";
import { Field, inputClassName } from "./ui/Field";
import type { SupplierPaymentSourceType } from "../domain/types";

const today = () => new Date().toISOString().slice(0, 10);

export function SupplierPaymentForm({
  supplierId,
  onDone,
}: {
  supplierId: string;
  onDone: () => void;
}) {
  const { parties, treasuryAccounts, addSupplierPayment } = useAppData();
  const owners = useMemo(() => parties.filter((p) => p.type === "OWNER"), [parties]);
  const custodians = useMemo(() => parties.filter((p) => p.type === "CUSTODIAN"), [parties]);
  const activeTreasuryAccounts = useMemo(
    () => treasuryAccounts.filter((t) => t.status === "ACTIVE" && !t.projectId),
    [treasuryAccounts],
  );

  const [date, setDate] = useState(today());
  const [amount, setAmount] = useState("");
  const [sourceType, setSourceType] = useState<SupplierPaymentSourceType>("TREASURY");
  const [sourcePartyId, setSourcePartyId] = useState("");
  const [treasuryAccountId, setTreasuryAccountId] = useState(activeTreasuryAccounts[0]?.id ?? "");
  const [reference, setReference] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitError, setSubmitError] = useState("");

  const needsParty = sourceType === "CUSTODIAN" || sourceType === "OWNER";
  const needsTreasury = sourceType === "TREASURY";
  const partyOptions = sourceType === "CUSTODIAN" ? custodians : owners;

  function validate(): Record<string, string> {
    const e: Record<string, string> = {};
    const n = Number(amount);
    if (!Number.isFinite(n) || n <= 0) e.amount = "Enter an amount greater than zero";
    if (needsParty && !sourcePartyId) e.sourcePartyId = "Select who paid";
    if (needsTreasury && !treasuryAccountId) e.treasuryAccountId = "Select the cash/bank account";
    return e;
  }

  function handleSubmit(ev: React.FormEvent) {
    ev.preventDefault();
    const validation = validate();
    setErrors(validation);
    setSubmitError("");
    if (Object.keys(validation).length > 0) return;

    const input: NewSupplierPaymentInput = {
      date,
      supplierId,
      amount: Number(amount),
      sourceType,
      sourcePartyId: needsParty ? sourcePartyId : undefined,
      treasuryAccountId: needsTreasury ? treasuryAccountId : undefined,
      reference: reference.trim() || undefined,
    };
    try {
      addSupplierPayment(input);
      onDone();
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : "Could not record this payment.");
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <Field label="Date" required>
          <input type="date" value={date} onChange={(e) => setDate(e.target.value)} className={inputClassName} />
        </Field>
        <Field label="Amount (AED)" required error={errors.amount}>
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

      <Field label="Paid From" required>
        <select
          value={sourceType}
          onChange={(e) => {
            setSourceType(e.target.value as SupplierPaymentSourceType);
            setSourcePartyId("");
          }}
          className={inputClassName}
        >
          <option value="TREASURY">Cash / Bank (Treasury)</option>
          <option value="CUSTODIAN">Custodian</option>
          <option value="OWNER">Owner Current Account</option>
        </select>
      </Field>

      {needsTreasury && (
        <Field label="Cash / Bank Account" required error={errors.treasuryAccountId}>
          <select value={treasuryAccountId} onChange={(e) => setTreasuryAccountId(e.target.value)} className={inputClassName}>
            <option value="">Select…</option>
            {activeTreasuryAccounts.map((t) => (
              <option key={t.id} value={t.id}>
                {t.name}
              </option>
            ))}
          </select>
        </Field>
      )}

      {needsParty && (
        <Field label={sourceType === "CUSTODIAN" ? "Custodian" : "Owner"} required error={errors.sourcePartyId}>
          <select value={sourcePartyId} onChange={(e) => setSourcePartyId(e.target.value)} className={inputClassName}>
            <option value="">Select…</option>
            {partyOptions.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </select>
        </Field>
      )}

      <Field label="Reference (optional)">
        <input value={reference} onChange={(e) => setReference(e.target.value)} className={inputClassName} />
      </Field>

      {submitError && <p className="text-xs text-rose-500">{submitError}</p>}

      <div className="flex justify-end gap-2 pt-2">
        <button
          type="button"
          onClick={onDone}
          className="rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50"
        >
          Cancel
        </button>
        <button
          type="submit"
          className="rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800"
        >
          Save Payment
        </button>
      </div>
    </form>
  );
}
