import {sourceDirection,type SourceRecord} from './sourceModel';
// Payment-source confirmation is independent of an imported outflow claim.
export function sourcePaymentState(row:SourceRecord):'PAID'|'RECEIVED'|'UNCONFIRMED'|'NO_CASH'|'DOCUMENTED'{
 if(row.source_document?.state==='POSTED')return 'DOCUMENTED';
 const direction=sourceDirection(row);
 if(direction==='NONE')return 'NO_CASH';
 if(!row.cash_treasury_id)return 'UNCONFIRMED';
 return direction==='OUT'?'PAID':'RECEIVED';
}
export function sourceDuplicateCandidate(row:SourceRecord):string|null{
 if(row.classification.potential_duplicate!==true)return null;
 const candidate=row.classification.duplicate_candidate_source_reference;
 return typeof candidate==='string'&&candidate.trim()?candidate:null;
}
