import type { Database } from "../types/database.generated";

export type CompanyRole = Database["public"]["Enums"]["company_role"];
export interface AuthProfile { userId: string; displayName: string; email: string | null; locale: "en" | "ar"; }
export interface TenantMembership { membershipId: string; companyId: string; companyCode: string; companyName: string; role: CompanyRole; }
interface IdentityState { profile: AuthProfile; memberships: TenantMembership[]; }

export type AuthState =
  | { phase: "INITIALIZING_AUTH" }
  | { phase: "SIGNED_OUT" }
  | { phase: "LOADING_IDENTITY" }
  | { phase: "NO_ACTIVE_COMPANY"; profile: AuthProfile | null; memberships: TenantMembership[] }
  | ({ phase: "SELECTING_COMPANY" } & IdentityState)
  | ({ phase: "TENANT_READY"; activeTenant: TenantMembership } & IdentityState)
  | { phase: "IDENTITY_LOAD_ERROR" };

export type SignInResult = { ok: true } | { ok: false; kind: "invalid" | "connectivity" };
