import assert from 'node:assert/strict';
import {writeFileSync,readFileSync} from 'node:fs';
import {chromium} from 'playwright';
import {startPremiumCompletionServer} from './premium-completion-server.mjs';
const out='/tmp/narvo-data-workspace-verification',checks=process.env.DATA_WORKSPACE_FINAL_RESUME?JSON.parse(readFileSync('/tmp/narvo-data-workspace-verification/final-failure.json','utf8')).checks:[],errors=[];
const {server,base}=await startPremiumCompletionServer(out+'/snapshot.json');
const browser=await chromium.launch({headless:true,executablePath:'/usr/bin/google-chrome'}),page=await browser.newPage();
page.setDefaultTimeout(45000);page.setDefaultNavigationTimeout(120000);
page.on('pageerror',e=>errors.push(e.message));await page.route('**/*',r=>r.request().url().startsWith(base)?r.continue():r.abort());
const check=(ok,label)=>{assert(ok,label);checks.push(label);console.log('PASS',label);};
try{
 for(const route of (process.env.DATA_WORKSPACE_FINAL_RESUME?['/financial-evidence','/accounting-cycle']:['/subcontracts','/expenses','/expense-categories','/inventory/balances','/financial-evidence','/accounting-cycle'])){
  for(const language of ['en','ar']){
   await page.goto(base+route,{waitUntil:'domcontentloaded'});await page.locator('.company-workspace').waitFor();
   const toggle=page.getByRole('button',{name:language==='ar'?'العربية':'English',exact:true});if(await toggle.count())await toggle.click();
   if(route==='/expenses')await page.getByRole('link',{name:language==='en'?'Posted expenses':'المصروفات المرحلة',exact:true}).click();
   if(route==='/financial-evidence'){await page.getByRole('button',{name:language==='en'?'Refresh evidence':'تحديث الأدلة',exact:true}).click();await page.getByRole('button',{name:language==='en'?'Refresh financial register':'تحديث السجل المالي',exact:true}).click();}
   await page.waitForTimeout(250);
   const table=page.locator('table:visible').first();if(route==='/accounting-cycle'){check((await page.locator('main').innerText()).length>100,language+' accounting cycle overview remains available');for(const [width,height] of [[1366,768],[1920,1080],[390,844]]){await page.setViewportSize({width,height});check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),language+' cycle bounded '+width);}continue;}await table.waitFor();
   check(await table.locator('tbody tr').count()>0,language+' '+route+' final populated register');
   for(const [size,width,height] of [['laptop',1366,768],['desktop',1920,1080],['mobile',390,844]]){
    await page.setViewportSize({width,height});await table.scrollIntoViewIfNeeded();
    check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),language+' '+route+' '+size+' bounded horizontal page');
    check(await page.locator('.dw-table-viewport:visible').evaluateAll(nodes=>nodes.every(e=>e.scrollHeight<=e.clientHeight+2)),language+' '+route+' '+size+' natural vertical scrolling');
    if(['/subcontracts','/expenses'].includes(route)){
     await page.screenshot({path:out+'/'+language+'-'+route.slice(1)+'-final-'+size+'.png'});
     if(route==='/subcontracts'){
      const region=table.locator('..');await region.evaluate(e=>e.scrollLeft=getComputedStyle(e).direction==='rtl'?-e.scrollWidth:e.scrollWidth);await page.screenshot({path:out+'/'+language+'-subcontracts-financial-'+size+'.png'});
     }
    }
   }
   check(await page.evaluate(()=>window.premiumFixture.commands.length===0),language+' '+route+' no financial mutations');
  }
 }
 check(!errors.length,'No final changed-state runtime errors');
 writeFileSync(out+'/final.json',JSON.stringify({status:'PASS',checks,errors,financialWrites:0},null,2));
}catch(error){await page.screenshot({path:out+'/final-failure.png'});writeFileSync(out+'/final-failure.json',JSON.stringify({error:error.message,checks,errors,body:await page.locator('body').innerText()},null,2));console.error(error);process.exitCode=1;}
finally{await browser.close();await server.close();}
