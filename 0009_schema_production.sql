-- Production normalization and on-chain lineage.
-- This migration is additive: existing tables remain available to current
-- consumers while new integrations use the canonical tables below.

-- =========================================================
-- AUTHORIZATION CATALOG
-- =========================================================
create table if not exists public.roles (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique,
  description text,
  created_at  timestamptz not null default now(),
  constraint roles_name_format check (name ~ '^[a-z][a-z0-9_]{0,63}$')
);

create table if not exists public.permissions (
  id          uuid primary key default gen_random_uuid(),
  name        text not null unique,
  description text,
  created_at  timestamptz not null default now(),
  constraint permissions_name_format check (name ~ '^[a-z][a-z0-9_.]{0,127}$')
);

create table if not exists public.profile_roles (
  profile_id  uuid not null references public.profiles(id) on delete cascade,
  role_id     uuid not null references public.roles(id) on delete restrict,
  assigned_by uuid references public.profiles(id) on delete set null,
  assigned_at timestamptz not null default now(),
  primary key (profile_id, role_id)
);

create table if not exists public.role_permissions (
  role_id       uuid not null references public.roles(id) on delete cascade,
  permission_id uuid not null references public.permissions(id) on delete cascade,
  granted_at    timestamptz not null default now(),
  primary key (role_id, permission_id)
);

insert into public.roles (name, description) values
  ('user', 'Authenticated CeloHT user'),
  ('agent', 'Approved CeloHT service agent'),
  ('reviewer', 'Reviewer of agent and impact evidence'),
  ('admin', 'CeloHT platform administrator')
on conflict (name) do nothing;

insert into public.permissions (name, description) values
  ('profile.read', 'Read authorized profiles'),
  ('profile.manage', 'Manage profiles and role assignments'),
  ('agent.review', 'Review agent verification submissions'),
  ('education.manage', 'Manage education content and certificates'),
  ('impact.review', 'Review reforestation impact evidence'),
  ('audit.read', 'Read audit and administrative action records'),
  ('operations.read', 'Read indexer and system health data')
on conflict (name) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
join public.permissions p on (
  (r.name in ('user','agent') and p.name = 'profile.read')
  or (r.name in ('reviewer','admin') and p.name in ('profile.read','agent.review','impact.review'))
  or (r.name = 'admin' and p.name in ('profile.manage','education.manage','audit.read','operations.read'))
)
on conflict do nothing;

insert into public.profile_roles (profile_id, role_id)
select p.id, r.id
from public.profiles p
join public.roles r on r.name = p.role
on conflict (profile_id, role_id) do nothing;

create or replace function public.assign_default_user_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profile_roles (profile_id, role_id)
  select new.id, id from public.roles where name = 'user'
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists trg_profiles_default_role on public.profiles;
create trigger trg_profiles_default_role
  after insert on public.profiles
  for each row execute function public.assign_default_user_role();

create or replace function public.sync_legacy_profile_role()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  delete from public.profile_roles where profile_id = new.id;
  insert into public.profile_roles (profile_id, role_id)
  select new.id, id from public.roles where name = new.role
  on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists trg_profiles_sync_role on public.profiles;
create trigger trg_profiles_sync_role
  after update of role on public.profiles
  for each row when (old.role is distinct from new.role)
  execute function public.sync_legacy_profile_role();

create or replace function public.has_role(required_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profile_roles pr
    join public.roles r on r.id = pr.role_id
    where pr.profile_id = auth.uid() and r.name = any(required_roles)
  );
$$;

create or replace function public.has_permission(required_permission text)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profile_roles pr
    join public.role_permissions rp on rp.role_id = pr.role_id
    join public.permissions p on p.id = rp.permission_id
    where pr.profile_id = auth.uid() and p.name = required_permission
  );
$$;

