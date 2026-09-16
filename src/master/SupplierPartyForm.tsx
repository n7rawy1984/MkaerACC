import { useLayoutEffect, useRef, useState, type FormEvent } from "react";
import { Field, inputClassName } from "../components/ui/Field";
import { useT } from "../i18n/I18nContext";
import { normalizeSupplierParty, type SupplierPartyInput } from "./supplierPartyMutations";
import type { ProductionParty } from "./masterTypes";

export function SupplierPartyForm({ supplier, disabled, onSave, onCancel }: {
  supplier: ProductionParty | null;
  disabled: boolean;
  onSave: (input: SupplierPartyInput) => Promise<void>;
  onCancel: () => void;
}) {
  const t = useT();
  const [input, setInput] = useState<SupplierPartyInput>({
    name: supplier?.name ?? "", code: supplier?.code ?? null, trn: supplier?.taxRegistrationNumber ?? null,
    contact_person: supplier?.contactPerson ?? null, phone: supplier?.phone ?? null,
    email: supplier?.email ?? null, address: supplier?.address ?? null, notes: supplier?.notes ?? null,
  });
  const form = useRef<HTMLFormElement>(null);
  useLayoutEffect(() => {
    form.current?.querySelector<HTMLInputElement>('input[name="name"]')?.focus({ preventScroll: true });
    form.current?.scrollIntoView({ block: "start" });
  }, []);
  const [invalid, setInvalid] = useState(false);
  const submit = (event: FormEvent) => {
    event.preventDefault();
    if (disabled) return;
    const normalized = normalizeSupplierParty(input);
    setInvalid(!normalized);
    if (normalized) void onSave(normalized);
  };
  return <form ref={form} onSubmit={submit} className="mt-4 space-y-3 rounded-lg border border-slate-200 p-4" aria-label={t(supplier ? "supplierMutation.edit" : "supplierMutation.create")}>
    <h3 className="font-semibold">{t(supplier ? "supplierMutation.edit" : "supplierMutation.create")}</h3>
    {!supplier && <p className="text-sm text-slate-500">{t("supplierMutation.activeOnCreate")}</p>}
    <fieldset disabled={disabled} className="space-y-3">
      {(["name", "code", "trn", "contact_person", "phone", "email", "address", "notes"] as const).map((field) => <Field key={field} label={t(`supplierMutation.${field}`)} required={field === "name"}>
        {field === "address" || field === "notes"
          ? <textarea name={field} className={inputClassName} value={input[field] ?? ""} onChange={(e) => setInput({ ...input, [field]: e.target.value })} />
          : <input name={field} type="text" className={inputClassName} value={input[field] ?? ""} required={field === "name"} onChange={(e) => setInput({ ...input, [field]: e.target.value })} />}
      </Field>)}
      {invalid && <p role="alert" className="text-sm text-red-700">{t("supplierMutation.invalid")}</p>}
      <button type="submit" className="rounded-lg bg-[var(--tenant-primary)] px-4 py-2 text-sm text-white disabled:opacity-50">{t("supplierMutation.save")}</button>
    </fieldset>
    <button type="button" onClick={onCancel} className="text-sm underline">{t("supplierMutation.close")}</button>
  </form>;
}
