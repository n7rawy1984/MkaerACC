# P6C Slice 13 — CUSTODIAN Party Display Name UPDATE

**VERIFIED COMPLETE.** P6C IN PROGRESS; P6D/P6E NOT STARTED; Production readiness DEFERRED. Development only (`eqnzueginpkskbnqvgoc`). Authenticated browser acceptance, guarded cleanup and final integrity verification PASS. No Staging/Production action or Slice 14.

## Scope and role decision

Started from clean HEAD/origin/main `169352ecf5f978605d1aec62efa511fc371e34bc`, Slices 1–12 VERIFIED COMPLETE. CUSTODIAN name is descriptive on existing ACTIVE and INACTIVE Party rows. The unchanged P4 `party.manage` mapping gives ACCOUNTING_ADMIN and PROCUREMENT that permission, but the P4 Party UPDATE role policy excludes CUSTODIAN from PROCUREMENT's allowed types. Therefore **ACCOUNTING_ADMIN alone** may rename CUSTODIAN. Procurement and Data Entry may read it as an operational Party; Accountant and Management Viewer may read it; Project Manager and System Admin have no Party rows. No role mapping was added.

Only `parties.name` for existing CUSTODIAN rows is in scope, with boundary trimming and 1–200 Unicode characters, exact loaded `updated_at` optimism and Party-only refresh. Creation/deletion, type/status/code/TRN/contact/phone/email/address/notes, tenant/provenance/configuration and all other Party types are excluded. Custody advance/funding/settlement, expense/payment, Projects, Accounts/Treasury, GL/journals/ledger, balances, payroll, posting/reversal and P6D/P6E are untouched. A display-name change does not alter custodian ID or financial history.

## Database and frontend boundary

Before implementation, all 36 canonical migrations aligned; the exact Parties columns, constraints, indexes, triggers/functions, grants/column grants, P4 policies and party.manage mapping matched the Development catalog. FORCE RLS was active. Global Companies/settings were 14/14, missing/orphan 0/0. A linked dry-run listed only `20260922130000_p6c_custodian_party_name.sql`; that forward migration was applied to Development only.

The restrictive authenticated Party UPDATE policy adds CUSTODIAN to the existing Supplier/OTHER/EMPLOYEE types, ANDed with unchanged P4 permission/role policies. Supplier-only INSERT and table-wide exact column grants remain unchanged. A new fixed-empty-search-path SECURITY INVOKER trigger runs after Supplier preparation and before EMPLOYEE/OTHER preparation. It rejects authenticated CUSTODIAN changes beyond name and the earlier stamped token, derives `updated_by` from `auth.uid()`, trims Unicode boundary whitespace, and advances `updated_at` monotonically. Trusted updates retain their metadata/actor authority and also advance tokens. No direct trigger EXECUTE, broad browser table writes/delete/truncate, privileged browser RPC or schema rewrite was introduced.

The explicit repository sends `{name}` only, filtered by active Company, CUSTODIAN type, ID and loaded exact token. Zero rows means conflict/authority loss, with no silent retry. Provider session/scope checks surround write and Party-only refresh; late results from Company/user/role/logout/unmount changes are discarded. Supplier/OTHER/EMPLOYEE/CUSTODIAN operations serialize against the shared Parties snapshot. Inline populated editor supports save/cancel, duplicate-submit blocking, error/recovery feedback, focus restoration, keyboard and EN/AR/RTL.

## Automated and authenticated acceptance evidence

- Focused Development hosted rollback suite **115/115 PASS**: forced RLS, exact grants, fixed-path invoker/no direct EXECUTE, admin ACTIVE/INACTIVE rename, six denied roles with correct read visibility, protected fields/type, tenant isolation, inactive Company/membership/profile denial, Unicode/name bounds, actor/provenance, exact/no-op/future/trusted tokens, Supplier/OTHER/EMPLOYEE continuity. No durable fixture from this suite.
- Two simultaneous exact-token editors returned **1/0**, with winner actor and advanced token verified. Guarded disposable fixture cleanup removed only Slice 13 Company/Party/membership/settings; no Auth user was created.
- Focused repository/provider checks **PASS**: one-field payload, exact filters, invalid/conflict/denied/uncertain responses, allowed/denied roles, duplicate guard, delayed write/read isolation, Party-only refresh, known-commit recovery and shared serialization with Supplier/OTHER/EMPLOYEE.
- Real **isolated** Chromium **PASS** with actual providers/shell/form and in-memory transport: inactive rename, exact payload/token, conflict/recovery, role/tenant/revocation, draft/focus/keyboard, Arabic/RTL. Separate 390px EN/AR check passed full 200-character unbroken ASCII/Arabic wrapping without horizontal document/body overflow. Directly affected Supplier, OTHER and EMPLOYEE isolated Chromium regressions PASS. These are not hosted authenticated acceptance.
- Build PASS; lint 0 errors/4 existing warnings; P6A/P6C boundaries and affected master behavior PASS; changed-file secret scan and `git diff --check` PASS. 37 migrations aligned, final linked dry-run no-op, public DB lint clean. All Slice 13 automated/browser fixture/Auth counts 0; global Companies/settings 14/14, missing/orphan 0/0.

The [manual browser kit](verification/p6c-slice13/README.md) was subsequently executed against Development. Authenticated acceptance PASS covered ACCOUNTING_ADMIN ACTIVE/INACTIVE CUSTODIAN name updates, validation and Unicode/200-vs-201 boundaries, controlled two-tab stale conflict with no overwrite or silent retry, Alpha/Beta tenant isolation, the complete documented role matrix, open-form downgrade and genuine tab-return authority revalidation, Company/membership/profile revocation and restoration, draft/focus/keyboard behavior, EN/AR/RTL 390px long-name wrapping, protected Party type boundaries and unchanged financial/P6D holding behavior. Exact guarded cleanup completed after sign-out. Final verify returned all Slice 13 fixture Companies/Parties/memberships/settings/assignments and browser Auth/profile counts 0, global Companies/settings 14/14, missing/orphan 0/0. No credentials are stored.

| Lifecycle category | State |
|---|---|
| Business/accounting | VERIFIED descriptive-only scope; financial behavior NOT APPLICABLE |
| Security/authorization | VERIFIED | Automated Development boundary plus authenticated role/tenant/revocation acceptance PASS |
| Database | VERIFIED Development migration, hosted invariants/concurrency, alignment/lint/dry-run |
| Deployment | VERIFIED Development-only action; Staging/Production and readiness DEFERRED |
| Testing | VERIFIED | Focused automated gates plus authenticated browser acceptance and guarded cleanup PASS |
| Documentation | VERIFIED | Implementation, accepted browser evidence, cleanup and final integrity recorded |

Final Slice 13 state: **VERIFIED COMPLETE**. P6C remains IN PROGRESS; P6D/P6E NOT STARTED; Production readiness DEFERRED. One local closure commit is authorized; pushing remains the operator action.
