// Presentation-only fixture: transport is replaced by the verification server.
import {useState} from 'react';
import {createRoot} from 'react-dom/client';
import {BrowserRouter} from 'react-router-dom';
import {I18nProvider,useI18n} from '../../src/i18n/I18nContext';
import {TenantSettingsPresentationProvider} from '../../src/tenant/TenantSettingsContext';
import {ProductionMasterDataContext} from '../../src/master/productionMasterDataContext';
import TenantReadyApplication from '../../src/app/TenantReadyApplication';
import AttendanceApplication from '../../src/attendance/AttendanceApplication';
import PayrollApplication from '../../src/payroll/PayrollApplication';
import PayrollRegisterOutput from '../../src/payroll/PayrollRegisterOutput';
import {LoginPage} from '../../src/auth/LoginPage';
import {CompanySelectPage} from '../../src/auth/CompanySelectPage';
import {NoCompanyPage} from '../../src/auth/NoCompanyPage';
import {AuthErrorPage} from '../../src/auth/AuthErrorPage';
import {Modal} from '../../src/components/ui/Modal';
import {Sidebar} from '../../src/components/layout/Sidebar';
import '../../src/index.css';
const id=(n:number)=>`99000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const company=id(1),user=id(2),employee=id(3),project=id(4);
const base={companyId:company,createdAt:'2026-09-01',updatedAt:'2026-09-01',createdBy:null,updatedBy:null,status:'ACTIVE',notes:null};
const projects=[{...base,id:project,code:'P-0007',name:'مشروع المبنى',clientName:null,location:'دبي',contractNumber:'C-2026/01',startDate:null,expectedCompletionDate:null}];
const parties=[{...base,id:employee,type:'EMPLOYEE',name:'أحمد محمد',code:'EMP-0007',taxRegistrationNumber:null,contactPerson:null,phone:null,email:'demo@example.test',address:null},{...base,id:id(5),type:'SUPPLIER',name:'المورد التجريبي',code:'SUP-0007',taxRegistrationNumber:null,contactPerson:null,phone:null,email:'supplier@example.test',address:null},{...base,id:id(6),type:'SUBCONTRACTOR',name:'مقاول الباطن',code:'SC-0007',taxRegistrationNumber:null,contactPerson:null,phone:null,email:null,address:null}];
const companyProfile={...base,id:company,code:'V1-DEMO-20260929',name:'Original Company',legalName:'Original Legal Company',trn:null,address:null};
const account={...base,id:id(7),code:'1000-001',name:'النقدية',accountType:'ASSET',parentAccountId:null,requiresParty:false,systemKey:null};
const treasury={...base,id:id(8),code:'TR-0007',name:'خزينة الشركة',type:'CASH',projectId:null,glAccountId:account.id,bankName:null,accountReference:'AE-0007',notes:null};
const contract={...base,id:id(9),projectId:project,subcontractorId:id(6),contractNumber:'SUB-2026/0007',scopeOfWork:'أعمال المبنى',originalContractValueMinor:'100000',approvedVariationsMinor:'0',retentionBps:500,startDate:null,expectedEndDate:null};
const master=new Proxy({phase:'READY',company:companyProfile,projects,parties,expenseCategories:[{...base,id:id(10),code:'CAT-0007',name:'مواد البناء',description:null}],accounts:[account],treasuryAccounts:[treasury],subcontracts:[contract]},{get(o,k){return k in o?o[k as keyof typeof o]:String(k).endsWith('Mutation')?{phase:'IDLE'}:()=>{};}});
const membership={membershipId:id(11),companyId:company,companyCode:companyProfile.code,companyName:companyProfile.name,companyLegalName:companyProfile.legalName,role:'ACCOUNTING_ADMIN'};
const auth={state:{phase:'TENANT_READY',profile:{userId:user},activeTenant:membership,memberships:[membership]},signOut:async()=>{},showCompanySelector:()=>{},chooseCompany:()=>{},retry:()=>{},signIn:async()=>({ok:false,kind:'invalid'})};
const row={id:id(12),company_id:company,employee_id:employee,included:true,employee_name:'أحمد محمد',payroll_id:'0007',payroll_type:'شهري',profession:'مهندس',work_station:'دبي',default_project_id:project,payment_type:'نقدي',monthly_salary_minor:'123456',calendar_days:31,absence_half_units:0,absence_deduction_minor:'0',additions_minor:'0',deductions_minor:'0',gross_salary_minor:'123456',net_salary_minor:'123456'};
const draft={attendance_review_valid:true,stale:false,review_valid:true,period:{id:id(13),company_id:company,month:'2026-08-01',state:'DRAFT',version:1,calendar_days:31},rows:[row],adjustments:[]};
const profile={...row,id:id(14),employee_status:'ACTIVE',status:'ACTIVE',version:1};
const posted={id:id(15),company_id:company,month:'2026-08-01',period_id:id(13),draft_version:1,snapshot:draft,reversed:false,created_at:'2026-08-31',replaces_id:null};
const entitlement={id:id(16),company_id:company,payroll_id:id(15),employee_name:'أحمد محمد',project_id:project,amount_minor:'123456',unpaid_minor:'123400'};
const payment={id:id(17),company_id:company,entitlement_id:id(16),amount_minor:'56',payment_date:'2026-08-31',reference:'SAL-0007',reversed:false};
const calls:string[]=[];
const client={auth:{getSession:async()=>({data:{session:{user:{id:user}}},error:null}),onAuthStateChange:()=>({data:{subscription:{unsubscribe(){}}}})},rpc:async(name:string)=>{
 calls.push(name);if(!name.startsWith('read_')&&!['attendance_context','attendance_day','attendance_month'].includes(name))throw Error('Mutation forbidden in presentation fixture');
 const data=name==='attendance_context'?{today:'2026-10-01',projects:[{id:project,name:'مشروع المبنى'}],employees:[{id:employee,name:'أحمد محمد'}]}:name==='attendance_day'?{locked:false,rows:[{employee_id:employee,employee_name:'أحمد محمد',entry:null}]}:name==='attendance_month'?{period:{revision:1,reviewed_revision:1,locked_at:null},assignments:[],exceptions:[]}:name==='read_payroll_profiles'?{profiles:[profile],employees:[{id:employee,name:'أحمد محمد'}],projects:[{id:project,name:'مشروع المبنى'}]}:name==='read_payroll_draft'?draft:name==='read_payroll_postings'?{accounting:null,postings:[posted],entitlements:[entitlement],payments:[payment],treasuries:[{id:treasury.id,name:treasury.name,project_id:null}]}:null;
 return {data,error:null};
}};
const financialRow={id:id(20),company_id:company,project_id:project,supplier_id:id(5),subcontractor_id:id(6),subcontract_id:id(9),treasury_account_id:treasury.id,status:'POSTED',expense_reference:'EXP-0007',payment_reference:'PAY-0007',advance_reference:'ADV-0007',certificate_reference:'CERT-0007',contractor_certificate_number:'0007',release_reference:'REL-0007',expense_date:'2026-08-31',payment_date:'2026-08-31',advance_date:'2026-08-31',certificate_date:'2026-08-31',release_date:'2026-08-31',description:'مواد البناء',notes:null,external_reference:null,authorization_reference:null,created_at:'2026-08-31T08:00:00Z',created_by:user,posted_at:null,reversed_at:null,reversal_journal_entry_id:null,posted_journal_entry_id:id(21),funding_mode:'TREASURY',vat_mode:'ZERO',payment_method:'CASH',retention_bps:500,advance_recovery_minor:'123456',amount_minor:'123456',current_work_amount_minor:'123456',deductions_total_minor:'123456',gross_amount_minor:'123456',gross_certified_minor:'123456',net_amount_minor:'123456',net_before_vat_minor:'123456',outstanding_amount_minor:'123456',payable_amount_minor:'123456',previous_certified_work_minor:'123456',released_amount_minor:'123456',remaining_amount_minor:'123456',retention_amount_minor:'123456',total_amount_minor:'123456',vat_amount_minor:'123456',work_value_to_date_minor:'123456'};
const empty={phase:'READY',rows:[financialRow],hasNext:false,payments:[financialRow],outstanding:[financialRow],allocations:[],advances:[financialRow],certificates:[financialRow],deductions:[],mappings:[],releases:[financialRow],available:[financialRow]};
const fixture={auth,master,client,empty,calls};Object.assign(window,{demoPresentation:fixture});
const branding={phase:'READY' as const,settings:{companyId:company,tenantSlug:'demo',appDisplayName:'Maker',effectiveDisplayName:'Maker',defaultLocale:'en' as const,logoUrl:'/branding/maker-logo.webp',faviconUrl:null,primaryColor:'#0f172a',accentColor:'#2563eb'}};
export default function Fixture(){const {setLocale}=useI18n();const [view,setView]=useState('projects');const [modal,setModal]=useState(false);
 const shellViews=['projects','companyProfile','parties','expenseCategories','accounts','treasuryAccounts','subcontracts','expenses','supplierPayments','subcontractorAdvances','subcontractorCertificates','subcontractorPayments','retentionReleases','retentionPayments'];
 // oxlint-disable-next-line react/immutability -- Mutable Auth double is confined to this isolated presentation fixture.
 auth.state.phase=view==='select'?'SELECTING_COMPANY':'TENANT_READY';
 return <TenantSettingsPresentationProvider state={branding}><ProductionMasterDataContext.Provider value={master as any}><nav data-testid="fixture-controls" className="flex flex-wrap gap-2 p-2"><button onClick={()=>setLocale('en')}>EN</button><button onClick={()=>setLocale('ar')}>AR</button>{[...shellViews,'attendance','payroll','print','login','select','noCompany','retry','sidebar'].map(v=><button key={v} onClick={()=>setView(v)}>{v}</button>)}<button onClick={()=>setModal(true)}>modal</button></nav>
 {shellViews.includes(view)?<TenantReadyApplication view={view as any}/>:view==='attendance'?<AttendanceApplication/>:view==='payroll'?<PayrollApplication/>:view==='print'?<PayrollRegisterOutput userId={user} companyId={company} companyName={companyProfile.name} role="ACCOUNTANT" month="2026-08-01" source={{kind:'DRAFT',id:id(13),version:1}}/>:view==='login'?<LoginPage/>:view==='select'?<CompanySelectPage/>:view==='noCompany'?<NoCompanyPage/>:view==='retry'?<AuthErrorPage/>:<Sidebar/>}
 {modal&&<Modal title="تأكيد الإجراء" onClose={()=>setModal(false)}><p>مرجع المستند: <bdi dir="ltr">INV-2026/0007</bdi></p></Modal>}
 </ProductionMasterDataContext.Provider></TenantSettingsPresentationProvider>;
}
createRoot(document.getElementById('root')!).render(<I18nProvider><BrowserRouter><Fixture/></BrowserRouter></I18nProvider>);
