-- 0014_notifications.sql
-- Durable notification data layer for backend, indexer, and optional push worker.
-- Ownership: trusted backend/indexer services write through service_role.
-- Client roles receive only explicitly scoped read/read-state/preferences access.

-- =========================================================
-- NOTIFICATION ENUM-LIKE DOMAINS
-- =========================================================
create table if not exists public.notification_preferences (
  profile_id                 uuid primary key references public.profiles(id) on delete cascade,
  transaction_confirmations  boolean not null default true,
  transaction_failures       boolean not null default true,
  wallet_security_alerts     boolean not null default true,
  agent_activity              boolean not null default true,
  reforestation_updates       boolean not null default true,
  celoht_announcements        boolean not null default true,
  created_at                  timestamptz not null default now(),
  updated_at                  timestamptz not null default now()
);

create trigger trg_notification_preferences_updated_at
  before update on public.notification_preferences
  for each row execute function public.set_updated_at();

do $$
begin
  alter table public.wallet_identities
    add constraint wallet_identities_profile_address_unique unique (profile_id, address);
exception when duplicate_object then
  null;
end;
$$;

-- =========================================================
-- ADMIN ANNOUNCEMENTS
-- =========================================================
create table if not exists public.announcements (
  id             uuid primary key default gen_random_uuid(),
  title          text not null check (length(btrim(title)) between 1 and 200),
  message        text not null check (length(btrim(message)) between 1 and 10000),
  metadata       jsonb not null default '{}'::jsonb,
  status         text not null default 'draft'
                 check (status in ('draft', 'scheduled', 'published', 'expired', 'deactivated')),
  priority       smallint not null default 0 check (priority between 0 and 100),
  publish_at     timestamptz,
  expires_at     timestamptz,
  created_by     uuid not null references public.profiles(id) on delete restrict,
  published_at   timestamptz,
  deactivated_at timestamptz,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  constraint announcements_expiration_order
    check (expires_at is null or publish_at is null or expires_at > publish_at),
  constraint announcements_status_dates check (
    (status <> 'published' or published_at is not null)
    and (status <> 'deactivated' or deactivated_at is not null)
  )
);

create index if not exists announcements_publication_idx
  on public.announcements (status, publish_at, expires_at);
create trigger trg_announcements_updated_at
  before update on public.announcements
  for each row execute function public.set_updated_at();

-- =========================================================
-- DURABLE USER NOTIFICATIONS
-- =========================================================
create table if not exists public.notifications (
  id                    uuid primary key default gen_random_uuid(),
  profile_id            uuid not null references public.profiles(id) on delete cascade,
  recipient_wallet      text not null,
  notification_type     text not null check (notification_type in (
    'transaction_confirmed', 'transaction_failed', 'wallet_security_alert',
    'agent_activity', 'reforestation_update', 'announcement'
  )),
  title                 text not null check (length(btrim(title)) between 1 and 200),
  message               text not null check (length(btrim(message)) between 1 and 10000),
  metadata              jsonb not null default '{}'::jsonb,
  transaction_hash      text,
  chain_id              bigint,
  entity_id             uuid,
  announcement_id       uuid references public.announcements(id) on delete set null,
  created_at            timestamptz not null default now(),
  read_at               timestamptz,
  expires_at            timestamptz,
  priority              smallint not null default 0 check (priority between 0 and 100),
  delivery_status       text not null default 'pending'
                        check (delivery_status in ('pending', 'delivered', 'partially_delivered', 'failed', 'expired')),
  deduplication_key     text not null,
  creation_source       text not null check (creation_source in ('transaction', 'agent', 'reforestation', 'announcement', 'security', 'system')),
  updated_at            timestamptz not null default now(),
  constraint notifications_wallet_format
    check (recipient_wallet ~* '^0x[0-9a-f]{40}$' and recipient_wallet = lower(recipient_wallet)),
  constraint notifications_tx_hash_format
    check (transaction_hash is null or transaction_hash ~* '^0x[0-9a-f]{64}$'),
  constraint notifications_chain_id_positive
    check (chain_id is null or chain_id > 0),
  constraint notifications_expiration_order
    check (expires_at is null or expires_at >= created_at),
  constraint notifications_read_order
    check (read_at is null or read_at >= created_at),
  constraint notifications_deduplication_key_format
    check (length(btrim(deduplication_key)) between 1 and 512),
  constraint notifications_recipient_wallet_match
    foreign key (profile_id, recipient_wallet)
    references public.wallet_identities(profile_id, address)
    on delete cascade,
  constraint notifications_deduplication_unique unique (deduplication_key)
);

create index if not exists notifications_profile_created_idx
  on public.notifications (profile_id, created_at desc);
create index if not exists notifications_unread_idx
  on public.notifications (profile_id, created_at desc)
  where read_at is null;
create index if not exists notifications_delivery_idx
  on public.notifications (delivery_status, created_at)
  where delivery_status in ('pending', 'partially_delivered');
