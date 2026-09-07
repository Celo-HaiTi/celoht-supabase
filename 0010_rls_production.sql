-- RLS for additive production tables. No client write policy is granted to
-- indexer-owned or audit tables; the service role is used by trusted services.

alter table public.roles enable row level security;
alter table public.permissions enable row level security;
alter table public.profile_roles enable row level security;
alter table public.role_permissions enable row level security;
alter table public.wallet_identities enable row level security;
alter table public.agent_profiles enable row level security;
alter table public.agent_verifications enable row level security;
alter table public.agent_activity enable row level security;
alter table public.enrollments enable row level security;
alter table public.lesson_progress enable row level security;
alter table public.blockchain_networks enable row level security;
alter table public.contracts enable row level security;
alter table public.indexed_blocks enable row level security;
alter table public.indexed_transactions enable row level security;
alter table public.blockchain_events enable row level security;
alter table public.indexer_sync_state enable row level security;
alter table public.donations enable row level security;
alter table public.tree_records enable row level security;
alter table public.impact_records enable row level security;
alter table public.administrative_actions enable row level security;

create policy roles_select_admin on public.roles for select
  using (public.has_role(array['admin']));
create policy permissions_select_admin on public.permissions for select
  using (public.has_role(array['admin']));
create policy profile_roles_select_self on public.profile_roles for select
  using (profile_id = auth.uid());
create policy profile_roles_select_admin on public.profile_roles for select
  using (public.has_role(array['admin']))
;
create policy role_permissions_select_admin on public.role_permissions for select
  using (public.has_role(array['admin']));

create policy wallet_identities_select_owner on public.wallet_identities for select
  using (profile_id = auth.uid() or public.has_role(array['reviewer','admin']));
create policy wallet_identities_insert_owner on public.wallet_identities for insert
  with check (profile_id = auth.uid());
create policy wallet_identities_update_owner on public.wallet_identities for update
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy agent_profiles_select_owner on public.agent_profiles for select
  using (profile_id = auth.uid() or public.has_role(array['reviewer','admin']));
create policy agent_profiles_insert_owner on public.agent_profiles for insert
  with check (profile_id = auth.uid());
create policy agent_profiles_update_reviewer_admin on public.agent_profiles for update
  using (public.has_role(array['reviewer','admin']))
  with check (public.has_role(array['reviewer','admin']));

create policy agent_verifications_select_owner on public.agent_verifications for select
  using (exists (select 1 from public.agent_profiles a where a.id = agent_profile_id and a.profile_id = auth.uid())
    or public.has_role(array['reviewer','admin']));
create policy agent_verifications_insert_owner on public.agent_verifications for insert
  with check (exists (select 1 from public.agent_profiles a where a.id = agent_profile_id and a.profile_id = auth.uid()));
create policy agent_verifications_update_reviewer_admin on public.agent_verifications for update
  using (public.has_role(array['reviewer','admin']))
  with check (public.has_role(array['reviewer','admin']));

create policy agent_activity_select_owner on public.agent_activity for select
  using (exists (select 1 from public.agent_profiles a where a.id = agent_profile_id and a.profile_id = auth.uid())
    or public.has_role(array['reviewer','admin']));

create policy enrollments_select_own on public.enrollments for select
  using (profile_id = auth.uid() or public.has_role(array['admin']));
create policy enrollments_insert_own on public.enrollments for insert
  with check (profile_id = auth.uid());
create policy enrollments_update_own on public.enrollments for update
  using (profile_id = auth.uid()) with check (profile_id = auth.uid());

create policy lesson_progress_select_own on public.lesson_progress for select
  using (exists (select 1 from public.enrollments e where e.id = enrollment_id and e.profile_id = auth.uid())
    or public.has_role(array['admin']));
create policy lesson_progress_insert_own on public.lesson_progress for insert
  with check (exists (select 1 from public.enrollments e where e.id = enrollment_id and e.profile_id = auth.uid()));
create policy lesson_progress_update_own on public.lesson_progress for update
  using (exists (select 1 from public.enrollments e where e.id = enrollment_id and e.profile_id = auth.uid()))
  with check (exists (select 1 from public.enrollments e where e.id = enrollment_id and e.profile_id = auth.uid()));

create policy blockchain_networks_select_authenticated on public.blockchain_networks for select
  using (auth.role() = 'authenticated');
create policy contracts_select_authenticated on public.contracts for select
  using (auth.role() = 'authenticated');
create policy indexed_blocks_select_admin on public.indexed_blocks for select
  using (public.has_role(array['admin']));
create policy indexed_transactions_select_authenticated on public.indexed_transactions for select
  using (auth.role() = 'authenticated');
create policy blockchain_events_select_authenticated on public.blockchain_events for select
  using (auth.role() = 'authenticated');
create policy indexer_sync_state_select_admin on public.indexer_sync_state for select
  using (public.has_role(array['admin']));
create policy donations_select_authenticated on public.donations for select
  using (auth.role() = 'authenticated');

create policy tree_records_select_authenticated on public.tree_records for select
  using (auth.role() = 'authenticated');
create policy impact_records_select_authenticated on public.impact_records for select
  using (auth.role() = 'authenticated');

create policy administrative_actions_select_admin on public.administrative_actions for select
  using (public.has_role(array['admin']));

-- The canonical administrative action and audit tables are append-only to API
-- roles. Backend and indexer writes use service_role or a controlled RPC.