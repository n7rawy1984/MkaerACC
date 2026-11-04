import { useLayoutEffect, useRef, useState, type FormEvent } from "react";
import { Field, inputClassName } from "../components/ui/Field";
import { useI18n, useT } from "../i18n/I18nContext";
import { normalizeSupplierParty, type SupplierPartyInput } from "./supplierPartyMutations";
import type { ProductionParty } from "./masterTypes";

export function SupplierPartyForm({ supplier, disabled, onSave, onCancel, title, existingParties = [] }: {
  title?: string;
  existingParties?: readonly ProductionParty[];
  supplier: ProductionParty | null;
  disabled: boolean;
  onSave: (input: SupplierPartyInput) => Promise<void>;
  onCancel: () => void;
}) {
  const t = useT(), ar = useI18n().locale === "ar";
  const [duplicateReviewed, setDuplicateReviewed] = useState(false);
  const [input, setInput] = useState<SupplierPartyInput>({
    name: supplier?.name ?? "", code: supplier?.code ?? null, trn: supplier?.taxRegistrationNumber ?? null,
    contact_person: supplier?.contactPerson ?? null, phone: supplier?.phone ?? null,
    email: supplier?.email ?? null, address: supplier?.address ?? null, notes: supplier?.notes ?? null,
  });
  const key = (v: string | null) => v?.trim().replace(/\s+/g, " ").toLowerCase() || null;
  const possibleDuplicate = existingParties.some(p => p.id !== supplier?.id && ["SUPPLIER", "SUBCONTRACTOR"].includes(p.type) && (key(p.name) === key(input.name) || !!key(input.trn) && key(p.taxRegistrationNumber) === key(input.trn)));
  const change = (field: keyof SupplierPartyInput, value: string) => { setInput(v => ({...v, [field]: value})); setDuplicateReviewed(false); };
  const form = useRef<HTMLFormElement>(null);
  useLayoutEffect(() => {
    form.current?.querySelector<HTMLInputElement>('input[name="name"]')?.focus({ preventScroll: true });
    form.current?.scrollIntoView({ block: "start" });
  }, []);
  const [invalid, setInvalid] = useState(false);
  const submit = (event: FormEvent) => {
    event.preventDefault();
    if (disabled || possibleDuplicate && !duplicateReviewed) return;
    const normalized = normalizeSupplierParty(input);
    setInvalid(!normalized);
    if (normalized) void onSave(normalized);
  };
  return <form ref={form} onSubmit={submit} className="mt-4 space-y-3 rounded-lg border border-slate-200 p-4" aria-label={title ?? t(supplier ? "supplierMutation.edit" : "supplierMutation.create")}>
    <h3 className="font-semibold">{title ?? t(supplier ? "supplierMutation.edit" : "supplierMutation.create")}</h3>
    {!supplier && <p className="text-sm text-slate-500">{t("supplierMutation.activeOnCreate")}</p>}
    <fieldset disabled={disabled} className="space-y-3">
      {(["name", "code", "trn", "contact_person", "phone", "email", "address", "notes"] as const).map((field) => <Field key={field} label={t(`supplierMutation.${field}`)} required={field === "name"}>
        {field === "address" || field === "notes"
          ? <textarea name={field} className={inputClassName} value={input[field] ?? ""} onChange={(e) => change(field, e.target.value)} />
          : <input dir={field === "email" || field === "phone" || field === "trn" || field === "code" ? "ltr" : undefined} name={field} type="text" className={inputClassName} value={input[field] ?? ""} required={field === "name"} onChange={(e) => change(field, e.target.value)} />}
      </Field>)}
      {possibleDuplicate && <label className="flex items-start gap-2 text-sm"><input type="checkbox" checked={duplicateReviewed} onChange={e => setDuplicateReviewed(e.target.checked)}/>{ar ? "يوجد طرف ظاهر باسم أو رقم تسجيل ضريبي مشابه. راجعت التشابه وأؤكد إنشاء هوية مستقلة دون دمج السجلات." : "A visible party has a matching name or TRN. I reviewed the match and confirm a separate identity without merging records."}</label>}
      {invalid && <p role="alert" className="text-sm text-red-700">{t("supplierMutation.invalid")}</p>}
      <button type="submit" disabled={possibleDuplicate && !duplicateReviewed} className="rounded-lg bg-[var(--tenant-primary)] px-4 py-2 text-sm text-white disabled:opacity-50">{t("supplierMutation.save")}</button>
    </fieldset>
    <button type="button" onClick={onCancel} className="text-sm underline">{t("supplierMutation.close")}</button>
  </form>;
}
