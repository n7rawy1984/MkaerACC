import type { Database } from "../types/database.generated";

export type ProductionCompanyStatus = Database["public"]["Enums"]["account_status"];
export type ProductionProjectStatus = Database["public"]["Enums"]["project_status"];

export interface ProductionCompanyProfile {
  id: string;
  code: string;
  name: string;
  legalName: string | null;
  trn: string | null;
  address: string | null;
  notes: string | null;
  status: ProductionCompanyStatus;
  createdAt: string;
  createdBy: string | null;
  updatedAt: string;
  updatedBy: string | null;
}

export interface ProductionProjectSummary {
  id: string;
  companyId: string;
  code: string;
  name: string;
  clientName: string | null;
  location: string | null;
  contractNumber: string | null;
  startDate: string | null;
  expectedCompletionDate: string | null;
  status: ProductionProjectStatus;
  createdAt: string;
  createdBy: string | null;
  updatedAt: string;
  updatedBy: string | null;
}

export interface MasterDataQueryError {
  source: "company" | "projects" | "session";
  code: string | null;
  message: string;
}

export type ProductionMasterDataState =
  | { phase: "LOADING" }
  | { phase: "MISSING_COMPANY" }
  | { phase: "ERROR"; error: MasterDataQueryError }
  | { phase: "READY"; company: ProductionCompanyProfile; projects: ProductionProjectSummary[] };
