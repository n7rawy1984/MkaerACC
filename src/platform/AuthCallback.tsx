import { useEffect, useRef, useState, type FormEvent } from "react";
import { Link } from "react-router-dom";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { AuthFrame } from "../auth/AuthFrame";
import { useAuth } from "../auth/AuthContext";
import { useI18n } from "../i18n/I18nContext";
import { callPlatform, isUuid, transport } from "./platformApi";
import { platformText } from "./platformText";
import InvitationOnboarding from "./InvitationOnboarding";
import { assertPasswordSession, establishCallbackSession, type PasswordSession } from "./callbackSession";

function RecoveryCallback({ client }: { client: SupabaseClient<Database> }) {
  const { locale } = useI18n(); const t = platformText[locale]; const { retry } = useAuth();
  const [phase, setPhase] = useState<"loading" | "ready" | "error" | "accepted" | "passwordSaved" | "signOutError">("loading");
  const [busy, setBusy] = useState(false); const [initial] = useState(() => new URL(window.location.href));
  const flight = useRef<Promise<{ proof: PasswordSession | null; factor: string | null }> | null>(null);
  const proof = useRef<PasswordSession | null>(null);
  const [passwordAllowed, setPasswordAllowed] = useState(false);
  const [factor, setFactor] = useState<string | null>(null);
  const [mfaError, setMfaError] = useState(false);
  const invitationId = initial.searchParams.get("invitation_id");
  useEffect(() => {
    let alive = true;
    if (!flight.current) flight.current = (async () => {
      // Remove callback credentials from address/history before any asynchronous work.
      window.history.replaceState(null, "", `/auth/callback${isUuid(invitationId) ? `?invitation_id=${invitationId}` : ""}`);
      const verified = await establishCallbackSession(client, initial);
      if (!verified) return { proof: null, factor: null };
      const factors = await client.auth.mfa.listFactors();
      if (factors.error) throw factors.error;
      return { proof: verified, factor: factors.data.totp.find(f => f.status === "verified")?.id ?? null };
    })();
    void flight.current.then(value => { if (alive) { proof.current = value.proof; setPasswordAllowed(!!value.proof); setFactor(value.factor); setPhase(value.proof || isUuid(invitationId) ? "ready" : "error"); } }, () => { if (alive) setPhase("error"); });
    return () => { alive = false; };
  }, [client, invitationId, initial]);
  const accept = async () => { if (!isUuid(invitationId) || busy) return; setBusy(true); try { await callPlatform(transport(client), "accept_platform_invitation", { invitation_id: invitationId }); retry(); setPhase("accepted"); } catch { setPhase("error"); } finally { setBusy(false); } };
  const finishSignOut = async () => { setBusy(true);
    try { const result = await client.auth.signOut({ scope: "global" }); if (result.error) throw result.error; setPhase("passwordSaved"); }
    catch { setPhase("signOutError"); } finally { setBusy(false); }
  };
  const password = async (event: FormEvent<HTMLFormElement>) => { event.preventDefault(); if (busy) return; const data = new FormData(event.currentTarget); const password = String(data.get("password")); setBusy(true); setMfaError(false);
    try {
      if (!proof.current || phase !== "ready") throw new Error("Recovery required");
      await assertPasswordSession(client, proof.current);
      if (factor) {
        const verified = await client.auth.mfa.challengeAndVerify({ factorId: factor, code: String(data.get("code")) });
        if (verified.error) { setMfaError(true); return; }
        if (!verified.data.access_token || verified.data.user.id !== proof.current.userId) throw new Error("Session changed");
        proof.current = { userId: proof.current.userId, accessToken: verified.data.access_token };
        await assertPasswordSession(client, proof.current);
      }
      const result = await client.auth.updateUser({ password }); if (result.error) throw result.error; proof.current = null; await finishSignOut();
    } catch { proof.current = null; setPhase("error"); } finally { setBusy(false); }
  };
  return <AuthFrame><h1>{t.callback}</h1>{phase === "loading" && <p role="status">{t.loading}</p>}{phase === "error" && <p role="alert">{t.expired}</p>}
    {phase === "accepted" && <p role="status">{t.accepted}</p>}{phase === "passwordSaved" && <p role="status">{t.passwordSaved}</p>}
    {phase === "signOutError" && <><p role="alert">{t.passwordSignOutFailed}</p><button disabled={busy} onClick={() => void finishSignOut()}>{busy ? t.pending : t.signOut}</button></>}
    {phase === "ready" && <>{isUuid(invitationId) && <button disabled={busy} onClick={() => void accept()}>{busy ? t.pending : t.accept}</button>}
      {passwordAllowed && <><h2 className="mt-5">{t.recovery}</h2><form onSubmit={event => void password(event)}><label>{t.password}<input className="block w-full border rounded p-2 my-3" type="password" name="password" minLength={12} maxLength={128} autoComplete="new-password" required/></label>{factor && <label>{t.authenticatorCode}<input className="block w-full border rounded p-2 my-3" name="code" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" required/></label>}{mfaError && <p role="alert">{t.mfa}</p>}<button disabled={busy}>{busy ? t.pending : t.save}</button></form></>}
    </>}<p className="mt-5"><Link to="/auth/recovery">{t.recoveryRequest}</Link> · <Link to="/">{t.accounting}</Link> · <Link to="/platform">{t.title}</Link></p>
  </AuthFrame>;
}

export default function AuthCallback({ client }: { client: SupabaseClient<Database> }) {
  const invitationId = new URL(window.location.href).searchParams.get("invitation_id");
  return invitationId !== null ? <InvitationOnboarding key={invitationId} client={client} invitationId={invitationId}/> : <RecoveryCallback client={client}/>;
}
