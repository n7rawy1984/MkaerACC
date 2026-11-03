import type {ExpenseRead} from '../financial/expenseRepository';
// Read-only presentation of the already authorized current page; never a Company balance.
export function expensePageSummary(rows:readonly ExpenseRead[]){const posted=rows.filter(r=>r.status==='POSTED');return {count:posted.length,net:posted.reduce((n,r)=>n+BigInt(r.net_amount_minor),0n).toString(),gross:posted.reduce((n,r)=>n+BigInt(r.gross_amount_minor),0n).toString()};}
