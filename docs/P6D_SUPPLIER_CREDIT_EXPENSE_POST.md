# P6D Checkpoint 5 — Supplier Credit Expense POST

Status: **COMPLETE for Development** (2026-09-24). P6D remains **IN PROGRESS**.

## Delivered boundary

Production `/expenses` now exposes a separate Supplier Credit Expense form to `ACCOUNTING_ADMIN` and `ACCOUNTANT`. It collects business inputs only and invokes the existing canonical P5B `post_expense` command with `funding_mode = SUPPLIER_CREDIT`, the selected active Supplier, required `payment_method`, and null Treasury/paid-by inputs. The existing Expense READ refreshes from authoritative rows after posting. The client also confirms that the new Expense appears in Supplier Payment outstanding with outstanding equal to its stored gross amount before permitting another post.

The client preserves exact `BIGINT` minor-unit strings and the complete 17-field canonical payload. A frozen actor/Company-scoped request and idempotency key survive uncertain outcomes and reload; the same key is retried until authoritative Expense and outstanding readback succeeds. Known command rejection is distinguished from an uncertain transport outcome.

## Accounting behavior

- Project expense: Dr `PROJECT_COST` for net, with Project dimension.
- Company-level expense: Dr `COMPANY_EXPENSE` for net.
- Tax invoice VAT: Dr `INPUT_VAT` for server-derived `AUTO_5` VAT or validated `MANUAL` VAT.
- Funding: Cr `SUPPLIER_PAYABLE` for gross, with Supplier party and matching optional Project dimension.
- No Treasury line, cash movement, payment allocation, or recreated cost occurs.
- The posted Supplier Credit liability is immediately available to the existing Supplier Payment workflow. An active Supplier Payment allocation blocks Expense reversal until the payment is reversed.

The server remains authoritative for VAT calculation, active Supplier and Category checks, non-closed Project eligibility, tenant/dimension consistency, reference allocation, balanced journal construction, source uniqueness, row locking, immutable posting, normalized request hashing, and atomic document/journal/audit commit.

## Authorization and isolation

`ACCOUNTING_ADMIN` and `ACCOUNTANT` may post. Existing Expense RLS remains unchanged: `MANAGEMENT_VIEWER` is read-only, assigned `PROJECT_MANAGER` visibility remains Project-scoped, and denied roles, `SYSTEM_ADMIN`, inactive identities, and cross-tenant attempts fail closed. No browser direct financial-table write was added; the only new financial RPC call is canonical `post_expense`.

## Verification accepted

- Focused repository/form verifier: exact payload and null shape, exact large `BIGINT` strings, VAT modes/evidence, required payment method, role gate, real Supabase SDK RPC transport, frozen recovery, coalescing, same-key replay, known rejection handling, authoritative Expense/outstanding hooks, master preflight, and financial mutation boundary — PASS.
- Production build and lint — PASS.
- Rollback-only MakerACC-Development accounting/RLS matrix — PASS: ZERO/AUTO_5/MANUAL VAT, exact `9000000000000000`, journal accounts and dimensions, balance, outstanding availability, idempotent replay/changed-hash rejection, Accountant posting, read roles, inactive identity, inactive Supplier, closed Project, denied roles, cross-tenant isolation, and live Supplier Payment reversal dependency.
- Post-rollback integrity: zero Checkpoint 5 fixture Expenses; Supplier Payments/allocations remain 32/34; Companies/settings remain 14/14.
- Canonical migration history is unchanged; linked migration dry-run is a no-op.

## Explicit exclusions and deferrals

No corrected replacement Expense, draft/edit/delete, Supplier Payment change, Expense reversal change, additional funding mode, schema/RLS/grant change, migration, attachment flow, or other financial workflow is included. The existing P5B reversal semantics are only consumed and regression-checked.

Real-browser operator presentation smoke is recorded in `docs/PRE_DEMO_UAT.md` and remains deferred/non-blocking. Production readiness, the full Production Security & Accounting Integrity Audit, Staging, and Production remain deferred. No blocker remains for this Development checkpoint.
