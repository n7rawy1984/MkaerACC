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
const mutations = moduleAt("src/master/expenseCategoryMutations.ts", { "./masterRepositories": repositories });
const supplierMutations = moduleAt("src/master/supplierPartyMutations.ts", { "./masterRepositories": repositories });
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
  for (const method of ["select", "eq", "order", "insert", "update"]) query[method] = (...args) => { calls.push([method, ...args]); return query; };
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
function harness(overrides = {}, writer = mutations, supplierWriter = supplierMutations) {
  let previousDeps, cleanup, effect, output, calls = 0, cursor = 0;
  const slots = [];
  const hooks = {
    useState: (initial) => { const i = cursor++; if (!(i in slots)) slots[i] = initial; return [slots[i], (next) => { slots[i] = typeof next === "function" ? next(slots[i]) : next; }]; },
    useRef: (initial) => { const i = cursor++; slots[i] ??= { current: initial }; return slots[i]; },
    useLayoutEffect: (run) => { run(); },
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
    "./supplierPartyMutations": supplierWriter, "./expenseCategoryMutations": writer, "./masterRepositories": readers, "./productionMasterDataContext": { ProductionMasterDataContext: { Provider: "provider" } },
  });
  let userId = "user-a";
  const client = { auth: { getSession: async () => ({ data: { session: userId ? { user: { id: userId } } : null }, error: null }) } };
  const render = (props = {}) => {
    cursor = 0;
    output = ProductionMasterDataProvider({ client, userId: "user-a", activeCompanyId: "company-a", role: "ACCOUNTANT", children: null, ...props });
    const pending = effect; effect = null; pending?.();
    return output;
  };
  return { render, unmount: () => cleanup?.(), session: (id) => { userId = id; }, calls: () => calls, state: () => slots[0].state };
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
h.render();
assert.deepEqual(h.state(), { phase: "READY", company: { id: "company-a" }, projects: [], parties: [], expenseCategories: [], accounts: [], treasuryAccounts: [], subcontracts: [] });
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

// Slice 5: real write repository payloads and exact optimistic token.
const input = { code: " MAT ", name: " Materials ", description: " " };
const currentCategory = repositories.mapExpenseCategoryRow(category);
for (const command of [{ kind: "create", input: { ...input, id: "forged", status: "INACTIVE", created_by: "forged" } }, { kind: "edit", category: currentCategory, input }, { kind: "status", category: currentCategory, status: "ACTIVE" }]) {
  const client = queryClient({ data: [{ ...category, updated_at: "2026-09-13T00:00:00.123456+00:00" }], error: null });
  const result = await mutations.mutateExpenseCategory(client, "company-a", command);
  assert.equal(result.ok, true);
  assert.equal(result.category.updatedAt, "2026-09-13T00:00:00.123456+00:00");
  const payload = client.calls.find(([method]) => method === "insert" || method === "update")[1];
  assert.deepEqual(Object.keys(payload).sort(), command.kind === "create" ? ["code", "company_id", "description", "name"] : command.kind === "edit" ? ["code", "description", "name"] : ["status"]);
  if (command.kind !== "create") assert.deepEqual(client.calls.filter(([m]) => m === "eq"), [["eq", "company_id", "company-a"], ["eq", "id", category.id], ["eq", "updated_at", category.updated_at]]);
}
for (const [response, expected] of [
  [{ data: [], error: null }, "conflict"], [{ data: [category, category], error: null }, "uncertain"],
  [{ data: [{ ...category, company_id: "company-b" }], error: null }, "uncertain"],
  ...[["23505", "duplicate"], ["42501", "denied"], ["23514", "invalid"], ["", "uncertain"]].map(([code, expected]) => [{ data: null, error: { code, message: "private server detail" } }, expected]),
]) assert.deepEqual(await mutations.mutateExpenseCategory(queryClient(response), "company-a", { kind: "edit", category: currentCategory, input }), { ok: false, error: expected });
for (const bad of [{ ...input, code: " " }, { ...input, name: "x".repeat(201) }, { ...input, code: null }]) assert.equal(mutations.normalizeExpenseCategory(bad), null);
assert.equal(mutations.normalizeExpenseCategory({ ...input, code: "😀".repeat(50) }).code.length, 100);
const wrongTenantClient = queryClient({});
assert.equal((await mutations.mutateExpenseCategory(wrongTenantClient, "company-b", { kind: "edit", category: currentCategory, input })).error, "denied");
assert.equal(wrongTenantClient.calls.length, 0);

