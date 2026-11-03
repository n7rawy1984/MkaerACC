import type {CompanySubscriptionSnapshot} from './workspaceSubscriptionContext';
// Presentation of the existing verified subscription result, never an authorization grant.
export function workspaceBusinessAccess(snapshot:CompanySubscriptionSnapshot|null,companyId:string):'FULL'|'LIMITED'|'UNKNOWN'{return snapshot?.loaded&&snapshot.companyId===companyId&&snapshot.row?.company_id===companyId?snapshot.row.access:'UNKNOWN';}
