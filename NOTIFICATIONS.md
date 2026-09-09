# Notification Infrastructure Contract

This repository owns the durable Supabase data layer. It does not contain the
HTTP API, blockchain worker, Web Push runtime, or GitHub Pages frontend.

## Data flow

```text
Celo receipt/event -> celoht-indexer -> idempotent notification insert
                   -> public.notifications -> Supabase Realtime -> dApp
                   -> optional server-side Web Push dispatcher
```

The indexer must write notifications with a globally unique
`deduplication_key`. A duplicate insert is a successful no-op, not a second
delivery. Event identity must be derived from actual rows in
`blockchain_events`, `agent_transactions`, and
`reforestation_contributions`; this repository does not define ABI event names.

## Tables

- `notifications`: durable user-visible records. `profile_id` and the
  lower-case `recipient_wallet` are bound to `wallet_identities` by a foreign
  key. Client roles can select their own rows and update only `read_at`.
- `notification_preferences`: one server-synchronized preference row per
  profile. The backend must resolve the relevant category before creating or
  dispatching a notification.
- `monitored_transactions`: durable submitted transaction tracking. A hash is
  pending until a receipt is observed and the configured Celo confirmation or
  finality policy is satisfied. RPC timeouts must not be recorded as reverts.
- `announcements`: admin-authored content with scheduled publication and
  expiry. Administration requires the server-side `announcements.manage`
  permission.
- `push_subscriptions`: device-specific Web Push subscriptions. VAPID private
  material is not stored in Supabase.
- `notification_delivery_attempts`: worker-owned retry and permanent-failure
  state for optional Web Push delivery.

## Required backend endpoints

The backend must authenticate every endpoint and verify wallet ownership from
the existing wallet session/challenge flow. It must not accept a client-supplied
recipient as authorization.

```text
GET    /notifications
GET    /notifications/unread-count
PATCH  /notifications/:id/read
POST   /push-subscriptions
DELETE /push-subscriptions/:id
GET    /notification-preferences
PATCH  /notification-preferences

POST   /admin/announcements
PATCH  /admin/announcements/:id
DELETE /admin/announcements/:id
POST   /admin/announcements/:id/publish
```

The backend should use the service role only after independently authenticating
and authorizing the caller. It must return stable JSON errors and must not
expose database, RPC, service-role, or VAPID diagnostics.

## Worker requirements

`celoht-indexer` must use `indexed_blocks`, `indexed_transactions`,
`blockchain_events`, and `indexer_sync_state` as durable state. It must only
advance a checkpoint after the block projection and dependent notification
work have committed. It must populate `last_processed_block`, `safe_block`,
`worker_identity`, `worker_version`, and block hash/parent hash metadata. It
must store block number/hash/parent hash, verify the parent relationship, mark
divergent observations `orphaned`, rewind to the last canonical block, and
reprocess canonical events.

Transaction confirmation notifications must be generated from an observed
receipt plus the configured confirmation/finality rule. The worker must retry
transient RPC/Supabase failures with bounded exponential backoff and emit
structured health/error records in `system_health`.

Agent and Reforestation notifications must be derived only from the actual
decoded event/data rows present in this schema. The worker must not fabricate a
profile, contract, ABI event, or impact record when a source row is absent.

## Configuration boundary

Public frontend configuration may contain only the Supabase URL, publishable
key, backend API base URL, and VAPID public key. Backend/indexer secret stores
must contain the service-role key, database/RPC credentials, VAPID private key,
VAPID subject, confirmation policy, and worker identity. No private variable
may be exposed through a `NEXT_PUBLIC_*` frontend build.

## Deployment status in this checkout

The workspace has no Supabase project reference, production credentials,
backend API source, indexer source, contract deployment manifest, ABI bundle,
RPC endpoint, or worker runtime. Therefore migrations can be reviewed and
validated here, but production application, worker, Realtime, and Web Push
verification require those external dependencies and must not be reported as
deployed from this repository alone.