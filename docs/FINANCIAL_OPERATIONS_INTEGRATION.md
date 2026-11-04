# Partner funding, Treasury, Custody and personal reimbursements

2026-11-04 — supported increment implemented and locally verified. **Not hosted-activated or Production-ready.** Canonical baseline 75 is retained; new local migrations 76/77 are unapplied. The owner reports the preceding CUS-03/CUS-04 frontend already published; this increment has not been published.

## Implemented boundary

Existing CUS-03/CUS-04, Expense posting, journal/reversal kernel, Party statements, Treasury movements, Project-cost accounting and bilingual export infrastructure are reused. Canonical75 supports CASH as well as BANK custody issuance; the former frontend-only CASH prohibition did not describe the SQL capability. It is removed. Migration77 supplies actual database funds controls; publish this matching frontend only after approved database activation.

Authenticated `/financial-evidence` (Funding & reimbursements) captures original dated evidence, exact amounts, Partner/claimant, actual recipient, route, Treasury, Project and supporting references. Evidence capture/review never posts a journal. Multiple Company-scoped Partner identities are supported without creating Auth identities or financial balances. Latest evidence review and a separate financial confirmation are required before posting. Treasury movements links to the workflow. The Expenses page offers the existing Treasury form or the reused custody Expense workflow, preserving Supplier references.

Accounting Admin can create a restricted dedicated Party-required balance-sheet control or select an eligible existing one, with an explicit policy approval reference. Categories cannot share controls. Existing balances require explicit purpose/opening authorization; no existing balance is changed. Account mappings remain immutable; withdrawal-policy revisions are append-only. Same-key configuration recovery returns the original version and cannot reactivate superseded policy.

| Approved classification | Recognition | Supported outflow |
| --- | --- | --- |
| Capital | Credit dedicated Equity control by Partner | Capital reductions/distributions blocked |
| Additional capital | Credit separate Equity control by Partner | Capital reductions/distributions blocked |
| Partner current account | Explicit Company-approved Liability or Equity control | Explicitly authorized withdrawal bounded by recorded Partner credit at and after its date |
| Documented Partner loan | Credit separate Liability control by Partner | Principal repayment bounded by the original active loan |
| Personal reimbursement payable | Credit separate Liability control by claimant | Payment bounded by the original active claim |

There is no default loan classification, funding revenue, withdrawal Expense or automatic dividend. Classification-pending, distributions, counts and other unsupported categories remain evidence-only. Financing costs/interest, capital reductions, dividends, Partner overdrafts, inventory/assets/prepayments and unsupported tax treatment need their own policies/workflows.

## Accounting and recovery

Physical funding debits the actual mapped Treasury and credits the approved Partner control. Subsequent custody issue uses the existing canonical command: debit holder Custody / credit Treasury. Direct handover is captured as funding evidence first, then reviewed custody assignment posts **one** journal: debit the actual holder Custody / credit Partner control, with immutable evidence/recipient/Project links and no office cash movement or clearing residue. The operational funding record remains visible even when no Treasury cash passes through it.

Custody-funded operating/Project Expense uses the existing command once: cost and eligible VAT debits / holder Custody credit. Return restores Treasury and reduces Custody; settlement only groups Expenses and never posts cost again. Personal-funded cost recognizes cost/eligible evidenced VAT and a separate claimant payable, never reduces funded Custody, and requires original-cost attestation. Payments settle that payable without recreating cost. Active invoice identity (Company, Supplier, normalized invoice) is protected across personal recognition and ordinary Expense posting; reversed recognition permits a corrected new event. Sources and posted history remain immutable.

Specialized server commands derive the actor, require active profile/Company/membership and explicit permissions, validate Company-consistent dimensions and authoritative mappings, and use normalized idempotency with atomic document+journal commits. New recognition requires commercial readiness. Existing debt repayment and eligible reversals remain independent of that new-recognition gate. AA controls reversals; active dependent payments block original recognition reversal. Closed-Project guard adds only non-cost personal reimbursement settlement; new recognition/cost remains blocked.

All new tables have forced Company RLS, read-only financial-role grants and immutable audit records. Generic journal primitives and serialization records remain private. Browser recovery stores only an actor/Company-scoped frozen request and receipt, never financial balances. Lost responses/reloads reuse the original key. Definite first-dispatch rollback permits correction; unknown outcomes retain the request.

Migration77 guards **every new Treasury and custody journal outflow**, including existing deployed commands, against a negative date-ordered recorded balance, with private version serialization protecting competing commands and stale Repeatable Read snapshots. Those versions store no monetary balances. Actual receipts may improve incomplete legacy balances; further outflows require sufficient recorded funds. This is not physical cash certification, a bank overdraft facility or a substitute for opening evidence.

