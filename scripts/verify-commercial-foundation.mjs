import assert from 'node:assert/strict';
import {createRequire} from 'node:module';
import {randomUUID} from 'node:crypto';
import {mkdirSync,writeFileSync} from 'node:fs';
import {commercialFixture} from './commercial-readiness-fixture.mjs';
const load=createRequire(import.meta.url)('./financial-test-load.cjs');
const {readFinancialStatements,calculateFinancialStatements,financialStatementReport}=load('src/reports/financialStatements.ts');
const out='/tmp/narvo-commercial-readiness';mkdirSync(out,{recursive:true});
const f=await commercialFixture(),{ids,date,company}=f,checks=[],executed=[];
const check=(v,n)=>{assert(v,n);checks.push(n);console.log('PASS',n);};
// Independent answer key is declared before business execution; figures are minor units.
const oracle=[
 ['OPEN','Certified bank/capital opening',[['BANK',10000000,0],['EQUITY',0,10000000]]],
 ['FUND','Bank to Custody advance',[['CUSTODY_ADVANCE',1000000,0],['BANK',0,1000000]]],
 ['CASH','Immediate supplies purchase, fictional 5% recoverable VAT',[['COMPANY_EXPENSE',10000,0],['INPUT_VAT',500,0],['CUSTODY_ADVANCE',0,10500]]],
 ['BILL1','Credit service purchase with supported fictional VAT',[['COMPANY_EXPENSE',100000,0],['INPUT_VAT',5000,0],['SUPPLIER_PAYABLE',0,105000]]],
 ['BILL2','Credit service purchase without recoverable VAT',[['COMPANY_EXPENSE',50000,0],['SUPPLIER_PAYABLE',0,50000]]],
 ['PARTIAL','Partial Supplier payment',[['SUPPLIER_PAYABLE',40000,0],['BANK',0,40000]]],
 ['MULTI','One payment across two invoices',[['SUPPLIER_PAYABLE',80000,0],['BANK',0,80000]]],
 ['FINAL','Final Supplier settlement',[['SUPPLIER_PAYABLE',35000,0],['BANK',0,35000]]],
 ['ADV','Supplier advance from Custody',[['SUPPLIER_ADVANCE',20000,0],['CUSTODY_ADVANCE',0,20000]]],
 ['BILL3','Third credit service invoice',[['COMPANY_EXPENSE',50000,0],['SUPPLIER_PAYABLE',0,50000]]],
 ['APPLY','Apply Supplier advance without another payment',[['SUPPLIER_PAYABLE',20000,0],['SUPPLIER_ADVANCE',0,20000]]],
 ['CREDIT','Service credit note',[['SUPPLIER_PAYABLE',5000,0],['COMPANY_EXPENSE',0,5000]]],
 ['STOCK','Physical receipt against GRNI',[['INVENTORY',100000,0],['GRNI',0,100000]]],
 ['STOCKBILL','Credit invoice matched to receipt with fictional VAT',[['COMPANY_EXPENSE',100000,0],['INPUT_VAT',5000,0],['SUPPLIER_PAYABLE',0,105000],['GRNI',100000,0],['COMPANY_EXPENSE',0,100000]]],
 ['ISSUE','Project consumes 20 of 100 units at historical cost',[['PROJECT_COST',20000,0],['INVENTORY',0,20000]]],
 ['CONTRACTADV','Contract advance, no cost recognition',[['SUBCONTRACTOR_ADVANCE',50000,0],['BANK',0,50000]]],
 ['CERT','Certified cost with 10% retention and advance recovery',[['PROJECT_COST_SUBCONTRACTORS',200000,0],['SUBCONTRACTOR_ADVANCE',0,10000],['SUBCONTRACTOR_RETENTION_PAYABLE',0,20000],['SUBCONTRACTOR_PAYABLE',0,170000]]],
 ['CONTRACTPAY','Partial certified Contractor settlement',[['SUBCONTRACTOR_PAYABLE',70000,0],['BANK',0,70000]]],
 ['PROJECT','Direct Custody-funded Project expense',[['PROJECT_COST',10000,0],['CUSTODY_ADVANCE',0,10000]]],
 ['RETURN','Custody cash return without changing costs',[['BANK',100000,0],['CUSTODY_ADVANCE',0,100000]]],
 ['EMPADV','Employee advance, recoverable asset',[['EMPLOYEE_ADVANCE',20000,0],['BANK',0,20000]]],
 ['PAYROLL','Approved payroll with advance recovery',[['PROJECT_COST',300000,0],['SALARY_PAYABLE',0,300000],['SALARY_PAYABLE',10000,0],['EMPLOYEE_ADVANCE',0,10000]]],
 ['SALARY','Partial salary settlement',[['SALARY_PAYABLE',250000,0],['BANK',0,250000]]],
 ['REVERSE','Controlled supplies reversal including original VAT',[['CUSTODY_ADVANCE',10500,0],['COMPANY_EXPENSE',0,10000],['INPUT_VAT',0,500]]]
].map(([id,description,lines])=>({id,description,date:id==='OPEN'?f.month:id==='EMPADV'?f.month.slice(0,7)+'-02':id==='PAYROLL'?new Date(Date.UTC(Number(f.month.slice(0,4)),Number(f.month.slice(5,7)),0)).toISOString().slice(0,10):date,expected:lines.map(([account,debit,credit])=>({account,debit:String(debit),credit:String(credit)}))}));
writeFileSync(out+'/independent-oracle.json',JSON.stringify(oracle,null,2));
const journalRows=async()=>f.sql('select e.id,e.journal_reference,e.posting_date::text,l.account_id,l.party_id,l.project_id,l.treasury_account_id,l.subcontract_id,l.debit_minor::text,l.credit_minor::text from public.journal_entries e join public.journal_lines l on l.company_id=e.company_id and l.journal_entry_id=e.id where e.company_id=$1 order by e.id,l.line_number',[company]);
const keyByAccount=new Map(Object.entries(ids).filter(([k])=>/^[A-Z_]+$/.test(k)).map(([k,v])=>[v,k]));
function totals(lines,expected=false){const sums=new Map();for(const l of lines){const key=expected?l.account:keyByAccount.get(l.account_id);assert(key,'Known control account required');const t=sums.get(key)??[0n,0n];t[0]+=BigInt(expected?l.debit:l.debit_minor);t[1]+=BigInt(expected?l.credit:l.credit_minor);sums.set(key,t);}return Object.fromEntries([...sums].sort(([a],[b])=>a.localeCompare(b)).map(([k,v])=>[k,v.map(String)]));}
async function run(id,fn){const expected=oracle.find(s=>s.id===id);assert(expected);const before=new Set((await journalRows()).map(r=>r.id)),receipt=await fn(),actual=(await journalRows()).filter(r=>!before.has(r.id));assert.equal(new Set(actual.map(r=>r.id)).size,['STOCKBILL','PAYROLL'].includes(id)?2:1,id+' creates only required canonical journals');assert.deepEqual(totals(actual),totals(expected.expected,true),id+' independent journal oracle');assert(actual.every(r=>r.posting_date===expected.date));executed.push({...expected,receipt,actual,status:'PASS'});check(true,id+' canonical journal matches independently declared debits/credits');return receipt;}
const deny=async(fn,name)=>{const before=await journalRows();await assert.rejects(fn);assert.deepEqual(await journalRows(),before);check(true,name+' rejects atomically without financial effects');};
let cash,b1,b2,b3,stock,contract,certificate;
try{
 const opening=await f.call('prepare_certified_opening',{target_company_id:company,target_request_key:randomUUID(),business_input:{opening_date:f.month,period_month:f.month,source_reference:'DEMO-OPENING',reason:'Fictional balanced opening position',evidence_reference:'Independent fixture balance sheet',period_reference:'Disposable test period',positions:[{kind:'TREASURY',treasury_id:ids.treasury,amount_minor:'10000000',side:'DEBIT'},{kind:'BALANCE_SHEET',account_id:ids.EQUITY,amount_minor:'10000000',side:'CREDIT'}]}});
 await run('OPEN',()=>f.call('approve_certified_opening',{target_company_id:company,target_draft_id:opening.id,target_approval_reference:'Approved fictional opening only',target_confirmed:true}));
 const openingTB=await readFinancialStatements(f.client(),{companyId:company,from:f.month,through:f.month},f.admin);check(openingTB.assets==='10000000'&&openingTB.equity==='10000000'&&openingTB.profit==='0','Opening Trial Balance and Balance Sheet reconcile to independent capital');
 await run('FUND',()=>f.sql("select *from public.post_custody_advance($1,$2,$3,$4,null,1000000,'BANK','DEMO-FUND',null,$5)",[company,date,ids.custodian,ids.treasury,randomUUID()]));
 const expense=(amount='10000',project=null,vat='ZERO')=>f.sql("select *from public.post_expense($1,$2,$3,$4,'Fictional paid expense',$5,$6,null,'CUSTODIAN',null,$7,null,'OTHER',$8,$9,'Disposable payment evidence',$10)",[company,date,project,ids.category,amount,vat,ids.custodian,vat!=='ZERO',vat==='ZERO'?null:'DEMO-TAX-CASH',randomUUID()]);
 cash=(await run('CASH',()=>expense('10000',null,'AUTO_5')))[0];
 const first=f.invoice({invoice_number:'DEMO-SERVICE-1',vat_mode:'AUTO_5',has_tax_invoice:true});b1=await run('BILL1',()=>f.postInvoice(first));b2=await run('BILL2',()=>f.postInvoice(f.invoice({net_minor:'50000',invoice_number:'DEMO-SERVICE-2'})));
 await deny(()=>f.postInvoice(first),'Duplicate invoice');await deny(()=>f.postInvoice(f.invoice({vat_mode:'AUTO_5',has_tax_invoice:false})),'Unsupported input VAT claim');
 await run('PARTIAL',()=>f.payment([{expense_id:b1.id,amount_minor:'40000'}]));
 await run('MULTI',()=>f.payment([{expense_id:b1.id,amount_minor:'60000'},{expense_id:b2.id,amount_minor:'20000'}]));
 await run('FINAL',()=>f.payment([{expense_id:b1.id,amount_minor:'5000'},{expense_id:b2.id,amount_minor:'30000'}]));
 await deny(()=>f.payment([{expense_id:b1.id,amount_minor:'1'}]),'Supplier overpayment');
 const adv=await run('ADV',()=>f.adjustment('ADVANCE',{custodian_id:ids.custodian,net_minor:'20000',vat_minor:'0'}));
 b3=await run('BILL3',()=>f.postInvoice(f.invoice({net_minor:'50000',invoice_number:'DEMO-SERVICE-3'})));
 await run('APPLY',()=>f.adjustment('ADVANCE_ALLOCATION',{expense_id:b3.id,advance_id:adv.id,net_minor:'20000'}));
 await run('CREDIT',()=>f.adjustment('CREDIT_NOTE',{expense_id:b3.id,net_minor:'5000',vat_minor:'0'}));
 const postStock=async(input)=>{let e=await f.inventory('SAVE',{id:randomUUID(),version:0,...input});e=await f.inventory('REVIEW',{id:e.document_id,version:e.version,evidence:'Fictional receiving and value checked'});return f.inventory('POST',{id:e.document_id,version:e.version,evidence:'Fictional authorized stock event'});};
 const invState=await f.call('read_inventory',{cid:company});ids.INVENTORY=invState.configuration?.inventory_account_id;ids.GRNI=invState.configuration?.grni_account_id;
 if(!ids.INVENTORY){const cfg=(await f.db.query('select *from public.inventory_configuration where company_id=$1',[company])).rows[0];ids.INVENTORY=cfg.inventory_account_id;ids.GRNI=cfg.grni_account_id;}
 keyByAccount.set(ids.INVENTORY,'INVENTORY');keyByAccount.set(ids.GRNI,'GRNI');
 const stockInput={kind:'RECEIPT',date,material_id:f.material,location_id:f.location,qty_micros:'100000000',unit:'UNIT',value_minor:'100000',recognition:'GRNI',supplier_id:ids.supplier,not_previously_recognized:true,source_reference:'DEMO-RECEIPT',evidence:'Fictional 100 units received at AED10 each'};
 stock=await run('STOCK',()=>postStock(stockInput));
 await run('STOCKBILL',()=>f.postInvoice(f.invoice({net_minor:'100000',vat_mode:'AUTO_5',has_tax_invoice:true,receipt_id:stock.document_id,purchase_kind:'INVENTORY',invoice_number:'DEMO-STOCK-BILL'})));
 await run('ISSUE',()=>postStock({...stockInput,kind:'ISSUE',qty_micros:'20000000',project_id:ids.project,recipient_id:ids.custodian,source_reference:'DEMO-PROJECT-ISSUE'}));
 contract=await f.call('create_subcontract',{target_company_id:company,business_input:{project_id:ids.project,subcontractor_id:ids.contractor,contract_number:'DEMO-CONTRACT',scope_of_work:'Fictional progress work',original_contract_value_minor:'1000000',retention_bps:'1000'}});
 await run('CONTRACTADV',()=>f.sql("select *from public.post_subcontractor_advance($1,$2,$3,$4,50000,'BANK','DEMO-ADV',null,$5)",[company,date,contract,ids.treasury,randomUUID()]));
 certificate=(await f.sql("select *from public.create_subcontractor_certificate_draft($1,$2,$3,'DEMO-CERT',200000,0,10000,'ZERO',null,false,null,null,'[]',null)",[company,date,contract]))[0].subcontractor_certificate_id;
 await run('CERT',()=>f.sql('select *from public.approve_post_subcontractor_certificate($1,$2,$3)',[company,certificate,randomUUID()]));
 await run('CONTRACTPAY',()=>f.sql("select *from public.post_subcontractor_payment($1,$2,$3,$4,70000,'BANK',null,null,$5,$6)",[company,date,contract,ids.treasury,JSON.stringify([{certificate_id:certificate,amount_minor:'70000'}]),randomUUID()]));
 await run('PROJECT',()=>expense('10000',ids.project));
 await run('RETURN',()=>f.sql("select *from public.post_custody_cash_return($1,$2,$3,$4,100000,'BANK','DEMO-RETURN',null,$5)",[company,date,ids.custodian,ids.treasury,randomUUID()]));
 // Complete fictional HR/attendance/payroll workflow. This is not a legal compliance fixture.
 const hr=(action,input)=>f.call('command_hr',{cid:company,request_id:randomUUID(),action,input:{evidence:'Approved fictional employment policy',...input}});
 const employee=await f.call('command_employee_master',{cid:company,request_id:randomUUID(),employee:null,expected_updated_at:null,input:{name:'Demo salaried employee',code:'DEMO-EMP',status:'ACTIVE'},reason:'Fictional employee identity'});
 await hr('POLICY',{effective_month:f.month,method:'SCHEDULED_MINUTES',timezone:'Asia/Dubai',approved:true,version:0});
 await hr('SETUP',{version:0,advance_account_id:ids.EMPLOYEE_ADVANCE,SALARY_PAYABLE:ids.SALARY_PAYABLE,PROJECT_COST:ids.PROJECT_COST,COMPANY_EXPENSE:ids.COMPANY_EXPENSE});
 await hr('TERMS',{employee_id:employee.id,effective_on:f.month,employed_from:f.month,basic_minor:'300000',allowances:[],weekdays:[1,2,3,4,5,6,7],start_minute:480,end_minute:1020,break_minutes:60,project_id:ids.project,status:'ACTIVE',version:0});
 await f.sql("select public.save_payroll_profile($1,$2,0,'DEMO-EMP','STAFF','Demo operator','Demo site',$3,300000,'BANK','ACTIVE')",[company,employee.id,ids.project]);
 const hrRead=()=>f.call('read_hr_workspace',{cid:company,m:f.month});let h=await hrRead();
 await f.call('bulk_hr_attendance',{cid:company,request_id:randomUUID(),entries:h.days.filter(d=>d.employee_id===employee.id).map(d=>({employee_id:employee.id,day:d.day,version:0,status:'PRESENT',project_id:ids.project,start_minute:480,end_minute:1020,break_minutes:60,paid_leave_minutes:0,overtime_earned_minor:'0',evidence:'Fictional scheduled full-period attendance'}))});
 const employeeAdvance=await run('EMPADV',()=>hr('ADVANCE',{employee_id:employee.id,treasury_id:ids.treasury,date:f.month.slice(0,7)+'-02',amount_minor:'20000',monthly_limit_minor:'10000'}));
 await hr('RECOVERY',{month:f.month,advance_id:employeeAdvance.id,amount_minor:'10000',version:0});
 h=await hrRead();await hr('REVIEW',{month:f.month,version:h.period.revision});
 const payrollPeriod=await f.call('refresh_payroll_draft',{target_company_id:company,target_month:f.month,target_version:0});
 let payroll=await f.call('read_payroll_draft',{target_company_id:company,target_month:f.month});
 await f.call('prepare_payroll_accounting',{target_company_id:company,target_period_id:payrollPeriod,target_version:payroll.period.version,target_allocations:{[payroll.rows[0].id]:ids.project},target_classifications:{}});
 payroll=await f.call('read_payroll_draft',{target_company_id:company,target_month:f.month});await f.call('review_payroll_draft',{target_company_id:company,target_period_id:payrollPeriod,target_version:payroll.period.version});
 payroll=await f.call('read_payroll_draft',{target_company_id:company,target_month:f.month});
 const accrued=await run('PAYROLL',()=>f.call('post_payroll',{target_company_id:company,target_period_id:payrollPeriod,target_version:payroll.period.version,target_idempotency_key:randomUUID()}));
 const entitlement=(await f.db.query('select id from public.payroll_entitlements where company_id=$1 and payroll_id=$2',[company,accrued])).rows[0].id;
 await run('SALARY',()=>f.sql("select public.pay_salary($1,$2,$3,$4,250000,'DEMO-SALARY',$5)",[company,entitlement,ids.treasury,date,randomUUID()]));
 await run('REVERSE',()=>f.sql("select *from public.reverse_expense($1,$2,$3,'Fictional reversal with source preserved',$4)",[company,cash.expense_id,date,randomUUID()]));
 await deny(()=>f.sql("select *from public.reverse_expense($1,$2,$3,'Repeat reversal',$4)",[company,cash.expense_id,date,randomUUID()]),'Already reversed event');
 await deny(()=>f.postInvoice(f.invoice(),randomUUID(),f.viewer),'Management Viewer posting');await deny(()=>f.postInvoice(f.invoice(),randomUUID(),f.foreign),'Cross-company posting');
 await deny(()=>f.sql("update public.journal_lines set debit_minor=1 where company_id=$1",[company]),'Immutable journal direct write');
 const journalCount=new Set((await journalRows()).map(r=>r.id)).size;
 const result=await readFinancialStatements(f.client(),{companyId:company,from:f.month,through:date},f.admin);
 const expectedTotals=totals(oracle.flatMap(r=>r.expected),true),actualTotals=totals(await journalRows());assert.deepEqual(actualTotals,expectedTotals);check(true,'Entire ending ledger reconciles to predeclared independent scenario oracle');
 check(result.profit==='-725000'&&result.assets==='9565000'&&result.liabilities==='290000'&&result.equity==='10000000'&&result.unclosedResult==='-725000','Independent P&L loss AED7250 and Balance Sheet equation reconcile');
 const ap=await f.readAP(),inventory=await f.call('read_inventory',{cid:company});
 check(ap.invoices.reduce((n,i)=>n+BigInt(i.outstanding_minor),0n)===130000n&&ap.gl.reduce((n,g)=>n+BigInt(g.payable_minor),0n)===130000n,'Supplier outstanding AED1300 equals AP GL control');
 check(inventory.stock_value_minor==='80000','Remaining 80 units value AED800 equals independent valuation');
 const custody=result.rows.find(r=>r.account.id===ids.CUSTODY_ADVANCE).closing;check(custody==='870000','Custody AED8700 excludes reversed expense and includes one return');
 check(result.rows.find(r=>r.account.id===ids.SUBCONTRACTOR_ADVANCE).closing==='40000'&&result.rows.find(r=>r.account.id===ids.SUBCONTRACTOR_PAYABLE).closing==='-100000'&&result.rows.find(r=>r.account.id===ids.SUBCONTRACTOR_RETENTION_PAYABLE).closing==='-20000','Contract advance AED400, payable AED1000 and retention AED200 remain distinct');
 check(result.rows.find(r=>r.account.id===ids.EMPLOYEE_ADVANCE).closing==='10000'&&result.rows.find(r=>r.account.id===ids.SALARY_PAYABLE).closing==='-40000','Employee advance AED100 and salary liability AED400 reconcile without reducing earned payroll cost');
 const beforeReports=await journalRows();for(const lang of['en','ar']){const report=financialStatementReport(result,f.name,lang);check(report.sections.length===3&&report.sections[0].rows.length===result.rows.length+1,lang+' report includes all account rows, zero accounts and totals');}
 await assert.rejects(()=>readFinancialStatements(f.client(f.viewer),{companyId:company,from:f.month,through:date},f.viewer),/restricted/);check(true,'Restricted Payroll visibility cannot return a falsely complete Company statement');
 await assert.rejects(()=>readFinancialStatements(f.client(f.foreign),{companyId:company,from:f.month,through:date},f.foreign),/restricted/);check(true,'Foreign Company report is denied before financial reads');
 await assert.rejects(()=>readFinancialStatements(f.client(),{companyId:company,from:date,through:date},randomUUID()),/session/);check(true,'Wrong actor session cannot read statements');
 const future=await readFinancialStatements(f.client(),{companyId:company,from:'2027-01-01',through:'2027-01-31'},f.admin);check(future.debit==='0'&&future.credit==='0'&&future.profit==='0'&&future.assets===result.assets&&future.unclosedResult===result.unclosedResult,'Period income zero does not erase prior balances or cumulative unclosed loss');
 const acc=(await f.db.query('select id,company_id,code,name,account_type from public.accounts where company_id=$1',[company])).rows;
 const entries=(await f.db.query('select *,posting_date::text from public.journal_entries where company_id=$1',[company])).rows,lines=(await f.db.query('select *,debit_minor::text,credit_minor::text from public.journal_lines where company_id=$1',[company])).rows;
 assert.throws(()=>calculateFinancialStatements(result.scope,acc,entries,lines.slice(1)));check(true,'Incomplete or unbalanced ledger fails closed rather than inventing balances');
 assert.throws(()=>calculateFinancialStatements({...result.scope,from:'2026-11-31'},acc,entries,lines));check(true,'Impossible calendar date rejected without timezone conversion');
 assert.deepEqual(await journalRows(),beforeReports);check(true,'All report reads, failed actions and exports preserve posted financial history');
 check(journalCount===26&&executed.length===24,'24 unique economic scenarios produced 26 canonical journals; stock invoice and Payroll recovery each have an atomic journal pair');
 const record={status:'PARTIAL_PROGRAM',milestone:'Financial statement foundation and canonical multi-module simulation',environment:'Disposable in-process PGlite PostgreSQL, no network/hosted credentials',company:{id:company,name:f.name,bootstrap:'Synthetic fixture bootstrap; not a Company-onboarding acceptance test'},period:{from:f.month,through:date},checks,scenarios:executed,statements:result,openingTrialBalance:openingTB,subledgers:{supplierAP:ap,inventory,custody_minor:custody},journalCount,reversals:1,hostedRequests:0,blocked:['AR sales/customer cycle: no canonical implementation found','Fixed assets/depreciation lifecycle: no canonical implementation found','Accrual/prepayment operational commands: no canonical implementation found','Formal period close/closing entries: existing correction-period lock is not full fiscal closing','Cash Flow Statement: classification/cash-equivalent policy and reporting implementation missing','Remaining leave/absence/partial-hours and native concurrency/UI scenarios: not executed by this bounded test'],readiness:'NOT COMMERCIALLY READY'};
 writeFileSync(out+'/foundation-results.json',JSON.stringify(record,null,2));
 // Browser fixture reuses the same actual disposable posted results, no fabricated balances.
 writeFileSync(out+'/statement-snapshot.json',JSON.stringify({company,user:f.admin,name:f.name,date,month:f.month,accounts:acc,journal_entries:entries,journal_lines:lines,result},null,2));
 console.log('PASS ALL',checks.length,'checks;',executed.length,'economic scenarios');
}catch(e){writeFileSync(out+'/foundation-failure.json',JSON.stringify({message:e.message,code:e.code,detail:e.detail,where:e.where,checks,executed},null,2));console.error(e.stack,e.code,e.detail,e.where);process.exitCode=1;}finally{await f.close();}
