import { useMemo, useState } from "react";
import { useAppData, type NewTreasuryAccountInput } from "../state/AppDataContext";
import { Field, inputClassName } from "./ui/Field";
import { useT } from "../i18n/I18nContext";
import type { TranslationKey } from "../i18n/en";
import type { TreasuryAccount, TreasuryAccountStatus, TreasuryAccountType } from "../domain/types";

const TYPE_KEY: Record<TreasuryAccountType, TranslationKey> = {
  CASH: "treasuryType.CASH",
  PETTY_CASH: "treasuryType.PETTY_CASH",
  BANK: "treasuryType.BANK",
  PROJECT_CASH_BOX: "treasuryType.PROJECT_CASH_BOX",
  PROJECT_BANK: "treasuryType.PROJECT_BANK",
};

export function TreasuryAccountForm({ account, onDone }: { account?: TreasuryAccount; onDone: () => void }) {
  const t = useT();
  const { companies, projects, accounts, addTreasuryAccount, updateTreasuryAccount } = useAppData();
  const activeCompanies = useMemo(() => companies.filter((c) => c.status === "ACTIVE"), [companies]);
  const isEdit = Boolean(account);
  const glAccount = account ? accounts.find((a) => a.id === account.glAccountId) : undefined;

  const [companyId, setCompanyId] = useState(account?.companyId ?? activeCompanies[0]?.id ?? "");
  const [projectId, setProjectId] = useState(account?.projectId ?? "");
  const [code, setCode] = useState(account?.code ?? "");
  const [name, setName] = useState(account?.name ?? "");
  const [type, setType] = useState<TreasuryAccountType>(account?.type ?? "CASH");
  const [status, setStatus] = useState<TreasuryAccountStatus>(account?.status ?? "ACTIVE");
  const [bankName, setBankName] = useState(account?.bankName ?? "");
  const [accountReference, setAccountReference] = useState(account?.accountReference ?? "");
  const [notes, setNotes] = useState(account?.notes ?? "");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitError, setSubmitError] = useState("");

  const companyProjects = useMemo(() => projects.filter((p) => p.companyId === companyId), [projects, companyId]);
  const isBankType = type === "BANK" || type === "PROJECT_BANK";

  function validate(): Record<string, string> {
    const e: Record<string, string> = {};
    if (!code.trim()) e.code = t("common.required");
    if (!name.trim()) e.name = t("common.required");
    if (!companyId) e.companyId = t("treasury.form.selectCompany");
    return e;
  }

  function handleSubmit(ev: React.FormEvent) {
    ev.preventDefault();
    const validation = validate();
    setErrors(validation);
    setSubmitError("");
    if (Object.keys(validation).length > 0) return;

    const input: NewTreasuryAccountInput = {
      companyId,
      projectId: projectId || undefined,
      code: code.trim(),
      name: name.trim(),
      type,
      bankName: isBankType ? bankName.trim() || undefined : undefined,
      accountReference: isBankType ? accountReference.trim() || undefined : undefined,
      notes: notes.trim() || undefined,
    };

    try {
      if (isEdit && account) updateTreasuryAccount(account.id, { ...input, status });
      else addTreasuryAccount(input);
      onDone();
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : t("treasury.form.saveError"));
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <Field label={t("treasury.form.company")} required error={errors.companyId}>
          <select
            value={companyId}
            onChange={(e) => {
              setCompanyId(e.target.value);
              setProjectId("");
            }}
            className={inputClassName}
          >
            {activeCompanies.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </Field>
        <Field label={t("treasury.form.project")}>
          <select value={projectId} onChange={(e) => setProjectId(e.target.value)} className={inputClassName}>
            <option value="">{t("treasury.form.companyWide")}</option>
            {companyProjects.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </select>
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field label={t("treasury.form.code")} required error={errors.code}>
          <input
            value={code}
            onChange={(e) => setCode(e.target.value)}
            className={inputClassName}
            placeholder={t("treasury.form.codePlaceholder")}
          />
        </Field>
        <Field label={t("treasury.form.name")} required error={errors.name}>
          <input
            value={name}
            onChange={(e) => setName(e.target.value)}
            className={inputClassName}
            placeholder={t("treasury.form.namePlaceholder")}
          />
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field label={t("treasury.form.type")} required>
          <select value={type} onChange={(e) => setType(e.target.value as TreasuryAccountType)} className={inputClassName}>
            {(Object.keys(TYPE_KEY) as TreasuryAccountType[]).map((option) => (
              <option key={option} value={option}>
                {t(TYPE_KEY[option])}
              </option>
            ))}
          </select>
        </Field>
        {isEdit && (
          <Field label={t("common.status")}>
            <select value={status} onChange={(e) => setStatus(e.target.value as TreasuryAccountStatus)} className={inputClassName}>
              <option value="ACTIVE">{t("common.active")}</option>
              <option value="INACTIVE">{t("common.inactive")}</option>
            </select>
          </Field>
        )}
      </div>

      <div className="rounded-lg bg-slate-50 px-3 py-2 text-xs text-slate-500">
        {isEdit && glAccount
          ? t("treasury.form.dedicatedGlHint", { code: glAccount.code, name: glAccount.name })
          : t("treasury.form.newGlHint", {
              rootAccount:
                type === "BANK" || type === "PROJECT_BANK" ? "1100 Bank Account" : "1000 Cash on Hand",
            })}
      </div>

      {isBankType && (
        <div className="grid grid-cols-2 gap-4">
          <Field label={t("treasury.form.bankName")}>
            <input value={bankName} onChange={(e) => setBankName(e.target.value)} className={inputClassName} />
          </Field>
          <Field label={t("treasury.form.accountReference")}>
            <input value={accountReference} onChange={(e) => setAccountReference(e.target.value)} className={inputClassName} />
          </Field>
        </div>
      )}

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
          {isEdit ? t("common.saveChanges") : t("treasury.form.createButton")}
        </button>
      </div>
    </form>
  );
}