let writes = 0;
const successfulWriter = { mutateExpenseCategory: async () => { writes++; return { ok: true, category: currentCategory }; } };
const admin = { role: "ACCOUNTING_ADMIN" };
h = harness({}, successfulWriter); h.render(admin); await flush();
assert.equal(await h.render(admin).saveExpenseCategory({ kind: "create", input }), true);
assert.equal(h.calls(), 8, "save refreshes only categories");
assert.equal(h.render(admin).categoryMutation.phase, "SAVED");
h.render(admin); await flush(); assert.equal(h.calls(), 8, "focus-equivalent unchanged render does not reload");
for (const role of ["ACCOUNTANT", "PROCUREMENT", "DATA_ENTRY", "MANAGEMENT_VIEWER", "PROJECT_MANAGER", "SYSTEM_ADMIN"]) {
  h = harness({}, successfulWriter); h.render({ role }); await flush(); const before = writes;
  assert.equal(await h.render({ role }).saveExpenseCategory({ kind: "create", input }), false); assert.equal(writes, before);
}
for (const transition of ["company", "role", "user", "logout", "unmount"]) {
  const delayedWrite = deferred();
  h = harness({}, { mutateExpenseCategory: () => delayedWrite.promise }); h.render(admin); await flush();
  const action = h.render(admin).saveExpenseCategory({ kind: "create", input }); await flush();
  assert.equal(await h.render(admin).saveExpenseCategory({ kind: "create", input }), false, "duplicate in-flight submission rejected");
  let next = admin;
  if (transition === "company") next = { ...admin, activeCompanyId: "company-b" };
  if (transition === "role") next = { role: "PROCUREMENT" };
  if (transition === "user") { next = { ...admin, userId: "user-b" }; h.session("user-b"); }
  if (transition === "logout") h.session(null);
  if (transition === "unmount") h.unmount(); else { h.render(next); await flush(); }
  const reads = h.calls(); delayedWrite.resolve({ ok: true, category: currentCategory });
  assert.equal(await action, false); await flush(); assert.equal(h.calls(), reads, "stale save cannot refresh another scope");
  if (!["logout", "unmount"].includes(transition)) assert.equal(h.render(next).categoryMutation.phase, "IDLE");
}
let categoryReads = 0;
h = harness({ readActiveCompanyExpenseCategories: async () => ++categoryReads === 2 ? { ok: false, error: { source: "expenseCategories" } } : { ok: true, data: [] } }, successfulWriter);
h.render(admin); await flush();
assert.equal(await h.render(admin).saveExpenseCategory({ kind: "create", input }), false);
assert.equal(h.render(admin).categoryMutation.phase, "REFRESH_ERROR");
const beforeRetry = writes;
assert.equal(await h.render(admin).saveExpenseCategory({ kind: "create", input }), false); assert.equal(writes, beforeRetry);
assert.equal(await h.render(admin).refreshExpenseCategories(), true);
assert.equal(h.render(admin).categoryMutation.phase, "IDLE");
console.log("P6C Slice 5 payload, normalization, exact-token, denied-role, category-refresh, duplicate-submit, stale-save and refresh-recovery checks passed.");

