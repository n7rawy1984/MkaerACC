// Runs real transpiled repositories/provider with controlled query and hook adapters.
// This is deterministic lifecycle evidence, not a replacement for React/browser acceptance.
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";
import { createRequire } from "node:module";
import ts from "typescript";
const require = createRequire(import.meta.url);
const root = resolve(import.meta.dirname, "..");
function moduleAt(path, mocks = {}) {
  const source = ts.transpileModule(readFileSync(resolve(root, path), "utf8"), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX, target: ts.ScriptTarget.ES2022 },
  }).outputText;
  const module = { exports: {} };
  new Function("require", "module", "exports", source)((name) => mocks[name] ?? require(name), module, module.exports);
  return module.exports;
}
const repositories = moduleAt("src/master/masterRepositories.ts");
const audit = { created_at: "2026-09-12T00:00:00Z", created_by: null, updated_at: "2026-09-12T01:00:00Z", updated_by: "actor" };
const party = { ...audit, id: "party-a", company_id: "company-a", type: "SUPPLIER", name: "مورد", code: null, trn: "001234567890123", contact_person: "Contact", phone: null, email: null, address: null, status: "INACTIVE", notes: null };
const category = { ...audit, id: "category-a", company_id: "company-a", name: "Materials", code: "MAT", description: null, status: "INACTIVE" };
assert.deepEqual(repositories.mapPartyRow(party), {
  id: "party-a", companyId: "company-a", type: "SUPPLIER", name: "مورد", code: null,
  taxRegistrationNumber: "001234567890123", contactPerson: "Contact", phone: null, email: null,
  address: null, status: "INACTIVE", notes: null, createdAt: audit.created_at, createdBy: null,
  updatedAt: audit.updated_at, updatedBy: "actor",
});
for (const type of ["OWNER", "CUSTODIAN", "SUPPLIER", "EMPLOYEE", "SUBCONTRACTOR", "OTHER"]) {
  assert.equal(repositories.mapPartyRow({ ...party, type, trn: null }).type, type);
  assert.equal(repositories.mapPartyRow({ ...party, type, trn: null }).taxRegistrationNumber, null);
}
assert.deepEqual(repositories.mapExpenseCategoryRow(category), {
  id: "category-a", companyId: "company-a", name: "Materials", code: "MAT", description: null,
  status: "INACTIVE", createdAt: audit.created_at, createdBy: null, updatedAt: audit.updated_at, updatedBy: "actor",
});
const account = { ...audit, id: "gl-a", company_id: "company-a", code: "0010", name: "حساب", account_type: "ASSET", parent_account_id: "parent-a", requires_party: true, system_key: "INPUT_VAT", status: "INACTIVE" };
const treasury = { ...audit, id: "treasury-a", company_id: "company-a", project_id: null, code: "BANK-1", name: "بنك", type: "BANK", gl_account_id: "gl-a", status: "INACTIVE", bank_name: null, account_reference: "001234", notes: null };
assert.deepEqual(repositories.mapAccountRow(account), {
  id: "gl-a", companyId: "company-a", code: "0010", name: "حساب", accountType: "ASSET", parentAccountId: "parent-a", requiresParty: true, systemKey: "INPUT_VAT", status: "INACTIVE",
  createdAt: audit.created_at, createdBy: null, updatedAt: audit.updated_at, updatedBy: "actor",
});
assert.deepEqual(repositories.mapTreasuryAccountRow(treasury), {
  id: "treasury-a", companyId: "company-a", projectId: null, code: "BANK-1", name: "بنك", type: "BANK", glAccountId: "gl-a", status: "INACTIVE", bankName: null, accountReference: "001234", notes: null,
  createdAt: audit.created_at, createdBy: null, updatedAt: audit.updated_at, updatedBy: "actor",
});
for (const account_type of ["ASSET", "LIABILITY", "EQUITY", "REVENUE", "EXPENSE"]) {
  const mapped = repositories.mapAccountRow({ ...account, account_type, parent_account_id: null, requires_party: false, system_key: null });
  assert.equal(mapped.accountType, account_type); assert.equal(mapped.parentAccountId, null);
  assert.equal(mapped.requiresParty, false); assert.equal(mapped.systemKey, null);
}
for (const type of ["CASH", "PETTY_CASH", "BANK", "PROJECT_CASH_BOX", "PROJECT_BANK"]) {
  const mapped = repositories.mapTreasuryAccountRow({ ...treasury, type, project_id: "project-a", bank_name: "بنك", account_reference: null, notes: "ملاحظة", created_by: "actor", updated_by: null });
  assert.equal(mapped.type, type); assert.equal(mapped.glAccountId, account.id);
  assert.equal(mapped.projectId, "project-a"); assert.equal(mapped.bankName, "بنك");
  assert.equal(mapped.accountReference, null); assert.equal(mapped.notes, "ملاحظة");
  assert.equal(mapped.createdBy, "actor"); assert.equal(mapped.updatedBy, null);
}
const { findVisibleAccount } = moduleAt("src/master/accountPresentation.ts");
const mappedAccount = repositories.mapAccountRow(account);
assert.equal(findVisibleAccount([mappedAccount], "company-a", "gl-a"), mappedAccount);
assert.equal(findVisibleAccount([mappedAccount], "company-b", "gl-a"), null);
assert.equal(findVisibleAccount([], "company-a", "gl-a"), null, "PM Treasury mapping must not synthesize a hidden Account");
assert.equal(findVisibleAccount([mappedAccount], "company-a", "parent-a"), null, "partial parent reference stays unresolved");
assert.equal(findVisibleAccount([mappedAccount], "company-a", null), null);
const subcontract = { ...audit, id: "subcontract-a", company_id: "company-a", project_id: "project-a", subcontractor_id: "party-a", contract_number: "000123", scope_of_work: "أعمال الخرسانة", original_contract_value_minor: "9223372036854775807", approved_variations_minor: "-9007199254740993", retention_bps: 125, start_date: null, expected_end_date: null, status: "CLOSED", notes: null };
assert.deepEqual(repositories.mapSubcontractRow(subcontract), {
  id: "subcontract-a", companyId: "company-a", projectId: "project-a", subcontractorId: "party-a", contractNumber: "000123", scopeOfWork: "أعمال الخرسانة",
  originalContractValueMinor: "9223372036854775807", approvedVariationsMinor: "-9007199254740993", retentionBps: 125, startDate: null, expectedEndDate: null, status: "CLOSED", notes: null,
  createdAt: audit.created_at, createdBy: null, updatedAt: audit.updated_at, updatedBy: "actor",
});
for (const status of ["ACTIVE", "COMPLETED", "CLOSED"]) {
  const mapped = repositories.mapSubcontractRow({ ...subcontract, status, original_contract_value_minor: "0", approved_variations_minor: "0", retention_bps: 10000, start_date: "2026-01-01", expected_end_date: "2027-01-01", notes: "ملاحظة", created_by: "actor", updated_by: null });
  assert.equal(mapped.status, status); assert.equal(mapped.originalContractValueMinor, "0");
  assert.equal(mapped.approvedVariationsMinor, "0"); assert.equal(mapped.retentionBps, 10000);
  assert.equal(mapped.startDate, "2026-01-01"); assert.equal(mapped.expectedEndDate, "2027-01-01");
  assert.equal(mapped.notes, "ملاحظة"); assert.equal(mapped.createdBy, "actor"); assert.equal(mapped.updatedBy, null);
}
for (const field of ["original_contract_value_minor", "approved_variations_minor"]) {
  for (const invalid of [9007199254740992, 0, null, "1.5", "1e4", ""]) {
    assert.throws(() => repositories.mapSubcontractRow({ ...subcontract, [field]: invalid }), /Invalid exact/);
  }
}
function queryClient(result) {
  const calls = [];
  const query = { then: (done, fail) => Promise.resolve(result).then(done, fail) };
  for (const method of ["select", "eq", "order"]) query[method] = (...args) => { calls.push([method, ...args]); return query; };
  return { calls, from: (table) => { calls.push(["from", table]); return query; } };
}
for (const [read, table, row, source] of [
  [repositories.readActiveCompanyParties, "parties", party, "parties"],
  [repositories.readActiveCompanyExpenseCategories, "expense_categories", category, "expenseCategories"],
  [repositories.readActiveCompanyAccounts, "accounts", account, "accounts"],
  [repositories.readActiveCompanyTreasuryAccounts, "treasury_accounts", treasury, "treasuryAccounts"],
  [repositories.readActiveCompanySubcontracts, "subcontracts", subcontract, "subcontracts"],
]) {
  const client = queryClient({ data: [row, { ...row, id: "other", company_id: "company-b" }], error: null });
  const result = await read(client, "company-a");
  assert.equal(result.ok, true);
  assert.deepEqual(result.data.map((r) => r.id), [row.id]);
  assert.deepEqual(client.calls[0], ["from", table]);
  assert(client.calls.some((c) => c[0] === "eq" && c[1] === "company_id" && c[2] === "company-a"));
  assert(!client.calls.some((c) => c[0] === "eq" && c[1] === "status"));
  if (table === "subcontracts") {
    const projection = client.calls.find((c) => c[0] === "select")[1];
    assert(projection.includes("original_contract_value_minor::text"));
    assert(projection.includes("approved_variations_minor::text"));
    assert(!projection.includes("*"));
    assert.deepEqual(client.calls.filter((c) => c[0] === "order"), [["order", "contract_number", { ascending: true }], ["order", "id", { ascending: true }]]);
    const malformed = await read(queryClient({ data: [{ ...row, original_contract_value_minor: 9007199254740992 }], error: null }), "company-a");
    assert.equal(malformed.ok, false); assert.equal(malformed.error.source, "subcontracts");
  }
  for (const data of [[], null]) assert.deepEqual(await read(queryClient({ data, error: null }), "company-a"), { ok: true, data: [] });
  assert.deepEqual(await read(queryClient({ data: null, error: { code: "42501", message: "denied" } }), "company-a"), {
    ok: false, error: { source, code: "42501", message: source === "subcontracts" ? "Protected subcontracts could not be loaded." : "denied" },
  });
}
const flush = async () => { for (let i = 0; i < 20; i++) await Promise.resolve(); };
function deferred() { let resolve; const promise = new Promise((done) => { resolve = done; }); return { promise, resolve }; }
function harness(overrides = {}) {
  let state, ref, previousDeps, cleanup, effect, output, calls = 0;
  const hooks = {
    useState: (initial) => { state ??= initial; return [state, (next) => { state = next; }]; },
    useRef: (initial) => { ref ??= { current: initial }; return ref; },
    useEffect: (run, deps) => {
      if (!previousDeps || deps.some((d, i) => d !== previousDeps[i])) {
        effect = () => { cleanup?.(); cleanup = run(); };
        previousDeps = deps;
      }
    },
  };
  const ok = (data) => ({ ok: true, data });
  const readers = {
    readActiveCompanyProfile: async (_client, id) => ok({ id }),
    readActiveCompanyProjects: async () => ok([]),
    readActiveCompanyParties: async () => ok([]),
    readActiveCompanyExpenseCategories: async () => ok([]),
    readActiveCompanyAccounts: async () => ok([]),
    readActiveCompanyTreasuryAccounts: async () => ok([]),
    readActiveCompanySubcontracts: async () => ok([]), ...overrides,
  };
  for (const [key, fn] of Object.entries(readers)) readers[key] = (...args) => { calls++; return fn(...args); };
  const { ProductionMasterDataProvider } = moduleAt("src/master/ProductionMasterDataProvider.tsx", {
    react: hooks, "react/jsx-runtime": { jsx: (_type, props) => props.value },
    "./masterRepositories": readers, "./productionMasterDataContext": { ProductionMasterDataContext: { Provider: "provider" } },
  });
  let userId = "user-a";
  const client = { auth: { getSession: async () => ({ data: { session: userId ? { user: { id: userId } } : null }, error: null }) } };
  const render = (props = {}) => {
    output = ProductionMasterDataProvider({ client, userId: "user-a", activeCompanyId: "company-a", role: "ACCOUNTANT", children: null, ...props });
    const pending = effect; effect = null; pending?.();
    return output;
  };
  return { render, unmount: () => cleanup?.(), session: (id) => { userId = id; }, calls: () => calls, state: () => state.state };
}
let h = harness({
  readActiveCompanyParties: async () => ({ ok: true, data: [repositories.mapPartyRow(party)] }),
  readActiveCompanyExpenseCategories: async () => ({ ok: true, data: [repositories.mapExpenseCategoryRow(category)] }),
});
h.render(); await flush();
assert.equal(h.render().parties[0].taxRegistrationNumber, "001234567890123");
assert.equal(h.state().expenseCategories[0].status, "INACTIVE");
h = harness();
assert.equal(h.render().phase, "LOADING"); await flush();
assert.deepEqual(h.render(), { phase: "READY", company: { id: "company-a" }, projects: [], parties: [], expenseCategories: [], accounts: [], treasuryAccounts: [], subcontracts: [] });
h.render(); await flush(); assert.equal(h.calls(), 7, "unchanged scope must not reload");
assert.equal(h.render({ role: "PROCUREMENT" }).phase, "LOADING", "role change hides old data synchronously"); await flush();
assert.equal(h.calls(), 14);
for (const [source, reader] of [["parties", "readActiveCompanyParties"], ["expenseCategories", "readActiveCompanyExpenseCategories"], ["accounts", "readActiveCompanyAccounts"], ["treasuryAccounts", "readActiveCompanyTreasuryAccounts"], ["subcontracts", "readActiveCompanySubcontracts"]]) {
  h = harness({ [reader]: async () => ({ ok: false, error: { source, code: "42501", message: "denied" } }) });
  h.render(); await flush(); assert.equal(h.render().phase, "ERROR"); assert.equal(h.state().error.source, source);
}
h = harness({ readActiveCompanyProfile: async () => ({ ok: true, data: null }) });
h.render(); await flush(); assert.equal(h.render().phase, "MISSING_COMPANY");
h = harness({ readActiveCompanyParties: async () => { throw new Error("network"); } });
h.render(); await flush(); assert.equal(h.render().phase, "ERROR");
const late = deferred();
h = harness({ readActiveCompanyParties: async (_client, company) => company === "company-a" ? late.promise : { ok: true, data: [] } });
h.render(); await flush();
assert.equal(h.render({ activeCompanyId: "company-b" }).phase, "LOADING"); await flush();
assert.equal(h.render({ activeCompanyId: "company-b" }).company.id, "company-b");
late.resolve({ ok: true, data: [repositories.mapPartyRow(party)] }); await flush();
assert.equal(h.render({ activeCompanyId: "company-b" }).company.id, "company-b");
assert.deepEqual(h.state().parties, []);
for (const invalidate of ["unmount", "session"]) {
  const pending = deferred();
  h = harness({ readActiveCompanyParties: () => pending.promise }); h.render(); await flush();
  if (invalidate === "unmount") h.unmount(); else h.session(null);
  pending.resolve({ ok: true, data: [repositories.mapPartyRow(party)] }); await flush();
  assert.equal(h.state().phase, "LOADING", `${invalidate} must prevent late commit`);
}
h = harness(); h.session("different-user"); h.render(); await flush();
assert.equal(h.render().phase, "ERROR"); assert.equal(h.calls(), 0);
console.log("P6C mapper/query and controlled provider lifecycle checks passed (empty, partial, error, scope/role switch, late result, unmount, session, unchanged scope).");

