# RLS test plan

These are pgTAP-style test specs to implement against a disposable Supabase
project (or `supabase test db`) before promoting this schema to production.
Each item below must have an automated test before Phase 1 is considered
verified for production use.

1. A user cannot `select` another user's `profiles`, `agents`, `agent_kyc`,
   `course_progress`, or `certificates` row.
2. A user cannot `update` their own `profiles.role`.
3. A non-admin cannot `insert`/`update`/`delete` `courses`, `course_modules`,
   `lessons`, or `reforestation_projects`.
4. A non-admin cannot `select` a `draft` course/project.
5. No authenticated role can `insert` into `blockchain_transactions`,
   `agent_transactions`, `reforestation_contributions`,
   `governance_proposals`, `governance_activity`, or `indexer_state`.
6. No authenticated role can `update` or `delete` any row in `audit_logs`.
7. A user cannot read another user's object in the `agent-kyc`,
   `reforestation-evidence`, or `certificates` storage buckets.
8. A user cannot write into another user's folder in the `user-media` bucket.
9. `reforestation_evidence` with `status != 'verified'` is invisible to
   non-admin/reviewer roles.
10. Inserting a `governance_activity` row with a duplicate
    `(proposal_id, voter_wallet_address)` fails at the database level.