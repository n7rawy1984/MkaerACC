# P6D Checkpoint 8 — Subcontractor Payments

**Development status: COMPLETE (2026-09-24). P6D remains IN PROGRESS.**

## Delivered boundary

Production `/subcontractor-payments` now provides Company-scoped payment history/detail, immutable Certificate allocations, and authoritative outstanding Certificate payable balances. ACCOUNTING_ADMIN and ACCOUNTANT can post a Treasury-funded payment for one Subcontract with explicit positive allocations across one or more live POSTED Certificates of that same Subcontract. ACCOUNTING_ADMIN can reverse a posted payment. MANAGEMENT_VIEWER is read-only. All other Company roles, SYSTEM_ADMIN browser access, inactive memberships, and cross-tenant access fail closed through the existing P5H permissions and RLS.

The browser sends only the canonical P5H business inputs to `post_subcontractor_payment` and `reverse_subcontractor_payment`. Every monetary value remains an exact decimal BIGINT string. Frozen session-scoped attempts preserve the same idempotency key through uncertain outcomes, and successful commands require authoritative document/journal readback before the UI permits a new request.

## Accounting and lifecycle

Posting debits `SUBCONTRACTOR_PAYABLE` with the source Project, Subcontractor, and Subcontract dimensions and credits the selected Treasury permanent GL with Project, Subcontract, and Treasury dimensions. It does not recreate Project Cost, Input VAT, Retention, Advance recovery, deductions, or Certificate recognition, and it never settles Retention Payable. Reversal posts the exact opposite journal and restores Certificate payable outstanding while preserving the original document, allocations, and journal.

The canonical P5H database command derives Project and Subcontractor from the Subcontract, requires an active same-Company Treasury backed by an active Asset GL, and permits valid liabilities to remain payable after the Project/Subcontract closes or the Subcontractor becomes inactive. Transactional Subcontract and ordered Certificate locks, authoritative outstanding recalculation, allocation uniqueness, exact-total equality, source uniqueness, and normalized idempotency remain database-owned.

## Verification

- Focused repository verifier PASS: exact BIGINT transport, date/money/role validation, unique balanced allocations, canonical RPC payloads, first-rejection handling, same-key replay after an uncertain outcome, reversal, exact read projections, Project Treasury guard, authoritative readback, route integration, and no direct browser financial writes.
- Rollback-only MakerACC-Development accounting/RLS matrix PASS: ACCOUNTANT and ACCOUNTING_ADMIN posting; MANAGEMENT_VIEWER read; denied roles, SYSTEM_ADMIN, inactive membership and cross-tenant failure; partial and multi-Certificate allocation; a subsequent full settlement; closed/inactive master settlement; balanced Dr Payable / Cr Treasury journal with no cost/VAT/Retention/Advance recreation; over-allocation rejection; idempotent replay; live-payment Certificate reversal guard; exact payment reversal and restored outstanding.
- TypeScript/build, lint, P6A/P6C boundary checks, secret scan, `git diff --check`, rollback-fixture absence, Companies/settings integrity, migration alignment, linked no-op dry-run, and database lint are completion gates recorded in the final checkpoint result.
- No migration was required. Development was the only hosted environment touched. PRE_DEMO_UAT remains deferred and non-blocking.

## Explicit exclusions

Retention Release, Retention Payment, automatic allocation, overpayments/unallocated advances, payment editing/deletion, attachments, reports, new Certificate or Advance behavior, Payroll/WPS, Corrected Replacement Expense, P6E, Staging, and Production are outside this checkpoint and remain not started where applicable.
