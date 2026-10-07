import { useLayoutEffect, useRef, useState, type FormEvent } from "react";
import { useAuth } from "../auth/AuthContext";
import { useT } from "../i18n/I18nContext";
import { getSupabaseClient } from "../lib/supabase";
import { Field, inputClassName } from "../components/ui/Field";
import { useProductionMasterData } from "./productionMasterDataContext";
import { canCreatePersonMaster, createPersonMaster } from "./personMasterRepository";

export function PersonMasterCreationPanel({kind}:{kind:"person"|"project"}) {
 const {state}=useAuth(),master=useProductionMasterData(),t=useT();
 const [open,setOpen]=useState(false),[busy,setBusy]=useState(false),[message,setMessage]=useState("");
 const lock=useRef(false),origin=useRef<HTMLButtonElement>(null),restore=useRef(false);
 useLayoutEffect(()=>{if(!open&&!busy&&restore.current&&origin.current&&!origin.current.disabled){origin.current.focus();restore.current=false;}},[open,busy,message]);
 if(state.phase!=="TENANT_READY"||master.phase!=="READY"||!canCreatePersonMaster(state.activeTenant.role))return null;
 const companyId=state.activeTenant.companyId,userId=state.profile.userId;
 const close=()=>{restore.current=true;setOpen(false);};
 const refresh=()=>kind==="person"?master.refreshParties():master.refreshProjects();
 const blocked=busy||message==="uncertain"||message==="refreshError";
 const save=async(commandKind:"person"|"project"|"role",input:Record<string,string>)=>{
  if(lock.current||blocked)return;lock.current=true;setBusy(true);setMessage("");
  try {
   const client=getSupabaseClient(),session=await client.auth.getSession();
   if(session.error||session.data.session?.user.id!==userId){setMessage("denied");return;}
   const result=await createPersonMaster(client,companyId,commandKind,input);
   if(!result.ok){setMessage(result.error);return;}
   if(!await refresh()){setMessage("refreshError");return;}
   setMessage("saved");close();
  } catch{setMessage("uncertain");}finally{lock.current=false;setBusy(false);}
 };
 const submit=(event:FormEvent<HTMLFormElement>)=>{
  event.preventDefault();const input=Object.fromEntries(new FormData(event.currentTarget).entries()) as Record<string,string>;
  for(const key of Object.keys(input))input[key]=input[key].trim();
  if(!input.name||(kind==="project"&&!input.code)){setMessage("invalid");return;}
  void save(kind,input);
 };
 const recover=async()=>{if(lock.current)return;const committed=message==="refreshError";lock.current=true;setBusy(true);close();try{setMessage(await refresh()?committed?"saved":"review":committed?"refreshError":"uncertain");}catch{setMessage(committed?"refreshError":"uncertain");}finally{lock.current=false;setBusy(false);}};
 const label=t(kind==="person"?"personCreation.create":"personCreation.project");
 return <section className="mt-4 min-w-0">
  <button ref={origin} disabled={blocked||open} onClick={()=>{setMessage("");setOpen(true);}} className="rounded-lg border px-3 py-2 text-sm disabled:opacity-50">{label}</button>
  {message&&<p className="mt-3 text-sm" role={message==="saved"?"status":"alert"}>{t(`masterCreation.${message}` as never)}</p>}
  {busy&&<p role="status">{t("supplierMutation.pending")}</p>}
  {(message==="uncertain"||message==="refreshError")&&<button disabled={busy} onClick={()=>void recover()} className="mt-2 underline">{t("personCreation.refresh")}</button>}
  {open&&<form onSubmit={submit} aria-label={label} className="mt-4 min-w-0 space-y-3 rounded-lg border p-4">
   <fieldset disabled={blocked} className="space-y-3">
    {kind==="person"&&<Field label={t("personCreation.kind")} required><select name="kind" className={inputClassName}>{(["EMPLOYEE","CUSTODIAN","EMPLOYEE_CUSTODIAN"] as const).map(k=><option key={k} value={k}>{t(`personCreation.${k}`)}</option>)}</select></Field>}
    <Field label={t("supplierMutation.name")} required><input autoFocus name="name" required maxLength={200} className={inputClassName}/></Field>
    <Field label={t("personCreation.code")} required={kind==="project"}><input name="code" required={kind==="project"} maxLength={50} className={inputClassName}/></Field>
    {kind==="project"&&(["client_name","location","contract_number"] as const).map(field=><Field key={field} label={t(`projectMetadata.${field}`)}><input name={field} className={inputClassName}/></Field>)}
    <Field label={t("common.status")}><select name="status" className={inputClassName}>{(kind==="person"?["ACTIVE","INACTIVE"] as const:["PLANNING","ACTIVE","ON_HOLD","COMPLETED","CLOSED"] as const).map(status=><option key={status} value={status}>{kind==="person"?t(`partyStatus.${status as "ACTIVE"|"INACTIVE"}`):t(`projectStatus.${status as "PLANNING"|"ACTIVE"|"ON_HOLD"|"COMPLETED"|"CLOSED"}`)}</option>)}</select></Field>
    <Field label={t("common.notesOptional")}><textarea name="notes" className={inputClassName}/></Field>
    <button type="submit" className="rounded-lg bg-[var(--tenant-primary)] px-4 py-2 text-white">{t("supplierMutation.save")}</button>
   </fieldset>
   <button type="button" disabled={busy} onClick={close} className="underline">{t("supplierMutation.close")}</button>
  </form>}
  {kind==="person"&&<ul className="mt-3 space-y-2">{master.parties.filter(p=>p.status==="ACTIVE"&&(p.type==="EMPLOYEE"||p.type==="CUSTODIAN")&&p.personRoles?.length===1).map(p=><li key={p.id} className="flex min-w-0 flex-wrap items-center gap-2"><bdi className="break-words">{p.name}</bdi><button disabled={blocked} onClick={()=>void save("role",{party_id:p.id,role:p.type==="EMPLOYEE"?"CUSTODIAN":"EMPLOYEE"})} className="rounded border px-3 py-2 text-sm disabled:opacity-50">{t(p.type==="EMPLOYEE"?"personCreation.addCustodian":"personCreation.addEmployee")}</button></li>)}</ul>}
 </section>;
}
