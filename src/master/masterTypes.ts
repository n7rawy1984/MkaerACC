import type { OtherPartyNameCommand, OtherPartyNameMutationError } from "./otherPartyNameMutations";
import type { EmployeePartyNameCommand, EmployeePartyNameMutationError } from "./employeePartyNameMutations";
import type { CustodianPartyNameCommand, CustodianPartyNameMutationError } from "./custodianPartyNameMutations";
import type { OwnerPartyNameCommand, OwnerPartyNameMutationError } from "./ownerPartyNameMutations";
import type { SubcontractorPartyNameCommand, SubcontractorPartyNameMutationError } from "./subcontractorPartyNameMutations";
import type { TreasuryNameCommand, TreasuryNameMutationError } from "./treasuryNameMutations";
import type { AccountNameCommand, AccountNameMutationError } from "./accountNameMutations";
import type { ProjectMetadataCommand, ProjectMetadataMutationError } from "./projectMetadataMutations";
import type { CompanyProfileCommand, CompanyProfileMutationError } from "./companyProfileMutations";
import type { SupplierMutationError, SupplierPartyCommand } from "./supplierPartyMutations";
import type { Database } from "../types/database.generated";
import type { CategoryMutationError, ExpenseCategoryCommand } from "./expenseCategoryMutations";
import type { SubcontractMetadataCommand, SubcontractMetadataMutationError } from "./subcontractMetadataMutations";

export interface CategoryActions {
  categoryMutation: { phase: "IDLE" | "PENDING" | "SAVED" | "ERROR" | "REFRESH_ERROR"; error?: CategoryMutationError };
  saveExpenseCategory: (command: ExpenseCategoryCommand) => Promise<boolean>;
  refreshExpenseCategories: () => Promise<boolean>;
}
export interface SupplierActions {
  supplierMutation: { phase: "IDLE" | "PENDING" | "SAVED" | "ERROR" | "REFRESH_ERROR"; error?: SupplierMutationError };
  saveSupplierParty: (command: SupplierPartyCommand) => Promise<boolean>;
  refreshParties: () => Promise<boolean>;
}
export interface CompanyProfileActions {
  companyProfileMutation: { phase: "IDLE" | "PENDING" | "SAVED" | "ERROR" | "REFRESH_ERROR"; error?: CompanyProfileMutationError };
  saveCompanyProfile: (command: CompanyProfileCommand) => Promise<boolean>;
  refreshCompanyProfile: () => Promise<boolean>;
}
export interface ProjectMetadataActions {
  projectMetadataMutation: { phase: "IDLE" | "PENDING" | "SAVED" | "ERROR" | "REFRESH_ERROR"; error?: ProjectMetadataMutationError };
  saveProjectMetadata: (command: ProjectMetadataCommand) => Promise<boolean>;
  refreshProjects: () => Promise<boolean>;
}
export interface AccountNameActions {
  accountNameMutation: { phase: "IDLE" | "PENDING" | "SAVED" | "ERROR" | "REFRESH_ERROR"; error?: AccountNameMutationError };
  saveAccountName: (command: AccountNameCommand) => Promise<boolean>;
  refreshAccounts: () => Promise<boolean>;
}
export interface TreasuryNameActions {
  treasuryNameMutation: { phase: "IDLE" | "PENDING" | "SAVED" | "ERROR" | "REFRESH_ERROR"; error?: TreasuryNameMutationError };
  saveTreasuryName: (command: TreasuryNameCommand) => Promise<boolean>;
  refreshTreasuryAccounts: () => Promise<boolean>;
}
export interface OtherPartyNameActions {
  otherPartyNameMutation: { phase: "IDLE" | "PENDING" | "SAVED" | "ERROR" | "REFRESH_ERROR"; error?: OtherPartyNameMutationError };
  saveOtherPartyName: (command: OtherPartyNameCommand) => Promise<boolean>;
  refreshOtherPartyNames: () => Promise<boolean>;
}
export interface EmployeePartyNameActions {
  employeePartyNameMutation: { phase: "IDLE" | "PENDING" | "SAVED" | "ERROR" | "REFRESH_ERROR"; error?: EmployeePartyNameMutationError };
  saveEmployeePartyName: (command: EmployeePartyNameCommand) => Promise<boolean>;
  refreshEmployeePartyNames: () => Promise<boolean>;
}
export interface CustodianPartyNameActions {
  custodianPartyNameMutation: { phase: "IDLE" | "PENDING" | "SAVED" | "ERROR" | "REFRESH_ERROR"; error?: CustodianPartyNameMutationError };
  saveCustodianPartyName: (command: CustodianPartyNameCommand) => Promise<boolean>;
  refreshCustodianPartyNames: () => Promise<boolean>;
}
export interface OwnerPartyNameActions {
  ownerPartyNameMutation: { phase: "IDLE" | "PENDING" | "SAVED" | "ERROR" | "REFRESH_ERROR"; error?: OwnerPartyNameMutationError };
  saveOwnerPartyName: (command: OwnerPartyNameCommand) => Promise<boolean>;
  refreshOwnerPartyNames: () => Promise<boolean>;
}
export interface SubcontractorPartyNameActions {
  subcontractorPartyNameMutation: { phase: "IDLE" | "PENDING" | "SAVED" | "ERROR" | "REFRESH_ERROR"; error?: SubcontractorPartyNameMutationError };
  saveSubcontractorPartyName: (command: SubcontractorPartyNameCommand) => Promise<boolean>;
  refreshSubcontractorPartyNames: () => Promise<boolean>;
}
export interface SubcontractMetadataActions {
  subcontractMetadataMutation: { phase: "IDLE" | "PENDING" | "SAVED" | "ERROR" | "REFRESH_ERROR"; error?: SubcontractMetadataMutationError };
  saveSubcontractMetadata: (command: SubcontractMetadataCommand) => Promise<boolean>;
  refreshSubcontracts: () => Promise<boolean>;
}
export type ProductionMasterDataContextValue = ProductionMasterDataState & CategoryActions & SupplierActions & CompanyProfileActions & ProjectMetadataActions & AccountNameActions & TreasuryNameActions & OtherPartyNameActions & EmployeePartyNameActions & CustodianPartyNameActions & OwnerPartyNameActions & SubcontractorPartyNameActions & SubcontractMetadataActions;

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
  notes: string | null;
  startDate: string | null;
  expectedCompletionDate: string | null;
  status: ProductionProjectStatus;
  createdAt: string;
  createdBy: string | null;
  updatedAt: string;
  updatedBy: string | null;
}

