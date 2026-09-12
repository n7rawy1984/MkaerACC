/* oxlint-disable react/only-export-components -- provider and its colocated hook form one auth boundary */
import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useRef,
  useState,
  type ReactNode,
} from "react";
import type { AuthChangeEvent, Session, SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import type { AuthProfile, AuthState, SignInResult, TenantMembership } from "./authTypes";

interface TransportState { userId: string; generation: number; preserveReadyState: boolean; }
interface AuthContextValue {
  state: AuthState;
  signIn: (email: string, password: string) => Promise<SignInResult>;
  signOut: () => Promise<void>;
  retry: () => void;
  chooseCompany: (companyId: string) => void;
  showCompanySelector: () => void;
}

const AuthContext = createContext<AuthContextValue | null>(null);
const preferenceKey = (userId: string) => `makeracc:p6a:active-company:${userId}`;

function readPreference(userId: string): string | null {
  try { return window.localStorage.getItem(preferenceKey(userId)); } catch { return null; }
}
function writePreference(userId: string, companyId: string): void {
  try { window.localStorage.setItem(preferenceKey(userId), companyId); } catch { /* in-memory state remains authoritative */ }
}
function removePreference(userId: string): void {
  try { window.localStorage.removeItem(preferenceKey(userId)); } catch { /* storage may be unavailable */ }
}

function sameReadyAuthority(current: AuthState, profile: AuthProfile, memberships: TenantMembership[], activeTenant: TenantMembership): boolean {
  if (current.phase !== "TENANT_READY") return false;
  if (current.profile.userId !== profile.userId
    || current.profile.displayName !== profile.displayName
    || current.profile.email !== profile.email
    || current.profile.locale !== profile.locale
    || current.activeTenant.companyId !== activeTenant.companyId) return false;
  const membershipKey = (membership: TenantMembership) => [
    membership.membershipId,
    membership.companyId,
    membership.companyCode,
    membership.companyName,
    membership.companyLegalName,
    membership.role,
  ].join(":");
  return current.memberships.map(membershipKey).sort().join("|")
    === memberships.map(membershipKey).sort().join("|");
}

export function AuthProvider({ client, children }: { client: SupabaseClient<Database>; children: ReactNode }) {
  const [state, setState] = useState<AuthState>({ phase: "INITIALIZING_AUTH" });
  const stateRef = useRef<AuthState>(state);
  const [transport, setTransport] = useState<TransportState | null>(null);
  const sessionRef = useRef<Session | null>(null);
  const userIdRef = useRef<string | null>(null);
  const generationRef = useRef(0);
  const requestRef = useRef(0);
  const backgroundGenerationRef = useRef<number | null>(null);
  const forcedCompanyRef = useRef<string | null>(null);

  useEffect(() => {
    stateRef.current = state;
  }, [state]);

  const clearProtectedState = useCallback(() => {
    requestRef.current += 1;
    sessionRef.current = null;
    userIdRef.current = null;
    backgroundGenerationRef.current = null;
    forcedCompanyRef.current = null;
    setTransport(null);
    setState({ phase: "SIGNED_OUT" });
  }, []);

  useEffect(() => {
    const handleAuthEvent = (event: AuthChangeEvent, session: Session | null) => {
      if (event === "SIGNED_OUT" || !session) {
        clearProtectedState();
        return;
      }

      const sameKnownUser = userIdRef.current === session.user.id;
      sessionRef.current = session;
      userIdRef.current = session.user.id;
      if (event === "TOKEN_REFRESHED") return;

      // Supabase may re-emit SIGNED_IN when an existing tab regains focus. The
      // focus/visibility path below owns authority revalidation for that case.
      if (event === "SIGNED_IN" && sameKnownUser && stateRef.current.phase !== "SIGNED_OUT"
        && stateRef.current.phase !== "INITIALIZING_AUTH") return;

      if (event === "INITIAL_SESSION" || event === "SIGNED_IN" || event === "USER_UPDATED") {
        backgroundGenerationRef.current = null;
        const generation = ++generationRef.current;
        requestRef.current += 1;
        setState({ phase: "LOADING_IDENTITY" });
        setTransport({ userId: session.user.id, generation, preserveReadyState: false });
      }
    };

    const { data: { subscription } } = client.auth.onAuthStateChange(handleAuthEvent);
    return () => {
      requestRef.current += 1;
      subscription.unsubscribe();
    };
  }, [clearProtectedState, client]);

  useEffect(() => {
    if (!transport) return;
    const request = ++requestRef.current;
    const { userId, generation, preserveReadyState } = transport;
    const isCurrent = () => requestRef.current === request
      && generationRef.current === generation
      && userIdRef.current === userId
      && sessionRef.current?.user.id === userId;

    const loadIdentity = async () => {
      try {
        const { data: claimsData, error: claimsError } = await client.auth.getClaims();
        if (!isCurrent()) return;
        if (claimsError || claimsData?.claims?.sub !== userId) {
          clearProtectedState();
          await client.auth.signOut({ scope: "local" });
          return;
        }

        const { data: profileRow, error: profileError } = await client
          .from("profiles")
          .select("user_id, display_name, email_snapshot, locale, status")
          .eq("user_id", userId)
          .eq("status", "ACTIVE")
          .maybeSingle();
        if (!isCurrent()) return;
        if (profileError) throw profileError;

        if (!profileRow) {
          removePreference(userId);
          setState({ phase: "NO_ACTIVE_COMPANY", profile: null, memberships: [] });
          return;
        }

        const profile: AuthProfile = {
          userId: profileRow.user_id,
          displayName: profileRow.display_name,
          email: profileRow.email_snapshot,
          locale: profileRow.locale,
        };
        const { data: membershipRows, error: membershipError } = await client
          .from("company_memberships")
          .select("id, company_id, role, status, user_id")
          .eq("user_id", userId)
          .eq("status", "ACTIVE");
        if (!isCurrent()) return;
        if (membershipError) throw membershipError;

        const companyIds = [...new Set((membershipRows ?? []).map((row) => row.company_id))];
        let companyRows: Database["public"]["Tables"]["companies"]["Row"][] = [];
        if (companyIds.length > 0) {
          const { data, error } = await client
            .from("companies")
            .select("id, code, name, legal_name, status")
            .in("id", companyIds)
            .eq("status", "ACTIVE");
          if (!isCurrent()) return;
          if (error) throw error;
          companyRows = (data ?? []) as Database["public"]["Tables"]["companies"]["Row"][];
        }

        const companies = new Map(companyRows.map((company) => [company.id, company]));
        const memberships: TenantMembership[] = (membershipRows ?? []).flatMap((membership) => {
          const company = companies.get(membership.company_id);
          return company ? [{
            membershipId: membership.id,
            companyId: company.id,
            companyCode: company.code,
            companyName: company.name,
            companyLegalName: company.legal_name,
            role: membership.role,
          }] : [];
        });
        if (!isCurrent()) return;

        if (memberships.length === 0) {
          removePreference(userId);
          setState({ phase: "NO_ACTIVE_COMPANY", profile, memberships });
          return;
        }

        const forcedCompany = forcedCompanyRef.current;
        forcedCompanyRef.current = null;
        const rememberedCompany = forcedCompany ?? readPreference(userId);
        const selected = rememberedCompany
          ? memberships.find((membership) => membership.companyId === rememberedCompany)
          : undefined;

        if (rememberedCompany && !selected) removePreference(userId);
        if (forcedCompany && !selected) {
          setState({ phase: "SELECTING_COMPANY", profile, memberships });
          return;
        }
        if (selected || memberships.length === 1) {
          const activeTenant = selected ?? memberships[0];
          writePreference(userId, activeTenant.companyId);
          setState((current) => preserveReadyState && sameReadyAuthority(current, profile, memberships, activeTenant)
            ? current
            : { phase: "TENANT_READY", profile, memberships, activeTenant });
          return;
        }
        setState({ phase: "SELECTING_COMPANY", profile, memberships });
      } catch {
        if (isCurrent() && !preserveReadyState) setState({ phase: "IDENTITY_LOAD_ERROR" });
      } finally {
        if (backgroundGenerationRef.current === generation) backgroundGenerationRef.current = null;
      }
    };

    void loadIdentity();
  }, [clearProtectedState, client, transport]);

  const revalidate = useCallback((companyId?: string, background = false) => {
    const userId = userIdRef.current;
    if (!userId || !sessionRef.current) return;
    const preserveReadyState = background && stateRef.current.phase === "TENANT_READY";
    if (preserveReadyState && backgroundGenerationRef.current !== null) return;
    forcedCompanyRef.current = companyId ?? null;
    const generation = ++generationRef.current;
    backgroundGenerationRef.current = preserveReadyState ? generation : null;
    requestRef.current += 1;
    if (!preserveReadyState) setState({ phase: "LOADING_IDENTITY" });
    setTransport({ userId, generation, preserveReadyState });
  }, []);

  useEffect(() => {
    const refresh = () => revalidate(undefined, true);
    const visible = () => { if (document.visibilityState === "visible") revalidate(undefined, true); };
    window.addEventListener("focus", refresh);
    document.addEventListener("visibilitychange", visible);
    return () => {
      window.removeEventListener("focus", refresh);
      document.removeEventListener("visibilitychange", visible);
    };
  }, [revalidate]);

  const signIn = useCallback(async (email: string, password: string): Promise<SignInResult> => {
    try {
      const { error } = await client.auth.signInWithPassword({ email, password });
      if (!error) return { ok: true };
      return { ok: false, kind: error.status && error.status >= 500 ? "connectivity" : "invalid" };
    } catch {
      return { ok: false, kind: "connectivity" };
    }
  }, [client]);

  const signOut = useCallback(async () => {
    const userId = userIdRef.current;
    if (userId) removePreference(userId);
    generationRef.current += 1;
    clearProtectedState();
    await client.auth.signOut({ scope: "local" });
  }, [clearProtectedState, client]);

  const showCompanySelector = useCallback(() => {
    setState((current) => current.phase === "TENANT_READY"
      ? { phase: "SELECTING_COMPANY", profile: current.profile, memberships: current.memberships }
      : current);
  }, []);

  const value = useMemo<AuthContextValue>(() => ({
    state,
    signIn,
    signOut,
    retry: () => revalidate(),
    chooseCompany: (companyId) => revalidate(companyId),
    showCompanySelector,
  }), [revalidate, showCompanySelector, signIn, signOut, state]);

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth(): AuthContextValue {
  const context = useContext(AuthContext);
  if (!context) throw new Error("useAuth must be used within AuthProvider");
  return context;
}
