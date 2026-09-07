# CeloHT Data Model

## Identity and authorization

`profiles` links Supabase Auth users. `wallet_identities` stores verified
wallet associations. `roles`, `permissions`, `profile_roles`, and
`role_permissions` provide normalized server-side authorization. The legacy
`profiles.role` column is synchronized into `profile_roles` for compatibility.

## Agents and education

`agent_profiles` is the off-chain application record and may reference the
on-chain numeric agent ID only after the indexer observes it. `agent_verifications`
stores private review submissions; `agent_activity` stores activity references.

`courses` -> `course_modules` -> `lessons` is the content hierarchy.
`enrollments` and `lesson_progress` track user progress without granting
certificate authority. Certificates must be issued only by the authorized
backend/on-chain lifecycle.

## Chain projection

`blockchain_networks` -> `contracts` identifies a deployed source. Blocks and
transactions are separate from decoded `blockchain_events`; the event identity
`(chain_id, transaction_hash, log_index)` is the indexer idempotency key.
`indexer_sync_state` stores per-contract checkpoints and errors.

Amounts use integer base units in on-chain projections (`numeric(78,0)`) or
fixed precision where the application measures a decimal metric. Never use
floating point for money or token quantities.

## Reforestation and administration

`donations` is linked to an observed blockchain event. `tree_records` and
`impact_records` are backend evidence and metrics; neither is inferred from a
donation. `administrative_actions` complements the append-only `audit_logs`.