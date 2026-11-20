// Disposable local PostgreSQL only. Reuses retained core fixture, not CR07 simulation.
import{foundationFixture}from'./foundation-certification-fixture.mjs';import{randomUUID}from'node:crypto';
export async function purchaseOrderFixture(database){const f=await foundationFixture(database),{db,company}=f;
 await db.query("insert into private.company_legacy_eligibility(company_id,reason)values($1,'Disposable local purchasing fixture only')",[company]);
 const accountant=randomUUID(),procurement=randomUUID(),viewer=randomUUID(),supplier=randomUUID(),project=randomUUID(),material=randomUUID();
 for(const[u,role]of[[accountant,'ACCOUNTANT'],[procurement,'PROCUREMENT'],[viewer,'MANAGEMENT_VIEWER']]){await db.query('insert into auth.users(id,email)values($1,$2)',[u,u+'@example.invalid']);await db.query('insert into public.company_memberships(company_id,user_id,role)values($1,$2,$3)',[company,u,role]);}
 await db.query("insert into public.parties(id,company_id,code,name,type)values($1,$2,'PO-SUP','Fictional Supplier','SUPPLIER')",[supplier,company]);await db.query("insert into public.projects(id,company_id,code,name,status)values($1,$2,'PO-PROJECT','Fictional Project','ACTIVE')",[project,company]);await db.query("insert into public.inventory_materials(id,company_id,code,name,category,base_unit)values($1,$2,'PO-MAT','Fictional Material','Materials','UNIT')",[material,company]);
 const date=(await db.query("select(statement_timestamp()at time zone 'Asia/Dubai')::date::text d")).rows[0].d;
 const input=(patch={})=>({id:randomUUID(),version:'0',date,delivery_on:'',supplier_id:supplier,project_id:project,notes:'Local supplier terms',lines:[{material_id:material,description:'Fictional Material',unit:'UNIT',quantity_micros:'2500000',unit_price_minor:'1200'},{material_id:'',description:'Transport service',unit:'TRIP',quantity_micros:'333333',unit_price_minor:'301'}],...patch});
 const command=(action,input,key=randomUUID(),actor=f.admin)=>f.as(actor,'select public.command_purchase_order($1,$2,$3,$4)r',[company,key,action,input]).then(r=>r[0].r);
 const read=(actor=f.admin,page=0,size=25,cid=company)=>f.as(actor,'select public.read_purchase_orders($1,$2,$3)r',[cid,page,size]).then(r=>r[0].r);
 return{...f,accountant,procurement,viewer,supplier,project,material,date,input,command,read};
}
