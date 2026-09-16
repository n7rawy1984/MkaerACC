import { useLayoutEffect, useRef, useState, type FormEvent } from "react";
import { Field, inputClassName } from "../components/ui/Field";
import { useT } from "../i18n/I18nContext";
import { normalizeCompanyProfile, type CompanyProfileInput } from "./companyProfileMutations";
import type { ProductionCompanyProfile } from "./masterTypes";

export function CompanyProfileForm({ company, disabled, onSave, onCancel }: {
  company: ProductionCompanyProfile;
  disabled: boolean;
  onSave: (input: CompanyProfileInput) => Promise<void>;
  onCancel: () => void;
}) {
  const t = useT();
  const [input, setInput] = useState<CompanyProfileInput>({ legal_name: company.legalName, trn: company.trn, address: company.address, notes: company.notes });
  const form = useRef<HTMLFormElement>(null);
  useLayoutEffect(() => {
    form.current?.querySelector<HTMLInputElement>('input[name="legal_name"]')?.focus({ preventScroll: true });
    form.current?.scrollIntoView({ block: "start" });
  }, []);
  const submit = (event: FormEvent) => {
    event.preventDefault();
    if (disabled) return;
    const normalized = normalizeCompanyProfile(input);
    if (normalized) void onSave(normalized);
  };
  return <form ref={form} onSubmit={submit} className="mt-4 space-y-3 rounded-lg border border-slate-200 p-4" aria-label={t("companyProfile.edit")}>
    <p className="text-sm text-slate-500">{t("companyProfile.optional")}</p>
    <fieldset disabled={disabled} className="space-y-3">
      {(["legal_name", "trn", "address", "notes"] as const).map((field) => <Field key={field} label={t(`companyProfile.${field}`)}>
        {field === "address" || field === "notes"
          ? <textarea name={field} className={inputClassName} value={input[field] ?? ""} onChange={(e) => setInput({ ...input, [field]: e.target.value })} />
          : <input name={field} type="text" className={inputClassName} value={input[field] ?? ""} onChange={(e) => setInput({ ...input, [field]: e.target.value })} />}
      </Field>)}
      <button type="submit" className="rounded-lg bg-[var(--tenant-primary)] px-4 py-2 text-sm text-white disabled:opacity-50">{t("companyProfile.save")}</button>
    </fieldset>
    <button type="button" onClick={onCancel} className="text-sm underline">{t("companyProfile.close")}</button>
  </form>;
}
