# Operations

Monitor `indexer_sync_state`, legacy `indexer_state`, `system_health`, and
open `indexer_reconciliation_issues`. Alert on stale checkpoints, `error` or
`paused` status, critical discrepancies, and unexpected orphaned blocks.

The indexer must load Celo Sepolia deployment metadata from
`Celo-HaiTi/celoht-smart-contracts` and fail closed when it is missing. It must
upsert events by `(chain_id, transaction_hash, log_index)` and update
confirmation state after finality/reorg checks.

The backend must validate `SUPABASE_URL`, `SUPABASE_ANON_KEY`, and
`SUPABASE_SERVICE_ROLE_KEY` at startup. Missing configuration or database
connectivity fails closed; no mock users, balances, transactions, agents, or
events are permitted. The service-role key is server-only and must never be
placed in a browser or `NEXT_PUBLIC_*` variable.

Review append-only audit/security records and storage access logs during
incident response. KYC and evidence objects require private buckets and
short-lived authorized URLs.