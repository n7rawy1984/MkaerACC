export type AllocationInput={method:'DIRECT'|'PERCENT'|'QUANTITY'|'INDIRECT';basis:string;support:string;driver:string|null;unit:string|null;destinations:{project_id:string|null;weight:string}[]};
export type AllocationPlan=Omit<AllocationInput,'destinations'>&{rounding:'LARGEST_REMAINDER_V1';weight_scale:number;destinations:{project_id:string|null;weight:string;amount_minor:string}[]};
export function allocationWeight(value:string,method:AllocationInput['method']):string{
 if(method==='DIRECT')return '1';const scale=method==='PERCENT'?2:6;
 if(!new RegExp('^\\d+(?:\\.\\d{1,'+scale+'})?$').test(value))throw Error('Invalid weight');
 const [whole,fraction='']=value.split('.'),weight=BigInt(whole)*10n**BigInt(scale)+BigInt(fraction.padEnd(scale,'0'));
 if(weight<=0n||weight>9000000000000000n)throw Error('Invalid weight');return weight.toString();
}
export function allocateSharedCost(amount:string,input:AllocationInput):AllocationPlan{
 if(!/^\d+$/.test(amount)||BigInt(amount)<=0n||!input.basis.trim()||!input.support.trim()||[...input.basis.trim()].length>500||[...input.support.trim()].length>500||!['DIRECT','PERCENT','QUANTITY','INDIRECT'].includes(input.method))throw Error('Documented basis required');
 if(['QUANTITY','INDIRECT'].includes(input.method)&&(!input.driver?.trim()||!input.unit?.trim()))throw Error('Driver and unit required');
 if((input.driver?.trim().length??0)>100||(input.unit?.trim().length??0)>50)throw Error('Driver too long');
 const ds=input.destinations;if(ds.length<1||ds.length>20||(input.method==='DIRECT'?ds.length!==1:ds.length<2)||new Set(ds.map(d=>d.project_id)).size!==ds.length)throw Error('Invalid destinations');
 if(ds.some(d=>d.project_id!==null&&!/^[0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}$/.test(d.project_id)||!/^\d{1,16}$/.test(d.weight)||BigInt(d.weight)<=0n||BigInt(d.weight)>9000000000000000n))throw Error('Invalid destination weight');
 const total=ds.reduce((n,d)=>n+BigInt(d.weight),0n);if(input.method==='PERCENT'&&total!==10000n||input.method==='DIRECT'&&total!==1n)throw Error('Percentages must total 100');
 const key=(id:string|null)=>id??'~',compare=(a:string,b:string)=>a<b?-1:a>b?1:0;
 const parts=ds.map(d=>({...d,weight:BigInt(d.weight).toString(),minor:BigInt(amount)*BigInt(d.weight)/total,remainder:BigInt(amount)*BigInt(d.weight)%total}));
 const residual=BigInt(amount)-parts.reduce((n,d)=>n+d.minor,0n);const ranked=[...parts].sort((a,b)=>a.remainder===b.remainder?compare(key(a.project_id),key(b.project_id)):a.remainder>b.remainder?-1:1);
 for(let i=0;i<Number(residual);i++)ranked[i].minor++;
 if(parts.some(d=>d.minor<=0n))throw Error('Allocation below one minor unit');
 return {...input,basis:input.basis.trim(),support:input.support.trim(),driver:input.driver?.trim()||null,unit:input.unit?.trim()||null,rounding:'LARGEST_REMAINDER_V1',weight_scale:input.method==='PERCENT'?100:input.method==='DIRECT'?1:1000000,destinations:parts.sort((a,b)=>compare(key(a.project_id),key(b.project_id))).map(d=>({project_id:d.project_id,weight:d.weight,amount_minor:d.minor.toString()}))};
}
export function weightDisplay(weight:string,scale:number):string{const w=BigInt(weight),s=BigInt(scale);return s===1n?w.toString():`${w/s}.${(w%s).toString().padStart(String(scale).length-1,'0')}`;}
