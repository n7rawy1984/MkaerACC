# Historical source review — operator readiness

2026-11-05. This is a bounded generic UI correction, not an accounting posting release.

Fresh read-only verification preserves all345 Maker General sources (223 earlier +122 supplemental), existing source evidence and19 financial/access table fingerprints. No actual source completion, canonical Expense draft, opening, funding or financial posting is created in this batch. All122 supplemental sources remain pending. Source capture, editable source review, accounting-ready and posted are separate states. No precise posting batch is approved.

## Corrected interface

- Imported monetary movements without a confirmed payment source show “Payment source unconfirmed”, instead of “No cash movement”. Invoice-only sources retain the no-cash label. Existing confirmed payment labels are retained.
- Possible duplicates show a visible bilingual warning and a candidate-reference button that filters the existing list; no source is deleted, merged or posted.
- Search accepts source filename as well as reference/description/party/category, allowing the supplemental workbook to be isolated.
- Existing HR/partner funding guidance links to implemented modules. Unverified route suggestions open review guidance only; they do not change transaction nature, enable posting or select accounting ownership.
- Excel/PDF General-source exports use the same unconfirmed-source distinction and include duplicate warnings/candidate references. Amount calculations remain unchanged.
- Nested original evidence renders readably in Details rather than `[object Object]`.

Existing source completion, tenant/role checks, source UUID idempotency, cash-only historical Expense wrapper, financial commands and RLS are unchanged. A review note is not an accounting Company assignment; any other-Company item remains provisional until owner/evidence and the supported authorized workflow are established. No cross-Company source transfer, new generic ledger or arbitrary journal input is introduced.

## Operator sequence

Open Maker → Expenses → imported financial transactions. Search the V2 filename after publication, or an exact source reference before publication. Open Edit to complete evidence-backed working description/date/category/nature and review notes; Details retains original evidence. Resolve duplicates first, then other-Company/project ownership, missing/conflicting dates and tax/classification questions. Use the existing Project assignment only after confirmed ownership. Actual payment-source confirmation, accounting controls and genuine dated funding/openings require their existing authorized workflows and approval; free-text references do not create them.

Conditional handoffs use Expenses, Custody, Subcontracts, Funding & reimbursements and Payroll → HR employee advances as appropriate. Opening a module neither posts nor automatically links the historical source. Inventory/asset/prepayment or unsupported ownership treatment stays pending. Do not recreate sources or ordinary Expenses to resolve a source-review hold.

The private122-row operator queue is `/tmp/narvo-operator-completion/operator-queue.{html,xlsx,pdf}` with exact evidence requirements in `operator-queue.private.json`. Triage groups are exclusive primary priorities, not sole blockers: A0 ready; B77 funding/opening plus common evidence checks; C11 date issues; D15 duplicate/overlap candidates; E3 other-entity hints remaining after duplicate priority; F16 classification/tax/recognition. Every row still needs confirmed legal owner, actual payment source and payment evidence. No raw financial workbooks, payloads or personal records belong in Git.

## Verification and release boundary

Production build and focused lint PASS;17 focused actual-component browser checks PASS, including all345 visible references, all122 edit forms, original preservation, duplicate navigation, provisional handoffs, bilingual mobile layout and Manager read-only actions. 24 report/workflow regression assertions,8 bilingual PDF content/fit checks and both actual XLSX package inspections PASS. See `source-review-operator-verification.json`. Browser verification uses isolated mocked transport with the read-only345-row snapshot; it is not authenticated Production edit acceptance. Real source edits or financial command acceptance are not claimed. No schema/RLS/grant/accounting change: migration NOT REQUIRED. Owner push and matching Vercel deployment/operator acceptance remain pending.

Business/source preservation VERIFIED; accounting recognition DEFERRED. Authorization design unchanged; UI role controls verified locally, actual-user hosted acceptance DEFERRED. Database current source/financial preservation VERIFIED; schema change NOT APPLICABLE. Deployment DEFERRED. Risk-focused tests/build recorded locally; unrelated suites not repeated. Documentation reconciled; final security/operational/DR gates unchanged.
