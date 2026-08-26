import { useState } from "react";
import { useAppData, type NewCompanyInput } from "../state/AppDataContext";
import { Field, inputClassName } from "./ui/Field";
import { useT } from "../i18n/I18nContext";
import type { Company, CompanyStatus } from "../domain/types";

export function CompanyForm({ company, onDone }: { company?: Company; onDone: () => void }) {
  const t = useT();
  const { addCompany, updateCompany } = useAppData();
  const isEdit = Boolean(company);

  const [code, setCode] = useState(company?.code ?? "");
  const [name, setName] = useState(company?.name ?? "");
  const [legalName, setLegalName] = useState(company?.legalName ?? "");
  const [trn, setTrn] = useState(company?.trn ?? "");
  const [address, setAddress] = useState(company?.address ?? "");
  const [status, setStatus] = useState<CompanyStatus>(company?.status ?? "ACTIVE");
  const [notes, setNotes] = useState(company?.notes ?? "");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitError, setSubmitError] = useState("");

  function validate(): Record<string, string> {
    const e: Record<string, string> = {};
    if (!code.trim()) e.code = t("common.required");
    if (!name.trim()) e.name = t("common.required");
    return e;
  }

  function handleSubmit(ev: React.FormEvent) {
    ev.preventDefault();
    const validation = validate();
    setErrors(validation);
    setSubmitError("");
    if (Object.keys(validation).length > 0) return;

    const input: NewCompanyInput = {
      code: code.trim(),
      name: name.trim(),
      legalName: legalName.trim() || undefined,
      trn: trn.trim() || undefined,
      address: address.trim() || undefined,
      notes: notes.trim() || undefined,
    };

    try {
      if (isEdit && company) updateCompany(company.id, { ...input, status });
      else addCompany(input);
      onDone();
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : t("company.form.saveError"));
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <Field label={t("company.form.code")} required error={errors.code}>
          <input
            value={code}
            onChange={(e) => setCode(e.target.value)}
            className={inputClassName}
            placeholder={t("company.form.codePlaceholder")}
          />
        </Field>
        <Field label={t("company.form.tradeName")} required error={errors.name}>
          <input value={name} onChange={(e) => setName(e.target.value)} className={inputClassName} />
        </Field>
      </div>

      <Field label={t("company.form.legalName")}>
        <input value={legalName} onChange={(e) => setLegalName(e.target.value)} className={inputClassName} />
      </Field>

      <div className="grid grid-cols-2 gap-4">
        <Field label={t("company.form.trn")}>
          <input value={trn} onChange={(e) => setTrn(e.target.value)} className={inputClassName} />
        </Field>
        {isEdit && (
          <Field label={t("common.status")}>
            <select value={status} onChange={(e) => setStatus(e.target.value as CompanyStatus)} className={inputClassName}>
              <option value="ACTIVE">{t("common.active")}</option>
              <option value="INACTIVE">{t("common.inactive")}</option>
            </select>
          </Field>
        )}
      </div>

      <Field label={t("company.form.address")}>
        <input value={address} onChange={(e) => setAddress(e.target.value)} className={inputClassName} />
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
          {isEdit ? t("common.saveChanges") : t("company.form.createButton")}
        </button>
      </div>
    </form>
  );
}
