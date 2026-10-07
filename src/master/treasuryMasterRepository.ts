import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Json } from "../types/database.generated";
import type { ProductionAccount, ProductionTreasuryAccount } from "./masterTypes";
export type TreasuryMasterError = "invalid" | "duplicate" | "denied" | "conflict" | "uncertain";
export function eligibleTreasuryAccounts(accounts: ProductionAccount[], treasuries: ProductionTreasuryAccount[], companyId: string) {
 return accounts.filter(a => a.companyId === companyId && a.accountType === "ASSET" && a.status === "ACTIVE"
  && !a.requiresParty && a.systemKey === null && !treasuries.some(t => t.companyId === companyId && t.glAccountId === a.id));
}
type TreasuryDatabase = Omit<Database,"public"> & {public: Omit<Database["public"],"Functions"> & {Functions: Database["public"]["Functions"] & {
 create_treasury_master: {Args:{target_company_id:string;business_input:Json};Returns:string};
 set_treasury_master_status: {Args:{target_company_id:string;target_treasury_id:string;target_status:"ACTIVE"|"INACTIVE";expected_updated_at:string};Returns:string};
}}};
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export async function mutateTreasuryMaster(client:SupabaseClient<Database>,companyId:string,command:
 {kind:"create";input:Record<string,string>} | {kind:"status";treasury:ProductionTreasuryAccount;status:"ACTIVE"|"INACTIVE"}
):Promise<{ok:true;id:string}|{ok:false;error:TreasuryMasterError}> {
 if(!uuid.test(companyId)||(command.kind==="status"&&(command.treasury.companyId!==companyId||!command.treasury.updatedAt)))return {ok:false,error:"denied"};
 try {
  const api=client as unknown as SupabaseClient<TreasuryDatabase>;
  const {data,error}=command.kind==="create"
   ?await api.rpc("create_treasury_master",{target_company_id:companyId,business_input:command.input})
   :await api.rpc("set_treasury_master_status",{target_company_id:companyId,target_treasury_id:command.treasury.id,target_status:command.status,expected_updated_at:command.treasury.updatedAt});
  if(error)return {ok:false,error:error.code==="23505"?"duplicate":error.code==="42501"?"denied":error.code==="40001"?"conflict":["23514","23502","23503","22023","22P02"].includes(error.code)?"invalid":"uncertain"};
  return typeof data==="string"&&uuid.test(data)?{ok:true,id:data}:{ok:false,error:"uncertain"};
 }catch{return {ok:false,error:"uncertain"};}
}
