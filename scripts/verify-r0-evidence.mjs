import {chromium} from 'playwright';
import {readFileSync,writeFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
const browser=await chromium.launch({headless:true});const result={scans:[],external:[]};
try{const ctx=await browser.newContext({serviceWorkers:'block'});await ctx.route('**/*',q=>q.request().url().startsWith('file:')?q.continue():(result.external.push(q.request().url()),q.abort()));const page=await ctx.newPage();
 for(const width of [1440,390]){await page.setViewportSize({width,height:1000});await page.goto(pathToFileURL(resolve('docs/release/r0-production-impact/index.html')).href);await page.addScriptTag({content:readFileSync('/tmp/narvo-owner-redesign-tools/node_modules/axe-core/axe.min.js','utf8')});const scan=await page.evaluate(()=>window.axe.run(document,{runOnly:{type:'tag',values:['wcag2a','wcag2aa','wcag21aa','wcag22aa']}}));result.scans.push({width,violations:scan.violations,incomplete:scan.incomplete.map(x=>({id:x.id,nodes:x.nodes.length})),overflow:await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth)});}
 result.status=result.external.length||result.scans.some(x=>x.violations.length||x.overflow)?'FAIL':'PASS';writeFileSync('docs/release/r0-production-impact/gallery-verification.json',JSON.stringify(result,null,2)+'\n');console.log('Gallery',result.status);if(result.status!=='PASS')process.exitCode=1;
}finally{await browser.close();}
