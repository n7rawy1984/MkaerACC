import assert from 'node:assert/strict';
import {createServer} from 'vite';
import react from '@vitejs/plugin-react';
import {chromium} from 'playwright';
import {resolve} from 'node:path';
import {mkdir,writeFile,readFile} from 'node:fs/promises';
const root=resolve(import.meta.dirname,'..'),evidence='/tmp/maker-demo-presentation';
await mkdir(evidence,{recursive:true});
const server=await createServer({root,configFile:false,plugins:[{name:'isolated-presentation',load(id){
 if(id===resolve(root,'src/auth/AuthContext.tsx'))return 'export const useAuth=()=>window.demoPresentation.auth;';
 if(id===resolve(root,'src/lib/supabase.ts'))return 'export const getSupabaseClient=()=>window.demoPresentation.client;';
 const match=id.match(/\/financial\/(use\w+Read)\.ts$/);if(match)return `export const ${match[1]}=()=>window.demoPresentation.empty;`;
},configureServer(s){s.middlewares.use('/__presentation',async(_req,res)=>{res.setHeader('Content-Type','text/html');res.end(await s.transformIndexHtml('/__presentation','<html><body><div id="root"></div><script type="module" src="/scripts/fixtures/demo-presentation.tsx"></script></body></html>'));});}},react()],server:{host:'127.0.0.1',port:0,hmr:false},logLevel:'error'});
let browser;
const results=[];
try{
 await server.listen();browser=await chromium.launch({headless:true});const page=await browser.newPage();const errors=[];
 page.on('pageerror',e=>errors.push(e.message));page.on('console',m=>{if(m.type()==='error')errors.push(m.text());});
 await page.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());
 const url=`http://127.0.0.1:${server.httpServer.address().port}/__presentation`;
 await page.goto(url);const controls=page.getByTestId('fixture-controls');
 async function view(name){await controls.getByRole('button',{name,exact:true}).click();await page.waitForTimeout(100);assert.equal(errors.length,0,errors.join('\n'));}
 async function direction(locale,width){await page.setViewportSize({width,height:900});await controls.getByRole('button',{name:locale==='ar'?'AR':'EN',exact:true}).click();assert.equal(await page.locator('html').getAttribute('lang'),locale);assert.equal(await page.locator('html').getAttribute('dir'),locale==='ar'?'rtl':'ltr');}
 const views=['projects','companyProfile','parties','expenseCategories','accounts','treasuryAccounts','subcontracts','expenses','supplierPayments','subcontractorAdvances','subcontractorCertificates','subcontractorPayments','retentionReleases','retentionPayments','attendance','payroll','login','select','noCompany','retry','sidebar'];
 for(const locale of ['en','ar'])for(const width of [1440,390]){
  await direction(locale,width);
  for(const name of views){await view(name);
   if(['expenses','supplierPayments','subcontractorAdvances','subcontractorCertificates','subcontractorPayments','retentionReleases','retentionPayments'].includes(name)){
    const selects=page.locator('main select');for(const select of await selects.all()){if(await select.locator('option').count()>1)await select.selectOption({index:1});}
    const reverse=page.locator('main').getByRole('button',{name:locale==='ar'?/^عكس/:/^Reverse/}).first();if(await reverse.count())await reverse.click();
   }
   if(name==='payroll'){
    await page.getByRole('button',{name:locale==='ar'?'سجل المسودة':'Draft Register',exact:true}).click();await page.locator('input[type=month]').waitFor();await page.locator('input[type=month]').fill('2026-08');await page.waitForTimeout(100);
    await page.getByText('SAL-0007',{exact:true}).waitFor();assert.equal(await page.locator('input[name=reference]').getAttribute('dir'),'ltr');
   }
   const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth+1);
   assert(!overflow,`${locale}/${width}/${name} overflows`);
   const technical=page.locator('input[dir=ltr]');for(const input of await technical.all())assert.equal(await input.evaluate(e=>getComputedStyle(e).direction),'ltr');
   const logo=page.locator('img[alt=Maker]').first();if(await logo.count()){assert(await logo.evaluate(e=>e.complete&&e.naturalWidth===768));assert.equal(await logo.evaluate(e=>getComputedStyle(e).objectFit),'contain');}
   if(name==='login'){assert.equal(await page.locator('input[type=email]').getAttribute('dir'),'ltr');}
   if(name==='projects'&&locale==='ar'){assert.equal(await page.locator('header p').first().evaluate(e=>getComputedStyle(e).letterSpacing),'normal');}
   results.push({locale,width,view:name,result:'PASS'});
  }
  await view('expenses');await page.screenshot({path:`${evidence}/${locale}-${width}-expenses.png`,fullPage:true});
  await controls.getByRole('button',{name:'modal',exact:true}).click();await page.getByText('تأكيد الإجراء',{exact:true}).waitFor();assert.equal(await page.getByText('تأكيد الإجراء',{exact:true}).evaluate(e=>getComputedStyle(e).direction),locale==='ar'?'rtl':'ltr');
  await page.getByRole('button',{name:locale==='ar'?'إغلاق':'Close',exact:true}).click();
  await view('print');await page.getByRole('button',{name:locale==='ar'?'طباعة / حفظ PDF':'Print / Save PDF',exact:true}).click();const dialog=page.getByRole('dialog');await dialog.waitFor();
  assert.equal(await dialog.getAttribute('dir'),locale==='ar'?'rtl':'ltr');assert.equal(await page.locator('tbody td').nth(1).textContent(),'0007');assert.equal(await page.locator('tbody td').nth(12).textContent(),'1234.56');
  const first=await page.locator('thead th').first().boundingBox(),last=await page.locator('thead th').last().boundingBox();assert(locale==='ar'?first.x>last.x:first.x<last.x);
  assert.equal(await page.locator('tbody td').nth(1).locator('bdi').getAttribute('dir'),'ltr');assert.equal(await page.locator('.payroll-register-reference bdi').getAttribute('dir'),'ltr');
  assert(await dialog.locator('img[alt=Maker]').evaluate(e=>e.complete&&e.naturalWidth===768));
  await page.screenshot({path:`${evidence}/${locale}-${width}-register.png`,fullPage:true});
  await page.emulateMedia({media:'print'});const pdf=await page.pdf({preferCSSPageSize:true,path:`${evidence}/${locale}-${width}-register.pdf`});const box=pdf.toString('latin1').match(/\/MediaBox\s*\[0 0 ([\d.]+) ([\d.]+)\]/);assert(box);assert(Math.abs(Number(box[1])-841.89)<1&&Math.abs(Number(box[2])-595.28)<1);
  assert.equal(await page.locator('thead').evaluate(e=>getComputedStyle(e).display),'table-header-group');assert.equal(await page.locator('.payroll-register-controls').isVisible(),false);
  await page.emulateMedia({media:'screen'});await page.getByRole('button',{name:locale==='ar'?'إغلاق':'Close',exact:true}).click();
 }
 // Local preference and tenant presentation provider survive fixture reload; hosted login is deferred.
 await page.reload();await page.locator('img[alt=Maker]').waitFor();assert.equal(await page.title(),'Maker');assert.equal(await page.locator('html').getAttribute('dir'),'rtl');
 const calls=await page.evaluate(()=>window.demoPresentation.calls);assert(calls.every(n=>n.startsWith('read_')||['attendance_context','attendance_day','attendance_month'].includes(n)));
 const ar=await readFile(resolve(root,'src/i18n/ar.ts'),'utf8');assert(!/[\u202a-\u202e\u2066-\u2069]/u.test(ar));
 await writeFile(`${evidence}/results.json`,JSON.stringify({results,print:'EN/AR A4 landscape, LTR ID/amount, logical column order, exact 1234.56',consoleErrors:errors,hosted:'DEFERRED',externalRequests:'blocked'},null,2));
 console.log(`Presentation PASS: ${results.length} screen/locale/viewport checks; isolated tenant branding, refresh, forms, sidebar, modal, bidi and A4 print. Evidence: ${evidence}`);
}finally{await browser?.close();await server.close();}
