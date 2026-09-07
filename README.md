# celoht-supabase

Phase 1 of the CeloHT production infrastructure: the Supabase database
foundation used by `celoht-backend` and `celoht-indexer`.

This repository contains **schema only** — reproducible SQL migrations, RLS
policies, storage bucket configuration, and documentation. It intentionally
contains no application code and no seeded production data.

## Contents

```
migrations/
  0001_extensions.sql
  0002_helper_functions.sql
  0003_schema_core.sql        profiles, agents, KYC, education
  0004_schema_onchain.sql     indexer-owned on-chain tables
  0005_schema_audit_health.sql
  0006_rls.sql                Row Level Security for every table
  0007_storage.sql            buckets + storage policies
  0008_seed.sql               intentionally empty — no fake data
docs/
  DATABASE.md
  RLS.md
  STORAGE.md
  SECURITY.md
  AUTHORIZATION.md
  INDEXER_SCHEMA.md
  BACKEND_INTEGRATION.md
  MIGRATIONS.md
  OWNERSHIP.md
```

## Quick start

```bash
supabase link --project-ref <your-project-ref>
supabase db push
```

See `docs/MIGRATIONS.md` for details and `docs/RLS.md` before granting any
role access in a real project.

## Network status

CeloHT's on-chain contracts currently exist on **Celo Sepolia** (chain ID
`11142220`). This schema does not hardcode any contract address — those are
loaded at runtime by `celoht-indexer` from
`Celo-HaiTi/celoht-smart-contracts` deployment metadata. Mainnet
(`42220`) integration fails closed until that repository publishes an
official Mainnet deployment file.

## Verification status (Phase 1)

- [x] Migrations apply cleanly to an empty Supabase project.
- [x] Every application table has RLS enabled with explicit policies.
- [x] Sensitive storage buckets (`agent-kyc`, `reforestation-evidence`,
      `certificates`) are private with no public-URL path.
- [x] `audit_logs` has no update/delete policy for any role.
- [x] No secrets, private keys, or fake data are present in this repository.
- [ ] Independent security review (recommended before production use).

## Next phases

- Phase 2: `celoht-backend` (application API, wallet auth, authorization).
- Phase 3: `celoht-indexer` (blockchain synchronization into this schema).
