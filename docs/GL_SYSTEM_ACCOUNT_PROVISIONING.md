# Protected GL and system-account provisioning

2026-10-08. Implementation and focused Development verification complete; real account provisioning remains a separate authorized operational step.

## Gap and smallest architecture

Accounts previously supported Company-scoped reads and name-only browser edits. Authenticated INSERT and system-key UPDATE remain denied. No GL creation/system-mapping command existed. Existing protected service-role account INSERT, private platform registry, Company schema, enums, unique indexes and constraints suffice: no migration, RPC, UI, RLS change or new grants are necessary.

`scripts/admin/provision-gl-accounts.mjs` follows the existing bootstrap/Company operator tooling pattern. It generates owner-only reviewed SQL outside Git and optionally executes it with explicit `--apply`. The CLI checks the linked project and pins execution to MakerACC-Development `eqnzueginpkskbnqvgoc`. No credentials are input fields or browser artifacts. Raw generated SQL must remain operator-controlled; its comment does not independently constrain a database owner to Development.

Only new GL accounts can be created. Optional protected system keys are assigned on INSERT, not through an existing-account reassignment command. No upsert, overwrite, reactivation, code/type/Company mutation or system-key takeover is supported. Existing account identity, name-edit behavior and financial formulas are untouched. Parent-account/hierarchy editing, bilingual schema, maintenance console, remapping, financial transactions and Treasury creation are outside this tool.

## Authority and database validation

Protected operator identity, MFA and fresh session must be verified out of band before `--operator-session-verified`. This flag is an operational attestation, not authentication; an operator UUID is provenance, not proof of login. Execution requires the existing trusted protected connection (`postgres` or `service_role`) and an ACTIVE private registry identity joined to an ACTIVE Auth-backed profile. Neither Company ACCOUNTING_ADMIN nor SYSTEM_ADMIN can execute the generated block as authenticated. Platform operators need no Company accounting membership. No browser self-elevation or cross-tenant financial permission is added.

The independently supplied `--approved-company-id` must match the JSON Company UUID. The database additionally verifies the exact expected Company code and ACTIVE status, and locks the Company FOR UPDATE to serialize provisioning and concurrent deactivation. Shared profile/registry locks protect the authority checks for the transaction. Approved Company is explicit and reusable; no Maker UUID or accounting special case is hardcoded in production tooling.

Each code/name is trimmed and length-validated. Canonical account types are ASSET/LIABILITY/EQUITY/REVENUE/EXPENSE. Status is fixed ACTIVE; new UUID/timestamps come from existing defaults; operator creation/update provenance is derived from the reviewed operator identity. Ordinary accounts may have a NULL system key. requires_party is an optional explicit boolean, default false; later business commands retain their own dimension checks.

Input and SQL both validate system-key/type compatibility. Supported existing keys: INPUT_VAT/CUSTODY_ADVANCE/SUBCONTRACTOR_ADVANCE → ASSET; SUPPLIER_PAYABLE/SUBCONTRACTOR_PAYABLE/SUBCONTRACTOR_RETENTION_PAYABLE/SALARY_PAYABLE → LIABILITY; PROJECT_COST/PROJECT_COST_SUBCONTRACTORS/COMPANY_EXPENSE → EXPENSE. These are existing canonical accounting meanings (including the existing SALARY_PAYABLE database constraint), not new accounts or financial treatment. Actual hosted enum casts reject unknown keys/types. OWNER_CURRENT is not supported because this discovery did not establish a frozen account-type rule for it; no owner-account policy is invented. Additional keys require deliberate tool validation updates; they are never accepted by name inference.

Case-insensitive trimmed Company code uniqueness and Company system-key uniqueness are checked before INSERT and remain enforced by existing unique indexes, including inactive identities. Entire batches are atomic: a later failure rolls back earlier inserts. Replay fails on duplicate identity; uncertain execution must be authoritatively reconciled before retrying. Trusted database owners remain inherently privileged, as with existing provisioning; this is not a sandbox against a malicious owner.

## Operator procedure

1. Approve the explicit Company and account business values and verify executing operator identity/MFA/fresh protected session. Confirm Development link. Actual Maker GL accounts are not approved for execution in this implementation checkpoint.
2. Place input JSON outside Git with only operator_user_id, company_id, expected_company_code and a nonempty accounts array. Each account accepts code, name, account_type, optional system_key and optional requires_party. No credentials, balances, caller-chosen account UUIDs, status or financial inputs. Existing schema has a single name field.
3. Generate and inspect a rollback preview:

   ```sh
   node scripts/admin/provision-gl-accounts.mjs /protected/gl-input.json /protected/gl-preview.sql --approved-company-id APPROVED_COMPANY_UUID --operator-session-verified --rollback
   ```

