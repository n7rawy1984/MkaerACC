# Accounting provisioning — independent local PostgreSQL race gate

2026-11-01. **PASS — 6/6 controlled independent-connection scenarios.** [Execution evidence](release/local-company-accounting-provisioning-races-result.json). The unchanged provisioning migration has passed its outstanding local race gate; hosted activation still requires separate approval and fresh preflight/dry-run.

## Execution method

Inspected installed tools first: PostgreSQL clients (`psql`, `pg_config`) exist, but server tools (`postgres`, `initdb`, `pg_ctl`) and Docker/Podman were unavailable on PATH. Installed only the previously documented pinned `embedded-postgres@18.4.0-beta.17` under `/tmp/narvo-postgres-runner`. Its native server reports **PostgreSQL18.4**. No repository dependency or system database installation changed.

Executed the exact prepared harness `scripts/verify-company-accounting-provisioning-races.mjs`, SHA256 `025014549c906207bcf8f3cb20dbaea54df66d121d0f34d18cdce2c7e5ecdaff`, with the local runner path. Hosted database/session environment variables were unset for execution. The harness accepts no hosted DATABASE_URL and explicitly starts/connects to its own loopback server on a dynamically selected port, with a unique `/tmp/narvo-accounting-races-*` data/socket directory.

All63 canonical migrations were replayed only into this disposable server using synthetic Auth scaffolding. Two native PostgreSQL connections had distinct `pg_backend_pid()` values, asserted by the unchanged harness. An independent observer confirmed `pg_stat_activity.wait_event_type='Lock'` for the waiting backend in **each** scenario. Numeric backend IDs were not emitted by the prepared harness; no fabricated PID telemetry is included. This was genuine backend contention, not PGlite or sequential Promise simulation.

## Results

| Scenario | Actual result |
| --- | --- |
| Same request UUID | PASS: competing backend waited, then recovered the identical receipt; one foundation. |
| Different request UUIDs, equivalent intent | PASS: waiter resumed after commit; no duplicate accounts, Treasury, provision record or audit. |
| Concurrent changed intent | PASS: first committed; waiter rejected22023 and rolled back; original foundation preserved. |
| First transaction rolls back | PASS: waiter was blocked until rollback, then committed a single complete foundation. |
| Suspension commits first | PASS: waiting provisioning rejected42501; no foundation rows created. |
| Provisioning commits first | PASS: waiting lifecycle command's stale version rejected40001; one complete foundation remained. |

Each successful foundation was checked for exactly11 GL accounts,1 Treasury,1 private provisioning record and1 provisioning audit event. The suspension winner had all four counts0. The entire local database finished with **zero journal entries and zero reference counters**. Exit code0. No implementation or harness fix was required; accepted14 implementation/package/test hashes, migration hash and original race-harness hash remain unchanged.

This run validates concurrent idempotency, duplicate prevention, transaction rollback and lifecycle/optimistic-version authorization fencing. The previously accepted55 focused role/MFA/session/tenant/preservation checks and10 browser checks were not rerun or counted as fresh race assertions.

## Cleanup and boundaries

Harness cleanup closed its clients, stopped its own PostgreSQL process and removed the unique disposable data/socket directory. Independent post-run checks found0 matching data directories and0 matching PostgreSQL server processes. The temporary runner installation was then removed after validating its exact path and installed package version. Existing local databases/services were never connected, stopped, deleted or altered. Project dependency files remained unchanged.

No Supabase Development/Production connection, hosted migration/provisioning, historical financial access/change, frontend deployment, Vercel/Auth/configuration change, email or Git commit/push/merge was performed. Disposable synthetic Companies and accounting masters existed only in the removed local server. No financial transaction was posted by these race tests.

## Readiness and limits

**The unchanged migration is ready for separately authorized Development activation**, subject to the fresh hash/environment/preservation guards, exact single-file linked dry-run and explicit approvals in [the activation plan](COMPANY_ACCOUNTING_PROVISIONING_ACTIVATION.md). The local race blocker is resolved; do not repeat this gate without a source change or new failure.

Still excluded: actual hosted Company/Treasury provisioning, including Stage D, unless separately named/approved; OWNER_CURRENT/owner-funded operations; funding/opening entries; historical Company changes; Production. Hosted migration/runtime/new Preview verification remain unexecuted. This uses native PostgreSQL with synthetic Auth, not hosted Supabase/PostgREST authentication; six controlled schedules do not constitute an unbounded stress test or commercial-readiness claim.

Lifecycle: supported business setup/concurrency **VERIFIED locally**; security/authorization **VERIFIED** for these lifecycle/version orderings with prior focused checks retained; database **VERIFIED locally** including forward migration replay and cleanup; deployment **DEFERRED pending separate approval**; testing **VERIFIED6/6** within stated limits; documentation **VERIFIED** through this report/evidence/manifest/handoff/roadmap. No applied migration was edited.
