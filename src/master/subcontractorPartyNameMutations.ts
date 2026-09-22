import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { mapPartyRow } from "./masterRepositories";
import type { ProductionParty } from "./masterTypes";

export interface SubcontractorPartyNameInput {
  name: string;
}
export interface SubcontractorPartyNameCommand { party: ProductionParty; input: SubcontractorPartyNameInput; }
export type SubcontractorPartyNameMutationError = "invalid" | "denied" | "conflict" | "uncertain";
export type SubcontractorPartyNameMutationResult = { ok: true; party: ProductionParty } | { ok: false; error: SubcontractorPartyNameMutationError };
export function normalizeSubcontractorPartyName(input: SubcontractorPartyNameInput): SubcontractorPartyNameInput | null {
  if (!input || typeof input.name !== "string") return null;
  const name = input.name.trim();
  if (!name || [...name].length > 200) return null;
  return { name };
}
export async function updateSubcontractorPartyName(client: SupabaseClient<Database>, activeCompanyId: string, command: SubcontractorPartyNameCommand): Promise<SubcontractorPartyNameMutationResult> {
  if (command.party.type !== "SUBCONTRACTOR" || command.party.companyId !== activeCompanyId || !command.party.id || !command.party.updatedAt) return { ok: false, error: "denied" };
  const input = normalizeSubcontractorPartyName(command.input);
  if (!input) return { ok: false, error: "invalid" };
  try {
    const { data, error } = await client.from("parties").update(input)
      .eq("company_id", activeCompanyId).eq("type", "SUBCONTRACTOR").eq("id", command.party.id).eq("updated_at", command.party.updatedAt)
      .select("id, company_id, type, name, code, trn, contact_person, phone, email, address, status, notes, created_at, created_by, updated_at, updated_by");
    if (error) return { ok: false, error: error.code === "42501" ? "denied" : ["23514", "23502", "22P02"].includes(error.code) ? "invalid" : "uncertain" };
    if (!data?.length) return { ok: false, error: "conflict" };
    if (data.length !== 1 || data[0].company_id !== activeCompanyId || data[0].type !== "SUBCONTRACTOR" || data[0].id !== command.party.id || typeof data[0].updated_at !== "string" || !data[0].updated_at) return { ok: false, error: "uncertain" };
    return { ok: true, party: mapPartyRow(data[0]) };
  } catch { return { ok: false, error: "uncertain" }; }
}
