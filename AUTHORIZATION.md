# AUTHORIZATION.md — Roles & Authorization Boundaries

## Roles
| Role | Assigned by | Capabilities |
|---|---|---|
| `user` | default at signup | own profile, own progress, own certificates, apply to become an agent |
| `agent` | admin/reviewer promotion | same as `user`, plus agent-specific views |
| `reviewer` | admin only | review KYC, review reforestation evidence |
| `admin` | admin only (bootstrap via direct DB action for the first admin) | full read, content publishing, role management |

## Rules
1. Role changes are never accepted from client input. The `profiles_update_own`
   RLS policy explicitly freezes `role = 'user'` on self-updates so a user
   cannot escalate their own role through the API.
2. Only `admin` can change another profile's role (`profiles_update_admin`).
3. Every sensitive administrative action (KYC decision, agent
   suspension, evidence verification, content publication, config change)
   must be written to `audit_logs` by the backend in the same transaction as
   the state change.
4. The indexer never makes authorization decisions — it only writes
   objectively-decoded on-chain facts.

## Bootstrapping the first admin
There is intentionally no self-service path to the `admin` role. The first
admin row must be set directly against the database (e.g. via the Supabase
SQL editor with the project owner's credentials) as a documented, audited
one-time operational step — not automated in these migrations.
