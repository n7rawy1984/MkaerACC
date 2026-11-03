# Controlled integrated Production candidate — execution record

## Latest acceptance — technical PASS / promotion pending human approval

The user accepted the generated-alias exception. Authoritative metadata confirms the named Production domain and configured Production target remain on the original deployment. Actual owner identity/AAL2 and9 owner screens, independent Company administrator identity/RLS and19 Company routes, six-section/zero/unavailable semantics, representative EN/AR layouts and keyboard behavior are now verified. A minor summary-container group-label issue remains a non-blocking follow-up. Fresh no-mutation/configuration/source postflight PASS. No promotion occurred. [Current acceptance and human actions](PRODUCTION_CANDIDATE_ACCEPTANCE.md). The original execution stop below is historical and superseded by this acceptance.

## Original execution result and stop condition (historical)

**NO-GO for promotion.** Exactly one integrated Production candidate is READY, but the requested strict unaliased condition failed. No promotion or alias-repair command was executed. The existing `maker-eosin.vercel.app` alias remains on `dpl_DC2wK34FdbWNsVtnqMCzb54uRwDh`.

- Candidate: https://maker-rom44ea4z-n7rawy1984-8059s-projects.vercel.app
- Deployment: `dpl_8Jvbmi1GFoVPNhG36CAf1ZGkCfHP`.
- Existing maker project: `prj_n03DWya5Gr1uB82qtY084FvsC7q4`; team `team_HozmwrkzbERtyer2nIT25MWv`.
- Target: Production; `--prod --skip-domain` was used exactly once, with the existing project/team and reviewed Vite configuration.

Vercel assigned its automatic project alias `maker-n7rawy1984-8059s-projects.vercel.app`. This is an actual binding from the deployment-alias API, not merely a planned alias in deployment metadata. Deployment readback reports `autoAssignCustomDomains=false`. Installed CLI65.9.0 implements `--skip-domain` by setting `autoAssignCustomDomains=false`; the provider still assigned its generated project alias. This is a confirmed release-isolation mismatch, not evidence of an accounting or authorization defect. Both candidate and generated alias send unauthenticated requests to Vercel sign-in; protection was not disabled. No claim is made about the generated alias's prior deployment binding because that specific binding was not captured in preflight. Do not remove or rebind it automatically.

Release execution stopped at this guard. Only read-only impact/postflight checks and evidence recording followed. Authenticated owner/MFA, Company-module and visual candidate acceptance have **not** been completed.

## Frozen integrated frontend package

[272-file manifest and exact source hashes](release/controlled-production-candidate-manifest.json), [execution result](release/controlled-production-candidate-result.json), [clean build log](release/controlled-production-candidate-build.log), [clean install log](release/controlled-production-candidate-install.log).

Includes existing accounting engine/modules; Platform Owner; Company onboarding/provisioning/membership/subscriptions; M1 operator fixes; M2.1 six-section dashboard; M2.2 shared shell/module UI. The source package is the accepted251-file integrated Preview package plus21 new source files, with20 existing files updated. All current sources match the prior passing M2.2 evidence; protected application imports pass the production-boundary validator. No financial source edit was made during this release execution.

Excludes environment/credential files, database/Edge payloads, fixtures, screenshots, backups and private evidence. Only the two existing production-boundary helpers are included from scripts. The existing `deploy/platform-preview.vercel.json` is environment-agnostic Vite build/output, SPA rewrites and security/callback headers; the CLI explicitly targeted Production. No project root/build/protection configuration was changed.

Clean `npm ci --no-audit --no-fund` and `npm run build` PASS. Verified sole compiled Supabase target `eqnzueginpkskbnqvgoc`, `supabase-auth` mode, integrated feature markers, credential boundaries and unchanged frozen sources. Existing chunk-size advisory remains. Build output and dependencies were removed from the source upload directory before upload. Vercel upload dry-run matched all272 paths and SHA1 upload hashes; source SHA256 hashes are in the manifest. READY confirms remote build success; it does not prove authenticated UI acceptance.

## Approved invitation configuration change

Supabase `MakerACC-Development`, `eqnzueginpkskbnqvgoc`, remains the existing shared database behind Production and Preview. No project switch or schema change occurred.

- `PLATFORM_APP_ORIGIN=https://maker-eosin.vercel.app`.
- `PLATFORM_INVITATION_ADDITIONAL_ORIGINS=["https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app","https://maker-9eixk2rgu-n7rawy1984-8059s-projects.vercel.app"]`.

