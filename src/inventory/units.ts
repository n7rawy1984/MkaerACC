// Exact quantity previews only. Database-authorized material ratios remain authoritative.
export type UnitRatios=Record<string,{numerator:string;denominator:string}>;
export function baseQuantity(quantityMicros:string,unit:string,base:string,ratios:UnitRatios):string{
 if(!/^\d{1,16}$/.test(quantityMicros))throw Error('UOM_QUANTITY');const q=BigInt(quantityMicros);const r=unit===base?{numerator:'1',denominator:'1'}:ratios[unit];if(!r)throw Error('UOM_APPROVAL');const n=q*BigInt(r.numerator),d=BigInt(r.denominator);if(d<=0n||n%d!==0n||n/d>9000000000000000n)throw Error('UOM_PRECISION');return(n/d).toString();
}
