# P5I Subcontractor Retention

P5I-A Retention Release is implemented by `20260909120000_p5i_retention_releases.sql`. P5I-B Retention Payment is implemented by `20260910120000_p5i_retention_payments.sql`. Both are applied only to synthetic-only `MakerACC-Development`.

## P5I-A production model

An immutable `subcontractor_retention_releases` document belongs to exactly one Company and Subcontract and carries the derived Project and Subcontractor Party. Immutable `subcontractor_retention_release_allocations` preserve the Certificate-level source of every released amount. A Release may allocate multiple live POSTED Certificates from the same Subcontract, and Certificates may be released through multiple partial Releases.

Authoritative remaining retention is each Certificate's immutable `retention_amount_minor` less allocations belonging to live POSTED Releases. Reversed Releases retain their allocations but stop consuming availability. The command locks the Subcontract first and Certificate rows in UUID order, so concurrent Releases cannot over-consume retention and same-Party contracts never pool balances.

## Accounting and lifecycle

Posting is exactly:

- Dr `SUBCONTRACTOR_RETENTION_PAYABLE`.
- Cr `SUBCONTRACTOR_PAYABLE`.

Both lines preserve Project, Party and Subcontract. There is no Treasury, Project Cost, VAT, Advance recovery or deduction line. Manual Release authorization is Accounting-Admin-only. Existing recognized retention remains releasable for ACTIVE, COMPLETED or CLOSED Subcontracts, closed Projects, and inactive Subcontractors.

Reversal is Accounting-Admin-only exact P5A inversion. A Certificate cannot reverse while a live Release allocation consumes it. A Release cannot reverse while a live Retention Payment allocation consumes it. Once every consuming Payment reverses, the Release can reverse if otherwise valid; once the Release reverses, its immutable allocation history remains but no longer blocks the Certificate, subject to all other P5G/P5H dependencies.

## P5I-B Retention Payment

An immutable `subcontractor_retention_payments` document belongs to one Company and Subcontract and derives constrained Project/Subcontractor provenance from that Subcontract. Immutable `subcontractor_retention_payment_allocations` allocate only live POSTED Retention Releases from the same Subcontract. One Payment can settle multiple Releases; one Release can receive multiple partial Payments.

Authoritative released-but-unpaid is the immutable Release total less allocations from live POSTED Retention Payments. Reversed Payments retain allocation history but stop consuming availability. Subcontract-first and deterministic Release locks serialize settlement and prevent concurrent overpayment.

Payment posting is exactly Dr `SUBCONTRACTOR_PAYABLE` / Cr the selected active Treasury's permanent Asset GL. It creates no Retention Payable, Cost, VAT, Advance recovery, deduction, or additional Release line. Existing released liabilities remain payable through Project closure, Subcontract completion/closure, and Subcontractor inactivation; Treasury must remain active and project-compatible.

Accounting Admin and Accountant may post. Only Accounting Admin may reverse through exact P5A inversion, restoring released-but-unpaid availability. Atomic `SRPAY` references and normalized P5A idempotency provide stable retry behavior.

## Security and verification

All P5I tables use forced RLS. Accounting Admin, Accountant and Management Viewer receive company-scoped read access. Retention Release posting/reversal is Accounting-Admin-only; Retention Payment posting is available to Accounting Admin and Accountant, while reversal is Accounting-Admin-only. Operational roles, System Admin, other tenants and anonymous callers cannot mutate or read raw rows. Direct writes are denied and the private P5A kernel remains private.

Focused synthetic hosted verification covered the Release lifecycle plus full/partial and repeated Retention Payments, multi-Release settlement, exact remaining settlement, overpayment and concurrency rejection, idempotency replay/change rejection, atomic references, exact journal shape/inversion, dimensions, forbidden-line absence, role/direct-write denial, Release dependency and restoration, immutable allocations/history, and end-to-end reconciliation. Hosted DB lint returned no errors; migration alignment/dry-run, generated types, build, lint, reconciliation and focused grants/RLS checks were completed.

## Boundary

P5I adds no frontend Supabase path, alternate Supplier Payment funding, P6 cutover, Payroll, client AR/revenue or historical import. The P5I Release-to-Payment integration and reconciliation review is complete; no later phase was started.
