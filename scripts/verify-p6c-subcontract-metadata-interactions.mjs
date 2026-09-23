// Real Chromium with actual providers/forms and isolated in-memory transport.
import assert from 'node:assert/strict';
import { createServer } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'node:path';
import { chromium } from 'playwright';
const root=resolve(import.meta.dirname,'..');
const server=await createServer({root,configFile:false,plugins:[{name:'subcontract-metadata-fixture',configureServer(s){s.middlewares.use('/__subcontract_test',async(_req,res)=>{res.setHeader('Content-Type','text/html');res.end(await s.transformIndexHtml('/__subcontract_test','<html><body><div id="root"></div><script type="module" src="/scripts/fixtures/p6c-subcontract-metadata-interactions.tsx"></script></body></html>'));});}},react()],server:{host:'127.0.0.1',port:0},logLevel:'error'});
let browser;
try {
 await server.listen();browser=await chromium.launch({headless:true,...(process.env.CHROMIUM_PATH?{executablePath:process.env.CHROMIUM_PATH}:{})});
 const page=await browser.newPage({viewport:{width:1000,height:760}});const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.route('**/*',route=>new URL(route.request().url()).hostname==='127.0.0.1'?route.continue():route.abort());
 await page.goto(`http://127.0.0.1:${server.httpServer.address().port}/__subcontract_test`);
 const edits=()=>page.getByRole('button',{name:'Edit Subcontract details',exact:true});
 const edit=()=>edits().first();
 const form=()=>page.getByRole('form',{name:'Edit Subcontract details',exact:true});
 const refresh=()=>page.getByRole('button',{name:'Refresh Subcontracts',exact:true}).first();
 const resetLog=()=>page.evaluate(()=>{window.slice16.log.length=0;});
 const open=async()=>{await edit().focus();await page.keyboard.press('Enter');await form().waitFor();assert(await form().evaluate(el=>el.contains(document.activeElement)));};
 await edit().waitFor();assert.equal(await edits().count(),2);await open();
 assert.equal(await form().locator('[name="scope_of_work"]').inputValue(),'Original active scope');
 assert.equal(await form().locator('[name="start_date"]').inputValue(),'2026-01-01');
 assert.deepEqual(await form().locator('input,textarea').evaluateAll(es=>es.map(e=>e.name)),['scope_of_work','start_date','expected_end_date','notes']);
 for(const protectedName of ['contract_number','original_contract_value_minor','approved_variations_minor','retention_bps','status','project_id','subcontractor_id']) assert.equal(await form().locator(`[name="${protectedName}"]`).count(),0);
 await form().getByRole('button',{name:'Close',exact:true}).click();assert(await edit().evaluate(el=>document.activeElement===el));
 await open();await resetLog();await form().locator('[name="scope_of_work"]').fill('  نطاق  Mixed  ');await form().locator('[name="start_date"]').fill('2026-02-03');await form().locator('[name="expected_end_date"]').fill('');await form().locator('[name="notes"]').fill('  A\n  B  ');
 await form().getByRole('button',{name:'Save Subcontract details',exact:true}).click();await form().waitFor({state:'detached'});
 const saved=await page.evaluate(()=>window.slice16.log);assert.equal(saved.length,2);assert(saved.every(c=>c.table==='subcontracts'));
 assert.deepEqual(saved[0].payload,{scope_of_work:'نطاق  Mixed',start_date:'2026-02-03',expected_end_date:null,notes:'A\n  B'});
 assert.deepEqual(saved[0].filters,[['company_id','company-a'],['id','contract-active'],['updated_at','2000-01-01T00:00:00.123456+00:00']]);
 assert.equal(await page.evaluate(()=>window.slice16.subcontracts[0].original_contract_value_minor),'9007199254740993');assert.equal(await page.evaluate(()=>window.slice16.subcontracts[0].status),'ACTIVE');
 const closedEdit=edits().last();await closedEdit.click();assert.equal(await form().locator('[name="scope_of_work"]').inputValue(),'Closed scope');await form().getByRole('button',{name:'Close',exact:true}).click();
 await open();await form().locator('[name="scope_of_work"]').fill('Draft retained');await resetLog();await page.evaluate(()=>{window.dispatchEvent(new Event('focus'));document.dispatchEvent(new Event('visibilitychange'));});await page.waitForFunction(()=>window.slice16.log.some(c=>c.operation==='authority'));assert.equal(await form().locator('[name="scope_of_work"]').inputValue(),'Draft retained');assert((await page.evaluate(()=>window.slice16.log)).every(c=>['profiles','company_memberships','companies'].includes(c.table)));
 await page.evaluate(()=>window.slice16.concurrent());await form().getByRole('button',{name:'Save Subcontract details',exact:true}).click();await page.getByRole('alert').filter({hasText:'changed or is no longer available'}).waitFor();assert(await form().getByRole('button',{name:'Save Subcontract details',exact:true}).isDisabled());await refresh().click();await form().waitFor({state:'detached'});
 await open();await form().locator('[name="notes"]').fill('Known commit');await page.evaluate(()=>window.slice16.fail('read'));await form().getByRole('button',{name:'Save Subcontract details',exact:true}).click();await page.getByRole('alert').filter({hasText:'were saved, but Subcontracts could not be refreshed'}).waitFor();await refresh().click();await form().waitFor({state:'detached'});
 for(const role of ['ACCOUNTANT','MANAGEMENT_VIEWER','PROJECT_MANAGER','DATA_ENTRY','SYSTEM_ADMIN']) {await page.evaluate(r=>window.slice16.role(r),role);await page.getByText(`Role: ${role}`,{exact:true}).waitFor();assert.equal(await page.getByRole('button',{name:'Edit Subcontract details',exact:true}).count(),0);}
 await page.evaluate(()=>window.slice16.role('PROCUREMENT'));await edit().waitFor();assert.equal(await edits().count(),2);
 await page.evaluate(()=>window.slice16.role('ACCOUNTING_ADMIN'));await edit().waitFor();await open();await form().locator('[name="scope_of_work"]').fill('Late Alpha');await page.evaluate(()=>window.slice16.hold('update'));await form().getByRole('button',{name:'Save Subcontract details',exact:true}).click();await page.getByRole('button',{name:'Switch fixture company',exact:true}).click();await page.getByRole('heading',{name:'Beta Brand',exact:true}).waitFor();await page.evaluate(()=>window.slice16.release());await page.waitForTimeout(80);assert(!(await page.locator('main').textContent()).includes('Late Alpha'));assert((await page.locator('main').textContent()).includes('Beta scope'));
 await page.getByRole('button',{name:'Switch fixture company',exact:true}).click();await page.getByRole('heading',{name:'Alpha Brand',exact:true}).waitFor();await page.setViewportSize({width:390,height:760});await page.getByRole('button',{name:'العربية',exact:true}).click();await page.waitForFunction(()=>document.documentElement.dir==='rtl');
 const arEdit=page.getByRole('button',{name:'تعديل بيانات عقد مقاول الباطن',exact:true}).first();await arEdit.focus();await page.keyboard.press('Enter');const arForm=page.getByRole('form',{name:'تعديل بيانات عقد مقاول الباطن',exact:true});await arForm.waitFor();assert(await arForm.evaluate(el=>el.contains(document.activeElement)));await arForm.locator('[name="scope_of_work"]').fill('ن'.repeat(200));assert(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth));await arForm.getByRole('button',{name:'حفظ بيانات عقد مقاول الباطن',exact:true}).click();await arForm.waitFor({state:'detached'});assert(await arEdit.evaluate(el=>document.activeElement===el));
 await page.evaluate(()=>window.slice16.revoke());await page.getByTestId('auth-phase').filter({hasText:'NO_ACTIVE_COMPANY'}).waitFor();assert.equal(await page.locator('header').count(),0);await page.evaluate(()=>window.slice16.restore());await page.getByRole('button',{name:'Select fixture Alpha',exact:true}).click();await page.getByRole('heading',{name:'Alpha Brand',exact:true}).waitFor();await page.evaluate(()=>window.slice16.logout());await page.getByTestId('auth-phase').filter({hasText:'SIGNED_OUT'}).waitFor();
 assert.equal(errors.length,0,errors.join('\n'));
 console.log('Slice 16 real isolated Chromium PASS: populated four-field editor, exact payload/token, ACTIVE/CLOSED, validation boundary, stale/no-retry, failed-refresh recovery, role and authority revocation, resource-only tab return, tenant/late-result isolation, keyboard/focus, EN/AR/RTL and 390px.');
} finally {await browser?.close();await server.close();}
