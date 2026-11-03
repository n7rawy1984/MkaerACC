# Development Preview invitation origin alignment

2026-11-01. **VERIFIED — Development only**, project `eqnzueginpkskbnqvgoc`. Owner authorized permitting the new UI Preview while retaining the previous Preview. [Secret-free execution evidence](release/development-preview-invitation-origin-result.json).

## Exact mismatch and change

The previous handler admitted only `PLATFORM_APP_ORIGIN`. Its canonical value remains **unchanged**:

```text
PLATFORM_APP_ORIGIN=https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app
```

Added one server-only project setting, consumed only by the sole hosted invitation function:

```text
PLATFORM_INVITATION_ADDITIONAL_ORIGINS=["https://maker-9eixk2rgu-n7rawy1984-8059s-projects.vercel.app"]
```

The handler now builds an exact origin set from the canonical origin plus the optional JSON array. It returns the matching single origin for approved requests, retains `Vary: Origin`/no-store and the existing allowed methods/headers, and rejects unlisted origins. Invalid configuration, wildcard origins, non-HTTPS URLs, paths, credentials, queries and fragments fail closed. With no additional setting, the previous single-origin behavior remains. Invitation callback URLs still use the unchanged canonical origin; no Auth redirect configuration or recipient-access grant was changed.

Because the original code supported only one origin, this required **one Edge Function code deployment**, not a frontend deployment. Changed `handler.mjs`, `index.ts` and the non-secret `.env.example`; added `scripts/verify-platform-invitation-origins.mjs`. The isolated deployed package contained only index, handler and minimal JWT-enabled function configuration.

## Guards and version evidence

Fresh healthy Development identity and sole function inventory passed. Downloaded original source matched the accepted v1 hashes. Original authorize/claim/deliver/finish/callback code and entrypoint Auth/DB ports remain byte-identical, apart from wiring the optional configuration. Existing full Auth fingerprint, every existing secret digest, and user-managed metadata remained exact; only explicitly recognized provider timestamps may refresh. No RLS/grant/schema or rate-limit/lease/idempotency contract was changed.

The single setting update incremented function metadata from v1 to v2, causing the original full-record equality guard to stop **before any code deployment**. Readback established that **only version changed**; downloaded code remained byte-identical to original v1, with stable ID/JWT/status and preserved Auth/digests. After exact stable rechecks, execution continued with the **first and only code deployment**, reaching **ACTIVE v3**, ID `59414c7a-6baf-476d-8a7b-376783404b76`, `verify_jwt=true`. The setting command was not repeated. Source downloaded after deployment matches the tested manifest. No function was deleted and no rollback was needed.

[Supabase documents immediate secret propagation](https://supabase.com/docs/guides/functions/secrets) without needing a source redeployment. The version-only increment here is an observed, source-verified provider configuration refresh; the docs are not cited as explicitly promising that exact metadata increment.

## Executed verification

| Check | Result |
| --- | --- |
| New Preview OPTIONS |204, empty body, exact new Allow-Origin, original methods/headers, no-store and Origin in Vary |
| Previous Preview OPTIONS |204, empty body, exact old Allow-Origin, same strict CORS |
| Unknown origin OPTIONS |403 DENIED; unknown origin not echoed as allowed |
| Anonymous new Preview POST `{}` |401 Missing authorization header, JWT gateway |
| Anonymous old Preview POST `{}` |401 Missing authorization header, JWT gateway |
| New focused local origin/auth/callback tests |63 assertions PASS; synthetic ports only |
| Existing delivery-contract tests |21 base assertions PASS, plus existing stale-MFA and existing-identity checks |
| JS/TS syntax, focused Oxlint, diff checks |PASS |

All five hosted probes contained no credentials or invitation identifier and could not reach an authenticated delivery claim. The provider gateway401 has its own generic CORS headers; it is distinct from handler-level strict exact-origin OPTIONS behavior. No authenticated POST, email, invitation creation or mutation test was performed. Previous invitation/onboarding/MFA/accounting/subscription evidence is preserved, not rerun.

## Completion and limits

Business/financial boundaries **VERIFIED** through unchanged protected code and no business writes; live email delivery **DEFERRED by task constraint**. Authorization **VERIFIED** for preserved guards/source/JWT and anonymous rejection. Database changes **NOT APPLICABLE**. Deployment **VERIFIED** for this one Development Edge update; Production/Vercel/frontend untouched. Testing **VERIFIED** within non-delivery scope. Documentation **VERIFIED**.

The new Preview's invitation-origin blocker is resolved. Both approved Previews may call the same protected function. Canonical callback routing and existing Preview recipient-access requirements remain as previously configured; this change does not grant external Preview access or prove a new real-email journey. No commit/push/merge, migration, customer/subscription/membership/financial mutation, frontend deployment, Production or Auth change occurred. Stop after this verification.
