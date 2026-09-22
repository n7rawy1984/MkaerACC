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
const ownerPartyMutations = moduleAt("src/master/ownerPartyNameMutations.ts", { "./masterRepositories": repositories });
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
function harness(overrides = {}, writer = mutations, supplierWriter = supplierMutations, companyWriter = companyMutations, projectWriter = projectMutations, accountWriter = accountMutations, treasuryWriter = treasuryMutations, otherPartyWriter = otherPartyMutations, employeePartyWriter = employeePartyMutations, custodianPartyWriter = custodianPartyMutations, ownerPartyWriter = ownerPartyMutations) {
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
    "./ownerPartyNameMutations": ownerPartyWriter, "./custodianPartyNameMutations": custodianPartyWriter, "./employeePartyNameMutations": employeePartyWriter, "./otherPartyNameMutations": otherPartyWriter, "./treasuryNameMutations": treasuryWriter, "./accountNameMutations": accountWriter, "./projectMetadataMutations": projectWriter, "./companyProfileMutations": companyWriter, "./supplierPartyMutations": supplierWriter, "./expenseCategoryMutations": writer, "./masterRepositories": readers, "./productionMasterDataContext": { ProductionMasterDataContext: { Provider: "provider" } },
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
// Slice 14: OwnerParty display names only, including inactive OwnerParty.
let h; const admin = {role:'ACCOUNTING_ADMIN'};
const s14Row = { ...party, type:"OWNER", id:'ownerParty-a',code:'0010',name:'Original',status:'INACTIVE',updated_at:'2026-09-17T00:00:00.123456+00:00' };
const s14OwnerParty = repositories.mapPartyRow(s14Row);
const s14Input = {name:' \uFEFF حساب  Mixed '};
const s14Command = {party:s14OwnerParty,input:s14Input};
assert.deepEqual(ownerPartyMutations.normalizeOwnerPartyName(s14Input), {name:'حساب  Mixed'});
for (const name of ['', '  ', 'x'.repeat(201)]) assert.equal(ownerPartyMutations.normalizeOwnerPartyName({...s14Input,name}),null);
assert.equal(ownerPartyMutations.normalizeOwnerPartyName({...s14Input,name:'😀'.repeat(200)}).name.length,400,'Postgres character count');
for (const field of ['name']) assert.equal(ownerPartyMutations.normalizeOwnerPartyName({...s14Input,[field]:123}),null);
const s14Client=queryClient({data:[s14Row],error:null});
assert.equal((await ownerPartyMutations.updateOwnerPartyName(s14Client,'company-a',{...s14Command,input:{...s14Input,status:'ACTIVE',type:'BANK',gl_account_id:'forged',project_id:'forged',bank_name:'forged',account_reference:'forged',notes:'forged',code:'forged',company_id:'b',updated_by:'forged'}})).ok,true);
assert.deepEqual(s14Client.calls.find(([m])=>m==='update')[1],ownerPartyMutations.normalizeOwnerPartyName(s14Input));
assert.deepEqual(s14Client.calls.filter(([m])=>m==='eq'),[['eq','company_id','company-a'],['eq','type','OWNER'],['eq','id','ownerParty-a'],['eq','updated_at',s14Row.updated_at]]);
for (const [response,error] of [[{data:[],error:null},'conflict'],[{data:[s14Row,s14Row],error:null},'uncertain'],[{data:[{...s14Row,company_id:'b'}],error:null},'uncertain'],[{data:[{...s14Row,id:'b'}],error:null},'uncertain'],[{data:[{...s14Row,updated_at:null}],error:null},'uncertain'],[{data:null,error:{code:'42501'}},'denied'],[{data:null,error:{code:'23514'}},'invalid'],[{data:null,error:{}},'uncertain']]) assert.deepEqual(await ownerPartyMutations.updateOwnerPartyName(queryClient(response),'company-a',s14Command),{ok:false,error});
for (const party of [{...s14OwnerParty,type:'SUPPLIER'},{...s14OwnerParty,companyId:'b'},{...s14OwnerParty,updatedAt:''}]) {const c=queryClient({});assert.equal((await ownerPartyMutations.updateOwnerPartyName(c,'company-a',{...s14Command,party})).ok,false);assert.equal(c.calls.length,0);}
let s14Writes=0;
const s14Writer={updateOwnerPartyName:async()=>{s14Writes++;return {ok:true,party:s14OwnerParty};}};
const s14Readers={readActiveCompanyParties:async(_c,id)=>({ok:true,data:[{...s14OwnerParty,companyId:id}]})};
for (const role of ['ACCOUNTING_ADMIN']) {
 h=harness(s14Readers,mutations,supplierMutations,companyMutations,projectMutations,accountMutations,treasuryMutations,otherPartyMutations,employeePartyMutations,custodianPartyMutations,s14Writer);h.render({role});await flush();
 assert.equal(await h.render({role}).saveOwnerPartyName(s14Command),true);assert.equal(h.calls(),8);
 assert.equal(h.render({role}).ownerPartyNameMutation.phase,'SAVED');assert.equal(h.render({role}).companyProfileMutation.phase,'IDLE');
}
for (const role of ['ACCOUNTANT','PROCUREMENT','DATA_ENTRY','MANAGEMENT_VIEWER','SYSTEM_ADMIN','PROJECT_MANAGER']) {h=harness(s14Readers,mutations,supplierMutations,companyMutations,projectMutations,accountMutations,treasuryMutations,otherPartyMutations,employeePartyMutations,custodianPartyMutations,s14Writer);h.render({role});await flush();const n=s14Writes;assert.equal(await h.render({role}).saveOwnerPartyName(s14Command),false);assert.equal(s14Writes,n);}
for (const stage of ['write','refresh']) for (const transition of ['company','role','user','logout','unmount']) {
 const delayed=deferred();let reads=0;let props={role:'ACCOUNTING_ADMIN'};
 h=harness({readActiveCompanyParties:async(_c,id)=>++reads===2&&stage==='refresh'?delayed.promise:{ok:true,data:[{...s14OwnerParty,companyId:id}]}},mutations,supplierMutations,companyMutations,projectMutations,accountMutations,treasuryMutations,otherPartyMutations,employeePartyMutations,custodianPartyMutations,stage==='write'?{updateOwnerPartyName:()=>delayed.promise}:s14Writer);
 h.render(props);await flush();const pending=h.render(props).saveOwnerPartyName(s14Command);await flush();assert.equal(await h.render(props).saveOwnerPartyName(s14Command),false);
 if(transition==='unmount')h.unmount();else if(transition==='logout')h.session(null);else {props={...props,...(transition==='company'?{activeCompanyId:'company-b'}:transition==='role'?{role:'MANAGEMENT_VIEWER'}:{userId:'user-b'})};if(transition==='user')h.session('user-b');h.render(props);await flush();}
 delayed.resolve(stage==='write'?{ok:true,party:s14OwnerParty}:{ok:true,data:[s14OwnerParty]});assert.equal(await pending,false);
 if(!['unmount','logout'].includes(transition)){assert.equal(h.render(props).ownerPartyNameMutation.phase,'IDLE');if(transition==='company')assert.equal(h.state().parties[0].companyId,'company-b');}
}
let s14Reads=0,failOwnerPartyRead=true;
h=harness({readActiveCompanyParties:async()=>++s14Reads>1&&failOwnerPartyRead?{ok:false,error:{source:'parties'}}:{ok:true,data:[s14OwnerParty]}},mutations,supplierMutations,companyMutations,projectMutations,accountMutations,treasuryMutations,otherPartyMutations,employeePartyMutations,custodianPartyMutations,s14Writer);
h.render(admin);await flush();assert.equal(await h.render(admin).saveOwnerPartyName(s14Command),false);assert.equal(h.render(admin).ownerPartyNameMutation.phase,'REFRESH_ERROR');assert.equal(await h.render(admin).refreshOwnerPartyNames(),false);assert.equal(h.render(admin).ownerPartyNameMutation.phase,'REFRESH_ERROR');
const s14Before=s14Writes;failOwnerPartyRead=false;assert.equal(await h.render(admin).refreshOwnerPartyNames(),true);assert.equal(s14Writes,s14Before);
for(const error of ['conflict','denied','uncertain']) {h=harness(s14Readers,mutations,supplierMutations,companyMutations,projectMutations,accountMutations,treasuryMutations,otherPartyMutations,employeePartyMutations,custodianPartyMutations,{updateOwnerPartyName:async()=>({ok:false,error})});h.render(admin);await flush();assert.equal(await h.render(admin).saveOwnerPartyName(s14Command),false);assert.equal(h.render(admin).ownerPartyNameMutation.error,error);assert.equal(await h.render(admin).saveOwnerPartyName(s14Command),false);assert.equal(await h.render(admin).refreshOwnerPartyNames(),true);}

console.log('Slice 14 OwnerParty name repository/provider PASS: one-field payload, normalization, Unicode bounds, exact token, allowed/all denied roles, duplicate guard, late writes/reads across scope/session/unmount, selective refresh, conflict/uncertainty/known-commit recovery.');

const gate = deferred();
h = harness(s14Readers, mutations, supplierMutations, companyMutations, projectMutations, accountMutations, treasuryMutations, otherPartyMutations, employeePartyMutations, custodianPartyMutations, {updateOwnerPartyName:()=>gate.promise});
h.render(admin); await flush();
const pending = h.render(admin).saveOwnerPartyName(s14Command); await flush();
assert.equal(await h.render(admin).refreshParties(), false);
assert.equal(await h.render(admin).refreshOtherPartyNames(), false);
gate.resolve({ok:true,party:s14OwnerParty}); assert.equal(await pending,true);
const supplierGate = deferred();
h = harness(s14Readers, mutations, {mutateSupplierParty:()=>supplierGate.promise}, companyMutations, projectMutations, accountMutations, treasuryMutations, otherPartyMutations, employeePartyMutations, custodianPartyMutations, s14Writer);
h.render(admin); await flush();
const supplierPending = h.render(admin).saveSupplierParty({kind:'edit',supplier:repositories.mapPartyRow(party),input:{}}); await flush();
assert.equal(await h.render(admin).saveOwnerPartyName(s14Command),false);
supplierGate.resolve({ok:true,supplier:repositories.mapPartyRow(party)}); assert.equal(await supplierPending,true);
const otherGate = deferred();
h = harness(s14Readers, mutations, supplierMutations, companyMutations, projectMutations, accountMutations, treasuryMutations, {updateOtherPartyName:()=>otherGate.promise}, employeePartyMutations, custodianPartyMutations, s14Writer);
h.render(admin); await flush();
const otherPending = h.render(admin).saveOtherPartyName({party:{...s14OwnerParty,type:'OTHER'},input:{name:'Other'}}); await flush();
assert.equal(await h.render(admin).saveOwnerPartyName(s14Command),false);
otherGate.resolve({ok:true,party:{...s14OwnerParty,type:'OTHER'}}); assert.equal(await otherPending,true);
console.log('Slice 14 shared Party resource serialization PASS.');
const employeeGate = deferred();
h = harness(s14Readers, mutations, supplierMutations, companyMutations, projectMutations, accountMutations, treasuryMutations, otherPartyMutations, {updateEmployeePartyName:()=>employeeGate.promise}, custodianPartyMutations, s14Writer);
h.render(admin); await flush();
const employeePending = h.render(admin).saveEmployeePartyName({party:{...s14OwnerParty,type:'EMPLOYEE'},input:{name:'Employee'}}); await flush();
assert.equal(await h.render(admin).saveOwnerPartyName(s14Command), false);
assert.equal(await h.render(admin).refreshOwnerPartyNames(), false);
employeeGate.resolve({ok:true,party:{...s14OwnerParty,type:'EMPLOYEE'}}); assert.equal(await employeePending,true);
const custodianGate = deferred();
h = harness(s14Readers, mutations, supplierMutations, companyMutations, projectMutations, accountMutations, treasuryMutations, otherPartyMutations, employeePartyMutations, {updateCustodianPartyName:()=>custodianGate.promise}, s14Writer);
h.render(admin); await flush();
const custodianPending = h.render(admin).saveCustodianPartyName({party:{...s14OwnerParty,type:'CUSTODIAN'},input:{name:'Custodian'}}); await flush();
assert.equal(await h.render(admin).saveOwnerPartyName(s14Command), false);
assert.equal(await h.render(admin).refreshOwnerPartyNames(), false);
custodianGate.resolve({ok:true,party:{...s14OwnerParty,type:'CUSTODIAN'}}); assert.equal(await custodianPending,true);
console.log('Slice 14 Employee/Custodian/Owner shared Party serialization PASS.');
