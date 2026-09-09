-- 0017_indexer_notification_lineage.sql
-- Add durable worker ownership and event lineage needed for restart/reorg recovery.

alter table public.indexer_sync_state
  add column if not exists last_processed_block bigint not null default 0,
  add column if not exists safe_block bigint,
  add column if not exists last_processed_block_hash text,
  add column if not exists last_processed_parent_hash text,
  add column if not exists worker_identity text,
  add column if not exists worker_version text;

alter table public.indexer_sync_state
  add constraint indexer_sync_state_processed_block_nonnegative
    check (last_processed_block >= 0);
alter table public.indexer_sync_state
  add constraint indexer_sync_state_safe_block_order
    check (safe_block is null or safe_block <= last_processed_block);
alter table public.indexer_sync_state
  add constraint indexer_sync_state_block_hash_format
    check (last_processed_block_hash is null or last_processed_block_hash ~* '^0x[0-9a-f]{64}$');
alter table public.indexer_sync_state
  add constraint indexer_sync_state_parent_hash_format
    check (last_processed_parent_hash is null or last_processed_parent_hash ~* '^0x[0-9a-f]{64}$');
alter table public.indexer_sync_state
  add constraint indexer_sync_state_worker_identity_nonempty
    check (worker_identity is null or length(btrim(worker_identity)) between 1 and 200);
alter table public.indexer_sync_state
  add constraint indexer_sync_state_worker_version_nonempty
    check (worker_version is null or length(btrim(worker_version)) between 1 and 100);

create index if not exists indexer_sync_state_health_idx
  on public.indexer_sync_state (status, updated_at desc);

alter table public.notifications
  add column if not exists source_event_id uuid references public.blockchain_events(id) on delete set null;

create index if not exists notifications_source_event_idx
  on public.notifications (source_event_id)
  where source_event_id is not null;

comment on column public.indexer_sync_state.last_processed_block is
  'Highest block whose decoded projection and dependent work committed successfully.';
comment on column public.indexer_sync_state.safe_block is
  'Highest block safe under the configured confirmation/finality policy.';
comment on column public.notifications.source_event_id is
  'Optional canonical blockchain event that caused this notification; retained for reorg reconciliation.';