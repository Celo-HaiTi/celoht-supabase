# INDEXER_SCHEMA.md — Contract for `celoht-indexer`

This document is the interface contract that `celoht-indexer` (Phase 3) must
follow. It does not implement indexing logic itself — this repository only
owns the schema.

## Canonical tables the indexer writes (service role only)
- `blockchain_networks` and `contracts` — deployment metadata copied from the
  official smart-contracts manifest. `metadata_ref` must identify that source.
- `indexed_blocks` and `indexed_transactions` — chain observations used for
  confirmation and reorganization handling.
- `blockchain_events` — one decoded row per event log. Idempotency key:
  `(chain_id, transaction_hash, log_index)`.
- `indexer_sync_state` — one checkpoint per `(chain_id, contract_id)`.

The earlier tables below remain compatibility tables for existing consumers.
New indexer work should target the canonical tables above.

## Compatibility tables the indexer writes (service role only)
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
`profiles`, `wallet_identities`, `roles`, `permissions`, `agent_verifications`,
`courses`, `course_modules`, `lessons`, `enrollments`, `lesson_progress`,
`certificates`, `reforestation_projects`, `tree_records`, `impact_records`,
`audit_logs`, and `administrative_actions`. These are BACKEND OWNED.

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

For canonical events, retain observed block and transaction hashes and mark
reorged observations `orphaned` rather than deleting history blindly.
