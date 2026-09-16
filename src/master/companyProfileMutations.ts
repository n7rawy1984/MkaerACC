import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { mapCompanyRow } from "./masterRepositories";
import type { ProductionCompanyProfile } from "./masterTypes";

export interface CompanyProfileInput {
  legal_name: string | null;
  trn: string | null;
  address: string | null;
  notes: string | null;
}
export interface CompanyProfileCommand { company: ProductionCompanyProfile; input: CompanyProfileInput; }
export type CompanyProfileMutationError = "invalid" | "denied" | "conflict" | "uncertain";
export type CompanyProfileMutationResult = { ok: true; company: ProductionCompanyProfile } | { ok: false; error: CompanyProfileMutationError };

export function normalizeCompanyProfile(input: CompanyProfileInput): CompanyProfileInput | null {
  if (!input) return null;
  for (const field of ["legal_name", "trn", "address", "notes"] as const) {
    if (input[field] !== null && typeof input[field] !== "string") return null;
  }
  const optional = (value: string | null) => value === null ? null : value.trim() || null;
  return { legal_name: optional(input.legal_name), trn: optional(input.trn), address: optional(input.address), notes: optional(input.notes) };
}

export async function updateCompanyProfile(client: SupabaseClient<Database>, activeCompanyId: string, command: CompanyProfileCommand): Promise<CompanyProfileMutationResult> {
  if (command.company.id !== activeCompanyId || command.company.status !== "ACTIVE" || !command.company.updatedAt) return { ok: false, error: "denied" };
  const input = normalizeCompanyProfile(command.input);
  if (!input) return { ok: false, error: "invalid" };
  try {
    const { data, error } = await client.from("companies").update(input)
      .eq("id", activeCompanyId).eq("updated_at", command.company.updatedAt)
      .select("id, code, name, legal_name, trn, address, notes, status, created_at, created_by, updated_at, updated_by");
    if (error) return { ok: false, error: error.code === "42501" ? "denied" : ["23514", "23502", "22P02"].includes(error.code) ? "invalid" : "uncertain" };
    if (!data?.length) return { ok: false, error: "conflict" };
    if (data.length !== 1 || data[0].id !== activeCompanyId || data[0].status !== "ACTIVE"
      || typeof data[0].updated_at !== "string" || !data[0].updated_at) return { ok: false, error: "uncertain" };
    return { ok: true, company: mapCompanyRow(data[0]) };
  } catch {
    return { ok: false, error: "uncertain" };
  }
}
