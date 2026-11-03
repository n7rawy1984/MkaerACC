import assert from 'node:assert/strict';
import {createServer} from 'vite';
import react from '@vitejs/plugin-react';
import {chromium} from 'playwright';
import {readFile,writeFile,mkdir} from 'node:fs/promises';
import {resolve} from 'node:path';
const root=resolve(import.meta.dirname,'..'),out='/tmp/narvo-m2';await mkdir(out,{recursive:true});
const section=process.env.WORKSPACE_BROWSER_SECTION??'all';
const routes=['/','/company-profile','/projects','/parties','/expense-categories','/accounts','/treasury-accounts','/subcontracts','/expenses','/supplier-payments','/subcontractor-advances','/subcontractor-certificates','/subcontractor-payments','/retention-releases','/retention-payments','/attendance','/payroll','/accounting-cycle','/accounting-reports'];
const server=await createServer({root,configFile:false,plugins:[{name:'company-workspace-transport',load(id){if(id===resolve(root,'src/lib/supabase.ts'))return 'export const getSupabaseClient=()=>window.dashboardTest.client';},configureServer(s){s.middlewares.use(async(req,res,next)=>{if(!routes.includes(new URL(req.url,'http://localhost').pathname))return next();res.setHeader('Content-Type','text/html');res.end(await s.transformIndexHtml(req.url,'<html><head><meta name="viewport" content="width=device-width,initial-scale=1"></head><body><div id="root"></div><script type="module" src="/scripts/fixtures/company-workspace.tsx"></script></body></html>'));});}},react()],server:{host:'127.0.0.1',port:0,hmr:false},logLevel:'error'});
let browser,page;const checks=[],errors=[],scans=[];const axeSource=process.env.WORKSPACE_AXE_SOURCE?await readFile(process.env.WORKSPACE_AXE_SOURCE,'utf8'):null;
const check=(v,label)=>{assert(v,label);checks.push(label);if(section==='boundaries')console.log(label);else if(checks.length%25===0)console.log('Workspace browser: '+checks.length+' assertions passed');};
try{
 await server.listen();browser=await chromium.launch({headless:true});page=await browser.newPage({viewport:{width:1440,height:1000}});page.setDefaultTimeout(60000);page.setDefaultNavigationTimeout(60000);page.on('pageerror',e=>errors.push(e.message));await page.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());const base=`http://127.0.0.1:${server.httpServer.address().port}`;
 const ready=async()=>{await page.locator('.company-workspace').waitFor();await page.getByText('53.53 AED',{exact:true}).first().waitFor();};
 const navigate=async path=>{const mobile=await page.locator('.workspace-menu-toggle').isVisible();if(mobile)await page.locator('.workspace-menu-toggle').click();const nav=page.locator(mobile?'.workspace-navigation-dialog':'.workspace-sidebar');const a=nav.locator(`nav a[href="${path}"]`);await a.evaluate(a=>a.closest('details').open=true);await a.click();await page.waitForFunction(p=>location.pathname===p,path);await page.locator('main').waitFor();};
 const scan=async label=>{if(!axeSource)return;await page.addScriptTag({content:axeSource});const r=await page.evaluate(()=>window.axe.run(document,{runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21aa','wcag22aa']}}));scans.push({label,violations:r.violations.map(v=>({id:v.id,impact:v.impact,targets:v.nodes.map(n=>n.target)})),incomplete:r.incomplete.map(v=>v.id)});await writeFile(out+'/accessibility-'+section+'.json',JSON.stringify(scans,null,2));check(!r.violations.length,label+': accessibility '+JSON.stringify(scans.at(-1).violations));};
 await page.goto(base+'/',{waitUntil:'domcontentloaded'});await ready();
 if(section!=='boundaries'){
 check(await page.locator('.workspace-sidebar details').count()===8,'eight role-filtered collapsible navigation groups');
 for(const [label,value] of [['Posted expense net','53.53 AED'],['Supplier Outstanding','0.61 AED'],['Subcontractor Outstanding Payable','92.00 AED'],['Retention Held','7.00 AED']])check((await page.getByText(label,{exact:true}).first().locator('..').locator('..').innerText()).includes(value),'exact existing metric: '+label);
 check(await page.locator('.workspace-quick-actions a[href="/expenses#new-expense"]').count()===1,'verified Trial operator sees New Expense');
 check(await page.locator('.workspace-quick-actions a[href="/supplier-payments"]').count()===1,'operator payment shortcut is present');
 check(await page.locator('.recharts-surface').count()>=4,'existing financial charts rendered');
 check(await page.getByRole('region',{name:'Historical activity',exact:true}).count()===1 && (await page.locator('main').innerText()).includes('Imported cash/source evidence is not a posted ledger balance.'),'historical activity separated from posted accounting');
 const preserve=await page.evaluate(()=>JSON.stringify(window.dashboardTest.tables));
 for(const locale of ['en','ar']){
  if(locale==='ar')await page.getByRole('button',{name:'العربية',exact:true}).click();
  for(const width of [1440,820,390]){
   await page.setViewportSize({width,height:1000});await navigate('/');await ready();
   check(await page.locator('html').getAttribute('dir')===(locale==='ar'?'rtl':'ltr'),`${locale}/${width}: direction`);check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),`${locale}/${width}: dashboard no overflow`);
   await page.screenshot({path:out+`/dashboard-${locale}-${width}.png`,fullPage:true});if(width!==820)await scan(`dashboard-${locale}-${width}`);
   await navigate('/accounting-cycle');await page.locator('.workspace-cycle-grid>li').last().waitFor();
   check(await page.locator('.workspace-cycle-grid>li').count()===6,`${locale}/${width}: six accounting stages`);check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),`${locale}/${width}: cycle no overflow`);check(await page.locator('.workspace-cycle-grid .workspace-state-development').count()===1,`${locale}/${width}: incomplete reporting labelled`);check(await page.locator('.workspace-cycle-grid .workspace-state-verification').count()===1,`${locale}/${width}: closing requires verification`);
   if(width!==820){await page.screenshot({path:out+`/cycle-${locale}-${width}.png`,fullPage:true});await scan(`cycle-${locale}-${width}`);}
  }
 }
 await page.setViewportSize({width:1440,height:1000});await page.getByRole('button',{name:'English',exact:true}).click();
 for(const path of routes.filter(p=>p!=='/')){
  // Non-empty dashboard provenance is tested above. Existing financial modules
  // get valid empty read results here; mutation endpoints are always forbidden.
  await page.evaluate(p=>{window.dashboardTest.empty=p.startsWith('/subcontractor-')||p.startsWith('/retention-')||p==='/supplier-payments';},path);
  await navigate(path);await page.waitForTimeout(250);
  check(await page.locator('#company-workspace-main').count()===1,path+': shared main landmark');check(await page.locator('main main').count()===0,path+': no nested main');
  check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),path+': no document overflow');
  if(path==='/subcontracts')check((await page.locator('main').innerText()).includes('65,000.00 AED'),'M1 subcontract AED retained inside shared shell');
 }
 await navigate('/expenses');await page.getByRole('row').filter({hasText:'SYN-AUG'}).getByRole('button',{name:'Edit',exact:true}).click();await page.getByRole('region',{name:'Date evidence',exact:true}).waitFor();check((await page.getByRole('region',{name:'Date evidence',exact:true}).innerText()).includes('2026-08-01'),'M1 canonical date evidence retained inside shell');const save=page.getByRole('button',{name:'Save changes',exact:true});check(await save.isVisible(),'M1 accessible Save changes visible inside shell');check(await save.evaluate(e=>getComputedStyle(e).color!==getComputedStyle(e).backgroundColor),'M1 Save foreground/background remain distinct');await page.getByRole('button',{name:'Cancel edit',exact:true}).click();
 check(await page.evaluate(()=>window.dashboardTest.mutations.length)===0,'navigation invokes no mutation RPC/table write');
 check(await page.evaluate(()=>JSON.stringify(window.dashboardTest.tables))===preserve,'all synthetic financial/master/source data unchanged by navigation');
 }
 if(section!=='presentation'){
 await page.evaluate(()=>{window.dashboardTest.empty=false;});await navigate('/');await ready();
 for(const state of ['EXPIRED','CANCELLED']){await page.evaluate(s=>{window.dashboardTest.subscriptionState=s;window.dispatchEvent(new Event('focus'));},state);await page.waitForFunction(()=>document.querySelector('.workspace-quick-actions [aria-disabled="true"]'));check(await page.locator('.workspace-quick-actions a[href="/expenses#new-expense"]').count()===0,state+': new expense shortcut disabled');check(await page.locator('.workspace-quick-actions a[href="/supplier-payments"]').count()===1,state+': permitted settlement shortcut retained');}
 await page.evaluate(()=>{window.dashboardTest.subscriptionFail=true;window.dispatchEvent(new Event('focus'));});await page.getByText('Subscription status could not be verified. Reload to check.',{exact:true}).waitFor();check(await page.locator('.workspace-quick-actions a[href="/supplier-payments"]').count()===0,'unknown subscription hides transaction shortcut');
 await page.evaluate(()=>{window.dashboardTest.subscriptionFail=false;window.dashboardTest.foreignSubscription=true;window.dispatchEvent(new Event('focus'));});await page.waitForTimeout(100);check(await page.locator('.workspace-quick-actions a[href="/expenses#new-expense"]').count()===0,'foreign Company subscription cannot enable new-operation shortcut');
 await page.goto(base+'/?role=MANAGEMENT_VIEWER');await ready();check((await page.locator('.workspace-user').innerText()).replace(/\s/g,'')==='BRead-onlyaccess','Barq is a viewer identity, not a Company');check(await page.locator('.workspace-quick-actions a[href="/expenses#new-expense"],.workspace-quick-actions a[href="/supplier-payments"]').count()===0,'viewer has no mutation shortcuts');check(await page.locator('.workspace-sidebar a[href="/attendance"]').count()===0,'viewer sees no operator Attendance link');check(await page.locator('.workspace-sidebar a[href="/payroll"]').count()===1,'viewer retains existing source Payroll read access');
 await page.setViewportSize({width:390,height:900});const trigger=page.getByRole('button',{name:'Open workspace navigation',exact:true});await trigger.click();await page.getByRole('dialog').waitFor();await scan('mobile-navigation');await page.keyboard.press('Tab');check(await page.getByRole('dialog').evaluate(d=>d.contains(document.activeElement)),'mobile native dialog traps focus');await page.keyboard.press('Escape');check(await trigger.evaluate(e=>e===document.activeElement),'Escape restores navigation opener focus');
 await page.goto(base+'/?role=SYSTEM_ADMIN');await page.locator('.workspace-quick-actions').waitFor();check(await page.locator('.workspace-sidebar a[href="/accounting-reports"],.workspace-sidebar a[href="/accounts"]').count()===0,'System Admin has no implicit financial navigation');check(await page.locator('.workspace-kpi-value').count()===1,'System Admin overview has no financial KPI');
 await page.goto(base+'/?role=PROJECT_MANAGER');await page.locator('.workspace-quick-actions').waitFor();check(await page.locator('.workspace-sidebar a[href="/accounts"]').count()===0,'project role sees no Company COA');check(await page.locator('.workspace-sidebar a[href="/treasury-accounts"]').count()===1,'project role retains RLS-scoped Treasury route');
 await page.goto(base+'/?role=ACCOUNTING_ADMIN');await ready();await page.evaluate(()=>{window.dashboardTest.company=window.dashboardTest.other;window.dashboardTest.emit('USER_UPDATED');});await page.waitForFunction(()=>document.querySelector('.workspace-tenant')?.textContent.includes('Second Company'));check(true,'tenant transition replaces workspace identity');
 }
 check(errors.length===0,errors.join(';'));await writeFile(out+'/browser-'+section+'-result.json',JSON.stringify({status:'PASS',section,checks:checks.length,details:checks,errors,accessibility:scans,hosted:false},null,2));console.log(`PASS: ${checks.length} Company workspace browser assertions; role/subscription/navigation/provenance/RTL/responsive/data preservation.`);
}catch(e){await page?.screenshot({path:out+'/failure.png',fullPage:true}).catch(()=>{});await writeFile(out+'/failure.json',JSON.stringify({error:e.message,checks,errors},null,2));throw e;}finally{await browser?.close();await server.close();}
