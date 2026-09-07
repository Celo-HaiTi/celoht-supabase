-- 0004_schema_onchain.sql
-- On-chain synchronization schema. Ownership: INDEXER OWNED unless stated otherwise.
-- Written exclusively by celoht-indexer using the Supabase service role.
-- Never manually duplicate contract definitions here — event_data mirrors the
-- decoded ABI output from Celo-HaiTi/celoht-smart-contracts.

-- =========================================================
-- BLOCKCHAIN TRANSACTIONS (generic decoded-event ledger)
-- =========================================================
create table if not exists public.blockchain_transactions (
  id                 uuid primary key default gen_random_uuid(),
  chain_id           integer not null,
  contract_address   text not null,
  transaction_hash   text not null,
  log_index          integer not null,
  block_number       bigint not null,
  block_hash         text not null,
  event_name         text not null,
  event_data         jsonb not null,
  confirmed          boolean not null default false,
  created_at         timestamptz not null default now(),
  constraint blockchain_transactions_wallet_format
    check (contract_address ~* '^0x[0-9a-f]{40}$'),
  constraint blockchain_transactions_tx_hash_format
    check (transaction_hash ~* '^0x[0-9a-f]{64}$'),
  constraint blockchain_transactions_identity_unique
    unique (chain_id, transaction_hash, log_index)
);

create index if not exists idx_blockchain_tx_contract on public.blockchain_transactions (chain_id, contract_address);
create index if not exists idx_blockchain_tx_block on public.blockchain_transactions (chain_id, block_number);
create index if not exists idx_blockchain_tx_event_name on public.blockchain_transactions (event_name);

comment on table public.blockchain_transactions is
  'INDEXER OWNED. Idempotency key is (chain_id, transaction_hash, log_index). Data must come only from decoded, validated on-chain events.';

-- =========================================================
-- AGENT TRANSACTIONS (CeloHTServicePayments events tied to agents)
-- =========================================================
create table if not exists public.agent_transactions (
  id                          uuid primary key default gen_random_uuid(),
  blockchain_transaction_id  uuid not null references public.blockchain_transactions(id) on delete cascade,
  agent_wallet_address        text not null,
  payer_wallet_address        text not null,
  recipient_wallet_address    text not null,
  asset_address                text not null,
  amount                        numeric(38,18) not null check (amount >= 0),
  created_at                   timestamptz not null default now(),
  constraint agent_transactions_unique unique (blockchain_transaction_id)
);

create index if not exists idx_agent_tx_agent_wallet on public.agent_transactions (agent_wallet_address);

comment on table public.agent_transactions is
  'INDEXER OWNED. amount is numeric (never float) and denominated in the asset''s smallest recorded unit as emitted on-chain.';

