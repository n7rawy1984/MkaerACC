# P6D Checkpoint 7 — Subcontractor Certificates

Status: **COMPLETE for Development** (2026-09-24). P6D remains **IN PROGRESS**; Checkpoints 1–6 remain complete.

## Delivered boundary

Production `/subcontractor-certificates` provides Company-scoped Certificate and deduction history, Subcontract/Project/Subcontractor identity, lifecycle, exact source and server-calculated amounts, VAT evidence/mode, retention basis/amount, same-contract Advance recovery, mapped deductions, residual payable, and posting/reversal provenance. `ACCOUNTING_ADMIN` and `ACCOUNTANT` may create canonical no-GL drafts; only `ACCOUNTING_ADMIN` may approve/post or reverse. `MANAGEMENT_VIEWER` is read-only.

Draft preparation invokes canonical `create_subcontractor_certificate_draft` with its exact 14-field business payload. Its command has no idempotency key, so uncertainty recovery first reads the canonical unique `(subcontract_id, contractor_certificate_number)` source and verifies every input/deduction before any resend. Approval uses `approve_post_subcontractor_certificate`; reversal uses `reverse_subcontractor_certificate`. Their actor/Company-scoped attempt records freeze and reuse native idempotency UUIDs. Every result requires authoritative session-bound row readback before refresh.

The UI admits ACTIVE and COMPLETED Subcontracts whose Projects are not CLOSED and preserves canonical certification for an inactive Subcontractor identity. It filters deduction types to existing trusted mappings and never accepts an Account UUID or calculates accounting values in React. The database remains authoritative for prior/current/gross work, revised-value cap, rounding, retention, recovery availability, deductions, payable, references, locks, authorization, and journals.

## Accounting and dependencies

- Dr stable-key `PROJECT_COST_SUBCONTRACTORS` for current gross, with Project/Subcontractor/Subcontract dimensions.
- Dr `INPUT_VAT` only for qualifying invoice-backed VAT.
- Cr `SUBCONTRACTOR_RETENTION_PAYABLE`, same-Subcontract `SUBCONTRACTOR_ADVANCE`, mapped deduction Revenue accounts, and residual `SUBCONTRACTOR_PAYABLE` as applicable.
- No Treasury account or movement is created by Certificate approval.
- Exact PostgreSQL `BIGINT` minor units cross the browser boundary only as decimal strings; calculated amounts are read-only.
- The canonical Subcontract lock serializes cumulative cap and recovery. Approval/reversal idempotency and same-tab coalescing preserve a single effect.
- Reversal exactly inverts original lines and dimensions. Live Subcontractor Payment or Retention Release allocations block reversal until their parent documents reverse.

## Accepted evidence

- Focused repository/SDK/source verifier — PASS: exact 14-field draft, three-field approval and five-field reversal payloads; real SDK BIGINT string transport; money/input bounds; role gates; coalesced same-key approval recovery; canonical lifecycle/calculation/lock/dependency inspection; readback hooks; route and financial mutation boundary.
- Rollback-only MakerACC-Development matrix — PASS: no-GL draft, exact upper-bound money, server prior/current/gross calculation, AUTO_5 VAT evidence, retention, Advance recovery, mapped deduction, payable, balanced dimensioned journal, no Treasury, revised-value cap, ACTIVE/COMPLETED/inactive-party behavior, CLOSED rejection, all-role RLS/command matrix, inactive membership, tenant isolation, replay, exact reversal, and Payment/Retention Release guards. The first verifier run rolled back on an unassigned loop fixture; the corrected verifier passed without a product change.
- Build, lint, P6A/P6C boundaries, focused secret scan, and `git diff --check` — PASS. Lint retains only the four existing Fast Refresh warnings outside this checkpoint.
- Development DB lint — no errors; one pre-existing extra-variable warning in `private.post_supplier_payment`. Linked migration dry-run is a no-op.
- Post-rollback integrity — zero Certificate/Payment/Retention fixtures; Companies/settings remain 14/14.
- No migration, schema, RLS, grant, or accounting change.

## Lifecycle classification and deferrals

Business/accounting, security/authorization, database reuse, focused automated/hosted testing, and documentation are **VERIFIED** for Development. Schema migration and deployment are **NOT APPLICABLE**. Short authenticated EN/AR/RTL/narrow-screen presentation smoke, Staging/Production, production readiness, and the full pre-production audit are **DEFERRED**.

Subcontractor Payment, Retention Release, Retention Payment, new Advance behavior, Subcontract/value changes, arbitrary deduction mapping setup, attachments/reports, Corrected Replacement Expense, Payroll/Attendance, P6E, and every other financial workflow remain **NOT STARTED in P6D**. No blocker remains for this Development checkpoint.
