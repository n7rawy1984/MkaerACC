import { useEffect, useRef, useState, type FormEvent } from "react";
import { useAuth } from "../auth/AuthContext";
import { useT } from "../i18n/I18nContext";
import { Field, inputClassName } from "../components/ui/Field";
import { getSupabaseClient } from "../lib/supabase";
import { useProductionMasterData } from "./productionMasterDataContext";
import { eligibleTreasuryAccounts, mutateTreasuryMaster } from "./treasuryMasterRepository";

export function TreasuryMasterPanel() {
 const {state}=useAuth();
 if(state.phase!=="TENANT_READY"||state.activeTenant.role!=="ACCOUNTING_ADMIN")return null;
 return <TreasuryMasterForm key={`${state.profile.userId}:${state.activeTenant.companyId}:${state.activeTenant.role}`}/>;
}
function TreasuryMasterForm() {
 const {state}=useAuth(),master=useProductionMasterData(),t=useT();
 const [open,setOpen]=useState(false),[busy,setBusy]=useState(false),[message,setMessage]=useState("");
 const lock=useRef(false),live=useRef(true),origin=useRef<HTMLButtonElement>(null);
 useEffect(()=>{live.current=true;return()=>{live.current=false;};},[]);
 if(state.phase!=="TENANT_READY"||master.phase!=="READY")return null;
 const companyId=state.activeTenant.companyId,userId=state.profile.userId;
 const accounts=eligibleTreasuryAccounts(master.accounts,master.treasuryAccounts,companyId);
 const blocked=busy||["uncertain","refreshError","conflict"].includes(message)||master.treasuryNameMutation.phase!=="IDLE"&&master.treasuryNameMutation.phase!=="SAVED";
 const close=()=>{setOpen(false);queueMicrotask(()=>origin.current?.focus());};
 const save=async(command:Parameters<typeof mutateTreasuryMaster>[2])=>{
  if(lock.current||blocked)return;lock.current=true;setBusy(true);setMessage("");
  try {
   const client=getSupabaseClient(),session=await client.auth.getSession();
   if(session.error||session.data.session?.user.id!==userId){if(live.current)setMessage("denied");return;}
   const result=await mutateTreasuryMaster(client,companyId,command);
   if(!live.current)return;
   if(!result.ok){setMessage(result.error);return;}
   if(!await master.refreshTreasuryAccounts()){if(live.current)setMessage("refreshError");return;}
   if(live.current){setMessage("saved");close();}
  }catch{if(live.current)setMessage("uncertain");}finally{lock.current=false;if(live.current)setBusy(false);}
 };
 const submit=(event:FormEvent<HTMLFormElement>)=>{
  event.preventDefault();const input=Object.fromEntries(new FormData(event.currentTarget).entries()) as Record<string,string>;
  for(const key of Object.keys(input))input[key]=input[key].trim();
  if(!input.name||!input.code||!accounts.some(a=>a.id===input.gl_account_id)){setMessage("invalid");return;}
  void save({kind:"create",input});
 };
 const recover=async()=>{
  if(lock.current)return;lock.current=true;setBusy(true);close();
  const committed=message==="refreshError";
  try {const ok=await master.refreshTreasuryAccounts();if(live.current)setMessage(ok?committed?"saved":"review":committed?"refreshError":"uncertain");}
  catch{if(live.current)setMessage(committed?"refreshError":"uncertain");}finally{lock.current=false;if(live.current)setBusy(false);}
 };
 return <section className="mt-4 min-w-0 space-y-3">
  <button ref={origin} disabled={blocked||open} onClick={()=>{setMessage("");setOpen(true);}} className="rounded-lg border px-3 py-2 text-sm disabled:opacity-50">{t("treasuryMaster.create")}</button>
  {message&&<p role={message==="saved"?"status":"alert"} className="break-words text-sm">{t(`treasuryMaster.${message}` as never)}</p>}
  {busy&&<p role="status">{t("supplierMutation.pending")}</p>}
  {["uncertain","refreshError","conflict"].includes(message)&&<button disabled={busy} onClick={()=>void recover()} className="underline">{t("treasuryName.refresh")}</button>}
  {open&&<form aria-label={t("treasuryMaster.create")} onSubmit={submit} className="min-w-0 space-y-3 rounded-lg border p-4">
   <p className="text-sm">{t("treasuryMaster.permanent")}</p>
   <fieldset disabled={blocked} className="grid min-w-0 gap-3 sm:grid-cols-2">
    <Field label={t("supplierMutation.name")} required><input autoFocus name="name" required maxLength={200} className={inputClassName}/></Field>
    <Field label={t("personCreation.code")} required><input name="code" dir="ltr" required maxLength={50} className={inputClassName}/></Field>
    <Field label={t("treasuryMaster.type")} required><select name="type" className={inputClassName}>{(["CASH","PETTY_CASH","BANK","PROJECT_CASH_BOX","PROJECT_BANK"] as const).map(type=><option key={type} value={type}>{t(`treasuryType.${type}`)}</option>)}</select></Field>
    <Field label={t("productionMaster.permanentGlAccount")} required><select name="gl_account_id" defaultValue="" required className={inputClassName}><option value="">{t("treasuryMaster.selectGl")}</option>{accounts.map(a=><option key={a.id} value={a.id}>{a.code} · {a.name}</option>)}</select></Field>
    <Field label={t("productionMaster.projectId")}><select name="project_id" className={inputClassName}><option value="">{t("treasuryMaster.companyWide")}</option>{master.projects.filter(p=>p.companyId===companyId&&p.status!=="CLOSED").map(p=><option key={p.id} value={p.id}>{p.code} · {p.name}</option>)}</select></Field>
    <Field label={t("common.status")}><select name="status" className={inputClassName}>{(["ACTIVE","INACTIVE"] as const).map(s=><option key={s} value={s}>{t(`partyStatus.${s}`)}</option>)}</select></Field>
    <Field label={t("productionMaster.bankName")}><input name="bank_name" className={inputClassName}/></Field>
    <Field label={t("productionMaster.accountReference")}><input name="account_reference" className={inputClassName}/></Field>
    <Field label={t("common.notesOptional")}><textarea name="notes" className={inputClassName}/></Field>
    {!accounts.length&&<p role="status" className="text-sm">{t("treasuryMaster.noGl")}</p>}
    <button type="submit" disabled={!accounts.length} className="rounded-lg bg-[var(--tenant-primary)] px-4 py-2 text-white disabled:opacity-50">{t("supplierMutation.save")}</button>
   </fieldset>
   <button type="button" disabled={busy} onClick={close} className="underline">{t("supplierMutation.close")}</button>
  </form>}
  {!!master.treasuryAccounts.length&&<form aria-label={t("treasuryMaster.changeStatus")} className="min-w-0 space-y-3 rounded-lg border p-4" onSubmit={event=>{
   event.preventDefault();const fields=new FormData(event.currentTarget),treasury=master.treasuryAccounts.find(row=>row.companyId===companyId&&row.id===fields.get("treasury"));
   if(treasury)void save({kind:"status",treasury,status:fields.get("status") as "ACTIVE"|"INACTIVE"});
  }}><fieldset disabled={blocked} className="min-w-0 space-y-3">
   <Field label={t("treasuryMaster.changeStatus")} required><select name="treasury" required defaultValue="" className={inputClassName}><option value="">{t("treasuryMaster.selectTreasury")}</option>{master.treasuryAccounts.filter(row=>row.companyId===companyId).map(row=><option key={row.id} value={row.id}>{row.code} · {row.name} · {t(`partyStatus.${row.status}`)}</option>)}</select></Field>
   <Field label={t("common.status")}><select name="status" className={inputClassName}>{(["ACTIVE","INACTIVE"] as const).map(s=><option key={s} value={s}>{t(`partyStatus.${s}`)}</option>)}</select></Field>
   <label className="flex items-start gap-2 text-sm"><input type="checkbox" required/>{t("treasuryMaster.confirmStatus")}</label>
   <button type="submit" className="rounded-lg border px-3 py-2 text-sm">{t("treasuryMaster.changeStatus")}</button>
  </fieldset></form>}
 </section>;
}
