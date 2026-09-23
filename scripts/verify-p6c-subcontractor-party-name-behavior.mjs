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
const subcontractorPartyMutations = moduleAt("src/master/subcontractorPartyNameMutations.ts", { "./masterRepositories": repositories });
const otherPartyMutations = moduleAt("src/master/otherPartyNameMutations.ts", { "./masterRepositories": repositories });
const treasuryMutations = moduleAt("src/master/treasuryNameMutations.ts", { "./masterRepositories": repositories });
const accountMutations = moduleAt("src/master/accountNameMutations.ts", { "./masterRepositories": repositories });
const projectMutations = moduleAt("src/master/projectMetadataMutations.ts", { "./masterRepositories": repositories });
const companyMutations = moduleAt("src/master/companyProfileMutations.ts", { "./masterRepositories": repositories });
const supplierMutations = moduleAt("src/master/supplierPartyMutations.ts", { "./masterRepositories": repositories });
const subcontractMetadataMutations = moduleAt("src/master/subcontractMetadataMutations.ts", { "./masterRepositories": repositories });
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
function harness(overrides = {}, writer = mutations, supplierWriter = supplierMutations, companyWriter = companyMutations, projectWriter = projectMutations, accountWriter = accountMutations, treasuryWriter = treasuryMutations, otherPartyWriter = otherPartyMutations, employeePartyWriter = employeePartyMutations, custodianPartyWriter = custodianPartyMutations, subcontractorPartyWriter = subcontractorPartyMutations, ownerPartyWriter = ownerPartyMutations, subcontractWriter = subcontractMetadataMutations) {
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
    "./subcontractMetadataMutations": subcontractWriter, "./ownerPartyNameMutations": ownerPartyWriter, "./subcontractorPartyNameMutations": subcontractorPartyWriter, "./custodianPartyNameMutations": custodianPartyWriter, "./employeePartyNameMutations": employeePartyWriter, "./otherPartyNameMutations": otherPartyWriter, "./treasuryNameMutations": treasuryWriter, "./accountNameMutations": accountWriter, "./projectMetadataMutations": projectWriter, "./companyProfileMutations": companyWriter, "./supplierPartyMutations": supplierWriter, "./expenseCategoryMutations": writer, "./masterRepositories": readers, "./productionMasterDataContext": { ProductionMasterDataContext: { Provider: "provider" } },
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
// Slice 15: existing active/inactive SUBCONTRACTOR display names only.
let h; const admin = {role:'ACCOUNTING_ADMIN'};
const s15Row = { ...party, type:"SUBCONTRACTOR", id:'subcontractorParty-a',code:'0010',name:'Original',status:'INACTIVE',updated_at:'2026-09-17T00:00:00.123456+00:00' };
const s15SubcontractorParty = repositories.mapPartyRow(s15Row);
const s15Input = {name:' \uFEFF حساب  Mixed '};
const s15Command = {party:s15SubcontractorParty,input:s15Input};
assert.deepEqual(subcontractorPartyMutations.normalizeSubcontractorPartyName(s15Input), {name:'حساب  Mixed'});
for (const name of ['', '  ', 'x'.repeat(201)]) assert.equal(subcontractorPartyMutations.normalizeSubcontractorPartyName({...s15Input,name}),null);
assert.equal(subcontractorPartyMutations.normalizeSubcontractorPartyName({...s15Input,name:'😀'.repeat(200)}).name.length,400,'Postgres character count');
for (const field of ['name']) assert.equal(subcontractorPartyMutations.normalizeSubcontractorPartyName({...s15Input,[field]:123}),null);
const s15Client=queryClient({data:[s15Row],error:null});
assert.equal((await subcontractorPartyMutations.updateSubcontractorPartyName(s15Client,'company-a',{...s15Command,input:{...s15Input,status:'ACTIVE',type:'BANK',gl_account_id:'forged',project_id:'forged',bank_name:'forged',account_reference:'forged',notes:'forged',code:'forged',company_id:'b',updated_by:'forged'}})).ok,true);
assert.deepEqual(s15Client.calls.find(([m])=>m==='update')[1],subcontractorPartyMutations.normalizeSubcontractorPartyName(s15Input));
assert.deepEqual(s15Client.calls.filter(([m])=>m==='eq'),[['eq','company_id','company-a'],['eq','type','SUBCONTRACTOR'],['eq','id','subcontractorParty-a'],['eq','updated_at',s15Row.updated_at]]);
for (const [response,error] of [[{data:[],error:null},'conflict'],[{data:[s15Row,s15Row],error:null},'uncertain'],[{data:[{...s15Row,company_id:'b'}],error:null},'uncertain'],[{data:[{...s15Row,id:'b'}],error:null},'uncertain'],[{data:[{...s15Row,updated_at:null}],error:null},'uncertain'],[{data:null,error:{code:'42501'}},'denied'],[{data:null,error:{code:'23514'}},'invalid'],[{data:null,error:{}},'uncertain']]) assert.deepEqual(await subcontractorPartyMutations.updateSubcontractorPartyName(queryClient(response),'company-a',s15Command),{ok:false,error});
for (const party of [{...s15SubcontractorParty,type:'SUPPLIER'},{...s15SubcontractorParty,companyId:'b'},{...s15SubcontractorParty,updatedAt:''}]) {const c=queryClient({});assert.equal((await subcontractorPartyMutations.updateSubcontractorPartyName(c,'company-a',{...s15Command,party})).ok,false);assert.equal(c.calls.length,0);}
let s15Writes=0;
const s15Writer={updateSubcontractorPartyName:async()=>{s15Writes++;return {ok:true,party:s15SubcontractorParty};}};
const s15Readers={readActiveCompanyParties:async(_c,id)=>({ok:true,data:[{...s15SubcontractorParty,companyId:id}]})};
for (const role of ['ACCOUNTING_ADMIN','PROCUREMENT']) {
 h=harness(s15Readers,mutations,supplierMutations,companyMutations,projectMutations,accountMutations,treasuryMutations,otherPartyMutations,employeePartyMutations,custodianPartyMutations,s15Writer);h.render({role});await flush();
 assert.equal(await h.render({role}).saveSubcontractorPartyName(s15Command),true);assert.equal(h.calls(),8);
 assert.equal(h.render({role}).subcontractorPartyNameMutation.phase,'SAVED');assert.equal(h.render({role}).companyProfileMutation.phase,'IDLE');
}
for (const role of ['ACCOUNTANT','DATA_ENTRY','MANAGEMENT_VIEWER','SYSTEM_ADMIN','PROJECT_MANAGER']) {h=harness(s15Readers,mutations,supplierMutations,companyMutations,projectMutations,accountMutations,treasuryMutations,otherPartyMutations,employeePartyMutations,custodianPartyMutations,s15Writer);h.render({role});await flush();const n=s15Writes;assert.equal(await h.render({role}).saveSubcontractorPartyName(s15Command),false);assert.equal(s15Writes,n);}
for (const stage of ['write','refresh']) for (const transition of ['company','role','user','logout','unmount']) {
 const delayed=deferred();let reads=0;let props={role:'ACCOUNTING_ADMIN'};
 h=harness({readActiveCompanyParties:async(_c,id)=>++reads===2&&stage==='refresh'?delayed.promise:{ok:true,data:[{...s15SubcontractorParty,companyId:id}]}},mutations,supplierMutations,companyMutations,projectMutations,accountMutations,treasuryMutations,otherPartyMutations,employeePartyMutations,custodianPartyMutations,stage==='write'?{updateSubcontractorPartyName:()=>delayed.promise}:s15Writer);
 h.render(props);await flush();const pending=h.render(props).saveSubcontractorPartyName(s15Command);await flush();assert.equal(await h.render(props).saveSubcontractorPartyName(s15Command),false);
 if(transition==='unmount')h.unmount();else if(transition==='logout')h.session(null);else {props={...props,...(transition==='company'?{activeCompanyId:'company-b'}:transition==='role'?{role:'MANAGEMENT_VIEWER'}:{userId:'user-b'})};if(transition==='user')h.session('user-b');h.render(props);await flush();}
 delayed.resolve(stage==='write'?{ok:true,party:s15SubcontractorParty}:{ok:true,data:[s15SubcontractorParty]});assert.equal(await pending,false);
 if(!['unmount','logout'].includes(transition)){assert.equal(h.render(props).subcontractorPartyNameMutation.phase,'IDLE');if(transition==='company')assert.equal(h.state().parties[0].companyId,'company-b');}
}
let s15Reads=0,failSubcontractorPartyRead=true;
h=harness({readActiveCompanyParties:async()=>++s15Reads>1&&failSubcontractorPartyRead?{ok:false,error:{source:'parties'}}:{ok:true,data:[s15SubcontractorParty]}},mutations,supplierMutations,companyMutations,projectMutations,accountMutations,treasuryMutations,otherPartyMutations,employeePartyMutations,custodianPartyMutations,s15Writer);
h.render(admin);await flush();assert.equal(await h.render(admin).saveSubcontractorPartyName(s15Command),false);assert.equal(h.render(admin).subcontractorPartyNameMutation.phase,'REFRESH_ERROR');assert.equal(await h.render(admin).refreshSubcontractorPartyNames(),false);assert.equal(h.render(admin).subcontractorPartyNameMutation.phase,'REFRESH_ERROR');
const s15Before=s15Writes;failSubcontractorPartyRead=false;assert.equal(await h.render(admin).refreshSubcontractorPartyNames(),true);assert.equal(s15Writes,s15Before);
for(const error of ['conflict','denied','uncertain']) {h=harness(s15Readers,mutations,supplierMutations,companyMutations,projectMutations,accountMutations,treasuryMutations,otherPartyMutations,employeePartyMutations,custodianPartyMutations,{updateSubcontractorPartyName:async()=>({ok:false,error})});h.render(admin);await flush();assert.equal(await h.render(admin).saveSubcontractorPartyName(s15Command),false);assert.equal(h.render(admin).subcontractorPartyNameMutation.error,error);assert.equal(await h.render(admin).saveSubcontractorPartyName(s15Command),false);assert.equal(await h.render(admin).refreshSubcontractorPartyNames(),true);}

console.log('Slice 15 SubcontractorParty name repository/provider PASS: one-field payload, normalization, Unicode bounds, exact token, allowed/all denied roles, duplicate guard, late writes/reads across scope/session/unmount, selective refresh, conflict/uncertainty/known-commit recovery.');

const gate = deferred();
h = harness(s15Readers, mutations, supplierMutations, companyMutations, projectMutations, accountMutations, treasuryMutations, otherPartyMutations, employeePartyMutations, custodianPartyMutations, {updateSubcontractorPartyName:()=>gate.promise});
h.render(admin); await flush();
const pending = h.render(admin).saveSubcontractorPartyName(s15Command); await flush();
assert.equal(await h.render(admin).refreshParties(), false);
assert.equal(await h.render(admin).refreshOtherPartyNames(), false);
gate.resolve({ok:true,party:s15SubcontractorParty}); assert.equal(await pending,true);
const supplierGate = deferred();
h = harness(s15Readers, mutations, {mutateSupplierParty:()=>supplierGate.promise}, companyMutations, projectMutations, accountMutations, treasuryMutations, otherPartyMutations, employeePartyMutations, custodianPartyMutations, s15Writer);
h.render(admin); await flush();
const supplierPending = h.render(admin).saveSupplierParty({kind:'edit',supplier:repositories.mapPartyRow(party),input:{}}); await flush();
assert.equal(await h.render(admin).saveSubcontractorPartyName(s15Command),false);
supplierGate.resolve({ok:true,supplier:repositories.mapPartyRow(party)}); assert.equal(await supplierPending,true);
const otherGate = deferred();
h = harness(s15Readers, mutations, supplierMutations, companyMutations, projectMutations, accountMutations, treasuryMutations, {updateOtherPartyName:()=>otherGate.promise}, employeePartyMutations, custodianPartyMutations, s15Writer);
h.render(admin); await flush();
const otherPending = h.render(admin).saveOtherPartyName({party:{...s15SubcontractorParty,type:'OTHER'},input:{name:'Other'}}); await flush();
assert.equal(await h.render(admin).saveSubcontractorPartyName(s15Command),false);
otherGate.resolve({ok:true,party:{...s15SubcontractorParty,type:'OTHER'}}); assert.equal(await otherPending,true);
console.log('Slice 15 shared Party resource serialization PASS.');
const employeeGate = deferred();
h = harness(s15Readers, mutations, supplierMutations, companyMutations, projectMutations, accountMutations, treasuryMutations, otherPartyMutations, {updateEmployeePartyName:()=>employeeGate.promise}, custodianPartyMutations, s15Writer);
h.render(admin); await flush();
const employeePending = h.render(admin).saveEmployeePartyName({party:{...s15SubcontractorParty,type:'EMPLOYEE'},input:{name:'Employee'}}); await flush();
assert.equal(await h.render(admin).saveSubcontractorPartyName(s15Command), false);
assert.equal(await h.render(admin).refreshSubcontractorPartyNames(), false);
employeeGate.resolve({ok:true,party:{...s15SubcontractorParty,type:'EMPLOYEE'}}); assert.equal(await employeePending,true);
const custodianGate = deferred();
h = harness(s15Readers, mutations, supplierMutations, companyMutations, projectMutations, accountMutations, treasuryMutations, otherPartyMutations, employeePartyMutations, {updateCustodianPartyName:()=>custodianGate.promise}, s15Writer);
h.render(admin); await flush();
const custodianPending = h.render(admin).saveCustodianPartyName({party:{...s15SubcontractorParty,type:'CUSTODIAN'},input:{name:'Custodian'}}); await flush();
assert.equal(await h.render(admin).saveSubcontractorPartyName(s15Command), false);
assert.equal(await h.render(admin).refreshSubcontractorPartyNames(), false);
custodianGate.resolve({ok:true,party:{...s15SubcontractorParty,type:'CUSTODIAN'}}); assert.equal(await custodianPending,true);
console.log('Slice 15 Employee/Custodian/Subcontractor shared Party serialization PASS.');
const ownerGate = deferred();
h = harness(s15Readers, mutations, supplierMutations, companyMutations, projectMutations, accountMutations, treasuryMutations, otherPartyMutations, employeePartyMutations, custodianPartyMutations, s15Writer, {updateOwnerPartyName:()=>ownerGate.promise});
h.render(admin); await flush();
const ownerPending = h.render(admin).saveOwnerPartyName({party:{...s15SubcontractorParty,type:'OWNER'},input:{name:'Owner'}}); await flush();
assert.equal(await h.render(admin).saveSubcontractorPartyName(s15Command), false);
assert.equal(await h.render(admin).refreshSubcontractorPartyNames(), false);
ownerGate.resolve({ok:true,party:{...s15SubcontractorParty,type:'OWNER'}}); assert.equal(await ownerPending,true);
console.log('Slice 15 Owner/Subcontractor shared Party serialization PASS.');

const { createElement } = require('react');
const { renderToStaticMarkup } = require('react-dom/server');
const historicContract={id:'contract-a',companyId:'company-a',projectId:'project-a',subcontractorId:'subcontractorParty-a',contractNumber:'0001',scopeOfWork:'Historic work',originalContractValueMinor:'0',approvedVariationsMinor:'0',retentionBps:0,startDate:null,expectedEndDate:null,status:'ACTIVE',notes:null};
let displayParties=[];
const { SubcontractsList } = moduleAt('src/master/SubcontractsList.tsx',{ '../auth/AuthContext':{useAuth:()=>({state:{phase:'TENANT_READY',activeTenant:{role:'ACCOUNTANT'}}})}, '../i18n/I18nContext':{useT:()=>key=>key}, './SubcontractMetadataForm':{SubcontractMetadataForm:()=>null}, './productionMasterDataContext':{useProductionMasterData:()=>({phase:'READY',subcontracts:[historicContract],projects:[],parties:displayParties,subcontractMetadataMutation:{phase:'IDLE'},refreshSubcontracts:async()=>true,saveSubcontractMetadata:async()=>true})} });
const display=(parties)=>{displayParties=parties;return renderToStaticMarkup(createElement(SubcontractsList));};
const before=display([s15SubcontractorParty]);
const after=display([{...s15SubcontractorParty,name:'Renamed current identity'}]);
assert(before.includes('Original')&&!before.includes('Renamed current identity'));
assert(after.includes('Renamed current identity')&&!after.includes('Original'));
assert.equal(historicContract.subcontractorId,'subcontractorParty-a');
assert(after.includes('0001')&&after.includes('Historic work')&&after.includes('productionMaster.projectDetailsUnavailable'));
assert(!/<(?:input|form)\b/.test(after));
console.log('Slice 15 Subcontracts display dependency PASS: scoped Party name changes current label without changing the read-only Subcontract source.');

// Slice 16: existing Subcontract descriptive metadata only.
const s16Row={id:'contract-a',company_id:'company-a',project_id:'project-a',subcontractor_id:'subcontractorParty-a',contract_number:'0001',scope_of_work:'Original scope',original_contract_value_minor:'9007199254740993',approved_variations_minor:'17',retention_bps:525,start_date:'2026-01-01',expected_end_date:null,status:'CLOSED',notes:'Original notes',created_at:audit.created_at,created_by:'creator',updated_at:'2026-09-23T00:00:00.123456+00:00',updated_by:null};
const s16Subcontract=repositories.mapSubcontractRow(s16Row);
const s16Input={scope_of_work:' \uFEFF نطاق  Mixed ',start_date:'2026-02-03',expected_end_date:null,notes:'  A\n  B  '};
assert.deepEqual(subcontractMetadataMutations.normalizeSubcontractMetadata(s16Input),{scope_of_work:'نطاق  Mixed',start_date:'2026-02-03',expected_end_date:null,notes:'A\n  B'});
for(const value of ['', ' \uFEFF ']) assert.equal(subcontractMetadataMutations.normalizeSubcontractMetadata({...s16Input,scope_of_work:value}),null);
for(const value of ['2026-02-30','2026-2-03','x']) assert.equal(subcontractMetadataMutations.normalizeSubcontractMetadata({...s16Input,start_date:value}),null);
assert.deepEqual(subcontractMetadataMutations.normalizeSubcontractMetadata({...s16Input,start_date:'',notes:'  '}),{scope_of_work:'نطاق  Mixed',start_date:null,expected_end_date:null,notes:null});
const s16Command={subcontract:s16Subcontract,input:s16Input};
const s16Client=queryClient({data:[s16Row],error:null});
assert.equal((await subcontractMetadataMutations.updateSubcontractMetadata(s16Client,'company-a',{...s16Command,input:{...s16Input,contract_number:'FORGED',status:'ACTIVE',project_id:'FORGED',original_contract_value_minor:'0'}})).ok,true);
assert.deepEqual(s16Client.calls.find(([m])=>m==='update')[1],subcontractMetadataMutations.normalizeSubcontractMetadata(s16Input));
assert.deepEqual(s16Client.calls.filter(([m])=>m==='eq'),[['eq','company_id','company-a'],['eq','id','contract-a'],['eq','updated_at',s16Row.updated_at]]);
for(const [response,error] of [[{data:[],error:null},'conflict'],[{data:[s16Row,s16Row],error:null},'uncertain'],[{data:[{...s16Row,company_id:'b'}],error:null},'uncertain'],[{data:[{...s16Row,id:'b'}],error:null},'uncertain'],[{data:null,error:{code:'42501'}},'denied'],[{data:null,error:{code:'23514'}},'invalid'],[{data:null,error:{code:'22007'}},'invalid'],[{data:null,error:{}},'uncertain']]) assert.deepEqual(await subcontractMetadataMutations.updateSubcontractMetadata(queryClient(response),'company-a',s16Command),{ok:false,error});
for(const subcontract of [{...s16Subcontract,companyId:'b'},{...s16Subcontract,updatedAt:''}]) {const c=queryClient({});assert.equal((await subcontractMetadataMutations.updateSubcontractMetadata(c,'company-a',{...s16Command,subcontract})).ok,false);assert.equal(c.calls.length,0);}

const s16Harness=(overrides={},writer=subcontractMetadataMutations)=>harness(overrides,mutations,supplierMutations,companyMutations,projectMutations,accountMutations,treasuryMutations,otherPartyMutations,employeePartyMutations,custodianPartyMutations,subcontractorPartyMutations,ownerPartyMutations,writer);
let s16Writes=0;
const s16Writer={updateSubcontractMetadata:async()=>{s16Writes++;return {ok:true,subcontract:s16Subcontract};}};
const s16Readers={readActiveCompanySubcontracts:async(_c,id)=>({ok:true,data:[{...s16Subcontract,companyId:id}]})};
for(const role of ['ACCOUNTING_ADMIN','PROCUREMENT']) {h=s16Harness(s16Readers,s16Writer);h.render({role});await flush();assert.equal(await h.render({role}).saveSubcontractMetadata(s16Command),true);assert.equal(h.render({role}).subcontractMetadataMutation.phase,'SAVED');assert.equal(h.render({role}).projectMetadataMutation.phase,'IDLE');}
for(const role of ['ACCOUNTANT','DATA_ENTRY','MANAGEMENT_VIEWER','SYSTEM_ADMIN','PROJECT_MANAGER']) {h=s16Harness(s16Readers,s16Writer);h.render({role});await flush();const n=s16Writes;assert.equal(await h.render({role}).saveSubcontractMetadata(s16Command),false);assert.equal(s16Writes,n);}
for(const transition of ['company','role','user','logout','unmount']) {const delayed=deferred();let props={role:'ACCOUNTING_ADMIN'};h=s16Harness(s16Readers,{updateSubcontractMetadata:()=>delayed.promise});h.render(props);await flush();const pending=h.render(props).saveSubcontractMetadata(s16Command);await flush();assert.equal(await h.render(props).saveSubcontractMetadata(s16Command),false);if(transition==='unmount')h.unmount();else if(transition==='logout')h.session(null);else {props={...props,...(transition==='company'?{activeCompanyId:'company-b'}:transition==='role'?{role:'ACCOUNTANT'}:{userId:'user-b'})};if(transition==='user')h.session('user-b');h.render(props);await flush();}delayed.resolve({ok:true,subcontract:s16Subcontract});assert.equal(await pending,false);if(!['unmount','logout'].includes(transition))assert.equal(h.render(props).subcontractMetadataMutation.phase,'IDLE');}
let s16Reads=0,failS16=true;h=s16Harness({readActiveCompanySubcontracts:async()=>++s16Reads>1&&failS16?{ok:false,error:{source:'subcontracts'}}:{ok:true,data:[s16Subcontract]}},s16Writer);h.render(admin);await flush();assert.equal(await h.render(admin).saveSubcontractMetadata(s16Command),false);assert.equal(h.render(admin).subcontractMetadataMutation.phase,'REFRESH_ERROR');assert.equal(await h.render(admin).refreshSubcontracts(),false);failS16=false;assert.equal(await h.render(admin).refreshSubcontracts(),true);
for(const error of ['conflict','denied','uncertain','invalid']) {h=s16Harness(s16Readers,{updateSubcontractMetadata:async()=>({ok:false,error})});h.render(admin);await flush();assert.equal(await h.render(admin).saveSubcontractMetadata(s16Command),false);assert.equal(h.render(admin).subcontractMetadataMutation.error,error);assert.equal(await h.render(admin).saveSubcontractMetadata(s16Command),false);assert.equal(await h.render(admin).refreshSubcontracts(),true);}
console.log('Slice 16 Subcontract metadata repository/provider PASS: four-field allowlist, strict dates, exact token, allowed/denied roles, duplicate guard, selective refresh, recovery, and delayed-result isolation.');
