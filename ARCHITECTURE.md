# CeloHT Database Architecture

This repository owns the Supabase/PostgreSQL persistence layer only. The
runtime boundary is:

`celoht-smart-contracts` -> `celoht-indexer` -> `celoht-supabase` ->
`celoht-backend` -> dApp/Admin.

## Ownership

- **Blockchain:** authoritative for deployed contracts, balances, payments,
  agent registry state, certificate lifecycle, governance votes, and donation
  events.
- **Indexer:** writes decoded observations and synchronization checkpoints with
  the service role. It must load addresses, ABIs, and deployment blocks from
  the official deployment metadata, never from this database.
- **Backend:** owns profiles, wallet-link workflow, agent verification,
  education content/progress, certificates as an application artifact, impact
  evidence, and administrative actions.
- **Client:** reads through authenticated Supabase policies or backend APIs and
  never receives a service-role credential.

The database is a queryable projection and application store. It is never an
authority over chain state. Reorgs are represented with confirmation status
and must be reconciled by the indexer.

## Verified protocol facts

The schema reflects the current `celoht-smart-contracts` interfaces:

- USDm is the payment asset; CELO is gas only.
- Agent registry, service payments, education, reforestation, and governance
  are separate contracts.
- Governance is one wallet per proposal and advisory; there is no governance
  token or token-weighted vote.
- A donation does not imply a planted tree or a fixed impact ratio.
- Off-chain verification documents and impact evidence are not stored on-chain.

Contract addresses and deployment data are intentionally not seeded here.

## Migration order

Apply `0001` through `0011` in numeric order. `0009` is additive and does not
drop or rewrite existing data. The old tables remain during consumer migration;
new indexer integrations should target `blockchain_networks`, `contracts`,
`indexed_blocks`, `indexed_transactions`, `blockchain_events`, and
`indexer_sync_state`.