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
const custodianPartyMutations = moduleAt("src/master/custodianPartyNameMutations.ts", { "./masterRepositories": repositories });
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
function harness(overrides = {}, writer = mutations, supplierWriter = supplierMutations, companyWriter = companyMutations, projectWriter = projectMutations, accountWriter = accountMutations, treasuryWriter = treasuryMutations, otherPartyWriter = otherPartyMutations, employeePartyWriter = employeePartyMutations, custodianPartyWriter = custodianPartyMutations) {
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
    "./custodianPartyNameMutations": custodianPartyWriter, "./employeePartyNameMutations": employeePartyWriter, "./otherPartyNameMutations": otherPartyWriter, "./treasuryNameMutations": treasuryWriter, "./accountNameMutations": accountWriter, "./projectMetadataMutations": projectWriter, "./companyProfileMutations": companyWriter, "./supplierPartyMutations": supplierWriter, "./expenseCategoryMutations": writer, "./masterRepositories": readers, "./productionMasterDataContext": { ProductionMasterDataContext: { Provider: "provider" } },
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
// Slice 13: CustodianParty display names only, including inactive CustodianParty.
let h; const admin = {role:'ACCOUNTING_ADMIN'};
const s13Row = { ...party, type:"CUSTODIAN", id:'custodianParty-a',code:'0010',name:'Original',status:'INACTIVE',updated_at:'2026-09-17T00:00:00.123456+00:00' };
const s13CustodianParty = repositories.mapPartyRow(s13Row);
const s13Input = {name:' \uFEFF حساب  Mixed '};
const s13Command = {party:s13CustodianParty,input:s13Input};
assert.deepEqual(custodianPartyMutations.normalizeCustodianPartyName(s13Input), {name:'حساب  Mixed'});
for (const name of ['', '  ', 'x'.repeat(201)]) assert.equal(custodianPartyMutations.normalizeCustodianPartyName({...s13Input,name}),null);
assert.equal(custodianPartyMutations.normalizeCustodianPartyName({...s13Input,name:'😀'.repeat(200)}).name.length,400,'Postgres character count');
for (const field of ['name']) assert.equal(custodianPartyMutations.normalizeCustodianPartyName({...s13Input,[field]:123}),null);
const s13Client=queryClient({data:[s13Row],error:null});
assert.equal((await custodianPartyMutations.updateCustodianPartyName(s13Client,'company-a',{...s13Command,input:{...s13Input,status:'ACTIVE',type:'BANK',gl_account_id:'forged',project_id:'forged',bank_name:'forged',account_reference:'forged',notes:'forged',code:'forged',company_id:'b',updated_by:'forged'}})).ok,true);
assert.deepEqual(s13Client.calls.find(([m])=>m==='update')[1],custodianPartyMutations.normalizeCustodianPartyName(s13Input));
assert.deepEqual(s13Client.calls.filter(([m])=>m==='eq'),[['eq','company_id','company-a'],['eq','type','CUSTODIAN'],['eq','id','custodianParty-a'],['eq','updated_at',s13Row.updated_at]]);
for (const [response,error] of [[{data:[],error:null},'conflict'],[{data:[s13Row,s13Row],error:null},'uncertain'],[{data:[{...s13Row,company_id:'b'}],error:null},'uncertain'],[{data:[{...s13Row,id:'b'}],error:null},'uncertain'],[{data:[{...s13Row,updated_at:null}],error:null},'uncertain'],[{data:null,error:{code:'42501'}},'denied'],[{data:null,error:{code:'23514'}},'invalid'],[{data:null,error:{}},'uncertain']]) assert.deepEqual(await custodianPartyMutations.updateCustodianPartyName(queryClient(response),'company-a',s13Command),{ok:false,error});
for (const party of [{...s13CustodianParty,type:'SUPPLIER'},{...s13CustodianParty,companyId:'b'},{...s13CustodianParty,updatedAt:''}]) {const c=queryClient({});assert.equal((await custodianPartyMutations.updateCustodianPartyName(c,'company-a',{...s13Command,party})).ok,false);assert.equal(c.calls.length,0);}
let s13Writes=0;
const s13Writer={updateCustodianPartyName:async()=>{s13Writes++;return {ok:true,party:s13CustodianParty};}};
const s13Readers={readActiveCompanyParties:async(_c,id)=>({ok:true,data:[{...s13CustodianParty,companyId:id}]})};
for (const role of ['ACCOUNTING_ADMIN']) {
 h=harness(s13Readers,mutations,supplierMutations,companyMutations,projectMutations,accountMutations,treasuryMutations,otherPartyMutations,employeePartyMutations,s13Writer);h.render({role});await flush();
 assert.equal(await h.render({role}).saveCustodianPartyName(s13Command),true);assert.equal(h.calls(),8);
 assert.equal(h.render({role}).custodianPartyNameMutation.phase,'SAVED');assert.equal(h.render({role}).companyProfileMutation.phase,'IDLE');
}
for (const role of ['ACCOUNTANT','PROCUREMENT','DATA_ENTRY','MANAGEMENT_VIEWER','SYSTEM_ADMIN','PROJECT_MANAGER']) {h=harness(s13Readers,mutations,supplierMutations,companyMutations,projectMutations,accountMutations,treasuryMutations,otherPartyMutations,employeePartyMutations,s13Writer);h.render({role});await flush();const n=s13Writes;assert.equal(await h.render({role}).saveCustodianPartyName(s13Command),false);assert.equal(s13Writes,n);}
for (const stage of ['write','refresh']) for (const transition of ['company','role','user','logout','unmount']) {
 const delayed=deferred();let reads=0;let props={role:'ACCOUNTING_ADMIN'};
 h=harness({readActiveCompanyParties:async(_c,id)=>++reads===2&&stage==='refresh'?delayed.promise:{ok:true,data:[{...s13CustodianParty,companyId:id}]}},mutations,supplierMutations,companyMutations,projectMutations,accountMutations,treasuryMutations,otherPartyMutations,employeePartyMutations,stage==='write'?{updateCustodianPartyName:()=>delayed.promise}:s13Writer);
 h.render(props);await flush();const pending=h.render(props).saveCustodianPartyName(s13Command);await flush();assert.equal(await h.render(props).saveCustodianPartyName(s13Command),false);
 if(transition==='unmount')h.unmount();else if(transition==='logout')h.session(null);else {props={...props,...(transition==='company'?{activeCompanyId:'company-b'}:transition==='role'?{role:'MANAGEMENT_VIEWER'}:{userId:'user-b'})};if(transition==='user')h.session('user-b');h.render(props);await flush();}
 delayed.resolve(stage==='write'?{ok:true,party:s13CustodianParty}:{ok:true,data:[s13CustodianParty]});assert.equal(await pending,false);
 if(!['unmount','logout'].includes(transition)){assert.equal(h.render(props).custodianPartyNameMutation.phase,'IDLE');if(transition==='company')assert.equal(h.state().parties[0].companyId,'company-b');}
}
let s13Reads=0,failCustodianPartyRead=true;
h=harness({readActiveCompanyParties:async()=>++s13Reads>1&&failCustodianPartyRead?{ok:false,error:{source:'parties'}}:{ok:true,data:[s13CustodianParty]}},mutations,supplierMutations,companyMutations,projectMutations,accountMutations,treasuryMutations,otherPartyMutations,employeePartyMutations,s13Writer);
h.render(admin);await flush();assert.equal(await h.render(admin).saveCustodianPartyName(s13Command),false);assert.equal(h.render(admin).custodianPartyNameMutation.phase,'REFRESH_ERROR');assert.equal(await h.render(admin).refreshCustodianPartyNames(),false);assert.equal(h.render(admin).custodianPartyNameMutation.phase,'REFRESH_ERROR');
const s13Before=s13Writes;failCustodianPartyRead=false;assert.equal(await h.render(admin).refreshCustodianPartyNames(),true);assert.equal(s13Writes,s13Before);
for(const error of ['conflict','denied','uncertain']) {h=harness(s13Readers,mutations,supplierMutations,companyMutations,projectMutations,accountMutations,treasuryMutations,otherPartyMutations,employeePartyMutations,{updateCustodianPartyName:async()=>({ok:false,error})});h.render(admin);await flush();assert.equal(await h.render(admin).saveCustodianPartyName(s13Command),false);assert.equal(h.render(admin).custodianPartyNameMutation.error,error);assert.equal(await h.render(admin).saveCustodianPartyName(s13Command),false);assert.equal(await h.render(admin).refreshCustodianPartyNames(),true);}

console.log('Slice 13 CustodianParty name repository/provider PASS: one-field payload, normalization, Unicode bounds, exact token, allowed/all denied roles, duplicate guard, late writes/reads across scope/session/unmount, selective refresh, conflict/uncertainty/known-commit recovery.');

const gate = deferred();
h = harness(s13Readers, mutations, supplierMutations, companyMutations, projectMutations, accountMutations, treasuryMutations, otherPartyMutations, employeePartyMutations, {updateCustodianPartyName:()=>gate.promise});
h.render(admin); await flush();
const pending = h.render(admin).saveCustodianPartyName(s13Command); await flush();
assert.equal(await h.render(admin).refreshParties(), false);
assert.equal(await h.render(admin).refreshOtherPartyNames(), false);
gate.resolve({ok:true,party:s13CustodianParty}); assert.equal(await pending,true);
const supplierGate = deferred();
h = harness(s13Readers, mutations, {mutateSupplierParty:()=>supplierGate.promise}, companyMutations, projectMutations, accountMutations, treasuryMutations, otherPartyMutations, employeePartyMutations, s13Writer);
h.render(admin); await flush();
const supplierPending = h.render(admin).saveSupplierParty({kind:'edit',supplier:repositories.mapPartyRow(party),input:{}}); await flush();
assert.equal(await h.render(admin).saveCustodianPartyName(s13Command),false);
supplierGate.resolve({ok:true,supplier:repositories.mapPartyRow(party)}); assert.equal(await supplierPending,true);
const otherGate = deferred();
h = harness(s13Readers, mutations, supplierMutations, companyMutations, projectMutations, accountMutations, treasuryMutations, {updateOtherPartyName:()=>otherGate.promise}, employeePartyMutations, s13Writer);
h.render(admin); await flush();
const otherPending = h.render(admin).saveOtherPartyName({party:{...s13CustodianParty,type:'OTHER'},input:{name:'Other'}}); await flush();
assert.equal(await h.render(admin).saveCustodianPartyName(s13Command),false);
otherGate.resolve({ok:true,party:{...s13CustodianParty,type:'OTHER'}}); assert.equal(await otherPending,true);
console.log('Slice 13 shared Party resource serialization PASS.');
const employeeGate = deferred();
h = harness(s13Readers, mutations, supplierMutations, companyMutations, projectMutations, accountMutations, treasuryMutations, otherPartyMutations, {updateEmployeePartyName:()=>employeeGate.promise}, s13Writer);
h.render(admin); await flush();
const employeePending = h.render(admin).saveEmployeePartyName({party:{...s13CustodianParty,type:'EMPLOYEE'},input:{name:'Employee'}}); await flush();
assert.equal(await h.render(admin).saveCustodianPartyName(s13Command), false);
assert.equal(await h.render(admin).refreshCustodianPartyNames(), false);
employeeGate.resolve({ok:true,party:{...s13CustodianParty,type:'EMPLOYEE'}}); assert.equal(await employeePending,true);
console.log('Slice 13 Employee/Custodian shared Party serialization PASS.');
