// Synthetic transport only. Loaded exclusively by verify-platform-browser.mjs.
import { createRoot } from "react-dom/client";
import { BrowserRouter } from "react-router-dom";
import { I18nProvider } from "../../src/i18n/I18nContext";
import ProtectedApplication from "../../src/auth/ProtectedApplication";
import "../../src/index.css";
const id = (n: number) => `b0000000-0000-4000-8000-${String(n).padStart(12,"0")}`;
const listeners = new Set<(event: string, session: unknown) => void>();
const fixtureConfig = JSON.parse(window.sessionStorage.getItem("narvo-fixture-config") ?? "{}");
const f = {
  actor: id(fixtureConfig.actor ?? 1), aal: "aal1", totpAgeSeconds: 0, signedIn: fixtureConfig.signedIn ?? true, denied: false, uncertainNext: false, noFactor: !!fixtureConfig.realIdentity, realIdentity: !!fixtureConfig.realIdentity,
  hangSession: new URLSearchParams(window.location.search).has("fixture_auth_stall"),
  hangFactors: new URLSearchParams(window.location.search).has("fixture_mfa_stall"),
  hangRpc: new URLSearchParams(window.location.search).get("fixture_rpc_stall"),
  releaseRpc: null as null | (() => void),
  calls: [] as string[],
  mockDelivery: false, deliveryAttempts: 0, deliveredCount: 0,
  callbackCalls: [] as string[],
  factorListFailures: 0, enrollmentCalls: 0, signOutFails: false, passwordUpdates: 0, sessionToken: "synthetic-session",
  unfinishedFactors: [] as { id: string; status: string; friendly_name: string }[],
  unenrolledFactors: [] as string[],
  emit: (event = "SIGNED_IN") => listeners.forEach(cb => cb(event, f.signedIn ? { user: { id: f.actor } } : null)),
  client: {
    auth: {
      onAuthStateChange: (cb: (event: string, session: unknown) => void) => { listeners.add(cb); queueMicrotask(() => cb("INITIAL_SESSION", f.signedIn ? { user: { id: f.actor } } : null)); return { data: { subscription: { unsubscribe() { listeners.delete(cb); } } } }; },
      getClaims: async () => ({ data: { claims: { sub: f.actor } }, error: null }),
      getSession: async () => { if (f.hangSession) return new Promise(() => {}); return { data: { session: f.signedIn ? { user: { id: f.actor }, access_token: f.sessionToken } : null }, error: null }; },
      getUser: async () => ({ data: { user: f.signedIn ? { id: f.actor } : null }, error: null }),
      signInWithPassword: async () => { f.signedIn = true; window.sessionStorage.setItem("narvo-fixture-config", JSON.stringify({ ...fixtureConfig, signedIn: true })); f.emit(); return { error: null }; },
      signOut: async () => { if (f.signOutFails) return { error: new Error("Synthetic sign-out failure") }; f.signedIn = false; if (f.realIdentity) window.sessionStorage.setItem("narvo-fixture-config", JSON.stringify({ ...fixtureConfig, signedIn: false })); f.emit("SIGNED_OUT"); return { error: null }; },
      mfa: {
        listFactors: async () => { if (f.hangFactors) return new Promise(() => {}); if (f.factorListFailures > 0) { f.factorListFailures--; throw Error("Synthetic factor lookup failure"); } return { data: { totp: f.noFactor ? f.unfinishedFactors : [{ id: id(20), status: "verified" }] }, error: null }; },
        enroll: async () => { f.enrollmentCalls++; return { data: { id: id(20), totp: { qr_code: '<svg xmlns="http://www.w3.org/2000/svg" width="50" height="50"><rect width="50" height="50" fill="black"/></svg>' } }, error: null }; },
        unenroll: async ({ factorId }: { factorId: string }) => { f.unenrolledFactors.push(factorId); return { error: null }; },
        challengeAndVerify: async ({ code }: { code: string }) => { if (code !== "123456") return { error: new Error("Invalid fixture code") }; f.aal = "aal2"; f.totpAgeSeconds = 0; f.sessionToken = "synthetic-mfa-session"; f.emit("MFA_CHALLENGE_VERIFIED"); return { data: { access_token: f.sessionToken, user: { id: f.actor } }, error: null }; },
      },
      exchangeCodeForSession: async () => { f.callbackCalls.push("code"); return { data: { session: { access_token: f.sessionToken, user: { id: f.actor } }, user: { id: f.actor }, redirectType: "recovery" }, error: null }; },
      verifyOtp: async ({ type, token_hash }: { type: string; token_hash: string }) => { f.callbackCalls.push(type); if (token_hash === "synthetic-expired") return { data: { session: null, user: null }, error: new Error("Expired synthetic token") }; f.signedIn = true; if (f.realIdentity) window.sessionStorage.setItem("narvo-fixture-config", JSON.stringify({ ...fixtureConfig, signedIn: true })); return { data: { session: { access_token: f.sessionToken, user: { id: f.actor } }, user: { id: f.actor } }, error: null }; },
      updateUser: async () => { f.passwordUpdates++; if (f.realIdentity) await fetch("/__platform_password", { method: "POST", body: JSON.stringify({ actor: f.actor }) }); return { error: null }; }, resetPasswordForEmail: async () => ({ error: null }),
    },
    from: (table: string) => {
      f.calls.push(table); if (!f.realIdentity && !["profiles", "company_memberships", "companies"].includes(table)) throw Error("Unapproved fixture table");
      if (f.realIdentity) {
        const filters: Record<string, unknown> = {}; let one = false;
        const query = { select: () => query, eq: (k: string, v: unknown) => { filters[k] = v; return query; }, in: (k: string, v: unknown) => { filters[k] = v; return query; }, order: () => query, limit: () => query,
          maybeSingle: () => { one = true; return query; }, single: () => { one = true; return query; },
          then: async (done: (value: unknown) => void) => { const response = await fetch("/__platform_identity", { method: "POST", body: JSON.stringify({ table, actor: f.actor, filters, one }) }); return done(await response.json()); } };
        return query;
      }
      const query = { select: () => query, eq: () => query, in: () => query, maybeSingle: () => query,
        then: (done: (result: unknown) => void) => done({ data: table === "profiles" ? { user_id: f.actor, display_name: "Synthetic owner", email_snapshot: "owner@example.invalid", locale: "en", status: "ACTIVE" } : [], error: null }) };
      return query;
    },
    rpc: async (name: string, args = {}) => { f.calls.push(name); if (f.realIdentity && !["get_platform_onboarding", "set_company_subscription", "list_company_subscriptions", "get_my_company_subscription", "provision_company_accounting", "get_company_accounting_setup", "get_my_platform_invitation", "accept_platform_invitation", "get_platform_context", "get_platform_overview", "list_platform_entities", "platform_directory", "list_platform_invitations", "platform_admin_command", "platform_invitation_command"].includes(name)) return {data:null,error:{code:"FIXTURE_UNAVAILABLE"}}; const uncertain = f.uncertainNext && (/command$/.test(name) || ["provision_company_accounting", "set_company_subscription"].includes(name)); if (uncertain) f.uncertainNext = false;
      if (f.hangRpc === name) await new Promise<void>(resolve => { f.releaseRpc = resolve; });
      const result = await fetch("/__platform_rpc", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name, args, actor: f.denied ? id(2) : f.actor, aal: f.aal, totpAgeSeconds: f.totpAgeSeconds, uncertain }) }); return result.json();
    },
    functions: { invoke: async () => {
      if (!f.mockDelivery) return { data: null, error: new Error("Live delivery intentionally unavailable") };
      f.deliveryAttempts++;
      if (f.totpAgeSeconds > 600) return { data: null, error: { context: new Response(JSON.stringify({ error: "MFA_REQUIRED" }), { status: 403 }) } };
      f.deliveredCount++; return { data: { status: "DELIVERED" }, error: null };
    } },
  },
};
Object.assign(window, { platformFixture: f });
createRoot(document.getElementById("root")!).render(<I18nProvider><BrowserRouter><ProtectedApplication/></BrowserRouter></I18nProvider>);
