# P5G Subcontractor Certificates

P5G is implemented by `20260906123000_p5g_subcontractor_certificates.sql`, after the pre-P5G P5F lifecycle correction `20260906120000_p5f_active_contract_advances.sql`. Both are applied only to synthetic-only `MakerACC-Development`.

## Document, lifecycle, and authority

`subcontractor_certificates` stores an atomic `SCERT` reference, contractor Certificate number, date, constrained company/Project/Subcontractor/Subcontract identity, cumulative work input, current variation, requested recovery, VAT evidence, immutable calculated components, lifecycle, journal links, and actors. `subcontractor_certificate_deductions` stores immutable normalized lines.

Accounting Admin and Accountant may create a `DRAFT`; it has no calculated posting components and no journal. Only Accounting Admin has `certificate.approve_post` and may approve/post. Posted economics are immutable. Accounting Admin may reverse an otherwise unconsumed Certificate through an exact P5A inversion. P5H must add a live-payment dependency check before consuming Certificate payable; no payment rows were invented in P5G.

`ACTIVE` and `COMPLETED` Subcontracts may receive Certificates because final certification, Advance recovery, retention recognition, and liability cleanup remain legitimate after physical completion. `CLOSED` Subcontracts and closed Projects reject new approval. An inactive Subcontractor may still have an existing valid contract certified so deactivation cannot suppress a real obligation. New Advance funding is separately restricted to `ACTIVE` contracts.

## Authoritative calculation

The command locks the Subcontract, derives prior cumulative work from live posted Certificates, and calculates in `NUMERIC` before storing validated `BIGINT` minor units:

- Current work = work value to date − authoritative prior work value to date.
- Gross current Certificate = current work + current variation.
- Retention = gross × P3 Subcontract retention basis points ÷ 10,000, rounded once.
- Net before VAT = gross − retention − same-contract Advance recovery − mapped deductions.
- VAT is zero, manual, or AUTO 5% of net before VAT, matching the established local Certificate waterfall.
- Payable = net before VAT + VAT.

The cumulative sum of live posted gross Certificates cannot exceed original contract value plus approved variations. The locked Subcontract serializes simultaneous approvals, so concurrent Certificates cannot bypass that cap. Caller-supplied previous work, retention, VAT total, deduction account, or payable is never accepted.

Recoverable VAT greater than zero requires the received flag, invoice number, and invoice date. Reversal uses the already-rounded original lines exactly.

## Accounting equation and mappings

Posting creates no Treasury/cash line:

- Dr `PROJECT_COST_SUBCONTRACTORS` for gross current certified work.
- Dr `INPUT_VAT` only when recoverable evidence exists.
- Cr `SUBCONTRACTOR_RETENTION_PAYABLE`.
- Cr `SUBCONTRACTOR_ADVANCE` for recovery.
- Cr each mapped deduction Revenue account.
- Cr `SUBCONTRACTOR_PAYABLE` for the residual.

Every line preserves Project, Subcontractor Party, and Subcontract. Advance availability is the P5F journal-derived company/Subcontract balance. The Subcontract lock prevents concurrent over-recovery; reversal restores it.

The only supported deduction types are the existing local-domain `COMPANY_MATERIALS`, `BACKCHARGE`, and `OTHER`. `certificate_deduction_account_mappings` is the smallest trusted per-company type-to-active-Revenue-account configuration. Browser callers submit type, description, and positive amount only; arbitrary account UUIDs are never accepted. Mapping configuration is service-managed and read-only to accounting users.

## Security and verification

All three P5G tables have forced RLS. Accounting Admin, Accountant, and Management Viewer have company-scoped SELECT. Project Manager, Procurement, Data Entry, System Admin, other tenants, and anonymous callers receive no raw rows. Direct Certificate/deduction writes and private kernel execution remain denied. Commands use fixed empty search paths.

The definitive hosted matrix passed **134/134** cases. It covered draft/no-GL behavior, exclusive approval, exact cost/VAT/retention/recovery/deduction/payable lines, evidence, integer bounds, P5F active-only funding, `COMPLETED` Certificate posting, closed/inactive lifecycle, cumulative cap, simultaneous recovery and cap attempts, idempotency, atomic references, immutability, reversal, role/RLS/tenant isolation, and same-party multi-contract separation.

Trusted whole-scope reconciliation found zero orphan original/reversal links, unbalanced Certificate journals, duplicate original sources, Treasury lines, or missing Party/Project/Subcontract dimensions. Drafts had zero journal links. Database types were regenerated.

## Boundary

P5G adds no Subcontractor cash/payment settlement, Retention Release/payment, alternate Supplier Payment funding, frontend Supabase path, Payroll, client AR/revenue, P6, or import. The exact next proposed batch is separately reviewed **P5H Subcontractor Payment**. It has not started.
