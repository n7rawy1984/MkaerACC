import {useEffect,useMemo,useState} from 'react';
import {Link} from 'react-router-dom';
import {getSupabaseClient} from '../lib/supabase';
import {dashboardAED} from './dashboardSummary';
import {readMonthlyFinancials,type MonthlyFinancialData} from './monthlyFinancialRead';
import {discoverFinancialMonths,financialMetricKeys,monthlyJournalEntries,monthlyRange,sourceMonthlySummary,summarizeFinancialMonths,unconfirmedSources,type MonthlyScope} from './monthlyFinancialModel';
import {financialMetricText,monthlyFinancialText} from './monthlyFinancialText';
import {monthlyFinancialReport} from './monthlyFinancialReport';
import {formatFinancialDate,reportingMonthLabel} from '../historical/sourceDatePresentation';
import type {ReportingBasis,SourceRecord} from '../historical/sourceModel';
import {ReportExport} from '../reports/ReportExport';
import {statementDocumentPath,statementType} from '../reports/partyStatement';
type ReadState={phase:'LOADING'|'ERROR'}|{phase:'READY';data:MonthlyFinancialData};
export function MonthlyFinancialActivity({user,company,companyName,role,locale,revision,sources,sourceLoading,sourceError}:{user:string;company:string;companyName:string;role:string;locale:'en'|'ar';revision:number;sources:SourceRecord[];sourceLoading:boolean;sourceError:boolean}){
 const t=monthlyFinancialText[locale],ar=locale==='ar',allowed=['ACCOUNTING_ADMIN','ACCOUNTANT','MANAGEMENT_VIEWER'].includes(role);
 const [read,setRead]=useState<{scope:string;value:ReadState}|null>(null),[from,setFrom]=useState(''),[through,setThrough]=useState(''),[project,setProject]=useState('ALL'),[holder,setHolder]=useState('ALL'),[basis,setBasis]=useState<ReportingBasis>('DATE'),[page,setPage]=useState(0);
 const identity=JSON.stringify([user,company,role,revision]);
 useEffect(()=>{if(!allowed)return;let live=true;const client=getSupabaseClient(),commit=(value:ReadState)=>{if(live)setRead({scope:identity,value});};
 const{data}=client.auth.onAuthStateChange((event,session)=>{if(event==='SIGNED_OUT'||!session||session.user.id!==user){commit({phase:'ERROR'});live=false;}});
 void readMonthlyFinancials(client,user,company,()=>live).then(data=>commit({phase:'READY',data})).catch(()=>commit({phase:'ERROR'}));return()=>{live=false;data.subscription.unsubscribe();};
 },[allowed,identity,user,company]);
 const state=read?.scope===identity?read.value:null,data=state?.phase==='READY'?state.data:undefined;
 const discovered=useMemo(()=>discoverFinancialMonths(data,sources,basis),[data,sources,basis]);
 const start=from||discovered[0]||'',end=through||discovered.at(-1)||'',scope:MonthlyScope={from:start,through:end,project,holder};
 const result=useMemo(()=>{if(!data)return null;try{return summarizeFinancialMonths(data,{from:start,through:end,project,holder});}catch{return null;}},[data,start,end,project,holder]);
 const rangeValid=useMemo(()=>{try{monthlyRange(start,end);return true;}catch{return false;}},[start,end]);
 const pages=Math.max(1,Math.ceil((result?.length??0)/6)),currentPage=Math.min(page,pages-1),shown=result?.slice(currentPage*6,currentPage*6+6)??[];
 const holders=data?.parties.filter(p=>data.lines.some(l=>l.party_id===p.id&&data.accounts.find(a=>a.id===l.account_id)?.system_key==='CUSTODY_ADVANCE'))??[];
 const unknown=unconfirmedSources(sources).filter(r=>project==='ALL'||(project==='COMPANY'?!r.assigned_project_id:r.assigned_project_id===project));
 const restricted=(key:string)=>key.startsWith('custody')&&!data?.custodyComplete||['employeeAdvances','payrollCost','payrollPayments'].includes(key)&&!data?.payrollVisible;
 const amount=(key:string,minor:string)=>restricted(key)?<span className="monthly-restricted">{t.restricted}</span>:<bdi dir="ltr">{dashboardAED(minor)}</bdi>;
 if(!allowed)return <p>{t.restricted}</p>;
 return <section className="monthly-financial" aria-label={t.title} dir={ar?'rtl':'ltr'}>
 <div className="cycle-month-controls"><label>{t.from}<input type="month" aria-label={t.from} value={start} onChange={e=>{setFrom(e.target.value);setPage(0);}}/></label><label>{t.through}<input type="month" aria-label={t.through} value={end} onChange={e=>{setThrough(e.target.value);setPage(0);}}/></label><button type="button" onClick={()=>{setFrom('');setThrough('');setPage(0);}}>{t.all}</button>
 <label>{t.project}<select aria-label={t.project} value={project} onChange={e=>{setProject(e.target.value);setPage(0);}}><option value="ALL">{t.all}</option><option value="COMPANY">{t.company}</option>{data?.projects.map(p=><option key={p.id} value={p.id}>{p.code} · {p.name}</option>)}</select></label>
 <label>{t.holder}<select aria-label={t.holder} value={holder} onChange={e=>setHolder(e.target.value)}><option value="ALL">{t.allHolders}</option>{holders.map(p=><option key={p.id} value={p.id}>{p.name}</option>)}</select></label></div>
 <p className="cycle-evidence-note">{t.note}</p><p className="cycle-evidence-note">{t.custodyNote}</p><p className="cycle-evidence-note">{t.projectNote}</p>
 {(!state||state.phase==='LOADING'||sourceLoading)&&<p role="status">{t.load}</p>}
 {(state?.phase==='ERROR'||sourceError)&&<p role="alert">{t.error}</p>}
 {data&&result&&!sourceLoading&&!sourceError&&<ReportExport build={()=>monthlyFinancialReport(data,result,sources,scope,basis,companyName,locale)}/>}
 {data&&!result&&<p role="alert">{rangeValid?t.error:t.emptyRange}</p>}
 {data&&result&&<><div className="cycle-section-heading"><h3>{t.posted}</h3><Link to="/accounting-reports">{t.ledgerLink}</Link></div><div className="cycle-month-grid monthly-posted-grid">{shown.map(r=><article className="cycle-month" key={r.month} data-month={r.month} data-domain="posted"><h4>{reportingMonthLabel(r.month,locale)}</h4>{r.journals===0&&<p>{t.empty}</p>}<dl>
 {financialMetricKeys.map(k=><div key={k}><dt>{financialMetricText[k][ar?1:0]}</dt><dd>{amount(k,r.values[k])}</dd></div>)}
 {(['custodyOpening','custodyClosing','treasuryOpening','treasuryClosing'] as const).map(k=><div key={k}><dt>{t[k]}</dt><dd>{amount(k,r[k])}</dd></div>)}
 <div><dt>{t.journals}</dt><dd>{r.journals}</dd></div><div><dt>{t.stockMovements}</dt><dd>{r.stockMovements}</dd></div><div><dt>{t.payrollPeriods}</dt><dd>{data.payrollVisible?r.payrollPeriods:t.restricted}</dd></div></dl></article>)}</div>
 <h3>{t.holderBalances}</h3><dl className="monthly-holder-balances">{holders.filter(p=>holder==='ALL'||p.id===holder).map(p=>{const balance=summarizeFinancialMonths(data,{...scope,holder:p.id}).at(-1)?.custodyClosing??'0';return <div key={p.id}><dt><Link to="/custody">{p.name}</Link></dt><dd>{amount('custody',balance)}</dd></div>;})}</dl>
 <h3>{t.imported}</h3><label className="monthly-basis">{t.basis}<select aria-label={t.basis} value={basis} onChange={e=>{setBasis(e.target.value as ReportingBasis);setPage(0);}}><option value="DATE">{t.date}</option><option value="SOURCE">{t.provenance}</option></select></label><Link to="/historical-imports">{t.sourceLink}</Link>
 {!sourceLoading&&!sourceError&&<div className="cycle-month-grid monthly-source-grid">{shown.map(r=>{const s=sourceMonthlySummary(sources,company,r.month,basis,project);return <article className="cycle-month" key={r.month} data-month={r.month} data-domain="imported"><h4>{reportingMonthLabel(r.month,locale)}</h4>{!s.count&&<p>{t.sourceEmpty}</p>}{s.unknownAmounts>0&&<p role="status">{t.missingAmount}</p>}<dl>{(['inflow','outflow','payroll']as const).map((k,i)=><div key={k}><dt>{[t.sourceIn,t.sourceOut,t.sourcePayroll][i]}</dt><dd>{k==='payroll'&&!data.payrollVisible?t.restricted:!({inflow:s.inflowCount,outflow:s.outflowCount,payroll:s.payrollCount}[k])||s.unknownAmounts?'—':<bdi dir="ltr">{dashboardAED(s[k])}</bdi>}</dd></div>)}<div><dt>{t.unclassified}</dt><dd>{s.unclassified}</dd></div><div><dt>{t.unposted}</dt><dd>{s.unposted}</dd></div><div><dt>{t.linked}</dt><dd>{s.posted}</dd></div></dl></article>;})}</div>}
 <nav className="monthly-pagination" aria-label={t.page}><button type="button" disabled={currentPage===0} onClick={()=>setPage(currentPage-1)}>{t.previous}</button><span>{currentPage+1} / {pages}</span><button type="button" disabled={currentPage+1>=pages} onClick={()=>setPage(currentPage+1)}>{t.next}</button></nav>
 <details><summary>{t.details}</summary><div className="monthly-journal-table"><table><thead><tr><th>{t.dateLabel}</th><th>{t.journal}</th><th>{t.type}</th><th>{t.document}</th></tr></thead><tbody>{monthlyJournalEntries(data,scope).map(e=><tr key={e.id}><td><bdi dir="ltr">{formatFinancialDate(e.posting_date,locale)}</bdi></td><td><Link to="/accounting-reports"><bdi dir="ltr">{e.journal_reference}</bdi></Link></td><td>{statementType(e.source_type,ar)}</td><td><Link to={statementDocumentPath(e.source_type)}><bdi dir="ltr">{e.source_id}</bdi></Link>{sources.filter(s=>s.source_document?.receipt?.journal===e.id||s.expense?.posted_journal_entry_id===e.id).map(s=><p key={s.id}><Link to="/historical-imports">{s.source_reference}</Link></p>)}</td></tr>)}</tbody></table></div></details></>}
 <details><summary>{t.unknown}: {unknown.length}</summary><ul>{unknown.map(r=><li key={r.id}><Link to="/historical-imports">{r.source_reference}</Link> · {r.description}</li>)}</ul></details><p className="cycle-evidence-note">{t.periodNote}</p>
 </section>;
}
