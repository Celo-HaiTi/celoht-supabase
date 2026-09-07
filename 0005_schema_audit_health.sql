-- 0005_schema_audit_health.sql
-- Append-only audit logging and system health reporting.

-- =========================================================
-- AUDIT LOGS (append-only, never editable)
-- =========================================================
create table if not exists public.audit_logs (
  id           uuid primary key default gen_random_uuid(),
  actor_id     uuid references public.profiles(id),
  action       text not null,
  target_table text,
  target_id    uuid,
  metadata     jsonb not null default '{}'::jsonb,
  created_at   timestamptz not null default now(),
  constraint audit_logs_action_known check (action in (
    'kyc_review',
    'agent_approval',
    'agent_suspension',
    'agent_rejection',
    'evidence_verification',
    'evidence_rejection',
    'course_publication',
    'project_publication',
    'admin_configuration_change'
  ))
);

create index if not exists idx_audit_logs_actor on public.audit_logs (actor_id);
create index if not exists idx_audit_logs_target on public.audit_logs (target_table, target_id);
create index if not exists idx_audit_logs_created_at on public.audit_logs (created_at desc);

comment on table public.audit_logs is
  'BACKEND OWNED, append-only. No UPDATE or DELETE policy exists for any role except service_role maintenance; see RLS.md.';

-- =========================================================
-- SYSTEM HEALTH
-- =========================================================
create table if not exists public.system_health (
  id          uuid primary key default gen_random_uuid(),
  component   text not null check (component in ('backend','indexer')),
  status      text not null check (status in ('healthy','degraded','down')),
  details     jsonb not null default '{}'::jsonb,
  checked_at  timestamptz not null default now()
);

create index if not exists idx_system_health_component_time on public.system_health (component, checked_at desc);

comment on table public.system_health is
  'SHARED. Written by backend and indexer service roles. A component must never self-report healthy while a critical dependency is unavailable.';
