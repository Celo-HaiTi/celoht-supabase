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
| authenticated user A | Own profile role | own row only | n/a | role escalation denied | n/a | denied escalation | PASS locally |
| authenticated user A | Indexer-owned tables | n/a | denied | denied | denied | service role only | PASS locally |
| authenticated user A | Administrative actions | denied | denied | denied | denied | admin/service only | PASS locally |
| authenticated user A | Duplicate notification | n/a | rejected | n/a | n/a | idempotent uniqueness | PASS locally |
| database owner/indexer fixture | Canonical block height | n/a | one canonical | unique canonical | n/a | one canonical/confirmed | PASS locally |
| database owner/indexer fixture | Orphan block replacement | n/a | allowed | n/a | n/a | orphan retained | PASS locally |

## Not yet executed

- Real anonymous/authenticated Supabase sessions.
- Reviewer/admin positive-path tests.
- Complete storage object ownership matrix for every bucket.
- Governance and reforestation ownership tests.
- Service-role boundary tests against actual backend/indexer processes.
- Ownership transfer and cascade behavior in staging.
