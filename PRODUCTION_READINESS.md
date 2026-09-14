# CeloHT Production Readiness

## Repository

Name: `celoht-supabase`

Purpose: This repository provides the Supabase/PostgreSQL schema, RLS policies, storage configuration, notification contract, audit/health surface, and validation tooling used by the broader CeloHT ecosystem. It is a database infrastructure repository, not a standalone application or blockchain runtime.

## Repository Type

Supabase

## Status

NOT READY — EXTERNAL ENVIRONMENT VERIFICATION PENDING

## What Works

- Deterministic SQL migration chain from `0001` through `0018`.
- Required tables and RLS enablement checks pass via `npm run validate`.
- Disposable PostgreSQL execution and RLS/Data API assertions pass via `npm run verify:postgres`.
- CI workflow exists in `.github/workflows/validate.yml` and runs local validation plus SQL syntax validation on a disposable PostgreSQL instance.
- Sensitive storage buckets are configured as private.
- `auth_challenges` is implemented as server-only, deny-by-default infrastructure.
- Notification table contracts and lineage indexes are present.
- Documentation covers architecture, ownership, data provenance, deployment, security, RLS, storage, and notification integration.

## What Was Changed

- Created `AUDIT.md` to document repository role, architecture, existing functionality, gaps, dependencies, security, deployment, blockers, and current status.
- Created `PRODUCTION_READINESS.md` to provide an evidence-based status report for this repository.

## Tests

Executed locally:

- `npm run validate`

Result:

- `Validated 17 SQL migrations and 36 required tables.`

Also present in repository:

- CI validation workflow in `.github/workflows/validate.yml`
- Disposable PostgreSQL/Supabase smoke tests in `tests/database.sql`
- Full execution of all 18 migrations and `tests/database.sql` passed on a disposable PostgreSQL 16 database.
- External `celoht-indexer` PostgreSQL integration and failure-recovery suites passed against disposable PostgreSQL.
- External Celo Sepolia RPC integration passed against chain ID `11142220`.

## Security

Completed checks and controls evidenced in repository:

- No secrets or private keys committed.
- Private storage buckets for sensitive data.
- `auth_challenges` deny-all access design.
- RLS enabled for application tables.
- Audit and administrative data protections documented.
- Address/hash validation and append-only guarding are represented in SQL and docs.

Outstanding security requirements:

- Independent security review before production use.
- Live disposable-project verification against a real Supabase environment.

## Deployment

Verified in this session:

- Local schema validation succeeded.
- CI workflow is present and structured for validation.

Not verified in this session:

- Production or staging Supabase project deployment.
- Production environment variables.
- Live downstream integration with `celoht-backend` and `celoht-indexer`.

## External Dependencies

- `celoht-smart-contracts` for official deployment metadata and contract verification.
- `celoht-indexer` for event ingestion and concurrency-safe blockchain state handling.
- `celoht-backend` for wallet auth, profile workflows, education, KYC, and administrative actions.
- Supabase/PostgreSQL runtime.
- Celo Sepolia (`11142220`) as currently documented network context.

## Operational Readiness Matrix

| Component | Current State | Required Work | Can Implement Internally? | External Audit Required? | Final Status |
| --- | --- | --- | --- | --- | --- |
| Migration chain | All 17 migrations apply cleanly on disposable PostgreSQL 16 | Apply to a managed Supabase project when a target is provisioned | No, target project access is required | No | COMPLETE |
| Schema constraints and indexes | Validated by `npm run validate` and PostgreSQL execution | Keep migration history immutable | Yes | No | COMPLETE |
| RLS and storage privacy | Authenticated/anonymous isolation smoke tests pass; private buckets verified | Repeat against a managed Supabase target | Partly, target project access is required | Independent security review | COMPLETE |
| Wallet challenge ledger | Server-only table, expiry and replay constraints tested | Verify backend service-role calls against a live project | No, backend and target project are external | No | NEEDS INTEGRATION |
| Notifications and lineage | Tables, deduplication, RLS, realtime membership, and lineage schema present | Verify backend/indexer workers consume the contract | No, downstream runtimes are external | No | NEEDS INTEGRATION |
| Indexer persistence contract | Checkpoint, reorg, event idempotency, and reconciliation schema present | Verify with `celoht-indexer` and official contract metadata | No, downstream repos are external | No | NEEDS INTEGRATION |
| Deployment | Supabase CLI procedure documented; no target project supplied | Apply and verify in staging/production Supabase | No | No | NEEDS DEPLOYMENT |
| Documentation and CI | CI workflow, ownership docs, migration docs, and readiness evidence present | Maintain evidence as target environments are verified | Yes | No | COMPLETE |

## P0

- No P0 blockers remain for this schema repository.

## P1

- Downstream `celoht-backend` and `celoht-indexer` contract verification is still required.
- The remaining RLS test plan in `docs/RLS_TEST_PLAN.md` should be executed against a live Supabase target.
- Independent security review remains outstanding.

## P2

- Add automated integration tests covering expected backend/indexer schema contracts.
- Expand deployment health and observability checks.
- Add explicit environment-matrix documentation for test/staging/production.

## Remaining Blockers

### 1. Live environment verification

WHAT IS MISSING: An applied, disposable Supabase project test run using the repository’s migrations and RLS checks.

WHY IT MATTERS: Local validation does not prove production deployment compatibility or policy behavior on a live target.

WHAT IS REQUIRED: Apply migrations to a disposable project and rerun repository validation plus RLS smoke tests.

### 2. Production deployment metadata verification

WHAT IS MISSING: Verified contract addresses, deployment metadata, and environment configuration from the official smart-contracts deployment source.

WHY IT MATTERS: The schema references Celo Sepolia and expects runtime metadata from downstream repos; production deployment cannot be claimed without verified contract addresses and settings.

WHAT IS REQUIRED: Confirm the official deployment manifest and sync it into runtime configuration for the indexer/backend.

### 3. Downstream integration verification

WHAT IS MISSING: Verified runtime behavior of `celoht-backend` and `celoht-indexer` against this schema.

WHY IT MATTERS: This repo is infrastructure-only and must be proven compatible with the consumers that use it.

WHAT IS REQUIRED: Run end-to-end integration checks in a disposable project and environment that mirrors the intended network and service roles.

## External Audit Status

### PENDING EXTERNAL AUDIT

- Independent security review of the database/RLS and storage configuration.

## Evidence

- Local validation command run: `npm run validate`
- Result: `Validated 17 SQL migrations and 36 required tables.`
- PostgreSQL 16 result: `database tests passed`.
- CI workflow file: `.github/workflows/validate.yml`
- Smoke test file: `tests/database.sql`
- Architecture and ownership docs: `ARCHITECTURE.md`, `OWNERSHIP.md`, `SCHEMA.md`
- Migration documentation: `MIGRATIONS.md`
- Security documentation: `SECURITY.md`
- Deployment guidance: `DEPLOYMENT.md`

## Final Status

### NOT READY — EXTERNAL ENVIRONMENT VERIFICATION PENDING

Internal schema implementation, disposable PostgreSQL validation, and RLS/Data
API smoke tests pass. Managed Supabase deployment and backend/indexer/governance
runtime compatibility remain unverified external dependencies.

## Next Action

Provision a managed Supabase staging project, apply the immutable migrations,
and run the backend smoke suite with its required service configuration.
