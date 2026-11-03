**Stage C delivery activation — 2026-11-01: DEVELOPMENT VERIFIED / RECIPIENT ACCESS AND STAGE D PENDING.** Tested Vary-only parser fix passes13/13 local cases and syntax checks; other CORS assertions, source and metadata verifier unchanged. Fresh guards passed; one approved origin set and one unchanged function deployment reached ACTIVE v1/JWT enabled (ID59414c7a-6baf-476d-8a7b-376783404b76). Downloaded source hashes, all secret digests/user-managed metadata and full Auth settings preserved; only allowlisted provider timestamps refreshed. Hosted handler OPTIONS204/exact origin/CORS and gateway unauthenticated POST401 both pass; final function stable, no rollback. No email, records, financial, frontend/Vercel, Production, Git or recipient-access operations. [Actual activation and remaining access requirements](PLATFORM_ONBOARDING_STAGE_C_DELIVERY_ACTIVATION.md); [execution evidence](release/development-onboarding-stage-c-vary-activation-result.json). Delivery activation is bounded Development evidence, not real-recipient acceptance or commercial readiness. Earlier rollback/preparation labels remain historical.

**Stage C conditional retry — closure 2026-11-01: ROLLED BACK / ACTIVATION INCOMPLETE.** One authorized Development deployment reached ACTIVE v1 with exact source/JWT/origin; corrected metadata verification passed (all seven default digests unchanged, timestamps refreshed). OPTIONS returned204 with exact approved origin/method/header/no-store and `Vary: Accept-Encoding, Origin`; the operator verifier incorrectly required full-string `Vary: Origin`, triggering the authorized guarded rollback. New function and origin are absent; full Auth and secret digests preserved. Unauthenticated POST was not executed. No further retry, delivery/email, records, financial, frontend/Vercel, Production or Git actions. [Exact result and required Vary-token correction](PLATFORM_ONBOARDING_STAGE_C_RETRY.md); [execution evidence](release/development-onboarding-stage-c-retry-result.json). Recipient access/Stage D remain separately approved future work; commercial readiness is not claimed. Earlier preparation/activation descriptions remain historical.

**Latest metadata resolution — 2026-10-31: VERIFIER CORRECTED / RETRY PREPARED, NOT DEPLOYED.** Targeted read-only evidence supports documented provider-default initialization/visibility; exact historical field deltas cannot be recovered from the old aggregate-only snapshot. The corrected comparator records per-entry evidence, tolerates only exact-provider timestamps/order, and retains strict digests, user-managed metadata, origin, source/JWT and Auth checks.19 local cases and current read-only comparison pass. No hosted writes/invocations. A second activation requires new explicit approval; recipient access/Stage D remain separate. [Evidence, limits and exact retry scope](PLATFORM_ONBOARDING_STAGE_C_METADATA_RESOLUTION.md). Earlier rollback evidence below is retained unchanged.

# Stage C Development activation attempt — 2026-10-31

**ACTIVATION ROLLED BACK / FUNCTION AND ORIGIN ABSENCE VERIFIED.** The owner explicitly approved only the reviewed Development function/origin activation, non-delivery verification and guarded rollback. The preparation-only authorization statements below are historical; recipient access and Stage D remain separately gated.

[Exact execution evidence](release/development-onboarding-stage-c-activation-result.json).

## Actual outcome

