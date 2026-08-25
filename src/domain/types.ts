// Core domain models for the Contracting Accounting Control System.
// These types are storage-agnostic and UI-agnostic on purpose so the
// persistence layer (localStorage today, Supabase/Postgres later) and the
// posting engine can evolve independently of the React layer.

export type ID = string;

export type ProjectStatus = "PLANNING" | "ACTIVE" | "ON_HOLD" | "COMPLETED" | "CLOSED";

export type CompanyStatus = "ACTIVE" | "INACTIVE";

export interface Company {
  id: ID;
  code: string;
  name: string;
  legalName?: string;
  trn?: string;
  address?: string;
  status: CompanyStatus;
  notes?: string;
  createdAt: string;
  updatedAt: string;
}

export interface Project {
  id: ID;
  code: string;
  name: string;
  companyId: ID;
  status: ProjectStatus;
  location?: string;
  client?: string;
  contractNumber?: string;
  originalContractValue?: number;
  startDate?: string;
  expectedCompletionDate?: string;
  budget?: number;
  notes?: string;
  /** Optional dedicated treasury accounts for this project — see TreasuryAccount. Most
   * projects have neither; funding still flows through the company's shared treasury. */
  dedicatedBankAccountId?: ID;
  dedicatedCashBoxId?: ID;
  createdAt: string;
  updatedAt: string;
}

// ============================================================================
// PHASE 2B.1 — Treasury Foundation
// ============================================================================

export type TreasuryAccountType = "CASH" | "PETTY_CASH" | "BANK" | "PROJECT_CASH_BOX" | "PROJECT_BANK";
export type TreasuryAccountStatus = "ACTIVE" | "INACTIVE";

/**
 * A named, selectable funding source (Main Cash, Petty Cash, Main Bank, or a
 * project-specific box/account). Every treasury account maps to one of the
 * existing pooled GL control accounts (Cash or Bank) via glAccountId — this
 * phase introduces treasury accounts as real master data and as the funding
 * source for custodian advances, without splitting the chart of accounts
 * into one GL account per treasury account (see accounting/chartOfAccounts.ts).
 */
export interface TreasuryAccount {
  id: ID;
  companyId: ID;
  projectId?: ID;
  code: string;
  name: string;
  type: TreasuryAccountType;
  glAccountId: ID;
  status: TreasuryAccountStatus;
  bankName?: string;
  accountReference?: string;
  notes?: string;
  createdAt: string;
  updatedAt: string;
}

export type PartyType =
  | "OWNER"
  | "CUSTODIAN"
  | "SUPPLIER"
  | "EMPLOYEE"
  | "SUBCONTRACTOR"
  | "OTHER";

export type PartyStatus = "ACTIVE" | "INACTIVE";

export interface Party {
  id: ID;
  code?: string;
  name: string;
  type: PartyType;
  phone?: string;
  email?: string;
  address?: string;
  taxRegistrationNumber?: string;
  contactPerson?: string;
  notes?: string;
  /** Phase 2B.2 — optional; undefined is treated as ACTIVE (backward-compatible default) for
   * every pre-existing party record. Only Subcontractors currently expose editable status in the
   * UI (an inactive subcontractor keeps full accounting history but cannot be selected for a new
   * subcontract), but the field is generic on Party rather than duplicated per type. */
  status?: PartyStatus;
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

/** CASH/BANK are legacy values (Phase 2B.1A no longer produces them from the Expense form —
 * see TREASURY) kept only so historical ExpenseTransaction records remain valid and readable. */
export type PaidFromType = "CUSTODIAN" | "OWNER" | "TREASURY" | "CASH" | "BANK" | "SUPPLIER_CREDIT";

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
  /** Set only when paidFromType is TREASURY — the specific TreasuryAccount used. */
  treasuryAccountId?: ID;
  /** Optional link to the specific AdvanceTransaction this custodian spend draws down. Purely
   * informational — the custodian's balance is always the pooled total, never per-advance. */
  advanceId?: ID;
  paymentMethod: PaymentMethod;
  hasInvoice: boolean;
  notes?: string;
  status: ExpenseStatus;
}

