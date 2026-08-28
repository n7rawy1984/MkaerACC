# Binding Multi-Tenant and White-Label Architecture

This decision is binding for all product and database work. MakerACC is an internal codename; the product is a reusable contracting-accounting platform for independent tenant companies, not bespoke software for one company.

## Tenant boundary

`Company` is the security and accounting tenant: Platform → Company → memberships → projects, parties, accounts, treasury, documents, journals, and future modules. Tenant-owned rows carry `company_id` directly or derive it only through an explicitly constrained parent. UUID knowledge never grants access. PostgreSQL constraints, RLS, and specialized commands remain authoritative.

A user may belong to multiple companies. P6A will restore the Auth session, load active memberships, enter the sole company automatically or require a tenant choice, and hold an explicit active-company context. A URL slug is routing context only and never authorization evidence.

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

- Company-scoped master, authorization, expense, journal, and command schemas.
- Auth profiles and multi-company memberships.
- Forced-RLS tenant isolation and negative cross-tenant verification.
- Company/project-consistent foreign keys and dimensions.
- Company/type/year accounting references.
- Company-aware P5A/P5B accounting commands and idempotency.
- Explicit multi-company synthetic Development fixtures.

## Planned, not implemented

- Active-tenant selector and frontend tenant context.
- Tenant settings, branding, slug, logo, theme, and favicon.
- Custom domains and branded documents/messages.
- SaaS licensing, entitlements, provisioning, and suspension UI.
- Enterprise isolated deployments.

Development/demo data remains explicit tenant fixtures and must never imply that synthetic Company A is the permanent platform company. Production never auto-seeds a real tenant.

## Refined P6 boundary

- **P6A — Auth Session and Tenant Context:** login/logout, session restoration, protected routes, active memberships, explicit active tenant, and multi-company selector.
- **P6B — Tenant Settings and White-Label Foundation:** company settings, stable slug, display identity, logo/favicon, CSS-variable theme, locale, and removal of Maker-specific visible branding.
- **P6C — Master Data Async Repository Cutover:** typed tenant-scoped queries and master-data commands.
- **P6D — Financial Flow Cutover:** frontend use of specialized financial RPCs with no hybrid writes.
- **P6E — LocalStorage Retirement and Production Data Mode:** explicit demo adapter, production fail-closed behavior, and removal of localStorage as production accounting authority.

P6 is not implemented by this decision record.
