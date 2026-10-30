**Current checkpoint — 2026-10-31:** hosted Development history61 includes all five reviewed Platform migrations; latest20/20 postflight passed. The owner reports approximately one hour of real Platform Owner navigation without repeated MFA prompts: sustained browsing PASS. Invitation end-to-end acceptance, sensitive-operation real-session MFA/reconfirmation testing and Vercel deployment acceptance remain PENDING. Existing public site unchanged; no deployment or push is authorized in this local release-commit batch. Independent disaster recovery remains incomplete and owner-managed. Earlier four-migration/initial-MFA instructions below are historical preparation; use the current activation checklist.

# Existing application release preparation

The approved application is the existing Vercel project at `https://maker-eosin.vercel.app`; its Platform Owner route is `/platform`. No new project, custom domain or permanent Preview hostname is needed. This directory is deliberately not root `vercel.json`; existing deployments are not automatically reconfigured. No deployment has been created. Database activation and all mandatory release gates must succeed first. Recovery arrangements are owner-managed; perform no related operations. SMTP transport and the exact four-migration linked dry-run are now owner-verified; neither implies database activation or new-recipient invitation acceptance. See the single [execution checklist](../docs/PLATFORM_ACTIVATION_EXECUTION.md).

Use a temporary Preview in the SAME existing project only if needed for safe validation after database activation. Confirm account/project identity and deployment protection for that Preview. A temporary Preview must use its own exact approved callback/CORS configuration during testing; final delivery origin remains `https://maker-eosin.vercel.app`. Do not create another application or broad redirect wildcard. Vercel protection supplements Supabase authentication/MFA/RLS.

Use the existing architecture and browser-safe Supabase configuration from the [email/environment runbook](../supabase/templates/README.md). If using Preview, set the three browser-safe variables in Preview scope only. Verify actual project/environment identity before upload. This preparation does not run `--prod`, promote an alias, change the live deployment, or commit/push. Eventual use of the approved public route still requires database/compatibility/security gates and verified release behavior. No authenticated Vercel deployment access has been verified in this execution.

Only if Preview validation is necessary, after all gates, with an authorized installed Vercel CLI and verified existing-project selection, the prepared explicit-config invocation is:

```sh
vercel --local-config deploy/platform-preview.vercel.json
```

Do not deploy prebuilt synthetic `dist`; rebuild using the verified existing-application environment (or Preview scope only for an optional temporary Preview). Audit the emitted Auth bundle for fixture imports/private credentials and confirm real project URL. Verify deep requests to `/platform`, `/platform/entities` and `/auth/callback`, exact redirect/CORS origin and server-only function configuration. The supplied SPA rewrite and callback response headers are preparation; actual hosted routing/header/cache behavior remains unverified. Configure callback-query log redaction at the hosting/logging layer; response headers alone cannot redact access logs.

Owner then signs in normally, scans the real QR locally and enters a real TOTP in the protected browser. Do not put QR screenshots/seeds, codes, tokens or callback URLs in evidence. Require fresh AAL2 and no financial Company access. Hosted test users/Companies, invitations and changes to existing memberships still require the explicit acceptance-fixture allowlist. No arbitrary test financial postings.

Official references: [Vite SPA deep linking](https://vercel.com/docs/frameworks/frontend/vite), [Preview deployment protection](https://vercel.com/docs/deployment-protection). This file does not enable account-level protection or publish the existing application.
