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
  0017_indexer_notification_lineage.sql checkpoint and notification lineage
  0018_grants_and_function_security.sql explicit Data API grants and function security
  0019_client_privilege_hardening.sql revoke client writes to server-owned tables
  0020_indexer_contract_compatibility.sql indexer checkpoint RPC and transaction index

Core documentation is kept at the repository root. Supporting plans and audit
artifacts are kept under `docs/`.
```

## Quick start

The migrations are stored in the repository root, not in
`supabase/migrations/`. To apply them with the Supabase SQL Editor, run the SQL
files in order from `0001` through `0020`.

For local verification:

```bash
npm run validate
npm run verify:postgres
```

For a Supabase project with CLI/configuration setup, use the CI pipeline or
adapt the migrations to the `supabase/migrations/` structure before running
`supabase db push`.

See [MIGRATIONS.md](MIGRATIONS.md) for more details, and read [RLS.md](RLS.md)
before granting any role access in a real project.

Notification infrastructure is represented by the durable database contract in
`0014`-`0016`. The API, indexer worker, push dispatcher, and deployment runtime
remain separate repositories (`celoht-backend` and `celoht-indexer`) and are not
present in this schema-only checkout.

## Network status

Celo-HaiTi's on-chain contracts currently exist on **Celo Sepolia** (chain ID
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
- [ ] Verify current backend/indexer source against a real Supabase staging project.
- [ ] Verify official Sepolia deployment metadata and ABI at runtime.

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
