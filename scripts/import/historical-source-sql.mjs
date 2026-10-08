// Trusted operator source import only. No Auth impersonation or financial mutation.
import { readFileSync, writeFileSync } from 'node:fs';
const [payloadPath, company, code, operator, output] = process.argv.slice(2);
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
if (!uuid.test(company ?? '') || !uuid.test(operator ?? '') || !code || !output) throw Error('Usage: payload.json company_uuid company_code operator_uuid output.sql');
const records = JSON.parse(readFileSync(payloadPath, 'utf8'));
if (!Array.isArray(records) || records.length < 1 || records.length > 10000) throw Error('Invalid payload');
const json = JSON.stringify(records).replaceAll("'", "''");
let delimiter = '$source_import$'; while (json.includes(delimiter)) delimiter = delimiter.replace('$source_import', '$source_import_');
const q = s => `'${s.replaceAll("'", "''")}'`;
writeFileSync(output, `begin;
set local standard_conforming_strings=on;
do ${delimiter}
declare target uuid:=${q(company)}; operator_id uuid:=${q(operator)}; payload jsonb:='${json}'::jsonb;
 expected_count integer:=jsonb_array_length(payload); actual_count integer;
begin
 if current_user in ('anon','authenticated','service_role') then raise exception 'Protected operator connection required'; end if;
 perform 1 from private.system_administrators a join public.profiles p on p.user_id=a.user_id
  where a.user_id=operator_id and a.status='ACTIVE' and p.status='ACTIVE' for share of a,p;
 if not found then raise exception 'Active registered operator required'; end if;
 perform 1 from public.companies where id=target and code=${q(code)} and status='ACTIVE' for share;
 if not found then raise exception 'Approved Company mismatch'; end if;
 perform pg_advisory_xact_lock(hashtextextended(target::text || ':historical-source-import',0));
 if (select count(distinct (v->>'source_file',v->>'source_reference')) from jsonb_array_elements(payload) v)<>expected_count then
  raise exception 'Duplicate payload identities'; end if;
 insert into public.historical_source_records(company_id,source_file,source_hash,source_reference,record_type,source_month,source_date,description,outflow_minor,funding_minor,payroll_net_minor,raw_source,classification,created_by)
 select target,r.source_file,r.source_hash,r.source_reference,r.record_type,r.source_month,r.source_date,r.description,r.outflow_minor,r.funding_minor,r.payroll_net_minor,r.raw_source,r.classification,operator_id
 from jsonb_to_recordset(payload) as r(source_file text,source_hash text,source_reference text,record_type text,source_month text,source_date date,description text,outflow_minor bigint,funding_minor bigint,payroll_net_minor bigint,raw_source jsonb,classification jsonb)
 on conflict(company_id,source_file,source_reference) do nothing;
 -- Replays must match all immutable evidence; never overwrite completed review work.
 select count(*) into actual_count from jsonb_array_elements(payload) p
 join public.historical_source_records h on h.company_id=target and h.source_file=p->>'source_file' and h.source_reference=p->>'source_reference'
 where h.source_hash=p->>'source_hash' and h.raw_source=p->'raw_source' and h.classification=p->'classification'
 and h.record_type=p->>'record_type' and h.source_month=p->>'source_month'
 and h.source_date is not distinct from (p->>'source_date')::date and h.description=p->>'description'
 and h.outflow_minor is not distinct from (p->>'outflow_minor')::bigint
 and h.funding_minor is not distinct from (p->>'funding_minor')::bigint
 and h.payroll_net_minor is not distinct from (p->>'payroll_net_minor')::bigint;
 if actual_count<>expected_count then raise exception 'Existing source conflict; entire import rolled back'; end if;
end;
${delimiter};
select record_type,source_month,count(*) as source_count,sum(outflow_minor)::text as outflow_minor,sum(funding_minor)::text as funding_minor,sum(payroll_net_minor)::text as payroll_net_minor
 from public.historical_source_records where company_id=${q(company)} group by record_type,source_month order by record_type,source_month;
commit;
`, { mode: 0o600 });
console.log('Protected source-only SQL generated; no database mutation.');
