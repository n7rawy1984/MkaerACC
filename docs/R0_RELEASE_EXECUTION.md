# R0 Release Execution — Commercial Onboarding + Emerald Enterprise

2026-11-02, Asia/Dubai. **Candidate R0-5e27b3c79600: READY locally. Hosted activation/Production release: BLOCKED by unverified restoration.** Cleanup remains deferred. No hosted migration, business mutation, subscription/membership change, Auth deletion, Maker modification, deployment, commit, push or merge occurred.

## Operational status

| Gate | Actual result |
|---|---|
| Release candidate | READY: clean276-file source package,20 changed/4 new versus the accepted live package; every changed/new application hash matches the approved onboarding/visual/Emerald evidence. |
| Build/tests | PASS: clean offline npm ci, Production tsc/Vite build, focused source lint;49 local SQL checks,20 local workflow-browser checks,18 workspace checks and11 new preactivation/legacy checks. Two static-Preview layouts and its outbound-connection barrier pass. Existing chunk-size advisory remains. |
| Recovery | Encrypted database and role backups captured, complete decryption integrity verified, archive TOC readable. **Isolated restoration NOT performed: compatible local server/container runtime missing. Recovery gate NOT passed.** |
| Safe Preview | Separate inert visual Preview prepared and verified. Functional application Preview against the shared database is unsafe under this task's no-mutation requirement. Neither was deployed. |
| Migration65 | Exact hash and isolated canonical package prepared; current hosted history64 and missing65/helper verified. No linked dry-run/application executed. Explicit approval still required after demonstrated recovery. |
| Vercel Production | Existing project/environment verified; candidate build/configuration ready. Promotion blocked by recovery, migration activation and subsequent exact-candidate acceptance/authorization. |
| Single next owner action | **Install/start a local Docker Engine accessible to this user**, enabling an isolated Supabase-compatible restoration of the encrypted backup. No hosted setting or password reset is needed. |

This repository is React/Vite, not Next.js. Its existing Vercel workflow is retained. No framework conversion or feature redesign was introduced.

## Frozen application candidate and reproducibility

- Candidate: **R0-5e27b3c79600**; [source manifest](release/r0-release-execution/candidate-manifest.json), [artifact identity](release/r0-release-execution/candidate-artifact.json), [build result](release/r0-release-execution/build-result.json).
- Source directory: `/tmp/narvo-r0-release-20261102/source`.
- Deterministic source archive: `/tmp/narvo-r0-release-20261102/r0-source.tar.gz`; SHA256 `33d1ccc535aabcaa6715ed998cf2b2ade6498a8c463ad1c65c36c1f5b0acd27f`. Normalized timestamps/modes and sorted exact manifest paths; no Git operations required.
- Frozen package contains CommercialOnboarding, platform navigation/portfolio/progress and the approved Emerald tokens, global/console/workspace styling and bounded presentation refinements. The existing financial/Auth/tenant boundaries remain intact.
- No environment files, credentials, database/Edge payloads, browser fixtures, screenshots, private backup/evidence, node_modules or build output are in the276-file source manifest. Existing demo source is retained only as in the accepted package; the production import/configuration boundary excludes demo accounting and rejects Production demo mode.
- Production build directory: `/tmp/narvo-r0-release-20261102/production-build/dist`. Asset hashes, Node/npm versions and public-environment fingerprint are recorded. Install/build ran in a separate clean directory, preserving the frozen source and the original dirty tree.
- Verification ran in a separate sandbox; new test outputs are under `docs/release/r0-release-execution`, leaving earlier milestone artifacts intact. Prior native concurrency evidence is reused because all65 SQL hashes remain unchanged; it was not relabelled as newly executed.

The initial unscoped lint invocation scanned third-party node_modules because the clean source package has no repository Git ignore context. The release harness now lints explicit application/configuration paths, passes, and records the corrected scope. No product code was changed to satisfy lint. Old unscoped diagnostics remain private in the release work directory.

## Accessibility and before-migration behavior

