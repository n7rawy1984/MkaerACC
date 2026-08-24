import type {
  AdvanceTransaction,
  CustodySettlement,
  ExpenseTransaction,
  JournalEntry,
  JournalLine,
  JournalSourceType,
  SubcontractorAdvance,
  SubcontractorCertificate,
  SubcontractorPaymentTransaction,
  SupplierPaymentTransaction,
} from "../domain/types";
import { addMoney, toCents } from "../domain/money";
import { ACCOUNTS } from "./chartOfAccounts";

export class UnbalancedJournalError extends Error {
  constructor(entry: { reference: string }, debitTotal: number, creditTotal: number) {
    super(
      `Journal entry ${entry.reference} is not balanced: debits ${debitTotal} !== credits ${creditTotal}. ` +
        `This indicates a bug in the posting engine and must be fixed before this transaction can be posted.`,
    );
    this.name = "UnbalancedJournalError";
  }
}

/** Total debits must equal total credits, compared in integer cents. */
export function isBalanced(lines: JournalLine[]): boolean {
  const debitCents = lines.reduce((sum, l) => sum + toCents(l.debit), 0);
  const creditCents = lines.reduce((sum, l) => sum + toCents(l.credit), 0);
  return debitCents === creditCents;
}

function buildEntry(
  id: string,
  date: string,
  reference: string,
  description: string,
  sourceType: JournalSourceType,
  sourceId: string,
  lines: JournalLine[],
): JournalEntry {
  const entry: JournalEntry = { id, date, reference, description, sourceType, sourceId, lines };
  if (!isBalanced(lines)) {
    const debitTotal = lines.reduce((s, l) => addMoney(s, l.debit), 0);
    const creditTotal = lines.reduce((s, l) => addMoney(s, l.credit), 0);
    throw new UnbalancedJournalError(entry, debitTotal, creditTotal);
  }
  return entry;
}

function line(accountId: string, opts: Partial<JournalLine> = {}): JournalLine {
  return { accountId, debit: 0, credit: 0, ...opts };
}

/**
 * Expense transaction posting covers three of the spec's transaction types
 * depending on paidFromType: custodian-funded, owner-paid, and supplier
 * credit purchase all flow through here since the only thing that changes
 * is the credit side.
 */
export function postExpense(
  expense: ExpenseTransaction,
  journalId: string,
  reference: string,
): JournalEntry {
  const lines: JournalLine[] = [];
  const costAccount = expense.projectId ? ACCOUNTS.PROJECT_COST : ACCOUNTS.COMPANY_EXPENSE;

  lines.push(line(costAccount, { debit: expense.netAmount, projectId: expense.projectId }));

  if (expense.vatAmount > 0) {
    lines.push(line(ACCOUNTS.INPUT_VAT, { debit: expense.vatAmount, projectId: expense.projectId }));
  }

  switch (expense.paidFromType) {
    case "CUSTODIAN":
      lines.push(
        line(ACCOUNTS.ADVANCE_CUSTODY, {
          credit: expense.totalAmount,
          partyId: expense.paidFromPartyId,
          projectId: expense.projectId,
        }),
      );
      break;
    case "OWNER":
      lines.push(
        line(ACCOUNTS.OWNER_CURRENT, {
          credit: expense.totalAmount,
          partyId: expense.paidFromPartyId,
          projectId: expense.projectId,
        }),
      );
      break;
    case "SUPPLIER_CREDIT":
      lines.push(
        line(ACCOUNTS.ACCOUNTS_PAYABLE, {
          credit: expense.totalAmount,
          partyId: expense.supplierId,
          projectId: expense.projectId,
        }),
      );
      break;
    case "CASH":
      lines.push(line(ACCOUNTS.CASH, { credit: expense.totalAmount, projectId: expense.projectId }));
      break;
    case "BANK":
      lines.push(line(ACCOUNTS.BANK, { credit: expense.totalAmount, projectId: expense.projectId }));
      break;
  }

  return buildEntry(
    journalId,
    expense.date,
    reference,
    expense.description,
    "EXPENSE",
    expense.id,
    lines,
  );
}

