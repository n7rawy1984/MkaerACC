**2026-11-05 — local opening/count integration:** existing GL workflows are preserved. Scoped certified opening deltas are shown separately from funding/receipts; physical cash counts and immutable reviews are available in Treasury Accounts, with no automatic adjustment or reimbursement netting. Full Company opening completeness, bank matching and intraday reconstruction are not claimed. Canonical78 is local/unapplied; linked77 remains hosted. [Implementation, exact scope and verification](CERTIFIED_OPENINGS_AND_CASH_RECONCILIATION.md). Earlier limitations below describe the preceding increment.

**2026-11-04 local integration update:** The supported funding/withdrawal/personal reimbursement increment now reuses this capability. CASH was supported by canonical75; the former UI-only prohibition is removed with new migration77 recorded-funds safeguards. Approved new release order is local76→77, then matching frontend, after recovery/impact/explicit approval. Classified controls, direct-holder source tracing, separate personal payables and bilingual report integration are documented in [Financial Operations Integration](FINANCIAL_OPERATIONS_INTEGRATION.md). Nothing in this update is hosted-activated; older scope limitations below remain historical.

# Operational Go-Live — custody reconciliation

Implemented locally on 2026-11-04. This is the next bounded CUS-03 increment, not completion of the Treasury/Custody program or authorization for production import/publication.

Operational Go-Live is the immediate roadmap priority. Existing M3 implementation through migration 75 is preserved. Remaining M3/CON requirements remain incomplete and are deferred behind this operational priority.

## Delivered workflow

Treasury Accounts and Accounting Reports now expose the same reusable custody statement. Select a Company-authorized accountable person, dates and all Projects, one Project or unassigned activity. Primary Custodians and Employees with the existing secondary Custodian role are supported, including inactive historical holders. Existing Company-wide Accounting Admin/Accountant and read-only Management Viewer reporting scopes remain authoritative; no own-person restriction or new permission is invented.

The screen and bilingual Excel/PDF expose opening posted movement, period funding, gross Expense spending, returns, signed period operating difference, other movements and closing GL receivable. Each transaction retains its actual date, original source reference, Project dimension, journal reference, current source status and explicit reversal status. Exports additionally retain source UUIDs for audit. Monetary computations use exact BIGINT strings throughout, reusing the existing export precision safeguards.

Period difference = funding − spending − returns. Closing = opening + period difference + other movements. A negative period difference can be funded by a prior-period opening. Neither a negative period difference nor a negative Project slice establishes employee debt, reimbursement entitlement or physical cash. Project-filtered balances are analytic slices, not the pooled Company/person balance. Unassigned cash returns are never inferred into a Project. Unclassified historical journals are separated for review rather than invented as funding or expenditure.

The existing statement reader validates complete balanced journals, Company/dimension/source links, current reporting authority, keyset pagination and capture stability. The wrapper requires complete all-type account activity before deriving custody totals; it includes only the CUSTODY_ADVANCE control account, never salary/other Party balances. Existing operational settlement references are shown separately; finalization adds no journal and does not recognize cost again. Period settlement history does not prove every Expense has been settled.

Arabic RTL/English LTR use existing components, five themes, keyboard-focusable scroll regions, clear errors/loading/empty states and stale-filter/session invalidation. No financial command is added or exposed. The existing custodian Expense command continues to reject spending beyond the pooled funded balance. This increment introduces no path to negative physical cash and makes no new claim about Treasury cash sufficiency across historical openings.

A blank bilingual Excel/PDF evidence template covers dates, original source documents, Company/Party/optional Project IDs, transaction type, funding, approved spending, returns, reimbursement, classification, description, supporting references and review status. Amount fields explicitly use integer AED minor units. Scope starts August 2026; there are no invented data rows or opening balances. This is an evidence collection format, not an implemented importer, opening-entry command or automatic GL mapping.

## Changed files

