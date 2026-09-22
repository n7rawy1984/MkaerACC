// Real Chromium click/keyboard/layout regression; in-memory transport only.
// Setup: npm ci && npx playwright install chromium (see verification README).
import assert from 'node:assert/strict';
import { createServer } from 'vite';
import react from '@vitejs/plugin-react';
import { resolve, dirname } from 'node:path';
import { chromium } from 'playwright';
const root = resolve(import.meta.dirname, '..');
const mocks = {
  [resolve(root, 'src/auth/AuthContext')]: `export const useAuth = () => { const s=window.slice6.scope(); return { state:{phase:'TENANT_READY',activeTenant:{role:s.role,companyId:s.companyId,companyName:s.companyId},memberships:[1,2]},showCompanySelector:()=>window.slice6.change({companyId:'company-b'}),signOut:()=>window.slice6.change({signedIn:false}) }; };`,
  [resolve(root, 'src/i18n/I18nContext')]: `export const useT=()=>key=>key; export const useI18n=()=>({locale:'en',setLocale:()=>{}});`,
  [resolve(root, 'src/tenant/TenantSettingsContext')]: `export const useTenantSettings=()=>({phase:'READY',settings:{effectiveDisplayName:window.slice6.scope().companyId,logoUrl:null}});`,
};
const server = await createServer({ root, configFile: false, plugins: [
  { name: 'isolated-supplier-authority', enforce: 'pre', resolveId(source, importer) {
    if (!importer || !source.startsWith('.')) return;
    const path=resolve(dirname(importer), source).replace(/\.tsx?$/, '');
    if (mocks[path]) return '\0supplier-test:'+path;
  }, load(id) { if(id.startsWith('\0supplier-test:')) return mocks[id.slice('\0supplier-test:'.length)]; },
  configureServer(s) { s.middlewares.use('/__supplier_test', async (_req,res) => {
    res.setHeader('Content-Type','text/html');
    res.end(await s.transformIndexHtml('/__supplier_test', '<html><body><div id="root"></div><script type="module" src="/scripts/fixtures/p6c-supplier-interactions.tsx"></script></body></html>'));
  }); } }, react(),
], server: { host:'127.0.0.1', port:0 }, logLevel:'error' });
let browser;
try {
  await server.listen();
  browser=await chromium.launch({ headless:true, ...(process.env.CHROMIUM_PATH ? {executablePath:process.env.CHROMIUM_PATH}: {}) });
  const page=await browser.newPage({viewport:{width:1000,height:650}});
  const errors=[];
  page.on('pageerror',e=>errors.push(e.message));
  // Any external request is a test failure; this browser has no user profile/session.
  await page.route('**/*', route=>new URL(route.request().url()).hostname==='127.0.0.1' ? route.continue() : route.abort());
  const url=`http://127.0.0.1:${server.httpServer.address().port}/__supplier_test`;
  await page.goto(url);
  const row=page.getByRole('listitem').filter({has:page.getByText(/^Supplier-19 ·/)});
  await row.getByRole('button',{name:'supplierMutation.edit',exact:true}).click();
  const form=page.getByRole('form',{name:'supplierMutation.edit',exact:true});
  await form.waitFor();
  const box=await form.boundingBox();
  const focusInside=await form.evaluate(el=>el.contains(document.activeElement));
  console.log('Edit after lower-row click:',JSON.stringify({top:box.y,bottom:box.y+box.height,viewport:650,focusInside}));
  if(process.env.REPRO_ONLY==='1') {
    await form.getByRole('button',{name:'supplierMutation.close',exact:true}).click();
    await row.getByRole('button',{name:'supplierMutation.deactivate',exact:true}).click();
    const confirm=page.getByRole('button',{name:'supplierMutation.confirm',exact:true});
    console.log('Status confirmation after lower-row click:',JSON.stringify(await confirm.boundingBox()));
    assert.equal(errors.length,0,errors.join('\n'));
  } else {
    assert(box.y>=0 && box.y<650 && focusInside, 'Row Edit must reveal and focus its form, not silently open above the viewport');
    const editButton=row.getByRole('button',{name:'supplierMutation.edit',exact:true});
    const close=()=>form.getByRole('button',{name:'supplierMutation.close',exact:true}).click();
    const log=()=>page.evaluate(()=>structuredClone(window.slice6.log));
    const clearLog=()=>page.evaluate(()=>{window.slice6.log.length=0;});
    const panelVisible=async locator=>{
      const b=await locator.boundingBox();
      assert(b && b.y>=0 && b.y<650, 'Action panel must be in the viewport');
      assert(await locator.evaluate(el=>el.contains(document.activeElement)), 'Action panel must receive focus');
    };
    const assertOnlyParties=async()=>{
      const calls=await log();
      assert(calls.length>=2);
      assert(calls.every(call=>call.table==='parties'), JSON.stringify(calls));
      assert.equal(calls.filter(call=>call.kind==='read').length,1);
      assert.equal(calls.filter(call=>call.kind!=='read').length,1);
    };
    assert.equal(await form.locator('[name="name"]').inputValue(),'Supplier-19');
    assert.equal(await form.locator('[name="trn"]').inputValue(),'001234');
    await close();
    assert(await editButton.evaluate(el=>document.activeElement===el),'Close restores row focus');
    await editButton.focus(); await page.keyboard.press('Enter');
    await form.waitFor(); await panelVisible(form);
    await clearLog();
    await form.locator('[name="name"]').fill('Edited Supplier');
    await form.getByRole('button',{name:'supplierMutation.save',exact:true}).click();
    await form.waitFor({state:'detached'});
    assert(await row.textContent().then(text=>text.includes('Edited Supplier')));
    await assertOnlyParties();
    assert.deepEqual((await log())[0].filters,[['company_id','company-a'],['id','Supplier-19'],['type','SUPPLIER'],['updated_at','2026-09-13T00:00:00.123456+00:00']]);
    assert.equal((await log())[0].payload.name,'Edited Supplier');
    assert(!('updated_at' in (await log())[0].payload));
    for(const [action,status] of [['deactivate','INACTIVE'],['reactivate','ACTIVE']]) {
      await clearLog();
      await row.getByRole('button',{name:`supplierMutation.${action}`,exact:true}).click();
      const region=row.getByRole('region');
      await region.waitFor(); await panelVisible(region);
      assert.equal((await log()).length,0,'Opening status panel must not mutate');
      await region.getByRole('button',{name:'supplierMutation.close',exact:true}).click();
      assert.equal((await log()).length,0,'Cancelling status must not mutate');
      await row.getByRole('button',{name:`supplierMutation.${action}`,exact:true}).click();
      await row.getByRole('region').getByRole('button',{name:'supplierMutation.confirm',exact:true}).click();
      await row.getByRole('region').waitFor({state:'detached'});
      assert((await row.textContent()).includes(`partyStatus.${status}`));
      await assertOnlyParties();
      assert.deepEqual((await log())[0].payload,{status});
    }
    // Real form/provider/repository stale-token path, not a direct callback mock.
    await editButton.click(); await form.waitFor();
    await page.evaluate(()=>window.slice6.concurrentEdit('Supplier-19'));
    await clearLog();
    await form.getByRole('button',{name:'supplierMutation.save',exact:true}).click();
    await row.getByRole('alert').waitFor();
    assert((await row.getByRole('alert').textContent()).includes('supplierMutation.conflict'));
    assert.equal((await log()).length,1,'Conflict must not retry or refresh silently');
    assert(await form.locator('[name="name"]').isDisabled());
    await row.getByRole('button',{name:'supplierMutation.refresh',exact:true}).click();
    await form.waitFor({state:'detached'});
    await page.waitForFunction(()=>!document.querySelector('[role="alert"]'));
    // Pending duplicate prevention and committed-write/read-failure distinction.
    await editButton.click(); await form.waitFor();
    await page.evaluate(()=>{window.slice6.hold('update');window.slice6.fail('read');});
    await clearLog();
    await form.getByRole('button',{name:'supplierMutation.save',exact:true}).click();
    await page.waitForFunction(()=>document.querySelector('fieldset')?.disabled);
    assert.equal((await log()).filter(x=>x.kind==='update').length,1);
    await page.evaluate(()=>window.slice6.release());
    await row.getByRole('alert').waitFor();
    assert((await row.getByRole('alert').textContent()).includes('supplierMutation.refreshError'));
    await row.getByRole('button',{name:'supplierMutation.refresh',exact:true}).click();
    await form.waitFor({state:'detached'}); await page.waitForFunction(()=>!document.querySelector('[role="alert"]'));
    // Create still runs through real form -> provider -> repository -> Parties read.
    await page.getByRole('button',{name:'supplierMutation.create',exact:true}).click();
    const create=page.getByRole('form',{name:'supplierMutation.create',exact:true});
    await create.locator('[name="name"]').fill('Created through browser');
    await clearLog(); await create.getByRole('button',{name:'supplierMutation.save',exact:true}).click();
    await create.waitFor({state:'detached'}); await assertOnlyParties();
    const creation=(await log()).find(x=>x.kind==='insert');
    assert(!('type' in creation.payload));assert(!('status' in creation.payload));assert.equal(creation.payload.company_id,'company-a');
    const other=page.getByRole('listitem').filter({has:page.getByText('Other-row · Other-row',{exact:true})});
    assert.equal(await other.getByRole('button',{name:/^supplierMutation\./}).count(),0);
    assert.equal(await other.getByRole('button',{name:'otherPartyName.edit',exact:true}).count(),1);
    // Unchanged rerender/focus keeps draft and snapshot. No authority handler is replaced in production.
    await editButton.click(); await form.waitFor();
    await form.locator('[name="name"]').fill('Unsaved draft');await clearLog();
    await page.evaluate(()=>{window.slice6.change({});window.dispatchEvent(new Event('focus'));});
    assert.equal(await form.locator('[name="name"]').inputValue(),'Unsaved draft');assert.equal((await log()).length,0);
    // Role/Company/user/logout transitions while a real UI submission is pending.
    for(const patch of [{role:'MANAGEMENT_VIEWER'},{companyId:'company-b'},{userId:'user-b'},{signedIn:false}]) {
      await page.reload(); await row.waitFor(); await editButton.click(); await form.waitFor();
      await page.evaluate(()=>window.slice6.hold('update'));
      await form.getByRole('button',{name:'supplierMutation.save',exact:true}).click();
      await page.waitForFunction(()=>document.querySelector('fieldset')?.disabled);
      await page.evaluate(patch=>window.slice6.change(patch),patch);
      await form.waitFor({state:'detached'});
      await page.evaluate(()=>window.slice6.release());
      await page.waitForTimeout(80);
      assert.equal(await page.getByRole('alert').count(),0,'Old result cannot leak failure feedback');
      assert.equal(await page.getByText('supplierMutation.saved',{exact:true}).count(),0,'Old result cannot leak success feedback');
      if(patch.role) assert.equal(await page.getByRole('button',{name:'supplierMutation.edit',exact:true}).count(),0);
    }
    // Both allowed roles and every denied role, actual click-capable DOM.
    for(const role of ['ACCOUNTING_ADMIN','PROCUREMENT','ACCOUNTANT','DATA_ENTRY','MANAGEMENT_VIEWER','PROJECT_MANAGER','SYSTEM_ADMIN']) {
      await page.reload(); await row.waitFor();
      await page.evaluate(role=>window.slice6.change({role}),role);
      await row.waitFor();
      const allowed=['ACCOUNTING_ADMIN','PROCUREMENT'].includes(role);
      assert.equal(await row.getByRole('button',{name:'supplierMutation.edit',exact:true}).count(),allowed?1:0);
      if(allowed) {await editButton.click();await form.waitFor();assert.equal(await form.locator('[name="name"]').inputValue(),'Supplier-19');await close();}
    }
    // Narrow RTL layout must reveal both panels too.
    await page.reload(); await row.waitFor();await page.setViewportSize({width:390,height:650});
    await page.evaluate(()=>{document.documentElement.dir='rtl';});
    await editButton.click(); await form.waitFor();await panelVisible(form);await close();
    await row.getByRole('button',{name:'supplierMutation.deactivate',exact:true}).click();
    await row.getByRole('region').waitFor();await panelVisible(row.getByRole('region'));
    assert.equal(errors.length,0,errors.join('\n'));
    console.log('PASS: real row clicks/keyboard, populated edit/exact token, deactivate/reactivate, cancellation/focus, conflict/recovery, create, roles/types, scoped late results, Parties-only refresh and RTL viewport. In-memory transport only; no hosted fixture touched.');
  }
} finally { await browser?.close(); await server.close(); }
