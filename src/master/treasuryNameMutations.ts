import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { mapTreasuryAccountRow } from "./masterRepositories";
import type { ProductionTreasuryAccount } from "./masterTypes";

export interface TreasuryNameInput {
  name: string;
}
export interface TreasuryNameCommand { treasury: ProductionTreasuryAccount; input: TreasuryNameInput; }
export type TreasuryNameMutationError = "invalid" | "denied" | "conflict" | "uncertain";
export type TreasuryNameMutationResult = { ok: true; treasury: ProductionTreasuryAccount } | { ok: false; error: TreasuryNameMutationError };
export function normalizeTreasuryName(input: TreasuryNameInput): TreasuryNameInput | null {
  if (!input || typeof input.name !== "string") return null;
  const name = input.name.trim();
  if (!name || [...name].length > 200) return null;
  return { name };
}
export async function updateTreasuryName(client: SupabaseClient<Database>, activeCompanyId: string, command: TreasuryNameCommand): Promise<TreasuryNameMutationResult> {
  if (command.treasury.companyId !== activeCompanyId || !command.treasury.id || !command.treasury.updatedAt) return { ok: false, error: "denied" };
  const input = normalizeTreasuryName(command.input);
  if (!input) return { ok: false, error: "invalid" };
  try {
    const { data, error } = await client.from("treasury_accounts").update(input)
      .eq("company_id", activeCompanyId).eq("id", command.treasury.id).eq("updated_at", command.treasury.updatedAt)
      .select("id, company_id, project_id, code, name, type, gl_account_id, status, bank_name, account_reference, notes, created_at, created_by, updated_at, updated_by");
    if (error) return { ok: false, error: error.code === "42501" ? "denied" : ["23514", "23502", "22P02"].includes(error.code) ? "invalid" : "uncertain" };
    if (!data?.length) return { ok: false, error: "conflict" };
    if (data.length !== 1 || data[0].company_id !== activeCompanyId || data[0].id !== command.treasury.id || typeof data[0].updated_at !== "string" || !data[0].updated_at) return { ok: false, error: "uncertain" };
    return { ok: true, treasury: mapTreasuryAccountRow(data[0]) };
  } catch { return { ok: false, error: "uncertain" }; }
}
