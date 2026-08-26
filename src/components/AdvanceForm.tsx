import { useEffect, useMemo, useState } from "react";
import { useAppData, type NewAdvanceInput } from "../state/AppDataContext";
import { Field, inputClassName } from "./ui/Field";
import { useT } from "../i18n/I18nContext";
import type { AdvanceFundingSourceType, PaymentMethod } from "../domain/types";

const today = () => new Date().toISOString().slice(0, 10);

/** "treasury:<id>" or "owner:<id>" — a single select needs one flat value even
 * though it represents two different funding-source kinds under the hood. */
function encodeFundingSource(type: AdvanceFundingSourceType, id: string): string {
  return `${type === "TREASURY" ? "treasury" : "owner"}:${id}`;
}
function decodeFundingSource(value: string): { type: AdvanceFundingSourceType; id: string } | null {
  const [kind, id] = value.split(":");
  if (!kind || !id) return null;
  return { type: kind === "treasury" ? "TREASURY" : "OWNER_CURRENT", id };
}

export function AdvanceForm({ onDone }: { onDone: () => void }) {
  const t = useT();
  const { parties, projects, treasuryAccounts, addAdvance } = useAppData();
  const owners = useMemo(() => parties.filter((p) => p.type === "OWNER"), [parties]);
  const custodians = useMemo(() => parties.filter((p) => p.type === "CUSTODIAN"), [parties]);
  const openProjects = useMemo(() => projects.filter((p) => p.status !== "CLOSED"), [projects]);

  const [date, setDate] = useState(today());
  const [custodianId, setCustodianId] = useState(custodians[0]?.id ?? "");
  const [amount, setAmount] = useState("");
  const [projectId, setProjectId] = useState("");
  const [fundingSource, setFundingSource] = useState("");
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>("BANK");

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
  const [reference, setReference] = useState("");
  const [notes, setNotes] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitError, setSubmitError] = useState("");

  // Defaults (and re-defaults, if the current pick fell out of scope when the
  // project changed) to the first eligible treasury account.
  useEffect(() => {
    const stillEligible = eligibleTreasuryAccounts.some((t) => fundingSource === encodeFundingSource("TREASURY", t.id));
    if (!stillEligible) {
      setFundingSource(eligibleTreasuryAccounts[0] ? encodeFundingSource("TREASURY", eligibleTreasuryAccounts[0].id) : "");
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [eligibleTreasuryAccounts]);

  function validate(): Record<string, string> {
    const e: Record<string, string> = {};
    if (!date) e.date = t("common.required");
    if (!custodianId) e.custodianId = t("common.required");
    if (!fundingSource) e.fundingSource = t("advanceForm.fundingSourceHint");
    const n = Number(amount);
    if (!Number.isFinite(n) || n <= 0) e.amount = t("common.enterAmountGreaterThanZero");
    return e;
  }

  function handleSubmit(ev: React.FormEvent) {
    ev.preventDefault();
    const validation = validate();
    setErrors(validation);
    setSubmitError("");
    if (Object.keys(validation).length > 0) return;

    const decoded = decodeFundingSource(fundingSource);
    if (!decoded) {
      setErrors({ fundingSource: t("advanceForm.fundingSourceHint") });
      return;
    }

    const input: NewAdvanceInput = {
      date,
      custodianId,
      amount: Number(amount),
      projectId: projectId || undefined,
      fundingSourceType: decoded.type,
      fundingSourceId: decoded.id,
      paymentMethod,
      reference: reference.trim() || undefined,
      notes: notes.trim() || undefined,
    };
    try {
      addAdvance(input);
      onDone();
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : t("advanceForm.saveError"));
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <Field label={t("common.date")} required error={errors.date}>
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
        <Field label={t("advanceForm.toCustodian")} required error={errors.custodianId}>
          <select value={custodianId} onChange={(e) => setCustodianId(e.target.value)} className={inputClassName}>
            {custodians.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </Field>
        <Field label={t("advanceForm.projectPurposeOptional")}>
          <select value={projectId} onChange={(e) => setProjectId(e.target.value)} className={inputClassName}>
            <option value="">{t("advanceForm.generalPurpose")}</option>
            {openProjects.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </select>
        </Field>
      </div>

      <Field label={t("advanceForm.fundingSource")} required error={errors.fundingSource}>
        <select value={fundingSource} onChange={(e) => setFundingSource(e.target.value)} className={inputClassName}>
          <option value="">{t("common.selectEllipsis")}</option>
          {eligibleTreasuryAccounts.length > 0 && (
            <optgroup label={t("advanceForm.treasuryGroup")}>
              {eligibleTreasuryAccounts.map((account) => (
                <option key={account.id} value={encodeFundingSource("TREASURY", account.id)}>
                  {account.name}
                </option>
              ))}
            </optgroup>
          )}
          {owners.length > 0 && (
            <optgroup label={t("advanceForm.ownersGroup")}>
              {owners.map((o) => (
                <option key={o.id} value={encodeFundingSource("OWNER_CURRENT", o.id)}>
                  {t("advanceForm.ownerCurrentAccountSuffix", { name: o.name })}
                </option>
              ))}
            </optgroup>
          )}
        </select>
      </Field>

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

      <Field label={t("common.referenceOptional")}>
        <input value={reference} onChange={(e) => setReference(e.target.value)} className={inputClassName} />
      </Field>

      <Field label={t("common.notesOptional")}>
        <textarea value={notes} onChange={(e) => setNotes(e.target.value)} className={inputClassName} rows={2} />
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
          {t("advanceForm.saveButton")}
        </button>
      </div>
    </form>
  );
}