- Fresh preflight confirmed `MakerACC-Development / eqnzueginpkskbnqvgoc`, healthy identity, approved three-file package digest, empty hosted function list, absent origin, exact Stage B values and unchanged approved Preview protection. No existing hosted function could consume the shared origin setting.
- Exactly one `secrets set` applied the approved Preview origin. The provider returned its SHA256 digest under `value`, whereas the verifier initially expected `digest`. This caused a pre-deployment verifier KeyError. Read-only diagnosis proved the exact approved origin digest; no repeated configuration write or rollback occurred at that point. The original stop record is retained.
- Exactly one function deploy succeeded: `platform-invitation-delivery`, ID `1eb210fc-7a3b-461c-af61-a55e96eb6b50`, **version1 / ACTIVE / verify_jwt=true**. Downloaded `index.ts` and `handler.mjs` matched the manifest byte for byte, including existing Auth/user/MFA claim/finalization contracts. No source or policy weakening occurred.
- Verification then stopped on the full secret-metadata preservation assertion. Supabase runtime-default entries were visible after the first function deployment. Removing the approved origin and six expected provider-default additions in memory did **not** reconstruct the complete before-fingerprint. The residual difference was not attributed to a specific field or credential value because the before-metadata was retained only as a fingerprint. Full Auth configuration still exactly matched its preflight fingerprint.
- **This is a verification limitation, not evidence of a confirmed authorization or credential defect.** No credential value was exposed, manually rotated, overwritten or deleted. No success was manufactured from an unexplained difference.
- The documented guarded rollback was used: current function ID/version/update marker and downloaded source matched this batch, origin digest matched, and no other functions existed. Exactly one delete removed this new function, then exactly one unset removed this new origin. Final readback confirmed no hosted functions, no origin setting and identical full Auth configuration. No retry was performed.
- Provider-initialized runtime defaults remain present. They were not removed or rewritten; rollback restored **function/origin absence**, not the exact original secret-metadata snapshot. The remaining defaults' presence does not prove successful runtime use.
- **OPTIONS/CORS and unauthenticated-POST smoke checks were NOT executed.** Verification stopped before them; no authenticated or unauthenticated function invocation, claim, delivery or finalization occurred. Thus hosted CORS/JWT rejection and all real delivery/onboarding behavior remain unverified.

## Scope and final readiness

Four narrowly scoped hosted commands total: one origin set, one function deployment, one deletion of that deployment, one origin unset. No Auth configuration write, migration, DB/RLS/grant change, financial operation, record creation, invitation/link/email, frontend deployment, Vercel change, Production/Staging change or Git commit/push/merge. Stage A/B evidence is retained, not rerun. The original approved three-file package remains unchanged; CLI-generated package state was moved to private temporary operator evidence.

| Category | Final classification |
| --- | --- |
| Business/accounting | VERIFIED: scope preserved; no financial changes. Company accounting readiness remains a later batch. |
| Security/authorization | VERIFIED: deployed source/JWT metadata preserved and Auth fingerprint unchanged; DEFERRED: live JWT rejection, MFA/claim/finish and recipient access. |
| Database | NOT APPLICABLE: no schema/migration/RLS/grant work; no migration alignment/dry-run repeated. |
| Deployment | VERIFIED: one deployment and guarded rollback; DEFERRED: accepted activation, runtime-default use and CORS smoke. |
| Testing | VERIFIED: package/source/origin/ID/version and rollback readbacks; DEFERRED: non-delivery smoke and real onboarding. No full build/lint/regression/general audit rerun. |
| Documentation | VERIFIED: actual attempt, initial verifier stop, unresolved metadata comparison and limited rollback scope recorded without overwriting preparation evidence. |

**STOPPED as authorized.** Function delivery remains inactive. No automatic redeployment, broader secret diagnosis or recipient-access operation is authorized by this closure. Any subsequent retry must first use a reviewed preservation check that handles provider-managed metadata and captures sufficient safe before-evidence; obtain explicit approval for that new hosted attempt. Recipient access and Stage D still require their own separate approvals. Super Admin is not commercially ready.

---

# Stage C — invitation delivery and recipient access preparation

2026-10-31. **PREPARED / NOT ACTIVATED.** Authorization covers targeted inspection, local packaging and documentation only. No hosted writes, deployment, access grant, messages, records, financial mutations or Git delivery. Stage C means delivery/access preparation; **Stage D means separately authorized real-recipient acceptance**, superseding older stage names in the activation plan.

## Baseline and lifecycle

Branch `release/platform-owner-console`, HEAD `16cf326`; preserve the existing dirty onboarding work. Stage A history62 /22 checks and Stage B13/13 are retained evidence, not rerun. Owner Preview browsing is owner-reported PASS; it does not establish recipient access. Earlier unapplied/template/Preview-pending labels in historical documents are superseded by their latest execution records.

Current work is deployment/access design and preparation. Local onboarding implementation and bounded prior tests are complete; hosted function execution, recipient access, provider rendering/delivery and acceptance remain deferred. No accounting implementation is needed here.

Read: AGENTS.md, functional readiness, new-user onboarding, Preview readiness, Stage B and its result; consulted handoff, roadmap and activation plan. Reviewed only the delivery entrypoint/handler, function configuration and directly related delivery/template contracts.

