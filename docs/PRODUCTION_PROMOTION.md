# Integrated Production promotion — 2026-11-02

Status: **PROMOTED — FOCUSED PRODUCTION SMOKE PASS**. Final human visual approval and promotion authorization were supplied explicitly. Minor refinements are accepted for future controlled releases.

## Deployment and integrity

- Live site: https://maker-eosin.vercel.app
- Exact existing candidate promoted: `dpl_8Jvbmi1GFoVPNhG36CAf1ZGkCfHP` (READY).
- Supported command executed once: `vercel promote dpl_8Jvbmi1GFoVPNhG36CAf1ZGkCfHP --scope n7rawy1984-8059s-projects --yes --timeout 60s`; exit0. No build or deployment was created.
- Fresh guards confirmed maker/project/team, prior Production target and READY rollback deployment before promotion. All272 accepted source hashes and frozen manifest digest `062346de07e0a9b3f8e89c6d0f95883536b75804ff213c38a3ad8dc59058c02a` match.
- Authoritative alias and project Production target now identify the approved candidate. Generated project alias remains on that candidate; `maker-git-main-n7rawy1984-8059s-projects.vercel.app` remains on the previous deployment. No unrelated aliases changed.
- Production HTML SHA256 exactly matches the protected accepted candidate, obtained through its existing authenticated browser: `364140954c5cff976361305995a876edf97e9fb173c1da0f4a517aba8742b039`; same `/assets/index-DRjc0twI.js` entry. A separately compiled local build has a different JS filename and is not the promotion artifact. An unauthenticated candidate request redirects to Vercel protection and was excluded from payload comparison.

## Production smoke results

- Ten HTTP/SPA routes return200 and the identical app entry without redirects: `/`, `/platform`, `/platform/subscriptions`, `/expenses`, `/projects`, `/subcontracts`, `/treasury-accounts`, `/attendance`, `/payroll`, `/accounting-reports`.
- Fresh isolated browser sessions require NARVO email/password sign-in on owner and Company routes; mutation requests were blocked in this diagnostic browser. Google browser login does not authorize NARVO.
- Real owner SDK identity: `naghamel7ayah@gmail.com`, UUID `ebcf7115-6cd9-49be-af25-8e57b5befd75`; AAL2/current and next; server PLATFORM_OWNER; step_up_required=false; zero Company memberships. Overview, Accounting Entities and Subscriptions load with no alerts/overflow at375 CSSpx Arabic RTL. Direct owner HEAD reads for accounts/expenses/journal_entries return0 each, preserving financial tenant boundaries. The prior different Chrome account was correctly denied with42501; owner sign-in/MFA was then completed privately. No administrative command submitted.
- Real Company SDK identity: `m.saed@admin.com`, UUID `6f67b7bf-e531-49b7-9839-a0167c9c582b`, Maker ACCOUNTING_ADMIN. Two active memberships and exactly two authorized visible companies; Company RLS scope matches memberships. Platform Owner RPC denied. This evidence is not attributed to the invited test recipient or MANAGEMENT_VIEWER.
- Company Dashboard, Expenses, Projects, Subcontracts, Treasury, Attendance, Payroll and Reports load through actual navigation, no alerts/overflow at1366 CSSpx English. Dashboard has6 sections,5 AVAILABLE,4 VERIFIED_ZERO,16 UNAVAILABLE,0 ERROR/LOADING. Zero shows0.00; unavailable shows—. Final Arabic RTL dashboard also has6 sections/no overflow.
- Existing Maker subscription stays UNMANAGED/FULL and legacy setup UNASSESSED; no false setup-complete claim. Expired/cancelled restrictions retain prior accepted lifecycle evidence with unchanged code/catalog; transitions were not repeated.
- Production and both approved Preview invitation origins return OPTIONS204 with exact restricted CORS; unknown origin403; anonymous Production POST rejected401 by JWT gateway. No authenticated invitation endpoint or email delivery invoked.

## Preservation and limits

Fresh before/after read-only fingerprints are identical: `440fbe12b57e635e55073994f600952fe56dae05ed711a5930b9972419bc5c7d`. All46 Company-owned tables, Companies/profiles/memberships/subscriptions, private administrative/receipt/counter tables, financial records,64 migrations and functions/RLS/grants/policies remain unchanged. Auth settings, secret metadata/digests, Edge Function metadata, Vercel environment/protection and272 application source files remain unchanged. Production still uses the explicitly approved shared Supabase `eqnzueginpkskbnqvgoc` / MakerACC-Development in supabase-auth mode; no demo fallback or project switch.

No migrations, business mutations, financial postings, subscription changes, invitation delivery, cleanup, RLS changes, commits, pushes or merges. Existing authenticated browser sessions preserved; temporary diagnostic titles/overlays removed. Financial command execution is outside these read-only smoke checks. Minor generic-div Expense summary aria-label issue remains accepted for later correction; full assistive-technology certification and broader commercial operational readiness are not claimed.

## Rollback readiness

Rollback was **not needed or executed**. Previous deployment `dpl_DC2wK34FdbWNsVtnqMCzb54uRwDh` was confirmed READY in the same project before promotion. For an approved rollback or a release-breaking failure within this authorization, run `vercel rollback dpl_DC2wK34FdbWNsVtnqMCzb54uRwDh --scope n7rawy1984-8059s-projects --yes`, then read authoritative main-domain/project target metadata and repeat focused authentication/SPA smoke checks. Inspect unrelated aliases afterward. Frontend rollback does not undo database operations; none occurred in this release.

## Definition of done

Business/accounting VERIFIED for unchanged engine/read-only presentation; new posting tests NOT APPLICABLE. Security/authorization VERIFIED for actual identities/AAL2/membership scope/denials. Database VERIFIED unchanged; migration work NOT APPLICABLE. Deployment VERIFIED exact accepted candidate promoted and unrelated aliases preserved. Testing VERIFIED focused Production HTTP, browser, CORS and no-mutation checks; full lifecycle reruns NOT APPLICABLE. Documentation VERIFIED with attached evidence. Minor accessibility refinement and broader commercial operational readiness DEFERRED.

Evidence: [execution result](release/production-promotion/result.json), [candidate acceptance](PRODUCTION_CANDIDATE_ACCEPTANCE.md), [manifest](release/controlled-production-candidate-manifest.json). Screenshots: [Company dashboard](release/production-promotion/production-company-dashboard.png), [owner subscriptions](release/production-promotion/production-owner.png).
