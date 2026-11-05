# Imported source → canonical original-cost document

2026-11-05–06. A scoped vertical slice is implemented locally; migration83 is NOT APPLIED. This does not declare every imported-transaction destination complete.

## Reused accounting

Existing Historical Imports, Expense drafts/versioning, source completion, Project assignment, exact-money validators, canonical Expense commands, classified personal-cost recognition, journal/reporting and reversals remain authoritative. No parallel ledger or financial posting engine is introduced. New tables store only source/draft relationships and review evidence; draft lifecycle and money remain in existing canonical records.

Whole-source original operating/Project costs support actual cash, bank, Company-funded Custody and personally paid cost. Source capture, document DRAFT, REVIEWED, POSTED and REVERSED are shown separately. Source reports include linked journals and payment-document status; existing draft and project-cost Excel/PDF infrastructure is reused.

## Operator flow and controls

Open a General imported source, choose Create/open original-cost draft, and save incomplete working inputs. Source date/description are copied as unverified working values, VAT treatment starts blank, and no Company/project/payer/account is invented. Original source evidence is not modified. The source UUID supplies a reserved Company-scoped recognition identity.

An existing same-Company unposted draft can also be linked. Linking retains its immutable events, invalidates prior review, and requires source-specific review before posting; retries and competing ordinary-draft posting are protected. Sparse draft inputs retain explicit editable controls without inferring VAT.

Complete the existing source review and matching canonical draft. Review requires the same date, description and gross, approved Company ownership, actual payment evidence, distinct original-cost confirmation, correct Company masters, tax evidence and supporting references. Known duplicate groups and existing overlap candidates require a specific distinct-payment evidence reference. No automatic classification, zero-VAT inference or funding is created. Review is not a journal and does not promise sufficient funds at posting.

Post delegates to the existing Expense draft command, which delegates to canonical Expense/personal-cost commands. Existing period, funds, invoice uniqueness, immutable-history, Project and authorization controls remain active. The source version captured at review must still match; edits require re-review. Record plus journal and source linkage commit atomically. Lost responses reuse the identical request. Public generic-draft and legacy source-cash entry points cannot bypass a bound source claim; private delegates have no browser grants. Posted source cost dimensions/core completion cannot be administratively reassigned. Existing canonical reversals remain the correction mechanism; reversal never erases source lineage or authorizes automatic re-recognition.

Cancellation releases only a canonically CANCELLED nonfinancial claim, retaining the relationship and draft event history. A new draft may then be explicitly prepared. One active whole-source cost claim is enforced; this is a scope restriction, not a universal assertion that every source equals one Expense. Confirmed source splits continue through their existing flow; this conversion blocks rather than discards them.

Company is the security/accounting boundary. A Company-owner checkbox is an evidence attestation for the current authorized tenant, not permission to post another Company's costs. Cross-Company source transfer, invented intercompany receivables and service-role posting are not introduced. Management Viewer has General-source/document read access only. Existing payroll confidentiality is unchanged.

## Existing destinations versus deferred integration

Contractor settlement/advance, supplier settlement, Custody movements, HR employee advance and Partner funding/reimbursement retain their existing specialized commands and navigation. Focused compatibility scenarios exercise contractor payable settlement without new cost and an idempotent HR receivable advance without salary expense. These are handoffs, not automatic source-to-non-cost draft conversion or binding; they must not be reported as a fully integrated source lifecycle. No new module is justified.

Automatic non-cost document binding, multiple-source consolidation/partial-source recognition, cross-Company handover and a generic Treasury-transfer command are DEFERRED. Assets/inventory/prepayments remain blocked when unsupported treatment/workflow is unresolved. A contractor installment or employee advance cannot be converted through this original-Expense draft path. An outgoing source cannot be treated as an unpaid Supplier credit invoice.

## Migration and publication

Local canonical83: `20261105140000_historical_source_expense_drafts.sql`. It adds source-binding/review metadata, guarded wrappers, a read-only lineage RPC and immutable-source guard. It also forward-corrects Project Bank draft payment metadata to BANK; canonical money/posting logic otherwise remains unchanged. Applied migrations are not rewritten. Hosted project `eqnzueginpkskbnqvgoc` remains aligned through82;83 is absent. Current public interfaces remain compatible for unbound ordinary drafts; the legacy cash path remains available unless a source is claimed by the new workflow. New UI fails closed when source-document metadata is unavailable and preserves source visibility.

DO NOT PUSH/PUBLISH the matching frontend until83 has separate explicit hosted activation approval, preservation checks and successful postflight. This task applies no hosted migration, creates no Maker document, and performs no Maker source completion, opening/funding or posting. Owner Git push and Vercel confirmation are separate future gates. GitHub main was read-only verified at76298d5b0c86cacc9b5f303dec4c0cabfdc70e8d; the preceding source-review worktree exists and is clean. Vercel deployment of that commit was not independently verified.

## Evidence and limitations

Focused synthetic SQL, native concurrency and actual-component browser results are in `source-document-verification.json`; fixtures accept no hosted database URL. Actual Maker122 supplemental records are a read-only validation dataset:345 General sources remain, original supplemental fields match the captured payload, and zero Maker canonical Expenses/journals exist. No real source conversion was attempted. No recovery rehearsal, unrelated audit, salary import, automatic push or deployment occurred.

Business/accounting original-cost slice VERIFIED locally; broader destination integration DEFERRED. Authorization/tenant/locking/RLS controls VERIFIED within this slice. Database migration LOCAL ONLY, hosted activation DEFERRED. Testing/build/browser/export evidence recorded; actual authenticated Production workflow acceptance DEFERRED. Documentation reconciled. Final operational/security/DR gates remain separate.

## Reproduction

Run `node scripts/verify-source-expense-drafts.mjs` (51 checks), `node scripts/verify-source-expense-races.mjs` (5 independent-connection scenarios), and `node scripts/verify-source-expense-browser.mjs` (15 checks). Create `/tmp/narvo-source-documents` for evidence output. Native concurrency uses the existing isolated `embedded-postgres` installation in `/tmp/narvo-priority-native` or `/tmp/narvo-project-native`; browser checks require local Chromium and loopback permissions. None accepts a hosted database URL. Run the Production build and focused lint for the changed application files. No business fixture is written to Supabase. Known state-in-effect/dependency lint warnings remain non-blocking; zero lint errors.

## Maker operating prerequisites

The read-only dataset is validation evidence, not posting approval. Ownership, actual payer/Treasury or Custody, confirmed date, supporting references, tax treatment, appropriate master/account configuration and duplicate clearance remain transaction-specific prerequisites. Existing funding/recorded-funds safeguards remain blocking where the actual source has no evidenced balance. No openings, incoming funding or liability classifications are fabricated to unblock payment. The 122 supplemental records remain pending and unposted.

Final local results: 51 database checks PASS; 5 native concurrency scenarios PASS; 15 browser checks PASS; Production build PASS; focused lint zero errors / six warnings; `git diff --check` PASS; focused sensitive-artifact scan PASS. Candidate application source matches the verified workspace source. The existing bundle-size advisory is non-blocking. No hosted migration dry-run or activation was performed: fresh hosted release preflight remains a separate authorization gate.
