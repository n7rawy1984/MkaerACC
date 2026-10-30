**Actual result:** all four reviewed migrations applied to `eqnzueginpkskbnqvgoc`; hosted history60, original56 rows and54 datasets preserved, grants/RLS/canonical function bodies verified. Owner-approved Development-only risk exception used; independent disaster recovery remains incomplete. Do not rerun the apply command below. See the [actual execution checklist](PLATFORM_ACTIVATION_EXECUTION.md). Real owner MFA, hosted email/function acceptance and public deployment remain separate.

# Controlled Development Platform Owner activation procedure

**EXACT DEVELOPMENT BATCH APPLIED / POSTFLIGHT PASS. This is now the historical controlled procedure, not a command to reapply.** P0-H8 authorized no activation; the subsequent activation-execution instruction conditionally authorizes exactly four Development migrations only after every mandatory gate passes. The latest explicit owner risk exception clears the independent-custody release-policy gate for this exact Development batch only. Independent disaster recovery remains incomplete; all technical preflight/postflight conditions remain mandatory. See the [current execution checklist](PLATFORM_ACTIVATION_EXECUTION.md). Target exclusively MakerACC-Development `eqnzueginpkskbnqvgoc`; Staging/Production and existing live financial changes remain outside this plan.

**Latest completed evidence:** owner verified custom SMTP/Resend transport delivery to an existing historical Auth user, exact four-migration linked CLI dry-run and matching release allowlist. SMTP setup and initial dry-run are closed; new-user/Platform invitation acceptance is not implied. Targeted GET still finds hosted templates without TokenHash and no delivery function. The current Development-only owner exception supersedes the earlier gate blocker for this exact batch; it is not recovery verification. See the [minimal current sequence](PLATFORM_ACTIVATION_EXECUTION.md). No Production deployment is authorized.

**0. Define the authorized existing-application batch**

Use the existing Vercel project and application origin `https://maker-eosin.vercel.app`, console route `/platform`, and existing Supabase Development project. No separate project/domain/permanent Preview. Confirm a maintenance/quiet window, operator, four hash-pinned migrations, provider/function/frontend work and permitted existing/synthetic test identities/Companies. No broad permission to mutate real Maker memberships or financial data is implied. Preserve the reviewed source snapshot (main/HEAD `9da8612…` plus accumulated uncommitted platform work); no commit/push is authorized here. Verify no unexpected source changes since H8 and rerun affected tests if hashes change. Synthetic H8 build output uses example.invalid and must not be deployed.

**1. Final database/financial preflight — abort on discrepancy**

- Authenticate the exact target and check health/linked ref/public configuration without printing credentials. Use an existing database credential supplied through protected process configuration; never use an absent-password fallback that can initialize a login role. H8 used Management API READ ONLY SQL and did not configure a native credential.
- Reconfirm exactly56 canonical versions through `20261008160000`, matching local originals; four pending hashes must equal the H8 table. No new platform object/function/epoch-trigger conflict may exist. Resolve divergence before any DDL; never rewrite applied history or run repair/reset to hide mismatch.
- Reconfirm the sole documented ACTIVE registry owner, ACTIVE/confirmed/non-banned identity and zero Company memberships; inventory any unexpected registry entry. Migration1200 defaults EVERY existing registry row to PLATFORM_OWNER, so a changed registry requires review, not blind application. Never rerun owner bootstrap.
- Recheck actual Auth session/TOTP column types, live-session/delete dependency privileges, RLS/table/function/schema/default grants and role membership options. Native dump alone omits ACLs; retain existing verification evidence in documentation. Backup/recovery handling is owner-managed and outside agent scope.
- Capture a fresh repeatable-read aggregate baseline for all54 original application tables using H8's ordered PostgreSQL JSON/SHA256 convention, full56-row migration history and journal balance. H8 totals528 journals/1102 lines/248 historical sources and all54 hashes match H3/H6, but later writes must be reassessed. Do not assume an old recovery point covers newer financial activity; report any difference without performing backup/recovery operations.

**2. Backup/custody gate — no silent exception**

The owner handles backup, encryption, keys, custody, transfer, deletion and recovery separately. Do not perform related operations or request destinations, keys, devices or custody details. Keep existing H3–H6/H8 verification documented. Independent disaster recovery is not verified complete. The owner has explicitly authorized the limited release-gate amendment for these four Development migrations and accepted whole-workstation-loss risk. This clears the policy gate for this batch only; do not infer any broader waiver, Production readiness or authority for unrelated changes. Do not rerun recovery-clone/decryption procedures as a migration check. Reuse their recorded rehearsal evidence while the SQL hashes remain unchanged.