export interface ProductionParty {
  id: string;
  companyId: string;
  type: Database["public"]["Enums"]["party_type"];
  name: string;
  code: string | null;
  taxRegistrationNumber: string | null;
  contactPerson: string | null;
  phone: string | null;
  email: string | null;
  address: string | null;
  status: Database["public"]["Enums"]["account_status"];
  notes: string | null;
  createdAt: string;
  createdBy: string | null;
  updatedAt: string;
  updatedBy: string | null;
}

export interface ProductionExpenseCategory {
  id: string;
  companyId: string;
  code: string;
  name: string;
  description: string | null;
  status: Database["public"]["Enums"]["account_status"];
  createdAt: string;
  createdBy: string | null;
  updatedAt: string;
  updatedBy: string | null;
}

export interface ProductionAccount {
  id: string;
  companyId: string;
  code: string;
  name: string;
  accountType: Database["public"]["Enums"]["account_type"];
  parentAccountId: string | null;
  requiresParty: boolean;
  status: Database["public"]["Enums"]["account_status"];
  systemKey: Database["public"]["Enums"]["system_account_key"] | null;
  createdAt: string;
  createdBy: string | null;
  updatedAt: string;
  updatedBy: string | null;
}

export interface ProductionTreasuryAccount {
  id: string;
  companyId: string;
  projectId: string | null;
  code: string;
  name: string;
  type: Database["public"]["Enums"]["treasury_account_type"];
  glAccountId: string;
  status: Database["public"]["Enums"]["account_status"];
  bankName: string | null;
  accountReference: string | null;
  notes: string | null;
  createdAt: string;
  createdBy: string | null;
  updatedAt: string;
  updatedBy: string | null;
}

export interface ProductionSubcontract {
  id: string;
  companyId: string;
  projectId: string;
  subcontractorId: string;
  contractNumber: string;
  scopeOfWork: string;
  // Exact decimal strings from server-side BIGINT-to-text projections.
  originalContractValueMinor: string;
  approvedVariationsMinor: string;
  retentionBps: number;
  startDate: string | null;
  expectedEndDate: string | null;
  status: Database["public"]["Enums"]["subcontract_status"];
  notes: string | null;
  createdAt: string;
  createdBy: string | null;
  updatedAt: string;
  updatedBy: string | null;
}

export interface MasterDataQueryError {
  source: "company" | "projects" | "parties" | "expenseCategories" | "accounts" | "treasuryAccounts" | "subcontracts" | "session";
  code: string | null;
  message: string;
}

export type ProductionMasterDataState =
  | { phase: "LOADING" }
  | { phase: "MISSING_COMPANY" }
  | { phase: "ERROR"; error: MasterDataQueryError }
  | { phase: "READY"; company: ProductionCompanyProfile; projects: ProductionProjectSummary[]; parties: ProductionParty[]; expenseCategories: ProductionExpenseCategory[]; accounts: ProductionAccount[]; treasuryAccounts: ProductionTreasuryAccount[]; subcontracts: ProductionSubcontract[] };
