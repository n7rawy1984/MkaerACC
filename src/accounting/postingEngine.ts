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
 * A fully-resolved funding/payment source, ready to post as one journal
 * line: which GL account to hit, and which party (if any) to scope it to.
 * Callers resolve this in AppDataContext (see resolveFundingSource there,
 * Phase 2B.1A) — the posting engine stays pure and never touches storage.
 */
export interface ResolvedFundingSource {
  glAccountId: string;
  partyId?: string;
}

/**
 * Expense transaction posting covers several of the spec's transaction types
 * depending on paidFromType: custodian-funded, owner-paid, treasury-funded,
 * and supplier credit purchase all flow through here since the only thing
 * that changes is the credit side. `resolved` is required for CUSTODIAN,
 * OWNER, and TREASURY; legacy CASH/BANK records (pre-2B.1A, no longer
 * produced by the Expense form) and SUPPLIER_CREDIT don't need it.
 */
export function postExpense(
  expense: ExpenseTransaction,
  resolved: ResolvedFundingSource | undefined,
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
    case "OWNER":
    case "TREASURY":
      lines.push(
        line(resolved!.glAccountId, {
          credit: expense.totalAmount,
          partyId: resolved!.partyId,
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
    case "CASH": // legacy — no longer produced by the Expense form, see TREASURY
      lines.push(line(ACCOUNTS.CASH, { credit: expense.totalAmount, projectId: expense.projectId }));
      break;
    case "BANK": // legacy — no longer produced by the Expense form, see TREASURY
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

/**
 * Advance / funding: cash custody is handed to a custodian. The credit side
 * is whatever funding source the caller resolved (a treasury account's own
 * GL account, or Owner Current Account, party-scoped — see
 * AppDataContext.resolveFundingSource). Project is always just a dimension
 * on both lines — never the credited account itself.
 */
export function postAdvance(
  advance: AdvanceTransaction,
  resolved: ResolvedFundingSource,
  journalId: string,
  reference: string,
): JournalEntry {
  const lines: JournalLine[] = [
    line(ACCOUNTS.ADVANCE_CUSTODY, {
      debit: advance.amount,
      partyId: advance.custodianId,
      projectId: advance.projectId,
    }),
    line(resolved.glAccountId, {
      credit: advance.amount,
      partyId: resolved.partyId,
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

/** Supplier payment settles Accounts Payable from a treasury account, a custodian, or an owner.
 * `resolved` is required for TREASURY/CUSTODIAN/OWNER; legacy CASH/BANK records don't need it. */
export function postSupplierPayment(
  payment: SupplierPaymentTransaction,
  resolved: ResolvedFundingSource | undefined,
  journalId: string,
  reference: string,
): JournalEntry {
  const lines: JournalLine[] = [
    line(ACCOUNTS.ACCOUNTS_PAYABLE, { debit: payment.amount, partyId: payment.supplierId }),
  ];

  switch (payment.sourceType) {
    case "TREASURY":
    case "CUSTODIAN":
    case "OWNER":
      lines.push(line(resolved!.glAccountId, { credit: payment.amount, partyId: resolved!.partyId }));
      break;
    case "CASH": // legacy
      lines.push(line(ACCOUNTS.CASH, { credit: payment.amount }));
      break;
    case "BANK": // legacy
      lines.push(line(ACCOUNTS.BANK, { credit: payment.amount }));
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
 * posted again here. Called once, when a settlement is finalized. `resolved`
 * is required for TREASURY/OWNER; legacy CASH/BANK records don't need it.
 */
export function postCashReturn(
  settlement: CustodySettlement,
  resolved: ResolvedFundingSource | undefined,
  journalId: string,
  reference: string,
): JournalEntry {
  const lines: JournalLine[] = [];

  switch (settlement.cashReturnDestinationType) {
    case "TREASURY":
    case "OWNER":
      lines.push(line(resolved!.glAccountId, { debit: settlement.cashReturnAmount, partyId: resolved!.partyId }));
      break;
    case "BANK": // legacy
      lines.push(line(ACCOUNTS.BANK, { debit: settlement.cashReturnAmount }));
      break;
    case "CASH": // legacy
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
 * stores contractId, so the caller resolves and passes these dimensions). `resolved` is required
 * for TREASURY/OWNER/CUSTODIAN; legacy CASH/BANK records don't need it. */
export function postSubcontractorAdvance(
  advance: SubcontractorAdvance,
  subcontractorId: string,
  projectId: string,
  resolved: ResolvedFundingSource | undefined,
  journalId: string,
  reference: string,
): JournalEntry {
  const lines: JournalLine[] = [
    line(ACCOUNTS.SUBCONTRACTOR_ADVANCE, {
      debit: advance.amount,
      partyId: subcontractorId,
      projectId,
      contractId: advance.contractId,
    }),
  ];

  switch (advance.paymentSourceType) {
    case "TREASURY":
    case "OWNER":
    case "CUSTODIAN":
      lines.push(
        line(resolved!.glAccountId, {
          credit: advance.amount,
          partyId: resolved!.partyId,
          projectId,
          contractId: advance.contractId,
        }),
      );
      break;
    case "BANK": // legacy
      lines.push(line(ACCOUNTS.BANK, { credit: advance.amount, projectId, contractId: advance.contractId }));
      break;
    case "CASH": // legacy
    default:
      lines.push(line(ACCOUNTS.CASH, { credit: advance.amount, projectId, contractId: advance.contractId }));
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
      contractId: certificate.contractId,
    }),
  ];

  if (certificate.vatAmount > 0) {
    lines.push(
      line(ACCOUNTS.INPUT_VAT, {
        debit: certificate.vatAmount,
        projectId: certificate.projectId,
        contractId: certificate.contractId,
      }),
    );
  }

  if (certificate.retentionAmount > 0) {
    lines.push(
      line(ACCOUNTS.SUBCONTRACTOR_RETENTION_PAYABLE, {
        credit: certificate.retentionAmount,
        partyId: certificate.subcontractorId,
        projectId: certificate.projectId,
        contractId: certificate.contractId,
      }),
    );
  }

  if (certificate.advanceRecovery > 0) {
    lines.push(
      line(ACCOUNTS.SUBCONTRACTOR_ADVANCE, {
        credit: certificate.advanceRecovery,
        partyId: certificate.subcontractorId,
        projectId: certificate.projectId,
        contractId: certificate.contractId,
      }),
    );
  }

  for (const deduction of certificate.deductionLines) {
    lines.push(
      line(deduction.accountId, {
        credit: deduction.amount,
        partyId: certificate.subcontractorId,
        projectId: certificate.projectId,
        contractId: certificate.contractId,
      }),
    );
  }

  lines.push(
    line(ACCOUNTS.SUBCONTRACTOR_PAYABLE, {
      credit: certificate.netPayable,
      partyId: certificate.subcontractorId,
      projectId: certificate.projectId,
      contractId: certificate.contractId,
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

/** Settling the payable never changes Project Cost, certified amount, or retention. `resolved`
 * is required for TREASURY/CUSTODIAN/OWNER; legacy CASH/BANK records don't need it. `projectId` is
 * the certificate's project (Phase 2B.2) — dimension only, never stored redundantly on the payment
 * record itself. `payment.contractId` (also Phase 2B.2) tags both lines when known. */
export function postSubcontractorPayment(
  payment: SubcontractorPaymentTransaction,
  projectId: string | undefined,
  resolved: ResolvedFundingSource | undefined,
  journalId: string,
  reference: string,
): JournalEntry {
  const lines: JournalLine[] = [
    line(ACCOUNTS.SUBCONTRACTOR_PAYABLE, {
      debit: payment.amount,
      partyId: payment.subcontractorId,
      projectId,
      contractId: payment.contractId,
    }),
  ];

  switch (payment.sourceType) {
    case "TREASURY":
    case "CUSTODIAN":
    case "OWNER":
      lines.push(
        line(resolved!.glAccountId, {
          credit: payment.amount,
          partyId: resolved!.partyId,
          projectId,
          contractId: payment.contractId,
        }),
      );
      break;
    case "BANK": // legacy
      lines.push(line(ACCOUNTS.BANK, { credit: payment.amount, projectId, contractId: payment.contractId }));
      break;
    case "CASH": // legacy
    default:
      lines.push(line(ACCOUNTS.CASH, { credit: payment.amount, projectId, contractId: payment.contractId }));
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
