import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { platformDeadline, PlatformDeadlineError, type ReadOptions } from "./platformDeadline.ts";

export const companyRoles = ["ACCOUNTING_ADMIN", "ACCOUNTANT", "PROJECT_MANAGER", "DATA_ENTRY", "PROCUREMENT", "MANAGEMENT_VIEWER", "FOREMAN"] as const;
export type CompanyAccessRole = typeof companyRoles[number];
export type Resource = "entities" | "customers" | "users" | "memberships" | "invitations" | "audit" | "settings" | "subscriptions";
export type PlatformRow = Record<string, string | number | boolean | null | Record<string, unknown>>;
export interface Directory { items: PlatformRow[]; has_more: boolean; }
export interface PlatformContext { user_id: string; role: "PLATFORM_OWNER"; step_up_required: boolean; }
export interface Receipt { id: string; request_id: string; command: string; status: "CONFIRMED"; }
export type AdminCommand =
  | { name: "set_subscription"; input: { id: string; version: string; plan_key: string; subscription_state: string; starts_on: string; ends_on: string; billing_method: string; payment_status: string; payment_reference?: string; reason: string } }
  | { name: "provision_accounting"; input: { id: string; version: string; code: string; treasury_name: string; treasury_type: string; bank_name?: string; reason: string } }
  | { name: "create_customer"; input: { code: string; name: string; contact_email?: string } }
  | { name: "update_customer"; input: { id: string; version: string; name: string; contact_email?: string } }
  | { name: "create_entity"; input: { code: string; name: string; tenant_slug: string; locale: string; entity_kind: string; initial_admin_id?: string; customer_id?: string; legal_name?: string; trn?: string; address?: string; region?: string } }
  | { name: "update_entity"; input: { id: string; version: string; name: string; entity_kind: string; plan_key: string; customer_id?: string; legal_name?: string; trn?: string; address?: string; region?: string } }
  | { name: "set_lifecycle"; input: { id: string; version: string; state: string; reason: string } }
  | { name: "set_membership"; input: { company_id: string; user_id: string; version: string; role: string; reason: string } }
  | { name: "set_user_status"; input: { id: string; version: string; status: string; reason: string } }
  | { name: "update_settings"; input: { version: string; support_email?: string; notice_en: string; notice_ar: string } }
  | { name: "invite"; input: { company_id: string; email: string; role: string } }
  | { name: "resend"; input: { id: string; version: string } }
  | { name: "revoke"; input: { id: string; version: string; reason: string } };
