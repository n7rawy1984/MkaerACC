// Isolated Supabase transport; real Auth, tenant providers, repositories, routing and UI.
// No credentials, hosted data, writable financial transport or business storage.
import { createRoot } from 'react-dom/client';
import { BrowserRouter } from 'react-router-dom';
import { I18nProvider } from '../../src/i18n/I18nContext';
import ProtectedApplication from '../../src/auth/ProtectedApplication';
import '../../src/index.css';
const id=(n:number)=>`98000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const user=id(1),company=id(2),other=id(3),project=id(4),category=id(5),supplier=id(6),contractor=id(7),treasury=id(8),subcontract=id(9);
const base={company_id:company,created_at:'2026-10-02',updated_at:'2026-10-02',created_by:user,updated_by:user,status:'ACTIVE',notes:null};
const companyRow={id:company,code:'DASHBOARD-FIXTURE',name:'Authoritative Company',legal_name:'Legal Company',status:'ACTIVE',trn:null,address:null,notes:null,created_at:'2026-10-02',updated_at:'2026-10-02',created_by:user,updated_by:user};
const expenses=Array.from({length:55},(_,i)=>({...base,id:id(100+i),expense_reference:`EXP-${String(i).padStart(4,'0')}`,expense_date:'2026-10-01',project_id:i===54?null:project,expense_category_id:category,supplier_id:i===0?supplier:null,description:i===0?'فاتورة المورد':'أعمال البناء',net_amount_minor:'101',vat_amount_minor:'0',gross_amount_minor:'101',vat_mode:'ZERO',funding_mode:i===0?'SUPPLIER_CREDIT':'TREASURY',treasury_account_id:treasury,paid_by_party_id:null,payment_method:'CASH',has_tax_invoice:false,invoice_number:null,status:i===1?'REVERSED':i===2?'DRAFT':'POSTED',posted_journal_entry_id:id(600+i),reversal_journal_entry_id:null}));
const certificate={...base,id:id(20),certificate_reference:'CERT-0007',certificate_date:'2026-10-01',project_id:project,subcontractor_id:contractor,subcontract_id:subcontract,payable_amount_minor:'10000',retention_amount_minor:'1000',status:'POSTED'};
const release={...base,id:id(21),release_reference:'REL-0007',release_date:'2026-10-01',project_id:project,subcontractor_id:contractor,subcontract_id:subcontract,total_amount_minor:'300',status:'POSTED'};
const payment={...base,id:id(22),payment_reference:'PAY-0007',payment_date:'2026-10-01',supplier_id:supplier,project_id:project,subcontractor_id:contractor,subcontract_id:subcontract,treasury_account_id:treasury,total_amount_minor:'40',payment_method:'CASH',external_reference:null,status:'POSTED',posted_journal_entry_id:id(601),reversal_journal_entry_id:null};
const tables:Record<string,any[]>={
 companies:[companyRow],
 company_settings:[{company_id:company,tenant_slug:'dashboard-fixture',app_display_name:'Maker',default_locale:'en',logo_url:'/branding/maker-logo.webp',favicon_url:null,primary_color:'#0f172a',accent_color:'#2563eb'}],
 projects:[{...base,id:project,code:'P-0007',name:'مشروع المبنى',client_name:null,location:'دبي',contract_number:null,start_date:null,expected_completion_date:null},{...base,id:id(30),code:'P-0008',name:'مشروع مكتمل',status:'COMPLETED',client_name:null,location:null,contract_number:null,start_date:null,expected_completion_date:null}],
 expense_categories:[{...base,id:category,code:'CAT-0007',name:'مواد البناء',description:null}],
 parties:[{...base,id:supplier,type:'SUPPLIER',name:'المورد الأول',code:'SUP-0007',trn:null,contact_person:null,phone:null,email:null,address:null},{...base,id:contractor,type:'SUBCONTRACTOR',name:'مقاول الباطن الأول',code:'SC-0007',trn:null,contact_person:null,phone:null,email:null,address:null}],
 accounts:[],treasury_accounts:[],subcontracts:[],expenses,
 supplier_payments:[payment],supplier_payment_allocations:[{...base,id:id(23),supplier_payment_id:payment.id,expense_id:expenses[0].id,allocated_amount_minor:'40'}],
 subcontractor_certificates:[certificate],subcontractor_payments:[{...payment,id:id(24),total_amount_minor:'1000'}],subcontractor_payment_allocations:[{...base,id:id(25),subcontractor_payment_id:id(24),subcontractor_certificate_id:certificate.id,allocated_amount_minor:'1000'}],
 subcontractor_retention_releases:[release],subcontractor_retention_release_allocations:[{...base,id:id(26),retention_release_id:release.id,subcontractor_certificate_id:certificate.id,allocated_amount_minor:'300'}],
 subcontractor_retention_payments:[{...payment,id:id(27),total_amount_minor:'100'}],subcontractor_retention_payment_allocations:[{...base,id:id(28),retention_payment_id:id(27),retention_release_id:release.id,allocated_amount_minor:'100'}],
};
const listeners=new Set<(event:string,session:any)=>void>();
const f={user,company,other,role:new URLSearchParams(location.search).get('role')??'ACCOUNTING_ADMIN',session:user,active:true,empty:false,fail:'',delayed:false,pending:[] as (()=>void)[],injectForeign:false,reads:[] as any[],mutations:[] as string[],tables,
 emit:(event='SIGNED_IN')=>listeners.forEach(cb=>cb(event,event==='SIGNED_OUT'?null:{user:{id:f.session}})),
 release:()=>{f.delayed=false;f.pending.splice(0).forEach(done=>done());},
 client:{auth:{onAuthStateChange:(cb:any)=>{listeners.add(cb);queueMicrotask(()=>cb('INITIAL_SESSION',{user:{id:f.session}}));return{data:{subscription:{unsubscribe(){listeners.delete(cb);}}}};},getClaims:async()=>({data:{claims:{sub:f.session}},error:null}),getSession:async()=>({data:{session:{user:{id:f.session}}},error:null}),signOut:async()=>f.emit('SIGNED_OUT')},
 from:(table:string)=>{
  if(/payroll|salary|journal/i.test(table))throw Error('Private/ledger table forbidden in Dashboard fixture');
  const filters:any[]=[],orders:any[]=[];let bounds:number[]|null=null,single=false,projection='';
  const q:any={select:(p:string)=>{projection=p;return q;},eq:(k:string,v:any)=>{filters.push([k,v]);return q;},in:(k:string,v:any[])=>{filters.push([k,v]);return q;},order:(k:string,o:any)=>{orders.push([k,o?.ascending!==false]);return q;},range:(a:number,b:number)=>{bounds=[a,b];return q;},maybeSingle:()=>{single=true;return q;},
   then:(done:any)=>{
    f.reads.push({table,projection,filters:structuredClone(filters),bounds});
    const activeCompany=f.company;
    let rows=table==='profiles'?(f.active?[{user_id:user,display_name:'Fixture actor',email_snapshot:null,locale:null,status:'ACTIVE'}]:[]):table==='company_memberships'?[{id:id(50),user_id:user,company_id:activeCompany,role:f.role,status:'ACTIVE'}]:table==='companies'?[{...companyRow,id:activeCompany,name:activeCompany===company?'Authoritative Company':'Second Company'}]:(f.empty?[]:tables[table]??[]).map(r=>({...r,company_id:activeCompany}));
    for(const [k,v] of filters)rows=rows.filter(r=>Array.isArray(v)?v.includes(r[k]):r[k]===v);
    if(orders.length)rows.sort((a,b)=>{for(const [k,asc] of orders){const c=String(a[k]).localeCompare(String(b[k]));if(c)return asc?c:-c;}return 0;});
    if(bounds)rows=rows.slice(bounds[0],bounds[1]+1);
    if(f.injectForeign&&table==='expenses'&&rows.length)rows[0]={...rows[0],company_id:other};
    const result={data:single?rows[0]??null:rows,error:f.fail===table?{code:'offline',message:'Fixture read failure'}:null};
    const finish=()=>done(result);if(f.delayed&&table==='expenses')f.pending.push(finish);else queueMicrotask(finish);
   },insert:()=>{f.mutations.push(table);throw Error('Mutation forbidden');},update:()=>{f.mutations.push(table);throw Error('Mutation forbidden');},delete:()=>{f.mutations.push(table);throw Error('Mutation forbidden');},upsert:()=>{f.mutations.push(table);throw Error('Mutation forbidden');}};return q;
 },rpc:()=>{f.mutations.push('rpc');throw Error('RPC forbidden');}}
};
Object.assign(window,{dashboardTest:f});
createRoot(document.getElementById('root')!).render(<I18nProvider><BrowserRouter><ProtectedApplication/></BrowserRouter></I18nProvider>);
