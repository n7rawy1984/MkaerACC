import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import type {
  MasterDataQueryError,
  ProductionCompanyProfile,
  ProductionProjectSummary,
  ProductionParty,
  ProductionExpenseCategory,
  ProductionAccount,
  ProductionTreasuryAccount,
} from "./masterTypes";

type CompanyRow = Database["public"]["Tables"]["companies"]["Row"];
type ProjectRow = Database["public"]["Tables"]["projects"]["Row"];

export function mapCompanyRow(row: CompanyRow): ProductionCompanyProfile {
  return {
    id: row.id,
    code: row.code,
    name: row.name,
    legalName: row.legal_name,
    trn: row.trn,
    address: row.address,
    notes: row.notes,
    status: row.status,
    createdAt: row.created_at,
    createdBy: row.created_by,
    updatedAt: row.updated_at,
    updatedBy: row.updated_by,
  };
}

export function mapProjectRow(row: Pick<ProjectRow,
  "id" | "company_id" | "code" | "name" | "client_name" | "location" |
  "contract_number" | "start_date" | "expected_completion_date" | "status" |
  "created_at" | "created_by" | "updated_at" | "updated_by"
>): ProductionProjectSummary {
  return {
    id: row.id,
    companyId: row.company_id,
    code: row.code,
    name: row.name,
    clientName: row.client_name,
    location: row.location,
    contractNumber: row.contract_number,
    startDate: row.start_date,
    expectedCompletionDate: row.expected_completion_date,
    status: row.status,
    createdAt: row.created_at,
    createdBy: row.created_by,
    updatedAt: row.updated_at,
    updatedBy: row.updated_by,
  };
}

function queryError(source: MasterDataQueryError["source"], error: { code?: string; message?: string }): MasterDataQueryError {
  return {
    source,
    code: error.code ?? null,
    message: error.message ?? "The protected master-data query failed.",
  };
}

export type RepositoryResult<T> = { ok: true; data: T } | { ok: false; error: MasterDataQueryError };

export async function readActiveCompanyProfile(
  client: SupabaseClient<Database>,
  activeCompanyId: string,
): Promise<RepositoryResult<ProductionCompanyProfile | null>> {
  const { data, error } = await client
    .from("companies")
    .select("id, code, name, legal_name, trn, address, notes, status, created_at, created_by, updated_at, updated_by")
    .eq("id", activeCompanyId)
    .maybeSingle();
  if (error) return { ok: false, error: queryError("company", error) };
  if (!data || data.id !== activeCompanyId) return { ok: true, data: null };
  return { ok: true, data: mapCompanyRow(data) };
}

export async function readActiveCompanyProjects(
  client: SupabaseClient<Database>,
  activeCompanyId: string,
): Promise<RepositoryResult<ProductionProjectSummary[]>> {
  const { data, error } = await client
    .from("projects")
    .select("id, company_id, code, name, client_name, location, contract_number, start_date, expected_completion_date, status, created_at, created_by, updated_at, updated_by")
    .eq("company_id", activeCompanyId)
    .order("code", { ascending: true });
  if (error) return { ok: false, error: queryError("projects", error) };
  return {
    ok: true,
    data: (data ?? []).filter((row) => row.company_id === activeCompanyId).map(mapProjectRow),
  };
}

export function mapPartyRow(row: Database["public"]["Tables"]["parties"]["Row"]): ProductionParty {
  return {
    id: row.id,
    companyId: row.company_id,
    type: row.type,
    name: row.name,
    code: row.code,
    taxRegistrationNumber: row.trn,
    contactPerson: row.contact_person,
    phone: row.phone,
    email: row.email,
    address: row.address,
    status: row.status,
    notes: row.notes,
    createdAt: row.created_at,
    createdBy: row.created_by,
    updatedAt: row.updated_at,
    updatedBy: row.updated_by,
  };
}

export function mapExpenseCategoryRow(row: Database["public"]["Tables"]["expense_categories"]["Row"]): ProductionExpenseCategory {
  return {
    id: row.id,
    companyId: row.company_id,
    code: row.code,
    name: row.name,
    description: row.description,
    status: row.status,
    createdAt: row.created_at,
    createdBy: row.created_by,
    updatedAt: row.updated_at,
    updatedBy: row.updated_by,
  };
}

