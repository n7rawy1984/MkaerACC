import type {WorkspaceTextKey} from './workspaceText';
const accounting=['ACCOUNTING_ADMIN','ACCOUNTANT','MANAGEMENT_VIEWER'];
const operational=[...accounting,'PROJECT_MANAGER','DATA_ENTRY','PROCUREMENT'];
export const workspaceNavigation:readonly {label:WorkspaceTextKey;items:readonly {label:WorkspaceTextKey;path:string;roles?:readonly string[]}[]}[]=[
 {label:'dashboard',items:[{label:'overview',path:'/'}]},
 {label:'masters',items:[{label:'parties',path:'/parties',roles:operational},{label:'categories',path:'/expense-categories',roles:operational}]},
 {label:'projects',items:[{label:'projects',path:'/projects',roles:operational}]},
 {label:'financial',items:[{label:'expenses',path:'/expenses',roles:operational},{label:'supplierPayments',path:'/supplier-payments',roles:accounting},{label:'treasury',path:'/treasury-accounts',roles:[...accounting,'PROJECT_MANAGER']}]},
 {label:'contracts',items:[{label:'subcontracts',path:'/subcontracts',roles:[...accounting,'PROJECT_MANAGER','PROCUREMENT']},{label:'advances',path:'/subcontractor-advances',roles:accounting},{label:'certificates',path:'/subcontractor-certificates',roles:accounting},{label:'subcontractorPayments',path:'/subcontractor-payments',roles:accounting},{label:'retentionReleases',path:'/retention-releases',roles:accounting},{label:'retentionPayments',path:'/retention-payments',roles:accounting}]},
 {label:'people',items:[{label:'attendance',path:'/attendance',roles:['ACCOUNTING_ADMIN','ACCOUNTANT']},{label:'payroll',path:'/payroll',roles:accounting}]},
 {label:'accounting',items:[{label:'cycle',path:'/accounting-cycle'},{label:'accounts',path:'/accounts',roles:accounting},{label:'reports',path:'/accounting-reports',roles:accounting}]},
 {label:'settings',items:[{label:'companyProfile',path:'/company-profile'}]},
];
// Presentation only. Existing Company membership, RLS and RPCs remain authority.
export function navigationForRole(role:string){return workspaceNavigation.map(g=>({...g,items:g.items.filter(i=>!i.roles||i.roles.includes(role))})).filter(g=>g.items.length);}
export const isAccountingReader=(role:string)=>accounting.includes(role);
