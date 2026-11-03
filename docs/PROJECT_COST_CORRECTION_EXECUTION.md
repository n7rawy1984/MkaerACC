# M3 — Project-cost correction execution

Implemented on 2026-11-03: controlled execution extends the existing immutable Expense correction reviews. This is a bounded allocation increment; M3 remains incomplete. Hosted migration and validation status are recorded below and in the release evidence.

## Business and accounting scope

The accounting administrator can execute the latest Project-allocation review for a posted, current-UTC-month cash Expense, using today's server-derived date. The source must have an unchanged canonical two-line original journal, no VAT, supplier/party, settlement history, bank account or Project-restricted Treasury. Source and destination Projects must be active. Company overhead is an explicit supported allocation. Full existing commercial access is required.

The accountant explicitly opens the current scoped correction period with a reason, confirming it is open in the Company's books. Immutable OPEN/CLOSED events are audited; CLOSED is terminal. There is no automatic opening or reopening. These controls govern these new commands only: they do not implement general financial-period closing or authorize reopening an externally closed period. Prior-period sources and dates other than today are blocked.

Before execution the accountant reviews the source, destination, exact amount and date, supplies a verification/document reference and explicitly attests that the cash Expense is unreconciled and has no external settlement or contractual dependency. This is recorded human evidence, not automated reconciliation. Unknown or reconciled cases must not be confirmed. Bank sources are always blocked, including apparently unreconciled bank documents.

The authoritative Project-cost ledger derives allocation from immutable journal-line dimensions. Consequently execution posts a balanced reclassification, Dr destination cost / Cr original cost. Project-to-Project uses the same existing PROJECT_COST account, leaving its GL balance unchanged. Transfers to/from overhead use the existing COMPANY_EXPENSE mapping. Company-wide expense is unchanged; cash, VAT, payables, settlements and the original Expense/journal remain untouched. No administrative status change creates an accounting entry.

## Commands and integrity

Migration `20261103150000_project_cost_correction_execution.sql` adds three immutable Company-scoped evidence tables, four authenticated public commands, constrained private helpers and a source-reversal dependency trigger. The existing accounting/Auth/subscription function definitions are preserved. Fixed search paths, minimal execution grants, forced RLS, Company-consistent foreign keys, server-derived actor/accounts/amounts and existing administrator/accounting.post authority remain authoritative.

Execution atomically creates the balanced journal and PCC reference/receipt. Normalized request hashes, source/review locking and same-key replay protect retries and concurrent attempts. There is one execution per review and one live correction per Expense. Changed request intent and stale reviews are rejected. Lost responses retain the original key for retry.

A dedicated confirmed correction reversal posts the exact inverse in today's open correction period, with reason, operator and immutable linkage. It never reverses the cash Expense. Original Expense reversal is blocked while a live correction exists; after correction reversal its existing safeguards remain in force. Another allocation requires a new current review. Closed-period corrections cannot be reversed through this increment.

## UI and reports

The existing correction review displays eligibility/blockers, accounting effect, verification evidence, confirmation, execution reference/date/amount/status and correction-only reversal. Arabic/English use existing components and themes. Review-time dependency snapshots remain historical evidence; live eligibility is separately recomputed under database locks.

The posted Project-cost ledger and shared Excel/PDF exports include original/corrected Projects, source/PCC reference, effective date, exact amount, reason/operator and posting/reversal status. Reclassification amounts are already included in ledger movement and are not added again from audit sections. Reports use actual journal dates. Original source-based views retain original Expense dimensions; they are not substitutes for the journal-based allocation ledger.

## Verification and remaining gates

Local evidence: 43 isolated SQL checks, eight independent native PostgreSQL lock schedules and 24 browser checks. They cover roles/foreign Company isolation, source immutability, exact allocation/overhead movement, no additional expense, replay/conflict/rollback, stale reviews, period closure, source reversal races and safe exact correction reversal. Actual supplier settlement and bank cases are blocked without changing their records. Browser checks exercise actual local SQL, uncertain-response recovery, ledger readback, bilingual exports and narrow layouts; no hosted requests or business fixtures.

Production build, focused lint, bilingual export inspection and final diff checks are recorded in [release results](release/project-correction-execution/result.json). Local tests never constitute real hosted financial execution acceptance.

DEFERRED/INCOMPLETE: prior-period accounting policy, bank/reconciled or settled/supplier/custody/subcontract/payroll/tax corrections, financial classification and full-document correction, split/indirect allocations, general fiscal closing, wider Project lifecycle/WIP policy and wider M3. Next increment: controlled allocation expansion after defining its precise financial/dependency policy. No unsupported case is silently executed.

Lifecycle classification: business/accounting VERIFIED for the bounded scope; security/authorization and database invariants VERIFIED locally; hosted schema/preservation status below; testing VERIFIED locally, real operator hosted workflow acceptance DEFERRED; documentation VERIFIED; frontend publication and broader Production/recovery gates DEFERRED. No cleanup, commit, push or frontend deployment.

## Hosted activation

Migration69 APPLIED to the correctly linked `eqnzueginpkskbnqvgoc` (MakerACC-Development, shared hosted environment) using the authorized CLI. The exact allowlisted SQL SHA-256 is `ced23d3432b4088d38e326420979c89c65a89844e0d3cf6603371bf38065b20b`; dry-run permitted only this file. Migration68 was not reapplied. Read-only postflight verifies69 canonical/hosted versions, all three new tables with forced RLS and authenticated SELECT only, no anonymous execution, and zero correction-period/execution/reversal rows. Protected financial/access/subscription/administrator fingerprints and all pre-existing public/private function definitions are unchanged. Hosted schema/preservation VERIFIED; no hosted period opened or financial command executed. This is not frontend deployment or real operator workflow acceptance.

Reproduction: run `node scripts/verify-project-correction-execution.mjs`, `node scripts/verify-project-correction-browser.mjs`, `python3 scripts/verify-project-correction-exports.py`, focused oxlint and `npm run build`. Native races use `scripts/verify-project-correction-races.mjs` with disposable `embedded-postgres@18.4.0-beta.17` installed under `/tmp/narvo-project-native` and its bundled library path. Native processes require local loopback permissions. No hosted connection is accepted by these fixtures. Evidence includes actual English/Arabic Excel/PDF artifacts, local checks and the safe hosted postflight summary.
