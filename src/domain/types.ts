// Core domain models for the Contracting Accounting Control System.
// These types are storage-agnostic and UI-agnostic on purpose so the
// persistence layer (localStorage today, Supabase/Postgres later) and the
// posting engine can evolve independently of the React layer.

export type ID = string;

export type ProjectStatus = "ACTIVE" | "ON_HOLD" | "COMPLETED" | "CANCELLED";

export interface Company {
  id: ID;
  name: string;
  trn?: string;
  address?: string;
}

export interface Project {
  id: ID;
  code: string;
  name: string;
  status: ProjectStatus;
  location?: string;
  client?: string;
  startDate: string;
  budget?: number;
  notes?: string;
}

export type PartyType =
  | "OWNER"
  | "CUSTODIAN"
  | "SUPPLIER"
  | "EMPLOYEE"
  | "SUBCONTRACTOR"
  | "OTHER";

export interface Party {
  id: ID;
  name: string;
  type: PartyType;
  phone?: string;
  taxRegistrationNumber?: string;
  contactPerson?: string;
  notes?: string;
}

export interface ExpenseCategory {
  id: ID;
  name: string;
  code: string;
}

export type AccountType = "ASSET" | "LIABILITY" | "EQUITY" | "INCOME" | "EXPENSE";

// Some accounts are "control accounts" — their real balance is held per
// party (e.g. Accounts Payable is one account, but every supplier needs its
// own sub-balance). requiresParty marks that.
export interface Account {
  id: ID;
  code: string;
  name: string;
  type: AccountType;
  parentId?: ID;
  requiresParty?: boolean;
}

export type PaidFromType = "CUSTODIAN" | "OWNER" | "CASH" | "BANK" | "SUPPLIER_CREDIT";

export type PaymentMethod = "CASH" | "BANK" | "TRANSFER" | "CHEQUE" | "OTHER";

export type VatMode = "ZERO" | "MANUAL" | "AUTO_5";

export type ExpenseStatus = "POSTED" | "VOID";

export interface ExpenseTransaction {
  id: ID;
  date: string;
  projectId?: ID;
  supplierId?: ID;
  categoryId: ID;
  description: string;
  invoiceNumber?: string;
  netAmount: number;
  vatAmount: number;
  totalAmount: number;
  paidFromType: PaidFromType;
  paidFromPartyId?: ID;
  /** Optional link to the specific AdvanceTransaction this custodian spend draws down. Purely
   * informational — the custodian's balance is always the pooled total, never per-advance. */
  advanceId?: ID;
  paymentMethod: PaymentMethod;
  hasInvoice: boolean;
  notes?: string;
  status: ExpenseStatus;
}

export interface AdvanceTransaction {
  id: ID;
  date: string;
  fromPartyId: ID;
  custodianId: ID;
  amount: number;
  projectId?: ID;
  paymentMethod: PaymentMethod;
  reference?: string;
  notes?: string;
}

export type SupplierPaymentSourceType = "CASH" | "BANK" | "CUSTODIAN" | "OWNER";

export interface SupplierPaymentTransaction {
  id: ID;
  date: string;
  supplierId: ID;
  amount: number;
  sourceType: SupplierPaymentSourceType;
  sourcePartyId?: ID;
  reference?: string;
  notes?: string;
}

export type JournalSourceType =
  | "EXPENSE"
  | "ADVANCE"
  | "SUPPLIER_PAYMENT"
  | "CUSTODY_SETTLEMENT"
  | "SUBCONTRACTOR_ADVANCE"
  | "SUBCONTRACTOR_CERTIFICATE"
  | "SUBCONTRACTOR_PAYMENT"
  | "MANUAL";

export interface JournalLine {
  accountId: ID;
  debit: number;
  credit: number;
  projectId?: ID;
  partyId?: ID;
}

export interface JournalEntry {
  id: ID;
  date: string;
  reference: string;
  description: string;
  sourceType: JournalSourceType;
  sourceId: ID;
  lines: JournalLine[];
}