## Fresh read-only evidence

[Sanitized result](release/development-onboarding-stage-c-result.json).

- Supabase `eqnzueginpkskbnqvgoc`, MakerACC-Development: ACTIVE_HEALTHY. GET functions returned an empty list. `platform-invitation-delivery` is absent.
- GET custom-secret metadata contains none of the four required names. `PLATFORM_APP_ORIGIN` is therefore absent. The three `SUPABASE_*` names are provider-injected defaults, not proof of missing runtime credentials. Their actual runtime presence is **DEFERRED**; never create/rotate/copy them to resolve absence from this metadata list.
- Repository search finds only this function reading `PLATFORM_APP_ORIGIN`; example/runbook references are not other consumers. No hosted functions currently exist, so no current hosted function consumer was found. Project-level secrets remain shared: recheck functions and metadata before any write; stop on a new consumer or an existing origin.
- Vercel GETs verified existing project `prj_n03DWya5Gr1uB82qtY084FvsC7q4`, team `team_HozmwrkzbERtyer2nIT25MWv`, Hobby plan, `all_except_custom_domains` protection and READY deployment `dpl_9uerokdducUaR4V35BvDDbyfnqZH`.
- Exact Preview: https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app. No Git branch metadata on this CLI deployment. Do not infer branch-grant behavior for it.
- **External collaborator occupancy and actual grant scope remain NOT VERIFIED.** Current authenticated read-only CLI inspection did not provide that UI evidence. No undocumented access endpoint was invoked. Owner must inspect Deployment Protection → Access/Requests and the deployment Share dialog before approving a named grant. Do not infer an empty slot from project/team metadata.

Initial sandbox reads could not reach local credential services; authorized read-only inspection succeeded with sandbox escalation. Local Supabase help required its normal telemetry-file access; help only, no deploy/secrets command executed. CLI2.115.0 flags were checked; no upgrade performed.

## Approval package 1 — one Development function and one origin

**Not currently authorized.** [Manifest](release/development-onboarding-stage-c-manifest.json) pins exactly three [package files](release/development-onboarding-stage-c-package/supabase/config.toml): minimal function-only config plus byte-identical copies of current `index.ts` and `handler.mjs`. No Auth config, migrations, seeds, frontend, env files, credentials or other functions. Minimal config retains `verify_jwt=true` and explicit entrypoint. Source SDK import remains `npm:@supabase/supabase-js@2.112.4`; remote dependency resolution/bundling has not been exercised by preparation.

Package SHA-256: `1f276731c4f7d4a086850251b15ff92703fc1179e74d739a5a09364fd457bce8`.

Intended sole configuration write:

```text
PLATFORM_APP_ORIGIN=https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app
```

This is server-side project configuration, not Vercel configuration or a VITE variable. The baseline is absence; no current value requires backup. Record only absence/presence, not other secrets. The endpoint is reachable from outside Preview; CORS is a browser control. Existing user validation and database actor/owner/session/fresh-MFA/lease checks remain authoritative, followed by service-only finalization. Never substitute service-role claim, disable JWT verification or loosen CORS to solve runtime incompatibility.

### Exact proposed execution, after approval only

1. Recheck project identity/health, empty functions list, origin absence, approved Preview READY/protection, and Stage B artifacts. A changed baseline requires review. Do not reapply Stage A/B. Inspect source equality and manifest before upload; no whole-repository deployment.
2. Verify the package has exactly the manifest files and SHA256 values. Recompute package SHA256 from sorted `relative_path + TAB + file_sha256 + LF` records and require the digest above. Compare the two copied files with current canonical sources. Stop on drift.
3. From repository root, with existing protected local authentication (never echo tokens), run **only after explicit approval**:

```bash
node_modules/@supabase/cli-linux-x64/bin/supabase secrets set \
  PLATFORM_APP_ORIGIN=https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app \
  --project-ref eqnzueginpkskbnqvgoc

node_modules/@supabase/cli-linux-x64/bin/supabase functions deploy \
  platform-invitation-delivery --project-ref eqnzueginpkskbnqvgoc \
  --workdir docs/release/development-onboarding-stage-c-package --use-api
```

