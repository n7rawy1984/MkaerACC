# Maker Demo Branding + Arabic/RTL Presentation Hardening

2026-10-01. **Source checkpoint COMPLETE / VERIFIED; hosted branding/deployment verification DEFERRED to the operator.** P6E and Single-Company V1 Demo Ready remain accepted; WPS, production readiness and the full production audit remain deferred. No new product capability or phase.

Baseline: `main`, HEAD and origin/main both `65f5eedd5231d5b020051a5fa378f23ae2dabbc8`, ahead/behind 0/0, clean tree. Implementation-stage work performed no reset/cleanup/discard, commit or push. Scope is presentation source only, per the resumed user instruction; no database connection or mutation.

## Logo and branding

The exact supplied `Luxury Graphite and Bronze M Emblem.png` (1536×1024 RGBA) was converted with cwebp quality 92, alpha quality 100 to `public/branding/maker-logo.webp`: **768×512 RGBA, 58,832 bytes**, original 3:2 aspect ratio and transparency retained. The artwork/glow was retained without a speculative crop or redesign. Source alpha includes partially transparent pixels; no replacement background was added.

Existing P6B tenant settings remain the source of identity. TenantBrandMark now uses the configured effective display name as alt text (Maker for the intended settings), retains object-fit contain and cannot flex-shrink. No Maker name/URL is hardcoded into generic production tenant components. Attendance and Payroll headers now consume presentation branding; Payroll print includes configured name/logo when available. Underlying Company/legal identity and export context remain unchanged. Existing favicon configuration was inspected and preserved; no new favicon capability.

### Operator update, not performed

After deploying the asset to the approved demo origin, resolve the existing `public.companies.id` by `companies.code = 'V1-DEMO-20260929'`. Update only its existing `public.company_settings` row matched by `company_settings.company_id`:

| Existing column | Intended value |
|---|---|
| `app_display_name` | `Maker` |
| `logo_url` | `https://maker-eosin.vercel.app/branding/maker-logo.webp` |

These are the actual columns in canonical `20260911120000_p6b_company_settings.sql`; the URL constraint requires HTTPS. Preserve Company UUID/code/name/legal name, tenant_slug, default_locale, favicon, colors, and unrelated settings. The existing updated_at trigger remains authoritative. No browser settings write path, schema workaround, provisioning automation or operational SQL was added. Operator must use the existing trusted Development settings administration path. This record does not authorize Staging or Production.

## Findings and fixes

- **Confirmed presentation defects:** certificate POSTED label and related financial prose omitted the shadda in `مرحّلة`; corrected spelling in 14 dictionary entries and made three reversal confirmation sentences natural without changing intent. Accounting terminology/recognition/settlement rules were retained.
- **Confirmed presentation defects:** technical/numeric inputs inherited RTL, including dynamic supplier contact/code/TRN fields and Payroll ID. Scoped LTR direction now covers decimal/number/date/month/email/reference inputs; Arabic descriptions/notes/names inherit document direction. Payroll IDs, standalone amounts, UUIDs, codes, account references, emails and dates use isolated LTR where appropriate.
- **Confirmed presentation defects:** physical text-left/text-right, certificate control ml spacing, and status-card border-left did not follow RTL. Replaced with text-start/text-end, ms spacing and border-start. The demo-only sidebar/shell now stack at narrow widths with min-width and wrapping safeguards.
- **Hardening opportunity:** Arabic headings/labels inherited Latin tracking utilities. Arabic text now uses normal letter spacing to avoid shaping/spacing artifacts. Global form/table alignment follows logical start; Payroll numeric cells/totals align consistently to logical end.
- **Confirmed branding omission:** Attendance/Payroll headers bypassed existing presentation settings and lacked the tenant mark. They now use the existing provider, as does the print heading, while preserving authoritative Company/export data.
- **Expected behavior:** root locale already applies `html lang=ar dir=rtl` and `lang=en dir=ltr`; this logic was not changed. Existing semantic arrows already have RTL mirror classes; invariant icons were preserved. The authenticated navigation is a wrapping link bar; the separate sidebar belongs to local-demo.
- **Coverage limit:** no backwards Arabic literal, presentation-form codepoint, explicit bidi control or manual string reversal was found in the scanned translation surface. The original reported reversed-letter symptom was not independently reproduced with a pre-change hosted screenshot. Do not claim an established universal root cause. Post-change screenshots show reviewed Arabic headings/labels in logical order; no strings were reversed or artificial Unicode controls inserted.

