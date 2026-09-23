import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { mapSubcontractRow } from "./masterRepositories";
import type { ProductionSubcontract } from "./masterTypes";

export interface SubcontractMetadataInput {
  scope_of_work: string;
  start_date: string | null;
  expected_end_date: string | null;
  notes: string | null;
}
export interface SubcontractMetadataCommand { subcontract: ProductionSubcontract; input: SubcontractMetadataInput; }
export type SubcontractMetadataMutationError = "invalid" | "denied" | "conflict" | "uncertain";
export type SubcontractMetadataMutationResult = { ok: true; subcontract: ProductionSubcontract } | { ok: false; error: SubcontractMetadataMutationError };

function normalizeDate(value: string | null): string | null | undefined {
  if (value === null || value === "") return null;
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value)) return undefined;
  const [year, month, day] = value.split("-").map(Number);
  const date = new Date(Date.UTC(year, month - 1, day));
  return date.getUTCFullYear() === year && date.getUTCMonth() === month - 1 && date.getUTCDate() === day ? value : undefined;
}

export function normalizeSubcontractMetadata(input: SubcontractMetadataInput): SubcontractMetadataInput | null {
  if (!input || typeof input.scope_of_work !== "string" || (input.notes !== null && typeof input.notes !== "string")) return null;
  const scope_of_work = input.scope_of_work.trim();
  const start_date = normalizeDate(input.start_date);
  const expected_end_date = normalizeDate(input.expected_end_date);
  if (!scope_of_work || start_date === undefined || expected_end_date === undefined) return null;
  return { scope_of_work, start_date, expected_end_date, notes: input.notes === null ? null : input.notes.trim() || null };
}

export async function updateSubcontractMetadata(client: SupabaseClient<Database>, activeCompanyId: string, command: SubcontractMetadataCommand): Promise<SubcontractMetadataMutationResult> {
  if (command.subcontract.companyId !== activeCompanyId || !command.subcontract.id || !command.subcontract.updatedAt) return { ok: false, error: "denied" };
  const input = normalizeSubcontractMetadata(command.input);
  if (!input) return { ok: false, error: "invalid" };
  try {
    const { data, error } = await client.from("subcontracts").update(input)
      .eq("company_id", activeCompanyId).eq("id", command.subcontract.id).eq("updated_at", command.subcontract.updatedAt)
      .select("id, company_id, project_id, subcontractor_id, contract_number, scope_of_work, original_contract_value_minor::text, approved_variations_minor::text, retention_bps, start_date, expected_end_date, status, notes, created_at, created_by, updated_at, updated_by");
    if (error) return { ok: false, error: error.code === "42501" ? "denied" : ["23514", "23502", "22007", "22P02"].includes(error.code) ? "invalid" : "uncertain" };
    if (!data?.length) return { ok: false, error: "conflict" };
    if (data.length !== 1 || data[0].company_id !== activeCompanyId || data[0].id !== command.subcontract.id || typeof data[0].updated_at !== "string" || !data[0].updated_at) return { ok: false, error: "uncertain" };
    return { ok: true, subcontract: mapSubcontractRow(data[0]) };
  } catch { return { ok: false, error: "uncertain" }; }
}
