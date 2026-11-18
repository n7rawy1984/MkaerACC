// Fixture restoration only; original foundation evidence is preserved, not reverified here.
import{readFileSync,writeFileSync}from'node:fs';
import {randomUUID} from 'node:crypto';
import {commercialFixture} from './commercial-readiness-fixture.mjs';
export async function restoreCommercialDataset(){
 const f=await commercialFixture({company:'35866f1d-2888-40f2-9690-015802ec13a8',date:'2026-11-17'}),{ids,date,company}=f;
 const restored=[],run=async(id,fn)=>{console.log('Fixture event',id);const before=new Set((await f.db.query('select id from public.journal_entries where company_id=$1',[company])).rows.map(r=>r.id)),receipt=await fn(),journals=(await f.db.query('select id from public.journal_entries where company_id=$1',[company])).rows.filter(r=>!before.has(r.id)).map(r=>r.id);restored.push({id,receipt,restored_journals:journals});return receipt;},keyByAccount=new Map();let cash,b1,b2,b3,stock,contract,certificate;
 const opening=await f.call('prepare_certified_opening',{target_company_id:company,target_request_key:randomUUID(),business_input:{opening_date:f.month,period_month:f.month,source_reference:'DEMO-OPENING',reason:'Fictional balanced opening position',evidence_reference:'Independent fixture balance sheet',period_reference:'Disposable test period',positions:[{kind:'TREASURY',treasury_id:ids.treasury,amount_minor:'10000000',side:'DEBIT'},{kind:'BALANCE_SHEET',account_id:ids.EQUITY,amount_minor:'10000000',side:'CREDIT'}]}});
 await run('OPEN',()=>f.call('approve_certified_opening',{target_company_id:company,target_draft_id:opening.id,target_approval_reference:'Approved fictional opening only',target_confirmed:true}));
 await run('FUND',()=>f.sql("select *from public.post_custody_advance($1,$2,$3,$4,null,1000000,'BANK','DEMO-FUND',null,$5)",[company,date,ids.custodian,ids.treasury,randomUUID()]));
 const expense=(amount='10000',project=null,vat='ZERO')=>f.sql("select *from public.post_expense($1,$2,$3,$4,'Fictional paid expense',$5,$6,null,'CUSTODIAN',null,$7,null,'OTHER',$8,$9,'Disposable payment evidence',$10)",[company,date,project,ids.category,amount,vat,ids.custodian,vat!=='ZERO',vat==='ZERO'?null:'DEMO-TAX-CASH',randomUUID()]);
 cash=(await run('CASH',()=>expense('10000',null,'AUTO_5')))[0];
 const first=f.invoice({invoice_number:'DEMO-SERVICE-1',vat_mode:'AUTO_5',has_tax_invoice:true});b1=await run('BILL1',()=>f.postInvoice(first));b2=await run('BILL2',()=>f.postInvoice(f.invoice({net_minor:'50000',invoice_number:'DEMO-SERVICE-2'})));
 await run('PARTIAL',()=>f.payment([{expense_id:b1.id,amount_minor:'40000'}]));
 await run('MULTI',()=>f.payment([{expense_id:b1.id,amount_minor:'60000'},{expense_id:b2.id,amount_minor:'20000'}]));
 await run('FINAL',()=>f.payment([{expense_id:b1.id,amount_minor:'5000'},{expense_id:b2.id,amount_minor:'30000'}]));
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
 const original=JSON.parse(readFileSync('/tmp/narvo-commercial-readiness/foundation-results.json','utf8'));writeFileSync('/tmp/narvo-commercial-readiness/foundation-restoration-map.json',JSON.stringify({reason:'Original disposable in-memory database was closed; restored exact business inputs via canonical commands once as continuation fixture initialization. Original evidence unchanged. IDs of new local documents differ.',original_company:original.company.id,restored_company:company,scenarios:restored.map(r=>({...r,original_journals:[...new Set(original.scenarios.find(x=>x.id===r.id).actual.map(l=>l.id))]}))},null,2));
 return f;
}
