// Focused loopback-only UI test against the real local PostgreSQL RPCs.
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {chromium} from 'playwright';
import {startPlatformFixtureServer} from './platform-fixture-server.mjs';
const {db,server,base}=await startPlatformFixtureServer();let browser,checks=0;
const id=n=>`b0000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const check=(v,label)=>{assert(v,label);checks++;};
const cmd=(name,input)=>db.transaction(async tx=>{await tx.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:id(1),session_id:id(101),aal:'aal2',amr:[{method:'totp',timestamp:Math.floor(Date.now()/1000)}]})]);await tx.exec('set local role authenticated');return(await tx.query('select public.platform_admin_command($1,$2,$3::jsonb) r',[name,randomUUID(),JSON.stringify(input)])).rows[0].r;});
const count=async(table,cid)=>(await db.query(`select count(*)::int n from ${table} where company_id=$1`,[cid])).rows[0].n;
try{
 const company=(await cmd('create_entity',{code:'PROVISION-UI',name:'Synthetic provision UI Company',tenant_slug:'provision-ui',locale:'en',entity_kind:'BUSINESS',initial_admin_id:id(2)})).id;
 await cmd('set_lifecycle',{id:company,version:'1',state:'ACTIVE',reason:'Local test activation'});
 browser=await chromium.launch({headless:true});
 const local=async context=>{const page=await context.newPage();page.setDefaultTimeout(20000);await page.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());return page;};
 const memberContext=await browser.newContext();await memberContext.addInitScript(()=>sessionStorage.setItem('narvo-fixture-config',JSON.stringify({actor:2,signedIn:true,realIdentity:true})));
 const member=await local(memberContext);await member.goto(base+'/');await member.getByText('Company activated; accounting setup pending.',{exact:false}).waitFor();checks++;
 const page=await local(await browser.newContext());const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(base+'/platform/entities');await page.locator('input[name="code"]').fill('123456');await page.getByRole('button',{name:'Verify',exact:true}).click();
 await page.getByRole('button',{name:'Provision accounting',exact:true}).click();
 await page.locator('dialog [name="treasury_name"]').fill('Real synthetic cash counter');await page.locator('dialog [name="reason"]').fill('Synthetic reviewed setup');
 await page.evaluate(()=>{window.platformFixture.totpAgeSeconds=601;});
 await page.locator('dialog [name="confirm"]').check();await page.locator('dialog button[type="submit"]').click();
 await page.getByRole('heading',{name:'Verify your authenticator',exact:true}).first().waitFor();
 check(await count('public.accounts',company)===0,'stale MFA creates no chart');
 await page.locator('dialog input[name="code"]').fill('123456');await page.getByRole('button',{name:'Verify',exact:true}).click();await page.locator('[name="confirmResume"]').waitFor();
 check(await count('public.accounts',company)===0,'MFA verification alone never provisions');
 await page.evaluate(()=>{window.platformFixture.uncertainNext=true;});await page.locator('[name="confirmResume"]').check();await page.getByRole('button',{name:'Confirm and continue',exact:true}).click();
 await page.getByRole('button',{name:'Recover pending request',exact:true}).waitFor();check(await count('public.accounts',company)===11,'lost response committed once');
 await page.reload();await page.locator('input[name="code"]').fill('123456');await page.getByRole('button',{name:'Verify',exact:true}).click();await page.getByRole('button',{name:'Recover pending request',exact:true}).click();
 await page.getByRole('status').filter({hasText:'Confirmed.'}).waitFor();
 await page.getByRole('cell',{name:'Accounting foundation complete',exact:true}).waitFor();checks++;
 check(await count('public.accounts',company)===11&&await count('public.treasury_accounts',company)===1,'reload recovery cannot duplicate foundation');
 check(await page.getByRole('button',{name:'Provision accounting',exact:true}).count()===0,'completed Company hides initial provisioning');
 await member.reload();await member.getByText('Accounting foundation complete.',{exact:false}).waitFor();checks++;
 check(await member.getByRole('heading',{name:'Synthetic provision UI Company',exact:true}).isVisible(),'member remains in exact workspace');
 check(errors.length===0,'no owner UI runtime errors');
 console.log(`PASS: ${checks} focused browser checks: pending/complete, fresh MFA, explicit reconfirmation, uncertain response/reload recovery, member workspace. Local only.`);
}finally{await browser?.close();await server.close();await db.close();}