-- =========================================================
-- WALLET IDENTITIES
-- =========================================================
create table if not exists public.wallet_identities (
  id            uuid primary key default gen_random_uuid(),
  profile_id    uuid not null references public.profiles(id) on delete cascade,
  address       text not null,
  chain_id      bigint,
  is_primary    boolean not null default false,
  verified_at   timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint wallet_identities_address_format check (address ~* '^0x[0-9a-f]{40}$'),
  constraint wallet_identities_chain_id_positive check (chain_id is null or chain_id > 0),
  constraint wallet_identities_unique_address unique (address)
);

create unique index if not exists wallet_identities_one_primary
  on public.wallet_identities (profile_id) where is_primary;
create index if not exists wallet_identities_profile_idx on public.wallet_identities (profile_id);

create trigger trg_wallet_identities_updated_at
  before update on public.wallet_identities
  for each row execute function public.set_updated_at();

-- =========================================================
-- AGENT APPLICATION AND ACTIVITY
-- =========================================================
create table if not exists public.agent_profiles (
  id                  uuid primary key default gen_random_uuid(),
  profile_id          uuid not null unique references public.profiles(id) on delete cascade,
  wallet_identity_id  uuid not null unique references public.wallet_identities(id) on delete restrict,
  onchain_agent_id    numeric(78,0),
  offchain_status     text not null default 'pending'
                        check (offchain_status in ('pending','under_review','approved','suspended','rejected')),
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  constraint agent_profiles_onchain_id_positive check (onchain_agent_id is null or onchain_agent_id > 0)
);

create table if not exists public.agent_verifications (
  id               uuid primary key default gen_random_uuid(),
  agent_profile_id uuid not null references public.agent_profiles(id) on delete cascade,
  document_type    text not null,
  document_path    text not null,
  status           text not null default 'submitted'
                   check (status in ('submitted','under_review','approved','rejected')),
  reviewed_by      uuid references public.profiles(id) on delete set null,
  reviewer_notes   text,
  submitted_at     timestamptz not null default now(),
  reviewed_at      timestamptz,
  constraint agent_verifications_review_consistency check (
    status in ('submitted','under_review') or (reviewed_by is not null and reviewed_at is not null)
  )
);

create table if not exists public.agent_activity (
  id               uuid primary key default gen_random_uuid(),
  agent_profile_id uuid not null references public.agent_profiles(id) on delete cascade,
  activity_type    text not null,
  occurred_at      timestamptz not null default now(),
  source_event_id  uuid references public.blockchain_transactions(id) on delete set null,
  metadata         jsonb not null default '{}'::jsonb
);

create index if not exists agent_verifications_agent_idx on public.agent_verifications (agent_profile_id, submitted_at desc);
create index if not exists agent_activity_agent_time_idx on public.agent_activity (agent_profile_id, occurred_at desc);

create trigger trg_agent_profiles_updated_at
  before update on public.agent_profiles
  for each row execute function public.set_updated_at();

-- =========================================================
-- EDUCATION PROGRESS
-- =========================================================
create table if not exists public.enrollments (
  id           uuid primary key default gen_random_uuid(),
  profile_id   uuid not null references public.profiles(id) on delete cascade,
  course_id    uuid not null references public.courses(id) on delete cascade,
  enrolled_at  timestamptz not null default now(),
  completed_at timestamptz,
  constraint enrollments_unique_profile_course unique (profile_id, course_id),
  constraint enrollments_completion_order check (completed_at is null or completed_at >= enrolled_at)
);

create table if not exists public.lesson_progress (
  id            uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references public.enrollments(id) on delete cascade,
  lesson_id     uuid not null references public.lessons(id) on delete cascade,
  completed     boolean not null default false,
  completed_at  timestamptz,
  updated_at    timestamptz not null default now(),
  constraint lesson_progress_unique unique (enrollment_id, lesson_id),
  constraint lesson_progress_completion_consistency check (
    (completed and completed_at is not null) or (not completed and completed_at is null)
  )
);

create trigger trg_lesson_progress_updated_at
  before update on public.lesson_progress
  for each row execute function public.set_updated_at();