-- =========================================================
-- REFORESTATION PROJECTS (backend-authored catalog)
-- =========================================================
create table if not exists public.reforestation_projects (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  description  text,
  location     text,
  status       text not null default 'draft' check (status in ('draft','published','archived')),
  created_by   uuid references public.profiles(id),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create trigger trg_reforestation_projects_updated_at
  before update on public.reforestation_projects
  for each row execute function public.set_updated_at();

comment on table public.reforestation_projects is 'BACKEND OWNED.';

-- =========================================================
-- REFORESTATION CONTRIBUTIONS (on-chain financial contributions)
-- =========================================================
create table if not exists public.reforestation_contributions (
  id                          uuid primary key default gen_random_uuid(),
  blockchain_transaction_id  uuid not null references public.blockchain_transactions(id) on delete cascade,
  project_id                   uuid references public.reforestation_projects(id),
  contributor_wallet_address   text not null,
  asset_address                text not null,
  amount                        numeric(38,18) not null check (amount >= 0),
  created_at                   timestamptz not null default now(),
  constraint reforestation_contributions_unique unique (blockchain_transaction_id)
);

create index if not exists idx_reforestation_contrib_wallet on public.reforestation_contributions (contributor_wallet_address);
create index if not exists idx_reforestation_contrib_project on public.reforestation_contributions (project_id);

comment on table public.reforestation_contributions is
  'INDEXER OWNED. Represents a financial contribution only. Does NOT imply a tree was planted — see reforestation_evidence.';

-- =========================================================
-- REFORESTATION EVIDENCE (verified physical impact — backend/admin controlled)
-- =========================================================
create table if not exists public.reforestation_evidence (
  id              uuid primary key default gen_random_uuid(),
  project_id      uuid not null references public.reforestation_projects(id) on delete cascade,
  contribution_id uuid references public.reforestation_contributions(id),
  storage_path    text not null, -- path within the private 'reforestation-evidence' bucket
  trees_verified  integer check (trees_verified is null or trees_verified >= 0),
  status          text not null default 'pending' check (status in ('pending','verified','rejected')),
  verified_by     uuid references public.profiles(id),
  verified_at     timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint reforestation_evidence_verification_consistency
    check ( (status <> 'verified') or (verified_by is not null and verified_at is not null) )
);

create trigger trg_reforestation_evidence_updated_at
  before update on public.reforestation_evidence
  for each row execute function public.set_updated_at();

comment on table public.reforestation_evidence is
  'BACKEND OWNED. This table — not a blockchain payment — is the sole source of truth for verified physical impact.';

-- =========================================================
-- GOVERNANCE PROPOSALS (indexer-synced, 1 wallet = 1 vote, no token)
-- =========================================================
create table if not exists public.governance_proposals (
  id                          uuid primary key default gen_random_uuid(),
  on_chain_proposal_id       bigint not null,
  blockchain_transaction_id  uuid references public.blockchain_transactions(id),
  title                        text,
  description                  text,
  status                        text not null default 'pending'
                                  check (status in ('pending','active','passed','rejected','executed_advisory')),
  created_at                   timestamptz not null default now(),
  updated_at                   timestamptz not null default now(),
  constraint governance_proposals_onchain_id_unique unique (on_chain_proposal_id)
);

create trigger trg_governance_proposals_updated_at
  before update on public.governance_proposals
  for each row execute function public.set_updated_at();

comment on table public.governance_proposals is
  'INDEXER OWNED (status/id), presentation fields (title/description) may be enriched by BACKEND. Advisory only — never implies automatic Treasury execution.';

-- =========================================================
-- GOVERNANCE ACTIVITY (votes — strictly 1 wallet = 1 vote, no token weighting)
-- =========================================================
create table if not exists public.governance_activity (
  id                          uuid primary key default gen_random_uuid(),
  proposal_id                  uuid not null references public.governance_proposals(id) on delete cascade,
  blockchain_transaction_id  uuid references public.blockchain_transactions(id),
  voter_wallet_address        text not null,
  vote                          text not null check (vote in ('for','against','abstain')),
  created_at                   timestamptz not null default now(),
  constraint governance_activity_one_vote_per_wallet unique (proposal_id, voter_wallet_address),
  constraint governance_activity_wallet_format check (voter_wallet_address ~* '^0x[0-9a-f]{40}$')
);

comment on table public.governance_activity is
  'INDEXER OWNED. Uniqueness on (proposal_id, voter_wallet_address) enforces 1 wallet = 1 vote at the database level. No token-weighted voting logic exists anywhere in this schema.';

-- =========================================================
-- INDEXER STATE (checkpoints)
-- =========================================================
create table if not exists public.indexer_state (
  id                        uuid primary key default gen_random_uuid(),
  chain_id                  integer not null,
  contract_name             text not null,
  contract_address          text not null,
  last_processed_block      bigint not null default 0,
  latest_confirmed_block    bigint,
  sync_status               text not null default 'idle' check (sync_status in ('idle','syncing','error')),
  last_successful_sync_at   timestamptz,
  last_error                text,
  updated_at                timestamptz not null default now(),
  constraint indexer_state_unique unique (chain_id, contract_address)
);

create trigger trg_indexer_state_updated_at
  before update on public.indexer_state
  for each row execute function public.set_updated_at();

comment on table public.indexer_state is
  'INDEXER OWNED exclusively. Ordinary users and the backend must never write here.';
