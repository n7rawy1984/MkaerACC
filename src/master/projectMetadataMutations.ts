import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { mapProjectRow } from "./masterRepositories";
import type { ProductionProjectSummary } from "./masterTypes";

export interface ProjectMetadataInput {
  name: string;
  client_name: string | null;
  location: string | null;
  contract_number: string | null;
  notes: string | null;
}
export interface ProjectMetadataCommand { project: ProductionProjectSummary; input: ProjectMetadataInput; }
export type ProjectMetadataMutationError = "invalid" | "denied" | "conflict" | "uncertain";
export type ProjectMetadataMutationResult = { ok: true; project: ProductionProjectSummary } | { ok: false; error: ProjectMetadataMutationError };
export function normalizeProjectMetadata(input: ProjectMetadataInput): ProjectMetadataInput | null {
  if (!input || typeof input.name !== "string") return null;
  const name = input.name.trim();
  if (!name || [...name].length > 200) return null;
  for (const field of ["client_name", "location", "contract_number", "notes"] as const) {
    if (input[field] !== null && typeof input[field] !== "string") return null;
  }
  const optional = (value: string | null) => value === null ? null : value.trim() || null;
  return { name, client_name: optional(input.client_name), location: optional(input.location), contract_number: optional(input.contract_number), notes: optional(input.notes) };
}
export async function updateProjectMetadata(client: SupabaseClient<Database>, activeCompanyId: string, command: ProjectMetadataCommand): Promise<ProjectMetadataMutationResult> {
  if (command.project.companyId !== activeCompanyId || !command.project.id || !command.project.updatedAt) return { ok: false, error: "denied" };
  const input = normalizeProjectMetadata(command.input);
  if (!input) return { ok: false, error: "invalid" };
  try {
    const { data, error } = await client.from("projects").update(input)
      .eq("company_id", activeCompanyId).eq("id", command.project.id).eq("updated_at", command.project.updatedAt)
      .select("id, company_id, code, name, client_name, location, contract_number, notes, start_date, expected_completion_date, status, created_at, created_by, updated_at, updated_by");
    if (error) return { ok: false, error: error.code === "42501" ? "denied" : ["23514", "23502", "22P02"].includes(error.code) ? "invalid" : "uncertain" };
    if (!data?.length) return { ok: false, error: "conflict" };
    if (data.length !== 1 || data[0].company_id !== activeCompanyId || data[0].id !== command.project.id || typeof data[0].updated_at !== "string" || !data[0].updated_at) return { ok: false, error: "uncertain" };
    return { ok: true, project: mapProjectRow(data[0]) };
  } catch { return { ok: false, error: "uncertain" }; }
}
