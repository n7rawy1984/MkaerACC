# Development Trial subscription — assignment preparation

**Latest lifecycle execution — 2026-11-01: PASS within approved Development scope.** Controlled expiry and cancellation each passed persisted/audit/preservation and fresh recipient identity/read acceptance; final Trial renewal is verified through2026-12-31, renewal2027-01-01, subscription4/Company8. Exactly one current row, total4 audits/receipts including initial assignment. All17 historical Companies/46 Company-owned tables and memberships/accounts/Main Cash/financial records preserved. No financial posting or new hosted write-denial probe; prior deterministic/concurrency enforcement evidence retained. Earlier baseline/pending/approval-proposal labels below are historical. [Actual execution and limits](MANUAL_COMPANY_SUBSCRIPTIONS_LIFECYCLE_EXECUTION.md). No further mutation authorized.

**Current lifecycle checkpoint — 2026-11-01:** exact Development Trial remains version1 / Company version5, ACTIVE/COMPLETE; current recipient identity/workspace/Trial display verified. Six new read-only hosted date/state evaluations PASS; unchanged reviewed sources and prior63/9/13 evidence retained. Renewal/expired/cancelled real-browser transitions remain pending separate explicit approval. Earlier zero-subscription/local-only/pending-recipient labels below are historical. [Minimum remaining acceptance and exact three-operation proposal](MANUAL_COMPANY_SUBSCRIPTIONS_LIFECYCLE_ACCEPTANCE.md). No hosted mutation performed for this checkpoint.

**Current execution: one approved assignment is committed and verified; owner display PASS; recipient display confirmation pending.** See [execution and attribution limitations](MANUAL_COMPANY_SUBSCRIPTIONS_TRIAL_EXECUTION.md). Earlier preparation values below are historical, not current versions.

2026-11-01 (Asia/Dubai). **PREPARED / NOT EXECUTED / SEPARATE ASSIGNMENT APPROVAL REQUIRED.** This is preparation for the first isolated Company subscription, not approval to create it. [Fresh read-only evidence](release/development-trial-subscription-preparation.json). Prior [migration/Preview activation](MANUAL_COMPANY_SUBSCRIPTIONS_ACTIVATION.md) remains verified; no deployment, migration or general audit was repeated.

## Fresh verified state

Target is healthy `MakerACC-Development`, project `eqnzueginpkskbnqvgoc`, with all 64 canonical versions aligned. The hosted mutation source matches the reviewed canonical migration. Actual hosted constraints and current UI options were inspected.

Exact Company: `NARVO-INVITE-TEST-20261101`, UUID `23ec33fa-8045-468d-bbdb-0c06d0a816f6`, name `NARVO Invitation E2E — Development — 2026-11-01`. Company/lifecycle ACTIVE, Company metadata version **4**, accounting COMPLETE, 11 accounts, one Main Cash/CASH Treasury. The existing recipient has the exact active ACCOUNTING_ADMIN membership. Metadata plan is UNASSIGNED, effective enrollment state UNMANAGED, **subscription version 0**, with zero subscription rows, assignment audit events or confirmed assignment receipts. Global subscription count is also zero; 17 historical Companies remain outside this fixture.

Company version and subscription version are separate: the assignment uses subscription `version: "0"`. The workflow also updates the existing entity plan metadata and increments Company metadata version **4 → 5**; Company lifecycle/status, books and memberships do not change. This expected metadata increment must be included in approval and postflight expectations.

## Existing schema values and selected payload

| Field | Actual allowed values | Selected value |
| --- | --- | --- |
| Plan | TRIAL, STANDARD | TRIAL (existing plan, no new plan) |
| Recorded state | TRIAL, ACTIVE, EXPIRED, CANCELLED | TRIAL |
| Billing method | NONE, MANUAL_CASH, MANUAL_BANK_TRANSFER, MANUAL_OTHER | MANUAL_OTHER |
| Payment status | NOT_REQUIRED, UNPAID, PAID, WAIVED | NOT_REQUIRED |
| Payment reference | Nullable text; Paid requires non-None billing and reference | Omit/leave blank → NULL |
| Start/end | Valid ordered ISO dates, supported range 2000-01-01 through 9999-12-30 | 2026-11-01 through 2026-12-01 inclusive |

`Manual` is not a literal enum value. **MANUAL_OTHER** is the existing generic manual method, appropriate because no cash/bank receipt or actual payment is being asserted. `None` must not be typed as a payment reference. No amount, financial entry, invoice, gateway operation or payment notification is involved. Trial state requires the existing Trial plan. The supplied period satisfies current rules; no fixed 30-day maximum exists in this implementation. This period spans **31 inclusive days**, renewal due **2026-12-02**. A pure, nonpersisted row evaluation confirmed Trial on the start/end dates and Expired after the end date; no clock or stored subscription was changed.

