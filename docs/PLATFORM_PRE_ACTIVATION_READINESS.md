# P0-H8 — Platform Owner pre-activation readiness

**2026-10-29, MakerACC-Development `eqnzueginpkskbnqvgoc`: NO-GO for activation now.** This read-only audit and local release preparation performed no hosted migration, role/grant/data/Auth configuration change, deployment, user creation/deletion, credential reset, backup deletion, commit or push. The [ordered activation plan](PLATFORM_DEVELOPMENT_ACTIVATION_PLAN.md) is a future procedure, not authorization to execute it.

**1. Readiness summary**

Application/database migration implementation is locally verified, including a PostgreSQL 17 rehearsal on a native H6 recovery clone. Current hosted application data and authorization metadata match the documented baselines. Internal HDD copies are independently verified. Off-device backup/key custody, second-machine recovery, actual-owner MFA and hosted/provider acceptance remain incomplete. No residual-risk waiver is inferred from the owner's HDD-copy confirmation.

**2. Repository and migration state**

- Branch `main`, HEAD `9da8612ac0f9e9e92efa0b9eb417af0311cfc2e3`. At audit entry, the same seven tracked modifications and nineteen untracked Git status entries remained; all 692 H5-baselined files were unchanged. Untracked directories contain multiple files. No merge-conflict entries or unexpected implementation changes were found.
- All original 56 migration files match HEAD byte-for-byte. Actual hosted history exactly equals those 56 versions, through `20261008160000`. All four platform files remain unapplied remotely.
- Exact order and SHA256:

| Version / filename | SHA256 |
| --- | --- |
| `20261028120000_platform_control_plane.sql` | `d28121ca9a804e35721de8656b1ffa5545c7edc2f35d49df0a6b9fed8a27ebbb` |
| `20261028121000_platform_commands.sql` | `7f53d28b7347efb0249c4ad31e1d16a0c0062508aea4242714746c9a9d0e004b` |
| `20261028122000_platform_invitations.sql` | `2e5cfb32416e2009ea2ffe5f6e303cbd5310c5e6173b46925f37858d39110fe4` |
| `20261028123000_platform_invitation_revocation.sql` | `923fb86fd9ea7dfaa917749ebc48abcbcd252fa9cc735f907f91e7dce4e16c26` |

`1200` depends on the existing registry/profiles/Auth schema and introduces the control plane and live session/MFA validator. `1210` adds administrative commands. `1220` adds invitation/outbox commands. `1230` adds recipient/issuer epochs, Company/email/user fences, serialized authorization and stale-invitation invalidation. It must not be omitted or deployed separately after exposing `1220` invitation behavior.

No conflicting platform function names or epoch-trigger names exist remotely. The registry has exactly one documented ACTIVE owner, with ACTIVE profile, confirmed non-banned Auth identity, zero Company memberships, zero verified TOTP factors and zero owner application sessions. Mapping existing registry rows to PLATFORM_OWNER therefore affects only the approved owner in this snapshot. Recheck immediately before any future application; do not rerun bootstrap.

Hosted Auth users/sessions/factors columns, relevant postgres read/row-lock/session-delete privileges and session dependency metadata remain compatible with the documented design. Current 54 table ACL/RLS records, 680 columns, 68 policies, 132 function-definition hashes and 556 constraints equal H2; function owners/ACLs, role attributes and default ACLs equal H3, and all 25 membership options equal the recovery supplement. This closes the earlier *unverified current grant comparison* gap at the H8 snapshot; the native archive itself still omits ACL entries and must remain paired with its supplement. Provider service-role default grants remain unchanged, trusted-operator behavior, not browser authorization.

No linked CLI dry-run ran in H8. No native password is configured in this auditor process; using the CLI resolver without an existing password can initialize a hosted login role. Read-only SQL instead used the official Management API with explicit READ ONLY transactions and project-identity checks. The final canonical dry-run remains a later guarded gate with Vault updates disabled and no role/seed inclusion.

**3. Security and local test evidence**

