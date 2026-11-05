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
14. `0014_notifications.sql` (durable notifications, monitored transactions, announcements, preferences, and push delivery state)
15. `0015_notifications_rls.sql` (notification access policies and announcement administration permissions)
16. `0016_auth_predicate_hardening.sql` (remove previous `auth.role()` authorization predicates)
17. `0017_indexer_notification_lineage.sql` (durable worker checkpoint metadata and notification event lineage)
18. `0018_grants_and_function_security.sql` (explicit Data API privileges and SECURITY DEFINER boundaries)
19. `0019_client_privilege_hardening.sql` (remove client writes to server-owned tables)
20. `0020_indexer_contract_compatibility.sql` (checkpoint RPC and transaction index compatibility)
21. `0021_canonical_pilot_completion.sql` (verified wallet guards, quizzes, and auditable planting evidence review)
22. `0022_atomic_indexer_checkpoint_compatibility.sql` (require both checkpoint ledgers to advance atomically)

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

Run the complete local disposable PostgreSQL check with Docker:

```bash
npm run validate
npm run verify:postgres
```

CI applies every migration with `ON_ERROR_STOP=1` and runs
`tests/database.sql`. A disposable Supabase project remains a required
pre-production check because local PostgreSQL does not reproduce every
Supabase-managed grant and storage implementation detail.

## Migration 0021 rollout and rollback
Before applying `0021`, verify that no primary wallet is unverified and every
existing `agent_profiles.wallet_identity_id` belongs to that applicant and has
`verified_at` set. The migration fails with a preflight error if either
condition is not met; reconcile these records through the verified backend
workflow rather than fabricating verification timestamps.

The migration is additive to the canonical history. Its evidence-review
records are append-only and quiz attempts/answers may become user data, so
rollback must not drop their tables after they contain records. Prefer a
forward corrective migration. If a rollback is unavoidable before pilot data
exists, disable new client writes first, archive the new tables, and remove
the new policies/functions/constraints only in a reviewed migration. Never
rewrite `0001`-`0020` or delete audit/review history to make a rollback pass.
