**Release update — 2026-11-05:** Migration80 is now hosted-applied and focused preservation/schema postflight is verified. Original local-development checkpoints below remain historical. Application/SQL/tests are unchanged; frontend publication awaits owner push and Vercel confirmation. See [actual release record](OPERATIONAL_EXPENSE_RELEASE.md), including the live Auth fingerprint exception and untested restoration limitation.

# Essential Expenses and Project Cost Integration — local implementation

2026-11-05. Published GitHub baseline `652bc37ba372bf4fa8bbf454da0bba921f5758fa` fetched and confirmed. Existing development branch aligned by guarded reference/index update only after all prior dirty files were proven identical to that published commit; original bytes and index backed up under `/tmp/narvo-before-expense-phase1`. No new commit or publication.

## Reused implementation and bounded gap

Existing authenticated Expenses supports immediate Treasury (Cash/Bank), Company-funded Custody and unpaid Supplier credit posting, VAT, source/category/Project dimensions, posted registers, specialized reversal and correction. Financial Operations already supports personally funded original costs and later reimbursement. Shared-cost allocation, custody consumption, liability settlement, project lifecycle, immutable journals, commercial readiness and all existing permissions remain canonical. No Treasury, Custody, opening or contract engine is rebuilt.

The operational gap was durable partial capture/edit/review before posting across those sources. New `ExpenseDraftWorkspace` lives in the existing Expenses screen, with a Drafts & review anchor, register, versioned edit/save, explicit review, accountant posting confirmation, cancellation and same-request retry. Saving incomplete source text creates no money or journal. Save needs no financial completion or review reason; review and posting require actual evidence and classification. Existing immediate-entry and reversal workflows are preserved.

## Database and accounting

Local migration80: `20261105110000_operational_expense_drafts.sql`. Additive new table, private validators and one constrained public command only. Applied migrations are unchanged. Depends on canonical76 evidence/review,77 accounting/actor/serialization and78 period checks, against published79 baseline. No backfill, historical update, account creation or hosted write. Existing frontend remains compatible; activate80 before publishing the new draft UI.

`expense_draft_events` is append-only, Company-owned and forced-RLS. Only existing active Accountant/Accounting Admin with `accounting.post` may command it. Management Viewer may read/export only. All direct authenticated writes, service-role grants, anonymous calls and public/private helper execution are denied. Fixed empty search paths; no browser-selected GL accounts/journal lines.

Every action checks expected version and actor-bound normalized JSON request hash under existing Company operational serialization (including repeatable-read conflict protection). Review validates complete source, matching accounting month, supported dates/known closed correction months, active Company masters, explicit original recognition, classification and actual funding location. Editing invalidates review. Review preview retains server-calculated exact net/VAT/gross strings. Financial posting revalidates the frozen reviewed snapshot. Duplicate original references across posted drafts are blocked Company-wide; canonical invoice guards still span Expenses and personal liabilities. Original references should uniquely identify the Company source, not a generic description.

Treasury/Custody/Supplier Credit delegate to existing `post_expense`. Personally paid employee/eligible accountable-person costs atomically delegate to existing evidence submission, review and `post_reviewed_financial_operation`; approved reimbursement control configuration is required. Thus Treasury credits real cash/bank once; Custody credits the holder asset once with no second Treasury movement; unpaid Supplier expenses credit Supplier payable; personal costs credit reimbursement payable with no fictional Treasury. Existing settlement/reversal commands retain original history and dependency controls. No parallel ledger and no Partner funding as revenue or withdrawals as expenses.

Money is exact BIGINT minor units at recognition; partial raw AED text is nonfinancial evidence. Maximum two decimals; deterministic canonical 5% rounding; explicit manual VAT and invoice evidence. Supported nature is Company operating expense or direct Project cost. Contract events, Partner transactions, custody transfers and asset/inventory purchases may be saved but cannot post through this ordinary-cost command. No capitalization policy or fictitious financial treatment is introduced.

## Reporting and operator behavior

Draft register Excel/PDF includes Company, source date, source/classification/funding, entered amount text, state, posted document and journal. No false accounting totals from incomplete drafts. POSTED is an original receipt, not current settlement/reversal status; the canonical register remains authoritative. Actual posted Expenses retains its existing totals, reversal and personal-cost coverage.

Project-cost UI and Excel/PDF now expose existing category/code, actual Treasury or holder/funding source, source/invoice and supporting reference alongside source ID, journal, Project/account and reversal lineage. Totals still derive only from authorized balanced EXPENSE-account journal lines. Assets/WIP, cash transfers, Partner withdrawals and commitments are not relabelled as costs; certified contract work is reported separately from cash payments. Existing scoped report notes and Payroll visibility remain intact.

EN/AR labels and RTL/LTR use existing components, export infrastructure and approved themes. Uncertain commands retain the identical request in the live component; retry or reload the durable server register. Session/Company changes invalidate in-flight display. Refresh or navigation may discard unsaved form edits; explicitly saved versions persist and can be resumed. No browser business-data store is introduced.

## Verification and publication boundary

Actual check results, migration hash and file inventory: [verification record](expense-lifecycle-verification.json). Focused disposable canonical SQL, independent native PostgreSQL races, browser and bilingual artifact checks cover the changed workflow. Hosted access is READ ONLY: exact project `eqnzueginpkskbnqvgoc`, canonical SQL1–79 alignment, and linked dry-run listing only80. No hosted financial command or migration activation.

Business/accounting, authorization/database and focused local tests: locally verified within supported scope. Deployment: DEFERRED, migration80 required and unapplied; frontend uncommitted/unpublished. Documentation: current scoped state recorded, broader M3 not complete. Hosted runtime/operator acceptance is deferred to an explicitly authorized release. No restore rehearsal, Maker import, cleanup, commit, push or deployment.

## Remaining boundaries

- Asset/inventory capitalization, depreciation and procurement are separate unfinished capabilities. Real asset purchases must remain unposted here until an approved asset workflow exists.
- Personal reimbursement is limited to the existing eligible person roles and approved Company liability mapping. No arbitrary owner/Partner-current-account treatment is invented.
- Existing supported correction-period closure is checked; a comprehensive fiscal-period closing engine remains deferred. No claim of general fiscal close certification.
- No invoice attachment storage redesign, supplier invoice authenticity/tax-recoverability certification, automated detection of semantically identical undocumented receipts, universal multi-source splitting or advanced approval hierarchy.
- Existing split-source workflows remain available; this draft increment handles one Project or overhead and one funding source per source transaction.
- Actual opening completeness, real cash/evidence reconciliation, tax/legal readiness, final Production Security & Accounting Integrity Audit, disaster recovery validation and operator acceptance remain independent Go-Live gates. This local implementation does not certify Maker's actual books.
