import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync,readFileSync} from 'node:fs';
import {startEmeraldServer} from './fixtures/emerald-server.mjs';
const out='/tmp/narvo-premium-ui';mkdirSync(out,{recursive:true});
const {server,base,mutations}=await startEmeraldServer('after');
const suite=process.argv[2]??'all';
const result={suite,checks:[],errors:[],external:[],scans:[]};let browser;
const check=(v,label)=>{assert(v,label);result.checks.push(label)};
try {
 browser=await chromium.launch({headless:true});const ctx=await browser.newContext({serviceWorkers:'block',reducedMotion:'reduce'});
 await ctx.route('**/*',r=>new URL(r.request().url()).origin===base?r.continue():(result.external.push('blocked external request'),r.abort()));
 const page=await ctx.newPage();page.setDefaultNavigationTimeout(90000);page.setDefaultTimeout(60000);page.on('pageerror',e=>result.errors.push(e.message));
 await page.setViewportSize({width:1366,height:768});await page.goto(base+(suite==='onboarding'?'/platform/onboarding':'/projects'),{waitUntil:'domcontentloaded'});await page.locator(suite==='onboarding'?'main':'.record-identity').first().waitFor();
 check(await page.evaluate(()=>document.documentElement.dataset.theme)==='emerald','Default Signature Emerald');
 if(!['mobile','desktop','onboarding'].includes(suite)){
 for(const name of ['Royal Sapphire','Executive Graphite','Warm Champagne','Modern Teal','Signature Emerald']) {
  await page.locator('.theme-selector>summary').click();await page.getByRole('radio',{name,exact:true}).check();
  const color=await page.evaluate(()=>getComputedStyle(document.documentElement).getPropertyValue('--erp-primary').trim());
  check(color===({'Royal Sapphire':'#315DB4','Executive Graphite':'#485461','Warm Champagne':'#86652D','Modern Teal':'#087D89','Signature Emerald':'#087E68'})[name],name+' applies immediately');
  await page.keyboard.press('Escape');check(await page.locator('.theme-selector>summary').evaluate(e=>e===document.activeElement),'Escape restores focus');
  await page.addScriptTag({content:readFileSync('/tmp/narvo-owner-redesign-tools/node_modules/axe-core/axe.min.js','utf8')});
  const themeScan=await page.evaluate(()=>window.axe.run(document,{runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21aa']}}));
  result.scans.push({theme:name,violations:themeScan.violations.map(v=>({id:v.id,nodes:v.nodes.map(n=>({target:n.target,summary:n.failureSummary}))})),incomplete:themeScan.incomplete.map(v=>v.id)});

 }
 await page.locator('.theme-selector>summary').click();await page.getByRole('radio',{name:'Royal Sapphire',exact:true}).focus();await page.keyboard.press('ArrowDown');
 check(await page.getByRole('radio',{name:'Executive Graphite',exact:true}).isChecked(),'Native radio arrow-key selection');await page.keyboard.press('Escape');await page.reload();await page.locator('.record-identity').first().waitFor();
 check(await page.evaluate(()=>document.documentElement.dataset.theme)==='graphite','Preference restored after reload');
 await page.goto(base+'/platform/onboarding',{waitUntil:'domcontentloaded'});await page.locator('.theme-selector').waitFor();check(await page.evaluate(()=>document.documentElement.dataset.theme)==='graphite','Preference shared with Platform Console');
 await page.locator('.theme-selector>summary').click();await page.getByRole('radio',{name:'Signature Emerald',exact:true}).check();await page.keyboard.press('Escape');
 }
 for(const [route,width,locale] of [['/projects',1366,'en'],['/parties?employees=1',1440,'en'],['/expenses',1920,'en'],['/subcontracts',1024,'en'],['/',1440,'en'],['/attendance',1440,'en'],['/payroll',1440,'en'],['/accounting-reports',1440,'en'],['/platform/onboarding',1440,'en'],['/projects',390,'ar'],['/parties?employees=1',390,'ar'],['/expenses',390,'ar'],['/platform/onboarding',390,'ar']].filter(([r,w])=>suite==='onboarding'?r==='/platform/onboarding'&&w===1440:suite==='themes'?false:suite==='mobile'?w<600:suite==='desktop'?w>=600:true)) {
  await page.setViewportSize({width,height:900});await page.goto(base+route,{waitUntil:'domcontentloaded'});await page.locator('main').waitFor();await page.waitForTimeout(350);
  if(await page.evaluate(()=>document.documentElement.lang)!==locale)await page.getByRole('button',{name:locale==='ar'?'العربية':'English',exact:true}).click();
  check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),route+' '+width+' '+locale+' no page overflow');
  check(await page.locator('main').innerText().then(s=>s.length>50),route+' real module rendered');
  if(route.startsWith('/projects')||route.startsWith('/parties'))check(await page.locator('.record-identity h3').first().evaluate(e=>parseFloat(getComputedStyle(e).fontSize)>=20),route+' strong record hierarchy');
  if(['/projects','/parties?employees=1','/platform/onboarding'].includes(route)) {
    await page.addScriptTag({content:readFileSync('/tmp/narvo-owner-redesign-tools/node_modules/axe-core/axe.min.js','utf8')});
    const a=await page.evaluate(()=>window.axe.run(document.querySelector('main'),{runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21aa']}}));result.scans.push({route,width,locale,violations:a.violations.map(v=>({id:v.id,nodes:v.nodes.map(n=>({target:n.target,summary:n.failureSummary}))})),incomplete:a.incomplete.map(v=>v.id)});
  }
  await page.screenshot({path:out+'/'+route.split('?')[0].replaceAll('/','_')+'-'+width+'-'+locale+'.png',fullPage:true});
  if(await page.evaluate(()=>!!window.dashboardTest))check(await page.evaluate(()=>window.dashboardTest.mutations.length)===0,'No financial commands '+route);
  console.log('Checked',route,width,locale);
 }
 check(result.errors.length===0,'No runtime errors');check(result.external.length===0,'No external requests');check(mutations.length===0,'No platform commands');
 check(result.scans.every(s=>s.violations.length===0),'Focused accessibility scans');result.status='PASS';
} catch(e){result.status='FAIL';result.error=e.stack;process.exitCode=1;console.error(e.stack)}finally {writeFileSync(out+'/result-'+suite+'.json',JSON.stringify(result,null,2));await browser?.close();await server.close();}