// ============================================================================
// PHASE 2A — Custody Settlements
// ============================================================================

export type SettlementStatus = "DRAFT" | "SETTLED";
export type CashReturnDestinationType = "CASH" | "BANK" | "OWNER";

/**
 * A settlement is a reconciliation/document grouping over expenses already
 * posted through the normal expense flow — it never re-posts them. Its only
 * accounting effect is the optional cash-return line (unused custody handed
 * back to the company or an owner).
 */
export interface CustodySettlement {
  id: ID;
  settlementNumber: string;
  settlementDate: string;
  custodianId: ID;
  projectId?: ID;
  notes?: string;
  status: SettlementStatus;
  selectedExpenseIds: ID[];
  cashReturnAmount: number;
  cashReturnDestinationType?: CashReturnDestinationType;
  cashReturnOwnerId?: ID;
  createdAt: string;
  settledAt?: string;
  /** Journal entry for the cash return, set only once, on finalization. */
  journalEntryId?: ID;
}

// ============================================================================
// PHASE 2A — Subcontractors
// ============================================================================

export type SubcontractStatus = "ACTIVE" | "COMPLETED" | "CLOSED";

export interface Subcontract {
  id: ID;
  projectId: ID;
  subcontractorId: ID;
  contractNumber: string;
  scopeOfWork: string;
  originalContractValue: number;
  approvedVariations: number;
  retentionPercent: number;
  startDate?: string;
  endDate?: string;
  status: SubcontractStatus;
  notes?: string;
}

export type SubcontractorFundingSourceType = "CASH" | "BANK" | "OWNER" | "CUSTODIAN";

/** An advance to a subcontractor is an asset (recoverable through future
 * certificates) — it is never project cost until a certificate recovers it. */
export interface SubcontractorAdvance {
  id: ID;
  contractId: ID;
  date: string;
  amount: number;
  paymentSourceType: SubcontractorFundingSourceType;
  paymentSourcePartyId?: ID;
  paymentMethod: PaymentMethod;
  reference?: string;
  notes?: string;
}

export type CertificateStatus = "DRAFT" | "APPROVED" | "PARTIALLY_PAID" | "PAID";

export type DeductionType = "COMPANY_MATERIALS" | "BACKCHARGE" | "OTHER";

/** Every deduction must be mapped to a real account before a certificate can
 * be approved — no generic silent reduction of project cost. */
export interface CertificateDeduction {
  id: ID;
  description: string;
  amount: number;
  type: DeductionType;
  accountId: ID;
}

export interface SubcontractorCertificate {
  id: ID;
  certificateNumber: string;
  certificateDate: string;
  contractId: ID;
  projectId: ID;
  subcontractorId: ID;

  workValueToDate: number;
  previousCertifiedWork: number;
  currentWorkValue: number;

  currentVariationAmount: number;

  grossCurrentValue: number;

  retentionPercent: number;
  retentionAmount: number;

  advanceRecovery: number;

  deductionLines: CertificateDeduction[];

  vatMode: VatMode;
  vatAmount: number;
  taxInvoiceReceived: boolean;
  taxInvoiceNumber?: string;
  taxInvoiceDate?: string;

  netBeforeVat: number;
  netPayable: number;

  notes?: string;
  status: CertificateStatus;

  journalEntryId?: ID;
  approvedAt?: string;
}

export type SubcontractorPaymentSourceType = "CASH" | "BANK" | "CUSTODIAN" | "OWNER";

/** Payments are scoped to one certificate (not pooled per subcontractor) so
 * that certificate payment status (PARTIALLY_PAID / PAID) can be tracked. */
export interface SubcontractorPaymentTransaction {
  id: ID;
  date: string;
  subcontractorId: ID;
  certificateId: ID;
  amount: number;
  sourceType: SubcontractorPaymentSourceType;
  sourcePartyId?: ID;
  reference?: string;
  notes?: string;
}
