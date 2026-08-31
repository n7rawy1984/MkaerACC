# Maker Contracting Accounting System

React/Vite frontend for a UAE contracting accounting system. The current application still uses the localStorage demo adapter. Production Supabase integration is being introduced in controlled batches; P2 now provides a Development-applied and remotely verified Auth/profile/company-membership/role foundation.

## Frontend

```bash
npm install
npm run dev
npm run build
npm run lint
```

The existing Vercel SPA rewrite remains in `vercel.json`.

## Supabase CLI

The CLI is pinned as a development dependency, so use the repository version:

```bash
npx supabase --version
```

Do not depend on an untracked global CLI.

## Canonical migration workflow

Migrations in `supabase/migrations/` are the only schema history. They are forward-only, timestamped, committed to Git, and promoted unchanged:

```text
Development → Staging → Production
```

Create a migration:

```bash
npm run db:new -- descriptive_name
```

Edit the generated SQL, review it, and test it against a disposable local database or the linked remote Development project. Never make a dashboard-only schema change; if an emergency/manual change occurs, immediately capture and review the equivalent migration before any promotion.

Rollback in shared environments means a new corrective forward migration. `db reset` is only for disposable local Development data.

### Local Development database

The local Supabase stack requires a running Docker-compatible container runtime:

```bash
npx supabase start
npx supabase migration list --local
npx supabase db reset
npx supabase stop
```

`db reset` rebuilds the disposable local database from committed migrations. P1 disables `db.seed`, so it does not load frontend demo data. If Docker is unavailable, do not run or claim local database verification; use a separately provisioned remote Development project once its credentials are approved.

### Remote environments

Development, Staging, and Production are separate Supabase projects. Never create Production until region, data-location expectations, plan, backups/PITR, RPO, and RTO are confirmed.

Authenticate and link one environment at a time without committing credentials:

```bash
npx supabase login
npx supabase link --project-ref <environment-project-ref>
npx supabase migration list --linked
npx supabase db push --dry-run
npx supabase db push
```

Use a clean checkout/CI job per environment so a stale local link cannot target the wrong project. Apply and verify Development first, then Staging. Production requires explicit approval, backup confirmation, reviewed dry-run output, and post-migration checks.

Supabase stores local link state under ignored `supabase/.temp/`. Access tokens, database passwords, service-role keys, and project references must remain in developer/CI secret storage.

## Environment variables and secrets

Copy `.env.example` to an ignored environment-specific local file only when needed. P6A supports explicit `local-demo` (Vite development only) and `supabase-auth` modes.

- `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY` are the public browser configuration used only by `supabase-auth`.
- Every `VITE_*` value is browser-visible.
- Database passwords, management access tokens, secret/service-role keys, and other privileged credentials must never use a `VITE_*` name or enter the frontend bundle.
- Before enabling `supabase-auth` on Vercel, configure those two public values and `VITE_APP_DATA_MODE=supabase-auth`. Privileged values belong exclusively in protected server/CI secrets.
- Production fails explicitly if its mode or Auth configuration is unavailable; it never falls back to localStorage accounting.

## Seed policy

`supabase/config.toml` has automatic database seeding disabled.

- Development/Test may gain a separate, explicitly invoked synthetic seed later.
- Staging receives only test/rehearsal data intentionally loaded for that environment.
- Production never automatically receives demo companies, projects, transactions, historical frontend seed data, or opening balances.

## P2 identity boundary

P2 adds the Auth-linked profile lifecycle, a minimum company identity parent, memberships, frozen roles, centrally mapped permissions, authorization helpers, and a least-privilege RLS baseline. It was applied and verified against the synthetic-only Development project. Operational details and the authorization matrix are in `docs/P2_AUTHORIZATION.md`; generated public-schema types are in `src/types/database.generated.ts`.

The frontend remains the localStorage demo application: it does not consume Supabase credentials or imply that demo books belong to an authenticated company. P3 now provides verified backend master data, but does not add accounting transactions/RPCs, Storage buckets, data migration, or frontend cutover.
