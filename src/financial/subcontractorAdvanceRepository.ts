import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";

export interface SubcontractorAdvanceRead {
  id: string; company_id: string; advance_reference: string; advance_date: string;
  project_id: string; subcontractor_id: string; subcontract_id: string; treasury_account_id: string;
  amount_minor: string; payment_method: Database["public"]["Enums"]["payment_method"];
  external_reference: string | null; notes: string | null; status: "DRAFT" | "POSTED" | "REVERSED";
  posted_journal_entry_id: string | null; reversal_journal_entry_id: string | null;
  created_at: string; created_by: string; posted_at: string | null; posted_by: string | null;
  reversed_at: string | null; reversed_by: string | null;
}
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const projection = "id,company_id,advance_reference,advance_date,project_id,subcontractor_id,subcontract_id,treasury_account_id,amount_minor::text,payment_method,external_reference,notes,status,posted_journal_entry_id,reversal_journal_entry_id,created_at,created_by,posted_at,posted_by,reversed_at,reversed_by";
function map(row: any): SubcontractorAdvanceRead {
  if (!uuid.test(row.id) || !uuid.test(row.company_id) || !uuid.test(row.project_id) || !uuid.test(row.subcontractor_id)
    || !uuid.test(row.subcontract_id) || !uuid.test(row.treasury_account_id) || typeof row.amount_minor !== "string"
    || !/^\d+$/.test(row.amount_minor) || BigInt(row.amount_minor) > 9000000000000000n
    || !["DRAFT", "POSTED", "REVERSED"].includes(row.status)) throw new Error("Invalid Subcontractor Advance row");
  return row as SubcontractorAdvanceRead;
}
export const canReadSubcontractorAdvances = (role: string) => role === "ACCOUNTING_ADMIN" || role === "ACCOUNTANT" || role === "MANAGEMENT_VIEWER";
export async function readSubcontractorAdvances(client: SupabaseClient<Database>, companyId: string): Promise<SubcontractorAdvanceRead[]> {
  if (!uuid.test(companyId)) throw new Error("Invalid Subcontractor Advance scope"); const rows: SubcontractorAdvanceRead[] = [];
  for (let from = 0; ; from += 500) { const { data, error } = await client.from("subcontractor_advances").select(projection).eq("company_id", companyId)
      .order("advance_date", { ascending: false }).order("id", { ascending: true }).range(from, from + 499);
    if (error || !data) throw new Error("Subcontractor Advance read unavailable");
    for (const row of data) { if (row.company_id !== companyId) throw new Error("Invalid Subcontractor Advance scope"); rows.push(map(row)); }
    if (data.length < 500) return rows;
  }
}
export async function readSubcontractorAdvanceById(client: SupabaseClient<Database>, companyId: string, advanceId: string): Promise<SubcontractorAdvanceRead> {
  if (!uuid.test(companyId) || !uuid.test(advanceId)) throw new Error("Invalid Subcontractor Advance scope");
  const { data, error } = await client.from("subcontractor_advances").select(projection).eq("company_id", companyId).eq("id", advanceId).maybeSingle();
  if (error || !data || data.company_id !== companyId || data.id !== advanceId) throw new Error("Subcontractor Advance readback unavailable"); return map(data);
}
