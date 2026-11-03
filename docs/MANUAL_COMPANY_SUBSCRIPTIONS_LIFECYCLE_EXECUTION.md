# Development subscription lifecycle — controlled execution

2026-11-01 (Asia/Dubai). **PASS — THREE APPROVED TRANSITIONS, EACH WITH PERSISTED/AUDIT/PRESERVATION AND FRESH IDENTITY-BOUND RECIPIENT ACCEPTANCE.** [Secret-free execution evidence](release/development-manual-subscriptions-lifecycle-execution-result.json). [Reviewed exact sequence](MANUAL_COMPANY_SUBSCRIPTIONS_LIFECYCLE_ACCEPTANCE.md). Stopped after verification; no further hosted mutation is authorized by this execution.

## Scope and method

Only Development `eqnzueginpkskbnqvgoc`, Company `NARVO-INVITE-TEST-20261101` / `23ec33fa-8045-468d-bbdb-0c06d0a816f6`. Fresh initial guards verified ACTIVE/COMPLETE, Company5/subscription1, one existing Trial/audit/receipt,64 migrations and sole intended active recipient membership/no owner privilege. Scoped preservation baselines captured46 Company-owned tables and17 historical Companies, plus private provisioning/financial/admin state.

Agent filtered the exact Company and prepared each approved form using the existing real owner workflow. Each time the owner reviewed and submitted once, performed genuine MFA/explicit reconfirmation privately if prompted, and replied separately “Expiry confirmed”, “Cancellation confirmed”, “Renewal confirmed”. The agent did not click final administrative confirmations, impersonate identity, call mutation RPCs via management SQL, or automatically retry. Exact expected owner actor, normalized approved payload hash and durable audit/receipt were verified after each action. Private passwords/MFA/click details were not observed; no token/password/code was read or logged.

Before each next mutation, fresh exact-version guards passed and the previous recipient gate was complete. Common approved values stayed TRIAL plan, MANUAL_OTHER, NOT_REQUIRED, SQL NULL reference. No payment record or financial posting was created.

| Transition | Approved saved state/period | Result subscription / Company version | Recipient / owner acceptance |
| --- | --- | --- | --- |
| Controlled expiry | Recorded TRIAL,2026-10-01–2026-10-31; derived EXPIRED | 2 / 6 | Both show Expired; member RPC LIMITED, reads preserved. |
| Cancellation during otherwise-valid period | CANCELLED,2026-11-01–2026-12-01 | 3 / 7 | Both show Cancelled despite valid dates; member RPC LIMITED, reads preserved. |
| Trial renewal/reactivation | TRIAL,2026-11-01–2026-12-31 inclusive | 4 / 8 | Both show Trial; member RPC FULL, valid throughDec31, renewal2027-01-01; limited warning removed. |

After each step: exactly one new immutable `set_subscription` before/after audit and one CONFIRMED durable receipt; approved reason/hash/actor match; prior audits/receipts unchanged. Final inventory: **one current subscription row, version4; Company version8; total4 subscription audits and4 confirmed receipts**, including the original Trial assignment. Renewal updates the current row; no second/conflicting active subscription. No deliberate replay/stale mutation was used; existing63 DB/9 fixture-browser/13 independent native cases remain accepted and were not rerun.

## Fresh recipient acceptance at all three stages

Each stage ran a new existing-client `auth.getUser()` in the dark-profile recipient browser, outputting only safe selected identity/project/origin fields. All three confirm `n7rawy19840@gmail.com` / `0137311f-5ab7-491d-b101-8eda15b5830f`, Development project URL and approved Preview `https://maker-cz6z99kac-n7rawy1984-8059s-projects.vercel.app`. This is independent of earlier assumed-recipient screenshots; the [identity reconciliation](TEST_SESSION_IDENTITY_RECONCILIATION.md) remains valid and earlier unsupported attribution stays withdrawn.

