// Real Chromium with actual providers and forms; isolated in-memory transport.
import assert from 'node:assert/strict';
import { createServer } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve } from 'node:path';
import { chromium } from 'playwright';
const root=resolve(import.meta.dirname,'..');
const server=await createServer({root,configFile:false,plugins:[{name:'owner-party-name-fixture',configureServer(s){s.middlewares.use('/__owner_party_test',async(_req,res)=>{res.setHeader('Content-Type','text/html');res.end(await s.transformIndexHtml('/__owner_party_test','<html><body><div id="root"></div><script type="module" src="/scripts/fixtures/p6c-owner-party-name-interactions.tsx"></script></body></html>'));});}},react()],server:{host:'127.0.0.1',port:0},logLevel:'error'});
let browser;
try {
 await server.listen();browser=await chromium.launch({headless:true,...(process.env.CHROMIUM_PATH?{executablePath:process.env.CHROMIUM_PATH}:{})});
 const page=await browser.newPage({viewport:{width:1000,height:750}});const errors=[];
 page.on('pageerror',e=>errors.push(e.message));
 await page.route('**/*',route=>new URL(route.request().url()).hostname==='127.0.0.1'?route.continue():route.abort());
 await page.goto(`http://127.0.0.1:${server.httpServer.address().port}/__owner_party_test`);
 const edit=()=>page.getByRole('button',{name:'Edit owner name',exact:true}).last();
 const form=()=>page.getByRole('form',{name:'Edit owner name',exact:true});
 const refresh=()=>page.getByRole('button',{name:'Refresh owner records',exact:true}).first();
 const resetLog=()=>page.evaluate(()=>{window.slice14.log.length=0;});
 const open=async()=>{await edit().focus();await page.keyboard.press('Enter');await form().waitFor();assert(await form().evaluate(el=>el.contains(document.activeElement)));const box=await form().boundingBox();assert(box.y<750&&box.y+box.height>0);};
 await edit().waitFor();
 if(process.env.P6C_NARROW_ONLY==='1') {
  await page.setViewportSize({width:390,height:750});
  for(const locale of ['en','ar']) {
   if(locale==='ar'){await page.getByRole('button',{name:'العربية',exact:true}).click();await page.waitForFunction(()=>document.documentElement.dir==='rtl');}
   for(const [code,name] of [['000','A'.repeat(200)],['001','ع'.repeat(200)]]) {
    const label=page.getByText(`${code} · ${name}`,{exact:true});assert.equal(await label.textContent(),`${code} · ${name}`);
    assert(await label.evaluate(el=>{const r=el.getBoundingClientRect();return r.width<=el.parentElement.clientWidth&&r.height>parseFloat(getComputedStyle(el).lineHeight);}));
   }
   const button=page.getByRole('button',{name:locale==='en'?'Edit owner name':'تعديل اسم المالك',exact:true}).last();
   await button.focus();await page.keyboard.press('Enter');const panel=page.getByRole('form');await panel.waitFor();assert(await panel.evaluate(el=>el.contains(document.activeElement)));
   assert(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth&&document.body.scrollWidth<=innerWidth));
   await panel.getByRole('button',{name:locale==='en'?'Close':'إغلاق',exact:true}).click();assert(await button.evaluate(el=>document.activeElement===el));
  }
  assert.equal(errors.length,0,errors.join('\n'));
  console.log('PASS: Slice 14 focused 390px LTR/RTL, full 200-character ASCII/Arabic names wrap without document/body overflow; populated keyboard editor and cancel focus.');
 } else {
 await open();
 assert.equal(await form().locator('[name="name"]').inputValue(),'Party 11');
 assert.deepEqual(await form().locator('input,textarea').evaluateAll(es=>es.map(e=>e.name)),['name']);
 await form().getByRole('button',{name:'Close',exact:true}).click();assert(await edit().evaluate(el=>document.activeElement===el));
 await open();await resetLog();await form().locator('[name="name"]').fill('  مشروع  Mixed  ');
 await form().getByRole('button',{name:'Save owner name',exact:true}).click();await form().waitFor({state:'detached'});
 const saved=await page.evaluate(()=>window.slice14.log);assert.equal(saved.length,2);assert(saved.every(c=>c.table==='parties'));
 assert.deepEqual(saved[0].payload,{name:'مشروع  Mixed'});
 assert.deepEqual(saved[0].filters,[['company_id','company-a'],['type','OWNER'],['id','party-11'],['updated_at','2000-01-01T00:00:00.123456+00:00']]);
 assert.equal(await page.evaluate(()=>window.slice14.parties[11].status),'INACTIVE');
 const activeEdit=page.getByRole('button',{name:'Edit owner name',exact:true}).first();
 await activeEdit.click();await form().waitFor();
 await form().locator('[name="name"]').fill('   ');
 await form().getByRole('button',{name:'Save owner name',exact:true}).click();
 await form().getByRole('alert').filter({hasText:'1–200'}).waitFor();
 await form().locator('[name="name"]').fill('x'.repeat(201));
 await form().getByRole('button',{name:'Save owner name',exact:true}).click();
 assert.equal(await form().getByRole('alert').count(),1);
 await form().locator('[name="name"]').fill('A'.repeat(200));
 await form().getByRole('button',{name:'Save owner name',exact:true}).click();await form().waitFor({state:'detached'});
 assert.deepEqual(await page.evaluate(()=>({name:window.slice14.parties[0].name,status:window.slice14.parties[0].status})),{name:'A'.repeat(200),status:'ACTIVE'});
 await open();await form().locator('[name="name"]').fill('Draft retained');await resetLog();
 await page.evaluate(()=>{window.dispatchEvent(new Event('focus'));document.dispatchEvent(new Event('visibilitychange'));});
 await page.waitForFunction(()=>window.slice14.log.some(c=>c.operation==='authority'));
 assert.equal(await form().locator('[name="name"]').inputValue(),'Draft retained');assert((await page.evaluate(()=>window.slice14.log)).every(c=>['profiles','company_memberships','companies'].includes(c.table)));
 await page.evaluate(()=>window.slice14.concurrent());await form().getByRole('button',{name:'Save owner name',exact:true}).click();await page.getByRole('alert').filter({hasText:'changed or is no longer available'}).waitFor();assert(await form().getByRole('button',{name:'Save owner name',exact:true}).isDisabled());
 await refresh().click();await form().waitFor({state:'detached'});await edit().waitFor();
 await open();await form().locator('[name="name"]').fill('Saved before failed refresh');await page.evaluate(()=>window.slice14.fail('read'));await form().getByRole('button',{name:'Save owner name',exact:true}).click();await page.getByRole('alert').filter({hasText:'was saved, but owner records could not be refreshed'}).waitFor();
 await page.evaluate(()=>window.slice14.fail('read'));await refresh().click();await page.getByRole('alert').filter({hasText:'was saved, but owner records could not be refreshed'}).waitFor();await resetLog();await refresh().click();await page.getByRole('status').filter({hasText:'Owner name saved.'}).waitFor();assert((await page.evaluate(()=>window.slice14.log)).every(c=>c.kind==='read'));
 // Global Parties refresh must retain visible recovery feedback after closing the row panel.
 await open();await page.evaluate(()=>window.slice14.fail('read'));await form().getByRole('button',{name:'Save owner name',exact:true}).click();await page.getByRole('alert').waitFor();
 await page.evaluate(()=>window.slice14.fail('read'));await page.getByRole('button',{name:'Refresh parties',exact:true}).click();await form().waitFor({state:'detached'});await page.getByRole('alert').filter({hasText:'was saved, but owner records could not be refreshed'}).waitFor();
 await page.getByRole('button',{name:'Refresh parties',exact:true}).click();await page.getByRole('alert').waitFor({state:'detached'});assert(await edit().isEnabled());
 for(const role of ['PROCUREMENT','PROJECT_MANAGER','ACCOUNTANT','DATA_ENTRY','MANAGEMENT_VIEWER','SYSTEM_ADMIN']) {await page.evaluate(r=>window.slice14.role(r),role);await page.getByText(`Role: ${role}`,{exact:true}).waitFor();assert.equal(await edit().count(),0);}
 await page.evaluate(()=>window.slice14.role('ACCOUNTING_ADMIN'));await edit().waitFor();await open();await form().locator('[name="name"]').fill('Late Alpha');await page.evaluate(()=>window.slice14.hold('update'));await form().getByRole('button',{name:'Save owner name',exact:true}).click();
 await page.getByRole('button',{name:'Switch fixture company',exact:true}).click();await page.getByRole('heading',{name:'Beta Brand',exact:true}).waitFor();await page.evaluate(()=>window.slice14.release());await page.waitForTimeout(80);assert(!(await page.locator('main').textContent()).includes('Late Alpha'));assert((await page.locator('main').textContent()).includes('Beta Party'));
 await page.getByRole('button',{name:'Switch fixture company',exact:true}).click();await page.getByRole('heading',{name:'Alpha Brand',exact:true}).waitFor();await open();await page.evaluate(()=>window.slice14.role('MANAGEMENT_VIEWER'));await page.getByText('Role: MANAGEMENT_VIEWER',{exact:true}).waitFor();assert.equal(await form().count(),0);
 await page.evaluate(()=>window.slice14.role('ACCOUNTING_ADMIN'));await edit().waitFor();await page.setViewportSize({width:390,height:750});await page.getByRole('button',{name:'العربية',exact:true}).click();await page.waitForFunction(()=>document.documentElement.dir==='rtl');
 const arEdit=page.getByRole('button',{name:'تعديل اسم المالك',exact:true}).last();await arEdit.focus();await page.keyboard.press('Enter');const arForm=page.getByRole('form',{name:'تعديل اسم المالك',exact:true});await arForm.waitFor();assert(await arForm.evaluate(el=>el.contains(document.activeElement)));assert(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth));
 await arForm.locator('[name="name"]').fill('  ملاحظات عربية  ');await arForm.getByRole('button',{name:'حفظ اسم المالك',exact:true}).click();await arForm.waitFor({state:'detached'});assert(await arEdit.evaluate(el=>document.activeElement===el));
 await page.evaluate(()=>window.slice14.revoke());await page.getByTestId('auth-phase').filter({hasText:'NO_ACTIVE_COMPANY'}).waitFor();assert.equal(await page.locator('header').count(),0);
 await page.evaluate(()=>window.slice14.restore());await page.getByRole('button',{name:'Select fixture Alpha',exact:true}).click();await page.getByRole('heading',{name:'Alpha Brand',exact:true}).waitFor();await page.evaluate(()=>window.slice14.logout());await page.getByTestId('auth-phase').filter({hasText:'SIGNED_OUT'}).waitFor();
 assert.equal(errors.length,0,errors.join('\n'));
 console.log('Slice 14 real isolated Chromium PASS: lower-row keyboard/focus, populated exact payload/token, name-only INACTIVE Owner Party edit, resource-only refresh, stale conflict, failed-refresh recovery, role revocation, tenant/delayed-save isolation, tab return, RTL/narrow layout, profile revocation/logout.');
 }
} finally {await browser?.close();await server.close();}
