import type {SupabaseClient} from '@supabase/supabase-js';
import type {Database} from '../types/database.generated';
export type ActivationAttempt={companyId:string;projectId:string;expectedUpdatedAt:string;requestId:string;reason:string};
export type ActivationEvent=Pick<Database['public']['Tables']['project_activation_events']['Row'],'id'|'company_id'|'project_id'|'actor_id'|'reason'|'activated_at'>;
export type ActivationError='conflict'|'denied'|'invalid'|'unavailable'|'uncertain';
export async function readProjectActivation(client:SupabaseClient<Database>,companyId:string,projectId:string):Promise<{ok:true;event:ActivationEvent|null}|{ok:false}>{
 try {const {data,error}=await client.from('project_activation_events').select('id,company_id,project_id,actor_id,reason,activated_at').eq('company_id',companyId).eq('project_id',projectId).maybeSingle();
  if(error||data&&(data.company_id!==companyId||data.project_id!==projectId))return {ok:false};return {ok:true,event:data};
 }catch{return {ok:false};}
}
export async function activateProject(client:SupabaseClient<Database>,attempt:ActivationAttempt):Promise<{ok:true}|{ok:false;error:ActivationError}>{
 try{const {data,error}=await client.rpc('activate_project',{target_company_id:attempt.companyId,target_project_id:attempt.projectId,expected_updated_at:attempt.expectedUpdatedAt,request_id:attempt.requestId,reason:attempt.reason});
  if(error)return {ok:false,error:error.code==='40001'?'conflict':error.code==='42501'?'denied':['22023','23514','22P02'].includes(error.code)?'invalid':['PGRST202','42883','42P01'].includes(error.code)?'unavailable':'uncertain'};
  if(!data||typeof data!=='object'||Array.isArray(data)||data.company_id!==attempt.companyId||data.project_id!==attempt.projectId||data.request_id!==attempt.requestId||data.status!=='ACTIVE'||typeof data.id!=='string'||typeof data.updated_at!=='string')return {ok:false,error:'uncertain'};
  return {ok:true};
 }catch{return {ok:false,error:'uncertain'};}
}
