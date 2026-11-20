# Procurement I1 — Purchase orders and commercial commitments

2026-11-20. Product implementation continues from published release5689e2aa86b9793d58f405f55b302ee0be578eeb, clean `develop/narvo` in the new NARVO repository. Hosted106 is applied, read-only verified. CR-07, V1 remediation, Docker and historical simulations were not reopened.

## Capability and workflow

`/purchase-orders`, linked under Inventory, completes this bounded missing procurement capability:

1. Procurement or Accounting selects the existing Supplier, optional Project and catalog Material or explicitly described service.
2. Enter actual order date, optional expected delivery, instructions/terms and up to50 lines. Catalog lines use their existing base unit; service lines use an explicit unit. Incomplete drafts can be saved and completed under the same document identity.
3. Save Draft → Review. Review requires an active Company Supplier, available Project/materials, complete descriptions/units, positive quantities and a positive quoted total.
4. Authorized Accountant/Accounting Admin with `accounting.post` selects Approve & Issue, sees the exact reference/version/amount, and confirms. Procurement cannot issue through UI or direct RPC.
5. Read-only details show quoted lines, current state and complete version/actor history. Shared Arabic/English Excel and printable PDF outputs carry Company, Supplier, dates, Project, state, terms and totals. Cancellation requires an audited reason; only an authorized accountant can cancel an issued order. Issued or cancelled contents cannot be edited or reactivated; editing reviewed content returns it to Draft.

References use the canonical Company `PO` counter. Whole-request idempotency and document versions prevent repeat effects; lost responses recover the same frozen actor/Company request. Company serialization and locked active memberships/profiles protect concurrent approvals and authorization changes. Exact stale-state errors prevent two approvals from issuing two commitments.

## Accounting and scope

A purchase order is a commercial commitment, **not** an invoice, payable, inventory receipt, Project cost, payment, input VAT claim or GL journal. The existing receiving, Inventory/GRNI, Supplier AP and payment workflows remain the authoritative recognition/settlement commands. Links provide access to those existing workspaces; no automatic receipt, invoice or financial document is created or matched by a PO.

Quoted prices and commitment totals are AED **excluding tax**; no tax entitlement is inferred. Quantities reuse six-decimal integer micros; monetary totals are constrained BIGINT minor units with exact integer snapshot values. Server arithmetic rounds once per line, half up, then sums lines; client totals are never accepted. Example:2.5×12.00=30.00,0.333333×3.01=1.00, total31.00. Negative quantities/prices, ambiguous dates, overflow and unsupported fields are rejected.

The issued commitment metric includes all currently issued orders, including those physically fulfilled outside this register. It is explicitly not an outstanding commitment/payable balance. Listing is paginated with full Company counts and issued totals; table filters/search are explicitly page-scoped. No warehouse stock or GL balance is guessed. PO creation does not require invented funding or an open financial posting period, because it posts nothing. Existing commercial readiness/subscription controls still govern new purchasing; allowed cancellation creates no financial reversal.

## Reused architecture and security

Existing Supplier, Project, inventory Material/base-unit masters; Company workspace/router/navigation; DataWorkspace tables/drawers/date/money cells; Lucide icons; request-recovery conventions; shared Excel/PDF infrastructure; canonical Company role/permission helpers, operational serialization, reference allocation and immutable evidence trigger. No new UI framework, accounting engine, master catalog or tenant-specific branch.

Additive107 creates one append-only, forced-RLS `purchase_order_events` table, private validation helper and protected command/read/history RPCs. Active Company membership/profile and explicit Procurement/Accounting roles are required for writes; Management Viewer is read-only. Supplier/Project FKs are Company-consistent; catalog IDs are validated against that same Company. Anonymous/foreign actors and direct inserts are denied. Private helper has no browser grant; all definer functions use an empty fixed search_path. No existing financial function, RLS policy, table or journal is rewritten.

## Verification and remaining scope

Focused local database cases cover incomplete/completed drafts, review invalidation, exact rounding, issuance, cancellation, replay/changed intent, stale state, invalid/foreign masters, unit validation, overflow, future/ambiguous dates, role/tenant/direct-write denial, immutable events, complete audit, pagination and unchanged GL/stock. Independent native sessions verify a real lock wait, one successful issue and one rejected stale issue. Production-component browser cases cover English/Arabic entry/review/approval, usable drawer/preview transition, post-commit lost-response recovery, read-only audit, shared exports and390px RTL. Rendered screenshots inspected. Actual Excel totals and PDF content independently checked.

Existing fictional accounts, journals/lines, Treasury, memberships and stock remain unchanged. All data writes are confined to disposable local fixtures; no hosted Company, financial transaction, configuration or migration was changed. The previous85-scenario/183-check evidence is preserved and not rerun. Browser tests use synthetic local Auth as focused UI regressions, not a new claim of hosted authenticated acceptance.

**Remaining procurement scope:** purchase requisitions/RFQ, alternate-UOM ordering, PO-linked partial receipts/returns and quantity/invoice matching, amendments after issue, fulfillment/open-commitment reporting. Existing Inventory/GRNI/AP capability is retained; this release does not claim those new PO associations. Private documents, advanced HR/WPS, statutory tax outputs, specialist accounting and final security/operations/DR requirements remain on the original roadmap.

## Release gates / Definition of Done

- Business/accounting VERIFIED for nonfinancial purchasing commitments and stated boundaries.
- Security/authorization VERIFIED through focused role/tenant/direct-write/version/concurrency checks; previous financial invariants untouched.
- Database VERIFIED locally;107 PREPARED, NOT APPLIED. Hosted canonical history is106; only107 locally pending. No hosted dry-run or activation was performed; linked dry-run/preservation belongs to separately authorized activation.
- Testing VERIFIED in `purchase-orders-verification.json` and `purchase-orders-evidence/`; TypeScript/Production build recorded there. Three focused React state/effect/ref advisories and existing bundle-size advisory are non-blocking and do not weaken runtime guards.
- Deployment DEFERRED: approve107 activation first, then manually publish compatible release and perform a focused hosted route smoke check. No automatic push/deploy.
- Documentation VERIFIED: roadmap, handoff, requirement INV-01 and completion matrix updated without replacing the original roadmap. Full commercial readiness is not asserted by completing this milestone.