## Review and verification

Static review covered the 1,320-entry Arabic dictionary (all entries contain Arabic; zero presentation-form codepoints or explicit bidi overrides), Auth/loading/retry/no-company/selection, tenant shell/nav, master forms/lists, financial panels/command forms and Attendance/Payroll/output labels. Demo dashboard, supplier/subcontract detail and journal/sidebar layouts were source-reviewed; the current authenticated `/` route displays Projects rather than the old local-demo dashboard.

`node scripts/verify-demo-presentation.mjs` PASS: **84 combinations = 21 views × EN/AR × 1440/390px** using real UI components with isolated in-memory Auth/master/transport/read snapshots. Browser external requests are blocked; the transport rejects mutations. Views: Projects, Company profile, Parties, Categories, Accounts, Treasury, Subcontracts, Expenses/Supplier Credit, Supplier Payments, Subcontractor Advances, Certificates, Subcontractor Payments, Retention Releases/Payments, Attendance, Payroll, login, Company selection, no-company, retry, and sidebar. Populated financial rows, eligible allocation forms, financial reversal panels and Payroll draft/payment-history forms were rendered without posting or modifying data. Additional checks cover modal alignment, root lang/dir, no page overflow, input direction, logo load/aspect sizing/alt, settings-provider title and refresh, logical table column order, LTR IDs and exact `1234.56`, repeat print headings, and A4 landscape PDFs. Browser console/page errors: zero. Expense and register EN/AR screenshots were visually inspected.

`node scripts/verify-payroll-step3.mjs` PASS: focused isolated EN/AR Excel/Print output, exact money text/totals, IDs, RTL workbook metadata, authoritative DRAFT/POSTED snapshots, output boundary/revalidation, A4 landscape and multi-page print. No historical financial/accounting suites or hosted tests ran. Calculations and workbook data-generation code are unchanged.

`npm run build` PASS (existing >500KB bundle advisory); `npm run lint` PASS with only four pre-existing Fast Refresh warnings. `verify:p6a-boundary` and `verify:p6c-boundary` PASS. Focused changed-file secret scan and `git diff --check` PASS. Source/AST comparison verified unchanged executable financial state/command nodes outside JSX in 23 changed financial UI modules; JSX handlers were diff-reviewed separately. Repositories, calculation/domain/accounting/storage/seed code, Auth authority, generated schema, financial RPCs and canonical migrations have no changes. Asset is included in the built dist output.

Evidence is reproducible through the new fixture/runner. Temporary screenshots, PDFs and results: `/tmp/maker-demo-presentation/`; these may expire. Existing output-suite screenshot: `/tmp/makeracc-payroll-step3-rtl.png`.

## Completion categories and limits

| Category | Classification |
|---|---|
| Business/accounting | VERIFIED: presentation-only; amounts/commands/history unchanged. Hosted fixture checks intentionally not rerun. |
| Security/authorization | VERIFIED: authority/roles/RLS unchanged; focused dependency boundaries pass. Full production audit DEFERRED. |
| Database | NOT APPLICABLE: no access, settings mutation, schema change or migration; alignment/dry-run not needed for source-only work. |
| Deployment | DEFERRED: asset deployment and the exact operator settings update above; no external deployment performed. |
| Testing | VERIFIED: local/static/isolated browser and focused output evidence. Hosted real login/refresh/logout/login settings recovery DEFERRED until operator deployment/update. |
| Documentation | VERIFIED: this checkpoint plus minimal handoff/roadmap pointers; historical phases unchanged. |

Remaining operator checks: deployed HTTPS asset response, authoritative Company settings after actual login, refresh and logout/login, hosted desktop/narrow Arabic smoke and Payroll print/logo with the preserved demo fixture. Local mocked settings reload is not proof of hosted authentication/settings restoration. No source blocker remains. This is not Production readiness.

No DB/accounting/Attendance/Payroll-rule/fixture change; no migration or Staging/Production action.