// Late category refresh cannot repaint a different tenant, even after a confirmed write.
const lateRefresh = deferred(); let readNumber = 0;
h = harness({ readActiveCompanyExpenseCategories: async () => ++readNumber === 2 ? lateRefresh.promise : { ok: true, data: [] } }, successfulWriter);
h.render(admin); await flush(); const refreshAction = h.render(admin).saveExpenseCategory({ kind: "create", input }); await flush();
h.render({ ...admin, activeCompanyId: "company-b" }); await flush();
lateRefresh.resolve({ ok: true, data: [currentCategory] }); assert.equal(await refreshAction, false);
assert.deepEqual(h.render({ ...admin, activeCompanyId: "company-b" }).expenseCategories, []);
for (const error of ["conflict", "uncertain", "denied", "duplicate"]) {
  h = harness({}, { mutateExpenseCategory: async () => ({ ok: false, error }) }); h.render(admin); await flush();
  assert.equal(await h.render(admin).saveExpenseCategory({ kind: "create", input }), false);
  assert.deepEqual(h.render(admin).categoryMutation, { phase: "ERROR", error });
  assert.equal(await h.render(admin).saveExpenseCategory({ kind: "create", input }), false);
  assert.equal(await h.render(admin).refreshExpenseCategories(), true);
}
const fieldModule = moduleAt("src/components/ui/Field.tsx");
const categoryFormModule = moduleAt("src/master/ExpenseCategoryForm.tsx", {
  "../components/ui/Field": fieldModule, "../i18n/I18nContext": { useT: () => (key) => key }, "./expenseCategoryMutations": mutations,
});
const formHtml = renderToStaticMarkup(createElement(categoryFormModule.ExpenseCategoryForm, { category: null, disabled: false, onSave: async () => {}, onCancel: () => {} }));
assert(formHtml.includes("categoryMutation.activeOnCreate")); assert(!formHtml.includes("<select"));
for (const role of ["ACCOUNTING_ADMIN", "ACCOUNTANT", "PROCUREMENT", "DATA_ENTRY", "MANAGEMENT_VIEWER", "PROJECT_MANAGER", "SYSTEM_ADMIN"]) {
  const { ExpenseCategoriesList } = moduleAt("src/master/ExpenseCategoriesList.tsx", {
    "../auth/AuthContext": { useAuth: () => ({ state: { phase: "TENANT_READY", activeTenant: { role } } }) },
    "../i18n/I18nContext": { useT: () => (key) => key },
    "./productionMasterDataContext": { useProductionMasterData: () => ({ phase: "READY", expenseCategories: [currentCategory], categoryMutation: { phase: "IDLE" } }) },
    "./ExpenseCategoryForm": categoryFormModule,
  });
  const html = renderToStaticMarkup(createElement(ExpenseCategoriesList));
  for (const control of ["categoryMutation.create", "categoryMutation.edit", "categoryMutation.reactivate"]) assert.equal(html.includes(control), role === "ACCOUNTING_ADMIN");
  assert(!html.includes("categoryMutation.delete"));
}
console.log("P6C Slice 5 late-refresh, conflict/uncertainty recovery and actual role-gated list/form rendering checks passed.");

