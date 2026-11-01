# RLS and Ownership Matrix

## Verification status

This matrix records the local disposable PostgreSQL evidence. It is not a
managed Supabase verification. Staging execution remains BLOCKED because no
Supabase project is configured in this workspace.

| Actor | Resource | SELECT | INSERT | UPDATE | DELETE | Expected | Actual |
| --- | --- | --- | --- | --- | --- | --- | --- |
| anon | Sensitive storage | denied | denied | denied | denied | denied | PASS locally |
| anon | `auth_challenges` | denied | denied | denied | denied | denied | PASS locally |
| authenticated user A | Own notification | allowed | n/a | `read_at` only | denied | allowed/read-state only | PASS locally |
| authenticated user A | User B progress/KYC | denied | n/a | denied | denied | denied | PASS locally |
| authenticated user A | User B quiz attempts/responses | denied | n/a | denied | denied | denied | PASS locally |
| authenticated user A | Quiz answer keys/grading fields | denied | denied | denied | denied | server only | PASS locally |
| authenticated user A | Wallet verification fields | own unverified insert only | verified fields denied | verified fields denied | denied | backend only | PASS locally |
| authenticated user A | Other submitter's pending planting evidence | denied | own submission only | denied | denied | denied | PASS locally |
| authorized reviewer | Other submitter's planting evidence | allowed | append-only review | summary trigger only | denied | permission-gated | PASS locally |
| authenticated user A | Own profile role | own row only | n/a | role escalation denied | n/a | denied escalation | PASS locally |
| authenticated user A | Indexer-owned tables | n/a | denied | denied | denied | service role only | PASS locally |
| authenticated user A | Administrative actions | denied | denied | denied | denied | admin/service only | PASS locally |
| authenticated user A | Duplicate notification | n/a | rejected | n/a | n/a | idempotent uniqueness | PASS locally |
| database owner/indexer fixture | Canonical block height | n/a | one canonical | unique canonical | n/a | one canonical/confirmed | PASS locally |
| database owner/indexer fixture | Orphan block replacement | n/a | allowed | n/a | n/a | orphan retained | PASS locally |

## Not yet executed

- Real anonymous/authenticated Supabase sessions.
- Managed Supabase reviewer/admin sessions.
- Complete storage object ownership matrix for every bucket.
- Governance and reforestation ownership tests.
- Service-role boundary tests against actual backend/indexer processes.
- Ownership transfer and cascade behavior in staging.