-- =========================================================
-- BLOCKCHAIN SOURCE OF TRUTH AND INDEXER LEDGER
-- =========================================================
create table if not exists public.blockchain_networks (
  chain_id       bigint primary key,
  network        text not null unique,
  native_symbol  text not null,
  is_enabled     boolean not null default false,
  created_at     timestamptz not null default now(),
  constraint blockchain_networks_chain_id_positive check (chain_id > 0)
);

create table if not exists public.contracts (
  id                 uuid primary key default gen_random_uuid(),
  chain_id           bigint not null references public.blockchain_networks(chain_id) on delete restrict,
  contract_name      text not null,
  contract_address   text not null,
  deployment_block   bigint,
  deployment_tx_hash text,
  metadata_ref       text not null,
  is_active          boolean not null default true,
  created_at         timestamptz not null default now(),
  constraint contracts_address_format check (contract_address ~* '^0x[0-9a-f]{40}$'),
  constraint contracts_block_positive check (deployment_block is null or deployment_block >= 0),
  constraint contracts_tx_hash_format check (deployment_tx_hash is null or deployment_tx_hash ~* '^0x[0-9a-f]{64}$'),
  constraint contracts_unique_address unique (chain_id, contract_address),
  constraint contracts_unique_name unique (chain_id, contract_name)
);

create table if not exists public.indexed_blocks (
  chain_id     bigint not null references public.blockchain_networks(chain_id) on delete restrict,
  block_number bigint not null,
  block_hash   text not null,
  parent_hash  text,
  block_time   timestamptz,
  confirmed_at timestamptz,
  indexed_at   timestamptz not null default now(),
  primary key (chain_id, block_number),
  constraint indexed_blocks_number_nonnegative check (block_number >= 0),
  constraint indexed_blocks_hash_format check (block_hash ~* '^0x[0-9a-f]{64}$')
);

create table if not exists public.indexed_transactions (
  id                    uuid primary key default gen_random_uuid(),
  chain_id              bigint not null references public.blockchain_networks(chain_id) on delete restrict,
  transaction_hash      text not null,
  block_number          bigint not null,
  block_hash            text,
  transaction_time      timestamptz,
  confirmation_status   text not null default 'pending'
                        check (confirmation_status in ('pending','confirmed','finalized','orphaned')),
  indexed_at            timestamptz not null default now(),
  constraint indexed_transactions_unique unique (chain_id, transaction_hash),
  constraint indexed_transactions_hash_format check (transaction_hash ~* '^0x[0-9a-f]{64}$'),
  constraint indexed_transactions_block_nonnegative check (block_number >= 0)
);

create table if not exists public.blockchain_events (
  id                    uuid primary key default gen_random_uuid(),
  chain_id              bigint not null references public.blockchain_networks(chain_id) on delete restrict,
  contract_id           uuid not null references public.contracts(id) on delete restrict,
  transaction_id        uuid not null references public.indexed_transactions(id) on delete restrict,
  block_number          bigint not null,
  block_hash            text not null,
  transaction_hash      text not null,
  log_index             integer not null check (log_index >= 0),
  event_name            text not null,
  event_type            text,
  event_data            jsonb not null default '{}'::jsonb,
  confirmation_status   text not null default 'pending'
                        check (confirmation_status in ('pending','confirmed','finalized','orphaned')),
  block_timestamp       timestamptz,
  indexed_at            timestamptz not null default now(),
  constraint blockchain_events_identity_unique unique (chain_id, transaction_hash, log_index),
  constraint blockchain_events_tx_hash_format check (transaction_hash ~* '^0x[0-9a-f]{64}$'),
  constraint blockchain_events_block_hash_format check (block_hash ~* '^0x[0-9a-f]{64}$')
);

create index if not exists contracts_chain_name_idx on public.contracts (chain_id, contract_name);
create index if not exists indexed_transactions_block_idx on public.indexed_transactions (chain_id, block_number);
create index if not exists blockchain_events_contract_block_idx on public.blockchain_events (contract_id, block_number);
create index if not exists blockchain_events_name_idx on public.blockchain_events (event_name);

