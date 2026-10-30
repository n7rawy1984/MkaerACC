import { useState, type FormEvent } from "react";
import { Link } from "react-router-dom";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { AuthFrame } from "../auth/AuthFrame";
import { useI18n } from "../i18n/I18nContext";
import { platformText } from "./platformText";

export default function RecoveryRequest({ client }: { client: SupabaseClient<Database> }) {
  const { locale } = useI18n(); const t = platformText[locale];
  const [busy, setBusy] = useState(false); const [done, setDone] = useState(false);
  const submit = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault(); if (busy) return; const email = String(new FormData(event.currentTarget).get("email")).trim(); setBusy(true);
    try {
      await client.auth.resetPasswordForEmail(email, { redirectTo: `${window.location.origin}/auth/callback` });
    } finally {
      // Identical response for absent accounts/provider failures: no user enumeration.
      setDone(true); setBusy(false);
    }
  };
  return <AuthFrame><h1>{t.recoveryRequest}</h1>{done ? <p role="status">{t.recoveryRequested}</p> : <form onSubmit={event => { void submit(event).catch(() => { /* response above deliberately remains generic */ }); }}>
    <label>{t.email}<input className="my-3 block w-full rounded border p-2" dir="ltr" name="email" type="email" required autoComplete="email" maxLength={254}/></label>
    <button disabled={busy}>{busy ? t.pending : t.recoveryRequest}</button>
  </form>}<p className="mt-5"><Link to="/platform">{t.title}</Link></p></AuthFrame>;
}
