# Binding Multi-Tenant and White-Label Architecture

This decision is binding for all product and database work. MakerACC is an internal codename; the product is a reusable contracting-accounting platform for independent tenant companies, not bespoke software for one company.

Repository-root `AGENTS.md` is the binding engineering constitution governing implementation discipline, accounting invariants, proportional security review, and verification. This architecture record remains the detailed multi-tenant/white-label decision source.

## Tenant boundary

`Company` is the security and accounting tenant: Platform → Company → memberships → projects, parties, accounts, treasury, documents, journals, and future modules. Tenant-owned rows carry `company_id` directly or derive it only through an explicitly constrained parent. UUID knowledge never grants access. PostgreSQL constraints, RLS, and specialized commands remain authoritative.

A user may belong to multiple companies. Completed P6A restores the Auth session, loads active memberships, enters the sole company automatically or requires a tenant choice, and holds an explicit active-company context. A URL slug is routing context only and never authorization evidence.

`SYSTEM_ADMIN` remains platform/configuration administration and receives no automatic browser access to tenant financial data.

## One codebase and deployment model

All tenants use one application codebase and canonical migration history. Tenant differences belong in company master data, system-account mappings, permissions, settings, branding, and later feature entitlements—not copied pages, tenant UUIDs, tenant-specific journals, or `if company === ...` branches.

The default commercial topology is a shared application/database with strict RLS isolation. The same code and migrations may later run for an enterprise tenant in a dedicated Supabase project/environment/domain. Isolated deployment must not require an accounting fork.

## White-label configuration

P6B will add tenant-controlled settings for display/business name, legal name, logo, favicon, primary/accent colors, optional secondary/background and login branding, default locale, and a stable tenant slug. Branding will drive CSS variables and shared React surfaces.

The tenant slug is distinct from accounting `Company.code`; company code can change for business reasons and is not a public routing identity. Custom domains, email/PDF/report branding, feature flags, and plan presentation are later additions.

## Commercial platform layer

Subscription/license status, plan, entitlements, tenant provisioning/suspension, custom domains, platform administration, and centralized customer management are deferred platform concerns. They remain separate from accounting truth. A plan or license change must never rewrite or invalidate financial history.

## Implemented now

- Company-scoped master, authorization, expense, Supplier Payment, Custody Advance, Settlement, Cash Return, Subcontractor Advance, Subcontractor Certificate/deduction, journal, and command schemas.
- Auth profiles and multi-company memberships.
- Forced-RLS tenant isolation and negative cross-tenant verification.
- Company/project-consistent foreign keys and dimensions.
- Company/type/year accounting references.
- Company-aware P5A–P5G accounting commands and idempotency, including pooled company/Custodian balance enforcement, no-GL Settlement grouping, and contract-isolated Subcontractor Advance/Certificate balances.
- Explicit multi-company synthetic Development fixtures.
- Verified P6A Auth/session lifecycle, active tenant context, protected routes, tenant switching, and strict production-auth/local-demo isolation.

## Planned, not implemented

- Tenant settings, branding, slug, logo, theme, and favicon.
- Custom domains and branded documents/messages.
- SaaS licensing, entitlements, provisioning, and suspension UI.
- Enterprise isolated deployments.

Development/demo data remains explicit tenant fixtures and must never imply that synthetic Company A is the permanent platform company. Production never auto-seeds a real tenant.

Custody is an accounting control balance scoped by company and Custodian; Project is analytic rather than an authorization or per-Advance allocation bucket. P5D funding and P5E Cash Return are Treasury-only. Settlement groups already-posted Custodian Expenses without a journal, and Cash Return is independently auditable. Owner Current funding and Custody-funded Supplier Payments require separately reviewed commands and must not be inferred from localStorage legacy `CASH`/`BANK` values.

Subcontractor Advances are Treasury-funded recoverable Assets scoped by company and one P3 Subcontract, never pooled merely by party. Both journal lines preserve Project and Subcontract; the control debit also preserves Subcontractor Party and the funding credit preserves Treasury. New funding requires an `ACTIVE` Subcontract. P5G Certificates may post on `ACTIVE` or `COMPLETED` Subcontracts, recognize contract-scoped cost/VAT/retention/recovery/deductions/payable, and create no cash movement. `CLOSED` Subcontracts/Projects receive no new Certificate accounting. Final Subcontractor Payment and Retention Release remain later flows.

## Refined P6 boundary

- ✅ **P6A — Auth Session and Tenant Context:** verified complete on 2026-09-04; login/logout, session restoration, protected routes, active memberships, explicit active tenant, and multi-company selector.
- **P6B — Tenant Settings and White-Label Foundation:** company settings, stable slug, display identity, logo/favicon, CSS-variable theme, locale, and removal of Maker-specific visible branding.
- **P6C — Master Data Async Repository Cutover:** typed tenant-scoped queries and master-data commands.
- **P6D — Financial Flow Cutover:** frontend use of specialized financial RPCs with no hybrid writes.
- **P6E — LocalStorage Retirement and Production Data Mode:** explicit demo adapter, production fail-closed behavior, and removal of localStorage as production accounting authority.

P6A is implemented and verified complete as recorded in `docs/P6A_AUTH_TENANT_CONTEXT.md`; P6B–P6E remain planned and unimplemented.

## Pre-production integrity gate

Before real production accounting data or go-live, the read-only **Production Security & Accounting Integrity Audit** defined in `AGENTS.md` must be completed. It covers tenant/Auth/RLS isolation, financial command abuse and concurrency, journal/reversal/dependency integrity, immutable history, storage/report leakage, secrets/configuration, white-label/custom-domain tenant confusion, and financial reconciliation. This is a planned gate, not an implemented feature or a completed audit.
