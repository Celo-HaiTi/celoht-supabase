-- Production hardening for reorg handling, reconciliation, and append-only audit data.
-- This migration is additive except for the indexed_blocks key, which is changed
-- so orphaned observations can be retained alongside their replacement block.

-- =========================================================
-- REORGANIZATION-SAFE BLOCK OBSERVATIONS
-- =========================================================
alter table public.indexed_blocks
  add column if not exists confirmation_status text not null default 'canonical'
    check (confirmation_status in ('canonical', 'orphaned', 'confirmed'));

alter table public.indexed_blocks
  drop constraint if exists indexed_blocks_pkey;

alter table public.indexed_blocks
  add primary key (chain_id, block_number, block_hash);

create unique index if not exists indexed_blocks_one_canonical_per_height
  on public.indexed_blocks (chain_id, block_number)
  where confirmation_status in ('canonical', 'confirmed');

create index if not exists indexed_blocks_status_idx
  on public.indexed_blocks (chain_id, confirmation_status, block_number desc);

-- =========================================================
-- DISCREPANCY TRACKING
-- =========================================================
create table if not exists public.indexer_reconciliation_issues (
  id                    uuid primary key default gen_random_uuid(),
  chain_id              bigint not null references public.blockchain_networks(chain_id) on delete restrict,
  issue_type            text not null check (issue_type in (
    'missing_block', 'orphaned_block', 'missing_transaction',
    'duplicate_event', 'event_mismatch', 'stale_checkpoint', 'payment_mismatch'
  )),
  severity              text not null default 'warning'
                          check (severity in ('info', 'warning', 'critical')),
  block_number          bigint,
  transaction_hash      text,
  event_id              uuid references public.blockchain_events(id) on delete set null,
  details               jsonb not null default '{}'::jsonb,
  status                text not null default 'open'
                          check (status in ('open', 'investigating', 'resolved', 'ignored')),
  detected_at           timestamptz not null default now(),
  resolved_at           timestamptz,
  resolved_by           uuid references public.profiles(id) on delete set null,
  constraint reconciliation_block_nonnegative
    check (block_number is null or block_number >= 0),
  constraint reconciliation_tx_hash_format
    check (transaction_hash is null or transaction_hash ~* '^0x[0-9a-f]{64}$'),
  constraint reconciliation_resolution_consistency
    check (status not in ('resolved', 'ignored') or resolved_at is not null)
);

create index if not exists reconciliation_open_idx
  on public.indexer_reconciliation_issues (chain_id, status, severity, detected_at desc);
create index if not exists reconciliation_transaction_idx
  on public.indexer_reconciliation_issues (chain_id, transaction_hash)
  where transaction_hash is not null;

-- =========================================================
-- SECURITY EVENTS
-- =========================================================
create table if not exists public.security_events (
  id            uuid primary key default gen_random_uuid(),
  actor_id      uuid references public.profiles(id) on delete set null,
  event_type    text not null check (event_type in (
    'unauthorized_access', 'kyc_access', 'role_change',
    'policy_violation', 'credential_misuse', 'data_integrity'
  )),
  severity      text not null default 'warning'
                  check (severity in ('info', 'warning', 'critical')),
  request_id    text,
  metadata      jsonb not null default '{}'::jsonb,
  created_at    timestamptz not null default now()
);

create index if not exists security_events_created_idx
  on public.security_events (created_at desc, severity);
create index if not exists security_events_actor_idx
  on public.security_events (actor_id, created_at desc);

-- =========================================================
-- APPEND-ONLY ENFORCEMENT
-- =========================================================
create or replace function public.reject_audit_mutation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  raise exception 'append-only table: % cannot be modified', tg_table_name
    using errcode = '42501';
end;
$$;

drop trigger if exists trg_audit_logs_append_only on public.audit_logs;
create trigger trg_audit_logs_append_only
  before update or delete on public.audit_logs
  for each row execute function public.reject_audit_mutation();

drop trigger if exists trg_administrative_actions_append_only on public.administrative_actions;
create trigger trg_administrative_actions_append_only
  before update or delete on public.administrative_actions
  for each row execute function public.reject_audit_mutation();

drop trigger if exists trg_security_events_append_only on public.security_events;
create trigger trg_security_events_append_only
  before update or delete on public.security_events
  for each row execute function public.reject_audit_mutation();

-- =========================================================
-- PROFILE AUTHORIZATION FIX
-- =========================================================
create or replace function public.current_profile_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid();
$$;

drop policy if exists profiles_update_own on public.profiles;
create policy profiles_update_own
  on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid() and role = public.current_profile_role());

-- =========================================================
-- RLS FOR HARDENING TABLES
-- =========================================================
alter table public.indexer_reconciliation_issues enable row level security;
alter table public.security_events enable row level security;

create policy reconciliation_issues_select_admin
  on public.indexer_reconciliation_issues for select
  using (public.has_role(array['admin']));

create policy security_events_select_admin
  on public.security_events for select
  using (public.has_role(array['admin']));

comment on table public.indexed_blocks is
  'INDEXER OWNED. Multiple observations may exist at one height; only one can be canonical/confirmed, while orphaned blocks remain for reorg reconciliation.';
comment on table public.indexer_reconciliation_issues is
  'INDEXER OWNED. Open discrepancies are operational work items and must not be silently discarded.';
comment on table public.security_events is
  'BACKEND OWNED. Append-only security telemetry; never store secrets or credentials.';