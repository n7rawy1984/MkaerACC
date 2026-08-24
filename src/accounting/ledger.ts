import type {
  CustodySettlement,
  ExpenseTransaction,
  JournalEntry,
  Project,
  SubcontractorPaymentTransaction,
} from "../domain/types";
import { addMoney, subtractMoney } from "../domain/money";
import { ACCOUNTS } from "./chartOfAccounts";

type NormalSide = "DEBIT" | "CREDIT";

/**
 * Balance of an account, optionally scoped to one party (custodian, owner,
 * or supplier) and/or one project, expressed on its natural side. Assets
 * and expenses read naturally as debit balances; liabilities read
 * naturally as credit balances.
 */
function accountBalance(
  entries: JournalEntry[],
  accountId: string,
  normalSide: NormalSide,
  opts: { partyId?: string; projectId?: string } = {},
): number {
  let debit = 0;
  let credit = 0;
  for (const entry of entries) {
    for (const l of entry.lines) {
      if (l.accountId !== accountId) continue;
      if (opts.partyId && l.partyId !== opts.partyId) continue;
      if (opts.projectId && l.projectId !== opts.projectId) continue;
      debit = addMoney(debit, l.debit);
      credit = addMoney(credit, l.credit);
    }
  }
  return normalSide === "DEBIT" ? subtractMoney(debit, credit) : subtractMoney(credit, debit);
}

/** Remaining custody balance still held by a custodian (advances minus expenses charged). */
export function custodianBalance(entries: JournalEntry[], custodianPartyId: string): number {
  return accountBalance(entries, ACCOUNTS.ADVANCE_CUSTODY, "DEBIT", { partyId: custodianPartyId });
}

export function totalOpenCustodianAdvances(entries: JournalEntry[], custodianPartyIds: string[]): number {
  return custodianPartyIds.reduce((sum, id) => addMoney(sum, custodianBalance(entries, id)), 0);
}

/** Amount the company currently owes an owner for expenses/advances funded personally. */
export function ownerCurrentBalance(entries: JournalEntry[], ownerPartyId: string): number {
  return accountBalance(entries, ACCOUNTS.OWNER_CURRENT, "CREDIT", { partyId: ownerPartyId });
}

/** Amount currently owed to a supplier. */
export function supplierPayableBalance(entries: JournalEntry[], supplierPartyId: string): number {
  return accountBalance(entries, ACCOUNTS.ACCOUNTS_PAYABLE, "CREDIT", { partyId: supplierPartyId });
}

export function totalSupplierPayables(entries: JournalEntry[], supplierPartyIds: string[]): number {
  return supplierPartyIds.reduce((sum, id) => addMoney(sum, supplierPayableBalance(entries, id)), 0);
}

/** Direct (non-subcontractor) expense cost posted to a project. */
export function directExpenseCost(entries: JournalEntry[], projectId?: string): number {
  return accountBalance(entries, ACCOUNTS.PROJECT_COST, "DEBIT", { projectId });
}

/** Subcontractor cost recognized on APPROVED certificates only — DRAFT certificates never post. */
export function subcontractorCertifiedCost(entries: JournalEntry[], projectId?: string): number {
  return accountBalance(entries, ACCOUNTS.PROJECT_COST_SUBCONTRACTORS, "DEBIT", { projectId });
}

/** True total project cost = direct expenses + subcontractor certified work, recognized exactly
 * once each (subcontractor advances/payments never appear here — only certificate approval does). */
export function totalProjectCost(entries: JournalEntry[], projectId?: string): number {
  return addMoney(directExpenseCost(entries, projectId), subcontractorCertifiedCost(entries, projectId));
}

export function totalCompanyExpense(entries: JournalEntry[]): number {
  return accountBalance(entries, ACCOUNTS.COMPANY_EXPENSE, "DEBIT");
}

export function totalInputVat(entries: JournalEntry[], projectId?: string): number {
  return accountBalance(entries, ACCOUNTS.INPUT_VAT, "DEBIT", { projectId });
}

export function expensesWithoutInvoice(expenses: ExpenseTransaction[]): ExpenseTransaction[] {
  return expenses.filter((e) => !e.hasInvoice && e.status === "POSTED");
}

export interface CategoryCost {
  categoryId: string;
  amount: number;
}

