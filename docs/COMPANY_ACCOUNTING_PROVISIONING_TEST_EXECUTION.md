# Development test Company — accounting foundation provisioned

**Current recipient acceptance — 2026-11-01: VERIFIED.** A live `auth.getUser()` in the existing approved Development Preview confirms `n7rawy19840@gmail.com` / `0137311f-5ab7-491d-b101-8eda15b5830f`, not Platform Owner. The same session displays the exact test Company, ACCOUNTING_ADMIN, foundation COMPLETE, Trial valid through2026-12-01 and renewal2026-12-02. Read-only database evidence confirms its sole intended active membership and no Platform Owner registry entry. This new identity-qualified observation supersedes current-session pending labels only; earlier unattributed browser observations remain withdrawn. Exact11-account/Main Cash database evidence remains valid; no new complete recipient-bound listing or financial posting test is claimed. [Reconciliation and evidence](TEST_SESSION_IDENTITY_RECONCILIATION.md).

**Identity evidence correction — 2026-11-01:** the owner reports accidental Platform Owner sign-in during some prior recipient tests. Earlier recipient-specific browser attribution is **UNVERIFIED/WITHDRAWN**, while observed UI content and all valid database/migration/accounting/concurrency evidence are retained. This is an operator testing error, not an application defect. Current session verification and qualified acceptance are tracked in [the reconciliation](TEST_SESSION_IDENTITY_RECONCILIATION.md).

2026-11-01. **FOUNDATION DATABASE VERIFIED / EARLIER RECIPIENT VISIBILITY ATTRIBUTION UNVERIFIED.** [Before/after and read-only evidence](release/development-test-company-provisioning-result.json). Verification13:02:55 Asia/Dubai. This is the separate owner-approved Company operation following the completed Development activation; no deployment or migration was performed here.

## Exact scope and execution

- Development: `eqnzueginpkskbnqvgoc`.
- Company: `NARVO Invitation E2E — Development — 2026-11-01`, code `NARVO-INVITE-TEST-20261101`, UUID `23ec33fa-8045-468d-bbdb-0c06d0a816f6`.
- Authorized version3; actual preflight ACTIVE/version3/accounting INCOMPLETE, accounts0, Treasury0, provisions0, provisioning audit0, receipts0. No fixture journals/lines/expenses/reference counters. Existing hosted function source matches the accepted implementation. All17 historical Company/46-table preservation fingerprints and Stage D membership/invitation state match the previous verified baseline.
- Approved Treasury `Main Cash`, type CASH, bank name absent. Exact reason: `Initial accounting foundation setup for isolated Development E2E test.`
- Used the genuine owner workflow on `https://maker-bkylvumek-n7rawy1984-8059s-projects.vercel.app`. Paused before submission when Chrome changed tabs; resumed only after Browser idle confirmation and refreshed preflight. Filtered the exact Company, entered only approved fields and checked the normal administrative confirmation.
- The saved request hit the genuine fresh-MFA gate before provisioning. Owner verified/reconfirmed privately. The UI then already showed the exact Company UUID confirmed; authoritative readback showed one committed foundation. No additional submission or live hosted retry was made. No Auth token/password/MFA code was exported; no SQL identity impersonation or privileged browser secret was used.

## Verified result

Company remains **ACTIVE**, entity version **4**, accounting setup **COMPLETE**. Owner directory displays Accounting foundation complete; initial Provision accounting action is absent. [Safe result capture](release/development-test-company-provisioning-complete.png).

| Code | Account | Type | System key |
| --- | --- | --- | --- |
| 100000 | Primary Treasury | ASSET | None |
| 120000 | Input VAT | ASSET | INPUT_VAT |
| 130000 | Custody advances | ASSET | CUSTODY_ADVANCE |
| 140000 | Subcontractor advances | ASSET | SUBCONTRACTOR_ADVANCE |
| 210000 | Supplier payable | LIABILITY | SUPPLIER_PAYABLE |
| 220000 | Subcontractor payable | LIABILITY | SUBCONTRACTOR_PAYABLE |
| 230000 | Subcontractor retention payable | LIABILITY | SUBCONTRACTOR_RETENTION_PAYABLE |
| 240000 | Salary payable | LIABILITY | SALARY_PAYABLE |
| 510000 | Project cost | EXPENSE | PROJECT_COST |
| 520000 | Subcontractor project cost | EXPENSE | PROJECT_COST_SUBCONTRACTORS |
| 530000 | Company expense | EXPENSE | COMPANY_EXPENSE |