Only these two existing settings changed. Other user-managed secret metadata, all unrelated secret digests and full Auth configuration fingerprints are preserved. The seven previously reviewed provider-managed defaults permit timestamp-only metadata changes; no unrelated digest change is permitted. Function source was downloaded before/after and is byte-identical to reviewed local source. Function version3→4 was a configuration-only refresh; no function code deployment occurred. Status ACTIVE and JWT verification enabled.

Seven non-delivery checks PASS: OPTIONS for Production and both approved Previews204 with exact origin/method/header/cache controls and valid Vary set; unknown origin403; anonymous POST from each approved origin401 at the JWT gateway. No authenticated delivery/claim/finish endpoint, invitation, email or business command was invoked. The random candidate hostname was not added to the delivery allowlist. Production is now the canonical invitation callback destination, but no real invitation acceptance is claimed before release completion.

The initial read-only source download encountered a missing local template-file prerequisite in its isolated workdir. Supplying the existing template files locally resolved it; no hosted Auth configuration or function source changed, and no deployment retry occurred.

## Postflight and verification limits

Fresh preflight/postflight fingerprints are identical for all46 Company-owned tables, Companies/profiles, subscriptions and private administrative/request/counter tables. The64 canonical migrations, function definitions and RLS/grant/policy catalog fingerprints are unchanged. Auth session testing was not performed. Vercel Production environment metadata, branch/main linkage, project protection and named Production alias are unchanged. No database mutation/migration, record deletion, financial transaction, Git commit/push/merge, second candidate deployment or promotion occurred.

Previously passing local evidence remains valid because source hashes match:37 unit/preservation checks,116 Company browser assertions, Expense recovery and source edit/archive/export regressions, eight axe scans with zero reported violations. The `aria-prohibited-attr`/`color-contrast` incomplete items still need manual review; they are not passes or confirmed violations. Human M2.2 visual acceptance remains pending. Matching local evidence is not relabelled as authenticated candidate runtime evidence.

## Required next decision and rollback

First resolve or explicitly accept the generated-project-alias exception. Then complete real owner sign-in/MFA and Company session identity/membership checks, Company Dashboard/six sections, Expenses/Projects/Contracts/Treasury/Attendance/Payroll/Reports, truthful zero/unavailable states and responsive/RTL visual acceptance. User-controlled credentials/MFA must remain private. No promotion is authorized by the current task.

The existing named site already uses the rollback target; **no main-domain rollback is currently needed**. Known functioning target:

- `dpl_DC2wK34FdbWNsVtnqMCzb54uRwDh`.
- https://maker-7y2nimvnx-n7rawy1984-8059s-projects.vercel.app

If a future separately authorized promotion needs reversal, use Vercel rollback to this exact existing deployment, then confirm `maker-eosin.vercel.app` binding and authentication. A frontend rollback never reverses database writes. None occurred in this execution, so no database restore is required.

If separately authorized to abandon the origin change, first prove current settings still equal this execution's values, function source/JWT/Auth remain as recorded and unrelated metadata has not drifted. Restore only:

- `PLATFORM_APP_ORIGIN=https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app`.
- `PLATFORM_INVITATION_ADDITIONAL_ORIGINS=["https://maker-9eixk2rgu-n7rawy1984-8059s-projects.vercel.app"]`.

Read back expected setting digests, preserve unrelated user-managed metadata, allow timestamp changes only for the two owned settings and seven provider defaults, verify unchanged source/JWT/Auth and rerun non-delivery checks. Do not rewrite the function or restore the database. Any generated-alias repair/removal requires separate scope after independently establishing its intended prior binding; the main domain must remain unchanged.

## Completion classification

- Business/accounting: VERIFIED no mutation/semantic change; accepted disposable-data policy retained without cleanup.
- Security/authorization: VERIFIED unchanged catalog/Auth/JWT and provider protection; DEFERRED candidate authenticated session/MFA/Company acceptance.
- Database: VERIFIED64 aligned migrations and identical fresh data/catalog fingerprints; no schema work.
- Deployment: VERIFIED one READY Production candidate and unchanged named domain; FAILED strict unaliased condition; promotion unapproved.
- Testing: VERIFIED clean build/source/upload/non-delivery/postflight checks; DEFERRED authenticated candidate and human visual/accessibility acceptance.
- Documentation: VERIFIED manifest, machine result and this report reflect actual execution and stop condition.
