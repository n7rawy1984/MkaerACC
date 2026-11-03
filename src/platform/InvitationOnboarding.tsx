import { useCallback, useEffect, useRef, useState, type FormEvent } from "react";
import { Link, useNavigate } from "react-router-dom";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { useAuth } from "../auth/AuthContext";
import { AuthFrame } from "../auth/AuthFrame";
import { LoginPage } from "../auth/LoginPage";
import { useI18n } from "../i18n/I18nContext";
import { platformText } from "./platformText";
import { callPlatform, isUuid, platformAuthRequest, PlatformError, readRecipientInvitation, transport, type RecipientInvitation } from "./platformApi";
import { callbackInput } from "./callbackInput";
import { establishCallbackSession, assertPasswordSession, type PasswordSession } from "./callbackSession";
import { platformDeadline } from "./platformDeadline";

type Phase = "loading" | "signin" | "password" | "review" | "accepted" | "error" | "signOutError" | "entering";
export default function InvitationOnboarding({ client, invitationId }: { client: SupabaseClient<Database>; invitationId: string }) {
  const { locale } = useI18n(); const t = platformText[locale]; const navigate = useNavigate();
  const { state, chooseCompany, signOut } = useAuth();
  const [phase, setPhase] = useState<Phase>("loading"); const [context, setContext] = useState<RecipientInvitation | null>(null);
  const [busy, setBusy] = useState(false); const [message, setMessage] = useState<"unavailable" | "request" | "password" | "workspace" | null>(null);
  const [passwordSaved, setPasswordSaved] = useState(false); const [factor, setFactor] = useState<string | null>(null);
  const actor = useRef<string | null>(null); const proof = useRef<PasswordSession | null>(null); const mounted = useRef(false); const sequence = useRef(0); const lock = useRef(false);
  const initial = useRef(new URL(window.location.href)); const initialFlight = useRef<Promise<void> | null>(null);
  const load = useCallback(async () => {
    const run = ++sequence.current; setPhase("loading"); setMessage(null); proof.current = null;
    try {
      if (!isUuid(invitationId)) throw new PlatformError("denied");
      const session = await platformAuthRequest("auth_session", () => client.auth.getSession(), { timeoutMs: 5000 });
      if (!session.data.session) { if (mounted.current && run === sequence.current) { setContext(null); setPhase("signin"); } return; }
      const identity = await platformDeadline(() => client.auth.getUser());
      if (identity.error || identity.data.user?.id !== session.data.session.user.id) throw new PlatformError("denied");
      const data = await readRecipientInvitation(transport(client), invitationId);
      if (data.user_id !== identity.data.user.id) throw new PlatformError("denied");
      let verifiedFactor: string | null = null;
      if (data.password_required) {
        const factors = await platformAuthRequest("mfa_factors", () => client.auth.mfa.listFactors());
        if (!factors.data) throw new PlatformError("uncertain");
        verifiedFactor = factors.data.totp.find(f => f.status === "verified")?.id ?? null;
      }
      if (!mounted.current || run !== sequence.current) return;
      actor.current = data.user_id; setContext(data); setFactor(verifiedFactor);
      // This proof is memory-only and validated again before credential mutation.
      // The recipient RPC establishes eligibility; browser intent never authorizes it.
      if (data.password_required) proof.current = { userId: data.user_id, accessToken: session.data.session.access_token };
      setPhase(data.password_required ? "password" : data.state === "ACCEPTED" ? "accepted" : "review");
    } catch (error) {
      if (!mounted.current || run !== sequence.current) return;
      setContext(null); setMessage(error instanceof PlatformError && error.kind === "denied" ? "unavailable" : "request"); setPhase("error");
    }
  }, [client, invitationId]);
  useEffect(() => {
    mounted.current = true;
    // Only the non-secret invitation UUID survives in the URL; tokens never do.
    window.history.replaceState(null, "", `/auth/callback${isUuid(invitationId) ? `?invitation_id=${invitationId}` : ""}`);
    if (!initialFlight.current) initialFlight.current = (async () => {
      try {
        if (!isUuid(invitationId)) throw Error();
        if (callbackInput(initial.current).kind !== "session") await platformDeadline(() => establishCallbackSession(client, initial.current));
        if (mounted.current) await load();
      } catch { if (mounted.current) { setMessage("unavailable"); setPhase("error"); } }
    })();
    const { data: { subscription } } = client.auth.onAuthStateChange((event, session) => {
      if (event === "SIGNED_OUT") { sequence.current++; actor.current = null; proof.current = null; setContext(null); setPhase("signin"); }
      // SDK calls are deferred outside the Auth event's lock. Initial token
      // consumption is owned by the single initialFlight, never replayed here.
      if (event === "SIGNED_IN" && actor.current && session?.user.id !== actor.current) { sequence.current++; actor.current = null; proof.current = null; setContext(null); setPhase("loading"); }
      if (event === "SIGNED_IN") queueMicrotask(() => { if (mounted.current && !lock.current) void load(); });
    });
    return () => { mounted.current = false; subscription.unsubscribe(); };
  }, [client, invitationId, load]);
  useEffect(() => {
    if (phase !== "entering" || !context) return;
    if (state.phase === "TENANT_READY" && state.profile.userId === context.user_id && state.activeTenant.companyId === context.company_id) {
      navigate(state.activeTenant.role === "FOREMAN" ? "/attendance" : "/", { replace: true });
    }
  }, [phase, context, state, navigate]);
  useEffect(() => {
    if (phase !== "entering") return;
    const timer = setTimeout(() => { setPhase("accepted"); setMessage("workspace"); }, 10000);
    return () => clearTimeout(timer);
  }, [phase]);
  const workspaceDenied = phase === "entering" && (["NO_ACTIVE_COMPANY", "SELECTING_COMPANY", "IDENTITY_LOAD_ERROR"].includes(state.phase) || (state.phase === "TENANT_READY" && state.activeTenant.companyId !== context?.company_id));
  const finishSignOut = async () => {
    try {
      const result = await platformDeadline(() => client.auth.signOut({ scope: "global" })); if (result.error) throw Error();
      if (mounted.current) { setContext(null); setPasswordSaved(true); setPhase("signin"); }
    } catch { if (mounted.current) setPhase("signOutError"); }
  };
  const password = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault(); if (lock.current || !proof.current || !context) return;
    const data = new FormData(event.currentTarget); lock.current = true; setBusy(true); setMessage(null);
    try {
      await platformDeadline(() => assertPasswordSession(client, proof.current!));
      const latest = await readRecipientInvitation(transport(client), invitationId);
      if (latest.user_id !== context.user_id || !latest.password_required) { await load(); return; }
      if (factor) {
        const verified = await platformAuthRequest("mfa_verify", () => client.auth.mfa.challengeAndVerify({ factorId: factor, code: String(data.get("code")) }));
        if (!verified.data?.access_token || verified.data.user.id !== context.user_id) throw Error();
        proof.current = { userId: context.user_id, accessToken: verified.data.access_token };
        await platformDeadline(() => assertPasswordSession(client, proof.current!));
      }
      await platformDeadline(() => assertPasswordSession(client, proof.current!));
      const result = await platformDeadline(() => client.auth.updateUser({ password: String(data.get("password")) })); if (result.error) throw Error();
      proof.current = null; await finishSignOut();
    } catch { if (mounted.current) { setMessage("password"); setPhase("error"); } }
    finally { lock.current = false; if (mounted.current) setBusy(false); }
  };
  const accept = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault(); if (lock.current || !context) return; lock.current = true; setBusy(true); setMessage(null);
    try {
      const result = await callPlatform(transport(client), "accept_platform_invitation", { invitation_id: invitationId });
      if (result !== context.company_id) throw new PlatformError("uncertain");
      await load(); // Reconcile authoritative state; never create another grant locally.
    } catch (error) { if (mounted.current) { setPhase("error"); setMessage(error instanceof PlatformError && ["denied", "invalid"].includes(error.kind) ? "unavailable" : "request"); } }
    finally { lock.current = false; if (mounted.current) setBusy(false); }
  };
  if (phase === "signin") return <><AuthFrame><h1>{t.invitationContinue}</h1><p>{passwordSaved ? t.invitationPasswordSaved : t.invitationSignIn}</p></AuthFrame><LoginPage/></>;
  return <AuthFrame><h1>{t.invitationContinue}</h1>
    {workspaceDenied && <p role="alert">{t.invitationWorkspacePending}</p>}
    {message && <p role="alert">{message === "unavailable" ? t.invitationUnavailable : message === "password" ? t.invitationPasswordError : message === "workspace" ? t.invitationWorkspacePending : t.invitationRetry}</p>}
    {phase === "loading" || (phase === "entering" && !workspaceDenied) ? <p role="status">{t.loading}</p> : null}
    {context && <dl><dt>{t.company_id}</dt><dd>{context.company_name}</dd><dt>{t.role}</dt><dd>{t[context.role]}</dd></dl>}
    {phase === "password" && <form onSubmit={event => void password(event)}><h2>{t.recovery}</h2><p>{t.invitationPasswordFirst}</p><label>{t.password}<input className="block w-full border rounded p-2 my-3" type="password" name="password" minLength={12} maxLength={128} autoComplete="new-password" required disabled={busy}/></label>{factor && <label>{t.authenticatorCode}<input name="code" pattern="[0-9]{6}" autoComplete="one-time-code" inputMode="numeric" required disabled={busy}/></label>}<button disabled={busy}>{busy ? t.pending : t.save}</button></form>}
    {phase === "review" && <form onSubmit={event => void accept(event)}><p>{t.invitationReview}</p><label><input type="checkbox" name="confirmInvitation" required disabled={busy}/>{t.invitationConfirm}</label><button disabled={busy}>{busy ? t.pending : t.accept}</button></form>}
    {(phase === "accepted" || workspaceDenied) && <><p role="status">{t.accepted}</p>{!context?.company_active && <p>{t.invitationWorkspacePending}</p>}<button onClick={() => { if (context) { chooseCompany(context.company_id); setPhase("entering"); setMessage(null); } }}>{t.invitationOpenWorkspace}</button></>}
    {phase === "error" && <button disabled={busy} onClick={() => void load()}>{t.invitationCheckStatus}</button>}
    {phase === "signOutError" && <><p role="alert">{t.passwordSignOutFailed}</p><button disabled={busy} onClick={() => void finishSignOut()}>{t.signOut}</button></>}
    <p className="mt-5"><button disabled={busy} onClick={() => void signOut()}>{t.switchAccount}</button> · <Link to="/auth/recovery">{t.recoveryRequest}</Link></p>
  </AuthFrame>;
}
