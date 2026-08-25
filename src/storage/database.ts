import { LocalStorageDriver } from "./storageDriver";
import { Repository } from "./repository";
import type {
  Account,
  AdvanceTransaction,
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
  SubcontractorPaymentTransaction,
  SupplierPaymentTransaction,
  TreasuryAccount,
} from "../domain/types";

const driver = new LocalStorageDriver("cas");

// "cas" = Contracting Accounting System. Bumping this version invalidates
// old shapes if the demo needs a clean slate after a model change.
export const SCHEMA_VERSION = "v1";

export const db = {
  companies: new Repository<Company>(driver, `${SCHEMA_VERSION}:companies`),
  projects: new Repository<Project>(driver, `${SCHEMA_VERSION}:projects`),
  parties: new Repository<Party>(driver, `${SCHEMA_VERSION}:parties`),
  categories: new Repository<ExpenseCategory>(driver, `${SCHEMA_VERSION}:categories`),
  accounts: new Repository<Account>(driver, `${SCHEMA_VERSION}:accounts`),
  expenses: new Repository<ExpenseTransaction>(driver, `${SCHEMA_VERSION}:expenses`),
  advances: new Repository<AdvanceTransaction>(driver, `${SCHEMA_VERSION}:advances`),
  supplierPayments: new Repository<SupplierPaymentTransaction>(
    driver,
    `${SCHEMA_VERSION}:supplierPayments`,
  ),
  journalEntries: new Repository<JournalEntry>(driver, `${SCHEMA_VERSION}:journalEntries`),

  // Phase 2A
  custodySettlements: new Repository<CustodySettlement>(driver, `${SCHEMA_VERSION}:custodySettlements`),
  subcontracts: new Repository<Subcontract>(driver, `${SCHEMA_VERSION}:subcontracts`),
  subcontractorAdvances: new Repository<SubcontractorAdvance>(
    driver,
    `${SCHEMA_VERSION}:subcontractorAdvances`,
  ),
  subcontractorCertificates: new Repository<SubcontractorCertificate>(
    driver,
    `${SCHEMA_VERSION}:subcontractorCertificates`,
  ),
  subcontractorPayments: new Repository<SubcontractorPaymentTransaction>(
    driver,
    `${SCHEMA_VERSION}:subcontractorPayments`,
  ),

  // Phase 2B.1
  treasuryAccounts: new Repository<TreasuryAccount>(driver, `${SCHEMA_VERSION}:treasuryAccounts`),
};

export function isDatabaseEmpty(): boolean {
  return db.projects.isEmpty() && db.parties.isEmpty();
}

export function clearAll(): void {
  for (const repo of Object.values(db)) repo.replaceAll([]);
}

function newId(prefix: string): string {
  return `${prefix}_${Math.random().toString(36).slice(2, 10)}`;
}

export { newId };
