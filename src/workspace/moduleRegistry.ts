import {workspaceNavigation,navigationForRole} from './workspaceNavigation';
import {workspaceText,type WorkspaceTextKey} from './workspaceText';
export type ModuleId=string;
export type ModuleStatus='AVAILABLE'|'UNDER_DEVELOPMENT'|'REQUIRES_VERIFICATION';
export type WorkspaceModule={id:ModuleId;label:WorkspaceTextKey|null;translationKey:string;name:readonly[string,string];route:string|null;status:ModuleStatus;access:'EXISTING_ROUTE_ROLE'|'UNAVAILABLE';subscription:'ROLE_SCOPED_READ'|'NEW_BUSINESS_REQUIRES_FULL'|'SETTLEMENTS_PRESERVED';navigation:boolean};
// The existing navigation/role contract remains the single presentation access source.
// This registry describes capabilities; database/RPC authorization is authoritative.
const settlement=['/custody','/supplier-payments','/subcontractor-payments','/retention-payments'];
export const moduleRegistry:WorkspaceModule[]=[
 ...workspaceNavigation.flatMap(g=>g.items).map(i=>({id:i.path,label:i.label,translationKey:'workspace.'+i.label,name:[workspaceText.en[i.label],workspaceText.ar[i.label]] as const,route:i.path,status:'AVAILABLE' as const,access:'EXISTING_ROUTE_ROLE' as const,subscription:settlement.includes(i.path)?'SETTLEMENTS_PRESERVED' as const:['/expenses','/subcontracts','/projects','/payroll'].includes(i.path)?'NEW_BUSINESS_REQUIRES_FULL' as const:'ROLE_SCOPED_READ' as const,navigation:true})),
 ...([
 ['assets','Fixed assets','الأصول الثابتة','UNDER_DEVELOPMENT'],['employees',"Employee records",'بيانات الموظفين','UNDER_DEVELOPMENT'],
 ['rules',"Posting rules","قواعد الترحيل",'REQUIRES_VERIFICATION'],['ledger',"General ledger","الأستاذ العام",'UNDER_DEVELOPMENT'],
 ['trialBalance','Trial Balance','ميزان المراجعة','UNDER_DEVELOPMENT'],['income','Income Statement','قائمة الدخل','UNDER_DEVELOPMENT'],['balance','Balance Sheet',"قائمة المركز المالي",'UNDER_DEVELOPMENT'],
 ['execution','Execution tracking','متابعة التنفيذ','UNDER_DEVELOPMENT'],['cost',"Project cost analysis","تحليل تكاليف المشروعات",'UNDER_DEVELOPMENT'],['projectReports','Project reports','تقارير المشروعات','UNDER_DEVELOPMENT'],
 ['reconciliation','Reconciliation','التسويات والمطابقة','REQUIRES_VERIFICATION'],['closing','Period closing','إقفال الفترة','REQUIRES_VERIFICATION'],['finalReports',"Period-end reports","تقارير نهاية الفترة",'UNDER_DEVELOPMENT'],['nextPeriod','Next period','الفترة التالية','REQUIRES_VERIFICATION']
 ] as const).map(([id,en,ar,status])=>({id,label:null,translationKey:'modules.'+id,name:[en,ar] as const,route:null,status,access:'UNAVAILABLE' as const,subscription:'ROLE_SCOPED_READ' as const,navigation:false}))
];
export function moduleForRole(id:ModuleId,role:string){const m=moduleRegistry.find(m=>m.id===id);if(!m)throw Error('Unknown workspace module');return {...m,canNavigate:!!m.route&&navigationForRole(role).some(g=>g.items.some(i=>i.path===m.route))};}

// Planned labels are keyed here; existing keys use workspaceText EN/AR.
export const moduleTranslations=Object.fromEntries(moduleRegistry.filter(m=>!m.label).map(m=>[m.translationKey,{en:m.name[0],ar:m.name[1]}]));
