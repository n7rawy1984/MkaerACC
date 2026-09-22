# P6C Slice 14 — OWNER Party Display Name UPDATE

**VERIFIED COMPLETE.** P6C remains IN PROGRESS; P6D/P6E NOT STARTED; Production readiness DEFERRED. Development only (`eqnzueginpkskbnqvgoc`). Authenticated browser acceptance, guarded cleanup and final integrity verification PASS. No Staging/Production action or Slice 15.

## Scope and authorization

Started from clean `main`/`origin/main` `0b78c6ee07c316be495e735e0fd516eb884c4292`, with Slices 1–13 VERIFIED COMPLETE. OWNER display name is descriptive on existing ACTIVE and INACTIVE Parties. P4 grants `party.manage` to ACCOUNTING_ADMIN and PROCUREMENT, but the unchanged Party UPDATE role policy excludes OWNER from PROCUREMENT. **ACCOUNTING_ADMIN alone** may rename OWNER. ACCOUNTANT and MANAGEMENT_VIEWER may read OWNER without edit; PROCUREMENT and DATA_ENTRY cannot read OWNER, but retain their operational Party visibility; PROJECT_MANAGER and SYSTEM_ADMIN have no Party rows. No role mapping was changed.

Only `parties.name` is editable, with Unicode boundary trimming, 1–200 characters, exact loaded `updated_at` optimism and Party-only refresh. Party creation/deletion, type/status/code/TRN/contact/notes/provenance, current-account/equity configuration, other Party types and all financial/P6D behavior are excluded. The OWNER ID and historical references remain stable.

## Implementation

The canonical forward migration `20260922140000_p6c_owner_party_name.sql` was applied to MakerACC-Development only. Its restrictive authenticated UPDATE policy adds OWNER to the existing Supplier/OTHER/EMPLOYEE/CUSTODIAN types, ANDed with unchanged P4 permission and role policies. Supplier-only INSERT, forced RLS, SELECT rules and column grants remain unchanged. A fixed-empty-search-path SECURITY INVOKER trigger rejects authenticated OWNER changes beyond the name and earlier stamped token, derives the actor from `auth.uid()`, trims Unicode boundary whitespace and advances `updated_at` monotonically for authenticated and trusted updates. It grants no direct browser EXECUTE.

The explicit repository sends `{name}` only and filters by active Company, OWNER type, Party ID and exact loaded token. Zero affected rows report conflict/authority loss without overwrite or retry. Provider scope/session/generation checks discard late writes and reads after tenant, role, user, profile or logout changes. The shared Parties lock serializes OWNER with Supplier/OTHER/EMPLOYEE/CUSTODIAN operations. The populated inline control handles duplicate submits, save/cancel, recovery feedback, keyboard/focus and EN/AR/RTL.

## Automated and authenticated acceptance evidence

- Development hosted rollback suite **115/115 PASS**: forced RLS/grants/invoker path, allowed ACTIVE/INACTIVE updates, denied role/read matrix, protected fields/types, tenant and authority denial, Unicode/name bounds, actor/provenance/tokens and prior Party-type continuity. No durable hosted-suite fixture remains.
- Simultaneous exact-token editors returned **1/0**; winner actor and advanced token were verified. Guarded automated concurrency fixture cleanup passed. No Auth user was created.
- Focused repository/provider behavior and isolated Chromium OWNER interaction **PASS**, including ACTIVE/INACTIVE names, validation, stale conflict, role/tenant/revocation transitions, draft/focus/keyboard and 390px EN/AR/RTL 200-character wrapping. Supplier, OTHER, EMPLOYEE and CUSTODIAN isolated Chromium regressions PASS. Isolated Chromium uses in-memory transport and is **not** hosted authenticated acceptance.
- Build PASS; lint 0 errors/4 established Fast Refresh warnings; P6A/P6C boundaries and affected behavior PASS. All **38** migrations align, linked dry-run is no-op and public DB lint is clean. Final automated/browser fixture Companies/Parties/memberships/settings/assignments and browser Auth/profile counts are **0**; global Companies/settings **14/14**, missing/orphan **0/0**.

The [authenticated browser kit](verification/p6c-slice14/README.md) was subsequently executed against Development. Authenticated acceptance PASS covered ACCOUNTING_ADMIN ACTIVE/INACTIVE OWNER name updates, validation and Unicode/200-vs-201 boundaries, controlled two-tab stale conflict with no overwrite or silent retry, Alpha/Beta tenant isolation, the complete documented role matrix, open-form downgrade and genuine tab-return authority revalidation, Company/membership/profile revocation and restoration, draft/focus/keyboard behavior, EN/AR/RTL 390px long-name wrapping, protected Party type boundaries and unchanged owner-current-account/equity/payment/journal/P6D holding behavior. Exact guarded cleanup completed after sign-out. Final verification returned all Slice 14 fixture Companies/Parties/memberships/settings/assignments and browser Auth/profile counts 0, global Companies/settings 14/14, missing/orphan 0/0. No credentials are stored.

| Lifecycle category | State |
|---|---|
| Business/accounting | VERIFIED descriptive-only scope; financial behavior NOT APPLICABLE |
| Security/authorization | VERIFIED | Focused Development role/RLS checks plus authenticated role/tenant/revocation acceptance PASS |
| Database | VERIFIED canonical Development migration, hosted tests, 38 aligned migrations and final integrity |
| Deployment | VERIFIED Development-only action; Staging/Production DEFERRED |
| Testing | VERIFIED | Focused automated checks plus authenticated browser acceptance and guarded cleanup PASS |
| Documentation | VERIFIED | Implementation, accepted browser evidence, cleanup and final integrity recorded |

Final Slice 14 state: **VERIFIED COMPLETE**. P6C remains IN PROGRESS; P6D/P6E NOT STARTED; Production readiness DEFERRED. One local closure commit is authorized; pushing remains the operator action.
