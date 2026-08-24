import { createContext, useCallback, useContext, useMemo, useState, type ReactNode } from "react";
import type {
  Account,
  AdvanceTransaction,
  CashReturnDestinationType,
  CertificateDeduction,
  Company,
  CustodySettlement,
  ExpenseCategory,
  ExpenseTransaction,
  JournalEntry,
  Party,
  Project,
  Subcontract,
  SubcontractorAdvance,
  SubcontractorCertificate,
  SubcontractorFundingSourceType,
  SubcontractorPaymentSourceType,
  SubcontractorPaymentTransaction,
  SupplierPaymentTransaction,
  VatMode,
} from "../domain/types";
import { addMoney, calcVat, formatAED, subtractMoney } from "../domain/money";
import { db, newId } from "../storage/database";
import { ensurePhase2ASeeded, ensureSeeded } from "../seed/seedData";
import {
  postAdvance,
  postCashReturn,
  postCertificateApproval,
  postExpense,
  postSubcontractorAdvance,
  postSubcontractorPayment,
  postSupplierPayment,
} from "../accounting/postingEngine";
import { calcCertificate, validateCertificate } from "../accounting/certificateCalc";
import { certificatePaidAmount, custodianBalance, subcontractorAdvanceBalance } from "../accounting/ledger";

ensureSeeded();
ensurePhase2ASeeded();

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
  advanceId?: string;
  paymentMethod: ExpenseTransaction["paymentMethod"];
  hasInvoice: boolean;
  notes?: string;
}

export interface NewAdvanceInput {
  date: string;
  fromPartyId: string;
  custodianId: string;
  amount: number;
  projectId?: string;
  paymentMethod: AdvanceTransaction["paymentMethod"];
  reference?: string;
  notes?: string;
}

export interface NewSupplierPaymentInput {
  date: string;
  supplierId: string;
  amount: number;
  sourceType: SupplierPaymentTransaction["sourceType"];
  sourcePartyId?: string;
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
}

export interface NewSubcontractorAdvanceInput {
  contractId: string;
  date: string;
  amount: number;
  paymentSourceType: SubcontractorFundingSourceType;
  paymentSourcePartyId?: string;
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
  reference?: string;
  notes?: string;
}

interface AppDataContextValue extends AppData {
  addExpense: (input: NewExpenseInput) => void;
  addAdvance: (input: NewAdvanceInput) => void;
  addSupplierPayment: (input: NewSupplierPaymentInput) => void;
  addProject: (input: Omit<Project, "id">) => void;

  addCustodySettlement: (input: NewCustodySettlementInput) => void;
  discardDraftSettlement: (id: string) => void;
  finalizeCustodySettlement: (id: string) => void;

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
  };
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
        advanceId: input.advanceId,
        paymentMethod: input.paymentMethod,
        hasInvoice: input.hasInvoice,
        notes: input.notes,
        status: "POSTED",
      };
      const journalEntry = postExpense(expense, newId("je"), `EXP-${expense.id.slice(-6)}`);
      db.expenses.create(expense);
      db.journalEntries.create(journalEntry);
      refresh();
    },
    [refresh],
  );

  const addAdvance = useCallback(
    (input: NewAdvanceInput) => {
      const advance: AdvanceTransaction = {
        id: newId("adv"),
        date: input.date,
        fromPartyId: input.fromPartyId,
        custodianId: input.custodianId,
        amount: input.amount,
        projectId: input.projectId,
        paymentMethod: input.paymentMethod,
        reference: input.reference,
        notes: input.notes,
      };
      const journalEntry = postAdvance(advance, newId("je"), `ADV-${advance.id.slice(-6)}`);
      db.advances.create(advance);
      db.journalEntries.create(journalEntry);
      refresh();
    },
    [refresh],
  );

  const addSupplierPayment = useCallback(
    (input: NewSupplierPaymentInput) => {
      const payment: SupplierPaymentTransaction = {
        id: newId("pay"),
        date: input.date,
        supplierId: input.supplierId,
        amount: input.amount,
        sourceType: input.sourceType,
        sourcePartyId: input.sourcePartyId,
        reference: input.reference,
        notes: input.notes,
      };
      const journalEntry = postSupplierPayment(payment, newId("je"), `PAY-${payment.id.slice(-6)}`);
      db.supplierPayments.create(payment);
      db.journalEntries.create(journalEntry);
      refresh();
    },
    [refresh],
  );

  const addProject = useCallback(
    (input: Omit<Project, "id">) => {
      db.projects.create({ id: newId("proj"), ...input });
      refresh();
    },
    [refresh],
  );

  // ---------------------------------------------------------------------
  // Custody settlements
  // ---------------------------------------------------------------------

  const addCustodySettlement = useCallback(
    (input: NewCustodySettlementInput) => {
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
        const entry = postCashReturn(settlement, newId("je"), `STL-${settlement.id.slice(-6)}`);
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
  // Subcontractors
  // ---------------------------------------------------------------------

  const addSubcontractorAdvance = useCallback(
    (input: NewSubcontractorAdvanceInput) => {
      const contract = db.subcontracts.getById(input.contractId);
      if (!contract) throw new Error("Contract not found.");

      const advance: SubcontractorAdvance = {
        id: newId("subadv"),
        contractId: input.contractId,
        date: input.date,
        amount: input.amount,
        paymentSourceType: input.paymentSourceType,
        paymentSourcePartyId: input.paymentSourcePartyId,
        paymentMethod: input.paymentMethod,
        reference: input.reference,
        notes: input.notes,
      };
      const entry = postSubcontractorAdvance(
        advance,
        contract.subcontractorId,
        contract.projectId,
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

      const contract = db.subcontracts.getById(cert.contractId);
      if (!contract) throw new Error("Contract not found.");

      const entries = db.journalEntries.getAll();
      const availableAdvanceBalance = subcontractorAdvanceBalance(entries, cert.subcontractorId, cert.projectId);
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

      const payment: SubcontractorPaymentTransaction = {
        id: newId("subpay"),
        date: input.date,
        subcontractorId: cert.subcontractorId,
        certificateId: input.certificateId,
        amount: input.amount,
        sourceType: input.sourceType,
        sourcePartyId: input.sourcePartyId,
        reference: input.reference,
        notes: input.notes,
      };
      const entry = postSubcontractorPayment(payment, newId("je"), `SPAY-${payment.id.slice(-6)}`);
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
      addProject,
      addCustodySettlement,
      discardDraftSettlement,
      finalizeCustodySettlement,
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
      addProject,
      addCustodySettlement,
      discardDraftSettlement,
      finalizeCustodySettlement,
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
