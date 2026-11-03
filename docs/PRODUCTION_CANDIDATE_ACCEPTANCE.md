# Existing Production candidate — final acceptance

**TECHNICAL ACCEPTANCE PASS. GO for promotion after final human visual acceptance and separate explicit promotion authorization.** No promotion, deployment, alias repair, application-code change, migration, configuration change or business mutation was performed in this acceptance task.

Candidate: https://maker-rom44ea4z-n7rawy1984-8059s-projects.vercel.app/ — `dpl_8Jvbmi1GFoVPNhG36CAf1ZGkCfHP`.

[Exact machine result](release/production-candidate-acceptance/result.json) · [Screenshots/evidence](release/production-candidate-acceptance/index.html) · [Original frozen272-file manifest](release/controlled-production-candidate-manifest.json).

## Alias exception accepted and verified

The user accepted the automatically generated alias subject to preserving the existing Production site. Fresh authoritative Vercel deployment/alias/project metadata verifies:

| Target | Actual deployment |
| --- | --- |
| `maker-eosin.vercel.app` | Original `dpl_DC2wK34FdbWNsVtnqMCzb54uRwDh`; no redirect. |
| Configured project Production target | Original `dpl_DC2wK34FdbWNsVtnqMCzb54uRwDh`. |
| Candidate URL and generated `maker-n7rawy1984-8059s-projects.vercel.app` alias | Existing READY candidate `dpl_8Jvbmi1GFoVPNhG36CAf1ZGkCfHP`. |

The candidate has only the generated project alias; `autoAssignCustomDomains=false`. The named Production domain returns HTTP200 on its own hostname. No alias repair/removal was needed or attempted. The accepted exception supersedes the earlier strict-unaliased NO-GO; it does not authorize promotion.

## Genuine owner and Company sessions

Chrome owner: SDK `auth.getUser()` confirms `ebcf7115-6cd9-49be-af25-8e57b5befd75`, `naghamel7ayah@gmail.com`; current/next AAL2; server `get_platform_context()` returns PLATFORM_OWNER, step_up_required=false. Owner has zero Company memberships. Direct authenticated HEAD/count reads of accounts, Expenses and journals each returned0, demonstrating no financial cross-tenant bypass. No token, password or MFA code was extracted or logged. User completed genuine sign-in/MFA privately; normal future freshness prompts remain expected.

All nine owner screens loaded with real data/empty states, no alerts and no document overflow at375 CSS px: Overview, Customers, Accounting entities, Users, Memberships, Invitations, Subscriptions, Audit log and Settings. Representative counts:18 entities,25-row user/membership pages,1 invitation,18 subscription rows,13 audit rows and1 settings row. Existing Overview metrics show18 entities/17 active/0 Customers/290 profiles. No administrative form was submitted.

Firefox Company: genuine SDK identity `6f67b7bf-e531-49b7-9839-a0167c9c582b`, `m.saed@admin.com`, display M. Saed. Active Company `MAKER` (`c1ca8b02-0096-4bca-af4c-68331f510103`) with ACCOUNTING_ADMIN. Its two visible Companies match its two active memberships (Maker and the existing V1 demo Company). Server Platform Owner context is denied42501. This Company acceptance belongs to M. Saed; it is **not** attributed to the invited recipient or Platform Owner. Browser identity was checked before accepting route evidence.

## Existing Company modules and metric truth

All19 Company routes loaded in the genuine Company session at1366 CSS px, with no alerts or document-level overflow:

`/`, `/expenses`, `/projects`, `/company-profile`, `/parties`, `/expense-categories`, `/accounts`, `/treasury-accounts`, `/supplier-payments`, `/subcontracts`, `/subcontractor-advances`, `/subcontractor-certificates`, `/subcontractor-payments`, `/retention-releases`, `/retention-payments`, `/attendance`, `/payroll`, `/accounting-cycle`, `/accounting-reports`.

Both Overview and Accounting Cycle contain all six sections. Each reported5 AVAILABLE,4 VERIFIED_ZERO and16 UNAVAILABLE metric nodes, with0 ERROR/LOADING nodes. Unavailable values display an em dash; verified zeros display exact0.00 formatting. These are actual candidate read results, not fixture statistics. Source evidence and posted accounting remain distinct. The final Arabic Expenses view also shows invoice-only evidence unavailable rather than inventing a zero.

