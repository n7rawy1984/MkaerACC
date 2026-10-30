# Approved Development owner transfer — APPLIED AND VERIFIED

The product owner explicitly approved the exact reviewed SQL SHA256 `a100a39f71fdf9546904965840007c0ffdd7b68a12fae98d60eeb19a19031e80`. Applied only to MakerACC-Development (`eqnzueginpkskbnqvgoc`). Immediate postflight passed at **2026-10-29 17:44:59UTC /21:44:59Dubai**. This actual result supersedes all earlier preparation/approval-pending statements below and in earlier phase records. The reviewed SQL file is preserved unchanged as the approved artifact; its pre-approval comment is historical. Do not rerun it.

Actual committed state:

| Existing Auth identity | Registry status | Platform role | Authority epoch |
| --- | --- | --- | --- |
| `e1ef565b-c54d-4b52-bba3-360a03da7aa3` |INACTIVE|PLATFORM_OWNER|0→1|
| `ebcf7115-6cd9-49be-af25-8e57b5befd75` |ACTIVE|PLATFORM_OWNER|0 (new registry entry)|

Exactly one active owner, two retained registry records, one exact `platform_owner_transferred` audit event with request ID `d362061b-17d0-4eb2-9a9b-3d690fc8a817`. Both existing Auth accounts were preserved; no additional Auth account or simultaneously active owner was created. Audit metadata truthfully attributes the approved operator correction and does not claim target JWT/MFA authentication.

Fresh preflight verified exact project identity/health, trusted postgres role, original single active source owner, absent target registry/history/audit, both ACTIVE confirmed nonbanned identities, zero memberships and approved SQL hash. The protected executor supplied transaction-local project/approval guardrails only after those real checks and explicit approval. Reviewed registry/audit writes then committed atomically. No passwordless CLI login-role creation or schema/migration deployment occurred.

All immediate postflight checks passed: old owner inactive with one epoch increment; target sole ACTIVE PLATFORM_OWNER; exactly one correct audit; both membership counts zero; original authorization function definitions/configuration/ownership/ACLs unchanged. Ten DB-side row-count/fingerprint comparisons matched exactly: source/target Auth users, Auth identities, Auth sessions, MFA factors, profiles; all Company memberships; journal entries, journal lines, historical-source records and historical-source audit. No credential material, Auth hashes, tokens or financial rows were downloaded—only DB-side fingerprints/status metadata.

Financial counts preserved: **528 journal entries,1102 journal lines,248 historical-source records**; full dataset fingerprints also match, not merely counts. No financial or Company/member record changed. No MFA factor, session, password or profile changed. Source Auth account remains intact; only registry authority was retired.

Target verified TOTP count remains **0**. Real MFA enrollment/challenge and actual hosted Overview acceptance are **DEFERRED**. The owner's existing signed-in target session can choose Retry at `/platform` to obtain fresh database context; no password reset, account recreation or role-claim token workaround is needed. Enroll/verify the real authenticator when prompted; the console still requires fresh AAL2/TOTP before privileged data. No actual Overview success is claimed from registry state alone.

Verification: prior20 isolated SQL/authorization/preservation checks were already passed; not repeated. Fresh hosted preflight and immediate postflight pass; final documentation whitespace/hash checks pass. No frontend runtime change required, so no unrelated build/general audit was repeated. No backup/key/custody operation, SMTP/email, public/Production deployment, commit or push.

Definition of Done: operational authorization/database correction **VERIFIED** on Development; accounting/Auth/MFA/membership preservation **VERIFIED** by fingerprints; real MFA/browser/Overview acceptance **DEFERRED**; deployment/schema migrations **NOT APPLICABLE**; documentation **VERIFIED**. Independent disaster recovery remains owner-managed and is not reclassified. Evidence: `/tmp/narvo-owner-transfer-execution/preflight.json`, `apply-attempt.json`, `apply-response.json`, `postflight.json`, `result.json`; safe API request evidence is separate.

---

## Historical reviewed preparation (before execution approval)

# Guarded Development owner transfer — PREPARED, NOT APPLIED

The product owner confirmed that the intended owner is existing Auth UUID `ebcf7115-6cd9-49be-af25-8e57b5befd75`. That reply selected identity only, explicitly not execution approval. The currently hosted registry remains on `e1ef565b-c54d-4b52-bba3-360a03da7aa3`; the selected target is not authorized yet. No hosted call or mutation was performed during this preparation.

## Exact proposed operation