Actual member SDK/RLS reads after each transition returned the matching subscription/access/dates, **all11 expected account codes**, only **Main Cash/CASH**, and only the exact approved ACTIVE Company, with no read errors. These are authenticated browser SDK read results; they are not a claim of manually inspecting every account-row widget. The workspace itself visibly displayed exact Company/ACCOUNTING_ADMIN/COMPLETE and corresponding Expired/Cancelled/Trial banner/date/policy. Owner directory separately agreed.

- Expiry: [fresh identity/member reads](release/development-subscription-expiry-recipient-live-read.png), [workspace](release/development-subscription-expiry-recipient-workspace.png), [owner](release/development-subscription-expiry-owner-verified.png).
- Cancellation: [fresh identity/member reads](release/development-subscription-cancellation-recipient-live-read.png), [workspace](release/development-subscription-cancellation-recipient-workspace.png), [owner](release/development-subscription-cancellation-owner-verified.png).
- Renewal: [fresh identity/member reads](release/development-subscription-renewal-recipient-live-read.png), [workspace](release/development-subscription-renewal-recipient-workspace.png), [owner](release/development-subscription-renewal-owner-verified.png).

Native Console/focus handling required read-only retries and restoring existing windows. Incomplete unexecuted diagnostic input was cleared; no paste-protection override, account switch or session export was used. DevTools were closed after checks; both sessions preserved. No administrative mutation was retried because of a browser-control issue.

## Blocking and financial-access evidence boundaries

Fresh preflight verified exact reviewed hosted `guard_subscription_new_business` source and20 enabled business-access triggers, plus the separate plan-metadata guard. A local verifier initially miscounted21 triggers for the business function alone; targeted diagnosis confirmed20+1, and only that temporary verifier was corrected before any mutation. No application/schema defect was found.

Expired/Cancelled LIMITED policy blocks new business/masters and specified operational draft edits while preserving role-scoped reads and existing settlement/reversal permission. This is supported by live unchanged enforcement plus retained63 deterministic/native13 behavior; **no new hosted write-denial probe was submitted**. The browser policy notice alone is not treated as proof of rejected writes. All original financial permission, Company lifecycle, dimension, balance and reversal-dependency checks still apply.

No financial source exists here for an approved real settlement/reversal test, and none was invented. Successful expired settlement/reversal remains prior disposable-engine evidence; native expiry/cancellation missing-source probes remain nonposting permission/source-validation evidence. This execution does not claim successful hosted posting, settlement, reversal, payment collection or actual midnight rollover. FULL after renewal does not grant new permissions or prove a financial posting.

## Preservation and final state

Every transition's postflight matched the fresh baseline for all46 Company-owned tables globally and for17 historical Companies. Existing Company rows, memberships,11 accounts/Main Cash, all financial data, provisioning and invitation state, financial command requests/reference counters and unrelated private administration remained unchanged. Only the exact subscription, expected test-entity plan/version metadata and three new audits/receipts changed. Company stays ACTIVE; foundation COMPLETE. No historical enrollment or other subscription change.

Final: TRIAL/TRIAL, **2026-11-01–2026-12-31 inclusive**, renewal **2027-01-01**, MANUAL_OTHER/NOT_REQUIRED/NULL; subscription4/Company8. No financial transactions/payment records/settlement entries, Auth/Vercel/Production configuration, deployment, migration, commit/push/merge, membership edit or cleanup action. Production was not accessed for mutation; earlier Production deployment/configuration evidence is retained, not represented as a fresh full Production audit.

## Completion categories

Business/service lifecycle **VERIFIED** within the approved three-transition scope; hosted financial operations, paid Standard lifecycle and broader commercial readiness **DEFERRED**. Authorization **VERIFIED** for protected owner command actor/receipts and fresh recipient sole-Company reads, without a new broad audit. Database versions/uniqueness/audit/receipt/preservation **VERIFIED**; schema work **NOT APPLICABLE**. Deployment/configuration **NOT APPLICABLE**. Testing **VERIFIED** for three persisted transitions plus three fresh identity-bound browser/read gates; live write-denial probes/financial operations **DEFERRED**. Documentation/evidence **RECORDED** and locally validated. Local implementation/concurrency suites were not repeated. This bounded Development acceptance does not establish commercial or Production readiness.
