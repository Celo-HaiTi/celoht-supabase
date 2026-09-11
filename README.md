# celoht-supabase

Supabase/PostgreSQL infrastructure used by `celoht-backend` and
`celoht-indexer`.

This repository contains reproducible SQL migrations, RLS policies, private
storage configuration, validation, and documentation. It contains no
application code, production credentials, or fake application data.

## Contents

```
SQL migrations (repository root):
  0001_extensions.sql
  0002_helper_functions.sql
  0003_schema_core.sql        profiles, agents, KYC, education
  0004_schema_onchain.sql     indexer-owned on-chain tables
  0005_schema_audit_health.sql
  0006_rls.sql                Row Level Security for every table
  0007_storage.sql            buckets + storage policies
  0008_seed.sql               intentionally empty — no fake data
  0009_schema_production.sql  normalized production entities
  0010_rls_production.sql     deny-by-default RLS for new entities
  0011_storage_production.sql private education materials
  0012_schema_hardening.sql   reorg, reconciliation, and audit hardening
  0013_auth_challenges.sql    backend-owned wallet nonce/challenge ledger
  0014_notifications.sql     durable notification and transaction data layer
  0015_notifications_rls.sql notification access and admin announcement RLS
  0016_auth_predicate_hardening.sql legacy auth predicate cleanup

Core documentation is kept at the repository root. Supporting plans and audit
artifacts are kept under `docs/`.
```

## Quick start

Migrations yo nan rasin repo a, se pa nan `supabase/migrations/`. Pou aplike
yo ak Supabase SQL Editor, kouri fichye SQL yo nan lòd `0001` rive `0012`.

Pou verifikasyon lokal:

```bash
npm run validate
```

Pou yon pwojè Supabase ki gen CLI/configuration setup, itilize pipeline CI a
oswa adapte migration yo nan estrikti `supabase/migrations/` anvan ou kouri
`supabase db push`.

Gade [MIGRATIONS.md](MIGRATIONS.md) pou plis detay epi li [RLS.md](RLS.md)
anvan ou bay nenpòt aksè role nan yon pwojè reyèl.

Notification infrastructure is represented by the durable database contract in
`0014`-`0016`. The API, indexer worker, push dispatcher, and deployment runtime
remain separate repositories (`celoht-backend` and `celoht-indexer`) and are not
present in this schema-only checkout.

## Network status

CeloHT's on-chain contracts currently exist on **Celo Sepolia** (chain ID
`11142220`). This schema does not hardcode any contract address — those are
loaded at runtime by `celoht-indexer` from
`Celo-HaiTi/celoht-smart-contracts` deployment metadata. Mainnet
(`42220`) integration fails closed until that repository publishes an
official Mainnet deployment file.

## Verification status

- [x] Migrations have deterministic static validation and CI PostgreSQL execution.
- [x] Every application table has RLS enabled with explicit policies.
- [x] Sensitive storage buckets (`agent-kyc`, `reforestation-evidence`,
  `certificates`, `education-materials`) are private with no public-URL path.
- [x] `audit_logs` has no update/delete policy for any role.
- [x] No secrets, private keys, or fake data are present in this repository.
- [ ] Apply and verify against a disposable Supabase project.
- [ ] Independent security review before production use.

## Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md)
- [DATABASE.md](DATABASE.md)
- [DATA_MODEL.md](DATA_MODEL.md)
- [DEPLOYMENT.md](DEPLOYMENT.md)
- [INDEXER_SCHEMA.md](INDEXER_SCHEMA.md)
- [RLS.md](RLS.md)
- [SECURITY.md](SECURITY.md)
- [STORAGE.md](STORAGE.md)
- [SCHEMA.md](SCHEMA.md)
- [DATA_PROVENANCE.md](DATA_PROVENANCE.md)
- [BACKUP_RECOVERY.md](BACKUP_RECOVERY.md)
- [OPERATIONS.md](OPERATIONS.md)
- [NOTIFICATIONS.md](NOTIFICATIONS.md)
- [RLS test plan](docs/RLS_TEST_PLAN.md)

## Next phases

- Phase 2: `celoht-backend` (application API, wallet auth, authorization).
- Phase 3: `celoht-indexer` (blockchain synchronization into this schema).