create table if not exists public.indexer_sync_state (
  chain_id                 bigint not null references public.blockchain_networks(chain_id) on delete restrict,
  contract_id              uuid not null references public.contracts(id) on delete restrict,
  next_block               bigint not null default 0,
  latest_confirmed_block  bigint,
  status                   text not null default 'idle' check (status in ('idle','syncing','error','paused')),
  last_success_at          timestamptz,
  last_error               text,
  updated_at               timestamptz not null default now(),
  primary key (chain_id, contract_id),
  constraint indexer_sync_state_block_order check (latest_confirmed_block is null or latest_confirmed_block >= 0)
);

create trigger trg_indexer_sync_state_updated_at
  before update on public.indexer_sync_state
  for each row execute function public.set_updated_at();

-- =========================================================
-- REFORESTATION AND ADMINISTRATION
-- =========================================================
create table if not exists public.donations (
  id                  uuid primary key default gen_random_uuid(),
  blockchain_event_id uuid not null unique references public.blockchain_events(id) on delete restrict,
  donor_wallet        text not null,
  asset_address       text not null,
  amount              numeric(78,0) not null check (amount > 0),
  onchain_donation_id numeric(78,0),
  donated_at          timestamptz not null,
  constraint donations_wallet_format check (donor_wallet ~* '^0x[0-9a-f]{40}$'),
  constraint donations_asset_format check (asset_address ~* '^0x[0-9a-f]{40}$'),
  constraint donations_id_positive check (onchain_donation_id is null or onchain_donation_id > 0)
);

create table if not exists public.tree_records (
  id                   uuid primary key default gen_random_uuid(),
  project_id           uuid not null references public.reforestation_projects(id) on delete restrict,
  evidence_id          uuid references public.reforestation_evidence(id) on delete set null,
  external_reference   text,
  species              text,
  planted_at           date,
  location_description text,
  status               text not null default 'reported'
                       check (status in ('reported','verified','rejected')),
  created_by           uuid references public.profiles(id) on delete set null,
  verified_by          uuid references public.profiles(id) on delete set null,
  verified_at          timestamptz,
  created_at           timestamptz not null default now(),
  constraint tree_records_verification_consistency check (
    status <> 'verified' or (verified_by is not null and verified_at is not null)
  )
);

create table if not exists public.impact_records (
  id             uuid primary key default gen_random_uuid(),
  project_id     uuid not null references public.reforestation_projects(id) on delete restrict,
  evidence_id    uuid references public.reforestation_evidence(id) on delete set null,
  metric_name    text not null,
  metric_value   numeric(38,18) not null check (metric_value >= 0),
  metric_unit    text not null,
  methodology    text,
  status         text not null default 'reported' check (status in ('reported','verified','rejected')),
  recorded_by    uuid references public.profiles(id) on delete set null,
  verified_by    uuid references public.profiles(id) on delete set null,
  verified_at    timestamptz,
  created_at     timestamptz not null default now(),
  constraint impact_records_verification_consistency check (
    status <> 'verified' or (verified_by is not null and verified_at is not null)
  )
);

create table if not exists public.administrative_actions (
  id           uuid primary key default gen_random_uuid(),
  actor_id     uuid references public.profiles(id) on delete set null,
  action_type  text not null,
  target_table text,
  target_id    uuid,
  request_id   text,
  metadata     jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now(),
  constraint administrative_actions_request_id_unique unique (request_id)
);

create index if not exists donations_donor_idx on public.donations (donor_wallet, donated_at desc);
create index if not exists tree_records_project_idx on public.tree_records (project_id, status);
create index if not exists impact_records_project_idx on public.impact_records (project_id, status);
create index if not exists administrative_actions_created_idx on public.administrative_actions (created_at desc);

comment on table public.blockchain_events is
  'INDEXER OWNED. This is a decoded observation of chain state, never an authority over the chain.';
comment on table public.tree_records is
  'BACKEND OWNED. A tree record is operational evidence and is never inferred from a donation amount.';
comment on table public.impact_records is
  'BACKEND OWNED. Metrics require an explicitly recorded methodology and verification status.';