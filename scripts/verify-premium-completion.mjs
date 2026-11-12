import assert from'node:assert/strict';import{readFileSync,writeFileSync,mkdirSync}from'node:fs';import{chromium}from'playwright';import{startPremiumCompletionServer}from'./premium-completion-server.mjs';
const out='/tmp/narvo-premium-completion';mkdirSync(out,{recursive:true});const{server,base}=await startPremiumCompletionServer(),b=await chromium.launch({headless:true,executablePath:'/usr/bin/google-chrome'}),p=await b.newPage({viewport:{width:1366,height:768}}),checks=[],errors=[],external=[],surfaces=[];p.setDefaultTimeout(45000);p.on('pageerror',e=>errors.push(e.message));await p.route('**/*',r=>{if(r.request().url().startsWith(base)||r.request().url().startsWith('blob:'))return r.continue();external.push(r.request().url());return r.abort();});const check=(v,n)=>{assert(v,n);checks.push(n);console.log('PASS',n);};
const go=async path=>{await p.evaluate(path=>{history.pushState({},'',path);dispatchEvent(new PopStateEvent('popstate'));},path);await p.waitForTimeout(150);};
const language=async locale=>{const label=locale==='ar'?'العربية':'English',button=p.getByRole('button',{name:label,exact:true});if(await button.count())await button.first().click();};
const capture=async(name,locator=p.locator('#company-workspace-main'))=>{for(const[size,width,height]of[['laptop',1366,768],['mobile',390,844]]){await p.setViewportSize({width,height});check(await p.evaluate(()=>document.documentElement.scrollWidth<=innerWidth),name+' '+size+' populated page fits');await p.screenshot({path:out+'/'+name+'-'+size+'.png',fullPage:true});}surfaces.push(name);};
try{
 await p.goto(base+'/expenses',{waitUntil:'domcontentloaded'});await p.locator('.company-workspace').waitFor();
 const before=await p.evaluate(()=>JSON.stringify(window.premiumFixture.tables));
 const register=JSON.parse(readFileSync('docs/premium-system-ui-coverage.json','utf8'));
 if(!process.env.PREMIUM_REMAINING_SECTION||process.env.PREMIUM_REMAINING_SECTION==='populated'){
 for(const locale of['en','ar']){await language(locale);for(const row of register.companyRoutes.filter(r=>r.path!=='/')){
  await p.setViewportSize({width:1366,height:768});const path=row.path;await go(path==='/payroll'?path+'?view=register&month=2026-10':path);await p.locator('#company-workspace-main').waitFor();
  if(path==='/custody'){const h=p.getByLabel(locale==='en'?'Custody holder':'صاحب العهدة',{exact:true}).first();await h.selectOption(await p.evaluate(()=>window.premiumSnapshot.custodian));await p.getByRole('button',{name:locale==='en'?'Refresh custody register':'تحديث السجل',exact:true}).click();}
  if(path==='/subcontracts'){await p.getByLabel(locale==='en'?'Contract':'العقد',{exact:true}).selectOption({index:1});}
  if(path==='/attendance'){await p.getByLabel(locale==='en'?'Month':'الشهر',{exact:true}).last().fill('2026-10');}
  if(path.startsWith('/inventory/')){const select=p.getByLabel(locale==='en'?'Material profile':'ملف المادة',{exact:true});if(await select.count())await select.selectOption({index:1});}
  await p.waitForTimeout(180);const content=await p.locator('#company-workspace-main').innerText();check(content.length>40,locale+' '+path+' populated module renders');
  check(!/Records could not be loaded|Unable to load|Contract operations could not|Invalid Company HR/.test(content),locale+' '+path+' populated snapshot loads without read failure');
  await capture(locale+'-'+path.slice(1).replaceAll('/','-'));
 }
 }
 }
 check(await p.evaluate(()=>JSON.stringify(window.premiumFixture.tables))===before,'All synthetic financial/master/source snapshots remain unchanged');check(!errors.length,'No Production component runtime errors: '+errors.join(';'));check(!external.length,'No external or hosted requests');
 writeFileSync(out+'/populated.json',JSON.stringify({status:'PASS',checks,surfaces,errors,external,financialWrites:0},null,2));
}catch(e){await p.screenshot({path:out+'/failure.png',fullPage:true}).catch(()=>{});writeFileSync(out+'/failure.json',JSON.stringify({error:e.message,checks,surfaces,errors,external,body:(await p.locator('body').innerText()).slice(-9000)},null,2));console.error(e);process.exitCode=1;}finally{await b.close();await server.close();}
