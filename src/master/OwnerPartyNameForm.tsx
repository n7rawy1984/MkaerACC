import { useLayoutEffect, useRef, useState, type FormEvent } from "react";
import { Field, inputClassName } from "../components/ui/Field";
import { useT } from "../i18n/I18nContext";
import { normalizeOwnerPartyName, type OwnerPartyNameInput } from "./ownerPartyNameMutations";
import type { ProductionParty } from "./masterTypes";

export function OwnerPartyNameForm({ party, disabled, onSave, onCancel }: {
  party: ProductionParty; disabled: boolean;
  onSave: (input: OwnerPartyNameInput) => Promise<void>; onCancel: () => void;
}) {
  const t = useT();
  const [input, setInput] = useState<OwnerPartyNameInput>({ name: party.name });
  const [invalid, setInvalid] = useState(false);
  const form = useRef<HTMLFormElement>(null);
  useLayoutEffect(() => {
    form.current?.querySelector<HTMLInputElement>('input[name="name"]')?.focus({ preventScroll: true });
    form.current?.scrollIntoView({ block: "nearest" });
  }, []);
  const submit = (event: FormEvent) => {
    event.preventDefault();
    if (disabled) return;
    const normalized = normalizeOwnerPartyName(input);
    setInvalid(!normalized);
    if (normalized) void onSave(normalized);
  };
  return <form ref={form} onSubmit={submit} className="mt-4 space-y-3 rounded-lg border border-slate-200 p-4" aria-label={t("ownerPartyName.edit")}>
    <p className="text-sm text-slate-500">{t("ownerPartyName.scope")}</p>
    <fieldset disabled={disabled} className="min-w-0 space-y-3">
      <Field label={t("ownerPartyName.name")}>
        <input name="name" type="text" required className={inputClassName} value={input.name} onChange={(e) => setInput({ name: e.target.value })} />
      </Field>
      <button type="submit" className="rounded-lg bg-[var(--tenant-primary)] px-4 py-2 text-sm text-white disabled:opacity-50">{t("ownerPartyName.save")}</button>
    </fieldset>
    {invalid && <p role="alert">{t("ownerPartyName.invalid")}</p>}
    <button type="button" onClick={onCancel} className="text-sm underline">{t("ownerPartyName.close")}</button>
  </form>;
}
