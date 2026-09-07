# CeloHT Canonical Schema

The canonical normalized surface is introduced by `0009_schema_production.sql`.
The earlier tables remain compatibility surfaces during consumer migration and
must not be silently treated as a second source of truth.

## Ownership

| Group | Owner | Notes |
|---|---|---|
| `blockchain_networks`, `contracts`, indexed blocks/transactions/events, checkpoints | indexer | Observations only; source facts remain on Celo |
| profiles, wallets, agent applications, courses, progress | backend | User and workflow state |
| KYC and evidence | backend/reviewer | Private storage and controlled review |
| audit, admin, security, reconciliation | backend/indexer operations | Append-only or service-controlled |

`contracts` is the canonical contract-deployment table; a duplicate
`contract_deployments` table is intentionally not created. `indexed_blocks`
retains orphaned observations and permits only one canonical observation per
chain and height. Events are idempotent on
`(chain_id, transaction_hash, log_index)`.

## Asset rules

Celo Sepolia (`11142220`) is the configured network. USDm is the settlement
asset and CELO is gas only. The database does not create a CeloHT token or
invent contract addresses; deployment metadata comes from the official
smart-contracts repository at indexer startup.