Target only MakerACC-Development (`eqnzueginpkskbnqvgoc`). Review [the operational SQL](release/development-owner-transfer.sql), SHA256 `a100a39f71fdf9546904965840007c0ffdd7b68a12fae98d60eeb19a19031e80`. This is an operational registry-data correction, not a schema change or canonical migration. All60 applied migrations remain unchanged. No bootstrap rerun and no new administrator account.

Within one protected transaction:

1. Require a postgres operator, externally verified exact Development project, and explicit approval tied to operation `d362061b-17d0-4eb2-9a9b-3d690fc8a817`. The raw file is guarded and aborts without those executor-supplied settings. Settings are operator guardrails, not browser authentication or independent proof of project identity; the executor must verify the real API target before setting them.
2. Acquire the existing platform authorization gate and serialize registry writes. Use5-second lock/15-second statement limits. Require the sole original ACTIVE/PLATFORM_OWNER entry, absent target registry/history and absent prior operation audit. Abort on changed inventory or any replay.
3. Lock/check both existing Auth/profile identities; require ACTIVE profiles and a confirmed, nonbanned target. Require the documented zero memberships for both principals; abort on drift instead of altering memberships.
4. Mark `e1ef565b-c54d-4b52-bba3-360a03da7aa3` INACTIVE, preserving its registry history. The existing epoch trigger advances its authority generation. Keep both Auth accounts, profiles and sessions intact.
5. Insert one ACTIVE/PLATFORM_OWNER registry entry for `ebcf7115-6cd9-49be-af25-8e57b5befd75`, attributing the owner-approved operational change to the selected existing owner identity. The audit explicitly records protected-operator execution and does NOT claim that the target authenticated the operation by JWT/MFA.
6. Append exactly one immutable `platform_owner_transferred` audit event. Assert exactly one active owner, correct source/target states, source epoch advancement and unchanged zero memberships; commit only if all checks pass.

No Auth/profile rekeying, creation/deletion, password change, MFA reset, RLS/grant/function change, Company membership assignment, financial write, email, backup operation, deployment, commit or push. Old owner authority ends through current database checks; the target still needs real MFA before reading privileged Overview data. No access/session token is generated or fabricated by this operation.

## Focused local verification

`node scripts/verify-platform-owner-transfer.mjs` — **20 assertions PASS** on a disposable PostgreSQL fixture. The exact reviewed SQL executes there, using only synthetic users/data and external operator settings modeled inside the fixture. It checks:

- Missing approval/wrong project/non-postgres operator fail closed.
- Changed source status, inactive/unconfirmed/banned target, extra registry history and unexpected membership fail without partial registry/audit effects.
- Disabling the epoch trigger in the disposable fixture makes the postcondition fail and rolls the entire operation back. No trigger was disabled on hosted Supabase or in the operational SQL.
- Successful transfer retains the original INACTIVE entry and exactly one active target owner, with one audit event and an incremented old epoch.
- Fingerprints of fixture Auth users/sessions/MFA factors, profiles, Companies, memberships, accounts and balanced immutable journal entries/lines are identical before/after transfer.
- Target AAL1 receives `step_up_required:true`; Overview still rejects it with42501/MFA_REQUIRED. Old identity is denied. Owner gains no Company financial visibility. Reexecution fails without duplicate effects.

No actual owner MFA/hosted Overview success is claimed. No hosted rehearsal was run. Build/browser/general audits were not repeated because this batch changes no application runtime or schema; `git diff --check` and focused SQL/credential-literal review suffice locally.

## Execution boundary and acceptance

**PENDING: explicit approval to apply this exact privilege transfer.** Intent selection is complete, not authorization to execute. Before any approved application, freshly verify exact project identity, current source/target states and the SQL hash; abort on drift. Use only the pinned protected Development API/connection, never passwordless CLI role initialization or raw execution against an unverified project. Capture safe pre/post registry, Auth/MFA/session and membership evidence without logging credentials, hashes, session tokens or financial rows.

After an approved transfer passes postflight, the existing target browser can choose Retry to obtain its fresh database context; no password reset or account recreation is needed. Its actual verified TOTP count was zero at the last targeted snapshot, so real authenticator enrollment/verification remains an acceptance requirement. The agent cannot manufacture that proof. The existing console and database enforce it.

Definition of Done: business/accounting policy NOT APPLICABLE; zero financial/Company effects VERIFIED locally; authorization/MFA/DB guards VERIFIED locally; hosted application and real owner acceptance DEFERRED; deployment NOT APPLICABLE; documentation VERIFIED. Files: reviewed SQL, focused local verifier, npm verification script and current handoff/roadmap/console/activation/identity records. Existing recovery materials are untouched and independent disaster recovery is not reclassified.
