import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve} from 'node:path';
import {createServer} from 'vite';
import react from '@vitejs/plugin-react';
import {chromium} from 'playwright';
const out='/tmp/narvo-premium-system';mkdirSync(out,{recursive:true});
const paths=[...new Set([...readFileSync('src/workspace/workspaceNavigation.ts','utf8').matchAll(/path:'([^']+)'/g)].map(x=>x[1]))].filter(p=>p!=='/');
const checks=[],errors=[],external=[],coverage=[];const check=(v,n)=>{assert(v,n);checks.push(n);};
const server=await createServer({configFile:false,logLevel:'error',plugins:[{name:'premium-safe-fixture',load(p){if(p===resolve('src/lib/supabase.ts'))return 'export const getSupabaseClient=()=>window.dashboardTest.client;';},configureServer(s){s.middlewares.use(async(req,res,next)=>{if(!req.url.startsWith('/visual/'))return next();res.setHeader('Content-Type','text/html');res.end(await s.transformIndexHtml(req.url,'<!doctype html><html lang="en"><head><title>NARVO local visual verification</title><meta name="viewport" content="width=device-width,initial-scale=1"></head><body><div id="root"></div><script type="module" src="/scripts/fixtures/premium-system.tsx"></script></body></html>'));});}},react()],server:{host:'127.0.0.1',port:0,hmr:false}});
await server.listen();const base='http://127.0.0.1:'+server.httpServer.address().port;const browser=await chromium.launch({headless:true,executablePath:'/usr/bin/google-chrome'});const page=await browser.newPage({viewport:{width:1366,height:768}});page.setDefaultTimeout(60000);page.on('pageerror',e=>errors.push(e.message));page.on('request',r=>{if(!r.url().startsWith(base)&&!r.url().startsWith('blob:'))external.push(r.url());});
try{
 // The fixture enters the existing router directly, then follows actual navigation.
 await page.goto(base+'/visual/start',{waitUntil:'domcontentloaded'});await page.locator('.company-workspace').waitFor();
 const go=async path=>{await page.evaluate(p=>{history.pushState({},'',p);window.dispatchEvent(new PopStateEvent('popstate'));},path);await page.waitForTimeout(300);};
 if(!process.env.PREMIUM_ROLE_ONLY){
 await go('/expenses');await page.locator('.historical-data-table').waitFor();const original=await page.evaluate(()=>JSON.stringify(window.dashboardTest.tables));
 if(!process.env.PREMIUM_INTERACTIONS_ONLY){
 for(const locale of ['en','ar']){
  if(locale==='ar'){await page.getByRole('button',{name:'العربية',exact:true}).click();}
  for(const path of paths){
   await page.setViewportSize({width:1366,height:768});await go(path);await page.locator('.workspace-route-body').waitFor();console.log(locale+' '+path);
   check(await page.locator('.workspace-route-body').evaluate(e=>!!e.textContent.trim()),locale+' '+path+' actual route renders');
   check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),locale+' '+path+' laptop no page overflow');
   check(await page.locator('.workspace-sidebar').evaluate(e=>getComputedStyle(e).backgroundColor==='rgb(7, 23, 47)'),locale+' '+path+' approved navy shell');
   for(const [name,width,height]of [['desktop',1920,1080],['tablet',820,1180],['mobile',390,844]]){await page.setViewportSize({width,height});check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),locale+' '+path+' '+name+' no page overflow');}
   const file=path.slice(1).replaceAll('/','-');await page.screenshot({path:out+'/'+locale+'-'+file+'-mobile.png',fullPage:true});await page.setViewportSize({width:1366,height:768});await page.screenshot({path:out+'/'+locale+'-'+file+'-laptop.png',fullPage:true});
   coverage.push({locale,path,state:'PREMIUM PARTIAL',reason:'Shared identity applied; populated controls/substates only verified where separately recorded.'});
  }
 }
 }
 if(await page.getByRole('button',{name:'English',exact:true}).count())await page.getByRole('button',{name:'English',exact:true}).click();await go('/expenses');
 const edit=page.getByRole('row').filter({hasText:'Synthetic source review'}).getByRole('button',{name:'Edit',exact:true});await edit.click();await page.getByRole('region',{name:'Date verification',exact:true}).waitFor();check(await page.getByRole('button',{name:'Save changes',exact:true}).isVisible(),'Source edit form retains actionable save');await page.screenshot({path:out+'/en-source-edit-laptop.png',fullPage:true});await page.getByRole('button',{name:'Cancel edit',exact:true}).click();
 await page.locator('.narvo-row-menu').first().locator(':scope > summary').click();check(await page.getByRole('button',{name:'Correct',exact:true}).first().isVisible(),'Compact Expense menu exposes existing correction controls');await page.locator('.narvo-row-menu').first().locator(':scope > summary').click();
 await go('/subcontracts');await page.getByLabel('Contract',{exact:true}).selectOption('98000000-0000-4000-8000-000000000009');await page.getByText('Unrecovered advances',{exact:true}).waitFor();check((await page.locator('main').innerText()).includes('65,000.00 AED'),'Contract statement displays canonical dimensions without changing value');await page.screenshot({path:out+'/en-contract-summary-laptop.png',fullPage:true});
 await go('/employees');await page.getByRole('button',{name:/EMP-001/}).click();check(await page.getByRole('heading',{name:'Synthetic employee / موظف تجريبي',exact:true}).count()===1,'Existing employee profile opens');await page.screenshot({path:out+'/en-employee-profile-laptop.png',fullPage:true});
 await go('/inventory/materials');check(await page.getByRole('navigation',{name:'Inventory views'}).locator('a[aria-current=page]').count()===1,'Inventory tabs identify the active existing route');await page.screenshot({path:out+'/en-inventory-tabs-laptop.png',fullPage:true});
 for(const locale of ['en','ar']){const blob=await page.evaluate(async l=>{const {registerWorkbook}=await import('/src/payroll/payrollRegisterXlsx.ts');const {registerText}=await import('/src/payroll/payrollRegister.ts');const text=registerText[l];const b=await registerWorkbook({company:'Synthetic Company',month:'2026-11',status:'DRAFT',id:'SYN-REGISTER',locale:l,rows:[Array.from({length:13},(_,i)=>i===3?'Synthetic employee':i>4?'123.45':'SYN')],totals:Array.from({length:13},(_,i)=>i===0?text.total:i>4?'123.45':''),filename:'synthetic-register'});return Array.from(new Uint8Array(await b.arrayBuffer()));},locale);writeFileSync(out+'/payroll-'+locale+'.xlsx',Buffer.from(blob));check(blob.length>1000,locale+' styled Payroll workbook generated without changing register values');}
 await go('/payroll');check(await page.getByRole('navigation',{name:'Payroll views'}).getByRole('button',{pressed:true}).count()===1,'Payroll tabs preserve existing selected state');await page.screenshot({path:out+'/en-payroll-tabs-laptop.png',fullPage:true});
 await go('/expenses');
 await page.setViewportSize({width:390,height:844});const menu=page.getByRole('button',{name:'Open workspace navigation',exact:true});await menu.click();await page.getByRole('dialog').waitFor();await page.keyboard.press('Tab');check(await page.getByRole('dialog').evaluate(e=>e.contains(document.activeElement)),'Mobile navigation traps keyboard focus');await page.screenshot({path:out+'/en-navigation-mobile.png',fullPage:true});await page.keyboard.press('Escape');check(await menu.evaluate(e=>e===document.activeElement),'Escape restores navigation focus');
 check(await page.evaluate(()=>window.dashboardTest.mutations.length===0),'No synthetic financial/master mutations');check(await page.evaluate(()=>JSON.stringify(window.dashboardTest.tables))===original,'All financial/master fixture values unchanged');check(!errors.length,'No route runtime errors: '+errors.join(';'));check(!external.length,'No external/Production requests');
 }
 await page.goto(base+'/visual/start?role=MANAGEMENT_VIEWER');await page.locator('.company-workspace').waitFor();await go('/employees');await page.getByRole('button',{name:/EMP-001/}).click();check(await page.getByRole('button',{name:'Add employee',exact:true}).count()===0,'Management Viewer has no employee creation control');check(await page.locator('.workspace-sidebar a[href="/payroll"],.workspace-sidebar a[href="/attendance"]').count()===0,'Management Viewer navigation keeps payroll and attendance restricted');check(!(await page.evaluate(()=>window.dashboardTest.rpcReads)).includes('read_hr_workspace'),'Viewer employee details do not request confidential HR data');

 writeFileSync(out+(process.env.PREMIUM_ROLE_ONLY?'/roles.json':process.env.PREMIUM_INTERACTIONS_ONLY?'/interactions.json':'/browser.json'),JSON.stringify({status:'PASS',checks,coverage,errors,external,scope:'Synthetic read-only actual Company routes; not hosted financial verification'},null,2));console.log('PASS '+checks.length+' checks; mode '+(process.env.PREMIUM_ROLE_ONLY?'viewer':process.env.PREMIUM_INTERACTIONS_ONLY?'focused interactions':'routes and interactions'));
}catch(e){await page.screenshot({path:out+'/failure.png',fullPage:true});writeFileSync(out+'/failure.json',JSON.stringify({error:e.message,checks,errors,external,body:(await page.locator('body').innerText()).slice(-6000)},null,2));console.error(e);process.exitCode=1;}finally{await browser.close();await server.close();}
