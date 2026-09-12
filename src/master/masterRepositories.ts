import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import type {
  MasterDataQueryError,
  ProductionCompanyProfile,
  ProductionProjectSummary,
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