New product files: `src/reports/CustodyReconciliation.tsx` and `src/reports/custodyReconciliation.ts`. Integration: `src/app/TenantReadyApplication.tsx` and `src/workspace/WorkspaceReports.tsx`. Focused fixtures/checks: `scripts/custody-reconciliation-{fixture,browser-server}.mjs`, `scripts/fixtures/custody-reconciliation.tsx`, `scripts/verify-custody-reconciliation{,-browser}.mjs` and `scripts/verify-custody-reconciliation-exports.py`. Canonical roadmap, handoff and requirements register updated. No migrations changed.

## Verification and boundaries

- 22 focused isolated SQL/model/accounting/authorization checks against canonical migrations through 75: PASS. Actual existing overspend command rejects atomically; journal/Expense/settlement fingerprints remain unchanged. Signed reversal, exact BIGINT, Project/unassigned/empty periods, roles/foreign scopes and unavailable mapping/session paths are covered.
- 25 browser checks: PASS against the actual component backed by isolated canonical SQL. Bilingual desktop1366×768/mobile390×844, signed totals, Project stale state, empty/failure states, management reporting, sign-out, original Expense/return count, template download and read-only RPC transport covered. Five-theme control/layout smoke checks pass; no comprehensive accessibility audit is claimed.
- Five independent generated-artifact inspections: PASS for numeric Excel values, RTL sheets, actual PDF content, Company/person/date/status, signed amounts and blank-template structure.
- Focused lint, Production build and whitespace checks: PASS. Existing build chunk-size advisory remains non-blocking. A screenshot-observed Arabic header wrap was corrected with non-wrapping table headings and monetary cells; no theme/CSS palette changed.
- No hosted connection, schema/migration change, hosted fixture/import/financial write, credentials access, Git publication or deployment. Migration 75 is not reapplied; previously verified hosted alignment is not represented as a fresh live check. No accounting engine, RLS, role, subscription or authentication changes.

Reproducible checks:

```sh
node scripts/verify-custody-reconciliation.mjs
node scripts/verify-custody-reconciliation-browser.mjs
python3 scripts/verify-custody-reconciliation-exports.py
npm run build
npx oxlint src/reports/CustodyReconciliation.tsx src/reports/custodyReconciliation.ts src/app/TenantReadyApplication.tsx src/workspace/WorkspaceReports.tsx
git diff --check
```

Browser verification needs local loopback/Chromium permission. Artifacts and exact check results are generated under `/tmp/narvo-custody-*`; reviewed synthetic evidence is retained in ignored `docs/release/custody-reconciliation/`.

## Definition of done

| Category | Status | Evidence / limits |
|---|---|---|
| Business/accounting | VERIFIED for this statement | Exact posted movements only; no invented reimbursement/opening/cash or duplicate cost |
| Security/authorization | VERIFIED locally | Existing server roles/RLS, tenant and session checks; no write RPC transport |
| Database | VERIFIED locally; migration NOT REQUIRED | Canonical75 fixture, unchanged financial fingerprints; no new schema/grants |
| Deployment | DEFERRED | Local frontend only; hosted operator acceptance and publication not performed |
| Testing | VERIFIED locally | Focused accounting/authorization/browser/export/build/lint checks above |
| Documentation | VERIFIED | Canonical roadmap, handoff and requirements updated; wider scope explicitly incomplete |

## Remaining scope and next increment

Next Operational Go-Live increment: safely expose the existing custody funding/replenishment, custody-funded Expense, return and operational settlement commands to accountants with reviewed exact-money inputs, retry/idempotency and source references. Evaluate Treasury physical-cash/opening evidence and sufficiency before enabling new cash entry paths; do not manufacture opening funding merely to pass a guard.

Still incomplete: full Treasury movement reporting, holder balance portfolio, explicit many-to-many holder/Project master associations (current statement shows actual journal dimensions only), personal-funds reimbursement liability recognition/payment/corrections, item-level outstanding settlement/reimbursement queues, actual cash counts/variance/evidence reconciliation, historical review/import and controlled opening journals. Personal spending requires verified evidence and approved liability/account configuration, not negative custody or fictional cash. August source files have not been supplied or imported. Opening completeness, source classifications and reimbursement evidence must be established before financial import. Wider F0/M3/CON/M4 and R0 recovery/release gates remain open.