Live Company subscription RPC returns UNMANAGED/FULL, no assigned dates; this does not block reads. Legacy accounting setup is UNASSESSED, not falsely COMPLETE or automatically provisioned. No subscription, provisioning or Company-state change was needed. Prior accepted expiry/cancellation/renewal, database and concurrency evidence remains applicable because the source/catalog are unchanged; those hosted transitions were not repeated. New financial posting and settlement/reversal behavior were not retested through mutations.

## Representative visual and accessibility review

Live native browser layouts were reviewed in English/LTR and Arabic/RTL. Company widths:1366 desktop,768 tablet,500 mobile CSS px; Owner nine screens at375 CSS px. Actual width values are recorded rather than inferred from requested outer-window size. All measured layouts have no document overflow. Prior source-identical local390px Expenses evidence remains valid; it is not relabelled as a new native390px candidate run.

Arabic mobile navigation opens the native modal drawer, retains tested Tab focus inside with a visible3px outline, closes with Escape and returns visible focus to its trigger. Responsive screenshots, clean Arabic Expenses and both Dashboard directions are archived. Agent review does not substitute for the owner's final visual acceptance.

Only the two previously incomplete accessibility rules were examined, not another broad suite. Source-identical local computed-style review resolved78 gradient-background contrast cases (minimum conservative ratio4.907) and132 clipped-table text cases (all visible after scrolling, minimum ratio9.737). No contrast failure was found among these cases. These are computed source-style checks; they are not exhaustive live screen-reader certification.

**Minor non-blocking follow-up:** `src/financial/ExpenseReadPanel.tsx:46` applies aria-label to the generic `.expense-page-summary` div without a grouping role. Its group name is not reliably exposed; individual visible card headings remain available. This is a confirmed low-impact semantic labelling defect. A future separately authorized presentation change can add appropriate group semantics. No code was changed and no second deployment was created for it. Full assistive-technology certification is not claimed.

## No-mutation and environment postflight

Fresh acceptance-before/after fingerprints match for all46 Company-owned tables, Company/profile/membership/subscription data and private administrative/request/counter records. All64 migrations and function/RLS/grant/policy catalog fingerprints are unchanged. Auth configuration, invitation function source/configuration, JWT verification, Vercel variables/protection and all272 frozen source files remain unchanged. The existing shared project remains `eqnzueginpkskbnqvgoc`; no environment switch occurred. The seven prior non-delivery CORS/anonymous checks are retained under unchanged configuration; no email/invitation operation was executed.

Browser diagnostic focus/input issues were corrected before evidence was accepted. One read-only diagnostic text reached the address bar rather than executing; it contained no credential/session values. Unsupported identity claims, transient loading screenshots and a late incorrectly labelled screenshot were not counted as passes. Temporary Company diagnostic timer/title were removed. Existing authenticated sessions were preserved.

## Human actions and exact recommendation

1. Review this candidate using the preserved owner/Company sessions: Company Dashboard and Expenses, representative Projects/Contracts/Treasury/Attendance/Payroll/Reports, English/Arabic and narrow layout. Keep this review non-mutating. Complete MFA privately if normal session-freshness prompts recur.
2. Confirm final visual acceptance. The minor summary-container group-label issue is recorded as a non-blocking follow-up; no further technical blocker was found within this acceptance scope.
3. Separately authorize promotion of **only** `dpl_8Jvbmi1GFoVPNhG36CAf1ZGkCfHP` to the existing Production domain. This report and visual approval alone do not execute promotion.

Original rollback target remains `dpl_DC2wK34FdbWNsVtnqMCzb54uRwDh`, already serving the named Production site. No rollback or database restore is currently needed. New real financial operations, future modules and broader commercial operational readiness are not inferred from this read-only candidate acceptance.

## Completion classification

Business/accounting VERIFIED for non-mutating module/metric presentation and preserved engine; new financial postings NOT APPLICABLE to this read-only task. Security/authorization VERIFIED for actual owner/AAL2/Company identities, scoped reads and owner financial denial. Database VERIFIED unchanged; no schema work. Deployment VERIFIED existing READY candidate/accepted alias isolation; promotion DEFERRED. Testing VERIFIED targeted live routes/layout/keyboard and scoped contrast review; final human visual acceptance DEFERRED. Documentation VERIFIED with identity-specific evidence and explicit limits.
