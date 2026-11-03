**Stage C delivery activation — 2026-11-01: DEVELOPMENT VERIFIED / RECIPIENT ACCESS AND STAGE D PENDING.** Tested Vary-only parser fix passes13/13 local cases and syntax checks; other CORS assertions, source and metadata verifier unchanged. Fresh guards passed; one approved origin set and one unchanged function deployment reached ACTIVE v1/JWT enabled (ID59414c7a-6baf-476d-8a7b-376783404b76). Downloaded source hashes, all secret digests/user-managed metadata and full Auth settings preserved; only allowlisted provider timestamps refreshed. Hosted handler OPTIONS204/exact origin/CORS and gateway unauthenticated POST401 both pass; final function stable, no rollback. No email, records, financial, frontend/Vercel, Production, Git or recipient-access operations. [Actual activation and remaining access requirements](PLATFORM_ONBOARDING_STAGE_C_DELIVERY_ACTIVATION.md); [execution evidence](release/development-onboarding-stage-c-vary-activation-result.json). Delivery activation is bounded Development evidence, not real-recipient acceptance or commercial readiness. Earlier rollback/preparation labels remain historical.

# Stage C — one conditional Development retry result

Closure 2026-11-01 (Dubai). The authorized deployment and rollback ran on2026-10-31 at23:59 Dubai /19:59 UTC. **RETRY ROLLED BACK / DELIVERY ACTIVATION INCOMPLETE.** No further deployment attempted.

[Secret-free execution evidence](release/development-onboarding-stage-c-retry-result.json). The first attempt and metadata investigation records remain unchanged.

## Deployment and preservation evidence

- Fresh exact Development identity/health, no functions/origin, approved package and corrected-verifier hashes, seven stable provider digests, full Auth/Stage B equality and existing Preview protection all passed. Exactly three approved files were staged privately outside the repository.
- One origin set and one `platform-invitation-delivery` deployment succeeded on `eqnzueginpkskbnqvgoc`. Function ID `92bdb3cd-3137-4115-859f-e560c38bd309`, version1, ACTIVE, `verify_jwt=true`; recorded entrypoint matched this function. Both downloaded source files matched the unchanged approved hashes.
- Corrected metadata comparison passed immediately before writing, after origin set, after deployment and after rollback. All seven provider digests were preserved. All seven timestamps changed together from `2026-10-31T19:41:12.943Z` to `2026-10-31T19:59:22.761Z`; no other user-managed setting changed. This retry directly demonstrates timestamp-only provider refresh, without asserting that it recovers the first attempt's discarded historical before-records.
- Exact approved origin was verified by the corrected digest comparison. Full Auth configuration, including Stage B/templates/SMTP, remained equal to preflight throughout the guarded checks and final rollback. No database commands, migrations, financial operations or business-record mutations occurred.

## Hosted smoke result and exact failure

Only the documented OPTIONS probe was sent, with the approved origin and no credentials or invitation identifier. It returned:

```text
HTTP 204
Access-Control-Allow-Origin: https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app
Access-Control-Allow-Methods: POST, OPTIONS
Access-Control-Allow-Headers: authorization, apikey, content-type, x-client-info
Cache-Control: no-store
Vary: Accept-Encoding, Origin
```

The body was empty. Exact Allow-Origin, status/body and deployed-source checks passed. The operator verifier then failed at this condition:

```python
headers.get('vary') == 'Origin' and headers.get('cache-control') == 'no-store'
```

Cache-Control matched. The full-string Vary comparison did not. **This was an avoidable verification-procedure defect, not an established application CORS defect.** [RFC9110 §12.5.5](https://www.rfc-editor.org/rfc/rfc9110.html#section-12.5.5) defines Vary as a list of field names. `Accept-Encoding, Origin` legitimately contains Origin. The exact intermediary that added Accept-Encoding was not investigated or assumed.

The unauthenticated POST was **NOT EXECUTED** because authorization required stopping at a failed check. No gateway missing-JWT rejection, authenticated user/MFA/claim/finish or email delivery is claimed tested. No endpoint capable of invitation reservation, Auth-user creation or email delivery was invoked.

Required local verification correction before any future approved attempt: parse all Vary header lines as comma-separated, case-insensitive field-name tokens and require the Origin token, retaining exact Allow-Origin, no-store, status/body and method/header requirements. For example:

```python
vary_tokens = {
    token.strip().lower()
    for value in response.headers.get_all('Vary', [])
    for token in value.split(',')
}
assert 'origin' in vary_tokens
```

This report prepares the correction; it does not change the running function or authorize another deployment. A local parse of the recorded response confirms Origin is present. The failed execution record is preserved and is not relabeled as a complete passing smoke run.

## Authorized guarded rollback

The failed check triggered exactly the documented rollback. Current function ID/version/update marker and byte-identical downloaded source matched this attempt; no other functions existed. The function was deleted once. The still-matching new origin was then unset once. Final reads confirmed function/origin absence, provider digest preservation and full Auth equality. Provider defaults were not deleted or rewritten. Total hosted mutation commands: one origin set, one deploy, one scoped delete and one origin unset. Only one HTTP function probe occurred. No second deployment retry.

## Final readiness and remaining access work

| Category | Result |
| --- | --- |
| Business/accounting | VERIFIED: scope preserved; no financial behavior/data mutation. |
| Security/authorization | VERIFIED: source integrity, JWT metadata, strict secret digests/user-managed configuration and full Auth preservation. DEFERRED: live missing-JWT rejection and authenticated MFA/claim/finish. |
| Database | NOT APPLICABLE: no schema/migrations/RLS/grants/data writes; no unrelated DB audit or migration rerun. |
| Deployment | VERIFIED: successful bounded deployment and guarded rollback. Activation INCOMPLETE; function/origin absent. |
| Testing | VERIFIED: recorded OPTIONS response and corrected metadata/source/readback checks. FAILED: exact-string Vary guard. DEFERRED: unauthenticated POST and full onboarding. Full build/regression NOT APPLICABLE to unchanged source. |
| Documentation | VERIFIED: actual outcome/limits recorded, previous evidence retained, no manufactured pass. |

Remaining recipient requirements are unchanged: specify the independent Vercel recipient identity, verify the Hobby external-collaborator slot and actual deployment/branch grant scope, obtain separate access approval, then prove token-free ordinary Preview and callback access in the intended recipient browser. No grant or Vercel protection change occurred. Any later deployment needs separate authorization; Stage D also needs separate recipient/Company/role/email approval. No customer accounting setup or commercial readiness is claimed.

Production/Staging, frontend/Vercel settings, Stage A/B, templates/SMTP, users/Companies/memberships/invitations, email/Auth links, financial data, Git commit/push/merge and Stage D remained outside execution and were not changed. Existing uncommitted work and the approved package are preserved.
