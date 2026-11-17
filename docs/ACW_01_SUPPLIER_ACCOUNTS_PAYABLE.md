## 2026-11-17 — ACW-01 final focused acceptance and fixes (local release)

Published baseline `0eec66e96ee3345b4ad1d4757a7b55be6836ae03` and applied Migration94 reused. Final isolated tests exercised canonical SQL, actual application routes/forms and real native concurrency. Browser accounting results were NOT mocked: six invoices and four settlements posted only in a disposable synthetic Company, including AED5,000 → AED2,000 payment → AED3,000 remaining → final zero, Inventory/GRNI matching and immediate paid purchases. Separate SQL scenarios verified multi-invoice allocation, advances/applications, credits/VAT, reversals/dependencies, idempotency, authorization, tenant isolation and periods. Evidence separates fresh tests, synthetic Auth/master adapters and Production read-only checks: `docs/acw01-final-acceptance.json`.

Confirmed in-scope presentation fixes: Inventory mode had a misleading Service placeholder and unstable accessible label; actual receipt selection is now explicitly labeled/required. Accountant could preview Inventory matching but the posting action then hit the existing database Admin-only stock/cost rule; the UI now explains and guards that SAME rule. No grant/role change. Missing Supplier Payable configuration previously appeared as zero GL reconciliation; screen/exports now show setup required / reconciliation unavailable and suppress an invented numeric difference. Historical reporting remains available for inactive mapped controls. Supplier AP scope now explicitly distinguishes canonical invoices/settlements, source-linked activity and posted GL in both screen and shared Excel/PDF output.

Fresh focused results: canonical accounting42, integration20, credit15, independent native concurrency11, actual browser/canonical SQL57, changed-control browser20, report semantics12, export-file inspection5 — all PASS. Counts are separate suites, not claims of unique business scenarios. EN/AR at1366×768 and1920×1080; actual XLSX/PDF invoice/amount content inspected. TypeScript and final Production build PASS; scoped lint0errors/2existing state-effect advisories; existing bundle-size advisory. No broad unrelated audit or full183check suite restart.

Authenticated Production read-only before/after: 15 scoped table fingerprints, AP response and all captured GL dimensions unchanged; 370sources, 69Supplier parties (74total), 30journals/60lines, 16Expenses, 21draft bindings/66events, payroll postings0. Barq Custody **AED370,300.70** unchanged. Native Supplier dropdown opened, remained open and accepted selection; spontaneous closing was not reproduced. No hosted financial/configuration writes or administrative impersonation. ADNOC's zero AP invoices is consistent with the current canonical invoice register (0Supplier invoices); historic Supplier associations do not create AP. **Maker lacks the Supplier Payable control mapping**: authorized Company accounting setup remains an operational prerequisite for credit purchases/settlements; no account/code or balance was invented.

No migration required; Migration94 and all schema/RLS/Auth/permissions unchanged. All financial command payloads/idempotency/math preserved; sole command-entry guard mirrors existing Admin stock authority. Implementation/testing/documentation and read-only preservation **VERIFIED**; database change **NOT APPLICABLE**; publication and patch Production acceptance **DEFERRED**. Maker AP operational readiness is conditional on its separate approved setup. Preserve specialist stock return/price-credit, refund and fixed-asset limits; all original commercial requirements and deferred restoration/USB work. After this release, stop expanding ACW-01 and continue existing approved Roadmap V3 separately; no future phase implemented here. No push/deploy.

## 2026-11-14 — ACW-01 focused Supplier usability correction (local release)

Continues deployed navigation release `01782691757e95c217df36d5790bbaff01c00f6a`. The former Full GL link opened the generic Company reports collection; the Party parameter only initialized a buried form and did not load results. The primary action now opens `/supplier-statements?party=<id>&as_of=<snapshot-date>` and renders the **existing** Supplier report model (invoices, payments, credits, advances, allocations, aging and reconciliation). Posted GL detail is a distinct action: the existing Party reader auto-loads in a focused reports route with the selected Party. No parallel reporting/accounting engine.

Supplier labels/search/table headers previously inherited muted 13–14px shared styling. Scoped premium styles now use readable 16px labels/headers, stronger text contrast, spacing and bounded mixed-language Supplier controls. Selection is URL-backed, filter and export/action rows are separated, master loading disables the native selector, and changing Supplier clears stale table search/detail state. Native select and canonical financial forms remain in use.

