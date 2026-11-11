// Calendar dates are validated and formatted lexically. Never parse ambiguous text,
// infer a transaction date from a worksheet/month, or shift dates across timezones.
export const UNCONFIRMED_DATE='UNCONFIRMED_DATE';
export function validFinancialDate(value:unknown):value is string{
 if(typeof value!=='string'||!/^\d{4}-\d{2}-\d{2}$/.test(value))return false;
 const[y,m,d]=value.split('-').map(Number),days=[31,y%4===0&&(y%100!==0||y%400===0)?29:28,31,30,31,30,31,31,30,31,30,31];
 return y>=1&&m>=1&&m<=12&&d>=1&&d<=days[m-1];
}
export const unconfirmedDateLabel=(locale:'en'|'ar')=>locale==='ar'?'بدون تاريخ مؤكد':'Without a confirmed date';
export function formatFinancialDate(value:string|null|undefined,locale:'en'|'ar'='en'){
 return validFinancialDate(value)?value.slice(8,10)+'/'+value.slice(5,7)+'/'+value.slice(0,4):unconfirmedDateLabel(locale);
}
export const reportingMonthLabel=(month:string,locale:'en'|'ar')=>/^\d{4}-(0[1-9]|1[0-2])$/.test(month)?month.slice(5,7)+'/'+month.slice(0,4):unconfirmedDateLabel(locale);
export function sourceDatePresentation(value:string|null|undefined,locale:'en'|'ar'){
 const known=validFinancialDate(value);return{status:known?'KNOWN'as const:!value?'UNKNOWN'as const:'UNRESOLVED'as const,iso:known?value:null,label:formatFinancialDate(value,locale)};
}