The previously reviewed nine incomplete accessibility groups remain documented in the [R0 assessment](R0_PRODUCTION_IMPACT_AND_RECOVERY_ASSESSMENT.md): clipped table contrast, empty-table header association and overlay/paragraph heuristics. Relevant approved source hashes match; no new source change justifies repeating that audit. Whole-page incompletes remain limitations, not converted passes or certification. Broader screen-reader/browser/zoom acceptance remains deferred.

New isolated browser checks deliberately return PGRST202 for the missing onboarding RPC. EN desktop and AR narrow mobile show a visible progress error; refresh remains explicit, no Company cards falsely claim readiness, and no mutation occurs on load/refresh. Screenshots and [11-check result](release/r0-release-execution/preactivation-browser-result.json) are retained. Existing Customer creation controls remain enabled because those earlier RPCs exist: **missing migration65 does not make the application read-only**.

The pre65 UNMANAGED/FULL Company subscription response, without additive readiness metadata, still renders the internal-company/no-commercial-subscription explanation and Company workspace. Fresh49-check disposable database testing confirms the exact Maker legacy seed, FULL unenrolled access and protected historical/Company/membership preservation. The small fresh hosted checkpoint confirms Maker remains ACTIVE, unenrolled and the unique qualifying legacy seed; it does not execute a Maker transaction. All protected identity/membership requirements and the sealed cleanup denylist remain unchanged. No cleanup is part of release.

## Recovery performed and precise blocker

