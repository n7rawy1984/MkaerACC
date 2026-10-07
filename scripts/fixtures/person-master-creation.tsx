import { createRoot } from "react-dom/client";
import { useState } from "react";
import { AuthProvider, useAuth } from "../../src/auth/AuthContext";
import { ProductionMasterDataProvider } from "../../src/master/ProductionMasterDataProvider";
import { I18nProvider } from "../../src/i18n/I18nContext";
import { LanguageButton } from "../../src/auth/AuthFrame";
import { PartiesList } from "../../src/master/PartiesList";
import { ProjectsList } from "../../src/master/ProjectsList";
import { client } from "./person-master-creation-client";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../../src/types/database.generated";
import "/src/index.css";
export function Fixture() {
 const {state}=useAuth(); const [view,setView]=useState("parties");
 if(state.phase!=="TENANT_READY") return <p>{state.phase}</p>;
 return <><LanguageButton/><button onClick={()=>setView(view==="parties"?"subcontracts":"parties")}>Switch workspace</button><p>Role: {state.activeTenant.role}</p><ProductionMasterDataProvider key={`${state.activeTenant.companyId}:${state.activeTenant.role}`} client={client as unknown as SupabaseClient<Database>} userId={state.profile.userId} role={state.activeTenant.role} activeCompanyId={state.activeTenant.companyId}>{view==="parties"?<PartiesList/>:<ProjectsList/>}</ProductionMasterDataProvider></>;
}
localStorage.setItem("cas:v1:locale","en");
createRoot(document.getElementById("root")!).render(<I18nProvider><AuthProvider client={client as unknown as SupabaseClient<Database>}><Fixture/></AuthProvider></I18nProvider>);
