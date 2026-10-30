**Actual hosted Development checkpoint:** all four approved migrations are APPLIED; history60 and immediate financial/security postflight PASS. Approved owner only, zero Company financial membership. Independent recovery remains incomplete under the explicit Development-only owner risk exception. Real owner MFA and hosted email/function/browser acceptance remain pending; private real-Development app ready at `http://127.0.0.1:5173/platform`. No Production deployment or extra hosted configuration. See [actual execution record](PLATFORM_ACTIVATION_EXECUTION.md). Older unapplied/remote-unknown labels below are historical.

**Existing-application continuation:** origin selected as `https://maker-eosin.vercel.app`; local delivery checks now cover it. MFA/sign-out UI fixes preserve all four unchanged migration/security boundaries. No hosted changes or backup/recovery operations. See [current checklist](PLATFORM_ACTIVATION_EXECUTION.md).

**Latest execution:** [P0 activation checklist](PLATFORM_ACTIVATION_EXECUTION.md). All four SQL files remain unchanged/unapplied remotely; local callback hardening adds no administrative authority and does not replace invitation epoch/fence checks.

# P0 invitation revocation correction — local evidence, 2026-10-28

**P0-H8 update (2026-10-29):** current hosted compatibility/alignment/grants/financial and HDD-copy checks are verified within the [readiness record](PLATFORM_PRE_ACTIVATION_READINESS.md). Four migrations remain unapplied; actual-owner/provider/hosted acceptance and independent custody are not complete. The [activation procedure](PLATFORM_DEVELOPMENT_ACTIVATION_PLAN.md) is prepared only, not executed or authorized. Earlier dated test/status sections below remain historical evidence.

**LOCAL SECURITY FIX COMPLETE · HOSTED SECURITY UNVERIFIED · REMOTE ACTIVATION NOT AUTHORIZED.**

This is the bounded local security correction requested after P0-H1. Lifecycle stage: requirements, analysis/design, implementation, focused security/database review and local verification completed; hosted compatibility, release, owner acceptance and operational validation deferred. Platform Owner P0 remains the sole immediate track under the unchanged V1.6 master plan. No hosted mutation, migration application, live role grant, Company/user/invitation creation, email, configuration change, financial mutation, commit, push or deployment occurred.

## Confirmed defect and correction

The original `platform_member` revocation only inactivated membership. An earlier PENDING invitation survived; `accept_platform_invitation` saw no active membership and granted the old role. The preceding 59 migrations reproduce restoration of `is_company_member`, `accounting.view` and `accounting.post`. The permanent upgrade test reproduces this failure before applying the correction.

**Invariant:** once an authorized Company membership decision commits, an invitation issued under an earlier authorization generation cannot create membership or change the current decision. Revocation, any explicit membership assignment/role change, user deactivation, and Company suspension/archive invalidate the affected older invitation paths. Only a genuinely new authorized grant/invitation can restore access. Matching old command receipts are historical results and never repeat their effects.

Forward migration `20261028123000_platform_invitation_revocation.sql` implements:

- Private forced-RLS `platform_access_fences`, keyed by Company and a namespaced recipient subject (normalized Auth email or stable user UUID), with monotonically incremented BIGINT generations. Both keys are fenced for an existing user; invitation identity binding and independent user-generation checks prevent email-change/change-back resurrection. Invitations issued before signup retain email-based onboarding. Pending invitations become REVOKED, with durable reason, version increment and cancelled outbox/cleared delivery lease, in the same transaction as membership administration. Existing invitation, membership and event history remains.
- Each invitation snapshots email/user generations, the existing recipient UUID when known, and recipient profile, issuer registry and issuer profile epochs. Database triggers advance identity epochs on status changes in either direction. Reactivation does not restore an earlier authorization epoch. Acceptance checks these independently, before an accepted-invitation replay can return, and still enforces verified live recipient, current issuer authority, tenant/role restrictions and last-admin safety.
- Global user deactivation invalidates all affected recipient invitations, including Companies with invitations but no membership, and removes sessions. Reenabling a user retains the existing policy for their otherwise active memberships; it does not revive invalidated invitations. A new valid invitation can be issued after reenable.
- Suspension/archive invalidates Company invitations. Reactivation permits existing authorized memberships to resume; it requires new invitations for formerly pending paths. DRAFT invitation onboarding remains allowed. Expiration can still be renewed by currently authorized resend, provided no denial/identity fence superseded the invitation. Revoked/superseded invitations cannot be renewed.
- Issuer registry/profile deactivate/reactivate cycles fail the independent epoch check, including delivery and resend. These trusted issuer changes do not rewrite pending invitation history; acceptance stays denied and the owner can revoke/reissue. There is no new UI for owner-privilege management.
- Acceptance advances the entity version for every granted role, so stale administrative forms conflict consistently. No financial authorization helper, permission map or posting command is changed.
- The authorized invitation directory and EN/AR console display `invalidation_reason`.