User-approved closure uses the completed verification above without rerunning tests or starting new work. The bounded changes are recorded in one local commit, `Complete Maker demo branding and Arabic RTL hardening`; no push or environment action. Earlier no-commit statements refer to the implementation stage before this authorized closure.

## Files changed

- `PROJECT_HANDOFF.md`
- `PROJECT_ROADMAP.md`
- `docs/MAKER_DEMO_BRANDING_ARABIC_RTL.md`
- `public/branding/maker-logo.webp`
- `scripts/fixtures/demo-presentation.tsx`
- `scripts/verify-demo-presentation.mjs`
- `src/app/TenantReadyApplication.tsx`
- `src/attendance/AttendanceApplication.tsx`
- `src/auth/CompanySelectPage.tsx`
- `src/auth/LoginPage.tsx`
- `src/components/AdvanceForm.tsx`
- `src/components/CertificateForm.tsx`
- `src/components/CustodySettlementForm.tsx`
- `src/components/ExpenseForm.tsx`
- `src/components/ProjectForm.tsx`
- `src/components/SubcontractForm.tsx`
- `src/components/SubcontractorAdvanceForm.tsx`
- `src/components/SubcontractorForm.tsx`
- `src/components/SubcontractorPaymentForm.tsx`
- `src/components/SupplierPaymentForm.tsx`
- `src/components/layout/AppShell.tsx`
- `src/components/layout/Sidebar.tsx`
- `src/components/ui/StatCard.tsx`
- `src/financial/ExpenseReadPanel.tsx`
- `src/financial/ExpenseReverseAction.tsx`
- `src/financial/RetentionPaymentPanel.tsx`
- `src/financial/RetentionPaymentPost.tsx`
- `src/financial/RetentionPaymentReverseAction.tsx`
- `src/financial/RetentionReleasePanel.tsx`
- `src/financial/RetentionReleasePost.tsx`
- `src/financial/RetentionReleaseReverseAction.tsx`
- `src/financial/SubcontractorAdvancePanel.tsx`
- `src/financial/SubcontractorAdvancePost.tsx`
- `src/financial/SubcontractorAdvanceReverseAction.tsx`
- `src/financial/SubcontractorCertificateApproveAction.tsx`
- `src/financial/SubcontractorCertificateDraft.tsx`
- `src/financial/SubcontractorCertificateReverseAction.tsx`
- `src/financial/SubcontractorPaymentPanel.tsx`
- `src/financial/SubcontractorPaymentPost.tsx`
- `src/financial/SubcontractorPaymentReverseAction.tsx`
- `src/financial/SupplierCreditExpensePost.tsx`
- `src/financial/SupplierPaymentPanel.tsx`
- `src/financial/SupplierPaymentPost.tsx`
- `src/financial/SupplierPaymentReverseAction.tsx`
- `src/financial/TreasuryExpensePost.tsx`
- `src/i18n/ar.ts`
- `src/index.css`
- `src/master/AccountMasterLists.tsx`
- `src/master/CompanyProfileForm.tsx`
- `src/master/CompanyProfilePanel.tsx`
- `src/master/ExpenseCategoryForm.tsx`
- `src/master/PartiesList.tsx`
- `src/master/ProjectsList.tsx`
- `src/master/SubcontractMetadataForm.tsx`
- `src/master/SubcontractsList.tsx`
- `src/master/SupplierPartyForm.tsx`
- `src/pages/Advances.tsx`
- `src/pages/Dashboard.tsx`
- `src/pages/Expenses.tsx`
- `src/pages/Journal.tsx`
- `src/pages/OwnersCustodians.tsx`
- `src/pages/ProjectDetail.tsx`
- `src/pages/Projects.tsx`
- `src/pages/SubcontractDetail.tsx`
- `src/pages/SubcontractorDetail.tsx`
- `src/pages/Subcontractors.tsx`
- `src/pages/Suppliers.tsx`
- `src/pages/Treasury.tsx`
- `src/payroll/PayrollApplication.tsx`
- `src/payroll/PayrollPosting.tsx`
- `src/payroll/PayrollRegisterOutput.tsx`
- `src/payroll/payrollRegister.css`
- `src/tenant/TenantBrandMark.tsx`
