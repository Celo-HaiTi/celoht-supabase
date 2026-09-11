# Repository Audit

## Repository Role

This repository is the CeloHT Supabase/PostgreSQL infrastructure layer. It does not contain a user-facing application, backend runtime, indexer runtime, or smart contracts. Its real role is to provide reproducible database migrations, schema ownership boundaries, Row Level Security (RLS), private storage configuration, audit/health tables, notification persistence contracts, and validation artifacts that downstream CeloHT repositories can consume.

The repository is intentionally a schema foundation for the broader CeloHT ecosystem. Based on the existing files, the intended runtime boundary is:

- `celoht-smart-contracts` -> `celoht-indexer` -> `celoht-supabase` -> `celoht-backend` -> dApp/Admin

This repo is therefore production-critical infrastructure, but it is not a stand-alone production application by itself.

## Architecture

The current architecture is documented in `ARCHITECTURE.md`, `SCHEMA.md`, `DATABASE.md`, `INDEXER_SCHEMA.md`, `OWNERSHIP.md`, `BACKEND_INTEGRATION.md`, and `NOTIFICATIONS.md`.

Key architectural points:

- The database owns the canonical persistence contract for application and indexer state.
- Blockchain-derived state is treated as observations from Celo, not as source-of-truth application data.
- Indexer-owned tables are separated from backend-owned tables.
- Backend-owned tables include profiles, wallet identity, education, certificates, KYC evidence, and administrative actions.
- RLS is enabled across application-accessible tables, with sensitive storage buckets kept private.
- `auth_challenges` is intentionally server-only and deny-by-default for browser access.
- Notification infrastructure is represented by durable database tables and lineage indexes, with downstream API/push logic expected in separate repositories.

## Existing Functionality

The repository already contains a substantial and well-structured migration set:

- `0001_extensions.sql` through `0017_indexer_notification_lineage.sql` provide a complete migration chain.
- `0003_schema_core.sql` and `0009_schema_production.sql` establish normalized production entities.
- `0006_rls.sql`, `0010_rls_production.sql`, and `0015_notifications_rls.sql` define access control.
- `0007_storage.sql` and `0011_storage_production.sql` define private storage buckets for sensitive documents.
- `0013_auth_challenges.sql` establishes the backend-owned wallet nonce/challenge ledger.
- `0014_notifications.sql` and `0015_notifications_rls.sql` establish durable notification storage and access policies.
- `0012_schema_hardening.sql`, `0016_auth_predicate_hardening.sql`, and `0017_indexer_notification_lineage.sql` add hardening, cleanup, and lineage tracking.
- `schema-check.mjs` verifies that required tables, RLS enablement, uniqueness constraints, storage/bucket rules, and notification/indexer guarantees exist.
- GitHub Actions in `.github/workflows/validate.yml` run validations and SQL syntax checks in CI.
- `tests/database.sql` provides a disposable PostgreSQL/Supabase smoke test that exercises RLS boundaries and data isolation.
- `.env.example` documents required environment variables without committing secrets.

## Incomplete Functionality

The following areas are present but not fully verified in live infrastructure:

- No live Supabase project has been applied and verified against this repository in this session.
- No production deployment target, Supabase project reference, or production RPC/configuration was provided or verified here.
- The repository does not include the downstream `celoht-backend`, `celoht-indexer`, or `celoht-smart-contracts` implementations that consume this schema.
- The remaining RLS acceptance tests in `docs/RLS_TEST_PLAN.md` are documented as a future test plan, not yet automated as part of the repository’s local test suite.
- Operational production deployment, recovery, and live monitoring are described in documentation but not demonstrated here.

## Mock/Simulated Functionality

The repository contains intentionally synthetic validation content, but not fake production data in migrations:

- `tests/database.sql` uses fixture rows and synthetic wallet addresses to verify policy behavior.
- `schema-check.mjs` validates presence of required schema features, not live environment behavior.
- `docs/RLS_TEST_PLAN.md` contains a RLS test plan that is explicitly described as a future test specification.

