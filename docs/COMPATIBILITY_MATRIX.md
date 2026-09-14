# Backend and Indexer Compatibility Matrix

## Status

Static contract review: PARTIALLY VERIFIED. The current public backend and
indexer source repositories were inspected at their shallow clone heads.
Runtime compatibility against a real Supabase staging project remains BLOCKED.

Backend source validation passed in the audit clone: typecheck and 24 unit
tests. Indexer source validation passed in the audit clone: typecheck and 21
unit tests. These are source-level checks, not staging integration evidence.

## Backend contract from repository documentation

| Component | Database object | Expected operation | RLS/service role | Result |
| --- | --- | --- | --- | --- |
| Wallet auth | `auth_challenges` | Issue and atomically consume nonce server-side | Trusted backend service role only | BLOCKED runtime; schema contract verified locally |
| Identity | `profiles`, `wallet_identities` | Create/update through backend; client owns limited profile fields | Backend service role; client RLS for own data | BLOCKED runtime |
| Agent/KYC | `agents`, `agent_kyc`, `agent_profiles`, `agent_verifications` | Application and review workflows | Owner/reviewer/admin policies; service role for privileged workflow | BLOCKED runtime |
| Education | `courses`, `course_modules`, `lessons`, `enrollments`, `lesson_progress`, `certificates` | Content, progress, certificate issuance | Admin/owner RLS; certificates server-owned | BLOCKED runtime |
| Notifications | `notification_preferences`, `notifications`, `announcements`, `monitored_transactions`, `push_subscriptions` | Preferences, read state, announcements, monitoring | Owner/admin RLS; service role for creation/delivery | BLOCKED runtime |

## Indexer contract from repository documentation

| Component | Database object | Expected operation | RLS/service role | Result |
| --- | --- | --- | --- | --- |
| Deployment source | `blockchain_networks`, `contracts` | Load official network/contract metadata | Indexer service role | Source inspected; staging runtime BLOCKED |
| Chain projection | `indexed_blocks`, `indexed_transactions`, `blockchain_events` | Upsert observations and preserve reorg history | Indexer service role | Schema constraints locally verified; runtime BLOCKED |
| Checkpoint | `indexer_sync_state` | Persist block, hash, safe point, worker identity | Indexer service role | Schema constraints locally verified; runtime BLOCKED |
| Reconciliation | `indexer_reconciliation_issues` | Record missing/orphaned/mismatched observations | Indexer service role | Schema locally verified; runtime BLOCKED |
| Notifications | `notifications.source_event_id` | Create idempotent event-derived notifications | Indexer service role | Schema locally verified; runtime BLOCKED |

## Concrete mismatches

| Source | Mismatch | Result |
| --- | --- | --- |
| `celoht-indexer/src/db/canonical.ts` | Uses `onConflict: chain_id,block_number`, but migration `0012` intentionally uses `(chain_id,block_number,block_hash)` to retain orphan blocks. | BLOCKED; indexer must use the full key and explicit canonical status handling. |
| `celoht-indexer/src/db/checkpoints.ts` | Calls `commit_indexer_checkpoint`; migration `0020` now provides a service-role-only function. | FIXED AND VERIFIED locally; staging execution remains blocked. |
| `celoht-indexer/src/indexing/persist.ts` | Writes `indexed_transactions.transaction_index`; migration `0020` now adds the nullable compatibility column. | FIXED AND VERIFIED locally; staging execution remains blocked. |
| `celoht-indexer/src/db/checkpoints.ts` | Rollback deletes indexed blocks, while repository policy requires retaining orphan observations. | BLOCKED; indexer rollback logic needs a source change before reorg compatibility can pass. |

## Required runtime evidence

The matrix becomes VERIFIED only after the actual backend and indexer source
repositories are available and their integration suites pass against a real
staging Supabase project using official deployment metadata.
