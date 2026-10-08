# V1 canonical Expense Category provisioning — existing workflow verified

2026-10-08. Bounded master-data checkpoint; no new production implementation is required. Existing production Category creation and maintenance are reused. No real Company, approved category records, Expenses, journals or imports were created. No Treasury work. Authorized local delivery is recorded below; no push.

## Current architecture and production gap

`public.expense_categories` already supports Company, required code/name, optional description, ACTIVE/INACTIVE status and creation/update provenance. Production `/expense-categories` uses `ExpenseCategoriesList`, `ExpenseCategoryForm`, `ProductionMasterDataProvider` and `expenseCategoryMutations`. Creation starts ACTIVE; edit and separate deactivate/reactivate actions maintain the existing fields. No VAT, GL, Project, budget or recognition fields are introduced.

There is no missing Category creation capability. Reuse the existing column-restricted PostgREST INSERT/UPDATE workflow; do not add a duplicate RPC, migration or UI. Database trigger normalizes fields, derives authenticated provenance, preserves creation metadata and advances the update token. Edits use Company/ID/updated_at filters for optimistic concurrency; failures/uncertain outcomes require refresh. Provider locks submissions, checks the authenticated identity and discards stale tenant/session results.

Forced RLS and `category.manage` are authoritative. Hosted permission data grants it only to ACCOUNTING_ADMIN; active profile, membership and Company are required. ACCOUNTANT, PROCUREMENT, DATA_ENTRY, MANAGEMENT_VIEWER, PROJECT_MANAGER and SYSTEM_ADMIN cannot mutate categories. Platform status grants no bypass. Browser INSERT columns are company_id/code/name/description; UPDATE columns code/name/description/status. No browser DELETE, tenant reassignment, caller-supplied provenance or arbitrary ID grants.

Uniqueness is the existing `expense_categories_company_code_unique_ci` index on `(company_id, lower(btrim(code)))`: space-trimmed, case-insensitive stable code within each Company, including inactive rows. Another authorized Company may reuse a code. Names need not be unique and are never silently merged. Existing UI/database validation supports names of 1–200 characters and codes of 1–50. Code remains an editable business field under the current workflow; future provisioning uses the approved stable codes below.

Expense reads retain `expense_category_id`, existing exact minor-unit handling, Company filtering and historical document identity. Posting requires an authoritative same-Company ACTIVE category through the unchanged existing validation. No Expense consumer, posting function or accounting rule is changed.

## Future real-Company seed set — documentation only

These are 18 approved concepts, not inserted records or an executable seed. Provision only after a distinct real Company exists and an authorized Company operator is ready. Create new Company-owned identities; never copy Demo IDs, rename/delete Demo categories or merge names automatically.

| Code | Canonical name |
| --- | --- |
| MATERIALS | مواد بناء |
| SITE_LABOR | أجور عمال |
| LOGISTICS | نقل ولوجستيات |
| EQUIPMENT_RENT | إيجار معدات |
| VEHICLE_RUNNING | وقود ومركبات |
| REPAIRS | صيانة وإصلاح |
| ELECTRICAL | كهرباء |
| PLUMBING | سباكة وأدوات صحية |
| FINISHES | دهانات وتشطيبات |
| CARPENTRY | نجارة وأخشاب |
| TILES_STONE | سيراميك وبلاط ورخام |
| SITE_WATER | مياه ومستهلكات موقع |
| OFFICE_ADMIN | مكتب وإدارة |
| IT_TELECOM | تقنية واتصالات |
| HOUSING_UTILITIES | سكن ومرافق |
| EMPLOYEE_AFFAIRS | موظفين ومعاملات |
| FEES_ADVISORY | رسوم واستشارات |
| SMALL_TOOLS | أدوات ومعدات صغيرة |

## Focused evidence and scope

- Verified linked MakerACC-Development (`eqnzueginpkskbnqvgoc`); Staging/Production untouched. No canonical migration added or applied. All 49 local/remote versions align; linked dry-run is a no-op. First dry-run hit a provider authentication timeout; the single retry passed.
- `scripts/sql/canonical-expense-categories/hosted-checks.sql`: **69 assertions PASS**, adapting the accepted Slice 5 matrix without its Expense/Party dependency fixture. Actual authenticated/anon/service roles exercise allowed creation/update/status, unauthorized roles, inactive actors/membership/Company, cross-Company rejection, duplicate normalized codes, same-code other Company, column privileges, forced RLS, provenance and stale-token conflict. All synthetic identity/Company/category data rolled back; separate read-only verification confirms zero retained fixtures.
- Checksums of all pre-existing categories (including Demo), Expenses, journal entries and journal lines remain identical during checks. No Expense or journal INSERT is executed. This is SQL-role verification, not a new hosted password-login/browser acceptance run.
- Existing EN/AR/RTL UI is reused without changes. Prior authenticated create/edit/status, duplicate/conflict, Viewer and Arabic/RTL acceptance is recorded in `docs/verification/p6c-slice5/README.md`; no new browser acceptance or narrow-screen runtime test was run here. Current form uses the existing responsive grid and wrapped actions. No UI was added.
- Current `npm run build` (including TypeScript) and focused oxlint of Category form/list/repository/provider and master read repository PASS. Existing build chunk-size advisory remains informational. Diff/secret/scope checks cover this checkpoint only; no broad audit or unrelated tests.

Business/accounting: VERIFIED master-only, zero financial effects. Security/authorization: VERIFIED focused hosted boundaries. Database: VERIFIED existing schema/grants/RLS, rollback checks and migration alignment. Deployment: existing Development database VERIFIED; new deployment NOT APPLICABLE because runtime code is unchanged; future real-Company onboarding and Production readiness DEFERRED. Testing: VERIFIED focused current checks and explicitly historical browser evidence; new hosted UI/narrow-screen testing DEFERRED. Documentation: VERIFIED approved seed set and current checkpoint boundaries.

