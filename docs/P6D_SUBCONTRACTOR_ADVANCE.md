# P6D Checkpoint 6 — Subcontractor Advance

Status: **COMPLETE for Development** (2026-09-24). P6D remains **IN PROGRESS**; Checkpoints 1–5 remain complete.

## Delivered boundary

Production `/subcontractor-advances` provides Company-scoped immutable Advance history, exact amounts, lifecycle, Subcontract/Project/Subcontractor/Treasury identity, payment method, optional external reference and notes, journal links, and creation provenance. `ACCOUNTING_ADMIN` and `ACCOUNTANT` can fund an eligible active Subcontract through canonical `post_subcontractor_advance`; only `ACCOUNTING_ADMIN` can invoke canonical `reverse_subcontractor_advance`. Every success is confirmed by authoritative row readback before the history refresh.

Posting input is limited to date, active Subcontract, eligible active Treasury, exact amount, required canonical payment method, optional external reference/notes, and a stable idempotency UUID. Project and Subcontractor are derived from the authoritative Subcontract. The UI preflights active Subcontract, non-closed Project, active Subcontractor, and an active same-Company Treasury whose permanent GL is an active Asset and whose optional Project matches. The database remains authoritative for every rule.

## Accounting and recovery

- Dr stable-key `SUBCONTRACTOR_ADVANCE` Asset with Project, Subcontractor Party, and Subcontract dimensions.
- Cr selected Treasury permanent Asset GL with Project, Subcontract, and Treasury dimensions.
- No Project cost, VAT, retention, payable, Certificate, deduction, or recovery is created at funding time.
- No contract-value cap is introduced.
- Exact PostgreSQL `BIGINT` minor-unit strings are preserved without floating-point conversion.
- Actor/Company-scoped frozen POST and reversal requests preserve the same idempotency key across uncertainty and reload, coalesce duplicate same-tab sends, and distinguish known first-attempt rejection from an unresolved outcome.
- Reversal exactly inverts the original journal, retains immutable history, and remains blocked when later Certificate recovery has consumed the same-Subcontract Advance balance.

## Authorization and isolation

Existing P5F permissions and forced RLS are unchanged: `ACCOUNTING_ADMIN`, `ACCOUNTANT`, and `MANAGEMENT_VIEWER` read; `ACCOUNTING_ADMIN` and `ACCOUNTANT` post; only `ACCOUNTING_ADMIN` reverses. Other tenant roles, `SYSTEM_ADMIN`, inactive memberships, and cross-tenant attempts fail closed. Browser code has no direct financial-table mutation; its only new financial RPCs are the two canonical P5F commands.

## Accepted evidence

- Focused repository/SDK/recovery/source verifier: exact nine-field POST and five-field reversal payloads, exact money strings, role gates, real Supabase SDK transport, persisted replay and coalescing, authoritative readback hooks, active-only serialized lock, recovery guard, eligible-master filtering, route integration, and production/demo financial boundary — PASS.
- Production build, lint, P6A boundary, focused secret scan, and `git diff --check` — PASS. Lint retains only the four existing Fast Refresh warnings outside this checkpoint.
- Rollback-only MakerACC-Development accounting/RLS matrix — PASS: posting/read/reversal roles, denied roles, inactive membership, cross-tenant isolation, active Subcontract/Subcontractor/Treasury, exact `9000000000000000`, balanced two-line journal and dimensions, prohibited account effects absent, idempotent replay/mismatch, exact reversal/replay, and Certificate-recovery reversal dependency.
- Post-rollback integrity: zero Checkpoint 6 Advance or Certificate fixtures; Companies/settings remain 14/14.
- No schema, RLS, grant, or accounting migration. Linked migration dry-run is a no-op.

## Exclusions and deferrals

Subcontractor Certificates, Subcontractor Payments, Retention Release, Retention Payment, automatic recovery, Subcontract changes, contract-value changes, attachments, reports, manual journals, Payroll/Attendance, P6E, and every other financial workflow remain not started in P6D. Short signed-in browser presentation smoke is recorded in `docs/PRE_DEMO_UAT.md` and remains deferred/non-blocking. No Staging or Production action occurred. No blocker remains for this Development checkpoint.
