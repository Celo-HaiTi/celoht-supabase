-- 0006_rls.sql
-- Row Level Security for every application table.
-- Principle: deny by default. Every table below has RLS enabled and only the
-- policies explicitly listed grant access. Roles come from public.profiles.role
-- (server-assigned) via has_role(), never from client-sent headers or metadata.

-- =========================================================
-- PROFILES
-- =========================================================
alter table public.profiles enable row level security;

create policy profiles_select_own
  on public.profiles for select
  using (id = auth.uid());

create policy profiles_select_admin
  on public.profiles for select
  using (public.has_role(array['admin','reviewer']));

create policy profiles_update_own
  on public.profiles for update
  using (id = auth.uid())
  with check (id = auth.uid() and role = 'user'); -- users cannot self-promote their role

create policy profiles_update_admin
  on public.profiles for update
  using (public.has_role(array['admin']));

-- Row creation happens via a backend service-role function tied to Supabase Auth
-- sign-up, not via direct client inserts.

-- =========================================================
-- AGENTS
-- =========================================================
alter table public.agents enable row level security;

create policy agents_select_own
  on public.agents for select
  using (profile_id = auth.uid());

create policy agents_select_reviewer_admin
  on public.agents for select
  using (public.has_role(array['reviewer','admin']));

create policy agents_insert_own
  on public.agents for insert
  with check (profile_id = auth.uid());

create policy agents_update_reviewer_admin
  on public.agents for update
  using (public.has_role(array['reviewer','admin']));

-- Note: on_chain_registry_status is written only by the indexer via service_role,
-- which bypasses RLS by design (see INDEXER_SCHEMA.md).

-- =========================================================
-- AGENT KYC
-- =========================================================
alter table public.agent_kyc enable row level security;

create policy agent_kyc_select_owner
  on public.agent_kyc for select
  using (
    agent_id in (select id from public.agents where profile_id = auth.uid())
  );

create policy agent_kyc_select_reviewer_admin
  on public.agent_kyc for select
  using (public.has_role(array['reviewer','admin']));

create policy agent_kyc_insert_owner
  on public.agent_kyc for insert
  with check (
    agent_id in (select id from public.agents where profile_id = auth.uid())
  );

create policy agent_kyc_update_reviewer_admin
  on public.agent_kyc for update
  using (public.has_role(array['reviewer','admin']));

-- =========================================================
-- COURSES / MODULES / LESSONS
-- =========================================================
alter table public.courses enable row level security;
alter table public.course_modules enable row level security;
alter table public.lessons enable row level security;

create policy courses_select_published
  on public.courses for select
  using (status = 'published');

create policy courses_select_admin
  on public.courses for select
  using (public.has_role(array['admin']));

create policy courses_write_admin
  on public.courses for all
  using (public.has_role(array['admin']))
  with check (public.has_role(array['admin']));

create policy course_modules_select_published_parent
  on public.course_modules for select
  using (
    exists (select 1 from public.courses c where c.id = course_id and c.status = 'published')
  );

create policy course_modules_select_admin
  on public.course_modules for select
  using (public.has_role(array['admin']));

create policy course_modules_write_admin
  on public.course_modules for all
  using (public.has_role(array['admin']))
  with check (public.has_role(array['admin']));

create policy lessons_select_published_parent
  on public.lessons for select
  using (
    exists (
      select 1
      from public.course_modules m
      join public.courses c on c.id = m.course_id
      where m.id = module_id and c.status = 'published'
    )
  );

create policy lessons_select_admin
  on public.lessons for select
  using (public.has_role(array['admin']));

create policy lessons_write_admin
  on public.lessons for all
  using (public.has_role(array['admin']))
  with check (public.has_role(array['admin']));

-- =========================================================
-- COURSE PROGRESS (strictly user-owned)
-- =========================================================
alter table public.course_progress enable row level security;

create policy course_progress_select_own
  on public.course_progress for select
  using (profile_id = auth.uid());

