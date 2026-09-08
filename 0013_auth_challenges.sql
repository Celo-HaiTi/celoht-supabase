-- 0013_auth_challenges.sql
-- Server-only wallet authentication challenge ledger for celoht-backend.
-- Ownership: BACKEND OWNED.
-- RLS: denies all direct client access. Only trusted backend service-role code
-- may issue or consume these challenges.

create table if not exists public.auth_challenges (
  id              uuid primary key default gen_random_uuid(),
  wallet_address   text not null,
  nonce           text not null,
  expires_at      timestamptz not null,
  used_at         timestamptz,
  created_at      timestamptz not null default now(),
  constraint auth_challenges_wallet_address_format
    check (wallet_address ~* '^0x[0-9a-f]{40}$' and wallet_address = lower(wallet_address)),
  constraint auth_challenges_nonce_format
    check (nonce ~ '^[0-9a-f]{64}$'),
  constraint auth_challenges_nonce_unique unique (nonce),
  constraint auth_challenges_wallet_nonce_unique unique (wallet_address, nonce),
  constraint auth_challenges_expiration_order check (expires_at > created_at),
  constraint auth_challenges_used_order check (
    used_at is null or (used_at >= created_at and used_at <= expires_at)
  )
);

create index if not exists idx_auth_challenges_wallet_expires
  on public.auth_challenges (wallet_address, expires_at);

create index if not exists idx_auth_challenges_used_at
  on public.auth_challenges (used_at);

create index if not exists idx_auth_challenges_created_at
  on public.auth_challenges (created_at desc);

alter table public.auth_challenges enable row level security;

revoke all on table public.auth_challenges from public;
revoke all on table public.auth_challenges from anon;
revoke all on table public.auth_challenges from authenticated;

create policy auth_challenges_deny_all
  on public.auth_challenges
  for all
  using (false)
  with check (false);

comment on table public.auth_challenges is
  'BACKEND OWNED. Wallet authentication nonce/challenge ledger used by celoht-backend. Client applications cannot read or write this table; only the backend service role may issue and consume nonce challenges.';
comment on column public.auth_challenges.wallet_address is
  'Canonical lower-case wallet address for challenge issuance and verification.';
comment on column public.auth_challenges.nonce is
  'Random 32-byte nonce encoded as lowercase hex; unique across all issued challenges.';
comment on column public.auth_challenges.expires_at is
  'Absolute expiration time for a challenge. Any verification after this timestamp fails.';
comment on column public.auth_challenges.used_at is
  'Null until the challenge is atomically consumed. Once set, the nonce is treated as replayed and cannot be reused.';
