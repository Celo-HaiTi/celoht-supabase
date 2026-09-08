# SECURITY.md — Supabase Foundation Security Notes

## Threat model summary
This foundation assumes the client (dApp/browser) is untrusted. All
authorization decisions that matter are enforced either by:
1. Postgres Row Level Security (`RLS.md`), or
2. server-side logic in `celoht-backend` using the service role key.

## Hard rules
- No private keys or seed phrases are ever requested, stored, or logged.
- `SUPABASE_SERVICE_ROLE_KEY` must never be shipped to a browser bundle or
  exposed via a `NEXT_PUBLIC_*` environment variable.
- No table trusts a client-supplied role/flag for authorization.
- Normalized role and permission assignments are stored server-side in
  `profile_roles` and `role_permissions`; role changes synchronize the legacy
  profile field through a security-definer trigger.
- `audit_logs` has no update or delete policy for any Postgres role reachable
  from the API layer — it is append-only in practice.
- Financial/token amounts use `numeric(38,18)`; floating point is never used
  for money or token quantities anywhere in this schema.
- Wallet address columns are constrained with a regex check
  (`^0x[0-9a-f]{40}$`) to reject malformed input at the database layer, as a
  defense-in-depth measure behind backend-side validation.
- Transaction hash columns are constrained similarly
  (`^0x[0-9a-f]{64}$`).
- Reorg observations are retained as `orphaned` rows; only one observation per
  chain and block height may be `canonical` or `confirmed`.
- `audit_logs`, `administrative_actions`, and `security_events` have database
  triggers that reject update and delete operations, including service-role
  database sessions.

## Secrets handling
No secrets are committed to this repository. `.env.example` lists every
required variable name with a placeholder value only. Actual credentials are
provisioned through Supabase project settings and the deployment platform's
secret manager.

## Known limitations / follow-ups for Phase 2 & 3
- RLS enforces read/write boundaries for authenticated users, but does not by
  itself prevent the indexer's service-role connection from writing to a
  backend-owned table — that boundary is enforced by code discipline in
  `celoht-indexer` (only ever targets tables documented as INDEXER OWNED or
  SHARED). This must be covered by an integration test in Phase 3.
- Wallet-based authentication (nonce/challenge/signature) is implemented in
  `celoht-backend`, and this repository now includes the backend-owned server-only
  `public.auth_challenges` ledger required for signing, expiration, and replay
  protection.
- `public.auth_challenges` is intentionally RLS-locked with a deny-all policy and
  no public or authenticated access. It is writeable only via trusted backend
  service-role flows, never from browsers or client-side application code.
- SQL syntax and structural checks run in CI. Disposable Supabase validation
  and independent security review remain required before production use.