The first connection probe could not use the pooler with the default system CA. Existing project-specific credentials were then resolved from the protected pgpass entry, and the existing `/home/nagham/Downloads/prod-ca-2021.crt` supplied the trusted Supabase CA. Direct IPv6 access has no route on this machine; the session pooler works with **verify-full TLS**. No SSL enforcement, network setting, password or hosted configuration changed. Supabase recommends the downloaded CA for verified connections. [Official SSL guidance](https://supabase.com/docs/guides/platform/ssl-enforcement).

Successful authorized exports:

- Complete custom-format database archive, encrypted while streaming; no plaintext dump file. Includes public/private application data, Auth, Storage metadata, canonical migration history and extension definitions.
- Global role definitions/memberships, encrypted separately, deliberately excluding database-role passwords. The existing credential remains in its original protected store.
- Both ciphertexts were fully decrypted to a discard sink to verify encryption integrity; pg_restore successfully read the archive TOC. Early closure of a TOC-only decryption stream is not mistaken for full integrity checking or an actual restore.
- Random encryption passphrase is stored only in the current user's OS Secret Service. Its locator, ciphertext hashes, timestamps and sizes are in the recovery metadata; no passphrase/password/token is printed or written to source.
- Private durable local backup directory: `/home/nagham/Backups/NARVO/R0-2026-11-02T191058`. Directory0700, files0600, ciphertext hashes verified after copying outside Git. Temporary work remains under `/tmp`; it is not the retained recovery artifact.

[Backup metadata](release/r0-release-execution/recovery-result.json). This is a local encrypted snapshot, not an off-site recovery service or a demonstrated restoration. Keep its OS-keyring entry and encrypted files together in the recovery plan; loss of the key makes the files unusable. A fresh final snapshot and approved retention/RPO/RTO remain execution-preflight items, not grounds to invent a recovery pass now.

**Exact missing prerequisite:** a runnable isolated Supabase-compatible PostgreSQL17 environment with `supabase_vault`, `pgcrypto`, `uuid-ossp` and `pg_stat_statements`. PostgreSQL client utilities are present, but the local server/initdb binaries and Docker/Podman engine/socket are absent. A client archive listing or the synthetic PGlite tests cannot restore this real database. Installing a plain server and omitting/stubbing Vault would not prove recovery.

Once Docker is available, use a dedicated compatible database-only runtime with no published ports and outbound network disabled. Do not start hosted-connected Auth, Edge, email or scheduled workers. Stream-decrypt into that isolated target, restore the required role/schema/data/grant scope without weakening production invariants, and verify canonical64 history, protected Company/Auth/profile/membership/MFA relationships, subscription/provision/foundation, all source and immutable financial hashes, journal balance and authorization definitions. Record restore errors/omissions and elapsed time; fail the gate on incompatible/missing objects. Keep sensitive restore files private and stop the isolated runtime after verification. Never test restoration on the shared project.

## Ordered single-migration activation procedure — preparation only

Package: `/tmp/narvo-r0-release-20261102/migration-package`; [manifest](release/r0-release-execution/migration-package-manifest.json). It contains the exact65 canonical SQL files and needed local configuration/templates; no schema file was changed.

1. Demonstrate the isolated restore, approve backup/recovery scope and retention, and establish a usable final pre-change recovery point. Agree operator/window, loss-of-intervening-writes handling and measured recovery time. A local backup by itself is insufficient.
2. Obtain **separate explicit approval for the shared-database/Production-impact migration**, identifying target `eqnzueginpkskbnqvgoc` and only `20261102120000_commercial_company_onboarding.sql`.
3. Confirm pending SQL SHA256 **`76aef69124d8eccc6b7df8f6152fcddf5f37b7a17934fe3926b674f71d395f67`**; exact64 hosted prefix/statements and schema dependencies; no extra pending SQL; protected baseline and unique expected Maker seed. Refresh only these execution guards, not a wholesale cleanup inventory.
4. Supply the existing database credential privately to the supported CLI, not on its command line or in a source file. In the isolated canonical package, execute a separately authorized `/media/nagham/msn4ever/www.downloadly.ir/Maker/node_modules/.bin/supabase db push --linked --dry-run --workdir /tmp/narvo-r0-release-20261102/migration-package`. Output must list only65. Halt on any discrepancy. No --include-all, unrelated migration, SQL Editor patch, reset or synthetic history entry.
5. Following the reviewed dry-run and explicit activation approval, use the same supported linked migration workflow to apply only65. Review transactional/history behavior and bounded lock timeout before invocation. Do not run the command from the dirty repository or automatically retry a failed/uncertain application.
6. Immediate read-only postflight: history65/first64 unchanged; expected new tables/helper/RPC/replaced functions; FORCE RLS and exact grants; all20 guard attachments enabled; eligibility exactly the Maker UUID; empty initialization scope; unchanged protected Company/account/membership/subscription/financial rows and specialized financial functions. Keep normal concurrent Auth refresh/new security-session activity distinct from identity, role, membership or MFA-factor changes.
7. Confirm Maker ready/FULL while unenrolled, ordinary authorization retained and no provisioning/subscription required. Recompute the reviewed17 other LIMITED results under unchanged inputs, distinguishing16 active/one inactive. Protected test/demo memberships remain intact; no Company cleanup, backfill, subscription assignment or Customer linkage is implied.
8. Validate public read contracts with genuine existing owner/member sessions; do not spoof hosted identities or issue diagnostic financial writes. No new Customer, Company, invitation, email, Treasury or subscription test record. The separately scoped real commercial write journey remains deferred until explicitly authorized.
9. Deploy/accept the matching application stages below. SQL activation changes current Production enforcement immediately, before a new UI is promoted; coordinate the interval and user messaging. New application before65 displays onboarding errors and is not a complete release.

The precise prior impact inventory, limitations and postflight matrix remain authoritative at [R0 impact/recovery assessment](R0_PRODUCTION_IMPACT_AND_RECOVERY_ASSESSMENT.md). No migration dry-run/application was performed this session. Current small checkpoint: [history/Maker guard](release/r0-release-execution/hosted-checkpoint.json).

## Preview, Production promotion and rollback

Existing Vercel project: `maker`, ID `prj_n03DWya5Gr1uB82qtY084FvsC7q4`, team `team_HozmwrkzbERtyer2nIT25MWv`. Fresh read-only metadata confirms `maker-eosin.vercel.app` and Production target still point to **`dpl_8Jvbmi1GFoVPNhG36CAf1ZGkCfHP`**. [Configuration readiness](release/r0-release-execution/vercel-readiness.json). No project setting, branch, alias, environment or protection was changed.

Required browser-safe values: VITE_APP_DATA_MODE=supabase-auth, VITE_SUPABASE_URL for the exact shared project, and its validated publishable key. Production values/scopes were read privately and used for the clean build; their fingerprint is recorded without the key value. Never embed a service-role/private credential. Missing/privileged configuration and Production demo mode fail closed. Match these values/fingerprint again at the actual Production build; an environment change invalidates prior artifact equivalence.

**Functional Preview:** the276-file candidate retains legitimate administrative/financial commands, including pre65 Customer creation. A Preview connected to this shared project can mutate Production resources when used by an authorized account. Read-only browsing discipline, hiding buttons, separate sessions or a missing RPC do not provide isolation. Do not deploy this live-connected candidate under the current Preview restriction. A truly isolated backend or separately reviewed server-enforced mutation boundary would be needed for functional Preview; neither is introduced here.

**Safe visual Preview:** `/tmp/narvo-r0-release-20261102/safe-visual-preview`, [manifest](release/r0-release-execution/safe-preview-manifest.json), [verification](release/r0-release-execution/safe-preview-result.json). Separate seven-file inert artifact of approved synthetic screenshots, no JavaScript/forms/SDK/environment values; CSP blocks connect/script/form actions. Desktop/mobile, local-GET-only requests and blocked outbound fetch were verified. It can be deployed as a separately identified static Preview without shared-database access, but was not deployed: human visual approval is already complete, and this adds no functional acceptance. It must never be promoted as the application release.

**Production workflow after recovery/migration:** use the existing Vite build/output/SPA security-header configuration with the276-file frozen source manifest. Verify upload paths/hashes, dependencies and public configuration; create a separately authorized production-configured candidate and inspect every assigned alias. The earlier generated-alias exception means --skip-domain cannot be assumed to prevent all aliases. Halt on unexpected routing. Retain protection and invitation/Auth settings; do not silently modify callback origins.

Smoke the exact READY candidate with existing protected sessions: Platform Owner navigation/onboarding/Customer portfolio/subscription reads, Maker full internal access and ordinary Company roles, Company switch, six dashboard sections, Expenses/Projects/Contracts/Treasury/Attendance/Payroll/Reports, error/empty states and Emerald EN/AR desktop/tablet/mobile/keyboard behavior. No form submission or new test business records. Capture candidate ID, bundle/configuration hashes and actual evidence. Existing local acceptance is not hosted runtime acceptance.

Obtain explicit Production promotion authorization for that identified candidate/alias set after acceptance. Promote the exact accepted artifact; do not rebuild into another ID during promotion. Verify named Production target/aliases, served assets, project reference, key fingerprints, owner/member/Maker reads, onboarding readiness, RTL/responsiveness, protected records and read/error visibility. Observe failed RPCs/Auth errors and record operator/timestamps/rollback decision owner.

**Rollback:** retain the current READY application `dpl_8Jvbmi1GFoVPNhG36CAf1ZGkCfHP` as the immediate UI rollback reference, rechecking readiness before release. The older `dpl_DC2wK34FdbWNsVtnqMCzb54uRwDh` is historical, not an automatic choice. UI rollback reassigns an existing deployment and **does not undo migration65**. Before SQL commit, use verified transactional failure handling; after commit, use a separately reviewed forward corrective migration or explicitly authorized, demonstrated full recovery. Never rewrite65, erase migration history, delete accounting data or assume frontend rollback restores server readiness rules.

## Verification and remaining gate

No repeated Company-cleanup assessment or full security audit was run. Reused evidence is hash-verified; fresh work is the clean candidate/build/tests, exact preactivation behavior, targeted checkpoint, verified encrypted backup and inert Preview. Restoration, real hosted onboarding writes, migration dry-run/application, live candidate acceptance and Production promotion remain explicitly unperformed.

VERIFIED: candidate/business-boundary preservation, focused tests and configuration, backup capture/integrity, documentation. BLOCKED: recovery demonstration. DEFERRED: stage-specific migration/deployment approvals and execution/runtime acceptance. No new accounting/subscription logic or migration was introduced.

**Next owner action: make a local Docker Engine available to this user so the authorized isolated Supabase-compatible restore can be completed.** No password sharing, hosted setting change or cleanup is required to take that step.
