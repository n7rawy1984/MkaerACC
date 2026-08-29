# P5F Subcontractor Advances

P5F is implemented by `20260905120000_p5f_subcontractor_advances.sql` and forward corrections `20260905123000_p5f_advance_account_compatibility.sql`, `20260906120000_p5f_active_contract_advances.sql`, and `20260907120000_p5f_active_contract_lock.sql`, applied only to synthetic-only `MakerACC-Development`.

## Scope and accounting

P5F reuses the P3 `subcontracts` master and adds immutable `subcontractor_advances`. Each document stores company, atomic `SADV` reference, date, derived Project and Subcontractor, authoritative Subcontract, selected Treasury, integer amount, payment method, optional external reference/notes, lifecycle, journal links, and actors/timestamps.

Posting is exactly:

- Dr stable-key `SUBCONTRACTOR_ADVANCE` Asset, with Project, Subcontractor Party, and Subcontract dimensions.
- Cr selected Treasury's permanent active Asset GL, with Project, Subcontract, and Treasury dimensions.

It creates no Project cost, VAT, retention, payable, Certificate, deduction, or recovery. The P3 contract value is not treated as a cash-advance ceiling: the local workflow has no such cap and contract value alone is not an approved funding limit.

## Contract authority and lifecycle

The Subcontract is the accounting scope. A composite foreign key binds the denormalized company, Project, Subcontractor, and Subcontract identity, so two contracts for one party cannot blend. The authoritative available amount is the `SUBCONTRACTOR_ADVANCE` journal debit-minus-credit balance scoped by `(company_id, subcontract_id)`. Future Certificate recovery must credit the same account and Subcontract dimension.

The original P5F command accepted `ACTIVE` and `COMPLETED` contracts because the local client reused a generic “not CLOSED” helper. Pre-P5G review found no approved reason to issue new funding after physical completion. Forward migration `20260906120000_p5f_active_contract_advances.sql` therefore permits new Advances only on `ACTIVE` Subcontracts. Existing Advances remain valid; `COMPLETED` contracts may still receive final Certificates/recovery and later settlement, while `CLOSED` contracts receive no new activity. Treasury and its permanent GL must be active Assets; a Project Treasury may fund only its own Project.

The P0–P5G retrospective found that the first active-only wrapper read status before the private implementation acquired its Subcontract lock. Forward migration `20260907120000_p5f_active_contract_lock.sql` closes that concurrency window by locking the same-company Subcontract before validating `ACTIVE` and delegating. A focused hosted regression passed **9/9** cases, including rejection after transition to `COMPLETED`, idempotent history preservation, and a single source journal.

## Atomicity, idempotency, and reversal

`post_subcontractor_advance` creates the document and balanced journal in one transaction, uses the P5A atomic reference counter, and reserves a canonical request hash. Exact retries replay one result; a changed payload under the same key fails.

`reverse_subcontractor_advance` is Accounting Admin-only and exactly inverts the original journal. It locks both the document and Subcontract and requires the current contract-scoped control balance to cover the Advance being reversed. P5F itself creates no recovery, but this guard deliberately prevents reversal after a future Certificate has consumed that contract balance. History cannot be updated or deleted directly.

The forward correction removed only an unnecessary `accounts.requires_party` posting prerequisite. The established stable-key account was absent from the initial synthetic Company A fixture and was then created for verification. Party remains mandatory in the generated journal regardless of that generic master flag.

## Authorization and hosted verification

The table has forced RLS. Accounting Admin, Accountant, and Management Viewer may read their active company rows. Accounting Admin and Accountant may post through the specialized command; only Accounting Admin may reverse. Data Entry, other roles, anonymous callers, and other tenants cannot read or execute financial effects. Direct authenticated insert/update/delete is denied; private balance/kernel functions have no browser execution grant.

The definitive hosted Development matrix passed **106/106** cases. It covered posting shape, stable-key resolution, active/inactive masters, `ACTIVE`/`COMPLETED`/`CLOSED` lifecycle, closed Project rejection, Project Treasury compatibility, safe money bounds, normalization, idempotency replay/mismatch, exact reversal, role boundaries, RLS, tenant isolation, and direct-write denial. Its mandatory same-Subcontractor/two-contract case proved balances of 12,001 and 23,002 minor units remained independently scoped while the party aggregate equalled 35,003.

Trusted whole-scope reconciliation found zero orphan sources, unbalanced or non-two-line P5F journals, missing Subcontract dimensions, or Project Cost/VAT/Subcontractor Payable/Retention account usage. Generated database types were refreshed and migration history is aligned through the later active-only lifecycle corrections. P5G verification confirmed active-only funding and same-contract Certificate recovery; the retrospective regression then confirmed the serialized lifecycle boundary.

## Boundary

P5F itself added no Subcontractor Certificate, advance recovery, deduction, retention, payable recognition, or final Subcontractor Payment. P5G subsequently completed Certificate approval, recovery, retention, deductions, and payable recognition without adding cash settlement.
