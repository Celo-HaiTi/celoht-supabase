# BACKEND_INTEGRATION.md — Contract for `celoht-backend`

## Connection
The backend connects to Supabase using:
- the **anon/public key** for any request that should be constrained by RLS
  (prefer this for user-scoped reads, quiz responses, and reviewer decisions), and
- the **service role key**, server-side only, for privileged operations
  (wallet verification, quiz submission/grading, KYC decisions, role changes,
  certificate issuance, and audit log writes).

`SUPABASE_SERVICE_ROLE_KEY` must live only in server-side environment
variables and must never appear in a `NEXT_PUBLIC_*` variable or client bundle.

Notification endpoints and authorization boundaries are specified in
`NOTIFICATIONS.md`. The backend owns notification creation, preference
resolution, announcement authorization, and transaction registration; it must
never accept an arbitrary client recipient as proof of wallet ownership.

## Tables the backend owns (read/write)
`profiles`, `agents.off_chain_kyc_status` (+ related fields), `agent_kyc`,
`courses`, `course_modules`, `lessons`, `quizzes`, `quiz_questions`,
`quiz_options`, `quiz_answer_keys`, `quiz_attempts`, `quiz_responses`,
`course_progress`, `certificates`, `reforestation_projects`,
`reforestation_evidence`, `reforestation_evidence_reviews`, `audit_logs`.

Authenticated users may create only unverified wallet identities with their
own profile ID. The backend verifies the wallet challenge/signature before
setting `wallet_identities.verified_at` or `is_primary`; agent applications
are rejected unless their wallet identity is verified and belongs to the same
profile. Never accept a client role or `verified_at` value as proof.

Quiz clients may read published questions/options, create their own attempt,
and submit their own responses. The backend alone submits and grades attempts;
`quiz_answer_keys` and grading fields are not available to Data API roles.
Never trust a client-supplied score, pass flag, or completion claim.

Planting evidence submissions must identify the authenticated submitter and
published project. The backend owns file validation and private storage
uploads; client inserts cannot set verification status or link a contribution.
Review decisions require the database-backed `impact.review` permission and
are recorded append-only. The review trigger updates the evidence summary in
the same transaction. Service-role calls bypass RLS, so any service-role
review path must independently check the caller's database permission and
record the actor; never derive authorization from JWT user metadata.

The backend also owns `notification_preferences`, `announcements`,
`monitored_transactions`, and `push_subscriptions`. It reads `notifications`
for authenticated users and uses the service role for trusted creation and
delivery-state updates.

## Tables the backend reads but never writes
`blockchain_transactions`, `agent_transactions`,
`reforestation_contributions`, `governance_proposals`,
`governance_activity`, `agents.on_chain_registry_status`, `indexer_state`
(admin dashboards only).

Blockchain transactions and events remain separate from application
evidence. A donation/contribution can be referenced for context but can never
create or approve a planting evidence record or a tree/impact record.

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
