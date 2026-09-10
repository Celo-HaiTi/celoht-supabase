# CeloHT Production Readiness

## Repository

Name: `celoht-supabase`

Purpose: This repository provides the Supabase/PostgreSQL schema, RLS policies, storage configuration, notification contract, audit/health surface, and validation tooling used by the broader CeloHT ecosystem. It is a database infrastructure repository, not a standalone application or blockchain runtime.

## Repository Type

Supabase

## Status

READY FOR TESTING

## What Works

- Deterministic SQL migration chain from `0001` through `0017`.
- Required tables and RLS enablement checks pass via `npm run validate`.
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

## P0

- BLOCKED — VERIFICATION REQUIRED: live Supabase project apply/validation in a disposable test environment.
- BLOCKED — VERIFICATION REQUIRED: production deployment metadata and environment configuration must be confirmed from official CeloHT repositories and deployment settings.

## P1

- Downstream `celoht-backend` and `celoht-indexer` contract verification is still required.
- The remaining RLS test plan in `README (1).md` should be automated or otherwise formally verified.
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

## Evidence

- Local validation command run: `npm run validate`
- Result: `Validated 17 SQL migrations and 36 required tables.`
- CI workflow file: `.github/workflows/validate.yml`
- Smoke test file: `tests/database.sql`
- Architecture and ownership docs: `ARCHITECTURE.md`, `OWNERSHIP.md`, `SCHEMA.md`
- Migration documentation: `MIGRATIONS.md`
- Security documentation: `SECURITY.md`
- Deployment guidance: `DEPLOYMENT.md`
