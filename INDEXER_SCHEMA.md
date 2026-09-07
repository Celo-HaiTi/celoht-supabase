# INDEXER_SCHEMA.md — Contract for `celoht-indexer`

This document is the interface contract that `celoht-indexer` (Phase 3) must
follow. It does not implement indexing logic itself — this repository only
owns the schema.

## Tables the indexer writes (service role only)
- `blockchain_transactions` — one row per decoded event log.
  Uniqueness key: `(chain_id, transaction_hash, log_index)`. Upsert on this
  key to stay idempotent across restarts/backfills.
- `agent_transactions`, `reforestation_contributions`,
  `governance_proposals`, `governance_activity` — one row per relevant
  decoded event, each referencing its parent `blockchain_transactions.id`.
- `agents.on_chain_registry_status` — **update only**, never insert. The
  indexer must locate the existing `agents` row by wallet address; if none
  exists yet (an on-chain registration with no corresponding off-chain
  application), the indexer must not fabricate a `profiles`/`agents` row —
  log it and surface it as an operational alert instead.
- `indexer_state` — one row per `(chain_id, contract_address)`, updated after
  every batch with `last_processed_block`, `sync_status`, and either
  `last_successful_sync_at` or `last_error`.
- `system_health` — periodic `component = 'indexer'` rows.

## Tables the indexer must never write
`profiles`, `agent_kyc`, `courses`, `course_modules`, `lessons`,
`course_progress`, `certificates`, `reforestation_projects`,
`reforestation_evidence`, `audit_logs`. These are BACKEND OWNED.

## Contract & network source of truth
Contract addresses, ABIs, and deployment block numbers must be loaded from
`Celo-HaiTi/celoht-smart-contracts` deployment metadata (e.g.
`deployedContracts/celoSepolia.json`) at indexer startup — never hand-typed
into indexer code or into this database directly. If that metadata is
missing for a given network (e.g. Mainnet), the indexer must fail closed for
that network rather than guessing.

## Idempotency contract
Every insert into `blockchain_transactions` must be an upsert keyed on
`(chain_id, transaction_hash, log_index)` so re-running a backfill or
recovering from a crash never creates duplicate rows.
