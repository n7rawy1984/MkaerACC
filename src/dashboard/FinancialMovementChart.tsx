import type {OverviewMonth} from './dashboardOverviewRead';
import {dashboardAED} from './dashboardSummary';
import {reportingMonthLabel} from '../historical/sourceDatePresentation';
import {movementChartModel,compactAxisAmount} from './financialMovementModel';
export function FinancialMovementChart({rows,locale,onSelect}:{rows:OverviewMonth[];locale:'ar'|'en';onSelect:(month:string)=>void}){
 const ar=locale==='ar',l=(a:string,b:string)=>ar?b:a,m=movementChartModel(rows),labels=[l('Custody funding','تمويل العهدة'),l('Custody payments','مدفوعات العهدة'),l('Posted expenses','المصروفات المرحلة')];
 return <><div className="op-chart-legend">{labels.map((s,i)=><span key={s}><i className={'op-series-'+i}/>{s}</span>)}</div>
 {m.restricted?<div className="op-chart-message">{l('Complete movement totals are restricted for your role.','إجماليات الحركة الكاملة مقيدة حسب صلاحياتك.')}</div>:<div className="op-chart" aria-label={l('Six-month posted movement chart','رسم الحركة المرحلة لستة أشهر')}>
 <div className="op-chart-axis" dir="ltr">{[m.max,(m.max+m.min)/2n,m.min].map((value,i)=><span key={i} title={dashboardAED(String(value))}>{compactAxisAmount(value)}</span>)}</div>
 <div className="op-chart-plot" dir="ltr"><div className="op-chart-zero" style={{top:`${m.zero}%`}}/>{rows.map((row,i)=><button key={row.month} className="op-chart-month" type="button" onClick={()=>onSelect(row.month)} aria-label={reportingMonthLabel(row.month,locale)+' · '+m.values[i].map((v,j)=>labels[j]+': '+(v===null?'—':dashboardAED(v))).join(' · ')} title={m.values[i].map((v,j)=>labels[j]+': '+(v===null?'—':dashboardAED(v))).join('\n')}><span className="op-chart-bars">{m.values[i].map((v,j)=>v!==null&&<i key={j} className={'op-series-'+j} style={{top:`${m.bar(v).top}%`,height:`${m.bar(v).height}%`}}/>)}</span><bdi className="op-chart-month-label">{row.month.slice(5)}/{row.month.slice(2,4)}</bdi></button>)}</div></div>}
 {m.empty&&<p className="op-chart-empty">{l('No posted movement in these months.','لا توجد حركة مرحلة في هذه الأشهر.')}</p>}
 <p className="op-chart-note">{l('Funding includes owner contributions, not revenue. Payments and expenses overlap; do not add them.','يشمل التمويل مساهمات المالك وليس إيرادًا. المدفوعات والمصروفات متداخلة ولا تُجمع.')}</p></>;
}
