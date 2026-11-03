import {createContext,useContext} from 'react';
export interface CompanySubscription {company_id:string;state:string;plan_key:string;ends_on:string|null;renewal_due_on:string|null;access:'FULL'|'LIMITED'}
export interface CompanySubscriptionSnapshot {companyId:string;loaded:boolean;row:CompanySubscription|null}
export const WorkspaceSubscriptionContext=createContext<CompanySubscriptionSnapshot|null>(null);
export const useWorkspaceSubscription=()=>useContext(WorkspaceSubscriptionContext);
