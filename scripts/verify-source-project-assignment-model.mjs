import assert from'node:assert/strict';import{readFileSync}from'node:fs';import{createRequire}from'node:module';import{resolve}from'node:path';
const require=createRequire(resolve('package.json')),ts=require('typescript');
const load=(path,mocks={})=>{const mod={exports:{}};const code=ts.transpileModule(readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText;new Function('require','module','exports',code)(n=>mocks[n]??require(n),mod,mod.exports);return mod.exports;};
const model=load('src/historical/sourceModel.ts'),{assignmentBlock,assignmentReport,assignmentSummary,prepareAssignment}=load('src/historical/sourceProjectAssignment.ts',{'./sourceModel':model});
const row={id:'s1',company_id:'c1',record_type:'GENERAL',source_reference:'REF-1',source_month:'2026-09',source_date:'2026-09-20',description:'Known source cost',outflow_minor:'9007199254740991',completion:{},classification:{nature:'EXPENSE'},raw_source:{Project:'Unverified name'},review_status:'REVIEWED',expense_id:null,payroll_entitlement_id:null,updated_at:'2026-11-03T00:00:00Z'};
assert.equal(assignmentBlock(row,'c1'),null);assert.equal(assignmentBlock(row,'c2'),'foreign');assert.equal(assignmentBlock({...row,expense_id:'expense'},'c1'),'posted');assert.equal(assignmentBlock({...row,review_status:'CANCELLED'},'c1'),'archived');assert.equal(assignmentBlock({...row,classification:{nature:'SUPPLIER_PAYMENT'}},'c1'),'nature');assert.equal(assignmentBlock({...row,completion:{amount_minor:'0'}},'c1'),'amount');
const attempt={request_id:'request',reason:'Verified attribution',items:[{source_id:'s1',expected_updated_at:row.updated_at,scope:'PROJECT',project_id:'p1'}]},projects=[{id:'p1',companyId:'c1',code:'PROJ-1'}];
for(const locale of['en','ar']){const report=assignmentReport([row],'c1','Company',projects,locale,attempt,[]);assert.equal(report.locale,locale);assert.equal(report.company,'Company');assert.equal(report.period,'2026-09');assert.equal(report.sections[0].rows[0][6],'—','Worksheet label is never a canonical Project');assert.equal(report.sections[0].rows[0][8],'PROJ-1');assert.deepEqual(report.sections[0].rows.at(-1)[3],{minor:'9007199254740991'});assert(report.note.includes(locale==='ar'?'وليست تكاليف مرحلة':'not posted project costs'));}
assert.throws(()=>assignmentReport([row],'c2','Foreign',[],'en',null,[]),/Company changed/);
console.log('PASS: eligibility, no text matching, Company boundary, exact BIGINT proposal totals and bilingual report basis');

const second={...row,id:'s2',source_reference:'REF-2',outflow_minor:'11'},third={...row,id:'s3',source_reference:'REF-3',outflow_minor:'9'};
const masters=[{id:'p1',companyId:'c1',code:'P1',status:'ACTIVE'},{id:'p2',companyId:'c1',code:'P2',status:'ACTIVE'},{id:'closed',companyId:'c1',status:'CLOSED'},{id:'foreign',companyId:'c2',status:'ACTIVE'}];
const batch=prepareAssignment([row,second,third],'c1',masters,['s1','s2','s3'],{s1:'p1',s2:'p2',s3:'COMPANY'},'  Confirmed source attribution  ');
assert.equal(batch.reason,'Confirmed source attribution');assert.equal(new Set(batch.items.map(i=>i.project_id)).size,3);
assert.deepEqual(assignmentSummary([row,second,third],'c1',batch.items).map(g=>g.amount),['9007199254740991','11','9']);
assert.equal(assignmentSummary([row,second,third],'c1',batch.items).reduce((n,g)=>n+BigInt(g.amount),0n),9007199254741011n);
const plan=(rows=[row],dest={s1:'p1'},ids=['s1'])=>prepareAssignment(rows,'c1',masters,ids,dest,'Reason');
assert.throws(()=>plan([row],{},['s1']),/Destination/);assert.throws(()=>plan([row],{s1:'closed'}),/Project unavailable/);assert.throws(()=>plan([row],{s1:'foreign'}),/Project unavailable/);
assert.throws(()=>plan([row],{s1:'p1'},['s1','s1']),/Invalid selection/);assert.throws(()=>plan([{...row,company_id:'c2'}]),/Source changed/);assert.throws(()=>plan([{...row,allocation_scope:'PROJECT',assigned_project_id:'p1'}]),/unchanged/);
assert.throws(()=>assignmentSummary([{...row,updated_at:'later'},second,third],'c1',batch.items),/Source changed/);
for(const nature of ['SUPPLIER_PAYMENT','SUPPLIER_INVOICE_OR_COMMITMENT','INVENTORY_PURCHASE','EMPLOYEE_ADVANCE','PAYROLL_OR_SALARY_PAYMENT','TREASURY_INFLOW_OR_FUNDING'])assert.throws(()=>plan([{...row,classification:{nature}}]),/Source changed/);
for(const locale of ['en','ar']){const report=assignmentReport([row,second,third],'c1','Company',masters,locale,batch,[]);assert.equal(report.sections[1].rows.length,4);assert.deepEqual(report.sections[1].rows.at(-1).at(-1),{minor:'9007199254741011'});}
console.log('PASS: mixed destinations, explicit overhead, exact reconciled totals, stale/no-op/Company/unsupported classification guards');
