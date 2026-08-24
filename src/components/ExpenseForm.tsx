import { useEffect, useMemo, useState } from "react";
import { useAppData, type NewExpenseInput } from "../state/AppDataContext";
import { Field, inputClassName } from "./ui/Field";
import { calcVat, formatAED } from "../domain/money";
import { formatDate } from "../domain/utils";
import type { PaidFromType, PaymentMethod, VatMode } from "../domain/types";

const today = () => new Date().toISOString().slice(0, 10);

export function ExpenseForm({ onDone }: { onDone: () => void }) {
  const { projects, parties, categories, advances, addExpense } = useAppData();
  const owners = useMemo(() => parties.filter((p) => p.type === "OWNER"), [parties]);
  const custodians = useMemo(() => parties.filter((p) => p.type === "CUSTODIAN"), [parties]);
  const suppliers = useMemo(() => parties.filter((p) => p.type === "SUPPLIER"), [parties]);

  const [date, setDate] = useState(today());
  const [projectId, setProjectId] = useState("");
  const [supplierId, setSupplierId] = useState("");
  const [categoryId, setCategoryId] = useState(categories[0]?.id ?? "");
  const [description, setDescription] = useState("");
  const [invoiceNumber, setInvoiceNumber] = useState("");
  const [netAmount, setNetAmount] = useState("");
  const [vatMode, setVatMode] = useState<VatMode>("ZERO");
  const [manualVatAmount, setManualVatAmount] = useState("");
  const [paidFromType, setPaidFromType] = useState<PaidFromType>("CUSTODIAN");
  const [paidFromPartyId, setPaidFromPartyId] = useState("");
  const [advanceId, setAdvanceId] = useState("");
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>("CASH");
  const [hasInvoice, setHasInvoice] = useState(false);
  const [notes, setNotes] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});

  const custodianAdvances = useMemo(
    () =>
      paidFromType === "CUSTODIAN" && paidFromPartyId
        ? advances
            .filter((a) => a.custodianId === paidFromPartyId)
            .sort((a, b) => (a.date < b.date ? 1 : -1))
        : [],
    [advances, paidFromType, paidFromPartyId],
  );

  // Default to the most recent advance whenever the custodian changes — the
  // link is purely informational (the custodian's balance stays pooled), so
  // it's never required and can be cleared.
  useEffect(() => {
    setAdvanceId(custodianAdvances[0]?.id ?? "");
    // Intentionally reacts only to the custodian changing, not to every
    // advances-list update, so it doesn't clobber a manual override.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [paidFromPartyId]);

  const net = Number(netAmount);
  const vatPreview = calcVat({
    netAmount: Number.isFinite(net) ? net : 0,
    vatMode,
    manualVatAmount: Number(manualVatAmount) || 0,
  });

  const partyOptions = paidFromType === "CUSTODIAN" ? custodians : paidFromType === "OWNER" ? owners : [];
  const needsParty = paidFromType === "CUSTODIAN" || paidFromType === "OWNER";
  const needsSupplier = paidFromType === "SUPPLIER_CREDIT";

  function validate(): Record<string, string> {
    const e: Record<string, string> = {};
    if (!date) e.date = "Required";
    if (!categoryId) e.categoryId = "Required";
    if (!description.trim()) e.description = "Required";
    if (!Number.isFinite(net) || net <= 0) e.netAmount = "Enter an amount greater than zero";
    if (vatMode === "MANUAL" && (!manualVatAmount || Number(manualVatAmount) < 0)) {
      e.manualVatAmount = "Enter a VAT amount";
    }
    if (needsParty && !paidFromPartyId) e.paidFromPartyId = "Select who paid";
    if (needsSupplier && !supplierId) e.supplierId = "Select the supplier";
    if (hasInvoice && !invoiceNumber.trim()) e.invoiceNumber = "Enter the invoice number";
    return e;
  }

  function handleSubmit(ev: React.FormEvent) {
    ev.preventDefault();
    const validation = validate();
    setErrors(validation);
    if (Object.keys(validation).length > 0) return;

    const input: NewExpenseInput = {
      date,
      projectId: projectId || undefined,
      supplierId: needsSupplier ? supplierId : supplierId || undefined,
      categoryId,
      description: description.trim(),
      invoiceNumber: invoiceNumber.trim() || undefined,
      netAmount: net,
      vatMode,
      manualVatAmount: vatMode === "MANUAL" ? Number(manualVatAmount) : undefined,
      paidFromType,
      paidFromPartyId: needsParty ? paidFromPartyId : undefined,
      advanceId: paidFromType === "CUSTODIAN" && advanceId ? advanceId : undefined,
      paymentMethod,
      hasInvoice,
      notes: notes.trim() || undefined,
    };
    addExpense(input);
    onDone();
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <Field label="Date" required error={errors.date}>
          <input type="date" value={date} onChange={(e) => setDate(e.target.value)} className={inputClassName} />
        </Field>
        <Field label="Category" required error={errors.categoryId}>
          <select value={categoryId} onChange={(e) => setCategoryId(e.target.value)} className={inputClassName}>
            {categories.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </Field>
      </div>

      <Field label="Description" required error={errors.description}>
        <input
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          className={inputClassName}
          placeholder="e.g. Cement & blocks purchase"
        />
      </Field>

      <div className="grid grid-cols-2 gap-4">
        <Field label="Project (optional)">
          <select value={projectId} onChange={(e) => setProjectId(e.target.value)} className={inputClassName}>
            <option value="">— Company expense —</option>
            {projects.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </select>
        </Field>
        <Field label={needsSupplier ? "Supplier" : "Supplier (optional)"} required={needsSupplier} error={errors.supplierId}>
          <select value={supplierId} onChange={(e) => setSupplierId(e.target.value)} className={inputClassName}>
            <option value="">—</option>
            {suppliers.map((s) => (
              <option key={s.id} value={s.id}>
                {s.name}
              </option>
            ))}
          </select>
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field label="Net Amount (AED)" required error={errors.netAmount}>
          <input
            type="number"
            min="0"
            step="0.01"
            value={netAmount}
            onChange={(e) => setNetAmount(e.target.value)}
            className={inputClassName}
            placeholder="0.00"
          />
        </Field>
        <Field label="VAT">
          <select value={vatMode} onChange={(e) => setVatMode(e.target.value as VatMode)} className={inputClassName}>
            <option value="ZERO">No VAT</option>
            <option value="AUTO_5">Auto 5%</option>
            <option value="MANUAL">Manual amount</option>
          </select>
        </Field>
      </div>

      {vatMode === "MANUAL" && (
        <Field label="VAT Amount (AED)" required error={errors.manualVatAmount}>
          <input
            type="number"
            min="0"
            step="0.01"
            value={manualVatAmount}
            onChange={(e) => setManualVatAmount(e.target.value)}
            className={inputClassName}
            placeholder="0.00"
          />
        </Field>
      )}

      <div className="rounded-lg bg-slate-50 px-3 py-2 text-xs text-slate-500">
        Net {vatPreview.netAmount.toFixed(2)} + VAT {vatPreview.vatAmount.toFixed(2)} = Total{" "}
        <span className="font-semibold text-slate-700">{vatPreview.totalAmount.toFixed(2)} AED</span>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field label="Paid From" required>
          <select
            value={paidFromType}
            onChange={(e) => {
              const next = e.target.value as PaidFromType;
              setPaidFromType(next);
              setPaidFromPartyId("");
              if (next === "CASH") setPaymentMethod("CASH");
              if (next === "BANK") setPaymentMethod("BANK");
            }}
            className={inputClassName}
          >
            <option value="CUSTODIAN">Custodian Advance</option>
            <option value="OWNER">Owner (paid directly)</option>
            <option value="SUPPLIER_CREDIT">Supplier Credit (pay later)</option>
            <option value="CASH">Company Cash</option>
            <option value="BANK">Company Bank</option>
          </select>
        </Field>
        {needsParty ? (
          <Field
            label={paidFromType === "CUSTODIAN" ? "Custodian" : "Owner"}
            required
            error={errors.paidFromPartyId}
          >
            <select
              value={paidFromPartyId}
              onChange={(e) => setPaidFromPartyId(e.target.value)}
              className={inputClassName}
            >
              <option value="">Select…</option>
              {partyOptions.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
          </Field>
        ) : paidFromType === "SUPPLIER_CREDIT" ? (
          <div className="flex items-end">
            <p className="rounded-lg bg-slate-50 px-3 py-2 text-xs text-slate-500">
              No payment now — added to the supplier&rsquo;s outstanding balance. Settle it later from the
              Suppliers page.
            </p>
          </div>
        ) : (
          <Field label="Payment Method">
            <select
              value={paymentMethod}
              onChange={(e) => setPaymentMethod(e.target.value as PaymentMethod)}
              className={inputClassName}
            >
              <option value="CASH">Cash</option>
              <option value="BANK">Bank</option>
              <option value="TRANSFER">Transfer</option>
              <option value="CHEQUE">Cheque</option>
              <option value="OTHER">Other</option>
            </select>
          </Field>
        )}
      </div>

      {paidFromType === "CUSTODIAN" && paidFromPartyId && custodianAdvances.length > 0 && (
        <Field label="Advance (optional)">
          <select value={advanceId} onChange={(e) => setAdvanceId(e.target.value)} className={inputClassName}>
            <option value="">— Pooled custody balance —</option>
            {custodianAdvances.map((a) => (
              <option key={a.id} value={a.id}>
                {formatDate(a.date)} · {formatAED(a.amount)}
                {a.reference ? ` · ${a.reference}` : ""}
              </option>
            ))}
          </select>
        </Field>
      )}

      <div className="flex items-center justify-between gap-4">
        <label className="flex items-center gap-2 text-sm text-slate-700">
          <input
            type="checkbox"
            checked={hasInvoice}
            onChange={(e) => setHasInvoice(e.target.checked)}
            className="h-4 w-4 rounded border-slate-300"
          />
          Has invoice
        </label>
        {hasInvoice && (
          <div className="flex-1">
            <input
              value={invoiceNumber}
              onChange={(e) => setInvoiceNumber(e.target.value)}
              className={inputClassName}
              placeholder="Invoice number"
            />
            {errors.invoiceNumber && (
              <span className="mt-1 block text-xs text-rose-500">{errors.invoiceNumber}</span>
            )}
          </div>
        )}
      </div>

      <Field label="Notes (optional)">
        <textarea
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          className={inputClassName}
          rows={2}
        />
      </Field>

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
          Save Expense
        </button>
      </div>
    </form>
  );
}
