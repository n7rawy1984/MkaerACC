// Isolated actual production UI/provider; remote requests blocked, no records retained.
import assert from "node:assert/strict";
import { createServer } from "vite";
import react from "@vitejs/plugin-react";
import { resolve } from "node:path";
import { chromium } from "playwright";
const root=resolve(import.meta.dirname,"..");
const server=await createServer({root,configFile:false,plugins:[{name:"treasury-fixture",enforce:"pre",resolveId(source,importer){if(source.endsWith("/lib/supabase")&&importer?.includes("src/master/"))return resolve(root,"scripts/fixtures/treasury-master-client.ts");},configureServer(s){s.middlewares.use("/__treasury_test",async(_req,res)=>{res.setHeader("Content-Type","text/html");res.end(await s.transformIndexHtml("/__treasury_test",'<html><body><div id="root"></div><script type="module" src="/scripts/fixtures/treasury-master.tsx"></script></body></html>'));});}},react()],server:{host:"127.0.0.1",port:0},logLevel:"error"});
let browser;
try {
 await server.listen();browser=await chromium.launch({headless:true,...(process.env.CHROMIUM_PATH?{executablePath:process.env.CHROMIUM_PATH}:{})});
 const page=await browser.newPage({viewport:{width:390,height:844}});page.setDefaultTimeout(20000);const errors=[];page.on("pageerror",e=>errors.push(e.message));
 await page.route("**/*",route=>new URL(route.request().url()).hostname==="127.0.0.1"?route.continue():route.abort());
 await page.goto(`http://127.0.0.1:${server.httpServer.address().port}/__treasury_test`);
 await page.getByRole("button",{name:"Create Treasury",exact:true}).click();
 let form=page.getByRole("form",{name:"Create Treasury",exact:true});
 assert.equal(await form.locator('[name="gl_account_id"] option').count(),3);
 assert.equal(await form.locator('[name="balance"], [name="opening_balance"]').count(),0);
 await form.locator('[name="name"]').fill("Main Cash");await form.locator('[name="code"]').fill("CASH");await form.locator('[name="gl_account_id"]').selectOption("97000000-0000-4000-8000-000000000031");
 await form.getByRole("button",{name:"Save",exact:true}).click();await form.waitFor({state:"detached"});
 await page.getByText("CASH · Main Cash",{exact:true}).waitFor();
 let status=page.getByRole("form",{name:"Change Treasury status",exact:true});
 const id=await page.evaluate(()=>window.treasuryFixture.treasuries[0].id);
 await status.locator('[name="treasury"]').selectOption(id);await status.locator('[name="status"]').selectOption("INACTIVE");await status.locator('[type="checkbox"]').check();
 await status.getByRole("button",{name:"Change Treasury status",exact:true}).click();
 await page.waitForFunction(()=>window.treasuryFixture.treasuries[0].status==="INACTIVE");
 await page.getByRole("button",{name:"Create Treasury",exact:true}).click();form=page.getByRole("form",{name:"Create Treasury",exact:true});
 assert.equal(await form.locator('[name="gl_account_id"] option').count(),2); // inactive mapping still reserved
 await form.getByRole("button",{name:"Close",exact:true}).click();
 for(const role of ["ACCOUNTANT","MANAGEMENT_VIEWER","PROJECT_MANAGER","SYSTEM_ADMIN"]){
  await page.evaluate(value=>window.treasuryFixture.role(value),role);await page.getByText(`Role: ${role}`,{exact:true}).waitFor();
  assert.equal(await page.getByRole("button",{name:"Create Treasury",exact:true}).count(),0);
  assert.equal(await page.getByRole("form",{name:"Change Treasury status",exact:true}).count(),0);
 }
 await page.evaluate(()=>window.treasuryFixture.role("ACCOUNTING_ADMIN"));await page.getByText("Role: ACCOUNTING_ADMIN",{exact:true}).waitFor();
 await page.getByRole("button",{name:"العربية",exact:true}).click();await page.getByRole("button",{name:"إنشاء خزينة",exact:true}).click();
 form=page.getByRole("form",{name:"إنشاء خزينة",exact:true});await form.waitFor();
 assert.equal(await page.locator("html").getAttribute("dir"),"rtl");assert(await page.evaluate(()=>document.documentElement.scrollWidth<=document.documentElement.clientWidth));
 await form.locator('[name="name"]').fill("خزينة البنك");await form.locator('[name="code"]').fill("BANK");await form.locator('[name="type"]').selectOption("BANK");await form.locator('[name="gl_account_id"]').selectOption("97000000-0000-4000-8000-000000000032");
 await form.getByRole("button",{name:"حفظ",exact:true}).click();await form.waitFor({state:"detached"});
 assert(await page.evaluate(()=>document.documentElement.scrollWidth<=document.documentElement.clientWidth));
 const calls=await page.evaluate(()=>window.treasuryFixture.calls.filter(c=>c.rpc));assert.equal(calls.length,3);
 assert.deepEqual(calls.map(c=>c.rpc),["create_treasury_master","set_treasury_master_status","create_treasury_master"]);
 assert.deepEqual(errors,[]);
 console.log("PASS: actual Treasury creation/status forms, eligible GL filtering, inactive mapping reserved, role controls, authoritative refresh, EN/AR/390px RTL, no financial calls or page errors.");
}finally{await browser?.close();await server.close();}
