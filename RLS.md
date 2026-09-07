# RLS.md — Row Level Security Model

## Default posture
Every table has `ENABLE ROW LEVEL SECURITY`. **No table is readable or
writable unless an explicit policy grants it.** There is no table-level
`GRANT ALL` fallback.

## Roles
Roles live in `profiles.role` (`user`, `agent`, `reviewer`, `admin`) and are
**assigned server-side only**, via backend logic running with the service
role or via direct admin action. They are never derived from:
- JWT custom claims set by the client,
- `localStorage` / client state,
- any user-editable table or column.

`public.has_role(text[])` is the single function all admin/reviewer policies
call, so authorization logic lives in one place.

## Policy summary by table

| Table | Public/self read | Elevated read | Write |
|---|---|---|---|
| `profiles` | own row | admin/reviewer | own row (role frozen to `user`), admin any |
| `agents` | own row | reviewer/admin | insert own, update reviewer/admin |
| `agent_kyc` | own agent's rows | reviewer/admin | insert own, update reviewer/admin |
| `courses`/`modules`/`lessons` | published only | admin (all statuses) | admin only |
| `course_progress` | own rows | admin | own rows only |
| `certificates` | own rows | admin | service role only (no client insert) |
| `blockchain_transactions` | public | — | service role only |
| `agent_transactions` | public | — | service role only |
| `reforestation_projects` | published only | admin | admin only |
| `reforestation_contributions` | public | — | service role only |
| `reforestation_evidence` | verified rows only | admin/reviewer (all) | admin/reviewer only |
| `governance_proposals`/`governance_activity` | public | — | service role only |
| `indexer_state` | — | admin only | service role only |
| `audit_logs` | — | admin only | service role only, **no update/delete policy for any role** |
| `system_health` | public | — | service role only |

## Why some on-chain tables are "public read"
`blockchain_transactions`, `agent_transactions`, `reforestation_contributions`,
and `governance_*` mirror data that is already public on the Celo blockchain.
Making them publicly readable in Postgres does not leak anything beyond what
Blockscout/RPC already expose, and it lets the dApp render transparency views
without a backend round-trip. Nothing sensitive (KYC, evidence documents,
audit trail) follows this pattern.

## Service role usage
The Supabase **service role key** is used only by:
- the `celoht-backend` server (never sent to the browser), and
- the `celoht-indexer` process.

Both bypass RLS by Supabase design, which is why table comments explicitly
flag "INDEXER OWNED" / "BACKEND OWNED" — RLS cannot fully separate the two at
the database layer for write access, so **application-layer discipline is
required**: the indexer process must never write to backend-owned tables, and
vice versa. See `INDEXER_SCHEMA.md` and `BACKEND_INTEGRATION.md`.

## Verification checklist (run before Phase 2)
- [ ] Every table in `DATABASE.md` has `rowsecurity = true` in `pg_tables`.
- [ ] No table has a permissive `using (true)` policy for `insert`/`update`/`delete`
      except where explicitly documented above (none currently).
- [ ] `audit_logs` has zero update/delete policies.
- [ ] A non-admin authenticated user cannot select another user's `agent_kyc`,
      `course_progress`, or `certificates` rows (covered by `tests/rls/`).
