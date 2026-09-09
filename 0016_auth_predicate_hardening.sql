-- 0016_auth_predicate_hardening.sql
-- Replace legacy auth.role() predicates with authenticated-subject checks.
-- Authorization remains based on auth.uid() and server-side roles/permissions.

drop policy if exists blockchain_networks_select_authenticated on public.blockchain_networks;
create policy blockchain_networks_select_authenticated on public.blockchain_networks for select
  using (auth.uid() is not null);

drop policy if exists contracts_select_authenticated on public.contracts;
create policy contracts_select_authenticated on public.contracts for select
  using (auth.uid() is not null);

drop policy if exists indexed_transactions_select_authenticated on public.indexed_transactions;
create policy indexed_transactions_select_authenticated on public.indexed_transactions for select
  using (auth.uid() is not null);

drop policy if exists blockchain_events_select_authenticated on public.blockchain_events;
create policy blockchain_events_select_authenticated on public.blockchain_events for select
  using (auth.uid() is not null);

drop policy if exists donations_select_authenticated on public.donations;
create policy donations_select_authenticated on public.donations for select
  using (auth.uid() is not null);

drop policy if exists storage_education_materials_select_published on storage.objects;
create policy storage_education_materials_select_published
  on storage.objects for select
  using (
    bucket_id = 'education-materials'
    and auth.uid() is not null
    and exists (
      select 1 from public.courses c
      where c.id::text = (storage.foldername(name))[1]
        and c.status = 'published'
    )
  );