for (const [reader, field, row, mapper] of [
  ["readActiveCompanyAccounts", "accounts", account, repositories.mapAccountRow],
  ["readActiveCompanyTreasuryAccounts", "treasuryAccounts", treasury, repositories.mapTreasuryAccountRow],
  ["readActiveCompanySubcontracts", "subcontracts", subcontract, repositories.mapSubcontractRow],
]) {
  h = harness({ [reader]: async () => ({ ok: true, data: [mapper(row)] }) });
  h.render(); await flush(); assert.deepEqual(h.render()[field], [mapper(row)]);
  for (const nextScope of [{ activeCompanyId: "company-b" }, { role: "PROJECT_MANAGER" }, { userId: "user-b" }]) {
    const delayed = deferred(); let requests = 0;
    h = harness({ [reader]: () => ++requests === 1 ? delayed.promise : Promise.resolve({ ok: true, data: [] }) });
    h.render(); await flush();
    if (nextScope.userId) h.session(nextScope.userId);
    assert.equal(h.render(nextScope).phase, "LOADING"); await flush();
    assert.equal(h.render(nextScope).phase, "READY");
    delayed.resolve({ ok: true, data: [mapper(row)] }); await flush();
    assert.deepEqual(h.render(nextScope)[field], [], "old tenant/role/user result cannot enter new snapshot");
  }
  for (const invalidate of ["unmount", "session"]) {
    const pending = deferred();
    h = harness({ [reader]: () => pending.promise }); h.render(); await flush();
    if (invalidate === "unmount") h.unmount(); else h.session(null);
    pending.resolve({ ok: true, data: [mapper(row)] }); await flush();
    assert.equal(h.state().phase, "LOADING", `${field}: ${invalidate} prevents late commit`);
  }
}
h = harness({ readActiveCompanyTreasuryAccounts: async () => ({ ok: true, data: [repositories.mapTreasuryAccountRow(treasury)] }) });
h.render({ role: "PROJECT_MANAGER" }); await flush();
assert.equal(h.render({ role: "PROJECT_MANAGER" }).treasuryAccounts[0].glAccountId, "gl-a");
assert.deepEqual(h.state().accounts, [], "Treasury without visible GL detail is a valid ready state");
console.log("P6C Slice 3 mapping, relationship visibility, and delayed tenant/role/user/session checks passed.");

