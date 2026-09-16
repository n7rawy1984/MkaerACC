// Real Chromium with actual providers and forms; isolated in-memory transport.
import assert from 'node:assert/strict';
import { createServer } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'node:path';
import { chromium } from 'playwright';
const root=resolve(import.meta.dirname,'..');
const server=await createServer({root,configFile:false,plugins:[{name:'company-profile-fixture',configureServer(s){s.middlewares.use('/__company_test',async(_req,res)=>{res.setHeader('Content-Type','text/html');res.end(await s.transformIndexHtml('/__company_test','<html><body><div id="root"></div><script type="module" src="/scripts/fixtures/p6c-company-profile-interactions.tsx"></script></body></html>'));});}},react()],server:{host:'127.0.0.1',port:0},logLevel:'error'});
let browser;
try {
 await server.listen();browser=await chromium.launch({headless:true,...(process.env.CHROMIUM_PATH?{executablePath:process.env.CHROMIUM_PATH}:{})});
 const page=await browser.newPage({viewport:{width:1000,height:750}});const errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 await page.route('**/*',route=>new URL(route.request().url()).hostname==='127.0.0.1'?route.continue():route.abort());
 await page.goto(`http://127.0.0.1:${server.httpServer.address().port}/__company_test`);
 const edit=()=>page.getByRole('button',{name:'Edit company profile',exact:true});
 const form=()=>page.getByRole('form',{name:'Edit company profile',exact:true});
 const refresh=()=>page.getByRole('button',{name:'Refresh company profile',exact:true});
 const log=()=>page.evaluate(()=>structuredClone(window.slice7.log));
 const resetLog=()=>page.evaluate(()=>{window.slice7.log.length=0;});
 const open=async()=>{await edit().click();await form().waitFor();assert(await form().evaluate(el=>el.contains(document.activeElement)));};
 await edit().waitFor();assert.equal(await page.getByTestId('auth-legal').textContent(),'Alpha Legal');
 await open();assert.deepEqual(await form().locator('input,textarea').evaluateAll(es=>es.map(e=>e.name)),['legal_name','trn','address','notes']);
 await form().getByRole('button',{name:'Close',exact:true}).click();
 assert(await edit().evaluate(el=>document.activeElement===el),'close restores focus');
 await open();await resetLog();
 await form().locator('[name="legal_name"]').fill('  شركة  MiXeD  ');
 await form().locator('[name="trn"]').fill(' 000123 ');
 await form().locator('[name="notes"]').fill(' \t ');
 await form().getByRole('button',{name:'Save profile',exact:true}).click();await form().waitFor({state:'detached'});
 assert.equal(await page.getByTestId('auth-legal').textContent(),'شركة  MiXeD');
 assert((await page.locator('header').textContent()).includes('شركة  MiXeD'));
 const saved=await log();assert.equal(saved.length,2);assert(saved.every(c=>c.table==='companies'));
 assert.deepEqual(saved[0].payload,{legal_name:'شركة  MiXeD',trn:'000123',address:null,notes:null});
 assert.deepEqual(saved[0].filters,[['id','company-a'],['updated_at','2000-01-01T00:00:00.123456+00:00']]);
 await open();await resetLog();
 await page.evaluate(()=>{window.dispatchEvent(new Event('focus'));document.dispatchEvent(new Event('visibilitychange'));});
 await page.waitForFunction(()=>window.slice7.log.some(c=>c.operation==='authority'));
 assert(await form().isVisible());assert((await log()).every(c=>['profiles','company_memberships','companies'].includes(c.table)&&c.operation!=='update'&&!c.columns.includes('updated_at')));
 await page.evaluate(()=>window.slice7.concurrent());await form().getByRole('button',{name:'Save profile',exact:true}).click();
 await page.getByRole('alert').filter({hasText:'changed or is no longer available'}).waitFor();
 assert(await form().getByRole('button',{name:'Save profile',exact:true}).isDisabled());
 await refresh().click();await form().waitFor({state:'detached'});await page.waitForFunction(()=>document.querySelector('[data-testid="auth-legal"]').textContent==='Concurrent Legal');
 // Save acknowledged, subsequent Company read fails; repeated recovery never replays.
 await open();await form().locator('[name="legal_name"]').fill('Saved despite refresh failure');await page.evaluate(()=>window.slice7.fail('read'));
 await form().getByRole('button',{name:'Save profile',exact:true}).click();
 await page.getByRole('alert').filter({hasText:'was saved, but could not be refreshed'}).waitFor();
 await page.evaluate(()=>window.slice7.fail('read'));await refresh().click();
 await page.getByRole('alert').filter({hasText:'was saved, but could not be refreshed'}).waitFor();
 await resetLog();await refresh().click();await page.waitForFunction(()=>document.querySelector('[data-testid="auth-legal"]').textContent==='Saved despite refresh failure');
 assert((await log()).every(c=>c.kind==='read'));
 // An older in-flight authority response cannot overwrite a later profile refresh.
 await page.evaluate(()=>{window.slice7.hold('authority');window.dispatchEvent(new Event('focus'));});
 await page.waitForFunction(()=>window.slice7.log.some(c=>c.operation==='authority'));
 await open();await form().locator('[name="legal_name"]').fill('Latest Legal');await form().getByRole('button',{name:'Save profile',exact:true}).click();await form().waitFor({state:'detached'});
 await page.evaluate(()=>window.slice7.release());await page.waitForTimeout(80);
 assert.equal(await page.getByTestId('auth-legal').textContent(),'Latest Legal');
 // Both configuration roles; all other roles lose mutation controls after revalidation.
 await page.evaluate(()=>window.slice7.role('SYSTEM_ADMIN'));await page.getByText('Role: SYSTEM_ADMIN',{exact:true}).waitFor();
 await open();await form().locator('[name="legal_name"]').fill('');await form().getByRole('button',{name:'Save profile',exact:true}).click();await form().waitFor({state:'detached'});
 assert.equal(await page.getByTestId('auth-legal').textContent(),'NULL');
 for(const role of ['ACCOUNTANT','PROCUREMENT','DATA_ENTRY','MANAGEMENT_VIEWER','PROJECT_MANAGER']) {
   await page.evaluate(r=>window.slice7.role(r),role);await page.getByText(`Role: ${role}`,{exact:true}).waitFor();assert.equal(await edit().count(),0);
 }
 await page.evaluate(()=>window.slice7.role('ACCOUNTING_ADMIN'));await edit().waitFor();
 // A delayed save finishing after a Company switch must not repaint Alpha under Beta.
 await open();await form().locator('[name="legal_name"]').fill('Late Alpha');await page.evaluate(()=>window.slice7.hold('update'));
 await form().getByRole('button',{name:'Save profile',exact:true}).click();
 await page.getByRole('button',{name:'Switch fixture company',exact:true}).click();await page.getByRole('heading',{name:'Beta Brand',exact:true}).waitFor();
 await page.evaluate(()=>window.slice7.release());await page.waitForTimeout(80);
 assert.equal(await page.getByTestId('auth-legal').textContent(),'Beta Legal');assert(!(await page.locator('main').textContent()).includes('Late Alpha'));
 await page.getByRole('button',{name:'Switch fixture company',exact:true}).click();await page.getByRole('heading',{name:'Alpha Brand',exact:true}).waitFor();
 await open();await page.evaluate(()=>window.slice7.role('MANAGEMENT_VIEWER'));await page.getByText('Role: MANAGEMENT_VIEWER',{exact:true}).waitFor();assert.equal(await form().count(),0);
 await page.evaluate(()=>window.slice7.role('ACCOUNTING_ADMIN'));await edit().waitFor();
 await page.getByRole('button',{name:'العربية',exact:true}).click();
 await page.waitForFunction(()=>document.documentElement.dir==='rtl');
 await page.getByRole('button',{name:'تعديل بيانات الشركة',exact:true}).click();
 const arabicForm=page.getByRole('form',{name:'تعديل بيانات الشركة',exact:true});await arabicForm.waitFor();assert(await arabicForm.evaluate(el=>el.contains(document.activeElement)));
 await arabicForm.locator('[name="address"]').fill('  عنوان عربي  ');await arabicForm.getByRole('button',{name:'حفظ البيانات',exact:true}).click();await arabicForm.waitFor({state:'detached'});
 await page.evaluate(()=>window.slice7.revoke());await page.getByTestId('auth-phase').filter({hasText:'NO_ACTIVE_COMPANY'}).waitFor();assert.equal(await page.locator('header').count(),0);
 await page.evaluate(()=>window.slice7.restore());await page.getByRole('button',{name:'Select fixture Alpha',exact:true}).click();await page.getByRole('heading',{name:'Alpha Brand',exact:true}).waitFor();
 await page.evaluate(()=>window.slice7.logout());await page.getByTestId('auth-phase').filter({hasText:'SIGNED_OUT'}).waitFor();
 assert.equal(errors.length,0,errors.join('\n'));
 console.log('Slice 7 real Chromium PASS: click/form/save/clear, exact payload/token, focus, RTL, Auth/legal-name synchronization including in-flight authority race, selective refresh and recovery, roles, tenant switch, stale edit, delayed save, revocation, logout. Isolated transport; not hosted authenticated acceptance.');
} finally {await browser?.close();await server.close();}