// Slice 6: explicit Supplier payloads, exact tokens, and separate provider state.
const supplierInput = { name: "  مورد ", code: " SUP ", trn: " 00123 ", contact_person: " Contact  Person ", phone: " +971 (0)01 ", email: " User@Example.test ", address: " ", notes: "\t\n" };
const normalizedSupplier = { name: "مورد", code: "SUP", trn: "00123", contact_person: "Contact  Person", phone: "+971 (0)01", email: "User@Example.test", address: null, notes: null };
const currentSupplier = repositories.mapPartyRow(party);
assert.deepEqual(supplierMutations.normalizeSupplierParty(supplierInput), normalizedSupplier);
assert.equal(supplierMutations.normalizeSupplierParty({ ...supplierInput, code: "\u00a0\t" }).code, null);
assert.equal(supplierMutations.normalizeSupplierParty({ ...supplierInput, name: "\u2003مورد\uFEFF" }).name, "مورد");
assert.equal(supplierMutations.normalizeSupplierParty({ ...supplierInput, code: "😀".repeat(50) }).code.length, 100);
for (const bad of [{ ...supplierInput, name: "\t " }, { ...supplierInput, name: "x".repeat(201) }, { ...supplierInput, code: "x".repeat(51) }, { ...supplierInput, trn: 123 }, { ...supplierInput, phone: undefined }]) assert.equal(supplierMutations.normalizeSupplierParty(bad), null);
for (const command of [
  { kind: "create", input: { ...supplierInput, company_id: "company-b", type: "OWNER", status: "INACTIVE", id: "forged", created_by: "forged", updated_at: "forged" } },
  { kind: "edit", supplier: currentSupplier, input: supplierInput },
  { kind: "status", supplier: currentSupplier, status: "ACTIVE" },
  { kind: "status", supplier: { ...currentSupplier, status: "ACTIVE" }, status: "INACTIVE" },
]) {
  const client = queryClient({ data: [{ ...party, updated_at: "2026-09-13T00:00:00.123456+00:00" }], error: null });
  const result = await supplierMutations.mutateSupplierParty(client, "company-a", command);
  assert.equal(result.ok, true); assert.equal(result.supplier.updatedAt, "2026-09-13T00:00:00.123456+00:00");
  const payload = client.calls.find(([m]) => m === "insert" || m === "update")[1];
  assert.deepEqual(payload, command.kind === "create" ? { company_id: "company-a", ...normalizedSupplier } : command.kind === "edit" ? normalizedSupplier : { status: command.status });
  if (command.kind !== "create") assert.deepEqual(client.calls.filter(([m]) => m === "eq"), [["eq", "company_id", "company-a"], ["eq", "id", party.id], ["eq", "type", "SUPPLIER"], ["eq", "updated_at", party.updated_at]]);
}
for (const type of ["OWNER", "CUSTODIAN", "EMPLOYEE", "SUBCONTRACTOR", "OTHER"]) {
  const client = queryClient({});
  assert.deepEqual(await supplierMutations.mutateSupplierParty(client, "company-a", { kind: "edit", supplier: { ...currentSupplier, type }, input: supplierInput }), { ok: false, error: "denied" });
  assert.equal(client.calls.length, 0);
}
for (const supplier of [{ ...currentSupplier, companyId: "company-b" }, { ...currentSupplier, updatedAt: "" }]) {
  const client = queryClient({});
  assert.equal((await supplierMutations.mutateSupplierParty(client, "company-a", { kind: "status", supplier, status: "ACTIVE" })).error, "denied");
  assert.equal(client.calls.length, 0);
}
for (const [response, expected] of [
  [{ data: [], error: null }, "conflict"], [{ data: [party, party], error: null }, "uncertain"],
  ...[{ company_id: "company-b" }, { type: "OWNER" }, { id: "other" }, { updated_at: null }].map((patch) => [{ data: [{ ...party, ...patch }], error: null }, "uncertain"]),
  ...[["23505", "duplicate"], ["42501", "denied"], ["23514", "invalid"], ["23502", "invalid"], ["22P02", "invalid"], ["22001", "invalid"], ["", "uncertain"]].map(([code, error]) => [{ data: null, error: { code, message: "Hidden Owner UUID and private detail" } }, error]),
]) assert.deepEqual(await supplierMutations.mutateSupplierParty(queryClient(response), "company-a", { kind: "edit", supplier: currentSupplier, input: supplierInput }), { ok: false, error: expected });
assert.equal((await supplierMutations.mutateSupplierParty(queryClient({ data: [], error: null }), "company-a", { kind: "create", input: supplierInput })).error, "uncertain");
const rejectingSupplierClient = { from: () => { throw new Error("Transport failure"); } };
assert.deepEqual(await supplierMutations.mutateSupplierParty(rejectingSupplierClient, "company-a", { kind: "create", input: supplierInput }), { ok: false, error: "uncertain" });
let supplierWrites = 0;
const supplierWriter = { mutateSupplierParty: async () => { supplierWrites++; return { ok: true, supplier: currentSupplier }; } };
for (const role of ["ACCOUNTING_ADMIN", "PROCUREMENT", "ACCOUNTANT", "DATA_ENTRY", "MANAGEMENT_VIEWER", "PROJECT_MANAGER", "SYSTEM_ADMIN"]) {
  const props = { role };
  const readCounts = {};
  const countedReaders = Object.fromEntries(["readActiveCompanyParties", "readActiveCompanyExpenseCategories", "readActiveCompanyAccounts", "readActiveCompanyTreasuryAccounts", "readActiveCompanySubcontracts"].map((name) => [name, async () => { readCounts[name] = (readCounts[name] ?? 0) + 1; return { ok: true, data: [] }; }]));
  h = harness(countedReaders, successfulWriter, supplierWriter); h.render(props); await flush();
  const before = supplierWrites;
  const allowed = role === "ACCOUNTING_ADMIN" || role === "PROCUREMENT";
  assert.equal(await h.render(props).saveSupplierParty({ kind: "create", input: supplierInput }), allowed);
  assert.equal(supplierWrites - before, allowed ? 1 : 0);
  assert.equal(h.calls(), allowed ? 8 : 7);
  for (const [name, count] of Object.entries(readCounts)) assert.equal(count, allowed && name === "readActiveCompanyParties" ? 2 : 1, name);
  assert.equal(h.render(props).categoryMutation.phase, "IDLE");
  h.render(props); await flush(); assert.equal(h.calls(), allowed ? 8 : 7, "unchanged scope does not reload");
}
for (const transition of ["company", "role", "user", "logout", "unmount"]) {
  const pending = deferred();
  h = harness({}, successfulWriter, { mutateSupplierParty: () => pending.promise }); h.render(admin); await flush();
  const action = h.render(admin).saveSupplierParty({ kind: "create", input: supplierInput }); await flush();
  assert.equal(await h.render(admin).saveSupplierParty({ kind: "create", input: supplierInput }), false);
  let next = admin;
  if (transition === "company") next = { ...admin, activeCompanyId: "company-b" };
  if (transition === "role") next = { role: "MANAGEMENT_VIEWER" };
  if (transition === "user") { next = { ...admin, userId: "user-b" }; h.session("user-b"); }
  if (transition === "logout") h.session(null);
  if (transition === "unmount") h.unmount(); else { h.render(next); await flush(); }
  const reads = h.calls(); pending.resolve({ ok: true, supplier: currentSupplier });
  assert.equal(await action, false); assert.equal(h.calls(), reads);
  if (!["logout", "unmount"].includes(transition)) assert.equal(h.render(next).supplierMutation.phase, "IDLE");
}
// Late Parties refresh cannot replace another scope, even after a committed save.
for (const transition of ["company", "role", "user", "logout", "unmount"]) {
  const pending = deferred(); let count = 0;
  h = harness({ readActiveCompanyParties: async () => ++count === 2 ? pending.promise : { ok: true, data: [] } }, successfulWriter, supplierWriter);
  h.render(admin); await flush(); const action = h.render(admin).saveSupplierParty({ kind: "create", input: supplierInput }); await flush();
  let next = admin;
  if (transition === "company") next = { ...admin, activeCompanyId: "company-b" };
  if (transition === "role") next = { role: "MANAGEMENT_VIEWER" };
  if (transition === "user") { next = { ...admin, userId: "user-b" }; h.session("user-b"); }
  if (transition === "logout") h.session(null);
  if (transition === "unmount") h.unmount(); else { h.render(next); await flush(); }
  pending.resolve({ ok: true, data: [currentSupplier] }); assert.equal(await action, false);
  assert.deepEqual(h.state().parties, []);
}
for (const error of ["conflict", "uncertain", "denied", "duplicate", "invalid"]) {
  let attempts = 0;
  h = harness({}, successfulWriter, { mutateSupplierParty: async () => { attempts++; return { ok: false, error }; } });
  h.render(admin); await flush(); assert.equal(await h.render(admin).saveSupplierParty({ kind: "create", input: supplierInput }), false);
  assert.deepEqual(h.render(admin).supplierMutation, { phase: "ERROR", error });
  assert.equal(await h.render(admin).saveSupplierParty({ kind: "create", input: supplierInput }), false); assert.equal(attempts, 1);
  assert.equal(await h.render(admin).refreshParties(), true);
}
let supplierReads = 0;
h = harness({ readActiveCompanyParties: async () => ++supplierReads === 2 || supplierReads === 3 ? { ok: false, error: { source: "parties" } } : { ok: true, data: [] } }, successfulWriter, supplierWriter);
h.render(admin); await flush(); assert.equal(await h.render(admin).saveSupplierParty({ kind: "create", input: supplierInput }), false);
assert.equal(h.render(admin).supplierMutation.phase, "REFRESH_ERROR");
const supplierBeforeRetry = supplierWrites;
assert.equal(await h.render(admin).saveSupplierParty({ kind: "create", input: supplierInput }), false);
assert.equal(supplierWrites, supplierBeforeRetry);
assert.equal(await h.render(admin).refreshParties(), false); assert.equal(h.render(admin).supplierMutation.phase, "REFRESH_ERROR");
assert.equal(await h.render(admin).refreshParties(), true); assert.equal(h.render(admin).supplierMutation.phase, "SAVED");
// A plain read failure must never announce a committed write.
supplierReads = 0;
h = harness({ readActiveCompanyParties: async () => ++supplierReads === 2 ? { ok: false, error: { source: "parties" } } : { ok: true, data: [] } });
h.render(admin); await flush(); assert.equal(await h.render(admin).refreshParties(), false);
assert.deepEqual(h.render(admin).supplierMutation, { phase: "ERROR", error: "uncertain" });
// Both independent operations can finish without losing the other's resource/state.
const independentSave = deferred();
h = harness({ readActiveCompanyParties: async () => ({ ok: true, data: [currentSupplier] }), readActiveCompanyExpenseCategories: async () => ({ ok: true, data: [currentCategory] }) }, successfulWriter, { mutateSupplierParty: () => independentSave.promise });
h.render(admin); await flush(); const independentAction = h.render(admin).saveSupplierParty({ kind: "create", input: supplierInput }); await flush();
assert.equal(await h.render(admin).saveExpenseCategory({ kind: "create", input }), true);
assert.equal(h.render(admin).supplierMutation.phase, "PENDING");
independentSave.resolve({ ok: true, supplier: currentSupplier }); assert.equal(await independentAction, true);
assert.equal(h.render(admin).categoryMutation.phase, "SAVED"); assert.equal(h.render(admin).supplierMutation.phase, "SAVED");
assert.deepEqual(h.state().parties, [currentSupplier]); assert.deepEqual(h.state().expenseCategories, [currentCategory]);
const supplierFormModule = moduleAt("src/master/SupplierPartyForm.tsx", {
  "../components/ui/Field": fieldModule, "../i18n/I18nContext": { useT: () => (key) => key }, "./supplierPartyMutations": supplierMutations,
});
const supplierFormHtml = renderToStaticMarkup(createElement(supplierFormModule.SupplierPartyForm, { supplier: null, disabled: false, onSave: async () => {}, onCancel: () => {} }));
assert(supplierFormHtml.includes("supplierMutation.activeOnCreate")); assert(!supplierFormHtml.includes("<select"));
assert.deepEqual([...supplierFormHtml.matchAll(/name="([^"]+)"/g)].map((m) => m[1]).sort(), Object.keys(normalizedSupplier).sort());
for (const role of ["ACCOUNTING_ADMIN", "PROCUREMENT", "ACCOUNTANT", "DATA_ENTRY", "MANAGEMENT_VIEWER", "PROJECT_MANAGER", "SYSTEM_ADMIN"]) {
  for (const type of ["SUPPLIER", "SUBCONTRACTOR", "OWNER", "CUSTODIAN", "EMPLOYEE", "OTHER"]) {
    const { PartiesList } = moduleAt("src/master/PartiesList.tsx", {
      "../auth/AuthContext": { useAuth: () => ({ state: { phase: "TENANT_READY", activeTenant: { role } } }) },
      "../i18n/I18nContext": { useT: () => (key) => key },
      "./productionMasterDataContext": { useProductionMasterData: () => ({ phase: "READY", parties: [{ ...currentSupplier, type }], supplierMutation: { phase: "IDLE" } }) },
      "./SupplierPartyForm": supplierFormModule,
    });
    const html = renderToStaticMarkup(createElement(PartiesList));
    const manager = role === "ACCOUNTING_ADMIN" || role === "PROCUREMENT";
    assert.equal(html.includes("supplierMutation.create"), manager);
    for (const control of ["supplierMutation.edit", "supplierMutation.reactivate"]) assert.equal(html.includes(control), manager && type === "SUPPLIER");
    assert(html.includes("001234567890123")); assert(html.includes(`productionMaster.type.${type}`));
    assert(!html.includes("supplierMutation.delete"));
  }
}
console.log("P6C Slice 6 Supplier payload, normalization, roles/types, exact-token, conflict, independent resource refresh, stale save/refresh isolation, recovery and actual rendering checks passed.");

for (const session of [null, "other-user"]) {
  h = harness({}, successfulWriter, supplierWriter); h.session(session); h.render(admin); await flush();
  const before = supplierWrites;
  assert.equal(await h.render(admin).saveSupplierParty({ kind: "create", input: supplierInput }), false);
  assert.equal(supplierWrites, before);
}

// Static markup cannot prove that row controls reveal an actionable panel.
// Opt in to real Chromium interactions; absence is reported rather than a browser PASS.
if (process.env.P6C_BROWSER_INTERACTIONS === "1") {
  await import("./verify-p6c-supplier-interactions.mjs");
} else {
  console.log("Supplier browser click/layout coverage NOT RUN. Use P6C_BROWSER_INTERACTIONS=1 with Playwright, or run scripts/verify-p6c-supplier-interactions.mjs separately.");
}