**3. Canonical migration application — four ordered steps**

Only after explicit activation authorization and gates1–2: securely supply the EXISTING Development database password to the operator's CLI child process (documented `SUPABASE_DB_PASSWORD`, no value in source, command arguments, terminal output or chat). The invocation must abort if the credential is absent; do not permit resolver-created login roles. Verify the installed CLI's credential binding/target first. Do not reset a password or create/grant a role for this release.

Run the guarded canonical dry-run from the reviewed repository using the installed CLI:

```sh
node_modules/@supabase/cli-linux-x64/bin/supabase db push --linked --project-ref eqnzueginpkskbnqvgoc --dry-run --skip-vault
```

Require EXACTLY the four versions below, no seed/custom-role branch and no Vault updates. Installed CLI help confirms Vault updates can precede migration execution without `--skip-vault`; therefore keep that flag on both dry-run and eventual apply. H8 did not execute this command.

After review of that exact dry-run, the separately authorized application is:

```sh
node_modules/@supabase/cli-linux-x64/bin/supabase db push --linked --project-ref eqnzueginpkskbnqvgoc --skip-vault
```

Do not add `--include-all`, `--include-roles` or `--include-seed`. One canonical invocation executes the four steps in timestamp order; do not invent a per-version flag (installed push has none), execute individual files in SQL Editor, or move migration files around to conceal history.

| Step | Version | Required effect/checkpoint |
| --- | --- | --- |
| 3a | `20261028120000` | Registry role column, five private control-plane tables, append-only audit, live actor/session/MFA validator and safe queries. Exactly the approved owner receives the default role; no Company membership/financial grant. |
| 3b | `20261028121000` | Administrative use-case commands, receipts, idempotency, lifecycle/onboarding and last-admin protections. No financial posting/GL writes. |
| 3c | `20261028122000` | Invitation/outbox/lease/acceptance commands. Do NOT expose/invoke invitation delivery or acceptance as a release feature at this intermediate point. |
| 3d | `20261028123000` | Issuer/recipient epochs and Company-scoped email/user fences, serialized decision gate, atomic invitation/outbox cancellation and replacement safe commands. Conservative cancellation of any legacy pending invitations; no history deletion. |

Do not assume the entire four-file batch is one transaction. Inspect CLI completion/history after any error; a committed prefix may remain. Keep the console/delivery unexposed until1230 is verified. The H8 native clone validated all four files and preservation; it did not validate this hosted CLI transaction behavior.

**4. Immediate post-migration schema/security checks — before UI/function enablement**

Read-only verify exact60 versions, including all four file identities; no altered original56 history. Confirm eight new private platform tables, forced/enabled RLS, expected additive columns/constraints/triggers and PLATFORM_OWNER only on the intended existing registry entry. All original132 function definitions must remain unchanged. Verify new SECURITY DEFINER functions have their fixed empty search_path and minimal function-specific grants.

Verify anonymous/ordinary/Company SYSTEM_ADMIN cannot invoke privileged platform entry points; service_role can only invoke its explicitly intended delivery completion path, not caller administrative authority. Private tables/helpers must not become browser-writable/readable. Check financial RLS/permissions remain unchanged and the zero-membership owner has no financial access. The existing npm verification scripts ALWAYS use local fixtures; rerunning them is not a hosted security pass.

Hosted behavioral authorization/race tests need a separately approved test matrix and isolated fixture IDs, actual signed sessions and service credentials kept server-side. Do not run the local SQL harness against hosted data, forge browser claims, execute actual privileged mutations merely to obtain a pass, or grant Company accounting access to the owner to bypass failure.

**5. Financial preservation — hard stop on unexplained differences**

Before acceptance fixtures, compare all54 original datasets to the immediate preflight point. Project only original columns: remove `platform_access_epoch` from profiles and `platform_role`/`platform_access_epoch` from registry for the old-data hash comparison. These additive columns and new platform metadata are expected; original field values/rows must remain unchanged. Original financial functions, journal/historical/treasury/account/project/contract data and balanced totals must match exactly.

For later approved hosted fixture tests, keep real Company financial data untouched. Track allowed synthetic administrative changes separately by explicit identity/Company allowlist; append-only audit is retained. Compare original financial rows and hashes with those exact exclusions where necessary; do not normalize away unexplained differences or call changed global Company/membership counts a financial preservation pass. No real posting/reversal/payment is part of platform acceptance.

**6. Real Platform Owner authentication/MFA and provider readiness**

