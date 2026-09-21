import { useLayoutEffect, useRef, useState, type FormEvent } from "react";
import { Field, inputClassName } from "../components/ui/Field";
import { useT } from "../i18n/I18nContext";
import { normalizeAccountName, type AccountNameInput } from "./accountNameMutations";
import type { ProductionAccount } from "./masterTypes";

export function AccountNameForm({ account, disabled, onSave, onCancel }: {
  account: ProductionAccount; disabled: boolean;
  onSave: (input: AccountNameInput) => Promise<void>; onCancel: () => void;
}) {
  const t = useT();
  const [input, setInput] = useState<AccountNameInput>({ name: account.name });
  const [invalid, setInvalid] = useState(false);
  const form = useRef<HTMLFormElement>(null);
  useLayoutEffect(() => {
    form.current?.querySelector<HTMLInputElement>('input[name="name"]')?.focus({ preventScroll: true });
    form.current?.scrollIntoView({ block: "nearest" });
  }, []);
  const submit = (event: FormEvent) => {
    event.preventDefault();
    if (disabled) return;
    const normalized = normalizeAccountName(input);
    setInvalid(!normalized);
    if (normalized) void onSave(normalized);
  };
  return <form ref={form} onSubmit={submit} className="mt-4 space-y-3 rounded-lg border border-slate-200 p-4" aria-label={t("accountName.edit")}>
    <p className="text-sm text-slate-500">{t("accountName.scope")}</p>
    <fieldset disabled={disabled} className="min-w-0 space-y-3">
      <Field label={t("accountName.name")}>
        <input name="name" type="text" required className={inputClassName} value={input.name} onChange={(e) => setInput({ name: e.target.value })} />
      </Field>
      <button type="submit" className="rounded-lg bg-[var(--tenant-primary)] px-4 py-2 text-sm text-white disabled:opacity-50">{t("accountName.save")}</button>
    </fieldset>
    {invalid && <p role="alert">{t("accountName.invalid")}</p>}
    <button type="button" onClick={onCancel} className="text-sm underline">{t("accountName.close")}</button>
  </form>;
}
