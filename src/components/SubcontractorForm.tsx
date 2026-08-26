import { useState } from "react";
import { useAppData, type NewSubcontractorInput } from "../state/AppDataContext";
import { Field, inputClassName } from "./ui/Field";
import { useT } from "../i18n/I18nContext";
import type { Party, PartyStatus } from "../domain/types";

export function SubcontractorForm({ subcontractor, onDone }: { subcontractor?: Party; onDone: () => void }) {
  const t = useT();
  const { addSubcontractor, updateSubcontractor } = useAppData();
  const isEdit = Boolean(subcontractor);

  const [name, setName] = useState(subcontractor?.name ?? "");
  const [code, setCode] = useState(subcontractor?.code ?? "");
  const [taxRegistrationNumber, setTaxRegistrationNumber] = useState(subcontractor?.taxRegistrationNumber ?? "");
  const [contactPerson, setContactPerson] = useState(subcontractor?.contactPerson ?? "");
  const [phone, setPhone] = useState(subcontractor?.phone ?? "");
  const [email, setEmail] = useState(subcontractor?.email ?? "");
  const [address, setAddress] = useState(subcontractor?.address ?? "");
  const [notes, setNotes] = useState(subcontractor?.notes ?? "");
  const [status, setStatus] = useState<PartyStatus>(subcontractor?.status ?? "ACTIVE");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitError, setSubmitError] = useState("");

  function validate(): Record<string, string> {
    const e: Record<string, string> = {};
    if (!name.trim()) e.name = t("common.required");
    return e;
  }

  function handleSubmit(ev: React.FormEvent) {
    ev.preventDefault();
    const validation = validate();
    setErrors(validation);
    setSubmitError("");
    if (Object.keys(validation).length > 0) return;

    const input: NewSubcontractorInput = {
      name: name.trim(),
      code: code.trim() || undefined,
      taxRegistrationNumber: taxRegistrationNumber.trim() || undefined,
      contactPerson: contactPerson.trim() || undefined,
      phone: phone.trim() || undefined,
      email: email.trim() || undefined,
      address: address.trim() || undefined,
      notes: notes.trim() || undefined,
    };

    try {
      if (isEdit && subcontractor) updateSubcontractor(subcontractor.id, { ...input, status });
      else addSubcontractor(input);
      onDone();
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : t("subcontractorForm.saveError"));
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <Field label={t("subcontractorForm.name")} required error={errors.name}>
          <input value={name} onChange={(e) => setName(e.target.value)} className={inputClassName} />
        </Field>
        <Field label={t("subcontractorForm.code")}>
          <input
            value={code}
            onChange={(e) => setCode(e.target.value)}
            className={inputClassName}
            placeholder={t("subcontractorForm.codePlaceholder")}
          />
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field label={t("subcontractorForm.contactPerson")}>
          <input value={contactPerson} onChange={(e) => setContactPerson(e.target.value)} className={inputClassName} />
        </Field>
        <Field label={t("subcontractorForm.trn")}>
          <input
            value={taxRegistrationNumber}
            onChange={(e) => setTaxRegistrationNumber(e.target.value)}
            className={inputClassName}
          />
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field label={t("subcontractorForm.phone")}>
          <input value={phone} onChange={(e) => setPhone(e.target.value)} className={inputClassName} />
        </Field>
        <Field label={t("subcontractorForm.email")}>
          <input type="email" value={email} onChange={(e) => setEmail(e.target.value)} className={inputClassName} />
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field label={t("subcontractorForm.address")}>
          <input value={address} onChange={(e) => setAddress(e.target.value)} className={inputClassName} />
        </Field>
        {isEdit && (
          <Field label={t("common.status")}>
            <select value={status} onChange={(e) => setStatus(e.target.value as PartyStatus)} className={inputClassName}>
              <option value="ACTIVE">{t("common.active")}</option>
              <option value="INACTIVE">{t("common.inactive")}</option>
            </select>
          </Field>
        )}
      </div>

      {status === "INACTIVE" && (
        <div className="rounded-lg bg-slate-50 px-3 py-2 text-xs text-slate-500">
          {t("subcontractorForm.inactiveHint")}
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
          {isEdit ? t("common.saveChanges") : t("subcontractorForm.createButton")}
        </button>
      </div>
    </form>
  );
}
