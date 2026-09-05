-- P6B forward correction: the original eight-character UUID fragment made a
-- collision improbable, not impossible. A full Company UUID makes the suffix
-- deterministically unique while the bounded normalized prefix keeps the slug
-- within the approved 63-character limit.

update public.company_settings s
set tenant_slug = left(
  coalesce(
    nullif(trim(both '-' from regexp_replace(lower(btrim(c.code)), '[^a-z0-9]+', '-', 'g')), ''),
    'tenant'
  ),
  26
) || '-' || c.id::text
from public.companies c
where c.id = s.company_id;
