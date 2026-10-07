# Development first-platform-admin bootstrap — bounded checkpoint

2026-10-07. Development only; no real administrator elevated, Company provisioned or accounting records created.

## Architecture and identity decision

`private.system_administrators` keys an existing Auth UUID and records ACTIVE/INACTIVE status plus creation/update provenance. Its Auth FK is restrictive. Browser roles have no private-schema access. P2 already grants trusted service-role administration SELECT/INSERT/UPDATE, withholding DELETE. `profiles.user_id` references Auth; bootstrap requires both target and executing operator to have existing ACTIVE profiles. That FK establishes Auth existence without broadening access to `auth.users` (service_role has no SELECT there).

Company SYSTEM_ADMIN is a separate membership role, not private platform registration. `is_company_member`, `has_company_role` and `has_permission` require active profile + explicit active membership + active Company; they do not consult the private platform registry. Thus an existing Company user **can technically hold both identities** without receiving additional accounting permissions or automatic memberships. No exclusivity constraint or rule currently mandates separate identities. This checkpoint does not invent one.

**Recommend a dedicated operator Auth identity**, with no routine Company accounting membership, to reduce credential reuse and mistakes during protected platform work. Same identity is supported if explicitly approved; normal Company role restrictions remain. The tooling never creates/invites users or memberships and never chooses or elevates a user automatically.

MFA and session freshness are **operational requirements**, not automatically enforced by the current browser, registry or SQL. P2 documents protected Supabase operator administration until a trusted endpoint exists. First bootstrap cannot require an already registered platform admin: the authorized protected Development operator must verify identity, MFA and fresh administrative session out of band. Caller-supplied UUIDs provide provenance, not login proof; `--operator-session-verified` is an attestation, not an authentication mechanism. A normal browser session, Company role or localStorage cannot authorize execution. P7 immutable platform audit events/production readiness remain deferred.

## Smallest tooling added

`scripts/admin/bootstrap-development-platform-admin.mjs` generates a reviewed transaction and optionally executes it via the protected Supabase CLI only with explicit `--apply`. CLI generation refuses a repository linked to any project other than MakerACC-Development (`eqnzueginpkskbnqvgoc`); execution also pins that exact project ref rather than accepting a target URL/ref. No SQL RPC, browser UI, migration, RLS or grant changes.

The transaction requires `postgres` or `service_role`, locks a fixed transaction-scoped advisory key to serialize first-bootstrap calls, rejects an existing ACTIVE administrator, rejects any prior target registry history instead of reactivating it, locks/verifies ACTIVE profiles and inserts exactly one ACTIVE registry row with supplied operator attribution. Duplicate bootstrap fails clearly; no upsert, replacement, role edits or accounting effects. Further administrators/reactivation are outside this first-bootstrap tool.

Raw generated SQL is not independently environment-aware. Keep it outside Git under operator control and use the guarded CLI; do not paste it into another environment. Trusted database administration is inherently privileged, and these controls are not a sandbox against a malicious database owner.

## Exact user/operator inputs

Supply two existing verified Auth UUIDs, and explicitly authorize the target identity:

- `platform_admin_user_id`: intended first Development platform operator, preferably dedicated.
- `operator_user_id`: identity of the authorized protected operator performing this bootstrap; may equal the target if explicitly approved. It must also have an ACTIVE profile.

No passwords, credentials, tokens, keys, new profile fields, Company role, Company ID, currency or business identity values are accepted. Profile UUID equals Auth UUID; status is fixed ACTIVE; timestamps use existing schema defaults. The actual executing operator must confirm MFA and fresh session in protected administration before using the verification flag. If choosing a dedicated identity that does not exist, protected Auth invitation/creation is a separate explicit step; this tool does not perform it.

Review-only preparation (no database connection):

```sh
node scripts/admin/bootstrap-development-platform-admin.mjs /protected/bootstrap-input.json /protected/bootstrap-preview.sql --operator-session-verified --rollback
```

Owner-only output, exclusive creation; overwrite refused. After reviewing input, SQL and target, an explicitly authorized operator can use a **new output path** with `--apply --rollback` for rehearsal. A real approved bootstrap requires a new output path with `--apply` and no rollback flag. This checkpoint **did not execute apply or a committed bootstrap**. Never supply the verification flag until the out-of-band operational checks actually pass. No first identity has been designated or approved yet.

## Focused verification performed

- 16 generator checks: exact Development target, verified-session attestation, UUID validation/injection rejection, unsupported fields, rollback/commit generation and absence of public inserts or mutation/grant commands.
- CLI preview checks: missing verification flag rejected; preview produces rollback SQL without database execution; file mode 0600; existing output refused. No `--apply` executed.
- Development hosted rollback-only matrix passed: service_role bootstrap works using existing grants; ACCOUNTING_ADMIN, MANAGEMENT_VIEWER and Company SYSTEM_ADMIN cannot invoke the procedure or directly insert the registry; nonexistent operator/target and inactive profile rejected; one ACTIVE row has correct provenance; duplicate/second bootstrap and inactive registry history rejected; Company SYSTEM_ADMIN remains denied accounting.view/post after registration; registered identity without active memberships sees no Company and has no accounting permission.
- Company identity snapshot (including V1-DEMO-20260929), all membership identity links and journal-history checksums remained unchanged. Temporary role/profile/registry changes for verification were rolled back. No cross-tenant membership or accounting record was created by bootstrap. No Company fixture was created. The test uses only the existing synthetic demo member inside a rollback transaction; this does **not** select that identity for real elevation.
- Post-rollback read verified zero ACTIVE platform administrators and no authenticated private-schema access. No Staging/Production calls, financial-module audit, broad tests or frontend change. Syntax/lint/diff and focused secret checks pass. EN/AR/RTL/build are NOT APPLICABLE to this operator-only Node tooling.

## Readiness and remaining blocker

Tooling is ready for protected Development use, but **real bootstrap remains unexecuted**. User must choose/approve the first operator identity and provenance identity, ensure ACTIVE Auth/profile and complete operational MFA/session checks. There is still no ACTIVE Development private administrator, so real Company provisioning remains blocked. Company provisioning, real master onboarding, imports and Production readiness are separate future authorized actions.

Definition of Done: business/accounting boundary VERIFIED (registry only, zero accounting effect); focused security and existing grants VERIFIED, operational MFA responsibility retained and automatic endpoint/P7 audit DEFERRED; database rollback evidence VERIFIED, migration NOT APPLICABLE; Development target guards VERIFIED, production deployment NOT APPLICABLE; focused tests VERIFIED, real operator bootstrap DEFERRED; documentation VERIFIED. No actual identity elevation, real Company, XLSX import, business records or schema/migration/RLS changes. Implementation performed no commit or push.

## Authorized checkpoint closure

Closed in exactly one local commit, `Add development platform admin bootstrap`; no push. Final diff contains only the Development bootstrap tool, its focused verification script, this record and the current handoff/roadmap updates (five files). Closure reconciled documentation and reviewed the final diff without rerunning tests, bootstrapping any administrator, provisioning a Company or performing hosted actions. Real identity approval and operational MFA/session checks remain prerequisites; actual bootstrap and Company provisioning are deferred.