No `--no-verify-jwt`, `--prune`, `--debug`, `--yes`, Auth config push, DB push, frontend deployment or Git operation. `--use-api` requests remote bundling; successful local checks do not prove that bundling works. On failure stop rather than changing flags/SDK/authentication policy.

4. Read back function slug/status/version/entrypoint and `verify_jwt=true`; compare downloaded deployed source to the manifest, accounting explicitly for any provider normalization. Check only intended custom-secret presence/digest against the known non-secret origin, without dumping secret metadata/values. A passing handler OPTIONS response supports correct origin configuration but does not prove private runtime credentials.
5. Run only the non-delivery smoke checks below. Record deployment/readback separately from delivery acceptance.

### Non-delivery smoke checks — prepared, not run against hosted function

```bash
curl --silent --show-error --max-time 20 --request OPTIONS \
  'https://eqnzueginpkskbnqvgoc.supabase.co/functions/v1/platform-invitation-delivery' \
  --header 'Origin: https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app' \
  --header 'Access-Control-Request-Method: POST' \
  --header 'Access-Control-Request-Headers: authorization,apikey,content-type,x-client-info' \
  --dump-header - --output /dev/null

curl --silent --show-error --max-time 20 --request POST \
  'https://eqnzueginpkskbnqvgoc.supabase.co/functions/v1/platform-invitation-delivery' \
  --header 'Origin: https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app' \
  --header 'Content-Type: application/json' --data '{}'
```

OPTIONS: expect handler204 with exact Allow-Origin, Vary: Origin, allowed POST/OPTIONS and expected request headers. A generic gateway response is not handler evidence; inspect headers/status and classify the responding layer. POST has no Authorization, apikey, invitation UUID or recipient; gateway normally rejects missing JWT before handler. Handler-only missing-Bearer result is403/DENIED. Never label gateway401 as proof of handler authorization, and never expect a particular gateway body as the sole pass criterion. No authenticated POST smoke is authorized. No retries that add real credentials or invitation identifiers.

An OPTIONS503/CONFIGURATION_REQUIRED indicates handler configuration failure; missing provider runtime credentials may instead surface during actual authenticated work. Do not introduce a diagnostic endpoint exposing credentials. Presence of all runtime defaults and successful authenticated user/claim/finalization remain deferred to separately authorized runtime verification/Stage D. If gateway JWT compatibility prevents operation, report the observed blocker; retain verify_jwt=true.

### Guarded rollback included in the proposed approval scope

Before deployment, authorize rollback explicitly alongside the forward actions. If function is absent and only origin creation succeeded, remove only the new origin. If function creation succeeded, delete only this newly created function after checking its recorded ID/version/source; then remove only the origin created by this batch. Recheck no new dependent function and no concurrent origin/version change. Stop for review on drift. Commands are **not executed**:

```bash
node_modules/@supabase/cli-linux-x64/bin/supabase functions delete \
  platform-invitation-delivery --project-ref eqnzueginpkskbnqvgoc
node_modules/@supabase/cli-linux-x64/bin/supabase secrets unset \
  PLATFORM_APP_ORIGIN --project-ref eqnzueginpkskbnqvgoc
```

Do not replace/delete unrelated secrets or functions. No DB/template rollback. This restores the baseline function/origin absence only; it cannot undo any later email, session or membership. Those actions are excluded here. Deletion of this batch's function is limited operational rollback, not general deletion permission.

## Approval package 2 — named recipient Preview access

**Not executable yet:** recipient identity is unspecified, Hobby external-user capacity is unverified, actual grant scope for this branchless deployment is unverified. Do not select a recipient or issue a request/invite automatically.

