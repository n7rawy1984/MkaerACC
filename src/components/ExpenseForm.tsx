import { useEffect, useMemo, useState } from "react";
import { useAppData, type NewExpenseInput } from "../state/AppDataContext";
import { Field, inputClassName } from "./ui/Field";
import { calcVat, formatAED } from "../domain/money";
import { formatDate } from "../domain/utils";
import { useT } from "../i18n/I18nContext";
import type { PaidFromType, PaymentMethod, VatMode } from "../domain/types";

const today = () => new Date().toISOString().slice(0, 10);

export function ExpenseForm({ onDone }: { onDone: () => void }) {
  const t = useT();
  const { projects, parties, categories, advances, treasuryAccounts, addExpense } = useAppData();
  const owners = useMemo(() => parties.filter((p) => p.type === "OWNER"), [parties]);
  const custodians = useMemo(() => parties.filter((p) => p.type === "CUSTODIAN"), [parties]);
  const suppliers = useMemo(() => parties.filter((p) => p.type === "SUPPLIER"), [parties]);
  const openProjects = useMemo(() => projects.filter((p) => p.status !== "CLOSED"), [projects]);

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
  const [treasuryAccountId, setTreasuryAccountId] = useState("");
  const [advanceId, setAdvanceId] = useState("");
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>("CASH");
  const [hasInvoice, setHasInvoice] = useState(false);
  const [notes, setNotes] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitError, setSubmitError] = useState("");

  const selectedProject = projects.find((p) => p.id === projectId);

  // Company-wide treasury accounts are always eligible; project-specific ones only
  // for their own project — never another project's dedicated cash box (Phase 2B.1A).
  const eligibleTreasuryAccounts = useMemo(
    () =>
      treasuryAccounts.filter((t) => {
        if (t.status !== "ACTIVE") return false;
        if (selectedProject && t.companyId !== selectedProject.companyId) return false;
        if (t.projectId && t.projectId !== projectId) return false;
        return true;
      }),
    [treasuryAccounts, selectedProject, projectId],
  );

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

  useEffect(() => {
    setTreasuryAccountId(eligibleTreasuryAccounts[0]?.id ?? "");
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [paidFromType, projectId]);

  const net = Number(netAmount);
  const vatPreview = calcVat({
    netAmount: Number.isFinite(net) ? net : 0,
    vatMode,
    manualVatAmount: Number(manualVatAmount) || 0,
  });

  const partyOptions = paidFromType === "CUSTODIAN" ? custodians : paidFromType === "OWNER" ? owners : [];
  const needsParty = paidFromType === "CUSTODIAN" || paidFromType === "OWNER";
  const needsSupplier = paidFromType === "SUPPLIER_CREDIT";
  const needsTreasury = paidFromType === "TREASURY";

  function validate(): Record<string, string> {
    const e: Record<string, string> = {};
    if (!date) e.date = t("common.required");
    if (!categoryId) e.categoryId = t("common.required");
    if (!description.trim()) e.description = t("common.required");
    if (!Number.isFinite(net) || net <= 0) e.netAmount = t("common.enterAmountGreaterThanZero");
    if (vatMode === "MANUAL" && (!manualVatAmount || Number(manualVatAmount) < 0)) {
      e.manualVatAmount = t("expenseForm.enterVatAmount");
    }
    if (needsParty && !paidFromPartyId) e.paidFromPartyId = t("common.selectWhoPaid");
    if (needsSupplier && !supplierId) e.supplierId = t("expenseForm.selectSupplier");
    if (needsTreasury && !treasuryAccountId) e.treasuryAccountId = t("common.selectCashBankAccount");
    if (hasInvoice && !invoiceNumber.trim()) e.invoiceNumber = t("expenseForm.enterInvoiceNumber");
    return e;
  }

  function handleSubmit(ev: React.FormEvent) {
    ev.preventDefault();
    const validation = validate();
    setErrors(validation);
    setSubmitError("");
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
      treasuryAccountId: needsTreasury ? treasuryAccountId : undefined,
      advanceId: paidFromType === "CUSTODIAN" && advanceId ? advanceId : undefined,
      paymentMethod,
      hasInvoice,
      notes: notes.trim() || undefined,
    };
    try {
      addExpense(input);
      onDone();
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : t("expenseForm.saveError"));
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <Field label={t("common.date")} required error={errors.date}>
          <input type="date" value={date} onChange={(e) => setDate(e.target.value)} className={inputClassName} />
        </Field>
        <Field label={t("expenseForm.category")} required error={errors.categoryId}>
          <select value={categoryId} onChange={(e) => setCategoryId(e.target.value)} className={inputClassName}>
            {categories.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </Field>
      </div>

      <Field label={t("expenseForm.description")} required error={errors.description}>
        <input
          value={description}
          onChange={(e) => setDescription(e.target.value)}
          className={inputClassName}
          placeholder={t("expenseForm.descriptionPlaceholder")}
        />
      </Field>

      <div className="grid grid-cols-2 gap-4">
        <Field label={t("expenseForm.projectOptional")}>
          <select value={projectId} onChange={(e) => setProjectId(e.target.value)} className={inputClassName}>
            <option value="">{t("expenseForm.companyExpense")}</option>
            {openProjects.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </select>
        </Field>
        <Field
          label={needsSupplier ? t("expenseForm.supplier") : t("expenseForm.supplierOptional")}
          required={needsSupplier}
          error={errors.supplierId}
        >
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
        <Field label={t("expenseForm.netAmountAed")} required error={errors.netAmount}>
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
        <Field label={t("field.vat")}>
          <select value={vatMode} onChange={(e) => setVatMode(e.target.value as VatMode)} className={inputClassName}>
            <option value="ZERO">{t("vatMode.ZERO")}</option>
            <option value="AUTO_5">{t("vatMode.AUTO_5")}</option>
            <option value="MANUAL">{t("vatMode.MANUAL")}</option>
          </select>
        </Field>
      </div>

      {vatMode === "MANUAL" && (
        <Field label={t("field.vatAmountAed")} required error={errors.manualVatAmount}>
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
        {t("expenseForm.vatPreview", {
          net: vatPreview.netAmount.toFixed(2),
          vat: vatPreview.vatAmount.toFixed(2),
          total: vatPreview.totalAmount.toFixed(2),
        })}
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field label={t("common.paidFrom")} required>
          <select
            value={paidFromType}
            onChange={(e) => {
              const next = e.target.value as PaidFromType;
              setPaidFromType(next);
              setPaidFromPartyId("");
            }}
            className={inputClassName}
          >
            <option value="CUSTODIAN">{t("expenseForm.paidFromCustodian")}</option>
            <option value="OWNER">{t("expenseForm.paidFromOwner")}</option>
            <option value="SUPPLIER_CREDIT">{t("expenseForm.paidFromSupplierCredit")}</option>
            <option value="TREASURY">{t("expenseForm.paidFromTreasury")}</option>
          </select>
        </Field>
        {needsParty ? (
          <Field
            label={paidFromType === "CUSTODIAN" ? t("expenseForm.custodian") : t("common.owner")}
            required
            error={errors.paidFromPartyId}
          >
            <select
              value={paidFromPartyId}
              onChange={(e) => setPaidFromPartyId(e.target.value)}
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
        ) : needsTreasury ? (
          <Field label={t("common.cashBankAccount")} required error={errors.treasuryAccountId}>
            <select
              value={treasuryAccountId}
              onChange={(e) => setTreasuryAccountId(e.target.value)}
              className={inputClassName}
            >
              <option value="">{t("common.selectEllipsis")}</option>
              {eligibleTreasuryAccounts.map((account) => (
                <option key={account.id} value={account.id}>
                  {account.name}
                </option>
              ))}
            </select>
          </Field>
        ) : paidFromType === "SUPPLIER_CREDIT" ? (
          <div className="flex items-end">
            <p className="rounded-lg bg-slate-50 px-3 py-2 text-xs text-slate-500">
              {t("expenseForm.supplierCreditHint")}
            </p>
          </div>
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

      {paidFromType === "CUSTODIAN" && paidFromPartyId && custodianAdvances.length > 0 && (
        <Field label={t("expenseForm.advanceOptional")}>
          <select value={advanceId} onChange={(e) => setAdvanceId(e.target.value)} className={inputClassName}>
            <option value="">{t("expenseForm.pooledCustodyBalance")}</option>
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
          {t("expenseForm.hasInvoice")}
        </label>
        {hasInvoice && (
          <div className="flex-1">
            <input
              value={invoiceNumber}
              onChange={(e) => setInvoiceNumber(e.target.value)}
              className={inputClassName}
              placeholder={t("expenseForm.invoiceNumberPlaceholder")}
            />
            {errors.invoiceNumber && (
              <span className="mt-1 block text-xs text-rose-500">{errors.invoiceNumber}</span>
            )}
          </div>
        )}
      </div>

      <Field label={t("common.notesOptional")}>
        <textarea
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          className={inputClassName}
          rows={2}
        />
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
          {t("expenseForm.saveButton")}
        </button>
      </div>
    </form>
  );
}
