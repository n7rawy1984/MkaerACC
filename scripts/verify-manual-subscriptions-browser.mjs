// Real local RPCs and browser, synthetic MFA only. No hosted connection.
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {chromium} from 'playwright';
import {startPlatformFixtureServer} from './platform-fixture-server.mjs';
const {db,server,base}=await startPlatformFixtureServer();let browser,checks=0;
const id=n=>`b0000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const check=(v,label)=>{assert(v,label);checks++;};
const owner=async(sql,args=[])=>db.transaction(async tx=>{await tx.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:id(1),session_id:id(101),aal:'aal2',amr:[{method:'totp',timestamp:Math.floor(Date.now()/1000)}]})]);await tx.exec('set local role authenticated');return(await tx.query(sql,args)).rows;});
const cmd=(name,input)=>owner('select public.platform_admin_command($1,$2,$3::jsonb) r',[name,randomUUID(),JSON.stringify(input)]).then(r=>r[0].r);
const count=async()=> (await db.query('select count(*)::int n from private.company_subscriptions')).rows[0].n;
try{
 const c=await cmd('create_entity',{code:'SUBS-UI',name:'Synthetic subscription UI Company',tenant_slug:'subs-ui',locale:'en',entity_kind:'BUSINESS',initial_admin_id:id(2)});
 await cmd('set_lifecycle',{id:c.id,version:'1',state:'ACTIVE',reason:'Synthetic activation'});
 const dates=(await db.query("select ((statement_timestamp() at time zone 'Asia/Dubai')::date)::text today,(((statement_timestamp() at time zone 'Asia/Dubai')::date)-1)::text yesterday")).rows[0];
 browser=await chromium.launch({headless:true});
 const local=async context=>{const page=await context.newPage();page.setDefaultTimeout(20000);await page.route('**/*',r=>new URL(r.request().url()).hostname==='127.0.0.1'?r.continue():r.abort());return page;};
 const context=await browser.newContext();const page=await local(context);const errors=[];page.on('pageerror',e=>errors.push(e.message));
 await page.goto(base+'/platform/subscriptions');await page.locator('input[name="code"]').fill('123456');await page.getByRole('button',{name:'Verify',exact:true}).click();
 await page.getByRole('button',{name:'Manage / renew subscription',exact:true}).click();
 await page.locator('dialog [name="starts_on"]').fill(dates.today);await page.locator('dialog [name="ends_on"]').fill(dates.today);await page.locator('dialog [name="reason"]').fill('Synthetic trial assignment');
 await page.evaluate(()=>{window.platformFixture.totpAgeSeconds=601;});
 await page.locator('dialog [name="confirm"]').check();await page.locator('dialog button[type="submit"]').click();
 await page.locator('dialog input[name="code"]').waitFor();check(await count()===0,'stale MFA cannot assign subscription');
 await page.locator('dialog input[name="code"]').fill('123456');await page.getByRole('button',{name:'Verify',exact:true}).click();await page.locator('[name="confirmResume"]').waitFor();check(await count()===0,'MFA completion does not auto-submit');
 await page.evaluate(()=>{window.platformFixture.uncertainNext=true;});await page.locator('[name="confirmResume"]').check();await page.getByRole('button',{name:'Confirm and continue',exact:true}).click();
 await page.getByRole('button',{name:'Recover pending request',exact:true}).waitFor();check(await count()===1,'lost response committed once');
 await page.reload();await page.locator('input[name="code"]').fill('123456');await page.getByRole('button',{name:'Verify',exact:true}).click();await page.getByRole('button',{name:'Recover pending request',exact:true}).click();
 await page.getByRole('status').filter({hasText:'Confirmed.'}).waitFor();check(await count()===1,'reload recovers same subscription');
 await page.getByRole('cell',{name:'Full (existing role applies)',exact:true}).waitFor();checks++;
 const memberContext=await browser.newContext();await memberContext.addInitScript(()=>sessionStorage.setItem('narvo-fixture-config',JSON.stringify({actor:2,signedIn:true,realIdentity:true})));
 const member=await local(memberContext);await member.goto(base+'/');await member.getByText('Subscription: Trial',{exact:false}).waitFor();check(await member.getByText('Valid through:',{exact:false}).isVisible(),'member sees actual date and state');
 await owner('select public.set_company_subscription($1,$2)',[randomUUID(),JSON.stringify({id:c.id,version:'1',plan_key:'STANDARD',subscription_state:'ACTIVE',starts_on:dates.yesterday,ends_on:dates.yesterday,billing_method:'MANUAL_OTHER',payment_status:'UNPAID',reason:'Synthetic expired state'})]);
 await member.reload();await member.getByText('Subscription: Expired',{exact:false}).waitFor();await member.getByText('New business and new masters require renewal.',{exact:false}).waitFor();checks++;
 await owner('select public.set_company_subscription($1,$2)',[randomUUID(),JSON.stringify({id:c.id,version:'2',plan_key:'STANDARD',subscription_state:'CANCELLED',starts_on:dates.yesterday,ends_on:dates.today,billing_method:'MANUAL_OTHER',payment_status:'WAIVED',reason:'Synthetic cancellation'})]);
 await member.reload();await member.getByText('Subscription: Cancelled',{exact:false}).waitFor();checks++;
 check(errors.length===0,'no owner UI runtime errors');
 console.log(`PASS: ${checks} focused subscription browser checks, MFA/reconfirmation/recovery and member state/expiry/banner. Local only.`);
}finally{await browser?.close();await server.close();await db.close();}
