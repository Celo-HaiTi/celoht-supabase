# Deployment and Recovery

## Prerequisites

- Supabase CLI authenticated to the target project.
- A reviewed backup and a maintenance window for production DDL.
- Secrets supplied by the deployment platform, never committed to this repo.

## Apply migrations

```bash
supabase link --project-ref "$SUPABASE_PROJECT_REF"
supabase db push
```

Migrations are immutable after they reach a shared environment. Add a new
numbered migration for every change. Validate against a disposable project
before production.

## Recovery

Use Supabase point-in-time recovery or a tested PostgreSQL backup. Restore the
database before restarting backend/indexer consumers, then verify migration
status, RLS, storage bucket privacy, and indexer checkpoints. Re-run indexer
backfills from the official deployment block after chain/reorg review.

## Operational requirements

- Keep `SUPABASE_SERVICE_ROLE_KEY` only in backend/indexer secret stores.
- Configure `celoht-indexer` from the official smart-contract deployment
  manifest and upsert events by chain, transaction hash, and log index.
- Treat `orphaned` observations as non-authoritative after reorg handling.
- Review audit and health records independently of application traffic.