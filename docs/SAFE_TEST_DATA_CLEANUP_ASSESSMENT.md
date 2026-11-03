# Safe Test Data Cleanup Assessment

2026-11-02, Asia/Dubai. **CLEANUP BLOCKED — NO-GO for execution.** Authorized hosted activity was GET/SELECT only, inside explicit READ ONLY transactions. No data, lifecycle, subscription, membership, Auth identity, migration, deployment or Git-history operation was changed by this assessment.

## Exact inventory and classification

The shared MakerACC-Development project contains18 Companies,290 Auth users,290 profiles,281 memberships (275 active/6 inactive),2 platform-administrator records (one active owner/one inactive historical principal),1 platform entity,0 Commercial Customers/associations,1 accepted invitation,1 subscription,1 provision,1 MFA factor,0 Storage buckets and0 Storage objects. There are64 applied migrations; local migration65 remains unapplied. Metadata covered99 tables,278 foreign keys and54 Company-owned table dimensions.

| Company classification | Count | Proposed treatment |
|---|---:|---|
| KEEP — protected | 3 | Maker, retained invitation Company, and synthetic demo Company required to preserve the accounting account's other membership. Retain unchanged. |
| CANDIDATE_DELETE | 12 | Older P2/P3/P4 test Companies; confirmed fixture provenance, no journals or source documents. **Candidate classification does not mean a supported deletion path exists.** Prefer separately approved archival. |
| REVIEW_REQUIRED | 3 | Two P5A Companies and the already-inactive payroll race Company retain immutable accounting history. No purge or automatic archival. |

| Auth classification (disjoint; totals290) | Count |
|---|---:|
| KEEP | 66 |
| SHARED_IDENTITY | 3 |
| REVIEW_REQUIRED | 212 |
| CANDIDATE_DELETE | 9 |

**70 distinct Auth UUIDs are excluded from deletion in the sealed proposal:**14 protected access dependencies,55 additional necessary historical actors, and1 further shared-only identity. This includes one of the212 REVIEW_REQUIRED users marked **PROTECTED_PENDING_REVIEW** because personal ownership is unresolved. Protection is an additional flag, not a fifth additive classification. The four current protected human roles and the former Maker-provisioning administrator resolve to five core UUIDs; closure expands protection conservatively.

Security baseline:342 session rows for288 distinct Auth UUIDs,429 refresh rows (430 at postflight),347 AMR claims,15 MFA challenges and0 Auth audit-log rows. The platform retains13 events, source audit217, Attendance audit14 and Payroll audit22. Provider log-service retention was not audited; no security/audit pruning is proposed.

The nine Auth candidates are inactive, profile-only initial P2 diagnostic identities: no memberships, platform administrator role, application/financial attribution or owned Storage objects. Their observed dependencies total9 profiles,9 Auth identities,9 sessions,9 refresh rows and9 AMR claims, with0 MFA factors and0 owned Storage objects. Their precise dependencies are in the private report. The other users are not automatically disposable because their Company is a candidate or their address looks synthetic.

## Protected relationships and actual versus stale data

Authoritative joins resolve Maker's Accounting Admin and unique MANAGEMENT_VIEWER (the Barq/Bareq protection binding), the current ACTIVE PLATFORM_OWNER, the retained Company's invitation accepter, and the former administrator who created Maker and its historical source records. Display names alone were not used. The retained invitation is ACCEPTED and matches its actual Auth recipient and active Accounting Admin membership.

The protected accounting account also belongs to the synthetic demo Company. Removing that Company would violate the instruction to retain the account's memberships. The proposal therefore keeps that whole Company and its historical dependencies, rather than silently removing the extra membership. The former inactive platform administrator remains necessary to Maker's source/audit integrity; do not delete or reactivate it as cleanup.

Maker has248 historical source records,217 source audit rows,2 projects,2 contracts,18 categories and other protected masters despite having no posted journals. The retained invitation Company has11 foundation accounts,1 Treasury,1 provision and its TRIAL subscription. Both stay intact. The demo holds115 journals and includes protected-account activity.

All528 journals/1102 lines across the project are retained; the fresh balance check finds0 unbalanced journals. There are142 Expenses and248 historical source records. The payroll race Company contains4 reversal-preserved journals and is intentionally inactive; net-zero/reversed history is not disposable history. The two P5A Companies contain395 and14 journals. Existing master rows and many test Auth accounts remain real database records even if they originated as fixtures.

The12 Company candidates are corroborated by P2/P3/P4 documentation, reserved test-domain Auth memberships, and matching run markers in every membership—not their displayed names. Across them,51 memberships and their actual master/assignment/settings rows require preservation or a separately reviewed disposition. The nine profile-only Auth users match the P2 report's initial unsuccessful diagnostic batch. None of this proves that every old fixture is no longer needed by regression tests; owner approval must retire those dependencies explicitly.

## Supported cleanup architecture

