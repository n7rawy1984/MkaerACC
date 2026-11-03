import {chromium} from 'playwright';
import assert from 'node:assert/strict';
import {mkdirSync,writeFileSync} from 'node:fs';
import {startEmeraldServer} from './fixtures/emerald-server.mjs';
const captureOnly=process.argv.includes('--capture-only');
const out='/tmp/narvo-contrast-correction';mkdirSync(out,{recursive:true});
const result={checks:[],measurements:[],errors:[],externalRequests:0};
const check=(ok,message)=>{assert(ok,message);result.checks.push(message)};
const {server,base,mutations}=await startEmeraldServer('after');let browser;
// Measure real computed CSS, including loaded route styles and inherited backgrounds.
async function inspect(page,selector){return page.locator(selector).evaluateAll(elements=>{
 const rgb=s=>(s.match(/[\d.]+/g)??[]).map(Number),lum=c=>c.slice(0,3).map(v=>{v/=255;return v<=.04045?v/12.92:((v+.055)/1.055)**2.4}).reduce((s,v,i)=>s+v*[.2126,.7152,.0722][i],0);
 const ratio=(a,b)=>(Math.max(lum(a),lum(b))+.05)/(Math.min(lum(a),lum(b))+.05);
 return elements.filter(e=>e.getClientRects().length).map(e=>{
  const style=getComputedStyle(e);let bg=[255,255,255],opacity=1;
  for(let p=e;p;p=p.parentElement){const s=getComputedStyle(p);opacity*=Number(s.opacity);const c=rgb(s.backgroundColor);if((c[3]??1)>0){bg=c;break;}}
  // Opacity is checked independently through every ancestor, even beyond the background.
  opacity=1;for(let p=e;p;p=p.parentElement)opacity*=Number(getComputedStyle(p).opacity);
  return {tag:e.tagName,text:(e.textContent??'').trim().slice(0,100),color:style.color,background:bg,contrast:ratio(rgb(style.color),bg),opacity};
 });});}
try{
 browser=await chromium.launch({headless:true});const context=await browser.newContext({viewport:{width:1366,height:768},serviceWorkers:'block',reducedMotion:'reduce'});
 await context.addInitScript(()=>localStorage.setItem('cas:v1:locale','ar'));
 await context.route('**/*',r=>new URL(r.request().url()).origin===base?r.continue():(result.externalRequests++,r.abort()));
 const page=await context.newPage();page.setDefaultTimeout(60000);page.setDefaultNavigationTimeout(90000);page.on('pageerror',e=>result.errors.push(e.message));
 const themes=[['emerald','الزمرد المميز'],['sapphire','الياقوت الملكي'],['graphite','الجرافيت التنفيذي'],['champagne','الشمبانيا الدافئة'],['teal','الفيروزي العصري']];
 for(const route of (captureOnly?['/accounting-cycle']:['/accounting-cycle','/platform'])){
  await page.goto(base+route,{waitUntil:'domcontentloaded'});await page.locator('main').waitFor();await page.locator('.theme-selector').waitFor();
  if(route==='/accounting-cycle')await page.locator('.cycle-month h3').first().waitFor();
  check(await page.evaluate(()=>document.documentElement.dir==='rtl'),route+' Arabic RTL');
  for(const [id,label] of (captureOnly?themes.slice(0,1):themes)){
   await page.locator('.theme-selector>summary').click();await page.getByRole('radio',{name:label,exact:true}).check();await page.keyboard.press('Escape');
   check(await page.evaluate(()=>document.documentElement.dataset.theme)===id,route+' '+id+' selector works');
   const sidebar=route==='/platform'?'.platform-sidebar':'.workspace-sidebar';
   // Open existing groups to test inactive labels as well as active links.
   await page.locator(sidebar+' details').evaluateAll(nodes=>nodes.forEach(n=>n.open=true));
   const text=await inspect(page,sidebar+' a,'+sidebar+' summary,'+sidebar+' em,'+sidebar+' small,'+sidebar+' .platform-nav-group>p');
   check(text.length>8,route+' '+id+' real sidebar labels present');
   check(text.every(n=>n.contrast>=4.5&&n.opacity===1),route+' '+id+' all navigation labels AA and fully opaque');
   const icons=await inspect(page,sidebar+' nav svg');check(icons.length>0&&icons.every(n=>n.contrast>=3&&n.opacity===1),route+' '+id+' icons and indicators visible');
   const active=await inspect(page,sidebar+' a.active');check(active.length>0&&active.every(n=>n.contrast>=4.5),route+' '+id+' active contrast');
   const primary=await page.evaluate(()=>getComputedStyle(document.documentElement).getPropertyValue('--erp-primary').trim());
   if(id==='emerald')check(primary==='#087E68',route+' recovered Git green #087E68');
   const inactive=page.locator(sidebar+' nav a:not(.active)').first();await inactive.scrollIntoViewIfNeeded();await inactive.hover();
   const hover=await inspect(page,sidebar+' nav a:hover');check(hover.length>0&&hover.every(n=>n.contrast>=4.5),route+' '+id+' hover contrast');await page.mouse.move(1365,767);
   let months=[];
   if(route==='/accounting-cycle'){
    months=await inspect(page,'.cycle-month h3');check(months.length===3&&months.every(n=>n.contrast>=4.5),id+' three actual month titles AA');
    check(months.every(n=>n.color==='rgb(255, 255, 255)'),id+' original inverse month-header text');
    const headings=await inspect(page,'.cycle-stage-heading h2,.cycle-stage-heading p');result.measurements.push({route,theme:id,stageHeadings:headings});check(headings.every(n=>n.contrast>=4.5),id+' financial stage headings AA');
    if(id==='emerald'){
     await page.locator(sidebar+' details').evaluateAll(nodes=>nodes.forEach((n,i)=>n.open=i===0||!!n.querySelector('a.active')));
     await page.locator(sidebar).evaluate(e=>e.scrollTop=0);await page.locator('.cycle-month-grid').evaluate(e=>window.scrollTo({top:window.scrollY+e.getBoundingClientRect().top-130}));await page.screenshot({path:out+'/arabic-months-sidebar-1366.png'});
     await page.locator('.cycle-month-grid').screenshot({path:out+'/arabic-month-headers.png'});
    }
   }
   result.measurements.push({route,theme:id,primary,sidebar:text,icons,active,hover,months});
   check(await page.evaluate(()=>document.documentElement.scrollWidth<=innerWidth+1),route+' '+id+' no page overflow');
  }
 }
 check(result.errors.length===0,'No browser runtime errors');check(result.externalRequests===0,'No external requests');check(mutations.length===0,'No platform mutation attempts');result.status='PASS';
}catch(e){result.status='FAIL';result.error=e.stack;console.error(e.stack);process.exitCode=1}finally{writeFileSync(out+(captureOnly?'/capture-result.json':'/result.json'),JSON.stringify(result,null,2)+'\n');await browser?.close();await server.close();}
