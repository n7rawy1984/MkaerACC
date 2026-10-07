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