Source and hosted function definitions/grants were inspected; no administrative command was invoked.

| Operation | Actual support and boundary |
|---|---|
| Company archival | Supported by owner `set_lifecycle`: ACTIVE/SUSPENDED/DRAFT→ARCHIVED under allowed transitions. Sets Company INACTIVE, freezes normal access, retains rows, invalidates relevant invitations and appends audit/idempotency evidence. Legacy administrative metadata can be adopted lazily; this is not accounting provisioning. |
| Company suspension/deactivation | Supported lifecycle operation; also freezes access. Not an accounting settlement/closure workflow. |
| Accounting closure | No dedicated complete financial close-and-purge workflow found. Do not equate archival with settling liabilities or closing books. |
| Company physical deletion | **Missing.** No console command, browser grant or reviewed purge workflow. Existing dependencies prevent a direct parent operation. |
| Membership revocation | Supported through `set_membership`/REVOKED: marks membership INACTIVE and invalidates stale invitations; does not erase membership history. Last-active-admin/self/privileged guards apply. |
| Application user deactivation | Supported through `set_user_status`: profile INACTIVE, invitation invalidation and session revocation. Global user impact; last-admin and privileged/self guards. Not Auth/profile deletion. Nine Auth candidates are already inactive. |
| Profile/Auth user deletion | **Missing from the console.** `profiles.user_id` references Auth with ON DELETE RESTRICT. Even otherwise-unused candidates cannot be safely removed through a direct Auth call while their profiles remain. No bypass or invented browser deletion path is proposed. |
| Invitation revocation | Supported for applicable pending invitations; the sole retained invitation is ACCEPTED/protected. No revocation or resend proposed. |

The FK catalog has219 RESTRICT,31 NO ACTION,25 CASCADE and3 SET NULL edges. Company settings have a Company CASCADE, but most relevant Company/financial edges restrict deletion. Auth has provider-managed cascades; profiles restrict Auth deletion. Storage has delete-protection triggers. These are existing dependencies, not permission to trigger cascades. Immutable journals/audit and no-delete payroll/attendance guards must remain enabled. The inspected Companies, memberships, profiles, journals and platform audit tables grant no DELETE to authenticated, anon or service_role. A service-role credential is not a safe purge strategy.

