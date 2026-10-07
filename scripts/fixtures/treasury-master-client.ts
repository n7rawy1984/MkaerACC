// In-memory browser verification only. No remote connection or credentials.
export const companyId = "97000000-0000-4000-8000-000000000001";
export const projectId = "97000000-0000-4000-8000-000000000011";
const audit = { created_at: "2026-01-01T00:00:00Z", updated_at: "2026-01-01T00:00:00Z", created_by: "user-a", updated_by: "user-a" };
export const calls: unknown[] = [];
export const treasuries: Record<string,unknown>[] = [];
export const accounts: Record<string,unknown>[] = [
 { ...audit,id:"97000000-0000-4000-8000-000000000031",company_id:companyId,code:"CASH-GL",name:"Cash GL",account_type:"ASSET",status:"ACTIVE",requires_party:false,system_key:null,parent_account_id:null },
 { ...audit,id:"97000000-0000-4000-8000-000000000032",company_id:companyId,code:"BANK-GL",name:"Bank GL",account_type:"ASSET",status:"ACTIVE",requires_party:false,system_key:null,parent_account_id:null },
 { ...audit,id:"97000000-0000-4000-8000-000000000033",company_id:companyId,code:"VAT",name:"Reserved VAT",account_type:"ASSET",status:"ACTIVE",requires_party:false,system_key:"INPUT_VAT",parent_account_id:null },
 { ...audit,id:"97000000-0000-4000-8000-000000000034",company_id:companyId,code:"INACTIVE",name:"Inactive GL",account_type:"ASSET",status:"INACTIVE",requires_party:false,system_key:null,parent_account_id:null },
];
let role = "ACCOUNTING_ADMIN";
let fault = "";
const company = { ...audit,id:companyId,code:"A",name:"Alpha",legal_name:null,status:"ACTIVE",trn:null,address:null,notes:null };
const projects = [{ ...audit,id:projectId,company_id:companyId,code:"P1",name:"Project One",status:"ACTIVE" }];
export const client = {
 auth: {
  onAuthStateChange(callback: (event: string, session: unknown) => void) { queueMicrotask(() => callback("INITIAL_SESSION", {user:{id:"user-a"}})); return {data:{subscription:{unsubscribe(){}}}}; },
  getSession: async () => ({data:{session:{user:{id:"user-a"}}},error:null}),
  getClaims: async () => ({data:{claims:{sub:"user-a"}},error:null}),
 },
 from(table: string) {
  const filters: [string,unknown][] = []; let single = false;
  const query = {
   select(){return query;},order(){return query;},eq(key:string,value:unknown){filters.push([key,value]);return query;},in(key:string,value:unknown){filters.push([key,value]);return query;},maybeSingle(){single=true;return query;},
   then(done: (value: unknown) => unknown, fail: (error: unknown) => unknown) {return (async()=>{
    calls.push({read:table});
    if (fault === "read" && ["treasury_accounts"].includes(table)) { fault="";return {data:null,error:{code:"network"}}; }
    const rows = table === "accounts" ? accounts : table === "treasury_accounts" ? treasuries : table === "companies" ? [company] : table === "projects" ? projects : table === "profiles" ? [{user_id:"user-a",display_name:"Test",status:"ACTIVE",locale:"en"}] : table === "company_memberships" ? [{id:"membership",user_id:"user-a",company_id:companyId,role,status:"ACTIVE"}] : [];
    const data = rows.filter(row=>filters.every(([key,value])=>Array.isArray(value)?value.includes((row as Record<string,unknown>)[key]):(row as Record<string,unknown>)[key]===value));
    return {data:structuredClone(single?data[0]??null:data),error:null};
   })().then(done,fail);}
  }; return query;
 },
 async rpc(name:string,args:{target_company_id:string;business_input:Record<string,string|null>;target_treasury_id?:string;target_status?:string;expected_updated_at?:string}) {
  calls.push({rpc:name,args});
  if(role!=="ACCOUNTING_ADMIN" || args.target_company_id!==companyId) return {data:null,error:{code:"42501"}};
  if(fault==="duplicate") {fault="";return {data:null,error:{code:"23505"}};}
  const id=crypto.randomUUID(),v=args.business_input;
  if(name==="create_treasury_master")treasuries.push({...audit,id,company_id:companyId,project_id:null,bank_name:null,account_reference:null,notes:null,status:"ACTIVE",...v});
  else if(name==="set_treasury_master_status"){
   const treasury=treasuries.find(t=>t.id===args.target_treasury_id);
   if(!treasury)return {data:null,error:{code:"42501"}};
   if(fault==="conflict"){fault="";return {data:null,error:{code:"40001"}};}
   treasury.status=args.target_status;treasury.updated_at=new Date().toISOString();
   return {data:treasury.id,error:null};
  }else return {data:null,error:{code:"42501"}};
  if(fault==="uncertain") {fault="";throw Error("network");}
  return {data:id,error:null};
 }
};
export function getSupabaseClient() { return client; }
Object.assign(window,{treasuryFixture:{calls,treasuries,accounts,projects,role(value:string){role=value;window.dispatchEvent(new Event("focus"));},fault(value:string){fault=value;}}});
