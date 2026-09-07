# DATABASE.md — CeloHT Supabase Schema

## Scope
This document describes the relational schema created by `migrations/0001`–`0008`.
It is the single source of truth for table structure. No table, column, or
constraint exists in production that is not represented in these migrations.

## Design principles
- UUID primary keys (`gen_random_uuid()`) except where a natural on-chain key exists.
- `timestamptz` for all timestamps — never naive timestamps.
- `numeric(38,18)` for every financial/token amount — **never floating point**.
- Explicit `check` constraints for status enums instead of free-text.
- Every on-chain-derived table carries the natural blockchain identity
  (`chain_id`, `transaction_hash`, `log_index`) as a uniqueness constraint,
  enabling idempotent indexer writes.

## Table groups

### Identity & profiles
- `profiles` — one row per Supabase Auth user, linked 1:1 to a verified wallet address.

### Agents
- `agents` — off-chain application/KYC lifecycle. `off_chain_kyc_status` is
  backend-controlled; `on_chain_registry_status` is a read-only mirror
  populated exclusively by the indexer from `CeloHTAgentRegistry` events.
- `agent_kyc` — individual KYC document submissions and review history.

### Education
- `courses`, `course_modules`, `lessons` — content hierarchy with explicit ordering.
- `course_progress` — per-user, per-lesson completion state.
- `certificates` — issued only by the backend after verifying completion.

### On-chain ledger (INDEXER OWNED)
- `blockchain_transactions` — generic decoded-event table for every indexed
  contract event. Idempotency key: `(chain_id, transaction_hash, log_index)`.
- `agent_transactions` — `CeloHTServicePayments` events tied to a specific agent.
- `reforestation_contributions` — `CeloHTReforestation` financial contribution events.
- `governance_proposals` / `governance_activity` — `CeloHTGovernance` events.
  Voting uniqueness is enforced at the DB level: `unique(proposal_id, voter_wallet_address)`.

### Reforestation impact (BACKEND OWNED)
- `reforestation_projects` — project catalog.
- `reforestation_evidence` — the **only** source of truth for verified physical
  tree-planting impact. A financial contribution row never implies this table
  should be updated automatically.

### Operations
- `indexer_state` — sync checkpoints per `(chain_id, contract_address)`.
- `audit_logs` — append-only log of sensitive administrative actions.
- `system_health` — latest health snapshot per component (`backend` / `indexer`).

## On-chain vs. off-chain, at a glance

| Concept                     | Off-chain (backend)         | On-chain (indexer)                 |
|------------------------------|------------------------------|--------------------------------------|
| Agent status                 | `agents.off_chain_kyc_status` | `agents.on_chain_registry_status`   |
| Reforestation impact          | `reforestation_evidence`     | `reforestation_contributions`       |
| Course completion             | `course_progress`, `certificates` | — (not on-chain)               |
| Governance vote                | —                             | `governance_activity`               |

## Non-goals
This schema does not implement token-weighted governance, does not store
private keys or seed phrases anywhere, and does not include any table for
caching "fake"/placeholder production data.