| H8 execution | Result |
| --- | --- |
| Platform DB/security, all 60 migrations | PASS — 84 assertions |
| Invitation revocation and migration-59 forward upgrade | PASS — 44 assertions plus upgrade scenario |
| Independent-session PostgreSQL 17.9 races | PASS — 8 overlapping orderings; lock waits, no deadlocks/stale restoration |
| Delivery contract | PASS — 18 assertions; mocked ports, no email/network |
| Chromium platform UI / real local SQL RPCs | PASS — 27 assertions; external requests blocked; Auth/MFA mocked |
| P6A production Auth import boundary | PASS — 178 modules |
| P6E configuration/import/storage boundary | PASS |
| TypeScript/Vite build | PASS — synthetic public configuration; chunk-size advisory; output is not a deployable release |
| Lint | PASS — zero errors, ten existing warnings |
| Focused literal-secret scan | PASS — 13 production platform/server/migration files; no flagged literals |
| P6C blanket-RPC boundary verifier | FAIL — unchanged known `.rpc(` assertion in personMasterRepository; not suppressed/fixed |
| Executive Dashboard verifier | NOT RERUN — prior unrelated Payroll-link failure retained, no new pass claimed |

The native-clone rehearsal restored H6 into a private RAM-backed PostgreSQL17 cluster, then applied all four SQL files in separate LOCAL transactions, registering versions in that clone only. Local history advanced56→60. All 54 original datasets matched after projecting away only the three expected additive columns on profiles/registry. All 132 original function definitions remained unchanged. With the cloned real owner's zero-membership identity under `authenticated`, journals, journal lines, accounts, treasury, expenses and projects each returned zero rows. The clone was removed. No platform SQL was applied to hosted Development.

The tested boundary is independent platform authority, not a Company financial bypass. MFA requires the active registry/profile, real live owner session, database AAL2, verified bound TOTP factor and signed TOTP AMR within ten minutes (five-second future skew allowance); token refresh alone is insufficient. Local tests cover revocation, ban/expiry/session/factor checks, SYSTEM_ADMIN denial, private RLS/grants, last-admin protection, idempotency/rollback and Company isolation. Invitation correction checks current independent authority, monotonic recipient/issuer epochs, Company/email/user fences, cancellation of stale delivery jobs and all tested accept/revoke race orders. Neither source presence nor local acceptance proves actual hosted MFA/email behavior.

**4. Current financial baseline**

Hosted financial snapshot: `2026-10-29T05:25:28.020449+00:00` (09:25:28 Asia/Dubai). All **54 application table counts and SHA256 fingerprints exactly match H3 and the H6 native restore baseline**; zero unexplained differences. H8 transactions were read-only and separate metadata snapshots, not a promise about later writes.

| Aggregate | Count |
| --- | ---: |
| Companies / memberships | 17 / 280 |
| Projects / subcontracts | 24 / 69 |
| Accounts / treasury accounts | 63 / 21 |
| Expenses / historical sources | 142 / 248 |
| Journal entries / lines | 528 / 1,102 |
| Unbalanced journals | 0 |
| Storage buckets / objects | 0 / 0 |

No customer records, monetary amounts, names, emails, passwords, signing keys or Auth tokens are included in this document.

**5. Recovery readiness**

H6 evidence verifies AES-256-GCM authentication/tamper rejection, native archive decode, isolated PostgreSQL17 restoration and financial/history/schema comparisons. Its exact limitations remain: no native ACL/default-ACL backup, supplemented by now-current-compared H3 metadata; missing Supabase Vault extension and its zero-row config-data entry in the vanilla local rehearsal; no full Supabase Auth/Storage/provider/configuration service recovery. Native Auth data includes archived sessions/refresh records and requires an explicit future real-recovery invalidation decision. The plaintext source was not altered or deleted.

H8 independently compared `/media/nagham/msn4ever/NARVO_SECURE_BACKUPS` against source packages:

