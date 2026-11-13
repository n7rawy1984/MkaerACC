# ACW-01 — Supplier accounts and credit purchase cycle

Date: 2026-11-13. Status: implementation verified in isolated fixtures; hosted activation and publication deferred. Continues supplier-linking release `5d7fcf90cdabb53890c2dcad8b084f736f72d1ed`, including ACW-00 by ancestry.

## Reused accounting authority

Supplier Master and its existing authenticated creation form; canonical Expenses for Supplier invoice recognition; Supplier Payments and allocations; canonical Treasury/Custody funding validation; immutable journals and specialized reversal commands; Inventory receipt/GRNI matching; Party and Project GL statements; existing Company payment preferences, premium workspace, bilingual date/money cells and Excel/printable PDF exports. No second invoice accounting engine, arbitrary browser GL entry, historical-source reimport or inference of new liabilities from old payments.

## Delivered behavior

- Existing `/supplier-payments` becomes Supplier accounts and purchases. Enter Supplier, invoice number, explicit service/Inventory treatment, actual amounts/tax evidence and optional payment terms. Preview the authoritative journal, then Approve & Post.
- Service invoices recognize Company Expense/Project Cost and Supplier AP through `post_expense`. Cash invoices settle using the actual selected payer; credit invoices retain outstanding AP. Unsupported asset recognition cannot be disguised as a service invoice.
- Stock billing selects an actual posted, unmatched GRNI receipt, verifies Supplier and exact receipt value, then atomically recognizes the invoice and matches the receipt through canonical Inventory commands. Inventory was recognized at receipt; matching clears the temporary cost to GRNI and does not duplicate stock quantity, valuation or Project cost. Cash stock billing additionally settles AP atomically.
- Open an invoice and Pay: partial/full/multiple-invoice settlement from valid Treasury or Custody; Dr AP / Cr actual funding. No second cost or stock recognition.
- Dedicated Company-configured Supplier advance Asset: Dr advance / Cr payer. Subsequent invoice application Dr AP / Cr advance; no additional cash, cost or VAT. Mapping requires existing accounting-admin/account-manage authority and a genuinely unused Party Asset account; no account is configured on activation.
- Audited credit notes reverse only supported original cost and recoverable tax, within original limits. A note against a paid/cash invoice leaves an explicit Supplier debit/credit balance, never a fictional cash refund. Apply that credit to another invoice without cash/cost/tax movement.
- Original events are immutable. Controlled reversals have original-document journal previews, open-period checks, ordered dependency guards and new reversal journals. Invoice cancellation requires dependent live notes/applications/payments to be resolved. A real later refund is a separate receipt event, not a cancellation.
- Supplier account snapshot shows invoices, payments/allocations, advances/applications, notes/credit applications, separate outstanding and credit balances, aging and reconciliation to AP GL. As-of calculation respects reversal dates. Missing due dates remain distinguishable; invoice-age fallback does not assert contractual overdue terms. Complete chronological Party GL statement remains available.
- EN/AR tables, drawers, previews, statement and actual Excel/PDF output. Viewer reads financial reports without authoring controls or new Payroll exposure. Current valid Company DEFAULT payer may prefill; historical SOURCE_SET Barq preferences never become a global purchase default.
- Frozen idempotent intents survive an unknown command outcome while mounted: close/resume/retry sends the identical key/payload. Known rolled-back validation errors allow correction. Page reload recovery remains existing document lookup/reconciliation; requests are not persisted as credentials or business data in localStorage.

## Database and authorization

Migration **94**: `20261113140000_supplier_accounts_payable_cycle.sql`, additive and **NOT APPLIED**. Adds empty Company-scoped advance configuration, invoice terms and AP-document metadata; extends canonical Supplier Payment funding to Custody and current report/reversal handling. No seed, backfill, Company setup or financial command runs during activation. New tables force RLS with no authenticated direct financial write grants. Specialized RPCs derive actor, require explicit Company permission, validate authoritative dimensions and use a fixed empty search path. Private accounting plans remain uncallable by the browser. Company locks precede document locks to serialize competing payment/credit/reversal/advance use.