The existing owner signs in normally and enters `/platform` without Company membership. Hosted TOTP enrollment/verification are already enabled; do not toggle unrelated signup/provider policies. Enroll/verify a real authenticator under separately authorized owner control, require AAL2, matching live session/factor and signed TOTP AMR fresher than ten minutes. Do not export QR seed, codes, JWTs, session IDs or passwords to reports. Verify stale MFA, AAL1, token refresh without new challenge, revoked sessions/factors and inactive authority fail closed. No registry/self-recovery bypass, manual AAL grants or owner financial membership.

The owner selected the existing application at `https://maker-eosin.vercel.app/platform`. Keep the existing Vercel project, Supabase project and architecture; a temporary same-project Preview is optional only when needed for safe validation. This target decision does not authorize unverified live deployment or bypass the database/release gates. Authorize any needed exact redirects/templates and frontend/function configuration explicitly. Source callback accepts code or supported token_hash invite/recovery flows and rejects implicit fragments. Current invite/recovery templates lack TokenHash; configure/rehearse the documented flow before using those features. For the existing delivery redirect with `?invitation_id=…`, token-hash parameters need `&`; recovery callback without an existing query needs `?`. Review escaping, referrer/log behavior and provider semantics, not a blind template paste.

Zero delivery functions are deployed now. Separately authorize deployment of `platform-invitation-delivery`, server-only project/API credential configuration and exact HTTPS PLATFORM_APP_ORIGIN, with JWT/CORS checks intact. No private credential may be VITE_*. Retain the owner-verified Resend/custom SMTP configuration and Delivered/receipt transport evidence; do not repeat provider setup. This does not prove new-recipient invitation acceptance or the Platform delivery function. Do not send invitations or create Auth users without specific fixture/recipient approval. Existing-user delivery semantics and actual recovery must be demonstrated, not inferred from mocked tests.

**7. Browser/hosted acceptance and release decision**

Rebuild the existing application with verified browser-safe Development configuration only after database activation and compatibility checks. Use a temporary Preview in the existing project only if necessary; no duplicate application or permanent hostname. Publication to the existing public site remains subject to all mandatory gates and verified acceptance. Do not deploy H8 synthetic build output or assume the public alias's source/environment matches this release.

Actual owner verifies English/Arabic, RTL/LTR,390px/desktop layout, keyboard/focus, direct zero-membership platform routing, MFA enrollment/step-up/freshness/revocation and session transitions. Ordinary/Company SYSTEM_ADMIN users must be denied; tenant switching must not acquire platform or cross-company financial authority. Rehearse approved provisioning/lifecycle/idempotency/last-admin/invitation flows on isolated synthetic records only.

Hosted invitation matrix must cover stale invite after grant/revoke/downgrade, delivered-link replay, deactivation/reactivation, issuer revocation, CompanyB isolation, resend/delivery acknowledgement races, both overlapping accept/revoke orders and replay after accepted access is revoked. Validate user/profile/session epochs and genuine independent sessions, not just sequential calls. Actual email/callback/recovery and provider errors must be visible and safely handled. Preserve append-only audit and reconcile allowed fixture changes.

Repeat financial/history/security checks after acceptance. If any required hosted or actual-owner check is missing, report the exact partial scope and keep the affected feature unavailable; do not call the whole console accepted. Development acceptance never authorizes Staging/Production or real accounting go-live.

**8. Failure/recovery decision points**

- Preflight/credential/dry-run discrepancy: STOP before DDL; no role initialization, password reset, grant patch, migration repair or schema workaround.
- Migration error: keep console/delivery unavailable; inspect actual history and schema read-only. Do not blindly reapply an applied prefix. Correct an uncommitted/unapplied defect only through a newly reviewed/retested canonical plan; defects in applied migrations require a new forward correction, never rewriting history or manual schema edits.
- Auth/MFA/tenant/grant failure: fail closed; no bypass or broader role assignment. Capture sanitized evidence and fix under a new authorized batch.
- Financial fingerprint/balance difference: stop acceptance and financial activity through the approved operator procedure, preserve evidence and investigate. Do not rewrite posted history or restore old tables over newer accounting truth.
- Full recovery consideration: determine whether any new data would be lost, recoverability of service configuration/keys/sessions and the exact target. Prefer a safe forward fix where appropriate; a destructive hosted restore needs separate explicit authorization. H6's vanilla local/Vault/ACL/provider limitations remain relevant. Never delete backup/registry/audit history to make a release pass.

Official operational references: [Supabase CLI](https://supabase.com/docs/reference/cli/supabase-db-push), [Supabase MFA](https://supabase.com/docs/guides/auth/auth-mfa), [email templates](https://supabase.com/docs/guides/auth/auth-email-templates). Installed CLI help and actual repository/hosted evidence govern the specific reviewed release.
