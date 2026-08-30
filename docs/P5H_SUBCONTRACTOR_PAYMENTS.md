# P5H Subcontractor Payments

P5H is implemented by `20260908120000_p5h_subcontractor_payments.sql`, applied only to synthetic-only `MakerACC-Development`.

## Production mapping and scope

The localStorage model records one `SubcontractorPaymentTransaction` per Certificate and mutates a display status to `PARTIALLY_PAID` or `PAID`. Its established accounting correctly settles payable without recreating cost, VAT or Retention, but its browser-side writes and mutable status are not production authority.

Production uses one immutable `subcontractor_payments` document for exactly one Subcontract, with immutable `subcontractor_payment_allocations` preserving Certificate-level settlement provenance. One Payment may cover multiple live POSTED Certificates only when they belong to that same Company, Project, Subcontractor and Subcontract. One Certificate may receive multiple partial Payments. A Party-level aggregate is reportable, but accounting truth never blends two contracts.

Project and Subcontractor are derived from the locked Subcontract and stored as constrained immutable provenance. The Payment journal aggregates the payable debit into one line because every allocation has identical Project/Party/Subcontract dimensions; allocation rows retain the Certificate detail.

## Accounting and outstanding payable

Posting is only:

- Dr stable-key `SUBCONTRACTOR_PAYABLE`, with Project, Subcontractor Party and Subcontract.
- Cr the selected Treasury's permanent active Asset GL, with Project, Subcontract and Treasury.

Payment does not recreate Project Cost, Input VAT, Retention, Advance recovery or Certificate deductions. It does not pay `SUBCONTRACTOR_RETENTION_PAYABLE`.

Authoritative Certificate outstanding is its immutable P5G `payable_amount_minor` less allocations belonging to live `POSTED` Payments. Reversed Payments retain allocations but cease consuming outstanding. No mutable remaining-balance column exists.

## Lifecycle, Treasury and cleanup

Payment requires an active same-company Treasury backed by its permanent active Asset GL. A Project-specific Treasury may settle only a Subcontract from that Project; callers cannot provide a GL account.

`ACTIVE`, `COMPLETED` and `CLOSED` Subcontracts may settle existing payable. A closed Project and inactive Subcontractor likewise do not trap a recognized liability. These exceptions permit settlement only; they do not authorize new commercial activity or weaken P5F/P5G creation rules.

## Atomicity, concurrency and reversal

`post_subcontractor_payment` accepts business inputs plus an explicit total and normalized Certificate allocations. It derives the actor and dimensions, checks `accounting.post`, locks the Subcontract and Certificates in deterministic UUID order, recalculates outstanding in the transaction, rejects overpayment, reserves P5A idempotency, allocates an atomic `SCPAY` reference, creates document/allocations/journal, links them and completes once.

The Subcontract lock serializes all Payments in the contract; Certificate locks protect each source. Identical concurrent retries create one effect through P5A idempotency, while different concurrent Payments cannot consume the same remaining payable twice.

`reverse_subcontractor_payment` requires `accounting.reverse`, uses the same Subcontract-first lock order, retains allocations and performs exact P5A inversion: Dr Treasury / Cr Subcontractor Payable. It restores derived outstanding.

P5G Certificate reversal is now wrapped with the same Subcontract-first lock order and protected by a database trigger. A Certificate with any allocation from a live POSTED Payment cannot reverse. After every consuming Payment is REVERSED, Certificate reversal is eligible again subject to all other P5G rules.

## Authorization and immutability

Both tables use forced RLS. Accounting Admin, Accountant and Management Viewer have company-scoped read access. Accounting Admin and Accountant may post through the command; only Accounting Admin may reverse. Project Manager, Procurement, Data Entry, System Admin, other tenants and anonymous callers have no raw rows or posting authority.

Authenticated direct insert/update/delete is denied. Posted Payment economics, source identity, allocation rows and original journals are immutable; no DELETE exists. Generic P5A journal primitives remain private. All privileged functions use a fixed empty search path and narrow EXECUTE grants.

## Hosted verification and reconciliation

The definitive synthetic Development matrix passed **95/95** assertions. It covered full/partial and multi-Certificate settlement, multiple partial Payments, exact journal shape, explicit-total validation, outstanding/overpayment, deterministic concurrency, idempotency/references, same-Party multi-contract isolation, closed/completed/inactive cleanup, Treasury compatibility, Certificate reversal dependency, exact Payment reversal, role/RLS/tenant boundaries, direct-write denial and trusted whole-scope reconciliation.

The first run passed 94/95; its only failure was a test query that looked for reversals under `SUBCONTRACTOR_PAYMENT`. P5A correctly records exact reversals as `JOURNAL_REVERSAL` linked through `reversal_of_journal_entry_id`. The query was corrected without a schema change, and the definitive rerun passed 95/95.

Trusted reconciliation found zero orphan original/reversal links, unbalanced Payment journals, forbidden Cost/VAT/Retention/Advance lines, duplicate original sources, allocation-total mismatches or missing contract dimensions. Database types were regenerated.

## Boundary

P5H adds no Retention Release/payment, new Certificate behavior beyond the mandatory live-Payment reversal dependency, alternate Supplier Payment funding, frontend Supabase path, Payroll, client AR/revenue, P6 or historical import.

The next P5 batch, if any, requires separate review. Retention Release/Settlement is explicitly not part of P5H. STOP before it or P6.