No browser/service-role direct access is granted to the new private table/helpers. Definer helpers use fixed empty `search_path`; existing RPC signatures and their EXECUTE allowlists remain. Identity epoch triggers are invoker functions without privileged access. Browser profile/epoch writes are denied. Platform authority still grants zero Company financial membership.

## Ordering and concurrency contract

Every platform administrative mutation, invitation create/revoke/resend/accept, delivery lease claim and service acknowledgement first acquires the same **transaction-scoped advisory gate**, before actor validation/row locks. This intentionally serializes low-volume control-plane operations. It avoids adding a complex distributed lock hierarchy; financial RPCs never acquire this gate.

Within the gate, existing per-user advisory locks, ordered Company locks, identity/session locks and invitation/job locks remain. All replacement mutation entry points acquire the gate before their row-locking authorization checks; idempotent receipt paths also pass current authorization. No function-scoped/session-scoped locks are retained after transaction end. No timestamp comparison establishes invitation ordering.

If acceptance wins first, a later successful revocation inactivates that membership and advances its fence; accepted-invitation replay then fails. If revocation wins first, waiting acceptance sees the new state/generation and fails. A newly authorized invitation ordered after revocation may grant membership. A stale version may produce `40001`; it is not a successful revocation, and the administrator must refresh/review/retry. The test of acceptance-first supplies the resulting current entity version so revocation actually commits.

Permanent tests use two distinct `pg_backend_pid()` connections and observe real `pg_stat_activity` lock waits before releasing the first transaction. Eight genuine overlapping orderings passed: revoke→accept, accept→revoke, create→revoke, revoke→new-create, deactivate→accept, suspend→accept, downgrade→accept, and revoke→service-acknowledge. No deadlock or stale restoration occurred in those controlled scenarios. This is local PostgreSQL 18.4 evidence, not hosted Supabase/GoTrue concurrency acceptance. PGlite single-connection results are never described as that evidence.

The administrative gate trades throughput for simple correctness; acceptable for this bounded control plane. Independent trusted SQL/operator activity and future entry points must respect the documented command/fence contract. This does not audit every service-role/operator financial operation or change existing financial transaction semantics.

## Migration strategy and upgrade behavior

Hosted history could not be verified in P0-H1: no management/direct database credential was available. The preceding three platform migrations have not intentionally been activated, but filenames and intent do not prove their absence everywhere. Therefore all preceding **59 files remain byte-for-byte unchanged**, including the original 56 checked against HEAD, and a fourth platform migration is appended. No hosted dry-run/apply was attempted in this correction.

Existing PENDING invitations at upgrade are conservatively revoked with `SECURITY_CORRECTION_REISSUE_REQUIRED`, their jobs cancelled and migration-cause audit events retained. Their earlier authorization order cannot be reconstructed safely. The audit identifies the historical creator and invitation correlation, explicitly marked `CANONICAL_MIGRATION`; it does not invent a logged-in migration actor. New invitations work after current authorization. Already accepted memberships are not silently removed: if any environment previously ran the vulnerable path, authorized review of invitation/membership audit history and current access is required before activation. The migration cannot infer which historical grants were intentional.

The permanent upgrade test runs the original exploit on migration 59, then applies only the new forward correction, checks legacy pending cancellation/history/audit and successful new invitation acceptance. It complements clean replay of all 60 migrations.

## Permanent regression coverage and executed results

