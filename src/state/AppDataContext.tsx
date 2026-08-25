import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from "react";
import type {
  Account,
  AdvanceFundingSourceType,
  AdvanceTransaction,
  CashReturnDestinationType,
  CertificateDeduction,
  Company,
  CompanyStatus,
  CustodySettlement,
  ExpenseCategory,
  ExpenseTransaction,
  JournalEntry,
  Party,
  PartyStatus,
  Project,
  ProjectStatus,
  Subcontract,
  SubcontractorAdvance,
  SubcontractorCertificate,
  SubcontractorFundingSourceType,
  SubcontractorPaymentSourceType,
  SubcontractorPaymentTransaction,
  SubcontractStatus,
  SupplierPaymentTransaction,
  TreasuryAccount,
  TreasuryAccountStatus,
  TreasuryAccountType,
  VatMode,
} from "../domain/types";
import { addMoney, calcVat, formatAED, subtractMoney } from "../domain/money";
import { db, newId } from "../storage/database";
import { ensurePhase2ASeeded, ensureSeeded } from "../seed/seedData";
import { ensurePhase2B1Migrated, ensurePhase2B1AMigrated, ensurePhase2B2Migrated } from "../storage/migrations";
import { ACCOUNTS } from "../accounting/chartOfAccounts";
import {
  postAdvance,
  postCashReturn,
  postCertificateApproval,
  postExpense,
  postSubcontractorAdvance,
  postSubcontractorPayment,
  postSupplierPayment,
  type ResolvedFundingSource,
} from "../accounting/postingEngine";
import { calcCertificate, validateCertificate } from "../accounting/certificateCalc";
import {
  certificatePaidAmount,
  contractAdvanceBalance,
  contractCertifiedCost,
  custodianBalance,
} from "../accounting/ledger";

ensureSeeded();
ensurePhase2ASeeded();
ensurePhase2B1Migrated();
ensurePhase2B1AMigrated();
ensurePhase2B2Migrated();

interface AppData {
  companies: Company[];
  projects: Project[];
  parties: Party[];
  categories: ExpenseCategory[];
  accounts: Account[];
  expenses: ExpenseTransaction[];
  advances: AdvanceTransaction[];
  supplierPayments: SupplierPaymentTransaction[];
  journalEntries: JournalEntry[];
  custodySettlements: CustodySettlement[];
  subcontracts: Subcontract[];
  subcontractorAdvances: SubcontractorAdvance[];
  subcontractorCertificates: SubcontractorCertificate[];
  subcontractorPayments: SubcontractorPaymentTransaction[];
  treasuryAccounts: TreasuryAccount[];
}

export interface NewExpenseInput {
  date: string;
  projectId?: string;
  supplierId?: string;
  categoryId: string;
  description: string;
  invoiceNumber?: string;
  netAmount: number;
  vatMode: VatMode;
  manualVatAmount?: number;
  paidFromType: ExpenseTransaction["paidFromType"];
  paidFromPartyId?: string;
  treasuryAccountId?: string;
  advanceId?: string;
  paymentMethod: ExpenseTransaction["paymentMethod"];
  hasInvoice: boolean;
  notes?: string;
}

export interface NewAdvanceInput {
  date: string;
  custodianId: string;
  amount: number;
  projectId?: string;
  fundingSourceType: AdvanceFundingSourceType;
  fundingSourceId: string;
  paymentMethod: AdvanceTransaction["paymentMethod"];
  reference?: string;
  notes?: string;
}

export interface NewCompanyInput {
  code: string;
  name: string;
  legalName?: string;
  trn?: string;
  address?: string;
  notes?: string;
}

export interface UpdateCompanyInput extends NewCompanyInput {
  status: CompanyStatus;
}

export interface NewProjectInput {
  code: string;
  name: string;
  companyId: string;
  status: ProjectStatus;
  location?: string;
  client?: string;
  contractNumber?: string;
  originalContractValue?: number;
  startDate?: string;
  expectedCompletionDate?: string;
  budget?: number;
  notes?: string;
  dedicatedBankAccountId?: string;
  dedicatedCashBoxId?: string;
}

export interface NewTreasuryAccountInput {
  companyId: string;
  projectId?: string;
  code: string;
  name: string;
  type: TreasuryAccountType;
  bankName?: string;
  accountReference?: string;
  notes?: string;
}

export interface UpdateTreasuryAccountInput extends NewTreasuryAccountInput {
  status: TreasuryAccountStatus;
}

export interface NewSupplierPaymentInput {
  date: string;
  supplierId: string;
  amount: number;
  sourceType: SupplierPaymentTransaction["sourceType"];
  sourcePartyId?: string;
  treasuryAccountId?: string;
  reference?: string;
  notes?: string;
}

export interface NewCustodySettlementInput {
  settlementDate: string;
  custodianId: string;
  projectId?: string;
  notes?: string;
  selectedExpenseIds: string[];
  cashReturnAmount: number;
  cashReturnDestinationType?: CashReturnDestinationType;
  cashReturnOwnerId?: string;
  cashReturnTreasuryAccountId?: string;
}

export interface NewSubcontractorInput {
  name: string;
  code?: string;
  taxRegistrationNumber?: string;
  contactPerson?: string;
  phone?: string;
  email?: string;
  address?: string;
  notes?: string;
}

export interface UpdateSubcontractorInput extends NewSubcontractorInput {
  status: PartyStatus;
}

export interface NewSubcontractInput {
  projectId: string;
  subcontractorId: string;
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

export interface NewSubcontractorAdvanceInput {
  contractId: string;
  date: string;
  amount: number;
  paymentSourceType: SubcontractorFundingSourceType;
  paymentSourcePartyId?: string;
  treasuryAccountId?: string;
  paymentMethod: AdvanceTransaction["paymentMethod"];
  reference?: string;
  notes?: string;
}

export interface CertificateFormInput {
  contractId: string;
  certificateNumber: string;
  certificateDate: string;
  workValueToDate: number;
  previousCertifiedWork: number;
  currentVariationAmount: number;
  retentionPercent: number;
  advanceRecovery: number;
  deductionLines: CertificateDeduction[];
  vatMode: VatMode;
  manualVatAmount?: number;
  taxInvoiceReceived: boolean;
  taxInvoiceNumber?: string;
  taxInvoiceDate?: string;
  notes?: string;
}

export interface NewSubcontractorPaymentInput {
  certificateId: string;
  date: string;
  amount: number;
  sourceType: SubcontractorPaymentSourceType;
  sourcePartyId?: string;
  treasuryAccountId?: string;
  reference?: string;
  notes?: string;
}

interface AppDataContextValue extends AppData {
  addExpense: (input: NewExpenseInput) => void;
  addAdvance: (input: NewAdvanceInput) => void;
  addSupplierPayment: (input: NewSupplierPaymentInput) => void;