Future Auth deletion, if separately designed and approved, must review the profile restriction, identity/session/AMR/refresh dependencies, non-FK references and Storage ownership explicitly through a trusted operator mechanism. Supabase documents that deleting a user does not immediately invalidate an issued JWT, and owned Storage objects can block deletion. [Official Auth guidance](https://supabase.com/docs/guides/auth/managing-user-data). No such workflow is implemented or authorized here.

## Recovery gate

Fresh backup metadata again lists **no available backup**, PITR disabled, WAL-G enabled, and no restore window. No isolated restoration evidence for the current shared project, protected Auth/MFA and current accounting state was demonstrated. Existing local native-clone/test rehearsals do not establish current full-project disaster recovery. The prior R0 assessment reaches the same limit. A provider flag alone is not recovery assurance.

Before any cleanup: approve backup scope/frequency/retention, secure artifact/location, incident/restoration owner, RPO/RTO and an isolated restore rehearsal. Verify Maker, protected identities/MFA/memberships, retained invitation/subscription/provision, complete source/financial history, schema/history/grants and application authorization. Include Auth, private data, required configuration and independently protected Storage objects if any appear. Supabase backups do not contain uploaded object bytes; a live restore entails downtime. [Official backup scope/process](https://supabase.com/docs/guides/platform/backups). No backup was created, downloaded or restored here.

## Proposed execution sequence — gated, not executed

1. Review the private UUID inventory, allowlist and sealed denylist. Resolve PROTECTED_PENDING_REVIEW ownership; retain it meanwhile. Confirm retirement of the12 old test runs and identify regression scripts/accounts still relying on them. Do not expand an allowlist from a name/prefix or Company membership alone.
2. Demonstrate recovery in an explicitly authorized isolated target. Obtain product-owner approval for the exact operation scope and UUID set, maintenance window, expected effects, operator and rollback/reopening procedure. This assessment grants no execution authority.
3. Refresh project identity, schema/history, dependencies, balances, exact counts, candidate lifecycle/version, protected fingerprints and Storage ownership. Compare the immutable denylist SHA256; halt on overlap or unexplained drift. Quiesce/attribute concurrent activity without changing protected sessions as a diagnostic measure.
4. Preferred first cleanup stage: **archive only the12 allowlisted Companies** using existing owner UI/actions with genuine MFA, reviewed version/reason and unique idempotency receipts, one Company at a time. Preserve all rows/memberships/Auth identities, financial records and audit. No archival of the3 protected or3 financial-review Companies. No “remove all test users” operation.
5. Recheck protected records and financial/source fingerprints independently after each action and as a batch. Archival is reopened through ARCHIVED→SUSPENDED→ACTIVE only when separately authorized and its existing active-admin rules are satisfied; do not invent an alternate status patch.
6. Auth candidates remain nine separately reviewed inactive identities. **Stop before Auth/profile deletion:** recovery and owner approval are necessary but insufficient; a supported, reviewed profile/Auth dependency-handling mechanism must first be designed/tested. No direct Auth API call, profile SQL operation, constraint disabling or cascade is proposed for execution in this package.
7. Physical Company removal is likewise deferred until a separately reviewed supported capability exists and every exact child/audit/invariant dependency has an approved disposition. Do not remove posted history, weaken immutability or manually remove application records merely to satisfy a foreign key.
8. Record actual outcomes, authorized audit deltas, independently verified preservation and deferred items. No migration65, release deployment or subscription change is part of cleanup. Archival retains Companies and does not satisfy their commercial-readiness requirements.

Required approvals: exact Company archival list and fixture retirement; protection/ownership decisions; demonstrated recovery and restore authority; execution window/operator/expected side effects; and separate future design/execution approvals for any profile/Auth or physical Company removal. No approval is requested to execute an unsupported path.

## Expected counts and independent verification

| Scenario | Companies | Auth users/profiles | Memberships | Other expectations |
|---|---:|---:|---:|---|
| This read-only assessment | 18 | 290/290 | 281 | No cleanup occurred. |
| Recommended future12-Company archival only | 18 (5 ACTIVE/13 INACTIVE) | 290/290 | 281 |13 platform entities after12 lazy adoptions;25 events/20 requests if exactly12 new successful lifecycle requests, with no unrelated activity. Subscriptions1/provisions1/accepted invitations1 unchanged. |
| Nine Auth removals, only after a separate supported mechanism/approval | 18 | 281/281 | 281 | Conditional arithmetic; existing profile restriction and provider dependencies remain blockers. Not part of recommended archival execution. |
| Unsupported physical removal of12 Companies | 6 | Never automatically reduced | 230 | Arithmetic only, not an executable plan; violates current workflow constraints until separately resolved. |

Posted journals528, lines1102, sources248, Expenses142 and all protected fingerprints must remain intact in the recommended archive-only scenario. Actual token/session and audit counts can change through legitimate authorized activity; verify expected UUID-bound changes rather than manufacturing an all-Auth-byte-identical claim.

Private `post-cleanup-validation.sql` provides independent SELECT-only checks for protected Company/Auth/profile/membership/MFA identity, accepted invitation, subscription/provision/accounts/Treasury, candidate archival states, journal balance, orphan rows, migration history, global roles and Storage. `protected-company-validation-query.sql` returns table/Company hashes for comparison to the saved protected baseline, plus protected Company/profile/administrator/permission hashes. Re-running these queries is verification, never cleanup execution. Review exact immutable audit rows/receipts as retained evidence; permitted new lifecycle events must be additive.

## Evidence and limitations

Secure local package: `/tmp/narvo-cleanup-assessment-20261102/` (directory0700; inventory/report files0600). `REPORT.md` contains explicit protected Company IDs and core Auth UUID bindings; structured files classify all18 Companies/all290 users and enumerate all70 excluded Auth UUIDs. Exact candidate allowlist, per-Company FK/row dependencies, per-user FK/non-FK references and Auth candidate provider dependencies are separate files. `protected-denylist.immutable.v1.json` and its SHA256 file are sealed read-only0400; treat this version as immutable and issue a new version for future additions. File permissions/digest are local change controls, not hosted enforcement or a tamper-proof filesystem guarantee. These UUID artifacts are not copied into the repository; `/tmp` is temporary and must not be mistaken for a backup.

Initial inventory:2026-11-02 18:23:21 UTC; postflight inventory:18:33:13 UTC. All64 public/private application-table fingerprints and sanitized identity/membership/admin/invitation/subscription/provision/MFA inventories match. Auth refresh rows changed429→430; a separate read-only attribution finds one new row for the protected accounting UUID at18:27:46 UTC. This is concurrent Auth activity outside the read-only assessment, not a cleanup write; no token value was read. Do not describe all hosted Auth state as unchanged. No storage objects exist at this snapshot; future objects or external-service identity use require renewed assessment.

VERIFIED: authoritative identity/dependency inventory; classification; supported-operation source/catalog/grant review; balances and preservation; documentation. DEFERRED/BLOCKED: recovery demonstration, owner decisions, any cleanup execution and missing deletion mechanisms. NOT APPLICABLE: application implementation/build, migration dry-run/application, deployment and full pre-production audit. No product/security/accounting logic changed; no destructive test was used as evidence.

[Verification result](release/safe-test-cleanup-assessment-result.json).

**Final recommendation: CLEANUP BLOCKED. Retain the protected graph, obtain demonstrated recovery, then consider only separately approved supported archival. Nine Auth identities are candidates for future design review, not approved deletions.**
