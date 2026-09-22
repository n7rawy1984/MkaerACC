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
const employeePartyMutations = moduleAt("src/master/employeePartyNameMutations.ts", { "./masterRepositories": repositories });
const otherPartyMutations = moduleAt("src/master/otherPartyNameMutations.ts", { "./masterRepositories": repositories });
const treasuryMutations = moduleAt("src/master/treasuryNameMutations.ts", { "./masterRepositories": repositories });
const accountMutations = moduleAt("src/master/accountNameMutations.ts", { "./masterRepositories": repositories });
const projectMutations = moduleAt("src/master/projectMetadataMutations.ts", { "./masterRepositories": repositories });
const companyMutations = moduleAt("src/master/companyProfileMutations.ts", { "./masterRepositories": repositories });
const supplierMutations = moduleAt("src/master/supplierPartyMutations.ts", { "./masterRepositories": repositories });
const audit = { created_at: "2026-09-12T00:00:00Z", created_by: null, updated_at: "2026-09-12T01:00:00Z", updated_by: "actor" };
const party = { ...audit, id: "party-a", company_id: "company-a", type: "SUPPLIER", name: "مورد", code: null, trn: "001234567890123", contact_person: "Contact", phone: null, email: null, address: null, status: "INACTIVE", notes: null };
function queryClient(result) {
  const calls = [];
  const query = { then: (done, fail) => Promise.resolve(result).then(done, fail) };
  for (const method of ["select", "eq", "order", "insert", "update"]) query[method] = (...args) => { calls.push([method, ...args]); return query; };
  return { calls, from: (table) => { calls.push(["from", table]); return query; } };
}
const flush = async () => { for (let i = 0; i < 20; i++) await Promise.resolve(); };
function deferred() { let resolve; const promise = new Promise((done) => { resolve = done; }); return { promise, resolve }; }
function harness(overrides = {}, writer = mutations, supplierWriter = supplierMutations, companyWriter = companyMutations, projectWriter = projectMutations, accountWriter = accountMutations, treasuryWriter = treasuryMutations, otherPartyWriter = otherPartyMutations, employeePartyWriter = employeePartyMutations) {
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
    "./employeePartyNameMutations": employeePartyWriter, "./otherPartyNameMutations": otherPartyWriter, "./treasuryNameMutations": treasuryWriter, "./accountNameMutations": accountWriter, "./projectMetadataMutations": projectWriter, "./companyProfileMutations": companyWriter, "./supplierPartyMutations": supplierWriter, "./expenseCategoryMutations": writer, "./masterRepositories": readers, "./productionMasterDataContext": { ProductionMasterDataContext: { Provider: "provider" } },
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
// Slice 12: EmployeeParty display names only, including inactive EmployeeParty.
let h; const admin = {role:'ACCOUNTING_ADMIN'};
const s12Row = { ...party, type:"EMPLOYEE", id:'employeeParty-a',code:'0010',name:'Original',status:'INACTIVE',updated_at:'2026-09-17T00:00:00.123456+00:00' };
const s12EmployeeParty = repositories.mapPartyRow(s12Row);
const s12Input = {name:' \uFEFF حساب  Mixed '};
const s12Command = {party:s12EmployeeParty,input:s12Input};
assert.deepEqual(employeePartyMutations.normalizeEmployeePartyName(s12Input), {name:'حساب  Mixed'});
for (const name of ['', '  ', 'x'.repeat(201)]) assert.equal(employeePartyMutations.normalizeEmployeePartyName({...s12Input,name}),null);
assert.equal(employeePartyMutations.normalizeEmployeePartyName({...s12Input,name:'😀'.repeat(200)}).name.length,400,'Postgres character count');
for (const field of ['name']) assert.equal(employeePartyMutations.normalizeEmployeePartyName({...s12Input,[field]:123}),null);
const s12Client=queryClient({data:[s12Row],error:null});
assert.equal((await employeePartyMutations.updateEmployeePartyName(s12Client,'company-a',{...s12Command,input:{...s12Input,status:'ACTIVE',type:'BANK',gl_account_id:'forged',project_id:'forged',bank_name:'forged',account_reference:'forged',notes:'forged',code:'forged',company_id:'b',updated_by:'forged'}})).ok,true);
assert.deepEqual(s12Client.calls.find(([m])=>m==='update')[1],employeePartyMutations.normalizeEmployeePartyName(s12Input));
assert.deepEqual(s12Client.calls.filter(([m])=>m==='eq'),[['eq','company_id','company-a'],['eq','type','EMPLOYEE'],['eq','id','employeeParty-a'],['eq','updated_at',s12Row.updated_at]]);
for (const [response,error] of [[{data:[],error:null},'conflict'],[{data:[s12Row,s12Row],error:null},'uncertain'],[{data:[{...s12Row,company_id:'b'}],error:null},'uncertain'],[{data:[{...s12Row,id:'b'}],error:null},'uncertain'],[{data:[{...s12Row,updated_at:null}],error:null},'uncertain'],[{data:null,error:{code:'42501'}},'denied'],[{data:null,error:{code:'23514'}},'invalid'],[{data:null,error:{}},'uncertain']]) assert.deepEqual(await employeePartyMutations.updateEmployeePartyName(queryClient(response),'company-a',s12Command),{ok:false,error});
for (const party of [{...s12EmployeeParty,type:'SUPPLIER'},{...s12EmployeeParty,companyId:'b'},{...s12EmployeeParty,updatedAt:''}]) {const c=queryClient({});assert.equal((await employeePartyMutations.updateEmployeePartyName(c,'company-a',{...s12Command,party})).ok,false);assert.equal(c.calls.length,0);}
let s12Writes=0;
const s12Writer={updateEmployeePartyName:async()=>{s12Writes++;return {ok:true,party:s12EmployeeParty};}};
const s12Readers={readActiveCompanyParties:async(_c,id)=>({ok:true,data:[{...s12EmployeeParty,companyId:id}]})};
for (const role of ['ACCOUNTING_ADMIN']) {
 h=harness(s12Readers,mutations,supplierMutations,companyMutations,projectMutations,accountMutations,treasuryMutations,otherPartyMutations,s12Writer);h.render({role});await flush();
 assert.equal(await h.render({role}).saveEmployeePartyName(s12Command),true);assert.equal(h.calls(),8);
 assert.equal(h.render({role}).employeePartyNameMutation.phase,'SAVED');assert.equal(h.render({role}).companyProfileMutation.phase,'IDLE');
}
for (const role of ['ACCOUNTANT','PROCUREMENT','DATA_ENTRY','MANAGEMENT_VIEWER','SYSTEM_ADMIN','PROJECT_MANAGER']) {h=harness(s12Readers,mutations,supplierMutations,companyMutations,projectMutations,accountMutations,treasuryMutations,otherPartyMutations,s12Writer);h.render({role});await flush();const n=s12Writes;assert.equal(await h.render({role}).saveEmployeePartyName(s12Command),false);assert.equal(s12Writes,n);}
for (const stage of ['write','refresh']) for (const transition of ['company','role','user','logout','unmount']) {
 const delayed=deferred();let reads=0;let props={role:'ACCOUNTING_ADMIN'};
 h=harness({readActiveCompanyParties:async(_c,id)=>++reads===2&&stage==='refresh'?delayed.promise:{ok:true,data:[{...s12EmployeeParty,companyId:id}]}},mutations,supplierMutations,companyMutations,projectMutations,accountMutations,treasuryMutations,otherPartyMutations,stage==='write'?{updateEmployeePartyName:()=>delayed.promise}:s12Writer);
 h.render(props);await flush();const pending=h.render(props).saveEmployeePartyName(s12Command);await flush();assert.equal(await h.render(props).saveEmployeePartyName(s12Command),false);
 if(transition==='unmount')h.unmount();else if(transition==='logout')h.session(null);else {props={...props,...(transition==='company'?{activeCompanyId:'company-b'}:transition==='role'?{role:'MANAGEMENT_VIEWER'}:{userId:'user-b'})};if(transition==='user')h.session('user-b');h.render(props);await flush();}
 delayed.resolve(stage==='write'?{ok:true,party:s12EmployeeParty}:{ok:true,data:[s12EmployeeParty]});assert.equal(await pending,false);
 if(!['unmount','logout'].includes(transition)){assert.equal(h.render(props).employeePartyNameMutation.phase,'IDLE');if(transition==='company')assert.equal(h.state().parties[0].companyId,'company-b');}
}
let s12Reads=0,failEmployeePartyRead=true;
h=harness({readActiveCompanyParties:async()=>++s12Reads>1&&failEmployeePartyRead?{ok:false,error:{source:'parties'}}:{ok:true,data:[s12EmployeeParty]}},mutations,supplierMutations,companyMutations,projectMutations,accountMutations,treasuryMutations,otherPartyMutations,s12Writer);
h.render(admin);await flush();assert.equal(await h.render(admin).saveEmployeePartyName(s12Command),false);assert.equal(h.render(admin).employeePartyNameMutation.phase,'REFRESH_ERROR');assert.equal(await h.render(admin).refreshEmployeePartyNames(),false);assert.equal(h.render(admin).employeePartyNameMutation.phase,'REFRESH_ERROR');
const s12Before=s12Writes;failEmployeePartyRead=false;assert.equal(await h.render(admin).refreshEmployeePartyNames(),true);assert.equal(s12Writes,s12Before);
for(const error of ['conflict','denied','uncertain']) {h=harness(s12Readers,mutations,supplierMutations,companyMutations,projectMutations,accountMutations,treasuryMutations,otherPartyMutations,{updateEmployeePartyName:async()=>({ok:false,error})});h.render(admin);await flush();assert.equal(await h.render(admin).saveEmployeePartyName(s12Command),false);assert.equal(h.render(admin).employeePartyNameMutation.error,error);assert.equal(await h.render(admin).saveEmployeePartyName(s12Command),false);assert.equal(await h.render(admin).refreshEmployeePartyNames(),true);}

console.log('Slice 12 EmployeeParty name repository/provider PASS: one-field payload, normalization, Unicode bounds, exact token, allowed/all denied roles, duplicate guard, late writes/reads across scope/session/unmount, selective refresh, conflict/uncertainty/known-commit recovery.');

const gate = deferred();
h = harness(s12Readers, mutations, supplierMutations, companyMutations, projectMutations, accountMutations, treasuryMutations, otherPartyMutations, {updateEmployeePartyName:()=>gate.promise});
h.render(admin); await flush();
const pending = h.render(admin).saveEmployeePartyName(s12Command); await flush();
assert.equal(await h.render(admin).refreshParties(), false);
assert.equal(await h.render(admin).refreshOtherPartyNames(), false);
gate.resolve({ok:true,party:s12EmployeeParty}); assert.equal(await pending,true);
const supplierGate = deferred();
h = harness(s12Readers, mutations, {mutateSupplierParty:()=>supplierGate.promise}, companyMutations, projectMutations, accountMutations, treasuryMutations, otherPartyMutations, s12Writer);
h.render(admin); await flush();
const supplierPending = h.render(admin).saveSupplierParty({kind:'edit',supplier:repositories.mapPartyRow(party),input:{}}); await flush();
assert.equal(await h.render(admin).saveEmployeePartyName(s12Command),false);
supplierGate.resolve({ok:true,supplier:repositories.mapPartyRow(party)}); assert.equal(await supplierPending,true);
const otherGate = deferred();
h = harness(s12Readers, mutations, supplierMutations, companyMutations, projectMutations, accountMutations, treasuryMutations, {updateOtherPartyName:()=>otherGate.promise}, s12Writer);
h.render(admin); await flush();
const otherPending = h.render(admin).saveOtherPartyName({party:{...s12EmployeeParty,type:'OTHER'},input:{name:'Other'}}); await flush();
assert.equal(await h.render(admin).saveEmployeePartyName(s12Command),false);
otherGate.resolve({ok:true,party:{...s12EmployeeParty,type:'OTHER'}}); assert.equal(await otherPending,true);
console.log('Slice 12 shared Party resource serialization PASS.');
