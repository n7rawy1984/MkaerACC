import type {Locale} from './I18nContext';
/** Display names only; role identifiers and permission checks remain unchanged. */
const labels:Record<Locale,Record<string,string>>={
 en:{ACCOUNTING_ADMIN:'Accounting administrator',ACCOUNTANT:'Accountant',PROJECT_MANAGER:'Project manager',DATA_ENTRY:'Data entry',PROCUREMENT:'Procurement',MANAGEMENT_VIEWER:'Management viewer',FOREMAN:'Site supervisor'},
 ar:{ACCOUNTING_ADMIN:'مسؤول المحاسبة',ACCOUNTANT:'محاسب',PROJECT_MANAGER:'مدير مشروع',DATA_ENTRY:'مدخل بيانات',PROCUREMENT:'مسؤول المشتريات',MANAGEMENT_VIEWER:'مستخدم عرض إداري',FOREMAN:'مشرف موقع'},
};
export function roleLabel(role:string,locale:Locale){return labels[locale][role]??(locale==='ar'?'مستخدم':'User');}
