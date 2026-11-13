// Synthetic actual Production components, local-only screenshot evidence.
import {chromium} from 'playwright';
import {startPremiumCompletionServer} from './premium-completion-server.mjs';
const out='/tmp/narvo-data-workspace-verification';
const {server,base}=await startPremiumCompletionServer(out+'/snapshot.json');
const browser=await chromium.launch({headless:true,executablePath:'/usr/bin/google-chrome'}),page=await browser.newPage({viewport:{width:1920,height:1080}});
page.setDefaultNavigationTimeout(120000);await page.route('**/*',r=>r.request().url().startsWith(base)?r.continue():r.abort());
try{for(const lang of ['en','ar'])for(const route of ['/subcontracts','/expenses']){
 await page.goto(base+route,{waitUntil:'domcontentloaded'});await page.locator('.company-workspace').waitFor();
 const toggle=page.getByRole('button',{name:lang==='ar'?'العربية':'English',exact:true});if(await toggle.count())await toggle.click();
 const table=page.locator('table:visible').first();await table.waitFor();await table.scrollIntoViewIfNeeded();
 await page.screenshot({path:out+'/'+lang+'-'+route.slice(1)+'-publication.png'});
 if(route==='/subcontracts'){
  await page.setViewportSize({width:390,height:844});await table.scrollIntoViewIfNeeded();const viewport=table.locator('..');
  await viewport.evaluate(e=>e.scrollLeft=getComputedStyle(e).direction==='rtl'?-e.scrollWidth:e.scrollWidth);
  if(!await viewport.evaluate(e=>Math.abs(e.scrollLeft)>0))throw Error('Horizontal table scroll did not move');
  await page.screenshot({path:out+'/'+lang+'-subcontracts-mobile-financial-final.png'});await page.setViewportSize({width:1920,height:1080});
 }else{await page.getByRole('link',{name:lang==='ar'?'المصروفات المرحلة':'Posted expenses',exact:true}).click();await table.scrollIntoViewIfNeeded();await page.screenshot({path:out+'/'+lang+'-expenses-posted-publication.png'});}
 if(await page.evaluate(()=>window.premiumFixture.commands.length))throw Error('Unexpected mutation');
}console.log('PASS final synthetic EN/AR screenshots and real RTL/LTR horizontal table movement');}finally{await browser.close();await server.close();}
