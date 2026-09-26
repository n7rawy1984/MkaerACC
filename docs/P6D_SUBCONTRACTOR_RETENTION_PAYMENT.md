# P6D Checkpoint 10 — Subcontractor Retention Payment

**Development status: COMPLETE (2026-09-26). P6D remains IN PROGRESS.**

## Delivered boundary

Production `/retention-payments` provides Company-scoped Retention Payment history/detail, immutable Retention Release allocations, Subcontract/Project/Subcontractor/Treasury identity, provenance and journal/reversal links, plus authoritative released-but-unpaid balances. ACCOUNTING_ADMIN and ACCOUNTANT can post a Treasury-funded partial, full, or multi-Release payment within one Subcontract. ACCOUNTING_ADMIN can reverse a posted payment; MANAGEMENT_VIEWER is read-only. Other roles, SYSTEM_ADMIN browser access, inactive memberships, and cross-tenant access fail closed through canonical P5I-B permissions and RLS.

The browser sends only canonical business inputs to `post_subcontractor_retention_payment` and `reverse_subcontractor_retention_payment`. All money remains exact decimal BIGINT strings. Frozen session-scoped attempts preserve one idempotency UUID through uncertain outcomes, and authoritative document/journal readback is required before a new request.

## Accounting and lifecycle

Posting debits `SUBCONTRACTOR_PAYABLE` with Project, Subcontractor Party, and Subcontract dimensions and credits the selected Treasury permanent GL with Project, Subcontract, and Treasury dimensions. It settles released retention payable without recreating Retention, Project Cost, VAT, Advance recovery, or deductions. Reversal posts the exact inverse and restores released-but-unpaid availability while retaining immutable payment and allocation history.

Availability is each live POSTED Retention Release total less allocations from live POSTED Retention Payments. Canonical database validation enforces one Subcontract, allocation uniqueness and exact-total equality, active same-Company Asset-backed Treasury compatibility, authoritative availability, Subcontract and ordered Release locking, normalized idempotency, and dependency ordering. Existing liabilities remain payable after related masters close or become inactive. Live Payments block Retention Release reversal; after all consuming Payments reverse, Release reversal eligibility returns.

## Verification

- Focused verifier PASS: exact ten-field post and five-field reversal payloads, BIGINT strings beyond JavaScript safe integer range, unique balanced Release allocations, exact role controls, Treasury/UI guards, first-rejection handling, uncertain-outcome replay, readback, route integration, and no direct browser financial writes.
- Rollback-only MakerACC-Development matrix PASS: Accountant/Admin post, Admin reversal, authorized reads, denied roles/SYSTEM_ADMIN/inactive/cross-tenant failure, partial/full multi-Release allocation, cross-Subcontract and overpayment rejection, active Treasury enforcement, closed/inactive settlement, exact Dr Payable / Cr Treasury, forbidden reposting absence, replay, Release reversal dependency, exact reversal, and restored availability.
- Build, lint, current P6A/P6C boundaries, focused secret scan, diff check, migration alignment/no-op dry-run, DB lint, rollback fixture absence, and Companies/settings integrity are completion gates recorded in the final result.
- No migration was required. Development was the only hosted environment touched. Browser presentation smoke remains deferred/non-blocking in `PRE_DEMO_UAT.md`.

## Explicit exclusions

New Retention Release, Certificate, or Subcontractor Payment behavior; automatic allocation; overpayment; posted edit/delete; Corrected Replacement Expense; reports/attachments; Payroll/Attendance; P6E; Staging; and Production remain outside this checkpoint.
