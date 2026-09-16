-- PREPARED / NOT EXECUTED. MakerACC-Development only; NOT a migration.
begin transaction read only;
select id,code,name,type,created_by,updated_by,updated_at from public.parties where company_id='76100000-0000-4000-8000-0000000000a1' order by code;
select count(*) as total, count(*) filter(where lower(btrim(code))='race') as competing_create_rows,
 count(*) filter(where id='76100000-0000-4000-8000-0000000000f1' and name in ('Editor 1','Editor 2') and updated_at>'2000-01-01T00:00:00Z'::timestamptz) as edited_rows
from public.parties where company_id='76100000-0000-4000-8000-0000000000a1';
-- Required total=2, competing_create_rows=1, edited_rows=1, plus saved session counts 1/0.
-- Record the generated RACE UUID for cleanup; do not infer concurrency PASS from names alone.
rollback;