Exactly11 ACTIVE accounts, ten supported system keys, expected types/Party flags, no parent accounts, all owned by the exact Company. `OWNER_CURRENT` count0. Generated account IDs exactly match the unique private provision record's11 IDs; actor creation/update provenance matches across accounts, Treasury, provision, audit and receipt.

Exactly one **Main Cash**, CASH, code PRIMARY, ACTIVE, no bank/Project. Treasury UUID `1393da70-b458-4e5a-8f45-b1011ad178c5`; permanent GL UUID `843e1369-1ea6-4264-8292-0c344ac3589e` is account100000, an ordinary active Asset with no system key or Party requirement. No balance/funding entry was created.

One `CONTRACTING_BASELINE_V1` provision record, one immutable provisioning audit event with the exact approved reason, and one durable CONFIRMED receipt. Request UUID `c8ab51fd-639d-4b56-b9f8-09072e5f352d`; actual owner actor UUID `ebcf7115-6cd9-49be-af25-8e57b5befd75`.

## Read-only retry/duplicate verification

Stored normalized request hash matches the exact approved version3 input; stored template/intent hash matches the approved Company/Treasury intent, excluding version/reason as designed. Durable receipt matches Company, request ID, command and CONFIRMED status. Existing private Company PK, actor/request PK, normalized account-code/system-key uniqueness, Treasury code uniqueness and one-to-one Treasury/GL uniqueness remain present. No duplicate account codes/system keys, Treasury, provision or provisioning audit/receipt exists. Hosted function source hash is unchanged from the accepted implementation.

These checks verify the actual persisted request and duplicate-prevention/recovery structure without another mutation. **No live hosted retry was submitted or claimed as tested.** Previously accepted55 database,10 browser and6 independent native race checks provide the behavioral retry/concurrency evidence; they were not repeated.

## Preservation, limitations and stop

All17 historical Companies and all46 historical Company-owned table fingerprints are unchanged across this operation. All membership rows globally and the exact accepted invitation remain unchanged. Canonical history remains63 migrations. Fixture journals0, journal lines0, expenses0, reference counters0. No funds, opening entries, expenses, owner-current transactions or financial posting were created; no historical financial values were modified. Existing posted accounting truth remains untouched.

No Auth/Vercel/hosted configuration, invitation delivery, Production/Staging, migration, deployment, Git commit/push/merge or cleanup action was performed. The only intended durable changes are the exact test Company's11 accounts, one Treasury, unique provision evidence, immutable audit, request receipt and COMPLETE/version4 metadata.

The owner subsequently confirmed real Development recipient-browser acceptance: the authorized ACCOUNTING_ADMIN opened the exact test Company workspace and saw all11 provisioned accounts and Main Cash. This reported visibility did not independently verify the browser identity and therefore does not establish recipient account/Treasury visibility. It does **not** verify funding, Expense posting, payments, journals, reversals or any other hosted financial operation. No provisioning was repeated to record this confirmation. Funding and actual operation-specific masters remain separate. OWNER_CURRENT treatment is still excluded/undefined for future owner-funded operations. Baseline COMPLETE does not mean commercial onboarding or production accounting readiness.

Lifecycle: business/accounting **VERIFIED** for the approved foundation/no-posting scope; security/authorization **VERIFIED** through genuine owner/fresh MFA/normal confirmations and unchanged membership boundary; database **VERIFIED** for counts/mappings/provenance/receipt/preservation; deployment **NOT APPLICABLE** to this operational batch; testing **VERIFIED** through actual hosted readbacks and owner UI, with no live retry claim; documentation **VERIFIED** in this report/evidence/handoff/roadmap. Earlier recipient account/Treasury visibility **UNVERIFIED as to session identity**; hosted financial posting **DEFERRED / UNTESTED**. **Stopped after verification; no additional provisioning is authorized.**
