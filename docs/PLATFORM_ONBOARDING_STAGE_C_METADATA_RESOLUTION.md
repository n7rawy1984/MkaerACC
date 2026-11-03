**Stage C delivery activation — 2026-11-01: DEVELOPMENT VERIFIED / RECIPIENT ACCESS AND STAGE D PENDING.** Tested Vary-only parser fix passes13/13 local cases and syntax checks; other CORS assertions, source and metadata verifier unchanged. Fresh guards passed; one approved origin set and one unchanged function deployment reached ACTIVE v1/JWT enabled (ID59414c7a-6baf-476d-8a7b-376783404b76). Downloaded source hashes, all secret digests/user-managed metadata and full Auth settings preserved; only allowlisted provider timestamps refreshed. Hosted handler OPTIONS204/exact origin/CORS and gateway unauthenticated POST401 both pass; final function stable, no rollback. No email, records, financial, frontend/Vercel, Production, Git or recipient-access operations. [Actual activation and remaining access requirements](PLATFORM_ONBOARDING_STAGE_C_DELIVERY_ACTIVATION.md); [execution evidence](release/development-onboarding-stage-c-vary-activation-result.json). Delivery activation is bounded Development evidence, not real-recipient acceptance or commercial readiness. Earlier rollback/preparation labels remain historical.

**Stage C conditional retry — closure 2026-11-01: ROLLED BACK / ACTIVATION INCOMPLETE.** One authorized Development deployment reached ACTIVE v1 with exact source/JWT/origin; corrected metadata verification passed (all seven default digests unchanged, timestamps refreshed). OPTIONS returned204 with exact approved origin/method/header/no-store and `Vary: Accept-Encoding, Origin`; the operator verifier incorrectly required full-string `Vary: Origin`, triggering the authorized guarded rollback. New function and origin are absent; full Auth and secret digests preserved. Unauthenticated POST was not executed. No further retry, delivery/email, records, financial, frontend/Vercel, Production or Git actions. [Exact result and required Vary-token correction](PLATFORM_ONBOARDING_STAGE_C_RETRY.md); [execution evidence](release/development-onboarding-stage-c-retry-result.json). Recipient access/Stage D remain separately approved future work; commercial readiness is not claimed. Earlier preparation/activation descriptions remain historical.

# Stage C — runtime metadata blocker resolution

2026-10-31. **TARGETED INVESTIGATION COMPLETE / CORRECTED RETRY PREPARED / NO DEPLOYMENT.** Hosted activity in this batch was GET-only against Development `eqnzueginpkskbnqvgoc`. No function invocation, secrets/Auth write, data mutation, Vercel operation or Git delivery.

## Root cause and evidence boundary

The verification guard, not a demonstrated function defect, blocked the first activation. The guard hashed the complete `/secrets` response after removing only `PLATFORM_APP_ORIGIN` and required equality to one preflight aggregate hash. That response includes Supabase-managed runtime entries, their `updated_at` fields and list order. It was incorrectly treated as a stable inventory of exclusively user-managed configuration. The initial separate `digest`/`value` field-name bug was already diagnosed before deployment; it was not the final rollback trigger.

The approved first deployment actually reached ACTIVE/version1 with JWT enabled; both downloaded source files matched the approved hashes and the origin digest was correct. The guard stopped before non-delivery smoke. The documented rollback then removed only the new function/origin; Auth matched its preflight fingerprint throughout. Those historical results remain intact in [the first activation evidence](release/development-onboarding-stage-c-activation-result.json).

**Historical field-by-field attribution cannot be recovered exactly.** The original preflight retained only aggregate secret-metadata SHA256 `0797e7ef03eb8702e640aa4b63ae8374003d9e3d72991aa85927d74303e5f66a`, not entry names, digests or timestamps. The failed diagnostic removed six presumed additions, then unsuccessfully compared the remaining metadata to that aggregate. It does not prove that only `SUPABASE_DB_URL` changed, nor whether its old digest or timestamp changed. A search of55 retained local JSON evidence files found no raw before-metadata snapshot. Testing only public null/empty/epoch/project-creation timestamp substitutions with current DB_URL metadata did not reconstruct the historical hash. No credentials were guessed, retrieved for comparison, printed or modified.

