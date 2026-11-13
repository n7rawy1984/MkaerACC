import type {SourceRecord} from './sourceModel';
import type {ProductionParty} from '../master/masterTypes';

/** Presentation only. An original supplier name is not a posted payable or a GL Party dimension. */
export function sourceCounterparty(source:Pick<SourceRecord,'company_id'|'record_type'|'completion'|'raw_source'>,parties:ProductionParty[]){
 const ids=['supplier_id','subcontractor_id','party_id'];
 const id=ids.map(k=>source.completion[k]).find(v=>typeof v==='string'&&v.trim());
 const party=typeof id==='string'?parties.find(p=>p.id===id&&p.companyId===source.company_id):undefined;
 const original=source.raw_source['Supplier (exact)'];
 const working=source.completion.party;
 const evidence=typeof working==='string'&&working.trim()?working.trim():typeof original==='string'?original.trim():'';
 return {name:party?.name||evidence||'—',partyId:party?.id??null,originalName:typeof original==='string'?original.trim():'',linked:!!party};
}
export function sourceSupplierId(source:Pick<SourceRecord,'company_id'|'record_type'|'completion'|'raw_source'>,parties:ProductionParty[]){
 const id=source.completion.supplier_id;
 return source.record_type==='GENERAL'&&typeof id==='string'&&parties.some(p=>p.id===id&&p.companyId===source.company_id&&p.type==='SUPPLIER'&&p.status==='ACTIVE')?id:'';
}
