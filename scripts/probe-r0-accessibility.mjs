// Read-only synthetic UI probes for incomplete axe groups; never submits forms.
import {chromium} from 'playwright';
import {readFileSync,writeFileSync} from 'node:fs';
import {startEmeraldServer} from './fixtures/emerald-server.mjs';
const out='docs/release/r0-production-impact/';
const result={probes:[],external:[],errors:[]};
const {server,base,mutations}=await startEmeraldServer('after');let browser;
try {
 browser=await chromium.launch({headless:true});const ctx=await browser.newContext({reducedMotion:'reduce',serviceWorkers:'block'});
 await ctx.route('**/*',q=>new URL(q.request().url()).origin===base?q.continue():(result.external.push(q.request().url()),q.abort()));
 const page=await ctx.newPage();page.on('pageerror',e=>result.errors.push(e.message));
 for(const ar of [false,true]) {
  await page.setViewportSize({width:ar?390:1440,height:ar?844:1000});
  async function go(path) {await page.goto(base+path);await page.locator('main').waitFor();await page.waitForTimeout(600);if(await page.evaluate(()=>document.documentElement.dir==='rtl')!==ar)await page.getByRole('button',{name:ar?'العربية':'English',exact:true}).click();await page.evaluate(()=>document.fonts.ready);}
  await go('/expenses');const region=page.locator('.suite-table-region:has(tbody tr:nth-child(25))').first();
  const scroll=await region.evaluate(e=>({tabIndex:e.tabIndex,role:e.getAttribute('role'),label:e.getAttribute('aria-label'),overflowX:getComputedStyle(e).overflowX,overflowY:getComputedStyle(e).overflowY,scrollHeight:e.scrollHeight,clientHeight:e.clientHeight}));
  await region.focus();await page.keyboard.press('End');await page.keyboard.press('ArrowDown');await page.waitForTimeout(150);
  scroll.keyboardFocused=await region.evaluate(e=>document.activeElement===e);scroll.afterKeyboard=await region.evaluate(e=>e.scrollTop);
  const samples=[];for(const index of [0,24,49]) {const cell=region.locator('tbody tr').nth(index).locator('td').first();await cell.scrollIntoViewIfNeeded();samples.push(await cell.evaluate(e=>{const r=e.getBoundingClientRect(),p=e.closest('.suite-table-region').getBoundingClientRect();return {text:e.textContent?.trim().slice(0,60),withinScrollViewport:r.bottom>p.top&&r.top<p.bottom&&r.right>p.left&&r.left<p.right,color:getComputedStyle(e).color};}));}
  await page.screenshot({path:out+`expense-scroll-${ar?'ar-mobile':'en-desktop'}.png`,fullPage:false});
  result.probes.push({key:'expenses',ar,scroll,samples});
  await go('/payroll');await page.locator('main details>summary').first().click();await page.locator('main details>summary').first().click();
  await page.addScriptTag({content:readFileSync('/tmp/narvo-owner-redesign-tools/node_modules/axe-core/axe.min.js','utf8')});
  const scan=await page.evaluate(()=>window.axe.run(document.querySelector('main'),{runOnly:{type:'rule',values:['color-contrast','th-has-data-cells']}}));
  result.probes.push({key:'payroll-menu-closed',ar,violations:scan.violations.map(x=>x.id),incomplete:scan.incomplete.map(x=>({id:x.id,nodes:x.nodes.length}))});
  await go('/expenses?empty=1');result.probes.push({key:'empty-tables',ar,tables:await page.locator('main table').evaluateAll(es=>es.map(e=>({rows:e.tBodies[0]?.rows.length,headers:e.tHead?.textContent?.trim().slice(0,120)}))),messages:await page.locator('main').innerText()});
  if(!ar){await go('/platform/subscriptions');await page.locator('.platform-row-actions button').last().click();
   const help=await page.locator('dialog p.platform-wide').first().evaluate(e=>{const range=document.createRange();range.selectNodeContents(e);return {text:e.textContent,lines:[...range.getClientRects()].map(r=>{const x=Math.max(0,Math.min(innerWidth-1,r.x+r.width/2)),y=r.y+r.height/2,hit=document.elementFromPoint(x,y);return {x,y,unobstructed:hit===e||e.contains(hit),hit:hit?.tagName};})};});
   result.probes.push({key:'subscription-help-lines',...help});await page.screenshot({path:out+'subscription-help-en-desktop.png',fullPage:false});await page.keyboard.press('Escape');
  }
 }
 result.platform_mutations=mutations;result.status=result.errors.length||result.external.length||mutations.length?'REVIEW_REQUIRED':'COMPLETE';writeFileSync(out+'accessibility-probes.json',JSON.stringify(result,null,2)+'\n');console.log(result.status,result.probes.length,'probes');
} finally {await browser?.close();await server.close();}
