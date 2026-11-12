import type {OverviewMonth} from './dashboardOverviewRead';
export function postedExpenseAmount(row:OverviewMonth):string|null{return row.values.operating===null||row.values.projectCost===null?null:String(BigInt(row.values.operating)+BigInt(row.values.projectCost));}
export function movementChartModel(rows:OverviewMonth[]){
 const values=rows.map(r=>[r.values.custodyFunding,r.values.custodyPayments,postedExpenseAmount(r)]),known=values.flat().filter((v):v is string=>v!==null).map(BigInt);
 const max=known.reduce((a,b)=>b>a?b:a,0n),min=known.reduce((a,b)=>b<a?b:a,0n),range=max-min||1n;
 const position=(n:bigint)=>Number((max-n)*10000n/range)/100;
 return{values,max,min,zero:position(0n),bar:(v:string)=>{const n=BigInt(v);return{top:position(n>0n?n:0n),height:Number((n<0n?-n:n)*10000n/range)/100};},empty:known.length>0&&known.every(v=>v===0n),restricted:values.some(v=>v.some(n=>n===null))};
}
export function compactAxisAmount(minor:bigint){const abs=minor<0n?-minor:minor,sign=minor<0n?'-':'';for(const[unit,label]of[[100000000000n,'b'],[100000000n,'m'],[100000n,'k']]as const)if(abs>=unit){const tenth=abs*10n/unit;return sign+String(tenth/10n)+(tenth%10n?'.'+String(tenth%10n):'')+label;}return sign+String(abs/100n)+(abs%100n?'.'+String(abs%100n).padStart(2,'0'):'');}