## Reporting and limitations

Partner and holder statements retain separate GL accounts, dated opening/activity/closing, source/journal/reversal proof and approved classification labels. Direct funding feeds CUS-03 funding exactly once. Personal liabilities remain separate from Custody. Treasury GL movement reports exclude fictitious direct-handover cash. Project-cost ledger proves personal recognition and reversal; payments/funding do not create cost. Expense exports add a distinct personal-cost section, with explicit unavailable status if that source cannot be verified. Funding/reimbursement exports separate category totals and original loan/claim outstanding amounts, with source, Project, recipient, Supplier/invoice and journal references. Arabic RTL/English LTR Excel/PDF reuse the current infrastructure.

Visible posted opening movement is **not a certified opening balance**. Restricted Payroll Treasury coverage is marked partial; cash-count snapshots require Payroll visibility. Cash-count differences remain evidence and never generate an adjustment or reimbursement automatically. Complete certified historical openings/import, bank matching, fiscal-period closing and physical reconciliation certification remain incomplete. No new general period-closing policy is invented; existing kernel, Payroll, correction-period and Project restrictions are retained.

## Verification evidence

All fixture writes below use disposable local databases and synthetic identities; no hosted business records were created.

- `verify-priority-financial-integration.mjs`: 24 evidence, authorization, source uniqueness and reused CASH/custody Expense checks PASS.
- `verify-operational-liability-posting.mjs`: 43 accounting, configuration, RLS, retry, reversal, cross-workflow invoice, dated correction/dependency and actual report-reconciliation checks PASS.
- `verify-priority-financial-races.mjs`: three native evidence/review races PASS (retained applicable evidence).
- `verify-operational-finance-races.mjs`: six native races PASS, including different-holder Treasury overspend, Partner current overdraft, claim overpayment, same-key funding, stale snapshots and personal-vs-Expense invoice recognition.
- `verify-priority-financial-browser.mjs`: 16 actual evidence/custody Expense, read-only/session, Arabic/English and responsive checks PASS.
- `verify-operational-finance-browser.mjs`: nine actual account-creation/configuration, classified posting, lost-response reload/replay and bilingual/responsive checks PASS.
- Both export inspection scripts: four checks each PASS on generated Excel/PDF contents, exact numeric amounts, original references and direction.
- Production build, focused lint, production import boundary, changed-file secret-pattern scan and whitespace checks PASS; machine-readable results, SQL hashes and the complete file list are in [financial-operations-verification.json](financial-operations-verification.json). Existing chunk-size warning and two recovery-effect lint warnings are informational.

Artifacts are `/tmp/narvo-{priority-financial,operational-finance,operational-liability}-*.{json,log,png,xlsx,pdf}`; reproducible scripts are in `scripts/`. No gallery/prototype or unrelated audit was created.

## Activation boundary

Apply **neither migration automatically**. Order is76 (`20261104180000_financial_operation_evidence.sql`) then77 (`20261104190000_operational_liability_posting.sql`), after validating recovery, exact target, canonical alignment, hashes and separate explicit approval. No blanket push. Recovery and hosted alignment were not re-audited in this feature batch.

Before activation, inspect existing dated Treasury/holder balances and genuine opening completeness: migration77 intentionally changes insufficient-funds behavior for old clients too. Resolve actual evidence gaps through authorized workflows, never synthetic funding. Rehearse migration and old-client financial commands on an isolated restore; confirm protected identities/history and prior balances unchanged. Activate approved SQL, verify grants/RLS/definitions and unchanged financial records read-only, then publish the matching frontend under separate owner authorization. Do not deploy this frontend against baseline75 as a release candidate: its new CASH entry expects77's database safeguards. Unapplied new financial RPCs fail closed; existing unrelated routes are preserved.

Business/accounting, security/authorization, database design/local application, testing and documentation: **VERIFIED within the listed local supported scope**. Hosted alignment, recovery rehearsal, migration activation, human hosted workflow acceptance and release/Production validation: **DEFERRED and blocking activation**. Full financial domain, CUS-01/02/03 and broader M3/M4 are not declared complete. Next functional increment is certified opening/history and physical/bank reconciliation under approved policy; first release step is recovery/impact rehearsal and owner review.

Frontend rollback does not reverse posted documents or remove database safeguards. Preserve new source history and migrate forward under separate approval; never drop populated financial tables or remove accounting controls as a deployment rollback. The known shared target must be reconfirmed at the future activation gate; no hosted connection or recovery claim was made in this batch.
