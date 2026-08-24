import { useMemo, useState } from "react";
import { useAppData, type NewSubcontractorPaymentInput } from "../state/AppDataContext";
import { Field, inputClassName } from "./ui/Field";
import { formatAED, subtractMoney } from "../domain/money";
import { certificatePaidAmount } from "../accounting/ledger";
import type { SubcontractorCertificate, SubcontractorPaymentSourceType } from "../domain/types";

const today = () => new Date().toISOString().slice(0, 10);

export function SubcontractorPaymentForm({
  certificate,
  onDone,
}: {
  certificate: SubcontractorCertificate;
  onDone: () => void;
}) {
  const { parties, subcontractorPayments, addSubcontractorPayment } = useAppData();
  const owners = useMemo(() => parties.filter((p) => p.type === "OWNER"), [parties]);
  const custodians = useMemo(() => parties.filter((p) => p.type === "CUSTODIAN"), [parties]);

  const alreadyPaid = useMemo(
    () => certificatePaidAmount(subcontractorPayments, certificate.id),
    [subcontractorPayments, certificate.id],
  );
  const outstanding = subtractMoney(certificate.netPayable, alreadyPaid);

  const [date, setDate] = useState(today());
  const [amount, setAmount] = useState(outstanding.toFixed(2));
  const [sourceType, setSourceType] = useState<SubcontractorPaymentSourceType>("BANK");
  const [sourcePartyId, setSourcePartyId] = useState("");
  const [reference, setReference] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitError, setSubmitError] = useState("");

  const needsParty = sourceType === "OWNER" || sourceType === "CUSTODIAN";
  const partyOptions = sourceType === "OWNER" ? owners : custodians;

  function validate(): Record<string, string> {
    const e: Record<string, string> = {};
    const n = Number(amount);
    if (!Number.isFinite(n) || n <= 0) e.amount = "Enter an amount greater than zero";
    else if (n > outstanding + 0.01) e.amount = `Cannot exceed the outstanding balance (${formatAED(outstanding)})`;
    if (needsParty && !sourcePartyId) e.sourcePartyId = "Select who paid";
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
      reference: reference.trim() || undefined,
    };
    try {
      addSubcontractorPayment(input);
      onDone();
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : "Could not record this payment.");
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="rounded-lg bg-slate-50 px-3 py-2 text-xs text-slate-500">
        Net payable {formatAED(certificate.netPayable)} — already paid {formatAED(alreadyPaid)} — outstanding{" "}
        <span className="font-semibold text-slate-700">{formatAED(outstanding)}</span>
      </div>

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
          />
        </Field>
      </div>

      <Field label="Paid From" required>
        <select
          value={sourceType}
          onChange={(e) => {
            setSourceType(e.target.value as SubcontractorPaymentSourceType);
            setSourcePartyId("");
          }}
          className={inputClassName}
        >
          <option value="BANK">Company Bank</option>
          <option value="CASH">Company Cash</option>
          <option value="OWNER">Owner Directly</option>
          <option value="CUSTODIAN">Custodian</option>
        </select>
      </Field>

      {needsParty && (
        <Field label={sourceType === "OWNER" ? "Owner" : "Custodian"} required error={errors.sourcePartyId}>
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
