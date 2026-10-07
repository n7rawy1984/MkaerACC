import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database, Json } from "../types/database.generated";
import type { CreationError } from "./subcontractCreationRepository";
export type PersonRole = "EMPLOYEE" | "CUSTODIAN";
export const canCreatePersonMaster = (role: string) => role === "ACCOUNTING_ADMIN";
export type PersonMasterDatabase = Omit<Database,"public"> & {public: Omit<Database["public"],"Functions"|"Tables"> & {
 Tables: Database["public"]["Tables"] & {party_person_roles: {
  Row: {company_id:string;party_id:string;role:PersonRole;created_at:string;created_by:string};
  Insert: {company_id:string;party_id:string;role:PersonRole;created_by:string;created_at?:string}; Update: never; Relationships: [];
 }};
 Functions: Database["public"]["Functions"] & {
 create_person_party: {Args:{target_company_id:string;business_input:Json};Returns:string};
 create_project: {Args:{target_company_id:string;business_input:Json};Returns:string};
 add_party_person_role: {Args:{target_company_id:string;target_party_id:string;target_role:PersonRole};Returns:string};
 };
}};
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export async function createPersonMaster(client:SupabaseClient<Database>,companyId:string,kind:"person"|"project"|"role",input:Record<string,string>):Promise<{ok:true;id:string}|{ok:false;error:CreationError}> {
 if(!uuid.test(companyId))return {ok:false,error:"denied"};
 const api=client as unknown as SupabaseClient<PersonMasterDatabase>;
 try {
  const result=kind==="role"
   ? await api.rpc("add_party_person_role",{target_company_id:companyId,target_party_id:input.party_id,target_role:input.role as PersonRole})
   : await api.rpc(kind==="person"?"create_person_party":"create_project",{target_company_id:companyId,business_input:input});
  if(result.error)return {ok:false,error:result.error.code==="23505"?"duplicate":result.error.code==="42501"?"denied":["23514","23502","23503","22023","22P02"].includes(result.error.code)?"invalid":"uncertain"};
  return typeof result.data==="string"&&uuid.test(result.data)?{ok:true,id:result.data}:{ok:false,error:"uncertain"};
 } catch{return {ok:false,error:"uncertain"};}
}
