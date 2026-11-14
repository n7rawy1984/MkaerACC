import {TableViewport} from '../workspace/data/TableViewport';
import {displayReportCell} from '../reports/reportExport';
import {supplierAccountsReport,type SupplierAPRead} from './supplierAccounts';
/** Display the existing Supplier report model; all recognition and balance math stays authoritative. */
export function SupplierStatementView({data,supplier,name,company,locale}:{data:SupplierAPRead;supplier:string;name:string;company:string;locale:'en'|'ar'}){
 const report=supplierAccountsReport(data,supplier,name,company,locale),ar=locale==='ar';
 return <section className="supplier-statement-view" aria-label={ar?'كشف حساب المورد':'Supplier statement'}><h3>{report.title}</h3><p>{report.period}</p><p>{report.note}</p>{report.sections.map((section,i)=><section key={i}><h4>{section.title}</h4><TableViewport label={section.title}><table className="dw-table"><thead><tr>{section.headers.map((h,j)=><th scope="col" key={j}>{h}</th>)}</tr></thead><tbody>{section.rows.map((row,j)=><tr key={j}>{row.map((cell,k)=><td key={k}><bdi dir={typeof cell==='object'||typeof cell==='number'?'ltr':'auto'}>{displayReportCell(cell)}</bdi></td>)}</tr>)}</tbody></table></TableViewport>{!section.rows.length&&<p>{ar?'لا توجد حركات ضمن هذا القسم.':'No movements in this section.'}</p>}</section>)}</section>;
}