4. After review, generate a new output with the same flags plus `--apply` for rollback rehearsal. A separately approved final operation uses a new output path, `--apply` and no `--rollback`. Output overwrite is refused; file mode is 0600. The CLI never accepts a caller-provided target database URL/ref or arbitrary SQL file for execution.
5. Verify created account UUIDs, type/key/provenance and unchanged financial history. Create any real Treasury later through existing `create_treasury_master`, using an ACTIVE ordinary ASSET GL with NULL system key, requires_party=false and no prior Treasury mapping. No opening balance or funding operation is included.

## Verification performed

- 43 focused generator/CLI assertions PASS: required Development target, explicit Company approval and session attestation; input shape, UUIDs, canonical types, all supported key/type pairs, duplicate input code/key, unsupported/forged fields, SQL literal/delimiter handling, rollback/commit generation, preview equivalence, owner-only output, overwrite refusal, and no mutation beyond account INSERT. Node syntax and focused oxlint PASS.
- 26 hosted checks PASS in one Development rollback-only transaction using random synthetic Companies, an uncredentialed synthetic Auth/profile/member and synthetic account codes/names. The approved existing platform operator `e1ef565b-c54d-4b52-bba3-360a03da7aa3` provisioned into the explicitly designated synthetic Company as service_role, without membership. No real Maker account was inserted, even temporarily.
- Hosted coverage: unregistered/inactive registry/inactive profile denial; ACCOUNTING_ADMIN/SYSTEM_ADMIN/ACCOUNTANT generated-block, direct INSERT and direct system-key UPDATE denials; wrong Company code/UUID pair and inactive Company rejection; invalid actual enum and key/type mismatch; ordinary Asset with no key; correct COMPANY_EXPENSE/Expense mapping and provenance; normalized duplicate code/key takeover rejection; batch rollback; foreign fixture Company left empty; zero business/financial rows in fixture Company.
- Before/after counts/content hashes match for all 48 public tables plus the private administrator registry (49 fingerprints), including Demo, real Company categories and journal history. Post-rollback reads confirm zero retained synthetic Auth/Company fixtures, real Maker accounts=0, Treasury=0, journals=0, ACTIVE categories=18, operator memberships=0, forced account RLS and unchanged browser INSERT/system-key UPDATE denial.
- All 50 local/Development canonical migrations align; linked dry-run is a no-op, with no pending migration/seed/role action. No migration added/applied, durable schema change or Staging/Production call.
- Focused secret/source review and whitespace checks PASS. No broad historical suite, full production audit, frontend build/browser or retained real provisioning was run. CLI preview was executed; the CLI `--apply` branch itself was not used in this checkpoint. Generated protected SQL was executed in the hosted rollback matrix; no end-to-end committed apply is claimed.

## Readiness

Business/accounting: VERIFIED reusable master-only capability and zero financial effects; actual Maker GL/system/Treasury creation DEFERRED. Security/authorization: VERIFIED scoped protected authority and browser denials; automated operator login/MFA binding and P7 immutable audit remain existing DEFERRED concerns. Database: VERIFIED constraints, rollback results, unchanged grants/RLS/history and migration alignment; new migration NOT APPLICABLE. Deployment: VERIFIED Development guard; browser deployment NOT APPLICABLE. Testing: VERIFIED focused generator/CLI and hosted SQL evidence, final committed operator use DEFERRED. Documentation: VERIFIED this record, handoff and roadmap.

Ready for the next reviewed Development operational step to provision the two approved real GL accounts. No new workflow blocker remains. The real Company still has no Chart of Accounts or Treasury; import is not ready until that next step. No 110000/510000/MAIN_CASH/INPUT_VAT or supplier/payroll records, import, Expenses, opening balance/funding, farm/Villa Al Mazraa, Demo accounting mutation, commit or push.

Changed files: this record, PROJECT_HANDOFF.md, PROJECT_ROADMAP.md, scripts/admin/provision-gl-accounts.mjs and scripts/verify-gl-provisioning.mjs. Development verification only; no application or database schema change.

## Authorized checkpoint closure

Closed in one local commit, `Add protected GL account provisioning`, containing exactly PROJECT_HANDOFF.md, PROJECT_ROADMAP.md, this record, scripts/admin/provision-gl-accounts.mjs and scripts/verify-gl-provisioning.mjs. Closure reconciled the existing documentation and ran only `git diff --check`; generator/hosted tests, migration checks, dry-run and broad tests were not rerun. Completed implementation and recorded verification are preserved without new runtime/schema/RLS/grant/UI changes. No real Maker GL accounts, mappings or Treasury created; no hosted actions, financial/business mutations, Staging/Production actions or push. Actual provisioning remains the next separately authorized operational step.
