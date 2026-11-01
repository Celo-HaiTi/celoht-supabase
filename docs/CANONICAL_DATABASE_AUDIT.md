# Canonical Database Audit: CeloHT Sepolia Pilot

## Scope and finding

Audited the numbered migrations through `0020`, their RLS/grant layers, database tests, and ownership/backend documentation before making changes. The repository already contained most of the pilot foundation. Migration `0021_canonical_pilot_completion.sql` adds the missing quiz model, closes client control over wallet verification, and makes planting evidence submission/review attributable and auditable. Migrations `0001`-`0020` remain unchanged.

This is a repository and disposable-PostgreSQL audit, not a live Supabase data audit. No staging project is configured here.

## Required areas

| Area | Existing canonical foundation | Completion in `0021` |
| --- | --- | --- |
| Profiles and verified wallets | `profiles`, `wallet_identities`, wallet challenge ledger | Clients may add only unverified identities; verified/primary fields are trusted-backend-only. Agent applications require the applicant's verified wallet. |
| Education | Courses, modules, lessons, enrollments, lesson progress, certificates | Quizzes, questions, options, server-only answer keys, profile-owned attempts/responses, server-owned submission and grading. |
| Agent registration and application | `agent_profiles` application records, `agents` compatibility model | Existing records are preflight-checked; new/changed agent profiles require a verified wallet belonging to that profile. |
| Agent verification/review | `agent_verifications`, normalized roles/permissions | Existing reviewer/admin policies remain database-role-based. |
| Reforestation projects/evidence | Projects, evidence, tree and impact records | Evidence is attributable to its submitter; owner insert is limited to pending evidence for a published project. |
| Evidence review/approval | Existing evidence status/reviewer summary fields | `reforestation_evidence_reviews` preserves append-only reviewer decisions and updates the evidence summary transactionally. Self-review is denied. |
| Notifications/preferences | Preferences, notifications, announcements, delivery and monitored-transaction records | Already present with owner-scoped RLS, deduplication, and delivery ownership. |
| Governance | Proposals and activity with on-chain identity | Already present; indexer-owned, public-read projections. |
| Privileged audit | Append-only audit logs, administrative actions, security events | Already present; client mutation remains denied. |
| Transactions/events | Donations, indexed transactions/events, contributions, lineage | Already present; transactions remain separate from application planting evidence. |

## Security and integrity observations

- `0018` introduced broad authenticated table grants. `0019` removed client writes to server-owned tables, but wallet identities still allowed authenticated writes under the owner policy. `0021` revokes those writes and grants only insertion of unverified wallet fields.
- Client role claims and user metadata are not authorization sources. Reviewer access uses `has_permission('impact.review')`, backed by `profile_roles` and `role_permissions`.
- Quiz answer keys have RLS enabled and no Data API grants. Client roles cannot set attempt submission, score, pass, or grading fields.
- Evidence reviews are append-only. A donation/contribution reference does not create, verify, or approve planting evidence, nor does it create a tree or impact record.
- New evidence rows are private to their submitter and authorized reviewers until verified. The pre-existing public policy exposes only verified evidence rows; underlying evidence files remain in private storage.
- The service-role key bypasses RLS and must remain server-side. Service-role paths must independently authenticate the caller, check database-backed permissions, and record privileged actions.

## Preflight and rollout

Before applying `0021`, run the checks below against a backup/staging copy. Do not repair mismatches by assigning `verified_at` without completing the wallet challenge/signature verification flow.

```sql
select id, profile_id, address
from public.wallet_identities
where is_primary and verified_at is null;

select a.id, a.profile_id, a.wallet_identity_id, wi.profile_id as wallet_owner,
       wi.verified_at
from public.agent_profiles a
left join public.wallet_identities wi on wi.id = a.wallet_identity_id
where wi.id is null or wi.profile_id <> a.profile_id or wi.verified_at is null;
```

Both queries must return zero rows. The migration repeats these checks and fails with an explicit preflight error. Then apply numbered migrations in order and run `npm run validate` and `npm run verify:postgres`. Before production, repeat verification on a disposable Supabase project to cover managed grants and Storage behavior.

## Rollback considerations

`0021` is additive to the canonical migration history. Do not edit or remove applied migrations. Once quiz attempts, responses, or evidence review decisions exist, do not drop those tables to roll back application code. Prefer a forward corrective migration; if a rollback is unavoidable before pilot records exist, first disable new writes, archive the new data, and remove objects only through a reviewed numbered migration. Keep audit and review history intact.

## Verification status

- Local PostgreSQL: migration chain and behavioral tests pass, including quiz ownership/answer-key denial, wallet verification privilege denial, reviewer authorization/self-review denial, evidence approval summary update, and required-table RLS checks.
- Static schema validation: passes for all 21 numbered migrations and 43 required tables.
- Managed Supabase staging: not run; requires a configured disposable project.
- Independent security review: still required before production use.