**Selector evidence limitation:** in the real authenticated Production accountant browser (financial writes blocked), the 70-option native selector opened, stayed open, retained its DOM/focus and selected successfully by keyboard. The reported spontaneous closing was not reproduced; no focus/authentication/RLS defect is claimed or speculative bypass introduced. Loading and selection/layout weaknesses are corrected, but the original intermittent symptom still requires operator confirmation after publication.

Verification details and exact limits: `docs/acw01-ux-verification.json`. 50 focused browser checks PASS. TypeScript and final Production build PASS; scoped lint has 0 errors and 2 existing effect-state advisories. Synthetic EN/AR screenshots and focused local browser checks cover populated Supplier-specific views, native selection, report/GL navigation, font sizes, preview entry and Viewer visibility. Completed broad accounting tests are reused, not repeated. Production publication and post-publication UI acceptance remain **DEFERRED**. Source comparison confirms canonical preview/post/idempotency block, accounting report readers/calculations, Auth and all migrations unchanged. No hosted financial mutation, Supplier creation, invoice/payment posting, balance change, configuration change or migration. Migration94 remains the existing applied dependency.

Lifecycle: presentation/report navigation **VERIFIED locally**; unchanged accounting/authorization boundaries **VERIFIED by focused source comparison**; database changes **NOT APPLICABLE**; deployment **DEFERRED — no push/deploy**; original intermittent-close diagnosis **UNRESOLVED / not reproduced**. Preserve all original ACW specialist limits, Maker acceptance/Payroll, entity onboarding, commercial ERP roadmap and deferred recovery/USB work.

## 2026-11-14 — ACW-01 explicit Supplier navigation FIXED locally; publication pending

Confirmed presentation defect: `/supplier-invoices` was unregistered and reached the wildcard deferred screen, producing “Company access verified / Accounting records are not available.” It was not a Supabase authorization error. The deployed ACW-01 workspace exists under `/supplier-payments`; Product Owner confirms the observed legacy screen displayed no warning. No authenticated read failure or RLS defect was established, and no real-user JWT impersonation was performed. Public Production bundle contains ACW-01; CLI history confirms94aligned and hosted Supplier reader matches Migration94 with correct execution grants. The reported legacy-only browser screen was not independently reproduced in an attached authenticated session.

Small routing correction reuses the SAME existing workspace and canonical commands: sidebar **Supplier invoices** `/supplier-invoices` → Invoices; **Accounts Payable** `/accounts-payable` → Aging & statement; **Supplier statements** `/supplier-statements` → Aging & statement (select Supplier for existing exports/GL link); **Supplier payments** `/supplier-payments` → Payments. Existing tabs remain available. Route selection preserves current accounting intent and existing user/Company/role keying; no parallel forms, reports or accounting engine. Icons and EN/AR labels use the existing premium shell. Accounting Admin/Accountant retain entry actions; Management Viewer stays read-only; other roles receive no Supplier financial links/reads. Existing settlement availability is preserved; invoice module metadata identifies new-business requirements.

**26 focused browser checks PASS** through actual ProtectedApplication routes, CompanyWorkspaceShell/sidebar, TenantReadyApplication and Supplier workspace, using synthetic read responses and0hosted requests/financial commands. Covers four routes, EN/AR sidebar and invoice drawer, route-to-tab selection, Accountant/Admin/Viewer/non-accounting presentation boundaries. EN/AR screenshots inspected. TypeScript/Production build PASS; scoped lint0errors/2nonblocking state-effect advisories (existing async load and route synchronization); existing bundle-size advisory retained. Canonical input/preview/post/retry block, Auth, financial repositories and entire migration tree match base `269b4f9a628ee3ded238da6cf50e4622ac2d3592` exactly. No broad183check accounting suite repeated.

**Migration94 remains APPLIED; no new migration or hosted data/configuration change.** Prior activation preservation evidence is included at [Migration94 activation](acw01-migration94-hosted-activation.json); [navigation evidence/limits](acw01-navigation-verification.json). Base269b4f9 Production deployment is Product Owner-confirmed; this new navigation correction is prepared locally and NOT pushed/deployed. Operator publication and refreshed Production UI validation remain required. Existing Maker source/Party/financial/Payroll records untouched.

Lifecycle: presentation implementation, focused runtime, role visibility, unchanged accounting/authorization and documentation **VERIFIED locally**; database changes **NOT APPLICABLE**; publication and current-session Production acceptance **DEFERRED**. Existing AP specialist limits, remaining Maker acceptance and Payroll, entity onboarding, commercial roadmap and deferred restoration/USB requirements remain preserved. Earlier prepared-only Migration94 entries below are historical and superseded by its successful activation.

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
