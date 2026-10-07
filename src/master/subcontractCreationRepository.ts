import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Json } from "../types/database.generated";
export type CreationError = "invalid" | "duplicate" | "denied" | "uncertain";
export const canCreateSubcontractMaster = (role: string) => role === "ACCOUNTING_ADMIN";
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function parseMasterDecimal(value: string, signed = false): string {
  const clean = value.trim();
  if (!(signed ? /^-?\d+(\.\d{1,2})?$/ : /^\d+(\.\d{1,2})?$/).test(clean)) throw new Error("invalid");
  const negative = clean.startsWith("-");
  const [whole, fraction = ""] = clean.replace(/^-/, "").split(".");
  const result = (BigInt(whole) * 100n + BigInt(fraction.padEnd(2, "0"))) * (negative ? -1n : 1n);
  if (result < -9223372036854775808n || result > 9223372036854775807n) throw new Error("invalid");
  return result.toString();
}
export function subcontractCreationInput(fields: Record<string, string>): Record<string, string | null> {
  if (!uuid.test(fields.project_id) || !uuid.test(fields.subcontractor_id)) throw new Error("invalid");
  const contract_number = fields.contract_number.trim(), scope_of_work = fields.scope_of_work.trim();
  const original = parseMasterDecimal(fields.original_contract_value_minor);
  const variations = parseMasterDecimal(fields.approved_variations_minor || "0", true);
  const retention = parseMasterDecimal(fields.retention_bps);
  if (!contract_number || [...contract_number].length > 100 || !scope_of_work || BigInt(original) + BigInt(variations) < 0n || BigInt(retention) > 10000n
    || !["ACTIVE", "COMPLETED", "CLOSED"].includes(fields.status)) throw new Error("invalid");
  const date = (value: string) => {
    if (!value) return null;
    if (!/^\d{4}-\d{2}-\d{2}$/.test(value) || !Number.isFinite(Date.parse(value)) || new Date(value).toISOString().slice(0,10) !== value) throw new Error("invalid");
    return value;
  };
  return { project_id: fields.project_id, subcontractor_id: fields.subcontractor_id, contract_number, scope_of_work,
    original_contract_value_minor: original, approved_variations_minor: variations, retention_bps: retention,
    start_date: date(fields.start_date), expected_end_date: date(fields.expected_end_date), status: fields.status, notes: fields.notes.trim() || null };
}
type CreationDatabase = Omit<Database, "public"> & { public: Omit<Database["public"], "Functions"> & { Functions: Database["public"]["Functions"] & {
  create_subcontractor_party: { Args: { target_company_id: string; business_input: Json }; Returns: string };
  create_subcontract: { Args: { target_company_id: string; business_input: Json }; Returns: string };
} } };
export async function createSubcontractMaster(client: SupabaseClient<Database>, companyId: string, kind: "party" | "subcontract", input: Record<string, string | null>): Promise<{ ok: true; id: string } | { ok: false; error: CreationError }> {
  if (!uuid.test(companyId)) return { ok: false, error: "denied" };
  try {
    const { data, error } = await (client as unknown as SupabaseClient<CreationDatabase>).rpc(kind === "party" ? "create_subcontractor_party" : "create_subcontract", { target_company_id: companyId, business_input: input });
    if (error) return { ok: false, error: error.code === "23505" ? "duplicate" : error.code === "42501" ? "denied" : ["23514","23502","23503","22023","22003","22P02","22007","22008"].includes(error.code) ? "invalid" : "uncertain" };
    return typeof data === "string" && uuid.test(data) ? { ok: true, id: data } : { ok: false, error: "uncertain" };
  } catch { return { ok: false, error: "uncertain" }; }
}
