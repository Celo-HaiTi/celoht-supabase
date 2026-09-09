# BACKEND_INTEGRATION.md — Contract for `celoht-backend`

## Connection
The backend connects to Supabase using:
- the **anon/public key** for any request that should be constrained by RLS
  (rare — most backend reads/writes use the service role after the backend
  has independently verified the caller), and
- the **service role key**, server-side only, for privileged operations
  (KYC decisions, role changes, certificate issuance, audit log writes).

`SUPABASE_SERVICE_ROLE_KEY` must live only in server-side environment
variables and must never appear in a `NEXT_PUBLIC_*` variable or client bundle.

Notification endpoints and authorization boundaries are specified in
`NOTIFICATIONS.md`. The backend owns notification creation, preference
resolution, announcement authorization, and transaction registration; it must
never accept an arbitrary client recipient as proof of wallet ownership.

## Tables the backend owns (read/write)
`profiles`, `agents.off_chain_kyc_status` (+ related fields), `agent_kyc`,
`courses`, `course_modules`, `lessons`, `course_progress`, `certificates`,
`reforestation_projects`, `reforestation_evidence`, `audit_logs`.

The backend also owns `notification_preferences`, `announcements`,
`monitored_transactions`, and `push_subscriptions`. It reads `notifications`
for authenticated users and uses the service role for trusted creation and
delivery-state updates.

## Tables the backend reads but never writes
`blockchain_transactions`, `agent_transactions`,
`reforestation_contributions`, `governance_proposals`,
`governance_activity`, `agents.on_chain_registry_status`, `indexer_state`
(admin dashboards only).

## Wallet authentication dependency
This repository provisions `profiles.wallet_address` and links `profiles.id`
to `auth.users.id`. The actual nonce/challenge/signature verification flow is
implemented in `celoht-backend` (Phase 2) and, on success, creates the
Supabase Auth session and the corresponding `profiles` row.

## Fail-closed expectation
If the backend cannot reach Supabase, or required configuration
(`SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `SUPABASE_ANON_KEY`) is
missing, it must refuse to serve the affected endpoints rather than fall
back to mock/fake data.