The remaining provisioning blocker is the absent real Company and its authorized operator/onboarding prerequisites. Do not create those or the 18 categories within this checkpoint. No XLSX import, Treasury, Payroll, Attendance or Subcontract changes. Files changed: this record, current handoff/roadmap and the category-only rollback verification script.

## Authorized checkpoint closure

Documentation reconciled with the verified final Development state. The exact four-file diff contains only PROJECT_HANDOFF.md, PROJECT_ROADMAP.md, this record and scripts/sql/canonical-expense-categories/hosted-checks.sql. No runtime, migration, RPC or UI changes. Closure uses the recorded verification evidence without rerunning tests or performing hosted actions. Delivery is exactly one local commit, `Document canonical expense categories readiness`; no push. Real Company/category provisioning and Treasury remain outside this checkpoint.

## Real Company minimum master-data operation (2026-10-08)

This operation supersedes the earlier documentation-only seed state for the approved real Company. Baseline clean at `85ac2c4`, linked to MakerACC-Development `eqnzueginpkskbnqvgoc`. User authorized only the 18 canonical categories above in Company `c1ca8b02-0096-4bca-af4c-68331f510103` (`MAKER`, Maker Building Contracting). Farm/Villa Al Mazraa workbook is entirely excluded; no workbook or prior classification was opened or reprocessed. No payroll onboarding.

Company-scoped authoritative reads used the existing authenticated role/RLS with approved Company ACCOUNTING_ADMIN attribution `6f67b7bf-e531-49b7-9839-a0167c9c582b`. Company and membership are ACTIVE; category.manage is granted. Protected operator SQL set transaction-local authenticated identity context, using the existing category column grants, RLS, normalization and provenance trigger; this is protected database execution, not new browser/password-login evidence, and platform status was not treated as Company authority. No service-role category bypass or caller-supplied provenance was used. Only company_id/code/name/description were inserted. Existing normalized-code matches would be skipped only if approved name/status matched; discrepancies would abort, never silently overwrite. The transaction asserted all 18 approved code/name/ACTIVE pairs exactly once before commit. Initial categories were empty; all 18 were newly created with default ACTIVE status and approved Company admin creation/update provenance. Operation SQL/approved values remain outside Git under `/tmp/makeracc-masters-AFv5PMWG` with owner-only permissions.

Independent hosted readback found 18 total categories, 18 distinct normalized codes and all ACTIVE with exact approved codes; the atomic assertion verified the Arabic names. All 48 public-table counts/content hashes, excluding only this Company's new category rows, matched the pre-operation baseline. Company-scoped inventory changed only expense_categories from 0 to 18; journal_entries/lines, Expenses, payroll and every other business table remain zero. Demo and every other tenant's records remained unchanged; no Demo business investigation was performed. No Staging/Production calls.

Treasury readiness STOP: real Company accounts count is zero, Treasury count is zero, and there are zero eligible ACTIVE ordinary Asset GL candidates. Consequently there are no GL UUID/code/name/type/mapping candidates to list. No Treasury or GL was invented. Before the first real Expense import, approved Company Chart of Accounts/system mappings are needed (COMPANY_EXPENSE for overhead, INPUT_VAT if recoverable VAT applies, and relevant funding-mode system accounts where applicable), followed by actual Treasury code/name/type and eligible real Company-owned GL UUID. Bank details/Project scope are business inputs where applicable. Funding/custody decisions remain separate approved prerequisites; no opening balance/funding transaction is authorized here.

Project is optional in the existing Expense POST workflow: NULL Project selects COMPANY_EXPENSE; a supplied same-Company Project is validated and uses PROJECT_COST. A Project-scoped Treasury must match the Expense Project. Therefore Company/overhead General Expenses do not require a fake Project. No Project was created, no source-derived Project identity claimed, and no farm data was used. Existing `public.post_expense` delegates to `private.post_expense`; the unchanged canonical validation/GL resolution is in migrations `20260901120000` and `20260903120000`. No financial posting was executed.

Business/accounting: VERIFIED categories only and zero accounting effects; actual import/funding policy DEFERRED. Security/authorization: VERIFIED approved ACTIVE Company/admin, existing category permission/RLS/provenance; new browser login acceptance DEFERRED. Database: VERIFIED existing constraints and operational results; schema/migrations NOT APPLICABLE. Deployment: VERIFIED Development only; new app deployment NOT APPLICABLE. Testing: VERIFIED focused hosted readback, exact transaction assertion, before/after hashes and tenant counts; no broad tests/build/lint/migration dry-run or full audit rerun for unchanged code/schema. Documentation: VERIFIED this record/handoff/roadmap reconciled and git diff --check passed. Categories ready; General Expense import BLOCKED by absent Company chart and Treasury, not product implementation. No new features, code/schema changes, imports, Expenses, payroll, fake Project/Treasury or Demo cleanup. Execution performed no commit or push.

## Authorized real Company category-record closure (2026-10-08)

Completed category provisioning record closed in one local documentation-only commit, `Close real Company master categories`, containing only `PROJECT_HANDOFF.md`, `PROJECT_ROADMAP.md` and this record. Closure reconciled the existing evidence and ran `git diff --check`; no hosted checks, category creation or tests were rerun. The ACTIVE Company/admin, 18 unique ACTIVE approved categories, empty Chart of Accounts, absent Treasury, optional overhead Project, zero journals/transactions and unchanged Demo are prior verified operation results. No runtime/code/schema changes, imports, financial mutations or Staging/Production actions during closure; no push. Category checkpoint complete; Treasury/GL prerequisites and real Expense import remain separate work.