/** Cost grouped by expense category, using net amount (VAT excluded — it is recoverable, not cost). */
export function costByCategory(expenses: ExpenseTransaction[], projectId?: string): CategoryCost[] {
  const map = new Map<string, number>();
  for (const e of expenses) {
    if (e.status !== "POSTED") continue;
    if (projectId && e.projectId !== projectId) continue;
    map.set(e.categoryId, addMoney(map.get(e.categoryId) ?? 0, e.netAmount));
  }
  return [...map.entries()].map(([categoryId, amount]) => ({ categoryId, amount }));
}

export interface LedgerLine {
  date: string;
  reference: string;
  description: string;
  debit: number;
  credit: number;
  balance: number;
}

/**
 * Chronological ledger for one party against one control account (Owner
 * Current or Advance/Custody), with a running balance on the account's
 * natural side. Used for the person-level ledger views.
 */
export function partyLedger(
  entries: JournalEntry[],
  accountId: string,
  partyId: string,
  normalSide: NormalSide,
): LedgerLine[] {
  const rows: Omit<LedgerLine, "balance">[] = [];
  for (const entry of [...entries].sort((a, b) => (a.date < b.date ? -1 : 1))) {
    for (const l of entry.lines) {
      if (l.accountId !== accountId || l.partyId !== partyId) continue;
      rows.push({
        date: entry.date,
        reference: entry.reference,
        description: entry.description,
        debit: l.debit,
        credit: l.credit,
      });
    }
  }
  let running = 0;
  return rows.map((row) => {
    running =
      normalSide === "DEBIT"
        ? addMoney(running, subtractMoney(row.debit, row.credit))
        : addMoney(running, subtractMoney(row.credit, row.debit));
    return { ...row, balance: running };
  });
}

export interface ProjectCostSummary {
  project: Project;
  totalCost: number;
}

export function costByProject(entries: JournalEntry[], projects: Project[]): ProjectCostSummary[] {
  return projects.map((project) => ({
    project,
    totalCost: totalProjectCost(entries, project.id),
  }));
}

// ============================================================================
// PHASE 2A — Subcontractors
// ============================================================================

export function subcontractorPayableBalance(entries: JournalEntry[], subcontractorId: string): number {
  return accountBalance(entries, ACCOUNTS.SUBCONTRACTOR_PAYABLE, "CREDIT", { partyId: subcontractorId });
}

export function totalSubcontractorPayables(entries: JournalEntry[], subcontractorIds: string[]): number {
  return subcontractorIds.reduce((sum, id) => addMoney(sum, subcontractorPayableBalance(entries, id)), 0);
}

/** Available (unrecovered) advance balance for a subcontractor, optionally scoped to one project/contract. */
export function subcontractorAdvanceBalance(
  entries: JournalEntry[],
  subcontractorId: string,
  projectId?: string,
): number {
  return accountBalance(entries, ACCOUNTS.SUBCONTRACTOR_ADVANCE, "DEBIT", { partyId: subcontractorId, projectId });
}

export function subcontractorRetentionHeld(
  entries: JournalEntry[],
  subcontractorId: string,
  projectId?: string,
): number {
  return accountBalance(entries, ACCOUNTS.SUBCONTRACTOR_RETENTION_PAYABLE, "CREDIT", {
    partyId: subcontractorId,
    projectId,
  });
}

export function totalRetentionHeld(entries: JournalEntry[], subcontractorIds: string[]): number {
  return subcontractorIds.reduce((sum, id) => addMoney(sum, subcontractorRetentionHeld(entries, id)), 0);
}

/** Amount already paid against one certificate — derived from payment records, not the journal,
 * since payments are certificate-scoped for status tracking (PARTIALLY_PAID / PAID). */
export function certificatePaidAmount(
  payments: SubcontractorPaymentTransaction[],
  certificateId: string,
): number {
  return payments
    .filter((p) => p.certificateId === certificateId)
    .reduce((sum, p) => addMoney(sum, p.amount), 0);
}

// ============================================================================
// PHASE 2A — Custody Settlements
// ============================================================================

export function cashReturnedByCustodian(settlements: CustodySettlement[], custodianId: string): number {
  return settlements
    .filter((s) => s.custodianId === custodianId && s.status === "SETTLED")
    .reduce((sum, s) => addMoney(sum, s.cashReturnAmount), 0);
}

export function lastSettlementDate(settlements: CustodySettlement[], custodianId: string): string | undefined {
  const dates = settlements
    .filter((s) => s.custodianId === custodianId && s.status === "SETTLED" && s.settledAt)
    .map((s) => s.settledAt as string);
  if (dates.length === 0) return undefined;
  return dates.reduce((latest, d) => (d > latest ? d : latest));
}
