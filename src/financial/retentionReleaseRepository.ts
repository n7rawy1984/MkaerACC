import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";

export interface RetentionReleaseRead {
  id:string; company_id:string; release_reference:string; release_date:string; project_id:string; subcontractor_id:string; subcontract_id:string;
  total_amount_minor:string; authorization_reference:string|null; notes:string|null; status:"DRAFT"|"POSTED"|"REVERSED";
  posted_journal_entry_id:string|null; reversal_journal_entry_id:string|null; created_at:string; created_by:string|null;
  posted_at:string|null; posted_by:string|null; reversed_at:string|null; reversed_by:string|null; reversal_reason:string|null;
}
export interface RetentionReleaseAllocationRead { id:string; company_id:string; retention_release_id:string; subcontractor_certificate_id:string; allocated_amount_minor:string }
export interface CertificateRetentionAvailable { id:string; company_id:string; certificate_reference:string; certificate_date:string; project_id:string; subcontractor_id:string; subcontract_id:string; retention_amount_minor:string; released_amount_minor:string; remaining_amount_minor:string }
export interface RetentionReleaseSnapshot { releases:RetentionReleaseRead[]; allocations:RetentionReleaseAllocationRead[]; available:CertificateRetentionAvailable[] }
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const exact=(value:unknown)=>{if(typeof value!=="string"||!/^\d+$/.test(value)||BigInt(value)>9223372036854775807n)throw new Error("Invalid exact amount");return value};
const releaseProjection="id,company_id,release_reference,release_date,project_id,subcontractor_id,subcontract_id,total_amount_minor::text,authorization_reference,notes,status,posted_journal_entry_id,reversal_journal_entry_id,created_at,created_by,posted_at,posted_by,reversed_at,reversed_by,reversal_reason";
const allocationProjection="id,company_id,retention_release_id,subcontractor_certificate_id,allocated_amount_minor::text";
const certificateProjection="id,company_id,certificate_reference,certificate_date,project_id,subcontractor_id,subcontract_id,retention_amount_minor::text";
async function allRows<T>(load:(from:number,to:number)=>PromiseLike<{data:T[]|null;error:unknown}>):Promise<T[]>{const rows:T[]=[];for(let from=0;;from+=500){const{data,error}=await load(from,from+499);if(error||!data)throw new Error("Retention Release read unavailable");rows.push(...data);if(data.length<500)return rows}}
export const canReadRetentionReleases=(role:string)=>role==="ACCOUNTING_ADMIN"||role==="ACCOUNTANT"||role==="MANAGEMENT_VIEWER";
export async function readRetentionReleases(client:SupabaseClient<Database>,companyId:string):Promise<RetentionReleaseSnapshot>{
  if(!uuid.test(companyId))throw new Error("Invalid Retention Release scope");
  const releases=await allRows<any>((from,to)=>client.from("subcontractor_retention_releases").select(releaseProjection).eq("company_id",companyId).order("release_date",{ascending:false}).order("id",{ascending:true}).range(from,to));
  const allocations=await allRows<any>((from,to)=>client.from("subcontractor_retention_release_allocations").select(allocationProjection).eq("company_id",companyId).order("id",{ascending:true}).range(from,to));
  const certificates=await allRows<any>((from,to)=>client.from("subcontractor_certificates").select(certificateProjection).eq("company_id",companyId).eq("status","POSTED").order("certificate_date",{ascending:true}).order("id",{ascending:true}).range(from,to));
  if([...releases,...allocations,...certificates].some(row=>row.company_id!==companyId))throw new Error("Invalid Retention Release scope");
  const mappedReleases=releases.map(row=>{if(![row.id,row.project_id,row.subcontractor_id,row.subcontract_id].every((value:unknown)=>typeof value==="string"&&uuid.test(value))||!["DRAFT","POSTED","REVERSED"].includes(row.status))throw new Error("Invalid Retention Release row");return{...row,total_amount_minor:exact(row.total_amount_minor)} as RetentionReleaseRead});
  const status=new Map(mappedReleases.map(row=>[row.id,row.status]));
  const mappedAllocations=allocations.map(row=>({...row,allocated_amount_minor:exact(row.allocated_amount_minor)} as RetentionReleaseAllocationRead));
  const liveReleased=new Map<string,bigint>();for(const row of mappedAllocations)if(status.get(row.retention_release_id)==="POSTED")liveReleased.set(row.subcontractor_certificate_id,(liveReleased.get(row.subcontractor_certificate_id)??0n)+BigInt(row.allocated_amount_minor));
  const available=certificates.map(row=>{const retention=exact(row.retention_amount_minor),released=liveReleased.get(row.id)??0n,remaining=BigInt(retention)-released;if(remaining<0n||![row.id,row.project_id,row.subcontractor_id,row.subcontract_id].every((value:unknown)=>typeof value==="string"&&uuid.test(value)))throw new Error("Invalid remaining Certificate retention");return{...row,retention_amount_minor:retention,released_amount_minor:released.toString(),remaining_amount_minor:remaining.toString()} as CertificateRetentionAvailable}).filter(row=>BigInt(row.remaining_amount_minor)>0n);
  return{releases:mappedReleases,allocations:mappedAllocations,available};
}
export async function readRetentionReleaseById(client:SupabaseClient<Database>,companyId:string,releaseId:string):Promise<RetentionReleaseRead>{if(!uuid.test(companyId)||!uuid.test(releaseId))throw new Error("Invalid Retention Release scope");const{data,error}=await client.from("subcontractor_retention_releases").select(releaseProjection).eq("company_id",companyId).eq("id",releaseId).maybeSingle();if(error||!data||data.company_id!==companyId||data.id!==releaseId)throw new Error("Retention Release readback unavailable");return{...data,total_amount_minor:exact(data.total_amount_minor)} as RetentionReleaseRead}
