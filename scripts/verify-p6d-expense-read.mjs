import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { createRequire } from 'node:module';
import ts from 'typescript';
const require = createRequire(import.meta.url);
function moduleAt(path, mocks = {}) {
  const source = ts.transpileModule(readFileSync(new URL(`../${path}`, import.meta.url), 'utf8'), {
    compilerOptions: { module: ts.ModuleKind.CommonJS, jsx: ts.JsxEmit.ReactJSX, target: ts.ScriptTarget.ES2022 },
  }).outputText;
  const module = { exports: {} };
  new Function('require', 'module', 'exports', source)(name => mocks[name] ?? require(name), module, module.exports);
  return module.exports;
}
const repo = moduleAt('src/financial/expenseRepository.ts');
const row = {
  id:'expense-a',company_id:'company-a',expense_reference:'EXP-2026-000001',expense_date:'2026-09-23',
  project_id:null,expense_category_id:'category-a',supplier_id:'supplier-a',description:'Expense وصف',
  net_amount_minor:'9000000000000000',vat_mode:'ZERO',vat_amount_minor:'0',gross_amount_minor:'9000000000000000',
  funding_mode:'SUPPLIER_CREDIT',treasury_account_id:null,paid_by_party_id:null,payment_method:'OTHER',
  has_tax_invoice:false,invoice_number:null,notes:null,status:'POSTED',posted_journal_entry_id:'journal-a',reversal_journal_entry_id:null,
  created_at:'2026-09-23T00:00:00Z',created_by:'actor',updated_at:'2026-09-23T00:00:00Z',updated_by:'actor',
  posted_at:'2026-09-23T00:00:00Z',posted_by:'actor',reversed_at:null,reversed_by:null,
};
assert.deepEqual(repo.mapExpense(row),row);
for(const status of ['DRAFT','POSTED','REVERSED']) assert.equal(repo.mapExpense({...row,status}).status,status);
for(const field of ['net_amount_minor','vat_amount_minor','gross_amount_minor']) {
  for(const bad of [9000000000000000,null,'1.00','1e2','-1','9223372036854775808']) assert.throws(()=>repo.mapExpense({...row,[field]:bad}));
  assert.equal(repo.mapExpense({...row,[field]:'9007199254740993'})[field],'9007199254740993');
}
assert.throws(()=>repo.mapExpense({...row,status:'UNKNOWN'}));
for(const [minor,display] of [['0','0.00'],['1','0.01'],['105','1.05'],['9000000000000000','90000000000000.00'],['9007199254740993','90071992547409.93']]) assert.equal(repo.displayMinor(minor),display);
function queryClient(result) {
 const calls=[];const q={then:(a,b)=>Promise.resolve(result).then(a,b)};
 for(const method of ['select','eq','order','range']) q[method]=(...args)=>{calls.push([method,...args]);return q;};
 return {calls,from:table=>{calls.push(['from',table]);return q;}};
}
let client=queryClient({data:[row],error:null});
assert.deepEqual(await repo.readExpenses(client,'company-a'),{rows:[row],hasNext:false});
assert.deepEqual(client.calls.filter(c=>c[0]==='eq'),[['eq','company_id','company-a']]);
assert.deepEqual(client.calls.filter(c=>c[0]==='order'),[['order','expense_date',{ascending:false}],['order','id',{ascending:true}]]);
const projection=client.calls.find(c=>c[0]==='select')[1];
for(const field of ['net_amount_minor','vat_amount_minor','gross_amount_minor']) assert(projection.includes(`${field}::text`));
assert(!projection.includes('*'));assert.equal(projection.split(',').length,30);
client=queryClient({data:Array.from({length:51},(_,i)=>({...row,id:String(i)})),error:null});
const page=await repo.readExpenses(client,'company-a',2);assert.equal(page.rows.length,50);assert(page.hasNext);assert.deepEqual(client.calls.at(-1),['range',100,150]);
assert.deepEqual(await repo.readExpenses(queryClient({data:[],error:null}),'company-a'),{rows:[],hasNext:false});
for(const response of [{data:null,error:null},{data:[row],error:{code:'42501'}},{data:[{...row,company_id:'company-b'}],error:null},{data:[{...row,net_amount_minor:1}],error:null}]) await assert.rejects(repo.readExpenses(queryClient(response),'company-a'));
for(const p of [-1,1.1,Number.MAX_SAFE_INTEGER]) await assert.rejects(repo.readExpenses(queryClient({data:[],error:null}),'company-a',p));
const {createClient}=require('@supabase/supabase-js');
let requestUrl;
const transportClient=createClient('https://example.invalid','public-test-key',{
 auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},
 global:{fetch:async(url)=>{requestUrl=new URL(String(url));return new Response(JSON.stringify([row]),{headers:{'Content-Type':'application/json'}});}},
});
assert.deepEqual(await repo.readExpenses(transportClient,'company-a'),{rows:[row],hasNext:false});
assert.equal(requestUrl.pathname,'/rest/v1/expenses');
assert.equal(requestUrl.searchParams.get('company_id'),'eq.company-a');
assert.equal(requestUrl.searchParams.get('limit'),'51');
for(const field of ['net_amount_minor','vat_amount_minor','gross_amount_minor']) assert(requestUrl.searchParams.get('select').includes(`${field}::text`));
console.log('Expense repository PASS: scoped paged projection, exact amounts, all 30 fields, nulls, lifecycle, IDs/journals and errors.');
const flush=async()=>{for(let i=0;i<20;i++)await Promise.resolve();};
function deferred(){let resolve;const promise=new Promise(r=>resolve=r);return {promise,resolve};}
function harness(reader) {
 let cursor=0,previousDeps,cleanup,effect;const slots=[];let user='user-a',sessionError=null,callback,reads=0,unsubscribed=0;
 const hooks={useState(initial){const i=cursor++;if(!(i in slots))slots[i]=initial;return [slots[i],value=>slots[i]=typeof value==='function'?value(slots[i]):value];},useEffect(run,deps){if(!previousDeps||deps.some((v,i)=>v!==previousDeps[i])){effect=()=>{cleanup?.();cleanup=run();};previousDeps=deps;}}};
 const client={auth:{getSession:async()=>({data:{session:user?{user:{id:user}}:null},error:sessionError}),onAuthStateChange:cb=>{callback=cb;return {data:{subscription:{unsubscribe(){unsubscribed++;}}}};}}};
 const {useExpenseRead: runHook}=moduleAt('src/financial/useExpenseRead.ts',{react:hooks,'./expenseRepository':{readExpenses:async(...args)=>{reads++;return reader(...args);}}});
 return {render(props={}){cursor=0;const result=runHook(client,props.user??'user-a',props.company??'company-a',props.role??'ACCOUNTANT',props.page??0,props.revision??0);const run=effect;effect=null;run?.();return result;},session(value,error=null){user=value;sessionError=error;},event(event,value){user=value;callback(event,value?{user:{id:value}}:null);},unmount(){cleanup?.();},reads:()=>reads,unsubscribed:()=>unsubscribed};
}
let h=harness(async()=>({rows:[row],hasNext:false}));assert.equal(h.render().phase,'LOADING');await flush();assert.equal(h.render().phase,'READY');h.render();await flush();assert.equal(h.reads(),1);
for(const transition of [{company:'company-b'},{user:'user-b'},{role:'SYSTEM_ADMIN'},{page:1},{revision:1}]) {
 const gate=deferred();let n=0;h=harness(async()=>++n===1?gate.promise:{rows:[],hasNext:false});h.render();await flush();
 if(transition.user)h.session(transition.user);
 assert.equal(h.render(transition).phase,'LOADING');await flush();gate.resolve({rows:[row],hasNext:false});await flush();assert.deepEqual(h.render(transition),{phase:'READY',rows:[],hasNext:false});
}
for(const kind of ['logout','different-user','unmount','session-error','missing-session']) {
 const gate=deferred();h=harness(()=>gate.promise);h.render();await flush();
 if(kind==='logout')h.event('SIGNED_OUT',null);
 if(kind==='different-user')h.event('SIGNED_IN','user-b');
 if(kind==='unmount')h.unmount();
 if(kind==='session-error')h.session('user-a',new Error('session'));
 if(kind==='missing-session')h.session(null);
 gate.resolve({rows:[row],hasNext:false});await flush();assert.notEqual(h.render().phase,'READY');
 if(kind==='unmount')assert.equal(h.unsubscribed(),1);
}
h=harness(async()=>{throw new Error('network');});h.render();await flush();assert.equal(h.render().phase,'ERROR');
h=harness(async()=>({rows:[row],hasNext:false}));h.session(null);h.render();await flush();assert.equal(h.render().phase,'ERROR');assert.equal(h.reads(),0);
h=harness(async()=>({rows:[row],hasNext:false}));h.render();await flush();h.event('SIGNED_OUT',null);assert.equal(h.render().phase,'ERROR');
let fail=true;h=harness(async()=>{if(fail)throw new Error('network');return {rows:[],hasNext:false};});
h.render();await flush();assert.equal(h.render().phase,'ERROR');fail=false;assert.equal(h.render({revision:1}).phase,'LOADING');await flush();assert.deepEqual(h.render({revision:1}),{phase:'READY',rows:[],hasNext:false});
console.log('Expense lifecycle PASS: scope/role/user/page/refresh races, logout, unmount, session errors and no unchanged-scope reload.');
const React=require('react');const {renderToStaticMarkup}=require('react-dom/server');
for(const lang of ['en','ar']) {
 const dictionary=moduleAt(`src/i18n/${lang}.ts`).default;
 const t=(key,vars={})=>{assert.equal(typeof dictionary[key],'string',key);return dictionary[key].replace('{page}',String(vars.page??''));};
 for(const state of [{phase:'LOADING'},{phase:'ERROR'},{phase:'READY',rows:[],hasNext:false},{phase:'READY',rows:[{...row,status:'REVERSED',reversal_journal_entry_id:'reversal-a'}],hasNext:true}]) {
  const {ExpenseReadContent}=moduleAt('src/financial/ExpenseReadPanel.tsx',{'../auth/AuthContext':{},'./TreasuryExpensePost':{TreasuryExpensePost:()=>null},'./expensePostRepository':{canPostExpense:()=>false},'./ExpenseReverseAction':{ExpenseReverseAction:()=>null},'./expenseReverseRepository':{canReverseExpense:()=>false},'../i18n/I18nContext':{useT:()=>t},'../lib/supabase':{getSupabaseClient:()=>({})},'./expenseRepository':repo,'./useExpenseRead':{useExpenseRead:()=>state}});
  const html=renderToStaticMarkup(React.createElement(ExpenseReadContent,{userId:'user-a',companyId:'company-a',role:'ACCOUNTANT'}));
  assert(!/<form|<input/.test(html));
  if(state.phase==='READY'&&state.rows.length){for(const value of ['90000000000000.00','journal-a','reversal-a','supplier-a',dictionary['expenseRead.REVERSED']])assert(html.includes(value));}
  else assert(html.includes(dictionary[`expenseRead.${state.phase==='READY'?'empty':state.phase==='ERROR'?'error':'loading'}`]));
 }
}
for(const name of ['expenseRepository.ts','useExpenseRead.ts','ExpenseReadPanel.tsx']) {
 const source=readFileSync(new URL(`../src/financial/${name}`,import.meta.url),'utf8');
 assert(!/\.(insert|update|upsert|delete|rpc)\s*\(/.test(source),name);
 assert(!/localStorage|cas:v1|AppDataContext|service_role|\/storage\/|\/seed\/|\/pages\//.test(source),name);
}
assert(readFileSync(new URL('../src/auth/ProtectedApplication.tsx',import.meta.url),'utf8').includes('path="/expenses" element={<TenantReadyApplication view="expenses" />}'));
console.log('Expense EN/AR rendering and read-only production boundary PASS. No browser/Auth fixture or hosted mutation used.');