This is acceptable for a schema foundation repository, but it must not be mistaken for live production data or deployment state.

## Dependencies

This repository depends on external CeloHT repositories and services:

- `celoht-smart-contracts` for official deployment metadata, ABI references, and verified contract addresses.
- `celoht-indexer` for blockchain event ingestion, synchronization checkpoints, reorg handling, and durable event processing.
- `celoht-backend` for wallet auth, authorization, profile management, content, administrative operations, and service-role usage.
- Supabase/PostgreSQL runtime for migrations, RLS, storage, and authentication contexts.
- Celo Sepolia (`11142220`) as the currently configured network reference in docs; production mainnet deployment metadata is not present here.

## Security

The repository includes meaningful security controls and guardrails:

- No secrets or private keys are committed.
- Sensitive storage buckets are private and not publicly readable.
- `auth_challenges` is intentionally deny-all to browser/authenticated roles.
- Append-only enforcement is documented for audit and administrative data.
- Wallet address and transaction hash validation are enforced in SQL where applicable.
- `audit_logs`, `administrative_actions`, and `security_events` are designed to be append-only or service-controlled.
- RLS is enabled for application tables, and the schema aims to keep client-side access limited.

Remaining security follow-ups:

- Live Supabase project validation against a disposable environment is still required.
- Independent security review is still required before production use.
- Downstream repositories must maintain correct service-role separation and avoid writing indexer-owned tables through the backend.

## Deployment

Deployment status in this repo is currently limited to schema provisioning guidance and CI validation:

- `.github/workflows/validate.yml` runs local validation and SQL syntax checks.
- `DEPLOYMENT.md` documents applying migrations via Supabase CLI (`supabase db push`).
- `README.md` says this repository is used for Supabase migrations and validation, not as a full deployable application.

Current deployment posture is best described as:

- Validated locally
- Not yet verified against a live Supabase project
- Not yet verified against production environment configuration
- Not yet production-deployed in this session

## Documentation

Documentation is extensive and generally aligned with the actual repository role:

- `README.md`
- `ARCHITECTURE.md`
- `DATABASE.md`
- `DATA_MODEL.md`
- `SCHEMA.md`
- `RLS.md`
- `STORAGE.md`
- `SECURITY.md`
- `DEPLOYMENT.md`
- `MIGRATIONS.md`
- `INDEXER_SCHEMA.md`
- `BACKEND_INTEGRATION.md`
- `NOTIFICATIONS.md`
- `OWNERSHIP.md`
- `DATA_PROVENANCE.md`
- `OPERATIONS.md`
- `BACKUP_RECOVERY.md`
- `AUTHORIZATION.md`

Documentation gaps remain mainly around:

- live-target deployment verification
- production environment specifics
- definitive cross-repository contract verification
- complete end-to-end production readiness evidence

## Production Blockers

### P0 — Critical production blocker

- Live Supabase project verification is still required before production use. The repository has local validation, but not a verified production project application.
- Production contract deployment metadata and environment variables must be verified from the official `celoht-smart-contracts` repository and target deployment environment.

### P1 — Important production issue

- Downstream `celoht-backend` and `celoht-indexer` runtime behavior must be validated against this schema in an integration environment.
- Independent security review remains outstanding.
- The remaining RLS test plan in `docs/RLS_TEST_PLAN.md` should be automated or otherwise formally verified before claiming full production assurance.

### P2 — Improvement

- Add automated integration tests for the exact `celoht-backend`/`celoht-indexer` contracts expected by this schema.
- Add deployment health and observability checks for production use.
- Expand documentation to include a verified environment matrix for test/staging/production.

## Current Status

READY FOR TESTING

This repository is evidence-backed for local schema validation and CI checks, but it is not yet ready for production deployment or production claim without external verification.
