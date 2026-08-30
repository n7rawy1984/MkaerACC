# P5I Subcontractor Retention

P5I overall is **IN PROGRESS**. P5I-A Retention Release is implemented by `20260909120000_p5i_retention_releases.sql`, applied only to synthetic-only `MakerACC-Development`. P5I-B Retention Payment is not implemented.

## P5I-A production model

An immutable `subcontractor_retention_releases` document belongs to exactly one Company and Subcontract and carries the derived Project and Subcontractor Party. Immutable `subcontractor_retention_release_allocations` preserve the Certificate-level source of every released amount. A Release may allocate multiple live POSTED Certificates from the same Subcontract, and Certificates may be released through multiple partial Releases.

Authoritative remaining retention is each Certificate's immutable `retention_amount_minor` less allocations belonging to live POSTED Releases. Reversed Releases retain their allocations but stop consuming availability. The command locks the Subcontract first and Certificate rows in UUID order, so concurrent Releases cannot over-consume retention and same-Party contracts never pool balances.

## Accounting and lifecycle

Posting is exactly:

- Dr `SUBCONTRACTOR_RETENTION_PAYABLE`.
- Cr `SUBCONTRACTOR_PAYABLE`.

Both lines preserve Project, Party and Subcontract. There is no Treasury, Project Cost, VAT, Advance recovery or deduction line. Manual Release authorization is Accounting-Admin-only. Existing recognized retention remains releasable for ACTIVE, COMPLETED or CLOSED Subcontracts, closed Projects, and inactive Subcontractors.

Reversal is Accounting-Admin-only exact P5A inversion. A Certificate cannot reverse while a live Release allocation consumes it. Once every consuming Release reverses, its immutable allocation history remains but no longer blocks the Certificate, subject to all other P5G/P5H dependencies. P5I-B must add the live Retention Payment dependency before any Retention Payment exists.

## Security and verification

Both tables use forced RLS. Accounting Admin, Accountant and Management Viewer receive company-scoped read access. Only Accounting Admin can post or reverse; operational roles, System Admin, other tenants and anonymous callers cannot mutate or read raw rows. Direct writes are denied and the private P5A kernel remains private.

Focused synthetic hosted verification covered partial and full availability, repeated releases, exact allocations and journal lines, dimensions, no Treasury, over-release, idempotency replay/change rejection, concurrent over-consumption, direct-write and role denial, live-Release Certificate reversal blocking, exact Release inversion, retained immutable history, and restored availability. Hosted DB lint returned no errors; migration alignment/dry-run, generated types, build, lint, reconciliation and focused grants/RLS checks were completed.

## Boundary

P5I-A adds no Retention Payment, Treasury settlement, frontend Supabase path, P6 cutover, Payroll, client AR/revenue or historical import. P5I remains in progress until separately authorized P5I-B Retention Payment is implemented and verified.