/** Where a custodian advance's cash actually came from — a treasury account
 * (company/project cash or bank) or an owner's personal funds (owner current
 * account). This is the "Funding Source" concept from Phase 2B.1: it is
 * always distinct from the Project dimension, which only records which job
 * the advance was given for, never where the GL money physically sits. */
export type AdvanceFundingSourceType = "TREASURY" | "OWNER_CURRENT";

export interface AdvanceTransaction {
  id: ID;
  date: string;
  custodianId: ID;
  amount: number;
  projectId?: ID;
  fundingSourceType: AdvanceFundingSourceType;
  /** TreasuryAccount id when fundingSourceType is TREASURY, Party (OWNER) id when OWNER_CURRENT. */
  fundingSourceId: ID;
  paymentMethod: PaymentMethod;
  reference?: string;
  notes?: string;
}

/** CASH/BANK are legacy values, kept only for historical records — see TREASURY. */
export type SupplierPaymentSourceType = "TREASURY" | "CUSTODIAN" | "OWNER" | "CASH" | "BANK";

export interface SupplierPaymentTransaction {
  id: ID;
  date: string;
  supplierId: ID;
  amount: number;
  sourceType: SupplierPaymentSourceType;
  sourcePartyId?: ID;
  /** Set only when sourceType is TREASURY — the specific TreasuryAccount used. */
  treasuryAccountId?: ID;
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
  /** Phase 2B.2 — the Subcontract (contract) this line belongs to, when applicable. Additive
   * dimension alongside partyId/projectId so subcontractor payable/retention/advance balances can
   * be scoped per contract, not just per subcontractor party — see accounting/ledger.ts. Absent on
   * every non-subcontractor line, and on subcontractor-related lines whose historical contract
   * could not be determined with certainty during migration ("legacy party-scoped activity"). */
  contractId?: ID;
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
/** CASH/BANK are legacy values, kept only for historical/finalized records — see TREASURY. */
export type CashReturnDestinationType = "TREASURY" | "OWNER" | "CASH" | "BANK";

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
  /** Set only when cashReturnDestinationType is TREASURY — the specific TreasuryAccount used. */
  cashReturnTreasuryAccountId?: ID;
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

/** CASH/BANK are legacy values, kept only for historical records — see TREASURY. */
export type SubcontractorFundingSourceType = "TREASURY" | "OWNER" | "CUSTODIAN" | "CASH" | "BANK";

/** An advance to a subcontractor is an asset (recoverable through future
 * certificates) — it is never project cost until a certificate recovers it. */
export interface SubcontractorAdvance {
  id: ID;
  contractId: ID;
  date: string;
  amount: number;
  paymentSourceType: SubcontractorFundingSourceType;
  paymentSourcePartyId?: ID;
  /** Set only when paymentSourceType is TREASURY — the specific TreasuryAccount used. */
  treasuryAccountId?: ID;
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

/** CASH/BANK are legacy values, kept only for historical records — see TREASURY. */
export type SubcontractorPaymentSourceType = "TREASURY" | "CUSTODIAN" | "OWNER" | "CASH" | "BANK";

/** Payments are scoped to one certificate (not pooled per subcontractor) so
 * that certificate payment status (PARTIALLY_PAID / PAID) can be tracked. */
export interface SubcontractorPaymentTransaction {
  id: ID;
  date: string;
  subcontractorId: ID;
  certificateId: ID;
  /** Phase 2B.2 — derived from the certificate's contract at creation time (contractId is
   * immutable on a certificate, so this is a safe denormalization for contract-scoped display and
   * journal-line tagging). Optional only so pre-2B.2 historical records without a known contract
   * link stay valid — backfilled deterministically wherever possible, see storage/migrations.ts. */
  contractId?: ID;
  amount: number;
  sourceType: SubcontractorPaymentSourceType;
  sourcePartyId?: ID;
  /** Set only when sourceType is TREASURY — the specific TreasuryAccount used. */
  treasuryAccountId?: ID;
  reference?: string;
  notes?: string;
}
