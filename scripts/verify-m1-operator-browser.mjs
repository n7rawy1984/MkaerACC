import assert from 'node:assert/strict';
import {createServer} from 'vite';
import react from '@vitejs/plugin-react';
import {chromium} from 'playwright';
import {resolve} from 'node:path';
import {mkdir,writeFile} from 'node:fs/promises';
const root=resolve(import.meta.dirname,'..'),out='/tmp/narvo-m1';await mkdir(out,{recursive:true});
const server=await createServer({root,configFile:false,plugins:[{name:'m1-isolated-transport',load(id){if(id===resolve(root,'src/lib/supabase.ts'))return 'export const getSupabaseClient=()=>window.m1.client';if(id===resolve(root,'src/auth/AuthContext.tsx'))return 'export const useAuth=()=>({state:{phase:"TENANT_READY",profile:{userId:window.m1.user},activeTenant:{companyId:window.m1.company,role:window.m1.role}}})';if(id===resolve(root,'src/master/productionMasterDataContext.ts'))return 'export const useProductionMasterData=()=>window.m1.master';if(id===resolve(root,'src/master/SubcontractCreationPanel.tsx'))return 'export const SubcontractCreationPanel=()=>null';},configureServer(s){s.middlewares.use('/__m1',async(_q,r)=>{r.setHeader('Content-Type','text/html');r.end(await s.transformIndexHtml('/__m1','<html><head><meta name="viewport" content="width=device-width, initial-scale=1"></head><body><div id="root"></div><script type="module" src="/scripts/fixtures/m1-operator-correctness.tsx"></script></body></html>'));});}},react()],server:{host:'127.0.0.1',port:0},logLevel:'error'});
let browser;const checks=[];const check=(v,label)=>{assert(v,label);checks.push(label);};
try{
 await server.listen();browser=await chromium.launch({headless:true});const page=await browser.newPage({viewport:{width:1440,height:1000}});const errors=[];page.on('pageerror',e=>errors.push(e.message));await page.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());await page.goto(`http://127.0.0.1:${server.httpServer.address().port}/__m1`);await page.getByRole('dialog').waitFor();
 if(process.argv.includes('--diagnose')){const save=page.locator('button[type=submit]');console.log(JSON.stringify({button:await save.innerText(),styles:await save.evaluate(e=>({foreground:getComputedStyle(e).color,background:getComputedStyle(e).backgroundColor,classes:e.className})),nativeDate:await page.locator('input[type=date]').inputValue()}));await page.screenshot({path:out+'/before-save.png',fullPage:true});}
 else {
 const view=async name=>{await page.evaluate(v=>{window.m1.view=v;window.m1.render();},name);await page.locator(name==='edit'?'[role=dialog]':name==='expense'?'form':'ul').first().waitFor();};
 const locale=async l=>{await page.evaluate(l=>window.m1.locale(l),l);await page.waitForFunction(l=>document.documentElement.lang===l,l);};
 const contrast=async locator=>locator.evaluate(e=>{const rgb=s=>s.match(/[\d.]+/g).slice(0,3).map(Number).map(v=>{v/=255;return v<=0.04045?v/12.92:((v+0.055)/1.055)**2.4;});const lum=s=>rgb(s).reduce((n,v,i)=>n+v*[0.2126,0.7152,0.0722][i],0);const c=getComputedStyle(e),a=lum(c.color),b=lum(c.backgroundColor);return (Math.max(a,b)+0.05)/(Math.min(a,b)+0.05);});
 for(const l of ['en','ar']){
  await locale(l);await view('subcontracts');
  check(await page.getByText('65,000.00 AED',{exact:true}).count()===1,l+': contract value converted to exact AED');
  check(await page.getByText('-1.05 AED',{exact:true}).count()===1,l+': signed variation converted to AED');
  await page.screenshot({path:out+`/subcontracts-${l}.png`,fullPage:true});
  check(await page.evaluate(()=>window.m1.master.subcontracts[0].originalContractValueMinor)==='6500000',l+': original storage unchanged');
  await page.evaluate(()=>{window.m1.master.subcontracts[0].originalContractValueMinor='9007199254740993';window.m1.render();});await page.getByText('90,071,992,547,409.93 AED',{exact:true}).waitFor();check(true,l+': large exact AED browser display');
  await page.evaluate(()=>{window.m1.master.subcontracts[0].originalContractValueMinor='6500000';});
  await view('edit');const evidence=page.getByRole('region',{name:l==='ar'?'أدلة التاريخ':'Date evidence'});
  await evidence.waitFor();await evidence.screenshot({path:out+`/date-evidence-${l}.png`});check((await evidence.innerText()).includes('2026-08-01'),l+': explicit ISO evidence');
  check(await page.locator('input[type=date]').inputValue()==='2026-08-01',l+': native picker ISO stays August1');
  await page.locator('input[type=date]').fill('2026-01-08');check((await evidence.innerText()).includes('2026-01-08'),l+': selected January8 preview changes without reinterpreting imported date');
  check(await page.evaluate(()=>window.m1.row.source_date)==='2026-08-01',l+': imported original unchanged while editing');
  const save=page.getByRole('button',{name:l==='ar'?'حفظ التعديلات':'Save changes',exact:true});
  for(const width of [1440,390])for(const zoom of [1,1.25,2]){
   await page.setViewportSize({width,height:1000});await page.evaluate(z=>document.documentElement.style.zoom=String(z),zoom);await save.scrollIntoViewIfNeeded();
   check(await save.isVisible()&&(await save.innerText()).trim().length>0,`${l}/${width}/${zoom}: visible labelled save action`);
   check(await contrast(save)>=4.5,`${l}/${width}/${zoom}: save contrast >=4.5`);
   check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),`${l}/${width}/${zoom}: no document overflow`);
  }
  await page.evaluate(()=>document.documentElement.style.zoom='1');await page.screenshot({path:out+`/save-${l}-390.png`,fullPage:true});
  check(await page.evaluate(()=>window.m1.calls.length)===0,l+': presentation and editing alone make no RPC');
 }
 await locale('en');await page.setViewportSize({width:1440,height:1000});
 await page.evaluate(()=>{window.m1.failure=true;window.m1.hold=true;});
 await page.getByRole('button',{name:'Save changes',exact:true}).click();const busy=page.getByRole('button',{name:'Saving changes…',exact:true});await busy.waitFor();
 check(await busy.isDisabled(),'saving action disabled during outstanding request');check(await busy.getAttribute('aria-busy')==='true','saving exposes busy semantics');
 await page.waitForFunction(()=>!!window.m1.release);await page.evaluate(()=>window.m1.release());await page.getByRole('alert').waitFor();
 check(await page.getByRole('button',{name:'Save changes',exact:true}).isEnabled(),'failed save restores explicit action');
 const call=await page.evaluate(()=>window.m1.calls[0]);check(call.name==='complete_historical_source','save still uses existing source-review RPC');check(call.args.details.date==='2026-01-08','save sends exact picker ISO with no date reinterpretation');check(call.args.expected_updated_at==='2026-10-08T00:00:00Z','existing optimistic version guard retained');
 check(await page.evaluate(()=>window.m1.row.source_date)==='2026-08-01','failed save leaves imported original intact');
 await page.evaluate(()=>{window.m1.failure=false;window.m1.hold=false;});await page.getByRole('button',{name:'Save changes',exact:true}).click();await page.getByText('Closed',{exact:true}).waitFor();
 check(await page.evaluate(()=>window.m1.calls.length)===2,'one explicit success after known failure; no automatic save retry');
 check(await page.evaluate(()=>window.m1.calls.every(x=>x.name==='complete_historical_source')),'source saves never invoke posting');
 await page.evaluate(()=>{window.m1.row.completion.date='08/01/2026';});await view('edit');
 check((await page.getByRole('region',{name:'Date evidence'}).innerText()).includes('Ambiguous or invalid date; verify source'),'slash-date review value visibly unresolved, never guessed');
 check(await page.evaluate(()=>window.m1.row.completion.date)==='08/01/2026','ambiguous saved evidence preserved');
 await page.evaluate(()=>{delete window.m1.row.completion.date;window.m1.role='MANAGEMENT_VIEWER';window.m1.render();});
 check(await page.locator('button[type=submit]').count()===0,'viewer has no source save control');
 await page.evaluate(()=>{window.m1.role='ACCOUNTING_ADMIN';});
 for(const l of ['en','ar']){await view('expense');await locale(l);const post=page.getByRole('button',{name:l==='ar'?'ترحيل المصروف':'Post expense',exact:true});await post.waitFor();await post.scrollIntoViewIfNeeded();await page.screenshot({path:out+`/new-expense-${l}.png`,fullPage:true});check(await contrast(post)>=4.5,l+': Post expense action has readable contrast');check(await post.getAttribute('aria-label')===await post.innerText(),l+': post visible and accessible names match');check((await page.locator('form').innerText()).includes(l==='ar'?'ولا يحفظ مسودة مستقلة':'does not save a separate draft'),l+': posting is distinguished from saving review');}
 check(await page.evaluate(()=>window.m1.calls.every(x=>x.name==='complete_historical_source')),'New Expense inspection invokes no financial command');
 // Browser locale/timezone cannot change explicit ISO preview or native value.
 for(const config of [{locale:'en-US',timezoneId:'America/Los_Angeles'},{locale:'en-GB',timezoneId:'Asia/Dubai'}]){const context=await browser.newContext(config);const p=await context.newPage();await p.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());await p.goto(page.url());await p.locator('input[type=date]').waitFor();check(await p.locator('input[type=date]').inputValue()==='2026-08-01',config.locale+': native value remains ISO');check((await p.getByRole('region',{name:'Date evidence'}).innerText()).includes('2026-08-01 · 01 August 2026'),config.locale+': date evidence is timezone-stable');await context.close();}
 console.log(`PASS: ${checks.length} M1 browser assertions; EN/AR, 1440/390,125%/200%, money/date/actions, source-save payload/error/busy and preserved posting distinction.`);
 }
 assert.equal(errors.length,0,errors.join(';'));await writeFile(out+'/browser-result.json',JSON.stringify({status:'PASS',assertions:checks.length,checks,errors,hosted:false},null,2));
}finally{await browser?.close();await server.close();}
