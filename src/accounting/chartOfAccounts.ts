import type { Account } from "../domain/types";

// Fixed control accounts. Party-specific balances (which owner, which
// custodian, which supplier) are carried on the JournalLine.partyId
// dimension rather than by minting a new GL account per party — this
// keeps the chart of accounts small while still allowing per-party
// sub-ledgers to be derived (see accounting/ledger.ts).
export const ACCOUNTS = {
  CASH: "acc_cash",
  BANK: "acc_bank",
  ADVANCE_CUSTODY: "acc_advance_custody",
  INPUT_VAT: "acc_input_vat",
  PROJECT_COST: "acc_project_cost",
  COMPANY_EXPENSE: "acc_company_expense",
  ACCOUNTS_PAYABLE: "acc_accounts_payable",
  OWNER_CURRENT: "acc_owner_current",

  // Phase 2A — Subcontractors
  PROJECT_COST_SUBCONTRACTORS: "acc_project_cost_subcontractors",
  SUBCONTRACTOR_ADVANCE: "acc_subcontractor_advance",
  SUBCONTRACTOR_RETENTION_PAYABLE: "acc_subcontractor_retention_payable",
  SUBCONTRACTOR_PAYABLE: "acc_subcontractor_payable",
  DEDUCTION_COMPANY_MATERIALS: "acc_deduction_company_materials",
  DEDUCTION_BACKCHARGE: "acc_deduction_backcharge",
  DEDUCTION_OTHER: "acc_deduction_other",
} as const;

export const CHART_OF_ACCOUNTS: Account[] = [
  { id: ACCOUNTS.CASH, code: "1000", name: "Cash on Hand", type: "ASSET" },
  { id: ACCOUNTS.BANK, code: "1100", name: "Bank Account", type: "ASSET" },
  {
    id: ACCOUNTS.ADVANCE_CUSTODY,
    code: "1200",
    name: "Advance / Custody Account",
    type: "ASSET",
    requiresParty: true,
  },
  { id: ACCOUNTS.INPUT_VAT, code: "1300", name: "Input VAT Recoverable", type: "ASSET" },
  { id: ACCOUNTS.PROJECT_COST, code: "5000", name: "Project Costs", type: "EXPENSE" },
  { id: ACCOUNTS.COMPANY_EXPENSE, code: "5100", name: "Company Expenses", type: "EXPENSE" },
  {
    id: ACCOUNTS.ACCOUNTS_PAYABLE,
    code: "2100",
    name: "Accounts Payable - Suppliers",
    type: "LIABILITY",
    requiresParty: true,
  },
  {
    id: ACCOUNTS.OWNER_CURRENT,
    code: "2200",
    name: "Owner Current Account",
    type: "LIABILITY",
    requiresParty: true,
  },

  // Phase 2A — Subcontractors
  {
    id: ACCOUNTS.PROJECT_COST_SUBCONTRACTORS,
    code: "5010",
    name: "Project Cost - Subcontractors",
    type: "EXPENSE",
  },
  {
    id: ACCOUNTS.SUBCONTRACTOR_ADVANCE,
    code: "1210",
    name: "Subcontractor Advance",
    type: "ASSET",
    requiresParty: true,
  },
  {
    id: ACCOUNTS.SUBCONTRACTOR_RETENTION_PAYABLE,
    code: "2110",
    name: "Subcontractor Retention Payable",
    type: "LIABILITY",
    requiresParty: true,
  },
  {
    id: ACCOUNTS.SUBCONTRACTOR_PAYABLE,
    code: "2120",
    name: "Subcontractor Accounts Payable",
    type: "LIABILITY",
    requiresParty: true,
  },
  {
    id: ACCOUNTS.DEDUCTION_COMPANY_MATERIALS,
    code: "4100",
    name: "Recovery - Company Materials Supplied",
    type: "INCOME",
  },
  {
    id: ACCOUNTS.DEDUCTION_BACKCHARGE,
    code: "4110",
    name: "Recovery - Subcontractor Backcharges",
    type: "INCOME",
  },
  {
    id: ACCOUNTS.DEDUCTION_OTHER,
    code: "4120",
    name: "Recovery - Other Certificate Deductions",
    type: "INCOME",
  },
];

/** The small fixed set of accounts a certificate deduction line may be mapped to. */
export const DEDUCTION_ACCOUNT_IDS = [
  ACCOUNTS.DEDUCTION_COMPANY_MATERIALS,
  ACCOUNTS.DEDUCTION_BACKCHARGE,
  ACCOUNTS.DEDUCTION_OTHER,
] as const;