The isolated activation rehearsal checks exact preservation of pre-existing financial/source/master/Auth-membership rows, legacy request replay, empty new tables and RPC/RLS boundaries. It is not a hosted postflight or restoration rehearsal. Linked hosted dry-run lists only Migration94 pending against existing project `eqnzueginpkskbnqvgoc`; no migration was applied.

## Verification and evidence

See [machine-readable checks](acw01-verification.json) for exact final suite counts, migration checksum, limits and release status. Checks cover recognition, VAT, normalized duplicates/replay, partial/multi/full payments, advance/credit allocations, signed AP reconciliation, open/closed periods, insufficient Custody funding, inactive-Supplier/closed-Project settlement, immutable journals, Inventory/Project/report integration, tenant/role boundaries, native PostgreSQL concurrency, bilingual runtime, exports and additive activation preservation. Native races use independent actual PostgreSQL connections and observed lock waits, not only sequential simulation. Test fixtures never connect to Maker accounting.

Actual EN/AR rendered statement, mobile, credit and reversal screenshots were inspected. Production build includes TypeScript; scoped lint and whitespace/secret checks accompany packaging. Previously completed broad suites were not rerun. Existing bundle-size advisory remains nonblocking. Hosted business acceptance and Production frontend smoke remain deferred until approved publication.

## Real data / release gates

No real Maker invoice, Supplier payment, advance, credit, source edit, configuration or journal was created by ACW-01. Earlier completed 69 Supplier creations / 2 reused Parties / 131 links / 1 draft enrichment / 7 posted-source references are preserved and were not repeated. 193 prior identity-review exceptions remain. AED370,300.70 is the prior verified Barq checkpoint, not a new hosted balance query or this fixture's balance.

Read-only release check found GitHub main `3fb13e4040222c19a9667622f437c1c0c599a96e`. Base supplier-linking release remains included and pending publication. Vercel deployment metadata request returned HTTP403; actual Production SHA was not verified. Do not assume a current frontend deployment from local files or user intent.

Release order: authorize/apply **only Migration94** with scoped hosted preservation checks; publish the compatible release including supplier-linking ancestry; verify actual deployed SHA and focused authenticated/read-only UI behavior. Actual Maker AP accounting requires separate authorization. No automatic push, deployment or hosted migration.

## Genuine limits / preserved future work

- Physical Supplier returns and capitalized-stock price credits use the specialized Inventory/correction lifecycle; the ordinary service-credit command refuses these cases.
- Actual Supplier cash refunds need a distinct canonical receipt workflow; this milestone does not fabricate one by reversing real historical payments.
- Fixed-asset recognition remains outside the service/stock invoice treatments delivered here.
- Inventory matching retains existing receipt-master and accounting-period restrictions; historical/closed-receipt billing is not newly authorized or expanded.
- Supplier returns/refunds/advanced procurement and remaining full commercial ERP requirements remain outstanding. This milestone does not replace the original roadmap or settle uncertain historical Maker sources.

## Lifecycle classification

| Category | Status |
|---|---|
| Business/accounting implementation and isolated reconciliation | VERIFIED; specialist limits above DEFERRED |
| Security/authorization, tenant isolation, concurrency/idempotency | VERIFIED in canonical isolated fixtures |
| Database/schema, RLS and additive activation rehearsal | VERIFIED locally; hosted Migration94 activation DEFERRED |
| TypeScript, focused runtime/tests, EN/AR exports | VERIFIED in final evidence register |
| Deployment and Production postflight | DEFERRED; no push/deploy, Vercel metadata403 |
| Documentation / release packaging | VERIFIED at prepared isolated commit |
| Real Maker AP business execution | NOT APPLICABLE to this implementation authorization |

Maker operational acceptance, separate Payroll, entity onboarding Green/Villa13/Al Mazraa, the entire commercial ERP roadmap and deferred restoration/USB requirements remain unchanged.