// Render actual list components without an authenticated browser or hosted fixtures.
const { createElement } = require("react");
const { renderToStaticMarkup } = require("react-dom/server");
const { AccountsList, TreasuryAccountsList } = moduleAt("src/master/AccountMasterLists.tsx", {
  "../i18n/I18nContext": { useT: () => (key) => key },
  "./accountPresentation": { findVisibleAccount },
});
const accountMarkup = renderToStaticMarkup(createElement(AccountsList, { accounts: [mappedAccount] }));
assert(accountMarkup.includes("0010")); assert(accountMarkup.includes("parent-a"));
assert(accountMarkup.includes("INPUT_VAT")); assert(accountMarkup.includes("productionMaster.yes"));
assert(accountMarkup.includes("productionMaster.accountDetailsUnavailable"));
assert(!/<(?:button|input|form)\b/.test(accountMarkup));
const treasuryMarkup = (accounts) => renderToStaticMarkup(createElement(TreasuryAccountsList, { accounts, treasuryAccounts: [repositories.mapTreasuryAccountRow(treasury)] }));
assert(treasuryMarkup([mappedAccount]).includes("حساب"));
assert(treasuryMarkup([]).includes("gl-a"));
assert(treasuryMarkup([]).includes("productionMaster.accountDetailsUnavailable"));
assert(!treasuryMarkup([]).includes("حساب"));
assert(!/<(?:button|input|form)\b/.test(treasuryMarkup([])));
assert(renderToStaticMarkup(createElement(AccountsList, { accounts: [] })).includes("productionMaster.accountsEmpty"));
assert(renderToStaticMarkup(createElement(TreasuryAccountsList, { accounts: [], treasuryAccounts: [] })).includes("productionMaster.treasuryAccountsEmpty"));
console.log("P6C Slice 3 list rendering checks passed (references, hidden details, system flag, empty, no mutation controls).");