/** Advance / funding: an owner (or the company) hands cash custody to a custodian. */
export function postAdvance(
  advance: AdvanceTransaction,
  journalId: string,
  reference: string,
): JournalEntry {
  const lines: JournalLine[] = [
    line(ACCOUNTS.ADVANCE_CUSTODY, {
      debit: advance.amount,
      partyId: advance.custodianId,
      projectId: advance.projectId,
    }),
    line(ACCOUNTS.OWNER_CURRENT, {
      credit: advance.amount,
      partyId: advance.fromPartyId,
      projectId: advance.projectId,
    }),
  ];

  return buildEntry(
    journalId,
    advance.date,
    reference,
    `Cash advance to custodian`,
    "ADVANCE",
    advance.id,
    lines,
  );
}

/** Supplier payment settles Accounts Payable from cash, bank, a custodian, or an owner. */
export function postSupplierPayment(
  payment: SupplierPaymentTransaction,
  journalId: string,
  reference: string,
): JournalEntry {
  const lines: JournalLine[] = [
    line(ACCOUNTS.ACCOUNTS_PAYABLE, { debit: payment.amount, partyId: payment.supplierId }),
  ];

  switch (payment.sourceType) {
    case "CASH":
      lines.push(line(ACCOUNTS.CASH, { credit: payment.amount }));
      break;
    case "BANK":
      lines.push(line(ACCOUNTS.BANK, { credit: payment.amount }));
      break;
    case "CUSTODIAN":
      lines.push(
        line(ACCOUNTS.ADVANCE_CUSTODY, { credit: payment.amount, partyId: payment.sourcePartyId }),
      );
      break;
    case "OWNER":
      lines.push(
        line(ACCOUNTS.OWNER_CURRENT, { credit: payment.amount, partyId: payment.sourcePartyId }),
      );
      break;
  }

  return buildEntry(
    journalId,
    payment.date,
    reference,
    `Supplier payment`,
    "SUPPLIER_PAYMENT",
    payment.id,
    lines,
  );
}

// ============================================================================
// PHASE 2A — Custody Settlements
// ============================================================================

/**
 * A custody settlement's only accounting effect is returning unused cash —
 * the expenses it groups were already posted individually and must never be
 * posted again here. Called once, when a settlement is finalized.
 */
export function postCashReturn(
  settlement: CustodySettlement,
  journalId: string,
  reference: string,
): JournalEntry {
  const lines: JournalLine[] = [];

  switch (settlement.cashReturnDestinationType) {
    case "BANK":
      lines.push(line(ACCOUNTS.BANK, { debit: settlement.cashReturnAmount }));
      break;
    case "OWNER":
      lines.push(
        line(ACCOUNTS.OWNER_CURRENT, {
          debit: settlement.cashReturnAmount,
          partyId: settlement.cashReturnOwnerId,
        }),
      );
      break;
    case "CASH":
    default:
      lines.push(line(ACCOUNTS.CASH, { debit: settlement.cashReturnAmount }));
      break;
  }

  lines.push(
    line(ACCOUNTS.ADVANCE_CUSTODY, {
      credit: settlement.cashReturnAmount,
      partyId: settlement.custodianId,
      projectId: settlement.projectId,
    }),
  );

  return buildEntry(
    journalId,
    settlement.settlementDate,
    reference,
    `Custody cash return - ${settlement.settlementNumber}`,
    "CUSTODY_SETTLEMENT",
    settlement.id,
    lines,
  );
}

// ============================================================================
// PHASE 2A — Subcontractors
// ============================================================================

/** Subcontractor advance is an asset — never project cost until a certificate recovers it.
 * subcontractorId/projectId come from the advance's contract (SubcontractorAdvance itself only
 * stores contractId, so the caller resolves and passes these dimensions). */
