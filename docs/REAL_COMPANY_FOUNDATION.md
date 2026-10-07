# Real Company foundation — bounded checkpoint (2026-10-07)

## Existing boundary and gap

Company creation is trusted operator provisioning, not an ACCOUNTING_ADMIN or Company-membership SYSTEM_ADMIN browser permission. P2 service-role grants permit protected administration; browser INSERT to Companies, memberships and settings remains denied. `private.system_administrators` is the platform authority. Same-Company SYSTEM_ADMIN grants configuration/user permissions only; no accounting bypass. Existing authenticated Company selection loads ACTIVE profile, memberships and Companies; selected preferences never replace RLS.

The missing operational component was a reviewed atomic Company + settings + first membership procedure. `scripts/admin/provision-company.mjs` now generates that transaction for a trusted operator connection. It never connects to a database. It requires an ACTIVE registered platform operator with an ACTIVE profile, and an existing ACTIVE initial administrator profile. The initial membership is fixed to ACTIVE ACCOUNTING_ADMIN. It creates a fresh UUID; no update, copy, upsert or reuse of an existing Company. Duplicate case-insensitive code or unique slug fails the whole transaction. No Company, role, RLS, grant, RPC or schema migration added.

## Operator procedure

1. Confirm the authorized operator's identity, operational MFA and fresh protected administration session. Verify the target is MakerACC-Development for current onboarding; Staging/Production require separate authorization. The supplied operator UUID is an attribution/check against the private registry, **not proof of login**. This procedure is usable only through a protected trusted database/operator connection; it is not a browser endpoint.
2. Verify the operator is ACTIVE in `private.system_administrators` and has an ACTIVE profile. Operator registry enrollment remains a separately authorized protected bootstrap operation; this tool never registers or elevates users. Confirm the initial administrator is the intended existing ACTIVE Auth identity/profile. Invitations/identity creation remain the protected P2 admin workflow.
3. Create a local input JSON outside source. Required: `operator_user_id`, `initial_admin_user_id`, `code`, `name`, `tenant_slug`, `default_locale` (`en` or `ar`). No actual Maker values were supplied or inserted in this checkpoint.
4. Optional existing fields: `legal_name`, `trn`, `address`, `notes`, `app_display_name`, `logo_url`, `favicon_url`, `primary_color`, `accent_color`. URLs are HTTPS; colors are six-digit hex. Omitted presentation colors use existing schema defaults. Status is fixed ACTIVE. Currency is not an existing Company/settings field and is not accepted; this does not add currency policy. Code length 1–50, display name 1–200; slug lowercase letters/digits separated by hyphens, length 3–63. Inputs trim outside whitespace; internal spelling remains.
5. Generate and review SQL:

   ```sh
   node scripts/admin/provision-company.mjs /protected/company-input.json /protected/company-provision.sql --rollback
   ```

   Output is created exclusively with owner-only file permissions; an existing file is never overwritten. All values are quoted literal JSON; dollar-block delimiters avoid source collisions. No credentials belong in the JSON. SQL contains Company personal metadata and should remain operator-controlled, outside Git. Rollback mode is rehearsal only.
6. Use protected Supabase operator administration or the linked Development CLI to execute the reviewed SQL. Confirm the actual linked project before execution. Remove `--rollback` when generating a **new**, separately reviewed final output to commit the three rows. This checkpoint does not authorize actual business values; obtain them before final execution. Transaction atomicity preserves all-or-none bootstrap; on duplicate code/slug investigate the prior result, do not rename/retry to create duplicates. Report/inventory the generated Company UUID, initial membership and settings after success. Existing creation attribution provides traceability; P7 immutable platform audit events remain deferred before production.
7. Initial administrator signs in/revalidates or uses the existing Company chooser. Only ACTIVE authorized memberships are selectable. Existing Company profile editor can later edit legal_name/trn/address/notes; branding provisioning remains trusted administration. No new UI is introduced.

## Verification and limits

- 16 focused Node checks: validation/unsupported fields, normal/rollback termination, Unicode/apostrophe and dollar-delimiter handling, no financial inserts.
- Hosted **MakerACC-Development rollback-only** matrix passed: unregistered/inactive platform operator and inactive operator profile denied; missing initial profile denied; literal SQL metacharacters preserved; atomic Company/settings/ACCOUNTING_ADMIN membership and provenance correct; duplicate code and slug rollback; ACCOUNTING_ADMIN, MANAGEMENT_VIEWER and Company SYSTEM_ADMIN denied procedure and direct Company/membership INSERT; own settings visible; foreign Company selection cannot authorize reads; failed attempts leave no partial Companies.
- New fixture has zero rows in every other tenant-owned table; journal-history checksum and demo Company identity checksum unchanged. All temporary Company/registry/membership fixtures and test functions rolled back; no retained Company or business record created. No demo fixture mutation executed.
- Focused script syntax/lint and diff checks pass. No frontend changed, so EN/AR browser/RTL and frontend build are NOT APPLICABLE. Actual signed-in real-Company switching is DEFERRED until a real Company and credentials are supplied; source validation and hosted RLS isolate selection. No full audit or financial-flow reread.
- Current Development read found **zero ACTIVE private platform administrators**. This remains an operational blocker for real provisioning; the rollback test temporarily registered a synthetic existing identity solely inside its transaction. No actual user was elevated. Real identity values and approved initial administrator are also required.

## Definition of Done

Business/accounting: VERIFIED foundation is identity/settings/membership only, zero accounting effect. Security: VERIFIED focused boundary/role/tenant checks; operational MFA/session validation remains operator responsibility, immutable platform audit DEFERRED to P7/production gate. Database: VERIFIED existing constraints/grants and rollback evidence; migrations NOT APPLICABLE. Deployment: VERIFIED no deployment/configuration/secret change, Staging/Production untouched; real operator enrollment DEFERRED. Testing: VERIFIED focused checks, real browser onboarding DEFERRED. Documentation: VERIFIED this record plus current handoff/roadmap. Ready for protected Development provisioning once operator bootstrap and real input are approved; not production-ready or real-data-import-ready.

No XLSX import, employees, projects, categories, Suppliers, Treasury, opening balances, journals, Payroll/Attendance or financial logic changed. Synthetic V1-DEMO-20260929 remains intact. Implementation performed no commit or push.

## Authorized checkpoint closure

Closed in exactly one local commit, `Add real company provisioning foundation`; no push. Final diff contains only the provisioning generator, its focused verification script, this checkpoint record and the current handoff/roadmap updates (five files). Closure reconciled documentation and reviewed the diff without rerunning tests, starting platform-admin bootstrap, provisioning a Company or performing hosted actions. The operator-registration and real-input prerequisites remain deferred.
