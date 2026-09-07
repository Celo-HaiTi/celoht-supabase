# DATABASE.md — CeloHT Supabase Schema

## Scope
This document describes the relational schema created by root migrations `0001`–`0012`.
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

The original tables remain compatibility surfaces. The canonical normalized
tables added in migrations `0009`–`0011` are described below.

### Identity & profiles
- `profiles` — one row per Supabase Auth user, linked 1:1 to a verified wallet address.
- `wallet_identities` — normalized wallet links with one optional primary wallet.
- `roles`, `permissions`, `profile_roles`, `role_permissions` — server-side authorization catalog.

### Agents
- `agents` — off-chain application/KYC lifecycle. `off_chain_kyc_status` is
  backend-controlled; `on_chain_registry_status` is a read-only mirror
  populated exclusively by the indexer from `CeloHTAgentRegistry` events.
- `agent_kyc` — individual KYC document submissions and review history.
- `agent_profiles`, `agent_verifications`, `agent_activity` — normalized agent application, review, and activity records.

### Education
- `courses`, `course_modules`, `lessons` — content hierarchy with explicit ordering.
- `course_progress` — per-user, per-lesson completion state.
- `certificates` — issued only by the backend after verifying completion.
- `enrollments`, `lesson_progress` — normalized course participation and lesson state.

### On-chain ledger (INDEXER OWNED)
- `blockchain_networks`, `contracts` — deployment sources and verified contract identities.
- `indexed_blocks`, `indexed_transactions`, `blockchain_events` — block/transaction/event projection with reorg status and event-log idempotency.
- `indexer_sync_state` — per-contract checkpoint and error state.
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
- `donations`, `tree_records`, `impact_records` — donation lineage and explicitly
  recorded operational evidence; no tree or metric is inferred from payment.

### Operations
- `indexer_state` — sync checkpoints per `(chain_id, contract_address)`.
- `audit_logs` — append-only log of sensitive administrative actions.
- `system_health` — latest health snapshot per component (`backend` / `indexer`).
- `administrative_actions` — append-only administrative action idempotency and metadata.
- `indexer_reconciliation_issues` — explicit missing, stale, orphaned, and mismatched observation work items.
- `security_events` — append-only security telemetry without secrets.

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
