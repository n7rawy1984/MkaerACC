import{readFileSync}from'node:fs';
import{partyStatementFixture}from'./party-statement-fixture.mjs';
export async function custodyReconciliationFixture(){const f=await partyStatementFixture();for(const file of['20261104150000_project_lifecycle.sql','20261104160000_project_closure.sql'])await f.db.exec(readFileSync('supabase/migrations/'+file,'utf8'));await f.as(f.admin,"select public.add_party_person_role($1,$2,'CUSTODIAN')",[f.company,f.person]);return f;}
