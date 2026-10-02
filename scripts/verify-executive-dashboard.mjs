import assert from 'node:assert/strict';
import {createServer} from 'vite';
import react from '@vitejs/plugin-react';
import {chromium} from 'playwright';
import {resolve} from 'node:path';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {assertProductionBoundary,dependencyGraph} from './production-boundary.mjs';
const root=resolve(import.meta.dirname,'..'),evidence='/tmp/maker-executive-dashboard';await mkdir(evidence,{recursive:true});
const graph=assertProductionBoundary(root);assert([...graph].some(p=>p.endsWith('/dashboard/ExecutiveDashboard.tsx')));
for(const path of dependencyGraph(resolve(root,'src/dashboard/ExecutiveDashboard.tsx'))){
 if(!path.includes('/dashboard/'))continue;
 const text=await readFile(path,'utf8');assert(!/localStorage|sessionStorage|\.rpc\(|\.insert\(|\.update\(|\.upsert\(|\.delete\(|from\(["'](?:payroll|salary|journal)/.test(text),path);
}
const server=await createServer({root,configFile:false,plugins:[{name:'dashboard-transport',load(id){if(id===resolve(root,'src/lib/supabase.ts'))return 'export const getSupabaseClient=()=>window.dashboardTest.client;';},configureServer(s){s.middlewares.use(async(req,res,next)=>{
 const path=new URL(req.url,'http://localhost').pathname;if(!['/','/projects','/login','/no-company'].includes(path)){next();return;}
 res.setHeader('Content-Type','text/html');res.end(await s.transformIndexHtml(req.url,'<html><body><div id="root"></div><script type="module" src="/scripts/fixtures/executive-dashboard.tsx"></script></body></html>'));
});}},react()],server:{host:'127.0.0.1',port:0,hmr:false},logLevel:'error'});
let browser;const results=[];
try{
 await server.listen();browser=await chromium.launch({headless:true});const page=await browser.newPage();const errors=[];
 page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());
 await page.addInitScript(()=>{
  const original=Storage.prototype.getItem;Storage.prototype.getItem=function(k){if(k.startsWith('cas:v1:')&&k!=='cas:v1:locale')throw Error('Business storage read forbidden');return original.call(this,k);};
 });
 const base=`http://127.0.0.1:${server.httpServer.address().port}`;
 const refresh=()=>page.getByRole('button',{name:/Refresh summary|تحديث الملخص/});
 const summaryReady=async()=>{await page.getByText(/53\.53 AED/,{exact:true}).first().waitFor();assert.equal(await page.locator('.recharts-surface').count(),4);};
 const kpi=label=>page.getByText(label,{exact:true}).first().locator('..').locator('..');
 for(const role of ['ACCOUNTING_ADMIN','MANAGEMENT_VIEWER']){
  if(new URL(page.url()).protocol==='http:')await page.evaluate(()=>localStorage.setItem('cas:v1:locale','en'));
  await page.goto(`${base}/?role=${role}`);await summaryReady();assert.equal(new URL(page.url()).pathname,'/');
  assert.equal(await page.locator('main nav a').first().textContent(),'Dashboard');assert.equal(await page.locator('main nav a').first().getAttribute('href'),'/');
  for(const [label,value] of [['Active Projects','1'],['Posted expense net','53.53 AED'],['Supplier Outstanding','0.61 AED'],['Subcontractor Outstanding Payable','92.00 AED'],['Retention Held','7.00 AED']])assert((await kpi(label).textContent()).includes(value),`${label}: ${value}`);
  assert.equal(await page.locator('main nav a[href="/payroll"]').count(),role==='MANAGEMENT_VIEWER'?0:1);
  if(role==='MANAGEMENT_VIEWER')assert.equal(await page.getByRole('button',{name:/create|edit|post|pay|reverse/i}).count(),0);
  for(const locale of ['en','ar']){
   if(locale==='ar')await page.getByRole('button',{name:'العربية',exact:true}).click();
   assert.equal(await page.locator('html').getAttribute('lang'),locale);assert.equal(await page.locator('html').getAttribute('dir'),locale==='ar'?'rtl':'ltr');
   if(locale==='ar')assert.equal(await page.locator('main nav a').first().textContent(),'الرئيسية');
   for(const width of [1440,390]){
    await page.setViewportSize({width,height:900});await page.waitForTimeout(120);
    assert.equal(await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1),false);
    assert.equal(await page.locator('.recharts-bar-rectangle path').count()>0,true);
    const chartText=page.locator('svg text[direction]');assert.equal(await chartText.first().getAttribute('direction'),locale==='ar'?'rtl':'ltr');
    const tick=await chartText.first().boundingBox(),bar=await page.locator('.recharts-bar-rectangle path').first().boundingBox();
    assert(locale==='ar'?tick.x>=bar.x+bar.width-1:tick.x+tick.width<=bar.x+1,'Chart labels must not overlap bars');
    const cells=page.locator('table tbody tr').first().locator('td');const first=await cells.first().boundingBox(),last=await cells.last().boundingBox();assert(locale==='ar'?first.x>last.x:first.x<last.x);
    assert.equal(await page.locator('table tbody bdi[dir=ltr]').count()>0,true);
    assert(await page.locator('img[alt=Maker]').evaluate(e=>e.complete&&e.naturalWidth===768));
    await page.screenshot({path:`${evidence}/${role}-${locale}-${width}.png`,fullPage:true});results.push(`${role}/${locale}/${width}: PASS`);
   }
  }
  const reads=await page.evaluate(()=>window.dashboardTest.reads);
  const financial=reads.filter(r=>['expenses','supplier_payments','supplier_payment_allocations','subcontractor_certificates','subcontractor_payments','subcontractor_payment_allocations','subcontractor_retention_releases','subcontractor_retention_release_allocations','subcontractor_retention_payments','subcontractor_retention_payment_allocations'].includes(r.table));
  assert(financial.length>0);assert(financial.every(r=>r.filters.some(([k,v])=>k==='company_id'&&v===windowCompany(reads))));
  assert(financial.some(r=>r.table==='expenses'&&r.bounds?.[0]===50));assert.equal(await page.evaluate(()=>window.dashboardTest.mutations.length),0);
  await page.reload();await summaryReady();assert.equal(await page.locator('html').getAttribute('dir'),'rtl');assert.equal(await page.title(),'Maker');
  await page.getByRole('link',{name:'المشاريع',exact:true}).click();assert.equal(new URL(page.url()).pathname,'/projects');await page.getByRole('link',{name:'الرئيسية',exact:true}).click();await summaryReady();
  // Failed reads never fall back to the previously displayed totals.
  await page.evaluate(()=>window.dashboardTest.fail='supplier_payments');await refresh().click();await page.getByRole('alert').waitFor();assert.equal(await page.locator('.recharts-surface').count(),0);assert.equal(await page.getByText('53.53 AED',{exact:true}).count(),0);
  await page.evaluate(()=>window.dashboardTest.fail='');await refresh().click();await summaryReady();
 }
 // Empty authority is distinct from failed loading. Masters intentionally retained.
 await page.evaluate(()=>{const f=window.dashboardTest;for(const t of ['expenses','supplier_payments','supplier_payment_allocations','subcontractor_certificates','subcontractor_payments','subcontractor_payment_allocations','subcontractor_retention_releases','subcontractor_retention_release_allocations','subcontractor_retention_payments','subcontractor_retention_payment_allocations'])f.tables[t]=[];});await refresh().click();await page.getByText('0.00 AED',{exact:true}).first().waitFor();assert.equal(await page.locator('.recharts-surface').count(),0);
 await page.reload();await summaryReady();
 // Cross-Company rows are rejected by the existing repository and fail closed.
 await page.evaluate(()=>window.dashboardTest.injectForeign=true);await refresh().click();await page.getByRole('alert').waitFor();assert.equal(await page.getByText('53.53 AED',{exact:true}).count(),0);await page.evaluate(()=>window.dashboardTest.injectForeign=false);await refresh().click();await summaryReady();
 // Late old-Company reads cannot repaint the next Company's dashboard.
 await page.evaluate(()=>window.dashboardTest.delayed=true);await refresh().click();await page.getByRole('status').waitFor();assert.equal(await page.getByText('53.53 AED',{exact:true}).count(),0);
 await page.evaluate(()=>{const f=window.dashboardTest;f.company=f.other;window.dispatchEvent(new Event('focus'));});await page.getByText('Second Company · Legal Company',{exact:true}).waitFor();await page.evaluate(()=>window.dashboardTest.release());await summaryReady();assert.equal(await page.getByText('Authoritative Company · Legal Company',{exact:true}).count(),0);
 // Revoked membership/profile tears down the dashboard through existing Auth.
 await page.evaluate(()=>{window.dashboardTest.active=false;window.dispatchEvent(new Event('focus'));});await page.waitForURL('**/no-company');assert.equal(await page.locator('#executive-dashboard-title').count(),0);
 await page.evaluate(()=>window.dashboardTest.active=true);await page.getByRole('button',{name:'إعادة المحاولة',exact:true}).click();await summaryReady();
 // Non-financial roles get only authorized operational metadata and no financial reads.
 await page.evaluate(()=>localStorage.setItem('cas:v1:locale','en'));await page.goto(`${base}/?role=PROCUREMENT`);await page.locator('#executive-dashboard-title').waitFor();await page.getByText('Financial summaries are unavailable for this role.',{exact:false}).waitFor();assert.equal(await page.locator('.recharts-surface').count(),0);
 assert.equal(await page.evaluate(()=>window.dashboardTest.reads.some(r=>['expenses','supplier_payments','subcontractor_certificates'].includes(r.table))),false);
 const exact=await page.evaluate(async()=>{const m=await import('/src/dashboard/dashboardSummary.ts');return {money:m.dashboardAED('18446744073709551614'),chart:m.dashboardChartRows([{id:'1',label:'A',minor:'9223372036854775807'},{id:'2',label:'B',minor:'9223372036854775807'}])};});
 assert.equal(exact.money,'184,467,440,737,095,516.14 AED');assert.deepEqual(exact.chart.map(r=>r.weight),[100,100]);assert(exact.chart.every(r=>r.minor==='9223372036854775807'));
 assert.equal(errors.length,0,errors.join('\n'));
 await writeFile(`${evidence}/results.json`,JSON.stringify({results,repositoryReads:'Company filtered; multi-page expenses; existing outstanding/reversal handling',states:'Loading/empty/error/retry, injected scope rejection, delayed Company transition and Auth revocation PASS',mutations:0,privateTables:0,storage:'No business reads',consoleErrors:errors,hosted:'Not run'},null,2));
 console.log(`Executive Dashboard PASS: ${results.length} role/locale/viewport combinations; root/nav/refresh, real repository paging/totals, read-only roles, scope transitions, failure states, charts and no private/mutation/business-storage paths. ${evidence}`);
 function windowCompany(reads){return reads.find(r=>r.table==='company_settings').filters.find(([k])=>k==='company_id')[1];}
}finally{await browser?.close();await server.close();}