1. Owner supplies the dedicated recipient's Vercel identity privately; no password/token needed. Supabase test mailbox/Company/role/email approval belongs to Stage D.
2. Inspect Deployment Protection → Access/Requests and this exact deployment's Share dialog without granting. Hobby allows one external user per account, so this deployment's empty list alone does not prove capacity. Record only capacity and scope, no other collaborator identities. If occupied, stop; no revocation, upgrade or team membership.
3. Prefer individual sharing scoped to the exact immutable deployment if the actual UI supports it. Select the commit/deployment link instead of the default moving branch link. The CLI deployment has no branch/commit metadata, so do not assume the UI can provide that scope.
4. **Access requests are documented as branch-scoped.** Do not create a request first and silently treat acceptance as deployment-only. If individual access is only branch/project/team scope, document exactly which deployments it exposes and obtain a separate explicit decision. If scope cannot be determined, no grant.
5. After scope/capacity/identity approval, perform only that named individual grant. Prefer approving a request if its scope is approved; creating the request can notify the owner. Direct Vercel invitations send email and require explicit approval for that notification. No Anyone-with-link, bearer links, automation bypass, public exceptions, team additions or protection relaxation.
6. Recipient first opens the ordinary Preview URL and `/auth/callback` without any Auth credential/query, using their own Vercel session. Verify the actual NARVO sign-in/callback application loads through the exact hostname; Vercel login/302 alone is not acceptance. Record safe route/result only. Use this same browser/profile for Stage D email; avoid an unprepared mail in-app browser.
7. Hosting authorization and Supabase authorization are independent. Reauthenticate Vercel on cookie expiry; never start access requests using a credential-bearing invitation URL. No Company access is granted by Vercel access.
8. Prepare removal of only this grant after the controlled test, with exact scope/identity checked and separate authorization. Do not revoke unrelated access or disable protection. No grant was created in this batch, so no access rollback is currently needed.

Provider references inspected for this preparation: [Vercel individual sharing](https://vercel.com/docs/deployments/sharing-deployments), [Vercel branch access requests, Hobby limit and hostname cookies](https://vercel.com/docs/deployment-protection/methods-to-protect-deployments/vercel-authentication), [Supabase runtime defaults and project secrets](https://supabase.com/docs/guides/functions/secrets). Provider capability is not evidence that this recipient currently has access.

## Verification and completion boundaries

New package checks cover exact file set/hashes/source equality, minimal JWT config, unchanged entrypoint user/claim/finish contracts and origin consumers. New local non-delivery checks exercise only OPTIONS, foreign-origin denial and missing-Authorization rejection against packaged handler with all injected ports configured to fail if called. These are local checks, not hosted execution or a repeated financial/security suite. No frontend/runtime source edits, so no full build/lint/regression rerun. Diff whitespace and targeted complete-credential-signature scans cover new artifacts and summary changes. See result for actual counts and limits.

| Category | Classification | Evidence / remaining gate |
| --- | --- | --- |
| Business/accounting | VERIFIED | No business/financial source or data changed; existing invariants preserved by scope. Accounting provisioning remains a later batch. |
| Security/authorization | VERIFIED / DEFERRED | Existing checks retained in byte-identical package and local non-delivery checks; actual hosted JWT/MFA/recipient access remains deferred. No general audit. |
| Database | NOT APPLICABLE | No schema/RLS/grant/migration work. Stage A62-history evidence retained; no fresh alignment/dry-run required for documentation/function preparation. |
| Deployment | VERIFIED / DEFERRED | Fresh read-only identity/absence/protection plus deterministic package verified; upload/bundling/runtime/rollback execution deferred. |
| Testing | VERIFIED / DEFERRED | New local checks and scope checks recorded; hosted delivery, inbox/rendering, password/sign-in/acceptance and Company workspace deferred. |
| Documentation | VERIFIED | Stage C artifacts and current handoff/roadmap pointer distinguish prepared/applied/verified/deferred. Historical evidence retained. |

**Approval request 1:** create only the named Development origin setting and deploy only the SHA-pinned function package, with listed readback/non-delivery checks and guarded rollback; no real invocation/email or recipient access.

**Approval request 2:** after identifying recipient, confirming account capacity and showing actual scope, grant only that named individual's explicitly approved Preview access and verify token-free routes. No blanket grant approval is inferred from this document.

Stage D requires separate approval of exact recipient, dedicated Company, role, record retention and controlled email delivery. No Company/user/membership/invitation creation, Auth link generation or financial posting is authorized here. Invitation acceptance does not provision books or make Super Admin commercially ready.

Subsequent order remains: Stage D → Company accounting preparation → manual subscriptions → Super Admin design → acceptance/closure → original roadmap and urgent/experience improvements → Company Dashboard based on owner's forthcoming reference. Production/Staging, frontend redeployment, backups, Git reset/stash/commit/push/merge and broad audits remain excluded.
