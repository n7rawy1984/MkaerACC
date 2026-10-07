import assert from "node:assert/strict";
import { createServer } from "vite";
import react from "@vitejs/plugin-react";
import { resolve } from "node:path";
import { chromium } from "playwright";
const root=resolve(import.meta.dirname,"..");
const server=await createServer({root,configFile:false,plugins:[{name:"creation-fixture",enforce:"pre",resolveId(source,importer){if(source.endsWith("/lib/supabase") && importer?.includes("src/master/")) return resolve(root,"scripts/fixtures/person-master-creation-client.ts");},configureServer(s){s.middlewares.use("/__creation_test",async(_req,res)=>{res.setHeader("Content-Type","text/html");res.end(await s.transformIndexHtml("/__creation_test",'<html><body><div id="root"></div><script type="module" src="/scripts/fixtures/person-master-creation.tsx"></script></body></html>'));});}},react()],server:{host:"127.0.0.1",port:0},logLevel:"error"});
let browser;
try {
 await server.listen();browser=await chromium.launch({headless:true,...(process.env.CHROMIUM_PATH?{executablePath:process.env.CHROMIUM_PATH}:{})});
 const page=await browser.newPage({viewport:{width:390,height:844}});page.setDefaultTimeout(60000);const errors=[];page.on("pageerror",e=>errors.push(e.message));
 await page.route("**/*",route=>new URL(route.request().url()).hostname==="127.0.0.1"?route.continue():route.abort());
 await page.goto(`http://127.0.0.1:${server.httpServer.address().port}/__creation_test`,{waitUntil:"domcontentloaded",timeout:120000});
 await page.getByRole("button",{name:"Create employee / custodian",exact:true}).click();
 const form=page.getByRole("form",{name:"Create employee / custodian",exact:true});
 await form.locator('[name="name"]').fill("Dual Person");await form.locator('[name="code"]').fill("D1");await form.locator('[name="kind"]').selectOption("EMPLOYEE_CUSTODIAN");
 await form.getByRole("button",{name:"Save",exact:true}).click();await form.waitFor({state:"detached"});
 await page.getByText("D1 · Dual Person",{exact:true}).waitFor();
 assert.equal(await page.evaluate(()=>window.creationFixture.parties.filter(p=>p.name==="Dual Person").length),1);
 assert.equal(await page.getByRole("button",{name:"Add Custodian role",exact:true}).count(),0);
 await page.getByRole("button",{name:"Create employee / custodian",exact:true}).click();
 await form.locator('[name="name"]').fill("Custodian Person");await form.locator('[name="code"]').fill("C1");await form.locator('[name="kind"]').selectOption("CUSTODIAN");
 await form.getByRole("button",{name:"Save",exact:true}).click();await form.waitFor({state:"detached"});
 await page.getByRole("button",{name:"Add Employee role",exact:true}).click();
 await page.waitForFunction(()=>!document.querySelector('section button')?.disabled);
 await page.waitForFunction(()=>window.creationFixture.personRoles.some(r=>r.role==="EMPLOYEE"));
 assert.equal(await page.evaluate(()=>window.creationFixture.parties.filter(p=>p.name==="Custodian Person").length),1);
 await page.getByRole("button",{name:"Switch workspace"}).click();
 await page.getByRole("button",{name:"Create Project",exact:true}).click();
 const project=page.getByRole("form",{name:"Create Project",exact:true});
 await project.locator('[name="name"]').fill("Real-shaped synthetic Project");await project.locator('[name="code"]').fill("P2");await project.locator('[name="status"]').selectOption("ACTIVE");
 await project.getByRole("button",{name:"Save",exact:true}).click();await project.waitFor({state:"detached"});
 await page.getByText("P2 · Real-shaped synthetic Project",{exact:true}).waitFor();
 const calls=await page.evaluate(()=>window.creationFixture.calls);assert(calls.some(c=>c.rpc==="create_project"));assert(calls.some(c=>c.rpc==="create_person_party"));assert(calls.some(c=>c.rpc==="add_party_person_role"));
 for(const role of ["MANAGEMENT_VIEWER","PROJECT_MANAGER","SYSTEM_ADMIN","PROCUREMENT"]) {
  await page.evaluate(r=>window.creationFixture.role(r),role);await page.getByText(`Role: ${role}`,{exact:true}).waitFor();
  assert.equal(await page.getByRole("button",{name:"Create Project",exact:true}).count(),0);
  await page.getByRole("button",{name:"Switch workspace"}).click();assert.equal(await page.getByRole("button",{name:"Create employee / custodian",exact:true}).count(),0);
  await page.getByRole("button",{name:"Switch workspace"}).click();
 }
 await page.evaluate(()=>window.creationFixture.role("ACCOUNTING_ADMIN"));await page.getByText("Role: ACCOUNTING_ADMIN",{exact:true}).waitFor();
 await page.getByRole("button",{name:"العربية",exact:true}).click();await page.getByRole("button",{name:"إنشاء مشروع",exact:true}).click();
 assert(await page.getByRole("form",{name:"إنشاء مشروع",exact:true}).isVisible());assert.equal(await page.locator("html").getAttribute("dir"),"rtl");assert(await page.evaluate(()=>document.documentElement.scrollWidth<=document.documentElement.clientWidth));
 await page.getByRole("button",{name:"إغلاق",exact:true}).click();await page.getByRole("button",{name:"Switch workspace"}).click();await page.getByRole("button",{name:"إنشاء موظف / أمين عهدة",exact:true}).click();
 assert(await page.getByRole("form",{name:"إنشاء موظف / أمين عهدة",exact:true}).isVisible());assert(await page.evaluate(()=>document.documentElement.scrollWidth<=document.documentElement.clientWidth));
 assert.deepEqual(errors,[]);console.log("PASS: Employee/Custodian/dual identity + capability assignment + Project forms, exact RPCs, authoritative role readback, role denials, EN/AR and 390px RTL");
} finally {await browser?.close();await server.close();}
