import assert from 'node:assert/strict';
import load from './financial-test-load.cjs';
const m=load('src/historical/sourceModel.ts'),p=load('src/historical/sourceReviewPresentation.ts'),{sourceReport}=load('src/reports/sourceReports.ts');
const checks=[];function check(value,message){assert(value,message);checks.push(message);console.log('PASS',message)}
const row={id:'SYN-HOLD',record_type:'GENERAL',source_reference:'SYN-HOLD',source_file:'synthetic.xlsx',source_month:'2026-10',source_date:'2026-11-09',description:'Synthetic expense claim',outflow_minor:'500000',funding_minor:null,payroll_net_minor:null,classification:{nature:'EXPENSE'},completion:{operational_review_notes:'NEEDS ACCOUNTANT REVIEW — NOT POSTED. Evidence requirements: VAT_AND_RECOGNITION_PERIOD_REQUIRE_VERIFICATION, ACTUAL_FUNDING_SOURCE_UNCONFIRMED.'},raw_source:{original:'Immutable'},review_status:'PENDING',expense_id:null,payroll_entitlement_id:null,cash_treasury_id:'IMPORTED-TREASURY-CLAIM'};
const original=JSON.stringify(row);
check(m.sourceAccounting(row)==='CLASSIFIED_UNPOSTED','Imported classification never implies a draft or posting');
check(m.sourceAccounting({...row,classification:{nature:'NEEDS_REVIEW'}})==='UNCLASSIFIED','Unclassified source is separate from classified-unposted');
check(m.sourceAccounting({...row,source_document:{state:'DRAFT'}})==='DOCUMENT_DRAFT','Existing draft retains priority over source classification');
check(p.sourceNeedsReview(row),'Imported Treasury claim does not remove saved payer/VAT holds');
check(p.sourceSavedReviewReasons(row,'en').join().includes('Actual payer')&&p.sourceSavedReviewReasons(row,'ar').join().includes('الضريبية'),'Saved specific payer and VAT evidence requirements are bilingual');
check(p.sourceUnpostedWarning('ar')==='غير مرحّل — يحتاج مراجعة','Exact requested Arabic warning');
for(const locale of ['en','ar']){const report=sourceReport([row],'Synthetic',locale,'DATE','GENERAL','11/2026');const section=report.sections.at(-1);check(section.rows[0].includes(p.sourceUnpostedWarning(locale))&&section.rows[0].some(x=>typeof x==='string'&&x.includes(p.sourceSavedReviewReasons(row,locale)[0]))&&section.rows[0].length===section.headers.length,locale+' export retains warning, saved evidence and aligned columns');}
for(const posted of [{...row,expense_id:'existing-posted'},{...row,source_document:{state:'POSTED',receipt:{journal:'existing-journal'}}}])check(!p.sourceNeedsReview(posted)&&!p.sourceSavedReviewReasons(posted,'en').length&&m.sourceAccounting(posted)==='POSTED','Posted source is not mislabelled unposted by old saved notes');
check(!p.sourceNeedsReview({...row,review_status:'CANCELLED'})&&!p.sourceNeedsReview({...row,record_type:'PAYROLL'}),'Archived sources and separate Payroll retain existing presentation');
check(m.sourceAccounting({...row,source_document_unavailable:true})==='UNAVAILABLE','Unavailable document lookup stays fail-closed');
check(p.sourceSavedReviewReasons({...row,completion:{operational_review_notes:'Unrecognized specific evidence requirement'}},'en')[0]==='Unrecognized specific evidence requirement','Unstructured saved review reason remains visible without guessing');
check(JSON.stringify(row)===original,'Review display and exports preserve all source facts and working data');
console.log(JSON.stringify({status:'PASS',count:checks.length,hostedWrites:0}));