create policy course_progress_select_admin
  on public.course_progress for select
  using (public.has_role(array['admin']));

create policy course_progress_insert_own
  on public.course_progress for insert
  with check (profile_id = auth.uid());

create policy course_progress_update_own
  on public.course_progress for update
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

-- =========================================================
-- CERTIFICATES
-- =========================================================
alter table public.certificates enable row level security;

create policy certificates_select_own
  on public.certificates for select
  using (profile_id = auth.uid());

create policy certificates_select_admin
  on public.certificates for select
  using (public.has_role(array['admin']));

-- Certificates are only ever issued by the backend service role after verifying
-- genuine course completion; no client-side insert policy exists.

-- =========================================================
-- BLOCKCHAIN TRANSACTIONS / AGENT TRANSACTIONS (public read, indexer-only write)
-- =========================================================
alter table public.blockchain_transactions enable row level security;
alter table public.agent_transactions enable row level security;

create policy blockchain_transactions_select_public
  on public.blockchain_transactions for select
  using (true); -- on-chain data is public by nature

create policy agent_transactions_select_public
  on public.agent_transactions for select
  using (true);

-- No insert/update/delete policies for any authenticated role: only the
-- indexer's service_role key (which bypasses RLS) may write these tables.

-- =========================================================
-- REFORESTATION PROJECTS
-- =========================================================
alter table public.reforestation_projects enable row level security;

create policy reforestation_projects_select_published
  on public.reforestation_projects for select
  using (status = 'published');

create policy reforestation_projects_select_admin
  on public.reforestation_projects for select
  using (public.has_role(array['admin']));

create policy reforestation_projects_write_admin
  on public.reforestation_projects for all
  using (public.has_role(array['admin']))
  with check (public.has_role(array['admin']));

-- =========================================================
-- REFORESTATION CONTRIBUTIONS (public read, indexer-only write)
-- =========================================================
alter table public.reforestation_contributions enable row level security;

create policy reforestation_contributions_select_public
  on public.reforestation_contributions for select
  using (true);

-- =========================================================
-- REFORESTATION EVIDENCE
-- =========================================================
alter table public.reforestation_evidence enable row level security;

create policy reforestation_evidence_select_verified_public
  on public.reforestation_evidence for select
  using (status = 'verified');

create policy reforestation_evidence_select_admin
  on public.reforestation_evidence for select
  using (public.has_role(array['admin','reviewer']));

create policy reforestation_evidence_write_admin
  on public.reforestation_evidence for all
  using (public.has_role(array['admin','reviewer']))
  with check (public.has_role(array['admin','reviewer']));

-- =========================================================
-- GOVERNANCE PROPOSALS / ACTIVITY (public read, indexer-only write)
-- =========================================================
alter table public.governance_proposals enable row level security;
alter table public.governance_activity enable row level security;

create policy governance_proposals_select_public
  on public.governance_proposals for select
  using (true);

create policy governance_activity_select_public
  on public.governance_activity for select
  using (true);

-- =========================================================
-- INDEXER STATE (admin-only visibility, indexer-only write)
-- =========================================================
alter table public.indexer_state enable row level security;

create policy indexer_state_select_admin
  on public.indexer_state for select
  using (public.has_role(array['admin']));

-- No insert/update policy for any authenticated role. Only the indexer's
-- service_role key may write checkpoints.

-- =========================================================
-- AUDIT LOGS (admin read-only, append-only overall)
-- =========================================================
alter table public.audit_logs enable row level security;

create policy audit_logs_select_admin
  on public.audit_logs for select
  using (public.has_role(array['admin']));

-- Inserts happen only via backend service-role functions triggered by
-- verified administrative actions. No update or delete policy exists for
-- any role — audit logs are immutable at the RLS layer.

-- =========================================================
-- SYSTEM HEALTH (public read)
-- =========================================================
alter table public.system_health enable row level security;

create policy system_health_select_public
  on public.system_health for select
  using (true);

-- Writes come only from backend/indexer service-role health-check jobs.
