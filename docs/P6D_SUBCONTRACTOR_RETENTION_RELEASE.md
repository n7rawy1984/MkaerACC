# P6D Checkpoint 9 — Subcontractor Retention Release

**Development status: COMPLETE (2026-09-25). P6D remains IN PROGRESS.**

## Delivered boundary

Production `/retention-releases` provides Company-scoped Retention Release history/detail, immutable Certificate allocations, Subcontract/Project/Subcontractor identity, provenance and journal/reversal links, plus authoritative remaining releasable retention per posted Certificate. ACCOUNTING_ADMIN can post a partial, full, staged, or multi-Certificate Release within one Subcontract and can reverse a posted Release. ACCOUNTANT and MANAGEMENT_VIEWER are read-only. All other roles, SYSTEM_ADMIN browser access, inactive memberships, and cross-tenant access fail closed through canonical P5I-A permissions and RLS.

The browser sends only canonical business inputs to `post_subcontractor_retention_release` and `reverse_subcontractor_retention_release`. Monetary values remain exact decimal BIGINT strings. Frozen session-scoped attempts retain one idempotency UUID through uncertain outcomes, and the UI requires authoritative document/journal readback before allowing a new request.

## Accounting and lifecycle

Posting debits `SUBCONTRACTOR_RETENTION_PAYABLE` and credits `SUBCONTRACTOR_PAYABLE`, preserving Project, Subcontractor Party, and Subcontract dimensions. It is a liability reclassification: no Treasury, Project Cost, VAT, Advance recovery, or deduction line is created. Reversal posts the exact dimension-preserving inverse, keeps the original document and allocations immutable, and restores releasable Certificate retention.

Available retention is Certificate retention less allocations from live POSTED Releases. Canonical database validation enforces one Subcontract, allocation uniqueness and exact-total equality, authoritative availability, Subcontract and ordered Certificate locking, normalized idempotency, and dependency ordering. Existing retention remains releasable after the related Project/Subcontract closes or the Subcontractor becomes inactive. Live Releases block Certificate reversal; reversing those Releases removes that dependency. Independent Subcontractor Payment rows and allocations remain unchanged.

## Verification

- Focused verifier PASS: canonical eight-field post and five-field reversal payloads, exact BIGINT strings beyond JavaScript safe integer range, normalized unique allocations, Admin-only mutation controls, authorized read controls, first-rejection handling, uncertain-outcome same-key replay, authoritative readback hooks, route integration, and no direct browser financial writes.
- Rollback-only MakerACC-Development accounting/RLS matrix PASS: partial/full/staged and multi-Certificate allocation, cross-Subcontract and over-release rejection, authoritative remaining retention, closed/completed/inactive lifecycle behavior, normalized replay, exact Dr Retention Payable / Cr Subcontractor Payable journal and dimensions, forbidden-account/Treasury absence, role/RLS/tenant failure, Certificate reversal dependency, exact reversal/replay, restored availability, and unchanged Subcontractor Payment data.
- Build, lint, current P6A/P6C boundaries, focused secret scan, `git diff --check`, migration alignment/no-op dry-run, DB lint, rollback fixture absence, and Companies/settings integrity are completion gates recorded in the final checkpoint result.
- No migration was required. Development was the only hosted environment touched. Browser presentation smoke remains deferred and non-blocking in `PRE_DEMO_UAT.md`.

## Explicit exclusions

Retention Payment, automatic release eligibility, new Certificate or Subcontractor Payment behavior, automatic allocation, release editing/deletion, reports/attachments, Payroll/Attendance, Corrected Replacement Expense, P6E, Staging, and Production remain outside this checkpoint.
