import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { mapPartyRow } from "./masterRepositories";
import type { ProductionParty } from "./masterTypes";

export interface SupplierPartyInput {
  name: string; code: string | null; trn: string | null; contact_person: string | null;
  phone: string | null; email: string | null; address: string | null; notes: string | null;
}
export type SupplierPartyCommand =
  | { kind: "create"; input: SupplierPartyInput }
  | { kind: "edit"; supplier: ProductionParty; input: SupplierPartyInput }
  | { kind: "status"; supplier: ProductionParty; status: "ACTIVE" | "INACTIVE" };
export type SupplierMutationError = "invalid" | "duplicate" | "denied" | "conflict" | "uncertain";
export type SupplierMutationResult = { ok: true; supplier: ProductionParty } | { ok: false; error: SupplierMutationError };
const columns = "id, company_id, type, name, code, trn, contact_person, phone, email, address, status, notes, created_at, created_by, updated_at, updated_by";

export function normalizeSupplierParty(input: SupplierPartyInput): SupplierPartyInput | null {
  if (!input || typeof input.name !== "string") return null;
  for (const field of ["code", "trn", "contact_person", "phone", "email", "address", "notes"] as const) {
    if (input[field] !== null && typeof input[field] !== "string") return null;
  }
  const name = input.name.trim();
  const optional = (value: string | null) => value === null ? null : value.trim() || null;
  const code = optional(input.code);
  if (![...name].length || [...name].length > 200 || (code !== null && [...code].length > 50)) return null;
  // Reconstruct only business fields; never spread caller-controlled objects.
  return { name, code, trn: optional(input.trn), contact_person: optional(input.contact_person),
    phone: optional(input.phone), email: optional(input.email), address: optional(input.address), notes: optional(input.notes) };
}

export async function mutateSupplierParty(client: SupabaseClient<Database>, activeCompanyId: string, command: SupplierPartyCommand): Promise<SupplierMutationResult> {
  if (command.kind !== "create" && (command.supplier.companyId !== activeCompanyId
    || command.supplier.type !== "SUPPLIER" || !command.supplier.updatedAt)) return { ok: false, error: "denied" };
  const input = command.kind === "status" ? null : normalizeSupplierParty(command.input);
  if (command.kind !== "status" && !input) return { ok: false, error: "invalid" };
  if (command.kind === "status" && command.status !== "ACTIVE" && command.status !== "INACTIVE") return { ok: false, error: "invalid" };
  try {
    // Generated Insert requires type (no global default). The authenticated BEFORE
    // INSERT trigger supplies it. This assertion adds no runtime payload field.
    const query = command.kind === "create"
      ? client.from("parties").insert({ company_id: activeCompanyId, ...input! } as Database["public"]["Tables"]["parties"]["Insert"])
      : client.from("parties").update(command.kind === "status" ? { status: command.status } : input!)
        .eq("company_id", activeCompanyId).eq("id", command.supplier.id)
        .eq("type", "SUPPLIER").eq("updated_at", command.supplier.updatedAt);
    const { data, error } = await query.select(columns);
    if (error) return { ok: false, error: error.code === "23505" ? "duplicate" : error.code === "42501" ? "denied" : ["23514", "23502", "22P02", "22001"].includes(error.code) ? "invalid" : "uncertain" };
    if (!data?.length) return { ok: false, error: command.kind === "create" ? "uncertain" : "conflict" };
    if (data.length !== 1 || data[0].company_id !== activeCompanyId || data[0].type !== "SUPPLIER" || !data[0].id
      || typeof data[0].updated_at !== "string" || !data[0].updated_at
      || (command.kind !== "create" && data[0].id !== command.supplier.id)) return { ok: false, error: "uncertain" };
    return { ok: true, supplier: mapPartyRow(data[0]) };
  } catch {
    return { ok: false, error: "uncertain" };
  }
}
