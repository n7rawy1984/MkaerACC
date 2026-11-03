import {chromium} from 'playwright';
import {readFileSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import assert from 'node:assert/strict';
const out='docs/release/enterprise-theme-comparison';
const browser=await chromium.launch({headless:true});const errors=[],external=[],checks=[];
try{
const page=await browser.newPage({viewport:{width:1440,height:1000}});page.on('pageerror',e=>errors.push(e.message));await page.route('**/*',r=>r.request().url().startsWith('file:')?r.continue():(external.push(r.request().url()),r.abort()));
await page.goto('file://'+resolve(out,'index.html'));await page.locator('#image-a').waitFor();
const check=(v,label)=>{assert(v,label);checks.push(label);};
await page.selectOption('#screen','expenses');await page.selectOption('#layout','ar-mobile');
for(const k of ['a','b','c'])check((await page.locator('#image-'+k).getAttribute('src'))===`screenshots/expenses-ar-mobile-${k}.png`,'Equivalent screen and layout '+k);
await page.locator('[data-pick=b]').click();check(await page.locator('#card-b').getAttribute('data-emphasis')==='true','Highlight theme B');check(await page.locator('#screen').inputValue()==='expenses','Highlight preserves context');
await page.locator('[data-zoom=a]').click();await page.locator('[data-zoom-theme=c]').click();check((await page.locator('#zoom-image').getAttribute('src')).endsWith('expenses-ar-mobile-c.png'),'Full-size switch preserves context');
await page.keyboard.press('Escape');check(await page.locator('#zoom').evaluate(e=>!e.open),'Escape closes dialog');check(await page.locator('[data-zoom=a]').evaluate(e=>document.activeElement===e),'Focus restored');
await page.addScriptTag({content:readFileSync('/tmp/narvo-owner-redesign-tools/node_modules/axe-core/axe.min.js','utf8')});const scans=[];
for(const width of [1440,390]){await page.setViewportSize({width,height:1000});check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),'Gallery no horizontal overflow '+width);const a=await page.evaluate(()=>window.axe.run(document,{runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21aa','wcag22aa']}}));scans.push({width,violations:a.violations.map(v=>({id:v.id,impact:v.impact,nodes:v.nodes.map(n=>({target:n.target,summary:n.failureSummary}))})),incomplete:a.incomplete.map(v=>({id:v.id,nodes:v.nodes.length}))});}
await page.setViewportSize({width:1440,height:1000});await page.selectOption('#screen','onboarding-ready-active');await page.selectOption('#layout','en-desktop');await page.screenshot({path:out+'/gallery-preview.png',fullPage:false});
check(errors.length===0,'No gallery runtime errors');check(external.length===0,'No external gallery requests');writeFileSync(out+'/gallery-diagnostic.json',JSON.stringify(scans,null,2)+'\n');check(scans.every(s=>s.violations.length===0),'Gallery scoped axe scans have no violations');
writeFileSync(out+'/gallery-verification.json',JSON.stringify({status:'PASS',checks,scans,errors,external},null,2)+'\n');console.log('Gallery PASS',checks.length,'checks',scans.length,'axe scans');
}finally{await browser.close();}