const { SubcontractsList } = moduleAt("src/master/SubcontractsList.tsx", {
  "../i18n/I18nContext": { useT: () => (key) => key },
});
const contractMarkup = (projects = [], parties = [], extra = {}) => renderToStaticMarkup(createElement(SubcontractsList, {
  subcontracts: [repositories.mapSubcontractRow({ ...subcontract, ...extra })], projects, parties,
}));
const hiddenContract = contractMarkup();
for (const text of ["000123", "أعمال الخرسانة", "project-a", "party-a", "9223372036854775807", "-9007199254740993", "1.25%", "productionMaster.subcontractStatus.CLOSED", "productionMaster.projectDetailsUnavailable", "productionMaster.partyDetailsUnavailable"]) assert(hiddenContract.includes(text), text);
assert(!hiddenContract.includes("productionMaster.startDate"));
assert(!hiddenContract.includes("productionMaster.expectedEndDate"));
assert(!hiddenContract.includes("productionMaster.notes"));
assert(!/<(?:button|input|form)\b/.test(hiddenContract));
const visibleProject = { id: "project-a", companyId: "company-a", code: "P-1", name: "Visible Project" };
const visibleParty = { ...repositories.mapPartyRow(party), type: "SUBCONTRACTOR" };
assert(contractMarkup([visibleProject], [visibleParty]).includes("Visible Project"));
assert(contractMarkup([visibleProject], [visibleParty]).includes("مورد"));
const wrongCompany = contractMarkup([{ ...visibleProject, companyId: "company-b" }], [{ ...visibleParty, companyId: "company-b" }]);
assert(!wrongCompany.includes("Visible Project")); assert(!wrongCompany.includes("مورد"));
for (const [retention_bps, text] of [[0, "0.00%"], [1, "0.01%"], [10000, "100.00%"]]) assert(contractMarkup([], [], { retention_bps }).includes(text));
assert(renderToStaticMarkup(createElement(SubcontractsList, { subcontracts: [], projects: [], parties: [] })).includes("productionMaster.subcontractsEmpty"));
h = harness({ readActiveCompanySubcontracts: async () => ({ ok: true, data: [repositories.mapSubcontractRow(subcontract)] }) });
h.render({ role: "PROJECT_MANAGER" }); await flush();
assert.equal(h.render({ role: "PROJECT_MANAGER" }).subcontracts[0].subcontractorId, "party-a");
assert.deepEqual(h.state().parties, [], "Subcontract with hidden Party details is a valid snapshot");
const countBeforeFocus = h.calls(); h.render({ role: "PROJECT_MANAGER" }); await flush();
assert.equal(h.calls(), countBeforeFocus, "unchanged authority preserves contract snapshot");
console.log("P6C Slice 4 checks passed: exact BIGINT text, null/status/date mapping, query boundary/errors, delayed tenant/role/user/session, hidden references, empty/read-only lists and unchanged scope.");