Therefore earlier language saying all six names were definitively added by deployment should be read as an inference, not a proved field-level delta. The same evidence cannot distinguish backend creation from previously existing default metadata becoming visible. No actual credential rotation, unexpected user-managed configuration write or authorization defect has been established.

## Exact entries observed after deployment and now

All seven records below currently have `updated_at=2026-10-31T19:41:12.943Z`; the first function's creation marker was `2026-10-31T19:41:12.944Z`, one millisecond later. All names, digest fingerprints and timestamps match across consecutive read-only GETs, and the corrected comparator also passed a second pair. No user-managed entries are currently present; the function and origin remain absent. Full Auth fingerprint still equals the first activation's preflight.

| Entry | Evidence-based classification |
| --- | --- |
| `SUPABASE_DB_URL` | Documented provider default; deployment-time metadata timestamp. Its exact historical before-record is unavailable; a specific field change is unproved. |
| `SUPABASE_URL` | Documented provider default, observed absent in earlier preparation metadata checks and present after deployment. Initialization or increased visibility is supported; backend mechanism is not exposed. |
| `SUPABASE_ANON_KEY` | Same as URL; legacy provider default. |
| `SUPABASE_SERVICE_ROLE_KEY` | Same as URL; legacy provider default. No secret value was inspected or emitted. |
| `SUPABASE_PUBLISHABLE_KEYS` | Documented provider dictionary; present after deployment, with the same initialization-time timestamp. Historical presence was not individually recorded. |
| `SUPABASE_SECRET_KEYS` | Documented provider dictionary; same historical visibility limitation. |
| `SUPABASE_JWKS` | Documented provider default; same historical visibility limitation. |

`PLATFORM_APP_ORIGIN` was the sole approved user-managed addition and was removed by rollback. The earlier activation proved its API `value` equalled SHA256 of the exact approved non-secret origin. It is not an unexplained metadata change.

**Classification:** the named entries and deployment-time population/visibility are consistent with expected provider-managed initialization; this is a supported inference, not proof of the backend's exact creation path. No evidence supports genuinely unexpected user-managed configuration changes. The guard was overly strict about provider-managed inventory/timestamps and insufficiently informative about which entry differed.

## Official support and limits

