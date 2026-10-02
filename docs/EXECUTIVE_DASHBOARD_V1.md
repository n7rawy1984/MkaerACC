# Executive Dashboard — bounded V1 restoration, 2026-10-02

Source implementation and isolated verification complete; hosted signed-in acceptance remains deferred. Authenticated `/` now renders the tenant-scoped Executive Dashboard. Dashboard / الرئيسية is the first existing shell navigation item with a dashboard icon. The Foreman Attendance route behavior is preserved. No commit or push performed.

The legacy Dashboard's KPI cards, colored Recharts bars, project overview and recent-expense presentation were reused as visual patterns. Its localStorage data provider and ledger were not imported into the production route. No financial mutation controls are present. Accounting Admin and Management Viewer receive the same read-only financial summary; roles lacking the existing financial-read permissions receive only operational project information.

## Metrics and authoritative sources

| Presentation | Existing source and scope |
| --- | --- |
| Active Projects | Active Company's production master projects with ACTIVE status |
| Posted expense net; expense/project and expense/category charts; project expense column; six recent posted expenses | Every page of `readExpenses`, POSTED only, `net_amount_minor`; production master names/categories; Company-level expenses explicitly shown as overhead |
| Supplier Outstanding; supplier chart | `readSupplierPayments().outstanding.outstanding_amount_minor` |
| Subcontractor Payable; subcontractor chart | `readSubcontractorPayments().outstanding` plus disjoint released-but-unpaid `readRetentionPayments().outstanding` |
| Retention Held | `readRetentionReleases().available.remaining_amount_minor` |

All reads use the active authenticated Company and existing repositories/RLS. No new financial engine, posting formula, RPC, write, arbitrary journal read, employee profile or Payroll query was introduced. Amount totals and labels use exact BigInt minor units. Chart geometry alone uses normalized numeric weights; full exact amounts remain available in labels and tooltips.

Total/current Project Cost is omitted: expense documents alone do not represent certificates, Payroll and all ledger cost. Posted expense net is explicitly narrower and excludes VAT, certificates and Payroll. Treasury balance/distribution is omitted because Treasury masters do not expose an authoritative balance read. Legacy custody, owner, VAT and ledger KPIs are not reconstructed from partial data. Reads are live multi-query document summaries, not a transactionally consistent financial report; concurrent changes can require refresh. Duplicate expense pagination rejects rather than double-counts.

## Evidence and limits

`node scripts/verify-executive-dashboard.mjs` passed eight isolated real-application combinations: Accounting Admin / Management Viewer, English / Arabic, 1440px / 390px. An in-memory read-only transport replaced only the Supabase client; actual Auth, tenant authority, master providers, routes and financial repositories ran. Checks covered first navigation/root/Projects return, browser reload and locale persistence, all-page expense totals, exact large amounts, chart rendering and label separation, Viewer controls/privacy, loading/error/retry/empty states, foreign-row rejection, delayed tenant changes, authority revocation and an operational-only role. No mutation, Payroll/private-journal access or business localStorage read occurred. Screenshots were inspected, including final Arabic narrow layout. This is isolated evidence, not hosted role/RLS execution evidence.

Build passed. Lint passed with four existing Fast Refresh warnings. Production boundary verification passed across 152 modules; diff whitespace check passed. Build retains the chunk-size advisory. Focused credential-pattern inspection found no added secret. Hosted Maker Admin/Management Viewer smoke was not performed because user-controlled credentials were unavailable in this session. No hosted data, Development, Staging or Production configuration was changed; no migration/alignment/dry-run was needed.

| Completion category | Classification |
| --- | --- |
| Business/accounting | VERIFIED for bounded read-only source aggregation and explicit metric limitations; posting/accounting changes NOT APPLICABLE |
| Security/authorization | VERIFIED source boundaries and isolated role/scope/privacy behavior; hosted signed-in acceptance DEFERRED; existing database authorization unchanged |
| Database | NOT APPLICABLE to schema/migration changes; existing scoped reads/RLS reused |
| Deployment | NOT APPLICABLE to environment actions; hosted delivery/smoke DEFERRED |
| Testing | VERIFIED focused isolated browser matrix, build/lint, import boundary and whitespace checks; hosted smoke DEFERRED |
| Documentation | VERIFIED current route, evidence, omissions and limits reconciled in this record and handoff/roadmap pointers |

Changed files: `src/dashboard/{ExecutiveDashboard,DashboardChart}.tsx`, `src/dashboard/{dashboardRead,dashboardSummary,useDashboardRead}.ts`, `src/app/TenantReadyApplication.tsx`, `src/auth/ProtectedApplication.tsx`, `src/i18n/{en,ar}.ts`, `scripts/fixtures/executive-dashboard.tsx`, `scripts/verify-executive-dashboard.mjs`, this record, `PROJECT_HANDOFF.md`, `PROJECT_ROADMAP.md`.

Frozen V1 accounting, Attendance, Payroll, RLS, permissions and canonical migrations remain unchanged. WPS, Production readiness and the full pre-production audit remain deferred. No source implementation blocker remains; hosted acceptance still requires operator access.