| HDD package | Files | Equality / permissions |
| --- | ---: | --- |
| `P0_H6-20261029` | 25 | Exact; no missing/extra/changed files; dirs0700/files0600 |
| `P0_H4` | 17 | Exact; no missing/extra/changed files; dirs0700/files0600 |
| `H3_H4_COMPLETE` | 37 | Exact; no missing/extra/changed files; dirs0700/files0600 |

Copies are on a different filesystem/device from the home-directory sources but remain on the same workstation. **Independent off-device backup/key custody and second-machine recovery are NOT VERIFIED.** A key-reference JSON is not the encryption key. Same-host encrypted HDD copies alone cannot establish recovery after losing the sole native key store. No backup artifact or manifest was edited during H8.

**6. Outstanding activation gates**

- Complete independent encrypted backup/key custody and second-machine recovery, or obtain an explicit, reviewed Development-only residual-risk decision. This requirement is not marked complete or silently waived.
- Final time-of-release target/history/registry/hash/financial/grant recheck and guarded canonical CLI dry-run; no resolver-created role, no Vault update, no seeds or custom-role inclusion.
- Actual owner sign-in/enrollment/AAL2 session acceptance is unperformed. Hosted TOTP enrollment/verification are enabled (max10), signup remains disabled, but the owner has no verified factor/session now.
- Current invitation/recovery templates use ConfirmationURL and lack TokenHash placeholders. They are not configured for the documented callback flow (which rejects implicit fragments). Actual delivery/callback/recovery compatibility remains untested. No custom SMTP is configured; this alone is not declared a Development blocker, but provider delivery capability/limits must be verified.
- Zero Edge Functions are deployed. The delivery function, server-only configuration and exact approved HTTPS Development origin/redirects need separate authorization and acceptance. Current SiteURL is `https://maker-eosin.vercel.app`; do not assume that existing alias is the approved new console release target.
- Hosted authorization/race/delivery and actual-owner EN/AR browser acceptance remain future gates with explicitly approved isolated fixtures. No frontend/function deployment or real account/membership/Company change is authorized by H8.

These are operational/configuration/acceptance gates, not a newly demonstrated accounting/tenant defect. No confirmed new product security defect was identified. Strict callback behavior, trusted-role defaults and at-least-once email semantics remain expected behavior; production-wide monitoring/full disaster-recovery/Production Security & Accounting Integrity Audit remain separate readiness concerns.

**7. Decision and exact next authorized action**

**GO for review of the prepared activation procedure; NO-GO for activation now.** Database migration implementation and scoped application recovery are locally verified, but the remaining custody/configuration/owner acceptance gates are not satisfied. H8 authorizes no mutation, including using the future procedure immediately.

Next authorized work is independent custody/second-machine recovery preparation and continued read-only validation. After those gates (or an explicit reviewed Development risk decision), request a separately scoped controlled Development activation batch covering the precise migrations, provider/function/frontend changes and permitted hosted test fixtures. Do not ask for or send secrets in chat. Use the [activation plan](PLATFORM_DEVELOPMENT_ACTIVATION_PLAN.md), not an improvised SQL Editor deployment.

**8. Evidence and lifecycle classification**

Sanitized evidence and release manifest: `/tmp/narvo-p0h8/` (hosted metadata, 54 hashes, role/grant comparisons, provider flags, HDD comparisons, native-clone rehearsal). Existing H6 report/procedure remain at `/home/nagham/.local/share/narvo-backups/native/P0_H6-20261029/`. Browser evidence: `/tmp/narvo-platform-evidence/`. Temporary evidence is not independent backup custody.

Business/accounting: VERIFIED unchanged baseline and clone preservation. Security: VERIFIED local tested boundaries/current metadata; actual provider/hosted acceptance DEFERRED. Database: VERIFIED original-history preservation, current compatibility and local native-clone application; hosted dry-run/apply NOT PERFORMED. Deployment: NOT PERFORMED; future changes DEFERRED. Recovery: VERIFIED local/HDD scope; off-device key/second-machine/full-service scope DEFERRED. Documentation: this checkpoint and the linked future plan supersede older remote-unknown labels; earlier dated records remain historical. Only readiness documentation is added/updated; no application or migration implementation change.