export async function readActiveCompanyParties(
  client: SupabaseClient<Database>,
  activeCompanyId: string,
): Promise<RepositoryResult<ProductionParty[]>> {
  const { data, error } = await client
    .from("parties")
    .select("id, company_id, type, name, code, trn, contact_person, phone, email, address, status, notes, created_at, created_by, updated_at, updated_by")
    .eq("company_id", activeCompanyId)
    .order("name", { ascending: true })
    .order("id", { ascending: true });
  if (error) return { ok: false, error: queryError("parties", error) };
  // RLS-filtered subsets (including zero rows) are authoritative and valid.
  return { ok: true, data: (data ?? []).filter((row) => row.company_id === activeCompanyId).map(mapPartyRow) };
}

export async function readActiveCompanyExpenseCategories(
  client: SupabaseClient<Database>,
  activeCompanyId: string,
): Promise<RepositoryResult<ProductionExpenseCategory[]>> {
  const { data, error } = await client
    .from("expense_categories")
    .select("id, company_id, code, name, description, status, created_at, created_by, updated_at, updated_by")
    .eq("company_id", activeCompanyId)
    .order("code", { ascending: true })
    .order("id", { ascending: true });
  if (error) return { ok: false, error: queryError("expenseCategories", error) };
  return { ok: true, data: (data ?? []).filter((row) => row.company_id === activeCompanyId).map(mapExpenseCategoryRow) };
}

export function mapAccountRow(row: Database["public"]["Tables"]["accounts"]["Row"]): ProductionAccount {
  return {
    id: row.id,
    companyId: row.company_id,
    code: row.code,
    name: row.name,
    accountType: row.account_type,
    parentAccountId: row.parent_account_id,
    requiresParty: row.requires_party,
    systemKey: row.system_key,
    status: row.status,
    createdAt: row.created_at,
    createdBy: row.created_by,
    updatedAt: row.updated_at,
    updatedBy: row.updated_by,
  };
}

export async function readActiveCompanyAccounts(
  client: SupabaseClient<Database>,
  activeCompanyId: string,
): Promise<RepositoryResult<ProductionAccount[]>> {
  const { data, error } = await client
    .from("accounts")
    .select("id, company_id, code, name, account_type, parent_account_id, requires_party, system_key, status, created_at, created_by, updated_at, updated_by")
    .eq("company_id", activeCompanyId)
    .order("code", { ascending: true })
    .order("id", { ascending: true });
  if (error) return { ok: false, error: queryError("accounts", error) };
  return { ok: true, data: (data ?? []).filter((row) => row.company_id === activeCompanyId).map(mapAccountRow) };
}

export function mapTreasuryAccountRow(row: Database["public"]["Tables"]["treasury_accounts"]["Row"]): ProductionTreasuryAccount {
  return {
    id: row.id,
    companyId: row.company_id,
    code: row.code,
    name: row.name,
    projectId: row.project_id,
    type: row.type,
    glAccountId: row.gl_account_id,
    bankName: row.bank_name,
    accountReference: row.account_reference,
    notes: row.notes,
    status: row.status,
    createdAt: row.created_at,
    createdBy: row.created_by,
    updatedAt: row.updated_at,
    updatedBy: row.updated_by,
  };
}

export async function readActiveCompanyTreasuryAccounts(
  client: SupabaseClient<Database>,
  activeCompanyId: string,
): Promise<RepositoryResult<ProductionTreasuryAccount[]>> {
  const { data, error } = await client
    .from("treasury_accounts")
    .select("id, company_id, code, name, project_id, type, gl_account_id, bank_name, account_reference, notes, status, created_at, created_by, updated_at, updated_by")
    .eq("company_id", activeCompanyId)
    .order("code", { ascending: true })
    .order("id", { ascending: true });
  if (error) return { ok: false, error: queryError("treasuryAccounts", error) };
  return { ok: true, data: (data ?? []).filter((row) => row.company_id === activeCompanyId).map(mapTreasuryAccountRow) };
}
