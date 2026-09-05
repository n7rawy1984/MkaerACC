-- P6B: read-only tenant presentation settings. Company remains the tenant,
-- security, and accounting root; this owned child never authorizes access.

create table public.company_settings (
  company_id uuid primary key references public.companies (id) on delete cascade,
  tenant_slug text not null,
  app_display_name text,
  default_locale public.app_locale not null default 'en',
  logo_url text,
  favicon_url text,
  primary_color text not null default '#0f172a',
  accent_color text not null default '#2563eb',
  created_at timestamptz not null default now(),
  created_by uuid references auth.users (id) on delete set null,
  updated_at timestamptz not null default now(),
  updated_by uuid references auth.users (id) on delete set null,
  constraint company_settings_slug_canonical check (
    tenant_slug = lower(tenant_slug)
    and length(tenant_slug) between 3 and 63
    and tenant_slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
  ),
  constraint company_settings_display_name_valid check (
    app_display_name is null
    or (app_display_name = btrim(app_display_name) and length(app_display_name) between 1 and 200)
  ),
  constraint company_settings_logo_url_valid check (
    logo_url is null
    or (logo_url = btrim(logo_url) and length(logo_url) <= 2048 and logo_url ~ '^https://[^[:space:]]+$')
  ),
  constraint company_settings_favicon_url_valid check (
    favicon_url is null
    or (favicon_url = btrim(favicon_url) and length(favicon_url) <= 2048 and favicon_url ~ '^https://[^[:space:]]+$')
  ),
  constraint company_settings_primary_color_valid check (primary_color ~ '^#[0-9A-Fa-f]{6}$'),
  constraint company_settings_accent_color_valid check (accent_color ~ '^#[0-9A-Fa-f]{6}$')
);

create unique index company_settings_tenant_slug_unique_ci
  on public.company_settings (lower(tenant_slug));

comment on table public.company_settings is
  'P6B Company-owned presentation configuration. Slug and branding never authorize tenant or accounting access.';
comment on column public.company_settings.tenant_slug is
  'Stable routing/display metadata only; never an authorization or accounting-reference input.';

-- Always suffix the normalized code with deterministic UUID material. This
-- remains collision-safe even when distinct Company codes normalize equally.
insert into public.company_settings (company_id, tenant_slug)
select
  c.id,
  left(
    coalesce(
      nullif(trim(both '-' from regexp_replace(lower(btrim(c.code)), '[^a-z0-9]+', '-', 'g')), ''),
      'tenant'
    ),
    54
  ) || '-' || left(replace(c.id::text, '-', ''), 8)
from public.companies c
order by c.id;

create trigger company_settings_set_updated_at
  before update on public.company_settings
  for each row execute function public.set_updated_at();

alter table public.company_settings enable row level security;
alter table public.company_settings force row level security;

create policy company_settings_read_active_membership on public.company_settings
  for select to authenticated
  using (public.is_company_member(company_id));

revoke all on table public.company_settings from public, anon, authenticated;
grant select on table public.company_settings to authenticated;

grant select, insert, update on table public.company_settings to service_role;
revoke delete on table public.company_settings from service_role;