export type PendingCommand = { command: AdminCommand; requestId: string };
export type PlatformErrorKind = "denied" | "mfa" | "conflict" | "duplicate" | "invalid" | "uncertain" | "existing_user";
type AuthOperation = "auth_session" | "mfa_factors" | "mfa_enroll" | "mfa_unenroll" | "mfa_verify";
export class PlatformError extends Error {
  kind: PlatformErrorKind;
  operation?: RpcName | AuthOperation;
  code?: string;
  reason?: "unauthorized" | "session_revoked";
  constructor(kind: PlatformErrorKind, diagnostic?: { operation: RpcName | AuthOperation; code?: string; reason?: "unauthorized" | "session_revoked" }) {
    super(kind); this.kind = kind;
    this.operation = diagnostic?.operation; this.code = diagnostic?.code; this.reason = diagnostic?.reason;
  }
}
export const isUuid = (value: unknown): value is string => typeof value === "string" && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(value);
// These functions are provided by the canonical platform migrations. Keep the existing
// generated financial model intact; this transport accepts only this named RPC set.
type RpcName = "get_platform_onboarding" | "set_company_subscription" | "list_company_subscriptions" | "get_my_company_subscription" | "provision_company_accounting" | "get_platform_context" | "get_platform_overview" | "list_platform_entities" | "platform_directory" | "list_platform_invitations" | "platform_admin_command" | "platform_invitation_command" | "accept_platform_invitation" | "get_my_platform_invitation";
export interface PlatformTransport { rpc(name: RpcName, args?: Record<string, unknown>, options?: { signal?: AbortSignal }): PromiseLike<{ data: unknown; error: { code?: string; message?: string } | null }>; }
export function transport(client: SupabaseClient<Database>): PlatformTransport {
  const rpcClient = client as unknown as { rpc: (name: RpcName, args?: Record<string, unknown>) => ReturnType<PlatformTransport["rpc"]> & { abortSignal?: (signal: AbortSignal) => ReturnType<PlatformTransport["rpc"]> } };
  return { rpc(name, args, options) { const request = rpcClient.rpc(name, args); return options?.signal && request.abortSignal ? request.abortSignal(options.signal) : request; } };
}
const object = (value: unknown): value is Record<string, unknown> => value !== null && typeof value === "object" && !Array.isArray(value);
export async function callPlatform(api: PlatformTransport, name: RpcName, args?: Record<string, unknown>, options?: ReadOptions): Promise<unknown> {
  let response: Awaited<ReturnType<PlatformTransport["rpc"]>>;
  try { response = await platformDeadline(signal => api.rpc(name, args, { signal }), options); }
  catch (error) { throw new PlatformError("uncertain", { operation: name, code: error instanceof PlatformDeadlineError ? error.code : "TRANSPORT_ERROR" }); }
  if (response.error) {
    const { code, message } = response.error;
    // Retain only a bounded code and exact known denial reason. Never retain or
    // render arbitrary provider messages, details, JWTs or request payloads.
    const diagnostic = { operation: name, code: /^[A-Z0-9_]{1,32}$/.test(code ?? "") ? code : undefined,
      reason: code === "42501" && message === "Session revoked" ? "session_revoked" as const : code === "42501" && message === "Denied" ? "unauthorized" as const : undefined };
    throw new PlatformError(message?.includes("MFA_REQUIRED") ? "mfa" : code === "42501" ? "denied" : code === "40001" ? "conflict" : code === "23505" ? "duplicate" : ["22023", "22P02", "23514", "23503", "23502"].includes(code ?? "") ? "invalid" : "uncertain", diagnostic);
  }
  return response.data;
}
export async function readPlatformContext(api: PlatformTransport, options?: ReadOptions): Promise<PlatformContext> {
  const data = await callPlatform(api, "get_platform_context", undefined, options);
  if (!object(data) || !isUuid(data.user_id) || data.role !== "PLATFORM_OWNER" || typeof data.step_up_required !== "boolean") throw new PlatformError("denied", { operation: "get_platform_context", code: "INVALID_RESPONSE" });
  return data as unknown as PlatformContext;
}
export async function readPlatformOverview(api: PlatformTransport, options?: ReadOptions): Promise<Record<string, unknown>> {
  const data = await callPlatform(api, "get_platform_overview", undefined, options);
  const counts = ["entities", "active", "customers", "users", "pending_setup", "pending_invitations", "delivery_failures", "suspended", "archived"];
  if (!object(data) || counts.some(key => !Number.isSafeInteger(data[key]) || (data[key] as number) < 0) || typeof data.checked_at !== "string" || !Number.isFinite(Date.parse(data.checked_at))) {
    throw new PlatformError("uncertain", { operation: "get_platform_overview", code: "INVALID_RESPONSE" });
  }
  return data;
}
export async function readAuthenticatedPlatformContext(client: SupabaseClient<Database>, options?: ReadOptions): Promise<PlatformContext> {
  const session = await platformAuthRequest("auth_session", () => client.auth.getSession(), { ...options, timeoutMs: options?.timeoutMs ?? 5000 });
  if (!session.data.session) throw new PlatformError("denied", { operation: "auth_session", code: "SIGN_IN_REQUIRED" });
  return readPlatformContext(transport(client), options);
}
export async function platformAuthRequest<T extends { error: { code?: string } | null }>(operation: AuthOperation, work: () => PromiseLike<T>, options?: ReadOptions): Promise<T> {
  try {
    const result = await platformDeadline(work, options);
    if (result.error) {
      const code = /^[a-zA-Z0-9_]{1,48}$/.test(result.error.code ?? "") ? result.error.code : "AUTH_REQUEST_ERROR";
      const revoked = operation === "auth_session" && ["session_not_found", "session_expired", "refresh_token_not_found", "refresh_token_already_used", "bad_jwt"].includes(code ?? "");
      throw new PlatformError(revoked ? "denied" : "uncertain", { operation, code, reason: revoked ? "session_revoked" : undefined });
    }
    return result;
  } catch (error) {
    if (error instanceof PlatformError) throw error;
    throw new PlatformError("uncertain", { operation, code: error instanceof PlatformDeadlineError ? error.code : "AUTH_REQUEST_ERROR" });
  }
}
export async function readDirectory(api: PlatformTransport, resource: Resource, offset = 0, search = "", size = 25): Promise<Directory> {
  const args = { page_offset: offset, page_size: size, search: search.trim() };
  const data = await callPlatform(api, resource === "subscriptions" ? "list_company_subscriptions" : resource === "entities" ? "list_platform_entities" : resource === "invitations" ? "list_platform_invitations" : "platform_directory", resource === "entities" || resource === "invitations" || resource === "subscriptions" ? args : { ...args, resource });
  if (!object(data) || !Array.isArray(data.items) || data.items.length > size || data.items.some(row => !object(row)) || typeof data.has_more !== "boolean") throw new PlatformError("uncertain");
  return data as unknown as Directory;
}
export async function sendPlatformCommand(api: PlatformTransport, pending: PendingCommand): Promise<Receipt> {
  if (!isUuid(pending.requestId)) throw new PlatformError("invalid");
  const invitation = ["invite", "resend", "revoke"].includes(pending.command.name);
  const data = await callPlatform(api, pending.command.name === "set_subscription" ? "set_company_subscription" : pending.command.name === "provision_accounting" ? "provision_company_accounting" : invitation ? "platform_invitation_command" : "platform_admin_command", { ...(["provision_accounting", "set_subscription"].includes(pending.command.name) ? {} : { command_name: pending.command.name }), request_id: pending.requestId, business_input: pending.command.input });
  if (!object(data) || !isUuid(data.id) || data.request_id !== pending.requestId || data.status !== "CONFIRMED" || data.command !== (invitation ? `invitation_${pending.command.name}` : pending.command.name)) throw new PlatformError("uncertain");
  return data as unknown as Receipt;
}

