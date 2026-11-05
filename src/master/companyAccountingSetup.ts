import type {ProductionAccount} from './masterTypes';
export const controlDefinitions = [
 ['INPUT_VAT','ASSET',false,'Input VAT','ضريبة المدخلات'],
 ['CUSTODY_ADVANCE','ASSET',true,'Custody advances','العهد النقدية'],
 ['SUBCONTRACTOR_ADVANCE','ASSET',true,'Subcontractor advances','دفعات مقدمة للمقاولين'],
 ['SUPPLIER_PAYABLE','LIABILITY',true,'Supplier payable','ذمم الموردين'],
 ['SUBCONTRACTOR_PAYABLE','LIABILITY',true,'Subcontractor payable','ذمم المقاولين'],
 ['SUBCONTRACTOR_RETENTION_PAYABLE','LIABILITY',true,'Subcontractor retention','محتجزات المقاولين'],
 ['SALARY_PAYABLE','LIABILITY',true,'Salary payable','رواتب مستحقة'],
 ['PROJECT_COST','EXPENSE',false,'Project cost','تكلفة المشاريع'],
 ['PROJECT_COST_SUBCONTRACTORS','EXPENSE',false,'Subcontractor project cost','تكلفة مقاولي المشاريع'],
 ['COMPANY_EXPENSE','EXPENSE',false,'Company expense','مصروفات الشركة'],
] as const;
export function controlState(accounts:ProductionAccount[],definition:typeof controlDefinitions[number]) {
 const a=accounts.find(a=>a.systemKey===definition[0]);
 return !a?'MISSING':a.status==='ACTIVE'&&a.accountType===definition[1]&&a.requiresParty===definition[2]?'READY':'INVALID';
}
export type SetupIntent={user:string;company:string;request:string;action:'CONTROL'|'TREASURY';input:Record<string,string>;receipt?:string};
export const setupSlot=(user:string,company:string,mode:string)=>`narvo:accounting-setup:${user}:${company}:${mode}`;
export function readSetupIntent(storage:Storage,user:string,company:string,mode:'CONTROL'|'TREASURY'):SetupIntent|null {
 const raw=storage.getItem(setupSlot(user,company,mode));if(!raw)return null;
 const a=JSON.parse(raw) as SetupIntent;
 if(a.user!==user||a.company!==company||a.action!==mode||!a.input||typeof a.input!=='object'||Array.isArray(a.input)||Object.values(a.input).some(v=>typeof v!=='string')||!uuid(a.request)||a.receipt&&!uuid(a.receipt))throw Error('recovery');return a;
}
export const uuid=(x:unknown):x is string=>typeof x==='string'&&/^[a-f\d]{8}(-[a-f\d]{4}){3}-[a-f\d]{12}$/i.test(x);