| Requirement | Actual local evidence |
|---|---|
| T01 original exploit | Old pending invitation denied after revoke; pre-fix exploit reproduced in upgrade test |
| T02 delivered link | Real DB delivery lease/ack completed before revocation; acceptance denied |
| T03 replay | Repeated old acceptance denied; no restored privileges |
| T04 new authorized invitation | New post-revocation invitation accepted; current identity/issuer/tenant checks retained |
| T05 direct RPC | Direct authenticated SQL RPC denied; real browser direct-RPC denial also verified |
| T06 stronger old role | ACCOUNTING_ADMIN invitation cannot override downgrade or later revocation |
| T07 Company isolation | Company B membership and unrelated pending invitation retain their legitimate access |
| T08 concurrency | Eight controlled real multi-session orderings above, including both accept/revoke orders |
| T09 delivery race | Retry/claim and acknowledgement denied after invalidation; genuine service-ack race tested |
| T10 deactivation | Old invitation denied while inactive and after reenable/fresh session; new invite works |
| T11 audit | Authenticated actor, invitation target, Company, reason and revocation request correlation checked |
| T12 financial privilege | Member=false, accounting.view=false, accounting.post=false after stale replay |
| T13 last admin | Last active Accounting Admin removal denied by existing policy |
| T14 idempotency | Old invite/grant/revoke receipts cannot undo a newer decision; accepted replay cannot restore revoked access |
| T15 rollback | Trigger-injected failure rolls back membership, version, fence, invitation, outbox, receipt reservation and audit |

`verify-platform-revocation.mjs`: **44 assertions PASS** on PGlite and again on independent local PostgreSQL, plus the separate baseline/upgrade scenario PASS. Additional checks force a stale invitation state back to PENDING through a trusted local test connection and still get epoch denial; issuer registry/profile reactivation, recipient email-change/revoke/change-back, expiration/resend, private fence/epoch-write denial and authorized reason projection pass.

`verify-platform-concurrency.mjs`: **8 real multi-session scenarios PASS** on temporary PostgreSQL 18.4; 60 migrations replayed with synthetic Auth scaffolding. Tool `embedded-postgres@18.4.0-beta.17` was installed only under `/tmp/narvo-postgres-runner`, not as an application or repository dependency. The permanent runner fails if its optional tool is absent; it never falls back to sequential coverage or a hosted URL. It binds only 127.0.0.1, creates a random temporary local credential without printing it, cleans up its cluster, and does not create an OS user.

```sh
npm run verify:platform:revocation
npm install --prefix /tmp/narvo-postgres-runner --no-audit --no-fund embedded-postgres@18.4.0-beta.17
PLATFORM_POSTGRES_RUNNER=/tmp/narvo-postgres-runner/node_modules/embedded-postgres/dist/index.js npm run verify:platform:concurrency
```

Other executed correction-batch results:

| Check | Result |
|---|---|
| Platform security/database | PASS: 84 assertions; 60 canonical migrations; populated financial fingerprints unchanged |
| Trusted delivery handler | PASS: 18 assertions, mocked ports; no email/network |
| Platform Chromium | PASS: 27 assertions, including grant→invite→revoke through actual UI, visible reason, no resend action, direct stale acceptance denied |
| P6A boundary | PASS: 178 production Auth modules |
| P6E config/import/storage and Auth/tenant browser | PASS |
| TypeScript/Vite build | PASS, explicit synthetic browser-safe per-process configuration; existing chunk-size advisory |
| Lint | PASS: zero errors, ten warnings already present at the start of this correction (eight baseline, two prior console effect warnings) |
| Migration preservation | PASS: original 56 equal HEAD; all preceding 59 match pre-correction SHA256 snapshot |
| Financial/accounting/historical/Payroll/Attendance source preservation | PASS: no source edits relative to HEAD |
| Focused secret-pattern scan | PASS: 22 platform application/server/migration/test files; no actual credential values printed |
| Git diff check | PASS |
| P6C boundary | FAIL retained: unchanged blanket `.rpc(` assertion in personMasterRepository |
| Executive Dashboard browser verifier | FAIL retained: line 35 expects zero Payroll links for MANAGEMENT_VIEWER; unchanged implementation has one |
| Hosted alignment, linked dry-run, actual MFA/email/owner and hosted races | DEFERRED, not executed |

