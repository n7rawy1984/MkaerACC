# P5E Custody Settlement and Cash Return

P5E is implemented by `20260904120000_p5e_custody_settlements_returns.sql` and forward correction `20260904123000_p5e_settlement_expense_variable.sql`, applied only to synthetic-only `MakerACC-Development`.

## Pooled balance and local-domain audit

The localStorage workflow creates a DRAFT Settlement containing selected Expense IDs and optional return fields, then finalizes it. It correctly groups already-posted Custodian Expenses without reposting them and posts only a return, if present. Its client numbering, separate writes, project header, Owner/legacy destinations, and combined Settlement/Return lifecycle are not safe production authority.

Production preserves the approved accounting model: the authoritative custody receivable is the journal-derived `CUSTODY_ADVANCE` account balance scoped by `(company_id, custodian_id)`. Posted Advances debit it; posted Custodian Expenses and Cash Returns credit it; exact reversals invert those effects. Settlement itself has zero balance effect. Project is analytical and never partitions the pooled balance.

## Settlement structure and lifecycle

`custody_settlements` stores company, atomic `CSTL` reference, date, Custodian, notes, authoritative total, `DRAFT|FINALIZED`, and actor/timestamps. `custody_settlement_items` stores immutable same-company Settlement/Expense provenance and the Expense gross captured at finalization. A global Expense uniqueness constraint prevents inclusion in a second Settlement.

P5E exposes one atomic `finalize_custody_settlement` command rather than browser draft CRUD. It internally creates DRAFT, inserts items, then transitions to FINALIZED in one transaction. Finalized headers/items cannot be updated or deleted. Cancellation is deferred: it must later preserve the original grouping and explicitly release eligibility; direct mutation is never acceptable.

The command requires 1–999 unique Expense UUIDs. It locks the Custodian and Expenses in UUID order and accepts only same-company, `POSTED`, `CUSTODIAN`-funded Expenses for that Custodian. Projects may differ or be null, and closed-Project history remains eligible. The total is recalculated as the exact sum of P5B `gross_amount_minor`; a caller expected total must match. Finalization allocates the reference but creates no journal, cost, VAT, custody, or Treasury effect.

## Cash Return structure and accounting

`custody_cash_returns` stores company, atomic `CRET` reference, date, Custodian, active Treasury, integer amount, payment method, optional external reference/notes, `DRAFT|POSTED|REVERSED`, immutable journal links, and actors/timestamps.

Cash Return is independent of Settlement because accounting truth is Advances, Expenses, and Returns; administrative grouping must not create lifecycle coupling. P5E deliberately omits `project_id`: custody is pooled and a Return cannot reliably allocate cash back to one Project. It posts:

- Dr selected Treasury permanent Asset GL, Treasury dimension.
- Cr `CUSTODY_ADVANCE`, Custodian party dimension.

It creates no Project Cost, Company Expense, or VAT. An inactive Custodian may return an existing balance; Treasury must remain active. Closed Project status is irrelevant because no Project is accepted.

## Balance protection, concurrency, idempotency, and reversal

`post_custody_cash_return` locks the same Custodian party row used by P5D's P5B Expense wrapper, derives the current pooled journal balance, and rejects amount above balance. Return/Return and Return/Expense races therefore serialize and cannot jointly overdraw custody.

Canonical request hashing and P5A financial-command reservations give replay, changed-payload rejection, and one effect for concurrent identical calls. References use P5A atomic counters, never client counts or `MAX()+1`.

`reverse_custody_cash_return` requires `accounting.reverse`, locks the document and Custodian, and calls the exact P5A inversion primitive. The reversal debits Custody and credits Treasury with identical dimensions. It increases the custody asset, so no negative-balance dependency guard is required. Original document/journal and reversal journal remain immutable.

## Authorization and isolation

All three tables have forced RLS. Accounting Admin, Accountant, and Management Viewer receive company-scoped SELECT. Accounting Admin and Accountant may finalize Settlements/post Returns through authenticated specialized commands; only Accounting Admin may reverse. Project Manager, Data Entry, Procurement, System Admin, and anonymous callers have no pooled custody access or command authority. Direct browser financial mutation, browser DELETE, private balance/kernel execution, and service-role economic mutation are denied.

Two-company verification denied cross-tenant Settlement/item/Return reads and cross-company Expense, Custodian, and Treasury use. UUID knowledge never grants access.

## Hosted verification and correction

The first hosted Settlement call found `expense_id` ambiguous between a PL/pgSQL variable and an item column. Its transaction rolled back. The applied migration was not edited; `20260904123000` forward-replaced the command with `current_expense_id` and a qualified item column.

The definitive hosted matrix passed all 82 required balance, Settlement/no-repost, Return accounting, validation, concurrency, idempotency, immutability, reversal, authorization, tenant, and reconciliation checks. Trusted whole-database verification found 6 Settlements/10 items and 28 synthetic Returns with:

- zero Settlement total mismatches and zero `CUSTODY_SETTLEMENT` journal sources;
- zero orphan Return links, unbalanced Return journals, cost/VAT Return lines, or duplicate Return sources;
- zero pooled document-versus-journal balance mismatches;
- trusted Settlement and Return economic updates blocked.

Database lint adds no P5E finding; only P5C's documented unused Supplier validation variable remains. Migration history is aligned through both P5E migrations and generated public TypeScript types are refreshed.

## Boundary

P5E adds no Settlement cancellation, embedded Return relation, Owner/legacy Return destination, alternate Supplier Payment funding, subcontract commands, audit events, attachments, frontend Supabase path, Payroll, AR/revenue, or import. P5F subsequently completed the separately reviewed Subcontractor Advance command without changing P5E's custody model.
