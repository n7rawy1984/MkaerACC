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
function queryClient(result) {
  const calls = [];
  const query = { then: (done, fail) => Promise.resolve(result).then(done, fail) };
  for (const method of ["select", "eq", "order"]) query[method] = (...args) => { calls.push([method, ...args]); return query; };
  return { calls, from: (table) => { calls.push(["from", table]); return query; } };
}
for (const [read, table, row, source] of [
  [repositories.readActiveCompanyParties, "parties", party, "parties"],
  [repositories.readActiveCompanyExpenseCategories, "expense_categories", category, "expenseCategories"],
]) {
  const client = queryClient({ data: [row, { ...row, id: "other", company_id: "company-b" }], error: null });
  const result = await read(client, "company-a");
  assert.equal(result.ok, true);
  assert.deepEqual(result.data.map((r) => r.id), [row.id]);
  assert.deepEqual(client.calls[0], ["from", table]);
  assert(client.calls.some((c) => c[0] === "eq" && c[1] === "company_id" && c[2] === "company-a"));
  assert(!client.calls.some((c) => c[0] === "eq" && c[1] === "status"));
  for (const data of [[], null]) assert.deepEqual(await read(queryClient({ data, error: null }), "company-a"), { ok: true, data: [] });
  assert.deepEqual(await read(queryClient({ data: null, error: { code: "42501", message: "denied" } }), "company-a"), {
    ok: false, error: { source, code: "42501", message: "denied" },
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
    readActiveCompanyExpenseCategories: async () => ok([]), ...overrides,
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
assert.deepEqual(h.render(), { phase: "READY", company: { id: "company-a" }, projects: [], parties: [], expenseCategories: [] });
h.render(); await flush(); assert.equal(h.calls(), 4, "unchanged scope must not reload");
assert.equal(h.render({ role: "PROCUREMENT" }).phase, "LOADING", "role change hides old data synchronously"); await flush();
assert.equal(h.calls(), 8);
for (const source of ["parties", "expenseCategories"]) {
  const reader = source === "parties" ? "readActiveCompanyParties" : "readActiveCompanyExpenseCategories";
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