- [Supabase runtime defaults](https://supabase.com/docs/guides/functions/secrets) documents these seven names and reserves `SUPABASE_` for injected variables. It does not promise stable `updated_at` fields or a first-deployment metadata visibility lifecycle.
- [Management API list-secrets schema](https://supabase.com/docs/reference/api/v1-list-all-secrets) uses `name`, `value`, `updated_at`; it does not define a separate `digest` field or guarantee array order.
- [Official CLI source, v2.75.0](https://github.com/supabase/cli/blob/v2.75.0/internal/secrets/list/list.go) calls the operation `GetSecretDigests`, displays API `Value` under DIGEST and sorts rows by name. This is historical primary-source corroboration of the API convention, not a claim that the installed2.115.0 binary uses that exact source file. The first activation's exact known-origin digest comparison independently confirms the convention in this project.

These sources validate provider ownership and API interpretation. They do not recover the discarded before-records or prove runtime credentials have been successfully consumed. Metadata presence is not a live email/MFA/claim/finish test.

## Minimal correction

Local-only helper: [platform-invitation-secret-metadata.mjs](../scripts/platform-invitation-secret-metadata.mjs). Local validation: [verify-platform-invitation-secret-metadata.mjs](../scripts/verify-platform-invitation-secret-metadata.mjs).

The second attempt must begin with all seven already-initialized documented defaults present, no origin, no hosted functions and a healthy exact Development identity. No initial-population exception is needed now.

1. Convert raw API metadata in memory into a map keyed by name. Require the exact reviewed schema and a64-character hex digest in API `value`. Reject duplicates, missing required defaults and unreviewed `SUPABASE_*` names.
2. Persist safe per-entry before-evidence: name/kind, timestamp, SHA256 of the API digest, and full-record fingerprint. Never persist API `value`, credential values or complete raw API responses. Record an inventory of names, not only an aggregate hash.
3. Compare name sets regardless of response order. Require every preexisting default digest to remain identical. Allow only timestamp changes for the seven explicitly named provider defaults and record exactly which names changed timestamps. A default digest change or disappearance still stops verification; no blanket `SUPABASE_*` exclusion.
4. Require full-record equality for every unrelated user-managed entry, including its digest, timestamp and schema. New/deleted/changed entries fail. An empty user-managed baseline does not authorize future additions.
5. Permit only the approved origin addition, with exact double-hash comparison to its known value; require its absence again after rollback. Baseline origin presence is a stop condition, never implicit overwrite authorization.
6. Keep all independent package/source/JWT/actor/MFA/claim/finish, exact full-Auth preservation, tenant/data boundaries and non-delivery smoke requirements. The helper replaces only the aggregate secret-metadata comparison. It does not authorize or perform any hosted mutation.

The helper trusts only snapshots it captured within the same approved execution. Keep those local artifacts under operator control; they are evidence, not remotely supplied authorization. No generic secrets administration or new financial abstraction is introduced.

## Safe second attempt — requires new explicit approval

**GO to request one narrowly scoped retry; NOT authorization to deploy now.** Safety is conditional on fresh guards, not on a claim that the historical metadata delta was fully recovered.

1. Capture fresh identity/health, functions list and two metadata reads. Require no functions, no origin, all seven provider entries, unchanged per-entry digests across reads and the corrected comparison passing. Record full Auth fingerprint and verify exact accepted Stage B fields. Stop on unexplained drift; do not reapply Stage A/B.
2. Verify the same accepted package digest `1f276731c4f7d4a086850251b15ff92703fc1179e74d739a5a09364fd457bce8` and canonical source equality. Stage only its three manifest files into a fresh private `/tmp/narvo-stage-c-retry/source` directory, preserving relative paths. Reject existing unexpected files. Do not copy credentials, Auth config, migrations, other functions or the dirty repository. Readback downloads go to another private directory, never over canonical source.
3. Record safe per-entry baseline snapshots using the helper and a full Auth fingerprint. Before the first write require origin absent and no other function consumers. After each step use fresh readback; never downgrade a failed preservation check to success.
4. After separate approval, execute from repository root:

```bash
node_modules/@supabase/cli-linux-x64/bin/supabase secrets set \
  PLATFORM_APP_ORIGIN=https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app \
  --project-ref eqnzueginpkskbnqvgoc

node_modules/@supabase/cli-linux-x64/bin/supabase functions deploy \
  platform-invitation-delivery --project-ref eqnzueginpkskbnqvgoc \
  --workdir /tmp/narvo-stage-c-retry/source --use-api
```

Use reviewed installed CLI2.115.0, no upgrade or policy/flag workaround. Recheck exact source-file hashes, preserve `verify_jwt=true`, and record the newly returned function ID/version/update marker; do not assume another version1 or reuse the deleted ID.

5. After origin set and after deployment compare fresh snapshots with `verifySecretMetadata(before, after, { originState: 'present' })`. Persist the per-name result. Require exact full Auth fingerprint equality. Read back ACTIVE/JWT metadata; download function source and require the same two file hashes. Record actual entrypoint and ensure it is this function. No authenticated invocation.
6. Run the original documented OPTIONS request with the exact Preview origin, then POST `{}` with no Authorization/apikey/UUID. Require handler204/exact origin/Vary/method/header/no-store contract and distinguish gateway missing-JWT401 from handler403. Do not force a pass from a different response layer. Failure cannot authorize JWT/CORS/source changes. Stop and use the guarded rollback as appropriate.
7. Require stable final ID/version/JWT/source, exact origin, complete user-managed preservation, unchanged provider digests and full Auth equality. Report provider timestamp changes separately. Record actual smoke statuses; no email, claim or finish test. Stop after verification.

### Rollback conditions and guards

- An origin-write/deploy failure, wrong target/source/version/JWT, origin mismatch, unexpected managed configuration change, provider digest/name change, Auth drift, or failed/inconclusive smoke prevents acceptance. Preserve evidence first. Never automatically restore unrelated configuration.
- If only the origin was created, remove only that new origin, after checking absence-before, its current exact digest and no new function consumers.
- If the function was deployed, delete only this attempt's function after matching its captured ID/version/update marker/source and ensuring no concurrent replacement; then unset only its still-matching new origin. Never delete based on slug alone when ID/version drift exists.
- Stop for review if those guards cannot establish ownership or concurrent drift is present. Do not overwrite another operator's changes to make rollback pass.
- Verify final function/origin absence, unchanged full Auth configuration and corrected metadata comparison with `{ originState: 'absent' }`. Leave all provider defaults untouched. Record any remaining differences; rollback does not imply exact provider timestamps were restored.

```bash
node_modules/@supabase/cli-linux-x64/bin/supabase functions delete \
  platform-invitation-delivery --project-ref eqnzueginpkskbnqvgoc
node_modules/@supabase/cli-linux-x64/bin/supabase secrets unset \
  PLATFORM_APP_ORIGIN --project-ref eqnzueginpkskbnqvgoc
```

**Exact approval requested for a later turn:** one Development-only origin set and one deployment of the unchanged three-file SHA-pinned function, using the corrected comparator and private allowlisted staging; readback/download and only the two non-delivery probes; guarded deletion/unset of this attempt on failure. No redeployment, access grants or other writes are included in this investigation's current authorization. Production/Staging, Vercel/frontend, Stage A/B changes, data/financial mutations, records, real invitations/email, recipient access and Git delivery remain excluded. Stage D stays separate.

## Verification and Definition of Done

19/19 targeted local tests pass: approved origin, reordered responses, timestamp-only provider change, strict user-managed timestamp/digest changes, default digest changes, additions/removals, unknown provider names, schema changes, invalid digests, duplicates, wrong/missing origin, rollback absence, origin baseline drift, explicit phase and safe snapshot shape. Node syntax checks and project Oxlint on the two new scripts pass. An initial ESLint invocation was unavailable; package.json uses Oxlint, which was then run successfully. No full build or prior regression/security suite was repeated. Read-only current metadata comparison passed using the corrected helper; no hosted smoke or deploy occurred.

| Category | Classification |
| --- | --- |
| Business/accounting | VERIFIED: no financial behavior/data changes. |
| Security/authorization | VERIFIED: narrowly scoped metadata checks strengthened; no source/JWT/MFA/Auth boundary changes. Actual hosted rejection/delivery remains DEFERRED. |
| Database | NOT APPLICABLE: no schema, migrations, grants, RLS or data writes. |
| Deployment | VERIFIED: read-only absence/default stability/Auth preservation; second activation and smoke DEFERRED. |
| Testing | VERIFIED:19 local cases, syntax, targeted Oxlint and read-only comparator. Historical exact field-level reconstruction unavailable; runtime acceptance DEFERRED. |
| Documentation | VERIFIED: evidence limits, correction and exact conditional retry/rollback scope recorded. Previous execution evidence is preserved. |

Function remains absent and delivery inactive. Commercial readiness, recipient access and Stage D are not claimed.
