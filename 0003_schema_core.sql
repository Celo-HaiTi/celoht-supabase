-- 0003_schema_core.sql
-- Core off-chain application schema: profiles, agents, KYC, education.
-- Ownership: BACKEND OWNED unless stated otherwise.

-- =========================================================
-- PROFILES
-- =========================================================
create table if not exists public.profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  wallet_address  text not null,
  display_name    text,
  avatar_url      text,
  role            text not null default 'user'
                    check (role in ('user','agent','reviewer','admin')),
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  constraint profiles_wallet_address_format check (wallet_address ~* '^0x[0-9a-f]{40}$'),
  constraint profiles_wallet_address_unique unique (wallet_address)
);

create trigger trg_profiles_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

comment on table public.profiles is 'BACKEND OWNED. One row per Supabase Auth user, linked to a verified wallet.';
comment on column public.profiles.role is 'Server-assigned role. Never settable by the client directly.';

-- =========================================================
-- AGENTS (off-chain application state)
-- =========================================================
create table if not exists public.agents (
  id                      uuid primary key default gen_random_uuid(),
  profile_id              uuid not null unique references public.profiles(id) on delete cascade,
  wallet_address          text not null,
  off_chain_kyc_status    text not null default 'pending'
                            check (off_chain_kyc_status in
                              ('pending','kyc_review','approved','suspended','rejected')),
  on_chain_registry_status text
                            check (on_chain_registry_status is null or on_chain_registry_status in
                              ('unregistered','registered','suspended','revoked')),
  application_data        jsonb not null default '{}'::jsonb,
  reviewed_by             uuid references public.profiles(id),
  reviewed_at             timestamptz,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  constraint agents_wallet_address_format check (wallet_address ~* '^0x[0-9a-f]{40}$')
);

create index if not exists idx_agents_wallet_address on public.agents (wallet_address);
create index if not exists idx_agents_off_chain_status on public.agents (off_chain_kyc_status);

create trigger trg_agents_updated_at
  before update on public.agents
  for each row execute function public.set_updated_at();

comment on table public.agents is
  'BACKEND OWNED. off_chain_kyc_status is the application/KYC state. on_chain_registry_status is a read-only mirror of AgentRegistry state, written only by the indexer sync job (never guessed).';

-- =========================================================
-- AGENT KYC
-- =========================================================
create table if not exists public.agent_kyc (
  id             uuid primary key default gen_random_uuid(),
  agent_id       uuid not null references public.agents(id) on delete cascade,
  document_type  text not null,
  storage_path   text not null, -- path within the private 'agent-kyc' bucket
  status         text not null default 'submitted'
                   check (status in ('submitted','under_review','approved','rejected')),
  reviewer_id    uuid references public.profiles(id),
  reviewer_notes text,
  submitted_at   timestamptz not null default now(),
  reviewed_at    timestamptz
);

create index if not exists idx_agent_kyc_agent_id on public.agent_kyc (agent_id);
create index if not exists idx_agent_kyc_status on public.agent_kyc (status);

comment on table public.agent_kyc is
  'BACKEND OWNED. Documents live in the private agent-kyc storage bucket; storage_path is never a public URL.';

-- =========================================================
-- COURSES / MODULES / LESSONS / PROGRESS / CERTIFICATES
-- =========================================================
create table if not exists public.courses (
  id           uuid primary key default gen_random_uuid(),
  title        text not null,
  description  text,
  status       text not null default 'draft' check (status in ('draft','published','archived')),
  created_by   uuid references public.profiles(id),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);

create trigger trg_courses_updated_at
  before update on public.courses
  for each row execute function public.set_updated_at();

create table if not exists public.course_modules (
  id           uuid primary key default gen_random_uuid(),
  course_id    uuid not null references public.courses(id) on delete cascade,
  title        text not null,
  order_index  integer not null check (order_index >= 0),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint course_modules_unique_order unique (course_id, order_index)
);

create trigger trg_course_modules_updated_at
  before update on public.course_modules
  for each row execute function public.set_updated_at();

create table if not exists public.lessons (
  id           uuid primary key default gen_random_uuid(),
  module_id    uuid not null references public.course_modules(id) on delete cascade,
  title        text not null,
  content      text,
  video_url    text,
  order_index  integer not null check (order_index >= 0),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  constraint lessons_unique_order unique (module_id, order_index)
);

create trigger trg_lessons_updated_at
  before update on public.lessons
  for each row execute function public.set_updated_at();

create table if not exists public.course_progress (
  id            uuid primary key default gen_random_uuid(),
  profile_id    uuid not null references public.profiles(id) on delete cascade,
  lesson_id     uuid not null references public.lessons(id) on delete cascade,
  completed     boolean not null default false,
  completed_at  timestamptz,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  constraint course_progress_unique unique (profile_id, lesson_id),
  constraint course_progress_completed_at_consistency
    check ( (completed = false and completed_at is null) or (completed = true and completed_at is not null) )
);

create trigger trg_course_progress_updated_at
  before update on public.course_progress
  for each row execute function public.set_updated_at();

create table if not exists public.certificates (
  id                  uuid primary key default gen_random_uuid(),
  profile_id          uuid not null references public.profiles(id) on delete cascade,
  course_id           uuid not null references public.courses(id) on delete cascade,
  certificate_number  text not null unique,
  storage_path        text, -- path within the private 'certificates' bucket
  issued_at           timestamptz not null default now(),
  constraint certificates_unique_per_course unique (profile_id, course_id)
);

create index if not exists idx_certificates_profile_id on public.certificates (profile_id);

comment on table public.certificates is
  'BACKEND OWNED. A certificate must only be issued when course_progress shows genuine completion; never fabricated.';
