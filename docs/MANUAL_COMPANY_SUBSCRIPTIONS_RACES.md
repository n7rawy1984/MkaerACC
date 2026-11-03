# Manual subscriptions — final independent local concurrency gate

2026-11-01. **PASS — 13/13 controlled native independent-connection scenarios.** Scope: targeted verification of the existing implementation before Development activation. Earlier 63 database / 9 browser checks, build, lint and boundary checks remain separate accepted evidence; they were not repeated.

## Method and contracts

Reused the Company Accounting Provisioning disposable native-server approach. Installed only pinned `embedded-postgres@18.4.0-beta.17` under `/tmp/narvo-subscription-postgres-runner`; system PostgreSQL 17 client tools exist, but server binaries are unavailable. No repository dependency or existing database was changed.

Harness: `scripts/verify-manual-subscriptions-races.mjs`. Reproduce with the pinned optional runner:

```sh
env -u DATABASE_URL -u SUPABASE_DB_URL -u SUPABASE_DB_PASSWORD -u SUPABASE_ACCESS_TOKEN -u SUPABASE_SERVICE_ROLE_KEY \
  PLATFORM_POSTGRES_RUNNER=/tmp/narvo-subscription-postgres-runner/node_modules/embedded-postgres/dist/index.js \
  node scripts/verify-manual-subscriptions-races.mjs
```

The harness accepts no hosted connection string and explicitly starts its own PostgreSQL on loopback, a dynamic port and a unique `/tmp/narvo-subscription-races-*` data/socket directory. All 64 canonical migrations replay into this disposable server with synthetic Auth identities, registered owner, live sessions and fresh TOTP claims. This does not claim genuine hosted MFA verification. Two independent backend PIDs are asserted distinct and recorded. A third observer checks actual `pg_stat_activity` lock waits, rather than assuming concurrency from Promise scheduling.

The mutation contract uses the existing owner authorization advisory lock, then Company and subscription row locks, expected **subscription** version, normalized request hash, one current row per Company and durable request/audit receipts. Company lifecycle has a separate **Company** version. Assigning or renewing a subscription increments entity metadata version but never activates a suspended Company. A subscription labelled ACTIVE on an INACTIVE Company does not grant Company access. Expiry is derived from inclusive Dubai dates; it does not rewrite Company status or memberships.

## Controlled schedules

| Schedule | Required and observed outcome |
| --- | --- |
| Simultaneous first enrollment, distinct keys | One current row/audit/receipt; waiting stale version rejects `40001`. |
| Concurrent renewals, same expected version | First renewal's payment reference retained; second rejects `40001`; one current row and exactly one new audit/receipt. |
| Same UUID, normalized same intent | Identical recovered receipt; no duplicate subscription or payment metadata. |
| Same UUID, conflicting intent | First intent retained; second rejects `22023`. |
| First creation rolls back | Waiter resumes and creates exactly one row/audit/receipt; first leaves no durable effects. |
| Cancellation wins versus renewal | CANCELLED remains; stale renewal rejects `40001`. |
| Renewal wins versus cancellation | Renewal remains ACTIVE; stale cancellation rejects `40001`. |
| Date expiry versus read/settlement/reversal probes | Reads see committed MVCC state while owner change is open; after commit see EXPIRED/LIMITED. Member master read remains available. Missing-source probes reach `23503`, not subscription authorization denial. |
| Cancellation versus read/settlement/reversal probes | Same preservation, ending CANCELLED/LIMITED; memberships unchanged. |
| Subscription change versus stale Company lifecycle version | Pending suspension rejects `40001`; Company remains ACTIVE. |
| Company suspension before subscription assignment | Independent subscription metadata can be recorded, but Company remains INACTIVE and member status read rejects `42501`. |
| Expiry before queued new-master creation | Waiting creation rejects `42501`; no partial category row. |
| New-master creation before expiry | Expiry waits for the earlier authorized master insertion, then commits; no unordered late creation. |

Each schedule observes real overlapping lock contention; final structured results record actual server version, numeric backend PIDs and lock wait events. Audit counts, confirmed receipt counts and subscription version agree for each checked subscription; synchronized entity-plan metadata also agrees. There is no separate subscription-payment ledger to duplicate: manual payment status/reference are fields of the one current subscription, with immutable administrative history. Financial payment tables must remain empty.

## No financial transactions

No books were provisioned and no expense, payment, funding, payroll or journal was posted. Settlement probes deliberately reference nonexistent synthetic sources and stop at existing source validation (`23503`). Reversal probes may reserve transient command metadata, then missing-source failure rolls back the entire attempted command. They do not create financial documents. The authoritative final native database had zero rows in the checked journal, expense, settlement, payment, advance, certificate and payroll tables, plus zero financial command requests/reference counters.

These are native **concurrent nonposting authorization/source-validation probes**, not successful financial posting tests. Earlier accepted disposable-engine tests separately demonstrated successful settlement and reversal after expiry. Native successful financial settlement/reversal under contention was not executed, respecting this batch's no-financial-transactions constraint. Existing-master reads are exercised through the actual member role and RLS; no synthetic historical financial ledgers or hosted records were created.

## Execution, fixes and cleanup

Actual pass count, execution timestamps, SHA-256 values, backend IDs, zero-row results and cleanup evidence are in [the execution record](release/local-manual-subscriptions-races-result.json).

The initial harness completed all 13 schedules, then failed its final zero-row inventory because it referred to `retention_releases`/`retention_payments` instead of the canonical `subcontractor_retention_releases`/`subcontractor_retention_payments`. Only the new harness was corrected, including explicit nonzero failure exit handling. A fresh disposable-server rerun is the authoritative result. This was a test inventory error, not a confirmed subscription defect. The migration and reviewed frontend sources remain unchanged.

Cleanup completed: clients closed, owned server stopped and its own data/socket directory removed. Independent checks found zero matching data directories and zero matching PostgreSQL server processes. The pinned temporary runner was then removed after verifying its exact path/version. No existing database/service is connected, stopped or deleted. No hosted connection, migration, deployment, existing Company assignment, financial transaction, configuration change or Git history mutation occurs.

## Readiness and remaining approvals

After the recorded pass and cleanup, the independent local concurrency gate is complete. The unchanged migration is ready for **separately authorized Development activation preparation**, followed by the fresh guards and exact single-file linked dry-run/application described in [the main implementation report](MANUAL_COMPANY_SUBSCRIPTIONS.md). No approval is inferred from a local pass.

Remaining scopes: (1) review/pin the new source-package manifest and migration hash, approve Development-only migration/dry-run/read-only postflight on `eqnzueginpkskbnqvgoc`; (2) approve one existing-maker-project protected Preview deployment with Development environment values and no Production alias/config changes; (3) approve the exact isolated Company/subscription version/plan/state/dates/manual payment fields/reason and hosted acceptance actions. No historical Company enrollment, Stage D mutation, financial posting, Auth change or Production action is included by default. A frontend revert cannot remove database guards; applied migration defects require a forward correction.

Lifecycle: business/access semantics **VERIFIED locally** within these controlled schedules; authorization/version/tenant-preserving contracts **VERIFIED for this gate** with prior role/MFA/browser evidence retained; database/migration/concurrency **VERIFIED locally**; deployment/hosted acceptance **DEFERRED pending approval**; documentation **VERIFIED through evidence/main report/handoff/roadmap**. Broad stress testing, actual midnight rollover, native successful financial posting and commercial/Production readiness are not claimed. Do not repeat the completed gate without relevant source changes or a new failure.
