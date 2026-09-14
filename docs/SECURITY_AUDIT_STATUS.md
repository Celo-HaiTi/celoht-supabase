# Security Audit Status

## Status

- Internal security review: PARTIALLY VERIFIED
- Automated repository checks: PARTIALLY VERIFIED
- Independent external audit: REQUIRES INDEPENDENT EXTERNAL AUDIT

This document does not claim an independent security audit. No external auditor
or signed audit report is available in this repository.

## Evidence executed

- `npm run validate`: PASS for 19 migrations and 36 required tables.
- `npm run verify:postgres`: PASS on disposable PostgreSQL 16; database smoke
  tests passed.
- Backend production dependency audit: PASS with zero high/critical findings.
- Indexer production dependency audit: PASS with zero high/critical findings.
- Smart-contract production dependency audit: PASS with zero high/critical
  findings.
- Static inspection of RLS, grants, SECURITY DEFINER functions, storage
  policies, append-only triggers, auth challenges, and migration ordering.

## Findings

| Severity | Object or area | Finding | Status |
| --- | --- | --- | --- |
| Critical | None identified locally | No repository-controlled critical finding was identified by the available checks. | VERIFIED LOCALLY |
| High | None identified locally | No repository-controlled high finding was identified by the available checks. | VERIFIED LOCALLY |
| Medium | Live Supabase project | Security Advisor and managed-project catalog state were not available. | BLOCKED |
| Medium | Backend/indexer service boundaries | Runtime write targets and service-role behavior were not executable against staging. | BLOCKED |
| Medium | Full RLS matrix | Local smoke coverage is incomplete compared with the release matrix. | PARTIALLY VERIFIED |
| Medium | Recovery and reorg behavior | No staging backup/restore or live indexer recovery run was available. | NOT TESTED |

## Repository controls reviewed

- SECURITY DEFINER functions use an explicit `search_path = public`.
- Client access to `auth_challenges` is revoked and deny-all by RLS.
- Server-owned table client writes are revoked by `0019_client_privilege_hardening.sql`.
- Sensitive storage buckets are private in the migrations.
- Authorization policies use server-side profile roles and permissions, not
  editable user metadata or client role claims.

## Required independent scope

An independent reviewer must assess RLS bypasses, privilege escalation,
SECURITY DEFINER behavior, storage exposure, service-role separation, migration
safety, audit immutability, replay protection, and recovery/reorg assumptions.
