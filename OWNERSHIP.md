# OWNERSHIP.md — Table Ownership Map

| Table | Owner | Notes |
|---|---|---|
| profiles | BACKEND | role changes admin-only |
| agents | BACKEND (off-chain fields) / INDEXER (on_chain_registry_status) | split ownership within one row |
| agent_kyc | BACKEND | |
| courses / course_modules / lessons | BACKEND | |
| course_progress | BACKEND | |
| certificates | BACKEND | |
| blockchain_transactions | INDEXER | |
| agent_transactions | INDEXER | |
| reforestation_projects | BACKEND | |
| reforestation_contributions | INDEXER | |
| reforestation_evidence | BACKEND | source of truth for physical impact |
| governance_proposals | INDEXER (status) / BACKEND (presentation copy) | |
| governance_activity | INDEXER | |
| indexer_state | INDEXER | |
| audit_logs | BACKEND | append-only |
| system_health | SHARED | both services post health snapshots |

Neither service may write outside its column of this table without an
explicit, reviewed migration changing this contract.