create index if not exists notifications_transaction_idx
  on public.notifications (chain_id, transaction_hash)
  where transaction_hash is not null;
create trigger trg_notifications_updated_at
  before update on public.notifications
  for each row execute function public.set_updated_at();

-- =========================================================
-- REGISTERED TRANSACTIONS
-- =========================================================
create table if not exists public.monitored_transactions (
  id                    uuid primary key default gen_random_uuid(),
  profile_id            uuid not null references public.profiles(id) on delete cascade,
  chain_id              bigint not null references public.blockchain_networks(chain_id) on delete restrict,
  transaction_hash      text not null,
  sender_wallet         text not null,
  recipient_wallet      text,
  action                text,
  entity_id             uuid,
  submitted_at          timestamptz not null default now(),
  status                text not null default 'pending'
                        check (status in ('pending', 'confirmed', 'failed', 'dropped', 'unknown', 'orphaned')),
  confirmation_state    text not null default 'pending'
                        check (confirmation_state in ('pending', 'confirmed', 'finalized', 'orphaned')),
  block_number          bigint,
  block_hash            text,
  failure_code          text,
  failure_message       text,
  confirmed_at          timestamptz,
  updated_at            timestamptz not null default now(),
  constraint monitored_transactions_unique unique (chain_id, transaction_hash),
  constraint monitored_transactions_hash_format check (transaction_hash ~* '^0x[0-9a-f]{64}$'),
  constraint monitored_transactions_sender_format check (sender_wallet ~* '^0x[0-9a-f]{40}$' and sender_wallet = lower(sender_wallet)),
  constraint monitored_transactions_recipient_format check (recipient_wallet is null or (recipient_wallet ~* '^0x[0-9a-f]{40}$' and recipient_wallet = lower(recipient_wallet))),
  constraint monitored_transactions_block_nonnegative check (block_number is null or block_number >= 0),
  constraint monitored_transactions_block_hash_format check (block_hash is null or block_hash ~* '^0x[0-9a-f]{64}$')
);

create index if not exists monitored_transactions_pending_idx
  on public.monitored_transactions (chain_id, status, submitted_at)
  where status in ('pending', 'unknown');
create index if not exists monitored_transactions_profile_idx
  on public.monitored_transactions (profile_id, submitted_at desc);
create trigger trg_monitored_transactions_updated_at
  before update on public.monitored_transactions
  for each row execute function public.set_updated_at();

-- =========================================================
-- PUSH SUBSCRIPTIONS AND DELIVERY ATTEMPTS
-- =========================================================
create table if not exists public.push_subscriptions (
  id          uuid primary key default gen_random_uuid(),
  profile_id  uuid not null references public.profiles(id) on delete cascade,
  endpoint    text not null,
  p256dh      text not null,
  auth        text not null,
  user_agent  text,
  last_used_at timestamptz,
  disabled_at timestamptz,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now(),
  constraint push_subscriptions_endpoint_unique unique (endpoint),
  constraint push_subscriptions_endpoint_length check (length(endpoint) between 1 and 2048),
  constraint push_subscriptions_keys_length check (length(p256dh) between 1 and 512 and length(auth) between 1 and 512)
);

create index if not exists push_subscriptions_profile_idx
  on public.push_subscriptions (profile_id) where disabled_at is null;
create trigger trg_push_subscriptions_updated_at
  before update on public.push_subscriptions
  for each row execute function public.set_updated_at();

create table if not exists public.notification_delivery_attempts (
  id               uuid primary key default gen_random_uuid(),
  notification_id  uuid not null references public.notifications(id) on delete cascade,
  subscription_id  uuid references public.push_subscriptions(id) on delete set null,
  channel          text not null check (channel in ('realtime', 'webpush')),
  status           text not null check (status in ('pending', 'sent', 'retrying', 'failed', 'permanent_failure')),
  attempt_count    integer not null default 0 check (attempt_count >= 0),
  next_attempt_at  timestamptz,
  last_error       text,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  constraint notification_delivery_attempt_unique unique (notification_id, subscription_id, channel)
);

create index if not exists notification_delivery_retry_idx
  on public.notification_delivery_attempts (status, next_attempt_at)
  where status in ('pending', 'retrying');
create trigger trg_notification_delivery_attempts_updated_at
  before update on public.notification_delivery_attempts
  for each row execute function public.set_updated_at();

-- Enable only the notification stream for Supabase Realtime. The deployment
-- must also retain this publication membership when applying the migration.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    execute 'alter publication supabase_realtime add table public.notifications';
  end if;
exception when duplicate_object then
  null;
end;
$$;

comment on table public.notifications is
  'BACKEND/INDEXER OWNED. Client roles may read their own rows and update read_at only. deduplication_key is globally unique for idempotent creation.';
comment on table public.monitored_transactions is
  'BACKEND/INDEXER OWNED. A submitted hash is not a confirmation; status changes only from observed chain receipts and confirmation policy.';
comment on table public.push_subscriptions is
  'BACKEND OWNED. VAPID private material is never stored in this table.';