The Executive verifier initially could not bind loopback under the sandbox; rerunning with local networking allowed reached the known line-35 mismatch. Neither unrelated verifier nor accounting/Payroll implementation was changed or weakened. Browser evidence is under `/tmp/narvo-platform-evidence`; it uses real application components/SQL with synthetic Auth and blocked external networking. Build output uses example.invalid fixture configuration and is not a deployable release.

## Files changed in this correction

Added: this record, `supabase/migrations/20261028123000_platform_invitation_revocation.sql`, `scripts/verify-platform-revocation.mjs`, `scripts/verify-platform-concurrency.mjs`.

Updated: `scripts/verify-platform-database.mjs` (external local adapter and migration-prefix upgrade fixture), `scripts/verify-platform-security.mjs` (60-migration expectation only), `scripts/verify-platform-browser.mjs` (six additional relevant UI assertions), `package.json` (two verification commands), `src/platform/PlatformApplication.tsx` and `platformText.ts` (reason column/EN-AR labels), `docs/PLATFORM_OWNER_CONSOLE.md`, `PROJECT_HANDOFF.md`, `PROJECT_ROADMAP.md`.

All prior dirty implementation and supplied instruction documents preserved. No package dependency/lockfile changes in this correction. Branch main, HEAD `9da8612ac0f9e9e92efa0b9eb417af0311cfc2e3`; seven tracked files modified and 26 files untracked across the accumulated local console work. No commit or push.

## Remaining risks, prerequisites and readiness

The original vulnerability is a **confirmed defect, corrected locally**. At-least-once email delivery and inability to recall an already sent message are **expected/intentional behavior**; database acceptance remains authoritative. Admin-gate throughput is an understood tradeoff. Hosted Auth compatibility, current remote migration/registry inventory and actual-owner/MFA/provider/browser acceptance are **deferred verification gates**, not claimed passes. Full Production Security & Accounting Integrity Audit, observability/recovery/backup rehearsal and broader operational abuse controls remain separate future gates.

Before any separately authorized Development activation:

1. Read-only verify approved project `eqnzueginpkskbnqvgoc`, actual canonical history and owner registry identity. Resolve missing/divergent migrations without rewriting history; inventory any prior platform invitations, their audit events and restored memberships.
2. Verify hosted `auth.users`, `auth.sessions` AAL/factor/session-expiry columns, `auth.mfa_factors`, signed TOTP AMR, safe profile/registry epoch-column compatibility and session revocation. Local synthetic scaffolding is not provider acceptance.
3. Review the four platform migrations, the conservative legacy-pending cancellation policy, grants/RLS and backup/recovery expectations. Use the linked canonical dry-run only in its separately authorized batch. Installed CLI documents Vault updates before migration push unless `--skip-vault`; use that flag for an authorized dry-run/apply, with no seed/roles branch.
4. Only explicit authorization can permit canonical Development application, real access changes, hosted MFA/provider/template configuration, function deployment or frontend deployment. Staging/Production remain out of scope. Rehearse hosted versions of T01–T15, genuine races, delivery/callback/recovery, before/after financial fingerprints and actual-owner EN/AR acceptance with approved synthetic fixtures.

| Completion category | Classification |
|---|---|
| Business/accounting | VERIFIED locally: administrative semantics and unchanged synthetic posted truth; real ledger setup NOT APPLICABLE |
| Security/authorization | VERIFIED for the local correction and tested boundaries; actual provider/hosted acceptance DEFERRED |
| Database | VERIFIED: forward clean/upgrade replay, ordering, RLS/grants, rollback, preservation; remote alignment/dry-run DEFERRED |
| Deployment/environment | VERIFIED: local-only boundary and synthetic configuration; remote release/configuration/rollback rehearsal DEFERRED |
| Testing | VERIFIED: executed local results above; hosted/actual-owner acceptance DEFERRED |
| Documentation | VERIFIED: console, handoff, roadmap and this record reconciled; V1.6 priorities preserved |

**GO:** return to a read-only Development activation preflight when the missing user-controlled access is available. **NO-GO:** hosted activation/apply/deployment until compatibility, explicit authorization and hosted acceptance gates are satisfied. Local correction is not hosted acceptance or production readiness.
