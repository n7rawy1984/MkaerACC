import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {createRequire} from 'node:module';
import ts from 'typescript';
const require=createRequire(import.meta.url);
function load(path,mocks={}) { const module={exports:{}}; const source=ts.transpileModule(readFileSync(new URL(`../${path}`,import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX}}).outputText;new Function('require','module','exports',source)(name=>mocks[name]??require(name),module,module.exports);return module.exports; }
const repo=load('src/financial/expensePostRepository.ts');
const recovery=load('src/financial/expensePostAttempt.ts',{'./expensePostRepository':repo});
const id=n=>`90000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const input={date:'2026-09-23',projectId:null,categoryId:id(1),supplierId:null,treasuryId:id(2),description:'  Test وصف  ',netMinor:'9000000000000000',vatMode:'ZERO',manualVatMinor:null,paymentMethod:'BANK',hasInvoice:false,invoiceNumber:null,notes:null};
for(const [text,expected] of [['0.01','1'],['1.5','150'],['90000000000000.00','9000000000000000']])assert.equal(repo.parseAED(text),expected);
for(const value of ['0','-1','1e3','1.001','NaN','1,000','90000000000000.01'])assert.throws(()=>repo.parseAED(value));
const payload=repo.expensePayload(id(3),id(4),{...input,target_funding_mode:'OWNER',target_paid_by_party_id:id(9),gross_amount_minor:'0'});
assert.deepEqual(payload,{target_company_id:id(3),target_expense_date:'2026-09-23',target_project_id:null,target_expense_category_id:id(1),target_description:'Test وصف',target_net_amount_minor:'9000000000000000',target_vat_mode:'ZERO',target_manual_vat_amount_minor:null,target_funding_mode:'TREASURY',target_treasury_account_id:id(2),target_paid_by_party_id:null,target_supplier_id:null,target_payment_method:'BANK',target_has_tax_invoice:false,target_invoice_number:null,target_notes:null,target_idempotency_key:id(4)});
assert.equal(Object.keys(payload).length,17);assert.equal(payload.target_funding_mode,'TREASURY');assert.equal(payload.target_paid_by_party_id,null);assert.equal(payload.target_net_amount_minor,'9000000000000000');assert.equal(payload.target_description,'Test وصف');assert.equal(payload.target_manual_vat_amount_minor,null);
for(const role of ['ACCOUNTING_ADMIN','ACCOUNTANT','PROCUREMENT','PROJECT_MANAGER','DATA_ENTRY','MANAGEMENT_VIEWER','SYSTEM_ADMIN'])assert.equal(repo.canPostExpense(role),['ACCOUNTING_ADMIN','ACCOUNTANT'].includes(role));
for(const change of [{date:'2026-02-30'},{netMinor:1},{projectId:'bad'},{vatMode:'AUTO_5',hasInvoice:false},{vatMode:'MANUAL',manualVatMinor:'0'},{hasInvoice:true,invoiceNumber:null}])assert.throws(()=>repo.normalizeExpenseInput({...input,...change}));
for(const mode of ['AUTO_5','MANUAL']) {const args=repo.expensePayload(id(3),id(4),{...input,vatMode:mode,hasInvoice:true,invoiceNumber:'INV',manualVatMinor:mode==='MANUAL'?'47':null});assert.equal(args.target_manual_vat_amount_minor,mode==='MANUAL'?'47':null);assert(!('target_gross_amount_minor' in args));}
const receipt={expense_id:id(6),expense_reference:'EXP-2026-1',journal_entry_id:id(7),replayed:false};
let calls=[];const {createClient}=require('@supabase/supabase-js');
const sdk=createClient('https://example.invalid','public-test-key',{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},global:{fetch:async(url,init)=>{calls.push({url:String(url),body:JSON.parse(init.body)});return new Response(JSON.stringify([receipt]),{headers:{'Content-Type':'application/json'}});}}});
assert.deepEqual(await repo.postTreasuryExpense(sdk,id(3),id(4),input),receipt);assert(calls[0].url.endsWith('/rpc/post_expense'));assert.equal(calls[0].body.target_net_amount_minor,'9000000000000000');assert.equal(calls[0].body.target_project_id,null);
const storage=()=>{const data=new Map();return {getItem:k=>data.get(k)??null,setItem:(k,v)=>data.set(k,v),removeItem:k=>data.delete(k)};};
let store=storage();const attempt={version:1,userId:id(8),companyId:id(3),key:id(4),input:repo.normalizeExpenseInput(input)};
recovery.saveAttempt(store,attempt);assert.deepEqual(recovery.loadAttempt(store,id(8),id(3)),attempt);assert.equal(recovery.loadAttempt(store,id(9),id(3)),null);
const client=(rpc,user=id(8))=>({auth:{getSession:async()=>({data:{session:user?{user:{id:user}}:null},error:null})},rpc});
let sends=0;let resolve;const wait=new Promise(r=>resolve=r);const concurrent=client(async()=>{sends++;await wait;return {data:[receipt],error:null};});
const one=recovery.sendAttempt(concurrent,store,attempt,true),two=recovery.sendAttempt(concurrent,store,attempt,true);assert.equal(one,two);resolve();const saved=await one;assert.equal(sends,1);assert.deepEqual(saved.receipt,receipt);assert.deepEqual(recovery.loadAttempt(store,id(8),id(3)).receipt,receipt);
await recovery.sendAttempt(client(()=>{throw new Error('must not post known receipt');}),store,saved);assert.equal(sends,1);
store=storage();let payloads=[];const uncertain=client(async(_name,args)=>{payloads.push(args);if(payloads.length===1)throw new Error('lost response after commit');return {data:[{...receipt,replayed:true}],error:null};});
await assert.rejects(recovery.sendAttempt(uncertain,store,attempt,true));const restored=recovery.loadAttempt(store,id(8),id(3));assert.deepEqual(restored,attempt);const replayed=await recovery.sendAttempt(uncertain,store,restored);assert(replayed.receipt.replayed);assert.deepEqual(payloads[0],payloads[1]);
store=storage();const rejection=client(async()=>({data:null,error:{code:'23514'}}));await assert.rejects(recovery.sendAttempt(rejection,store,attempt,true),/rejected/);assert.equal(recovery.loadAttempt(store,id(8),id(3)),null);
recovery.saveAttempt(store,attempt);await assert.rejects(recovery.sendAttempt(rejection,store,attempt));assert.deepEqual(recovery.loadAttempt(store,id(8),id(3)),attempt);
await assert.rejects(recovery.sendAttempt(client(()=>{throw new Error('must not send');},id(10)),store,attempt),/denied/);
await assert.rejects(recovery.sendAttempt(client(()=>{throw new Error('must not send');}),{...store,setItem:()=>{throw new Error('storage');}},attempt),/storage/);
for(const name of readdirSync(new URL('../src/financial/',import.meta.url))) {const s=readFileSync(new URL(`../src/financial/${name}`,import.meta.url),'utf8');assert(!/\.(insert|update|delete|upsert)\s*\(/.test(s.replace('inFlight.delete(lock)', '')));assert(!/localStorage|cas:v1|service_role|AppDataContext/.test(s));if(!['expensePostRepository.ts','expenseReverseRepository.ts'].includes(name))assert(!/\.rpc\(/.test(s));}
console.log('Treasury POST PASS: exact 17-field SDK payload, BIGINT/nulls/VAT inputs, role gates, frozen persisted retry/replay, duplicate coalescing, confirmed-receipt no-repost, rejection vs uncertainty, actor/storage failure and financial mutation boundary.');
