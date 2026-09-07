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

Documentation is kept at the repository root.
```

## Quick start

```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

Run `npm run validate`. See `MIGRATIONS.md` for details and `RLS.md` before granting any
role access in a real project.

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
      `certificates`) are private with no public-URL path.
- [x] `audit_logs` has no update/delete policy for any role.
- [x] No secrets, private keys, or fake data are present in this repository.
- [ ] Apply and verify against a disposable Supabase project.
- [ ] Independent security review before production use.

## Next phases

- Phase 2: `celoht-backend` (application API, wallet auth, authorization).
- Phase 3: `celoht-indexer` (blockchain synchronization into this schema).
