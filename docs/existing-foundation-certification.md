# Existing-company foundation certification — CR-07 activation gap

2026-11-20. Local implementation only, based on deployed CR-07 `b637893f2fbbe93d785cbb057ca53b97eafe502c`. Hosted history was read-only verified through105; only106 is locally pending. No hosted customer, subscription, readiness, membership, account, financial transaction or schema was changed. The previous85 scenarios/90 journals/3 reversals/183 checks and genuine authenticated acceptance were not rerun or replaced.

## Implementation

Existing Platform Owner Companies and Customer onboarding pages now offer **Review / certify existing foundation**, in Arabic/English. The review uses a protected reporting RPC; certification uses the existing live-session Platform Owner/fresh MFA boundary, normalized idempotency requests, Company/operational serialization, immutable certification evidence and platform audit events. The server repeats validation at certification. Failed validation writes no certificate or financial data. Different concurrent requests converge to one certificate/event. An expired/revoked/unauthorized session cannot certify.

The original empty-company provisioner remains unchanged. A separate immutable certification record is accepted by the canonical commercial-readiness function as evidence of the existing foundation; no counterfeit eleven-account provisioning receipt is created. Enrollment, customer creation/association, active lifecycle and manual trial configuration reuse existing commands and pages. Company `version=0` is correctly presented as unenrolled rather than suspended. No Company UUID is hardcoded in application or migration logic.

## Validation scope

- ACTIVE Company, ACTIVE BUSINESS platform entity, active Accounting Admin/profile.
- Ten baseline stable control keys, canonical account types, active status and correct Party requirements.
- Active Treasury, Company-consistent asset GL mapping, Bank name where applicable, no unexpected system key/Party requirement, no negative recorded Treasury balance without supported overdraft policy.
- Account hierarchy types and no cycles.
- Every existing journal has at least two lines and balanced exact numeric debit/credit totals; line amounts and Company/account/Party/Project/Contract/Treasury dimensions are consistent.
- Existing unreversed certified opening positions reconcile with GL at their cutover; posted opening links remain valid. No opening is invented or required where none exists.
- Configured fiscal periods stay within years, do not overlap and cover retained journal dates. Closed historical periods remain valid. If fiscal years have never been configured, report `EXISTING_UNCONFIGURED` explicitly and preserve the existing opt-in policy—no new fiscal calendar is invented.
- Canonical journal immutability triggers are enabled.

The certificate records scope, checks, timestamp, counts, debit/credit totals and account/journal/line hashes. It is a structural point-in-time validation, **not** full historical invoice/recognition, tax, subledger, external bank statement or physical-cash certification. Future accounting commands and authorization remain authoritative.

## Actual V1 read-only outcome

Existing Company `V1-DEMO-20260929`, UUID `d3292026-0929-4000-8000-000000000001`, remains ACTIVE with12 accounts/117 journals. Total debit=credit **1,822,122 minor units**. Current Books were not changed. The finalized validation SELECT ran in a hosted READ ONLY transaction without installing106.

**NOT presently certifiable**. Exact failures:

1. `ENROLL_BUSINESS`: no platform entity/customer association. Existing active admin membership already passes.
2. Six `CONTROL_MAPPING` failures: existing active correctly typed `CUSTODY_ADVANCE`, `SALARY_PAYABLE`, `SUBCONTRACTOR_ADVANCE`, `SUBCONTRACTOR_PAYABLE`, `SUBCONTRACTOR_RETENTION_PAYABLE`, `SUPPLIER_PAYABLE` accounts all have `requires_party=false`; canonical control policy requires true. They are not missing accounts: do not duplicate them. Any authorized correction must first review historical dimension coverage and supported account-edit constraints; certification does not alter them or weaken that requirement.
3. `TREASURY_MAPPING`: active Bank `DEMO-BANK` has no bank name.
4. `TREASURY_BALANCE`: `DEMO-BANK` has a negative recorded balance. Reconcile the existing fictional funding/payment evidence and authorize an appropriate supported correction separately; do not manufacture cash, opening balances or an overdraft exception.

There is no subscription row (`UNMANAGED`), and no foundation or legacy eligibility record. Do not add legacy eligibility as a readiness bypass. See the scoped read-only preview and mapping evidence beside the test results.

## Remaining activation steps requiring Product Owner approval

1. Approve applying only106 to the existing target through the established migration activation/preservation workflow; do not publish the new UI before its RPCs exist.
2. Publish this compatible isolated release through the existing owner-controlled Git/Vercel flow.
3. Approve the exact fictional customer association/classification, reviewed fixes for the six Party flags, verified Bank name and evidence-backed resolution of negative Bank balance. Preserve all posted journals; any financial correction is a separate explicit scope, never an automatic setup mutation.
4. A registered Platform Owner with fresh MFA uses `/platform/onboarding?company=d3292026-0929-4000-8000-000000000001`, associates the approved customer with BUSINESS classification and retained ACTIVE lifecycle, reviews and certifies only once all checks pass. No new Company/user/membership is required.
5. Product Owner selects/approves explicit trial start/end dates. Platform Owner uses canonical Subscriptions: plan/state TRIAL, billing NONE, payment status NOT_REQUIRED. No subscription was activated in development.
6. Read-only verify `ready=true`, then complete only the remaining new-business genuine authenticated acceptance in this same fictional Company. Existing authenticated correction and simulation evidence remains valid; unrestricted new-business readiness is not yet claimed.

## Definition of Done

- Business/accounting: VERIFIED locally; actual V1 configuration/cash discrepancy remains DEFERRED for scoped approval and evidence, not bypassed.
- Security/authorization: VERIFIED targeted unauthorized actor, tenant, live MFA and direct-write denial; existing RLS/financial permissions untouched.
- Database: VERIFIED local additive106, single-statement snapshot validation and independent native concurrency; hosted application DEFERRED pending explicit authorization.
- Deployment: compatible app requires106 first; push/deploy DEFERRED to Product Owner. No hosted dry-run/application executed in this local-only task; read-only version alignment VERIFIED.
- Testing: focused local database/browser/native evidence, TypeScript and Production build recorded in the verification manifest. No previous183-check replay. Genuine Auth for the new certification command after publication remains DEFERRED; browser regression uses synthetic Auth locally and does not substitute for the retained genuine acceptance.
- Documentation: this record plus canonical roadmap/handoff/requirements updated. Prior commercial roadmap and deferred recovery tasks preserved.