export function postSubcontractorAdvance(
  advance: SubcontractorAdvance,
  subcontractorId: string,
  projectId: string,
  journalId: string,
  reference: string,
): JournalEntry {
  const lines: JournalLine[] = [
    line(ACCOUNTS.SUBCONTRACTOR_ADVANCE, {
      debit: advance.amount,
      partyId: subcontractorId,
      projectId,
    }),
  ];

  switch (advance.paymentSourceType) {
    case "BANK":
      lines.push(line(ACCOUNTS.BANK, { credit: advance.amount }));
      break;
    case "OWNER":
      lines.push(line(ACCOUNTS.OWNER_CURRENT, { credit: advance.amount, partyId: advance.paymentSourcePartyId }));
      break;
    case "CUSTODIAN":
      lines.push(
        line(ACCOUNTS.ADVANCE_CUSTODY, { credit: advance.amount, partyId: advance.paymentSourcePartyId }),
      );
      break;
    case "CASH":
    default:
      lines.push(line(ACCOUNTS.CASH, { credit: advance.amount }));
      break;
  }

  return buildEntry(
    journalId,
    advance.date,
    reference,
    `Advance to subcontractor`,
    "SUBCONTRACTOR_ADVANCE",
    advance.id,
    lines,
  );
}

/**
 * Approval posting for a subcontractor progress certificate. This is the
 * only place Project Cost - Subcontractors is ever debited — paying the
 * subcontractor later never touches cost again (see postSubcontractorPayment).
 */
export function postCertificateApproval(
  certificate: SubcontractorCertificate,
  journalId: string,
  reference: string,
): JournalEntry {
  const lines: JournalLine[] = [
    line(ACCOUNTS.PROJECT_COST_SUBCONTRACTORS, {
      debit: certificate.grossCurrentValue,
      projectId: certificate.projectId,
    }),
  ];

  if (certificate.vatAmount > 0) {
    lines.push(line(ACCOUNTS.INPUT_VAT, { debit: certificate.vatAmount, projectId: certificate.projectId }));
  }

  if (certificate.retentionAmount > 0) {
    lines.push(
      line(ACCOUNTS.SUBCONTRACTOR_RETENTION_PAYABLE, {
        credit: certificate.retentionAmount,
        partyId: certificate.subcontractorId,
        projectId: certificate.projectId,
      }),
    );
  }

  if (certificate.advanceRecovery > 0) {
    lines.push(
      line(ACCOUNTS.SUBCONTRACTOR_ADVANCE, {
        credit: certificate.advanceRecovery,
        partyId: certificate.subcontractorId,
        projectId: certificate.projectId,
      }),
    );
  }

  for (const deduction of certificate.deductionLines) {
    lines.push(
      line(deduction.accountId, {
        credit: deduction.amount,
        partyId: certificate.subcontractorId,
        projectId: certificate.projectId,
      }),
    );
  }

  lines.push(
    line(ACCOUNTS.SUBCONTRACTOR_PAYABLE, {
      credit: certificate.netPayable,
      partyId: certificate.subcontractorId,
      projectId: certificate.projectId,
    }),
  );

  return buildEntry(
    journalId,
    certificate.certificateDate,
    reference,
    `Subcontractor certificate ${certificate.certificateNumber} approved`,
    "SUBCONTRACTOR_CERTIFICATE",
    certificate.id,
    lines,
  );
}

/** Settling the payable never changes Project Cost, certified amount, or retention. */
export function postSubcontractorPayment(
  payment: SubcontractorPaymentTransaction,
  journalId: string,
  reference: string,
): JournalEntry {
  const lines: JournalLine[] = [
    line(ACCOUNTS.SUBCONTRACTOR_PAYABLE, { debit: payment.amount, partyId: payment.subcontractorId }),
  ];

  switch (payment.sourceType) {
    case "BANK":
      lines.push(line(ACCOUNTS.BANK, { credit: payment.amount }));
      break;
    case "CUSTODIAN":
      lines.push(
        line(ACCOUNTS.ADVANCE_CUSTODY, { credit: payment.amount, partyId: payment.sourcePartyId }),
      );
      break;
    case "OWNER":
      lines.push(line(ACCOUNTS.OWNER_CURRENT, { credit: payment.amount, partyId: payment.sourcePartyId }));
      break;
    case "CASH":
    default:
      lines.push(line(ACCOUNTS.CASH, { credit: payment.amount }));
      break;
  }

  return buildEntry(
    journalId,
    payment.date,
    reference,
    `Subcontractor payment`,
    "SUBCONTRACTOR_PAYMENT",
    payment.id,
    lines,
  );
}