Prepared `set_company_subscription` business input (not sent):

```json
{
  "id": "23ec33fa-8045-468d-bbdb-0c06d0a816f6",
  "version": "0",
  "plan_key": "TRIAL",
  "subscription_state": "TRIAL",
  "starts_on": "2026-11-01",
  "ends_on": "2026-12-01",
  "billing_method": "MANUAL_OTHER",
  "payment_status": "NOT_REQUIRED",
  "reason": "Development E2E subscription trial acceptance"
}
```

A single request UUID is generated only for the separately approved execution and retained by the existing owner workflow. Actor identity is derived server-side; no owner/user ID or financial account is supplied in this payload.

## Exact approval scope

> Authorize ONE first Trial subscription assignment on Development eqnzueginpkskbnqvgoc for NARVO-INVITE-TEST-20261101, UUID23ec33fa-8045-468d-bbdb-0c06d0a816f6, expected subscription version0 and currently Company metadata version4. Use existing TRIAL plan/state, 2026-11-01 through 2026-12-01 inclusive, MANUAL_OTHER, NOT_REQUIRED, no payment reference, and audit reason “Development E2E subscription trial acceptance”. Use the existing Platform Owner Preview workflow with genuine fresh MFA and explicit reconfirmation. Permit only the expected Company plan/version metadata synchronization4→5, one subscription, one immutable administrative audit event and one durable request receipt. Then perform read-only owner/member acceptance and preservation checks. Do not renew, cancel, record a payment, post financial transactions, modify memberships/historical Companies, change configuration or deploy. Stop after verification.

Approval must explicitly accept MANUAL_OTHER as the concrete mapping of the proposed Manual billing. No execution is authorized by this preparation request.

## Planned execution and read-only acceptance

1. Before execution, reconfirm exact Company identity/ACTIVE/COMPLETE, Company metadata version4, subscription version0/no row/no conflicting assignment, verified Development Preview and genuine owner authority. Stop if state changed; never silently replace or renew an existing subscription. Use the existing protected Preview `https://maker-cz6z99kac-n7rawy1984-8059s-projects.vercel.app/platform/subscriptions`. If browser tabs/pointer change unexpectedly, pause before submission rather than guessing the target.
2. Once separately authorized, submit exactly the prepared payload through the owner workflow. Complete private fresh MFA if required, followed by explicit administrative reconfirmation. Never use management SQL to bypass owner MFA. Do not send codes/passwords in chat.
3. Read back exactly one Company subscription: version1, plan/state TRIAL, selected dates and manual metadata, SQL NULL payment reference, renewal due2026-12-02. While within the approved period, effective state TRIAL and subscription access FULL under existing role/Company rules. No automatic renewal or payment is implied. If execution happens after the period, report the date-derived effective state and request an updated date decision before assignment.
4. Verify Company plan metadata TRIAL and metadata version5, while ACTIVE/COMPLETE, the same11 accounts/Main Cash, existing recipient membership and all accounting records remain unchanged. Check one `set_subscription` immutable audit event with exact reason/before/after and one CONFIRMED durable request receipt. Verify current-row uniqueness/idempotency evidence **read-only**; no live duplicate/replay mutation is part of this acceptance.
5. Owner Preview should display Trial, dates, renewal due, manual method and Not required. Recipient's own private session should display the same Company's Trial/date/renewal status and retain authorized workspace reads. Confirm unrelated memberships/Company access remain unchanged using existing authorized read-only checks. No owner credentials are shared with the recipient.
6. Compare fresh before/after preservation fingerprints: the17 historical Companies and financial/membership data remain unchanged; only the specified subscription plus expected entity plan/version and its administrative audit/receipt may change. Record secret-free evidence and stop. Financial posting, expiry/cancellation/renewal transitions, payment notifications and cleanup are separate scopes.

## Verification and boundaries

Fresh hosted check used explicit READ ONLY transactions and did not invoke the mutation RPC. Schema/source, Company identity/version/enrollment absence and pure date/state validation **VERIFIED**. Future assignment, owner MFA/reconfirmation, durable write receipt and recipient subscription acceptance **DEFERRED pending approval**. Database/configuration/financial mutation, deployment and Git history operations **NOT APPLICABLE / NOT PERFORMED** in preparation. No build, old test suite or race gate was rerun because source was unchanged. Documentation/evidence **RECORDED**. Preservation this turn follows from read-only execution; the activation's46-table before/after evidence remains separately retained, not represented as a newly repeated financial audit.