  addCompany: (input: NewCompanyInput) => void;
  updateCompany: (id: string, input: UpdateCompanyInput) => void;

  addProject: (input: NewProjectInput) => void;
  updateProject: (id: string, input: NewProjectInput) => void;
  deleteProject: (id: string) => void;

  addTreasuryAccount: (input: NewTreasuryAccountInput) => void;
  updateTreasuryAccount: (id: string, input: UpdateTreasuryAccountInput) => void;

  addCustodySettlement: (input: NewCustodySettlementInput) => void;
  discardDraftSettlement: (id: string) => void;
  finalizeCustodySettlement: (id: string) => void;

  addSubcontractor: (input: NewSubcontractorInput) => void;
  updateSubcontractor: (id: string, input: UpdateSubcontractorInput) => void;

  addSubcontract: (input: NewSubcontractInput) => void;
  updateSubcontract: (id: string, input: NewSubcontractInput) => void;
  deleteSubcontract: (id: string) => void;

  addSubcontractorAdvance: (input: NewSubcontractorAdvanceInput) => void;
  addCertificateDraft: (input: CertificateFormInput) => void;
  updateCertificateDraft: (id: string, input: CertificateFormInput) => void;
  approveCertificate: (id: string) => void;
  addSubcontractorPayment: (input: NewSubcontractorPaymentInput) => void;
}

const AppDataContext = createContext<AppDataContextValue | null>(null);

function loadAll(): AppData {
  return {
    companies: db.companies.getAll(),
    projects: db.projects.getAll(),
    parties: db.parties.getAll(),
    categories: db.categories.getAll(),
    accounts: db.accounts.getAll(),
    expenses: db.expenses.getAll(),
    advances: db.advances.getAll(),
    supplierPayments: db.supplierPayments.getAll(),
    journalEntries: db.journalEntries.getAll(),
    custodySettlements: db.custodySettlements.getAll(),
    subcontracts: db.subcontracts.getAll(),
    subcontractorAdvances: db.subcontractorAdvances.getAll(),
    subcontractorCertificates: db.subcontractorCertificates.getAll(),
    subcontractorPayments: db.subcontractorPayments.getAll(),
    treasuryAccounts: db.treasuryAccounts.getAll(),
  };
}

/** Cash-family types share the "1000 Cash on Hand" root, bank-family types share
 * "1100 Bank Account" — every treasury account still gets its own dedicated child GL
 * account under one of these two roots (Phase 2B.1A), e.g. "1000-002 · Petty Cash". */
function treasuryFamilyRootAccountId(type: TreasuryAccountType): string {
  return type === "BANK" || type === "PROJECT_BANK" ? ACCOUNTS.BANK : ACCOUNTS.CASH;
}

/**
 * Mints a brand-new, dedicated GL account for one treasury account — called once, at
 * treasury-account creation time, and never again (see updateTreasuryAccount, which
 * deliberately never touches glAccountId, so historical postings never change meaning).
 * Codes are sequential per family, e.g. "1000-001 Main Cash", "1000-002 Petty Cash",
 * "1100-001 Main Bank" — see PROJECT_ROADMAP.md Phase 2B.1A.
 */
function createTreasuryGlAccount(name: string, type: TreasuryAccountType): Account {
  const rootId = treasuryFamilyRootAccountId(type);
  const rootCode = db.accounts.getById(rootId)?.code ?? "1000";
  const siblings = db.accounts.getAll().filter((a) => a.code.startsWith(`${rootCode}-`));
  const nextSeq = siblings.reduce((max, a) => Math.max(max, Number(a.code.split("-")[1]) || 0), 0) + 1;
  const account: Account = {
    id: newId("acc"),
    code: `${rootCode}-${String(nextSeq).padStart(3, "0")}`,
    name,
    type: "ASSET",
    parentId: rootId,
  };
  db.accounts.create(account);
  return account;
}

/** The three kinds of "where did the money come from/go to" shared across custodian
 * advances, expenses, supplier payments, subcontractor advances/payments, and custody
 * cash returns. Centralizing resolution here (Phase 2B.1A) avoids repeating the same
 * treasury lookup/validation five times across AppDataContext — see PROJECT_ROADMAP.md. */
type GenericFundingSourceType = "TREASURY" | "OWNER_CURRENT" | "CUSTODIAN";

interface FundingContext {
  /** The project the transaction is being posted against, if any — used to enforce that a
   * project-specific treasury account can only be used for its own project (Phase 2B.1A). */
  projectId?: string;
  /** The company of that project, if any — used to enforce that a treasury account belongs
   * to the same company as the project it's being used for. */
  companyId?: string;
}

/** Resolves a funding-source selection into the GL account (and party, if control-account-
 * scoped) to post against — validating existence, active status, and project/company scope
 * along the way. Never called for legacy CASH/BANK values (those post directly in the
 * posting engine, unchanged, for backward compatibility). */
function resolveFundingSource(
  type: GenericFundingSourceType,
  id: string,
  ctx: FundingContext = {},
): ResolvedFundingSource {
  if (type === "OWNER_CURRENT") {
    const party = db.parties.getById(id);
    if (!party || party.type !== "OWNER") throw new Error("Select a valid owner.");
    return { glAccountId: ACCOUNTS.OWNER_CURRENT, partyId: id };
  }
  if (type === "CUSTODIAN") {
    const party = db.parties.getById(id);
    if (!party || party.type !== "CUSTODIAN") throw new Error("Select a valid custodian.");
    return { glAccountId: ACCOUNTS.ADVANCE_CUSTODY, partyId: id };
  }
  const treasury = db.treasuryAccounts.getById(id);
  if (!treasury) throw new Error("Funding source not found.");
  if (treasury.status !== "ACTIVE") throw new Error("This treasury account is inactive.");
  if (treasury.projectId && treasury.projectId !== ctx.projectId) {
    throw new Error("This treasury account is dedicated to a different project and cannot be used here.");
  }
  if (ctx.companyId && treasury.companyId !== ctx.companyId) {
    throw new Error("This treasury account belongs to a different company than the selected project.");
  }
  return { glAccountId: treasury.glAccountId };
}

/** A CLOSED project must not accept any new operational financial transaction (Phase
 * 2B.1A) — COMPLETED is deliberately not blocked (work may be done while accounting
 * close-out is still in progress). Historical transactions remain fully readable. */
function assertProjectAcceptsTransactions(projectId?: string): void {
  if (!projectId) return;
  const project = db.projects.getById(projectId);
  if (project && project.status === "CLOSED") {
    throw new Error("This project is closed and cannot accept new financial transactions. Reopen it first.");
  }
}

/** A CLOSED subcontract must not accept a new advance or certificate (Phase 2B.2) — COMPLETED is
 * deliberately not blocked, mirroring the Project CLOSED/COMPLETED distinction. Settling an
 * already-recognized payable (a payment) remains allowed even on a CLOSED contract. */
function assertContractAcceptsTransactions(contractId: string): void {
  const contract = db.subcontracts.getById(contractId);
  if (contract && contract.status === "CLOSED") {
    throw new Error("This subcontract is closed and cannot accept new financial transactions. Reopen it first.");
  }
}

/** True once a contract has any real accounting activity — used to lock its identity fields
 * (subcontractor, project, contract number) and block destructive deletion (Phase 2B.2, mirrors
 * the Project activity-guard pattern from Phase 2B.1). */
function subcontractHasActivity(contractId: string): boolean {
  return (
    db.subcontractorAdvances.getAll().some((a) => a.contractId === contractId) ||
    db.subcontractorCertificates.getAll().some((c) => c.contractId === contractId) ||
    db.subcontractorPayments.getAll().some((p) => p.contractId === contractId) ||
    db.journalEntries.getAll().some((e) => e.lines.some((l) => l.contractId === contractId))
  );
}

function validateContractNumber(contractNumber: string, projectId: string, excludeId?: string): string {
  const trimmed = contractNumber.trim();
  if (!trimmed) throw new Error("Contract number is required.");
  const duplicate = db.subcontracts
    .getAll()
    .some(
      (c) =>
        c.id !== excludeId &&
        c.projectId === projectId &&
        c.contractNumber.trim().toLowerCase() === trimmed.toLowerCase(),
    );
  if (duplicate) throw new Error(`Contract number "${trimmed}" is already used on this project.`);
  return trimmed;
}

function buildCertificateFromInput(
  input: CertificateFormInput,
  id: string,
  status: "DRAFT",
): SubcontractorCertificate {
  const contract = db.subcontracts.getById(input.contractId);
  if (!contract) throw new Error("Contract not found.");

  const calc = calcCertificate({
    workValueToDate: input.workValueToDate,
    previousCertifiedWork: input.previousCertifiedWork,
    currentVariationAmount: input.currentVariationAmount,
    retentionPercent: input.retentionPercent,
    advanceRecovery: input.advanceRecovery,
    deductionAmounts: input.deductionLines.map((d) => d.amount),
    vatMode: input.vatMode,
    manualVatAmount: input.manualVatAmount,
  });

  return {
    id,
    certificateNumber: input.certificateNumber,
    certificateDate: input.certificateDate,
    contractId: input.contractId,
    projectId: contract.projectId,
    subcontractorId: contract.subcontractorId,
    workValueToDate: input.workValueToDate,
    previousCertifiedWork: input.previousCertifiedWork,
    currentWorkValue: calc.currentWorkValue,
    currentVariationAmount: input.currentVariationAmount,
    grossCurrentValue: calc.grossCurrentValue,
    retentionPercent: input.retentionPercent,
    retentionAmount: calc.retentionAmount,
    advanceRecovery: input.advanceRecovery,
    deductionLines: input.deductionLines,
    vatMode: input.vatMode,
    vatAmount: calc.vatAmount,
    taxInvoiceReceived: input.taxInvoiceReceived,
    taxInvoiceNumber: input.taxInvoiceNumber,
    taxInvoiceDate: input.taxInvoiceDate,
    netBeforeVat: calc.netBeforeVat,
    netPayable: calc.netPayable,
    notes: input.notes,
    status,
  };
}

export function AppDataProvider({ children }: { children: ReactNode }) {
  const [data, setData] = useState<AppData>(loadAll);

  const refresh = useCallback(() => setData(loadAll()), []);

  const addExpense = useCallback(
    (input: NewExpenseInput) => {
      assertProjectAcceptsTransactions(input.projectId);

      const vat = calcVat({
        netAmount: input.netAmount,
        vatMode: input.vatMode,
        manualVatAmount: input.manualVatAmount,
      });
      const expense: ExpenseTransaction = {
        id: newId("exp"),
        date: input.date,
        projectId: input.projectId,
        supplierId: input.supplierId,
        categoryId: input.categoryId,
        description: input.description,
        invoiceNumber: input.invoiceNumber,
        netAmount: vat.netAmount,
        vatAmount: vat.vatAmount,
        totalAmount: vat.totalAmount,
        paidFromType: input.paidFromType,
        paidFromPartyId: input.paidFromPartyId,
        treasuryAccountId: input.treasuryAccountId,
        advanceId: input.advanceId,
        paymentMethod: input.paymentMethod,
        hasInvoice: input.hasInvoice,
        notes: input.notes,
        status: "POSTED",
      };

      let resolved: ResolvedFundingSource | undefined;
      const projectCompanyId = input.projectId ? db.projects.getById(input.projectId)?.companyId : undefined;
      if (input.paidFromType === "CUSTODIAN") {
        resolved = resolveFundingSource("CUSTODIAN", input.paidFromPartyId!);
      } else if (input.paidFromType === "OWNER") {
        resolved = resolveFundingSource("OWNER_CURRENT", input.paidFromPartyId!);
      } else if (input.paidFromType === "TREASURY") {
        resolved = resolveFundingSource("TREASURY", input.treasuryAccountId!, {
          projectId: input.projectId,
          companyId: projectCompanyId,
        });
      }

      const journalEntry = postExpense(expense, resolved, newId("je"), `EXP-${expense.id.slice(-6)}`);
      db.expenses.create(expense);
      db.journalEntries.create(journalEntry);
      refresh();
    },
    [refresh],
  );

  const addAdvance = useCallback(
    (input: NewAdvanceInput) => {
      assertProjectAcceptsTransactions(input.projectId);

      const projectCompanyId = input.projectId ? db.projects.getById(input.projectId)?.companyId : undefined;
      const resolved = resolveFundingSource(
        input.fundingSourceType === "TREASURY" ? "TREASURY" : "OWNER_CURRENT",
        input.fundingSourceId,
        { projectId: input.projectId, companyId: projectCompanyId },
      );

      const advance: AdvanceTransaction = {
        id: newId("adv"),
        date: input.date,
        custodianId: input.custodianId,
        amount: input.amount,
        projectId: input.projectId,
        fundingSourceType: input.fundingSourceType,
        fundingSourceId: input.fundingSourceId,
        paymentMethod: input.paymentMethod,
        reference: input.reference,
        notes: input.notes,
      };
      const journalEntry = postAdvance(advance, resolved, newId("je"), `ADV-${advance.id.slice(-6)}`);
      db.advances.create(advance);
      db.journalEntries.create(journalEntry);
      refresh();
    },
    [refresh],
  );

  const addSupplierPayment = useCallback(
    (input: NewSupplierPaymentInput) => {
      let resolved: ResolvedFundingSource | undefined;
      if (input.sourceType === "TREASURY") {
        resolved = resolveFundingSource("TREASURY", input.treasuryAccountId!);
      } else if (input.sourceType === "CUSTODIAN") {
        resolved = resolveFundingSource("CUSTODIAN", input.sourcePartyId!);
      } else if (input.sourceType === "OWNER") {
        resolved = resolveFundingSource("OWNER_CURRENT", input.sourcePartyId!);
      }

      const payment: SupplierPaymentTransaction = {
        id: newId("pay"),
        date: input.date,
        supplierId: input.supplierId,
        amount: input.amount,
        sourceType: input.sourceType,
        sourcePartyId: input.sourcePartyId,
        treasuryAccountId: input.treasuryAccountId,
        reference: input.reference,
        notes: input.notes,
      };
      const journalEntry = postSupplierPayment(payment, resolved, newId("je"), `PAY-${payment.id.slice(-6)}`);
      db.supplierPayments.create(payment);
      db.journalEntries.create(journalEntry);
      refresh();
    },
    [refresh],
  );

  // ---------------------------------------------------------------------
  // Companies
  // ---------------------------------------------------------------------

  const addCompany = useCallback(
    (input: NewCompanyInput) => {
      const code = input.code.trim();
      if (!code) throw new Error("Company code is required.");
      const duplicate = db.companies.getAll().some((c) => c.code.trim().toLowerCase() === code.toLowerCase());
      if (duplicate) throw new Error(`Company code "${code}" is already in use.`);

      const now = new Date().toISOString();
      const company: Company = {
        id: newId("company"),
        code,
        name: input.name.trim(),
        legalName: input.legalName?.trim() || undefined,
        trn: input.trn?.trim() || undefined,
        address: input.address?.trim() || undefined,
        status: "ACTIVE",
        notes: input.notes?.trim() || undefined,
        createdAt: now,
        updatedAt: now,
      };
      db.companies.create(company);
      refresh();
    },
    [refresh],
  );

  const updateCompany = useCallback(
    (id: string, input: UpdateCompanyInput) => {
      const existing = db.companies.getById(id);
      if (!existing) throw new Error("Company not found.");
      const code = input.code.trim();
      if (!code) throw new Error("Company code is required.");
      const duplicate = db.companies
        .getAll()
        .some((c) => c.id !== id && c.code.trim().toLowerCase() === code.toLowerCase());
      if (duplicate) throw new Error(`Company code "${code}" is already in use.`);

      db.companies.update(id, {
        code,
        name: input.name.trim(),
        legalName: input.legalName?.trim() || undefined,
        trn: input.trn?.trim() || undefined,
        address: input.address?.trim() || undefined,
        status: input.status,
        notes: input.notes?.trim() || undefined,
        updatedAt: new Date().toISOString(),
      });
      refresh();
    },
    [refresh],
  );

  // ---------------------------------------------------------------------
  // Projects
  // ---------------------------------------------------------------------

  function validateProjectCode(code: string, companyId: string, excludeId?: string): string {
    const trimmed = code.trim();
    if (!trimmed) throw new Error("Project code is required.");
    const duplicate = db.projects
      .getAll()
      .some(
        (p) =>
          p.id !== excludeId &&
          p.companyId === companyId &&
          p.code.trim().toLowerCase() === trimmed.toLowerCase(),
      );
    if (duplicate) throw new Error(`Project code "${trimmed}" is already used in this company.`);
    return trimmed;
  }

  /** True once a project has any real accounting or contract activity — used to
   * lock its identity fields and block destructive deletion (Phase 2B.1 rule). */
  function projectHasActivity(projectId: string): boolean {
    return (
      db.expenses.getAll().some((e) => e.projectId === projectId) ||
      db.advances.getAll().some((a) => a.projectId === projectId) ||
      db.custodySettlements.getAll().some((s) => s.projectId === projectId) ||
      db.subcontracts.getAll().some((c) => c.projectId === projectId) ||
      db.journalEntries.getAll().some((e) => e.lines.some((l) => l.projectId === projectId))
    );
  }

  const addProject = useCallback(
    (input: NewProjectInput) => {
      if (!input.name.trim()) throw new Error("Project name is required.");
      const company = db.companies.getById(input.companyId);
      if (!company) throw new Error("Select a valid company.");
      const code = validateProjectCode(input.code, input.companyId);

      const now = new Date().toISOString();
      const project: Project = {
        id: newId("proj"),
        code,
        name: input.name.trim(),
        companyId: input.companyId,
        status: input.status,
        location: input.location?.trim() || undefined,
        client: input.client?.trim() || undefined,
        contractNumber: input.contractNumber?.trim() || undefined,
        originalContractValue: input.originalContractValue,
        startDate: input.startDate || undefined,
        expectedCompletionDate: input.expectedCompletionDate || undefined,
        budget: input.budget,
        notes: input.notes?.trim() || undefined,
        dedicatedBankAccountId: input.dedicatedBankAccountId || undefined,
        dedicatedCashBoxId: input.dedicatedCashBoxId || undefined,
        createdAt: now,
        updatedAt: now,
      };
      db.projects.create(project);
      refresh();
    },
    [refresh],
  );

  const updateProject = useCallback(
    (id: string, input: NewProjectInput) => {
      const existing = db.projects.getById(id);
      if (!existing) throw new Error("Project not found.");
      if (!input.name.trim()) throw new Error("Project name is required.");

      const hasActivity = projectHasActivity(id);
      if (hasActivity && (input.code !== existing.code || input.companyId !== existing.companyId)) {
        throw new Error(
          "This project already has accounting activity — its project code and company cannot be changed.",
        );
      }

      const company = db.companies.getById(input.companyId);
      if (!company) throw new Error("Select a valid company.");
      const code = validateProjectCode(input.code, input.companyId, id);

      db.projects.update(id, {
        code,
        name: input.name.trim(),
        companyId: input.companyId,
        status: input.status,
        location: input.location?.trim() || undefined,
        client: input.client?.trim() || undefined,
        contractNumber: input.contractNumber?.trim() || undefined,
        originalContractValue: input.originalContractValue,
        startDate: input.startDate || undefined,
        expectedCompletionDate: input.expectedCompletionDate || undefined,
        budget: input.budget,
        notes: input.notes?.trim() || undefined,
        dedicatedBankAccountId: input.dedicatedBankAccountId || undefined,
        dedicatedCashBoxId: input.dedicatedCashBoxId || undefined,
        updatedAt: new Date().toISOString(),
      });
      refresh();
    },
    [refresh],
  );

  const deleteProject = useCallback(
    (id: string) => {
      if (projectHasActivity(id)) {
        throw new Error("This project has accounting activity and cannot be deleted. Close it instead.");
      }
      db.projects.remove(id);
      refresh();
    },
    [refresh],
  );

  // ---------------------------------------------------------------------
  // Treasury accounts
  // ---------------------------------------------------------------------

  const addTreasuryAccount = useCallback(
    (input: NewTreasuryAccountInput) => {
      const code = input.code.trim();
      if (!code) throw new Error("Treasury account code is required.");
      if (!input.name.trim()) throw new Error("Treasury account name is required.");
      const company = db.companies.getById(input.companyId);
      if (!company) throw new Error("Select a valid company.");
      if (input.projectId) {
        const project = db.projects.getById(input.projectId);
        if (!project) throw new Error("Select a valid project.");
        if (project.companyId !== input.companyId) {
          throw new Error("A project-specific treasury account must belong to the project's own company.");
        }
      }
      const duplicate = db.treasuryAccounts
        .getAll()
        .some((t) => t.companyId === input.companyId && t.code.trim().toLowerCase() === code.toLowerCase());
      if (duplicate) throw new Error(`Treasury account code "${code}" is already in use for this company.`);

      const glAccount = createTreasuryGlAccount(input.name.trim(), input.type);
      const now = new Date().toISOString();
      const account: TreasuryAccount = {
        id: newId("treasury"),
        companyId: input.companyId,
        projectId: input.projectId || undefined,
        code,
        name: input.name.trim(),
        type: input.type,
        glAccountId: glAccount.id,
        status: "ACTIVE",
        bankName: input.bankName?.trim() || undefined,
        accountReference: input.accountReference?.trim() || undefined,
        notes: input.notes?.trim() || undefined,
        createdAt: now,
        updatedAt: now,
      };
      db.treasuryAccounts.create(account);
      refresh();
    },
    [refresh],
  );

  const updateTreasuryAccount = useCallback(
    (id: string, input: UpdateTreasuryAccountInput) => {
      const existing = db.treasuryAccounts.getById(id);
      if (!existing) throw new Error("Treasury account not found.");
      const code = input.code.trim();
      if (!code) throw new Error("Treasury account code is required.");
      if (!input.name.trim()) throw new Error("Treasury account name is required.");
      if (input.projectId) {
        const project = db.projects.getById(input.projectId);
        if (!project) throw new Error("Select a valid project.");
        if (project.companyId !== input.companyId) {
          throw new Error("A project-specific treasury account must belong to the project's own company.");
        }
      }
      const duplicate = db.treasuryAccounts
        .getAll()
        .some(
          (t) => t.id !== id && t.companyId === input.companyId && t.code.trim().toLowerCase() === code.toLowerCase(),
        );
      if (duplicate) throw new Error(`Treasury account code "${code}" is already in use for this company.`);

      // glAccountId is deliberately never touched here — it's fixed at creation time
      // (Phase 2B.1A) so editing a treasury account's name/type/company never changes
      // the meaning of transactions already posted against its GL account.
      db.treasuryAccounts.update(id, {
        companyId: input.companyId,
        projectId: input.projectId || undefined,
        code,
        name: input.name.trim(),
        type: input.type,
        status: input.status,
        bankName: input.bankName?.trim() || undefined,
        accountReference: input.accountReference?.trim() || undefined,
        notes: input.notes?.trim() || undefined,
        updatedAt: new Date().toISOString(),
      });
      refresh();
    },
    [refresh],
  );

  // ---------------------------------------------------------------------
  // Custody settlements
  // ---------------------------------------------------------------------

  const addCustodySettlement = useCallback(
    (input: NewCustodySettlementInput) => {
      assertProjectAcceptsTransactions(input.projectId);

      const settlementNumber = `STL-${String(db.custodySettlements.getAll().length + 1).padStart(3, "0")}`;
      const settlement: CustodySettlement = {
        id: newId("settle"),
        settlementNumber,
        settlementDate: input.settlementDate,
        custodianId: input.custodianId,
        projectId: input.projectId,
        notes: input.notes,
        status: "DRAFT",
        selectedExpenseIds: input.selectedExpenseIds,
        cashReturnAmount: input.cashReturnAmount,
        cashReturnDestinationType: input.cashReturnDestinationType,
        cashReturnOwnerId: input.cashReturnOwnerId,
        cashReturnTreasuryAccountId: input.cashReturnTreasuryAccountId,
        createdAt: new Date().toISOString(),
      };
      db.custodySettlements.create(settlement);
      refresh();
    },
    [refresh],
  );

  const discardDraftSettlement = useCallback(
    (id: string) => {
      const settlement = db.custodySettlements.getById(id);
      if (!settlement || settlement.status !== "DRAFT") return;
      db.custodySettlements.remove(id);
      refresh();
    },
    [refresh],
  );

  const finalizeCustodySettlement = useCallback(
    (id: string) => {
      const settlement = db.custodySettlements.getById(id);
      if (!settlement) throw new Error("Settlement not found.");
      if (settlement.status === "SETTLED") {
        throw new Error("This settlement has already been finalized.");
      }

      const allExpenses = db.expenses.getAll();
      const selected = allExpenses.filter((e) => settlement.selectedExpenseIds.includes(e.id));
      const belongsToOther = selected.find(
        (e) => !(e.paidFromType === "CUSTODIAN" && e.paidFromPartyId === settlement.custodianId),
      );
      if (belongsToOther) {
        throw new Error("This settlement includes an expense that does not belong to the selected custodian.");
      }

      const otherSettled = db.custodySettlements.getAll().filter((s) => s.id !== id && s.status === "SETTLED");
      const alreadyClaimed = settlement.selectedExpenseIds.find((eid) =>
        otherSettled.some((s) => s.selectedExpenseIds.includes(eid)),
      );
      if (alreadyClaimed) {
        throw new Error("One of the selected expenses is already included in a finalized settlement.");
      }

      const entries = db.journalEntries.getAll();
      const balance = custodianBalance(entries, settlement.custodianId);
      if (settlement.cashReturnAmount > balance + 0.01) {
        throw new Error(
          `Cash return (${formatAED(settlement.cashReturnAmount)}) exceeds the custodian's current balance (${formatAED(balance)}).`,
        );
      }

      let journalEntryId: string | undefined;
      if (settlement.cashReturnAmount > 0) {
        const projectCompanyId = settlement.projectId
          ? db.projects.getById(settlement.projectId)?.companyId
          : undefined;
        let resolved: ResolvedFundingSource | undefined;
        if (settlement.cashReturnDestinationType === "TREASURY") {
          resolved = resolveFundingSource("TREASURY", settlement.cashReturnTreasuryAccountId!, {
            projectId: settlement.projectId,
            companyId: projectCompanyId,
          });
        } else if (settlement.cashReturnDestinationType === "OWNER") {
          resolved = resolveFundingSource("OWNER_CURRENT", settlement.cashReturnOwnerId!);
        }
        const entry = postCashReturn(settlement, resolved, newId("je"), `STL-${settlement.id.slice(-6)}`);
        db.journalEntries.create(entry);
        journalEntryId = entry.id;
      }

      db.custodySettlements.update(id, {
        status: "SETTLED",
        settledAt: new Date().toISOString(),
        journalEntryId,
      });
      refresh();
    },
    [refresh],
  );

  // ---------------------------------------------------------------------
  // Subcontractors — master data (Party.type === "SUBCONTRACTOR")
  // ---------------------------------------------------------------------

  const addSubcontractor = useCallback(
    (input: NewSubcontractorInput) => {
      if (!input.name.trim()) throw new Error("Subcontractor name is required.");
      const code = input.code?.trim() || undefined;
      if (code) {
        const duplicate = db.parties
          .getAll()
          .some((p) => p.type === "SUBCONTRACTOR" && p.code?.trim().toLowerCase() === code.toLowerCase());
        if (duplicate) throw new Error(`Subcontractor code "${code}" is already in use.`);
      }

      const party: Party = {
        id: newId("sub"),
        type: "SUBCONTRACTOR",
        name: input.name.trim(),
        code,
        taxRegistrationNumber: input.taxRegistrationNumber?.trim() || undefined,
        contactPerson: input.contactPerson?.trim() || undefined,
        phone: input.phone?.trim() || undefined,
        email: input.email?.trim() || undefined,
        address: input.address?.trim() || undefined,
        notes: input.notes?.trim() || undefined,
        status: "ACTIVE",
      };
      db.parties.create(party);
      refresh();
    },
    [refresh],
  );

  const updateSubcontractor = useCallback(
    (id: string, input: UpdateSubcontractorInput) => {
      const existing = db.parties.getById(id);
      if (!existing || existing.type !== "SUBCONTRACTOR") throw new Error("Subcontractor not found.");
      if (!input.name.trim()) throw new Error("Subcontractor name is required.");
      const code = input.code?.trim() || undefined;
      if (code) {
        const duplicate = db.parties
          .getAll()
          .some(
            (p) => p.id !== id && p.type === "SUBCONTRACTOR" && p.code?.trim().toLowerCase() === code.toLowerCase(),
          );
        if (duplicate) throw new Error(`Subcontractor code "${code}" is already in use.`);
      }

      db.parties.update(id, {
        name: input.name.trim(),
        code,
        taxRegistrationNumber: input.taxRegistrationNumber?.trim() || undefined,
        contactPerson: input.contactPerson?.trim() || undefined,
        phone: input.phone?.trim() || undefined,
        email: input.email?.trim() || undefined,
        address: input.address?.trim() || undefined,
        notes: input.notes?.trim() || undefined,
        status: input.status,
      });
      refresh();
    },
    [refresh],
  );

  // ---------------------------------------------------------------------
  // Subcontracts (contracts) — Phase 2B.2
  // ---------------------------------------------------------------------

  const addSubcontract = useCallback(
    (input: NewSubcontractInput) => {
      const project = db.projects.getById(input.projectId);
      if (!project) throw new Error("Select a valid project.");
      assertProjectAcceptsTransactions(input.projectId);

      const subcontractor = db.parties.getById(input.subcontractorId);
      if (!subcontractor || subcontractor.type !== "SUBCONTRACTOR") throw new Error("Select a valid subcontractor.");
      if (subcontractor.status === "INACTIVE") {
        throw new Error("This subcontractor is inactive and cannot be assigned a new contract. Reactivate it first.");
      }

      const contractNumber = validateContractNumber(input.contractNumber, input.projectId);
      if (!input.scopeOfWork.trim()) throw new Error("Scope of work is required.");
      if (input.originalContractValue < 0) throw new Error("Original contract value cannot be negative.");
      if (addMoney(input.originalContractValue, input.approvedVariations) < 0) {
        throw new Error("Approved variations cannot reduce the revised contract value below zero.");
      }
      if (input.retentionPercent < 0 || input.retentionPercent > 100) {
        throw new Error("Retention percent must be between 0 and 100.");
      }

      const contract: Subcontract = {
        id: newId("contract"),
        projectId: input.projectId,
        subcontractorId: input.subcontractorId,
        contractNumber,
        scopeOfWork: input.scopeOfWork.trim(),
        originalContractValue: input.originalContractValue,
        approvedVariations: input.approvedVariations,
        retentionPercent: input.retentionPercent,
        startDate: input.startDate || undefined,
        endDate: input.endDate || undefined,
        status: input.status,
        notes: input.notes?.trim() || undefined,
      };
      db.subcontracts.create(contract);
      refresh();
    },
    [refresh],
  );

  const updateSubcontract = useCallback(
    (id: string, input: NewSubcontractInput) => {
      const existing = db.subcontracts.getById(id);
      if (!existing) throw new Error("Contract not found.");

      const hasActivity = subcontractHasActivity(id);
      if (
        hasActivity &&
        (input.subcontractorId !== existing.subcontractorId ||
          input.projectId !== existing.projectId ||
          input.contractNumber.trim() !== existing.contractNumber)
      ) {
        throw new Error(
          "This contract already has accounting activity — its subcontractor, project, and contract number cannot be changed.",
        );
      }

      const project = db.projects.getById(input.projectId);
      if (!project) throw new Error("Select a valid project.");
      const subcontractor = db.parties.getById(input.subcontractorId);
      if (!subcontractor || subcontractor.type !== "SUBCONTRACTOR") throw new Error("Select a valid subcontractor.");
      if (!hasActivity && subcontractor.status === "INACTIVE") {
        throw new Error("This subcontractor is inactive and cannot be assigned a new contract. Reactivate it first.");
      }

      const contractNumber = validateContractNumber(input.contractNumber, input.projectId, id);
      if (!input.scopeOfWork.trim()) throw new Error("Scope of work is required.");
      if (input.originalContractValue < 0) throw new Error("Original contract value cannot be negative.");
      const revisedValue = addMoney(input.originalContractValue, input.approvedVariations);
      if (revisedValue < 0) {
        throw new Error("Approved variations cannot reduce the revised contract value below zero.");
      }
      if (hasActivity) {
        const certifiedToDate = contractCertifiedCost(db.journalEntries.getAll(), id);
        if (revisedValue < certifiedToDate - 0.01) {
          throw new Error(
            `Revised contract value (${formatAED(revisedValue)}) cannot be reduced below work already certified (${formatAED(certifiedToDate)}).`,
          );
        }
      }
      if (input.retentionPercent < 0 || input.retentionPercent > 100) {
        throw new Error("Retention percent must be between 0 and 100.");
      }

      db.subcontracts.update(id, {
        projectId: input.projectId,
        subcontractorId: input.subcontractorId,
        contractNumber,
        scopeOfWork: input.scopeOfWork.trim(),
        originalContractValue: input.originalContractValue,
        approvedVariations: input.approvedVariations,
        retentionPercent: input.retentionPercent,
        startDate: input.startDate || undefined,
        endDate: input.endDate || undefined,
        status: input.status,
        notes: input.notes?.trim() || undefined,
      });
      refresh();
    },
    [refresh],
  );

  const deleteSubcontract = useCallback(
    (id: string) => {
      if (subcontractHasActivity(id)) {
        throw new Error("This contract has accounting activity and cannot be deleted. Close it instead.");
      }
      db.subcontracts.remove(id);
      refresh();
    },
    [refresh],
  );

  // ---------------------------------------------------------------------
  // Subcontractor advances, certificates, payments
  // ---------------------------------------------------------------------

  const addSubcontractorAdvance = useCallback(
    (input: NewSubcontractorAdvanceInput) => {
      const contract = db.subcontracts.getById(input.contractId);
      if (!contract) throw new Error("Contract not found.");
      assertProjectAcceptsTransactions(contract.projectId);
      assertContractAcceptsTransactions(contract.id);

      let resolved: ResolvedFundingSource | undefined;
      if (input.paymentSourceType === "TREASURY") {
        const projectCompanyId = db.projects.getById(contract.projectId)?.companyId;
        resolved = resolveFundingSource("TREASURY", input.treasuryAccountId!, {
          projectId: contract.projectId,
          companyId: projectCompanyId,
        });
      } else if (input.paymentSourceType === "CUSTODIAN") {
        resolved = resolveFundingSource("CUSTODIAN", input.paymentSourcePartyId!);
      } else if (input.paymentSourceType === "OWNER") {
        resolved = resolveFundingSource("OWNER_CURRENT", input.paymentSourcePartyId!);
      }

      const advance: SubcontractorAdvance = {
        id: newId("subadv"),
        contractId: input.contractId,
        date: input.date,
        amount: input.amount,
        paymentSourceType: input.paymentSourceType,
        paymentSourcePartyId: input.paymentSourcePartyId,
        treasuryAccountId: input.treasuryAccountId,
        paymentMethod: input.paymentMethod,
        reference: input.reference,
        notes: input.notes,
      };
      const entry = postSubcontractorAdvance(
        advance,
        contract.subcontractorId,
        contract.projectId,
        resolved,
        newId("je"),
        `SADV-${advance.id.slice(-6)}`,
      );
      db.subcontractorAdvances.create(advance);
      db.journalEntries.create(entry);
      refresh();
    },
    [refresh],
  );

  const addCertificateDraft = useCallback(
    (input: CertificateFormInput) => {
      const contract = db.subcontracts.getById(input.contractId);
      if (!contract) throw new Error("Contract not found.");
      assertProjectAcceptsTransactions(contract.projectId);
      assertContractAcceptsTransactions(contract.id);
      const certificate = buildCertificateFromInput(input, newId("cert"), "DRAFT");
      db.subcontractorCertificates.create(certificate);
      refresh();
    },
    [refresh],
  );

  const updateCertificateDraft = useCallback(
    (id: string, input: CertificateFormInput) => {
      const existing = db.subcontractorCertificates.getById(id);
      if (!existing) throw new Error("Certificate not found.");
      if (existing.status !== "DRAFT") throw new Error("Only draft certificates can be edited.");
      assertProjectAcceptsTransactions(existing.projectId);
      assertContractAcceptsTransactions(existing.contractId);
      const updated = buildCertificateFromInput(input, id, "DRAFT");
      db.subcontractorCertificates.update(id, updated);
      refresh();
    },
    [refresh],
  );

  const approveCertificate = useCallback(
    (id: string) => {
      const cert = db.subcontractorCertificates.getById(id);
      if (!cert) throw new Error("Certificate not found.");
      if (cert.status !== "DRAFT") throw new Error("This certificate has already been approved.");
      assertProjectAcceptsTransactions(cert.projectId);

      const contract = db.subcontracts.getById(cert.contractId);
      if (!contract) throw new Error("Contract not found.");
      assertContractAcceptsTransactions(contract.id);

      const entries = db.journalEntries.getAll();
      // Contract-scoped (Phase 2B.2), not party+project-scoped — two contracts for the same
      // subcontractor must never share an advance balance, even on the same project.
      const availableAdvanceBalance = contractAdvanceBalance(entries, contract.id);
      const revisedContractValue = addMoney(contract.originalContractValue, contract.approvedVariations);
      const deductionAmounts = cert.deductionLines.map((d) => d.amount);

      const calc = {
        currentWorkValue: cert.currentWorkValue,
        grossCurrentValue: cert.grossCurrentValue,
        retentionAmount: cert.retentionAmount,
        totalDeductions: deductionAmounts.reduce((s, a) => addMoney(s, a), 0),
        netBeforeVat: cert.netBeforeVat,
        vatAmount: cert.vatAmount,
        netPayable: cert.netPayable,
      };

      const errors = validateCertificate(
        {
          workValueToDate: cert.workValueToDate,
          previousCertifiedWork: cert.previousCertifiedWork,
          currentVariationAmount: cert.currentVariationAmount,
          retentionPercent: cert.retentionPercent,
          advanceRecovery: cert.advanceRecovery,
          deductionAmounts,
          vatMode: cert.vatMode,
        },
        calc,
        {
          revisedContractValue,
          availableAdvanceBalance,
          deductionAmounts,
          taxInvoiceReceived: cert.taxInvoiceReceived,
          taxInvoiceNumber: cert.taxInvoiceNumber,
          taxInvoiceDate: cert.taxInvoiceDate,
        },
      );

      const unmapped = cert.deductionLines.some((d) => !d.accountId);
      if (unmapped) errors.deductionLines = "Every deduction must be mapped to an account before approval.";

      const firstError = Object.values(errors)[0];
      if (firstError) throw new Error(firstError);

      const journalId = newId("je");
      const entry = postCertificateApproval(cert, journalId, `CERT-${cert.id.slice(-6)}`);
      db.journalEntries.create(entry);
      db.subcontractorCertificates.update(id, {
        status: "APPROVED",
        approvedAt: new Date().toISOString(),
        journalEntryId: journalId,
      });
      refresh();
    },
    [refresh],
  );

  const addSubcontractorPayment = useCallback(
    (input: NewSubcontractorPaymentInput) => {
      const cert = db.subcontractorCertificates.getById(input.certificateId);
      if (!cert) throw new Error("Certificate not found.");
      if (cert.status === "DRAFT") throw new Error("Cannot pay a certificate that has not been approved.");

      const payments = db.subcontractorPayments.getAll();
      const alreadyPaid = certificatePaidAmount(payments, cert.id);
      const outstanding = subtractMoney(cert.netPayable, alreadyPaid);
      if (input.amount > outstanding + 0.01) {
        throw new Error(
          `Payment (${formatAED(input.amount)}) exceeds the outstanding balance on this certificate (${formatAED(outstanding)}).`,
        );
      }

      let resolved: ResolvedFundingSource | undefined;
      if (input.sourceType === "TREASURY") {
        const projectCompanyId = db.projects.getById(cert.projectId)?.companyId;
        resolved = resolveFundingSource("TREASURY", input.treasuryAccountId!, {
          projectId: cert.projectId,
          companyId: projectCompanyId,
        });
      } else if (input.sourceType === "CUSTODIAN") {
        resolved = resolveFundingSource("CUSTODIAN", input.sourcePartyId!);
      } else if (input.sourceType === "OWNER") {
        resolved = resolveFundingSource("OWNER_CURRENT", input.sourcePartyId!);
      }

      const payment: SubcontractorPaymentTransaction = {
        id: newId("subpay"),
        date: input.date,
        subcontractorId: cert.subcontractorId,
        certificateId: input.certificateId,
        contractId: cert.contractId,
        amount: input.amount,
        sourceType: input.sourceType,
        sourcePartyId: input.sourcePartyId,
        treasuryAccountId: input.treasuryAccountId,
        reference: input.reference,
        notes: input.notes,
      };
      const entry = postSubcontractorPayment(
        payment,
        cert.projectId,
        resolved,
        newId("je"),
        `SPAY-${payment.id.slice(-6)}`,
      );
      db.subcontractorPayments.create(payment);
      db.journalEntries.create(entry);

      const newPaid = addMoney(alreadyPaid, input.amount);
      const newStatus = newPaid >= cert.netPayable - 0.01 ? "PAID" : "PARTIALLY_PAID";
      db.subcontractorCertificates.update(cert.id, { status: newStatus });

      refresh();
    },
    [refresh],
  );

  const value = useMemo<AppDataContextValue>(
    () => ({
      ...data,
      addExpense,
      addAdvance,
      addSupplierPayment,
      addCompany,
      updateCompany,
      addProject,
      updateProject,
      deleteProject,
      addTreasuryAccount,
      updateTreasuryAccount,
      addCustodySettlement,
      discardDraftSettlement,
      finalizeCustodySettlement,
      addSubcontractor,
      updateSubcontractor,
      addSubcontract,
      updateSubcontract,
      deleteSubcontract,
      addSubcontractorAdvance,
      addCertificateDraft,
      updateCertificateDraft,
      approveCertificate,
      addSubcontractorPayment,
    }),
    [
      data,
      addExpense,
      addAdvance,
      addSupplierPayment,
      addCompany,
      updateCompany,
      addProject,
      updateProject,
      deleteProject,
      addTreasuryAccount,
      updateTreasuryAccount,
      addCustodySettlement,
      discardDraftSettlement,
      finalizeCustodySettlement,
      addSubcontractor,
      updateSubcontractor,
      addSubcontract,
      updateSubcontract,
      deleteSubcontract,
      addSubcontractorAdvance,
      addCertificateDraft,
      updateCertificateDraft,
      approveCertificate,
      addSubcontractorPayment,
    ],
  );

  return <AppDataContext.Provider value={value}>{children}</AppDataContext.Provider>;
}

export function useAppData(): AppDataContextValue {
  const ctx = useContext(AppDataContext);
  if (!ctx) throw new Error("useAppData must be used within AppDataProvider");
  return ctx;
}