export interface RecipientInvitation {
  user_id: string; invitation_id: string; company_id: string; company_name: string;
  role: CompanyAccessRole; state: "PENDING" | "ACCEPTED"; password_required: boolean; company_active: boolean;
}
export async function readRecipientInvitation(api: PlatformTransport, invitationId: string): Promise<RecipientInvitation> {
  const data = await callPlatform(api, "get_my_platform_invitation", { invitation_id: invitationId });
  if (!object(data) || !isUuid(data.user_id) || data.invitation_id !== invitationId || !isUuid(data.company_id)
    || typeof data.company_name !== "string" || !companyRoles.includes(data.role as CompanyAccessRole)
    || !["PENDING", "ACCEPTED"].includes(String(data.state)) || typeof data.password_required !== "boolean" || typeof data.company_active !== "boolean") {
    throw new PlatformError("uncertain", { operation: "get_my_platform_invitation", code: "INVALID_RESPONSE" });
  }
  return data as unknown as RecipientInvitation;
}

export interface CommercialReadiness {customer:boolean;active:boolean;administrator:boolean;foundation:boolean;subscription:boolean;legacy_eligible:boolean;legacy_access:boolean;ready:boolean;subscription_state:string}
export interface OnboardingCompany extends PlatformRow {id:string;name:string;code:string;readiness:CommercialReadiness & Record<string, string|boolean>;pending_admin_invitations:number}
export async function readOnboarding(api:PlatformTransport,args:{target_customer_id?:string;target_company_id?:string;page_offset:number;search:string}, options?:ReadOptions):Promise<{items:OnboardingCompany[];has_more:boolean}> {
  const data=await callPlatform(api,"get_platform_onboarding",args,options);
  if(!object(data)||!Array.isArray(data.items)||typeof data.has_more!=="boolean"||data.items.some(r=>!object(r)||!isUuid(r.id)||typeof r.name!=="string"||!object(r.readiness)||["customer","active","administrator","foundation","subscription","legacy_eligible","legacy_access","ready"].some(k=>typeof (r.readiness as Record<string,unknown>)[k]!=="boolean")))throw new PlatformError("uncertain");
  return data as unknown as {items:OnboardingCompany[];has_more:boolean};
}
