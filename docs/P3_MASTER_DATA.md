# P3 Core Production Master Data

P3 is implemented by `20260829120000_p3_core_master_data.sql` and verified on the linked synthetic-only `MakerACC-Development` project. It creates no journals, accounting transactions, demo import, or frontend Supabase data path.

## Tables and ownership

- `companies` is the P2 authorization parent extended with `legal_name`, `trn`, `address`, `notes`, and actor UUIDs. It was not duplicated.
- `projects` is a company-owned cost-center/analytic dimension. It is never a GL account. Optional contract value and budget use `BIGINT` minor units.
- `parties` is the shared company-owned master for owners, custodians, suppliers, employees, subcontractors, and other parties. Supplier/subcontractor contact details are not duplicated elsewhere.
- `expense_categories` remains a simple company-owned classification. The current domain decides project cost versus company expense from the transaction's project dimension, so P3 does not invent a category-level classification.
- `accounts` is the company chart of accounts with optional same-company parent, party-control marker, status, and stable system key.
- `treasury_accounts` owns one immutable, unique, same-company ASSET GL mapping and an optional same-company project.
- `subcontracts` is the project/subcontractor contract master only. Certificates, payments, journals, and posting commands are outside P3.

All important parents use `ON DELETE RESTRICT`. Master records carry nullable `created_by`/`updated_by` references so bootstrap/import tooling can explicitly have no human actor without inventing an Auth user. Normal trusted workflows should supply the real actor. Timestamps are database-managed.

## Code scopes

All code comparisons are trimmed and case-insensitive:

- Company code: globally unique.
- Project, party (when present), expense-category, account, and treasury codes: unique within company.
- Subcontract contract number: unique within project.
- System account key: unique within company.

These are master-data identifiers, not the future server-generated transaction references.

## Money and percentages

Every persisted P3 money value uses signed/non-negative-by-context `BIGINT` AED minor units. Subcontract retention uses integer basis points from 0 through 10,000. Revised subcontract value remains derived from `original_contract_value_minor + approved_variations_minor`; the database enforces a non-negative result and stores no redundant revised value.

## System-account strategy

Future P5 commands resolve stable accounting roles with the nullable `accounts.system_key` enum and a unique `(company_id, system_key)` index. They never resolve by account display name and never hardcode UUIDs. Frozen keys are:

- `INPUT_VAT`
- `CUSTODY_ADVANCE`
- `SUPPLIER_PAYABLE`
- `OWNER_CURRENT`
- `SUBCONTRACTOR_ADVANCE`
- `SUBCONTRACTOR_PAYABLE`
- `SUBCONTRACTOR_RETENTION_PAYABLE`
- `PROJECT_COST`
- `PROJECT_COST_SUBCONTRACTORS`
- `COMPANY_EXPENSE`

Treasury funding does not use a system key: every treasury row points directly to its own permanent GL account identity.

## Cross-dimensional enforcement

Composite foreign keys enforce same-company project, party, parent-account, treasury-GL, treasury-project, subcontract-project, and subcontract-party relationships. Focused fixed-search-path triggers additionally require treasury GLs to be ASSET accounts, freeze treasury company/GL identity, require subcontract parties to be active subcontractors for new assignments, reject new contracts on closed projects, and prevent a referenced subcontractor party from changing type.

## Security baseline

All six new public tables have RLS enabled and forced. Authenticated reads require the existing verified `is_company_member(company_id)` helper. There are no browser write policies or grants and no anon access. `service_role` receives only SELECT/INSERT/UPDATE; DELETE remains withheld. Full role/project-sensitive P4 authorization remains the next phase.

## Development verification

The synthetic matrix passed for global/company/project code scopes, party ownership, category and system-key uniqueness, separate treasury GL identities, treasury immutability, cross-company GL/project/party rejection, subcontract party type, retention bounds, contract-number uniqueness, browser/anon denial, service DELETE denial, and Company A versus Company B read isolation. Final migration dry-run is up to date and database lint reports no schema errors.
