import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { mapAccountRow } from "./masterRepositories";
import type { ProductionAccount } from "./masterTypes";

export interface AccountNameInput {
  name: string;
}
export interface AccountNameCommand { account: ProductionAccount; input: AccountNameInput; }
export type AccountNameMutationError = "invalid" | "denied" | "conflict" | "uncertain";
export type AccountNameMutationResult = { ok: true; account: ProductionAccount } | { ok: false; error: AccountNameMutationError };
export function normalizeAccountName(input: AccountNameInput): AccountNameInput | null {
  if (!input || typeof input.name !== "string") return null;
  const name = input.name.trim();
  if (!name || [...name].length > 200) return null;
  return { name };
}
export async function updateAccountName(client: SupabaseClient<Database>, activeCompanyId: string, command: AccountNameCommand): Promise<AccountNameMutationResult> {
  if (command.account.companyId !== activeCompanyId || !command.account.id || !command.account.updatedAt) return { ok: false, error: "denied" };
  const input = normalizeAccountName(command.input);
  if (!input) return { ok: false, error: "invalid" };
  try {
    const { data, error } = await client.from("accounts").update(input)
      .eq("company_id", activeCompanyId).eq("id", command.account.id).eq("updated_at", command.account.updatedAt)
      .select("id, company_id, code, name, account_type, parent_account_id, requires_party, system_key, status, created_at, created_by, updated_at, updated_by");
    if (error) return { ok: false, error: error.code === "42501" ? "denied" : ["23514", "23502", "22P02"].includes(error.code) ? "invalid" : "uncertain" };
    if (!data?.length) return { ok: false, error: "conflict" };
    if (data.length !== 1 || data[0].company_id !== activeCompanyId || data[0].id !== command.account.id || typeof data[0].updated_at !== "string" || !data[0].updated_at) return { ok: false, error: "uncertain" };
    return { ok: true, account: mapAccountRow(data[0]) };
  } catch { return { ok: false, error: "uncertain" }; }
}
