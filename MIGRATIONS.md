# MIGRATIONS.md — Running & Maintaining Migrations

## Order
Migrations are numbered and must be applied in order:

1. `0001_extensions.sql`
2. `0002_helper_functions.sql`
3. `0003_schema_core.sql`
4. `0004_schema_onchain.sql`
5. `0005_schema_audit_health.sql`
6. `0006_rls.sql`
7. `0007_storage.sql`
8. `0008_seed.sql` (no-op placeholder — contains no fake data by design)
9. `0009_schema_production.sql` (normalized production schema)
10. `0010_rls_production.sql` (RLS for normalized schema)
11. `0011_storage_production.sql` (private education materials)
12. `0012_schema_hardening.sql` (reorg history, reconciliation, security events, append-only enforcement)
13. `0013_auth_challenges.sql` (server-only wallet authentication challenge ledger used by `celoht-backend`)

## Applying to a clean Supabase project
Using the Supabase CLI:

```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

Or, without the CLI, run each root-level SQL file in order through the
Supabase SQL editor. CI runs them against PostgreSQL with `ON_ERROR_STOP=1`.

## Reproducibility guarantee
A brand-new Supabase project, given only this repository, must be able to
reach the exact same schema, RLS policy set, and storage bucket
configuration as production. No manual dashboard click-ops are required or
assumed. If you make a manual change in the dashboard, you must capture it
as a new numbered migration file before it is considered part of the schema.

## Adding a new migration
- Never edit a migration that has already been applied to any shared
  environment (staging/production). Add a new numbered file instead.
- Keep each migration focused (schema OR RLS OR storage OR data), matching
  the existing file boundaries, so review stays tractable.

CI applies every migration with `ON_ERROR_STOP=1` and runs
`tests/database.sql`. A disposable Supabase project remains a required
pre-production check because local PostgreSQL does not reproduce every
Supabase-managed grant and storage implementation detail.
