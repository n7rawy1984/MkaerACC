import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { mapExpenseCategoryRow } from "./masterRepositories";
import type { ProductionExpenseCategory } from "./masterTypes";

export interface ExpenseCategoryInput { code: string; name: string; description: string | null; }
export type ExpenseCategoryCommand =
  | { kind: "create"; input: ExpenseCategoryInput }
  | { kind: "edit"; category: ProductionExpenseCategory; input: ExpenseCategoryInput }
  | { kind: "status"; category: ProductionExpenseCategory; status: "ACTIVE" | "INACTIVE" };
export type CategoryMutationError = "invalid" | "duplicate" | "denied" | "conflict" | "uncertain";
export type CategoryMutationResult = { ok: true; category: ProductionExpenseCategory } | { ok: false; error: CategoryMutationError };
const columns = "id, company_id, code, name, description, status, created_at, created_by, updated_at, updated_by";

// Match PostgreSQL btrim(text)'s space trimming; lengths count Unicode characters.
export function normalizeExpenseCategory(input: ExpenseCategoryInput): ExpenseCategoryInput | null {
  const trim = (value: string) => value.replace(/^ +| +$/g, "");
  if (typeof input.code !== "string" || typeof input.name !== "string"
    || (input.description !== null && typeof input.description !== "string")) return null;
  const code = trim(input.code), name = trim(input.name);
  if (![...code].length || [...code].length > 50 || ![...name].length || [...name].length > 200) return null;
  return { code, name, description: input.description === null ? null : trim(input.description) || null };
}

export async function mutateExpenseCategory(client: SupabaseClient<Database>, activeCompanyId: string, command: ExpenseCategoryCommand): Promise<CategoryMutationResult> {
  if (command.kind !== "create" && (command.category.companyId !== activeCompanyId || !command.category.updatedAt)) return { ok: false, error: "denied" };
  const input = command.kind === "status" ? null : normalizeExpenseCategory(command.input);
  if (command.kind !== "status" && !input) return { ok: false, error: "invalid" };
  if (command.kind === "status" && command.status !== "ACTIVE" && command.status !== "INACTIVE") return { ok: false, error: "invalid" };
  try {
    const query = command.kind === "create"
      ? client.from("expense_categories").insert({ company_id: activeCompanyId, code: input!.code, name: input!.name, description: input!.description })
      : client.from("expense_categories").update(command.kind === "status"
        ? { status: command.status }
        : { code: input!.code, name: input!.name, description: input!.description })
        .eq("company_id", activeCompanyId).eq("id", command.category.id).eq("updated_at", command.category.updatedAt);
    const { data, error } = await query.select(columns);
    if (error) return { ok: false, error: error.code === "23505" ? "duplicate" : error.code === "42501" ? "denied" : ["23514", "23502", "22P02", "22001"].includes(error.code) ? "invalid" : "uncertain" };
    if (!data?.length) return { ok: false, error: command.kind === "create" ? "uncertain" : "conflict" };
    if (data.length !== 1 || data[0].company_id !== activeCompanyId || !data[0].id
      || typeof data[0].updated_at !== "string" || !data[0].updated_at
      || (command.kind !== "create" && data[0].id !== command.category.id)) return { ok: false, error: "uncertain" };
    return { ok: true, category: mapExpenseCategoryRow(data[0]) };
  } catch {
    return { ok: false, error: "uncertain" };
  }
}
