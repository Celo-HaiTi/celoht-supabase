-- 0007_storage.sql
-- Storage buckets and their access policies.
-- Convention: object paths are prefixed by the owning profile_id/agent_id so
-- ownership can be checked with storage.foldername(name).

insert into storage.buckets (id, name, public)
values
  ('agent-kyc',              'agent-kyc',              false),
  ('reforestation-evidence', 'reforestation-evidence', false),
  ('certificates',           'certificates',           false),
  ('user-media',             'user-media',             true)
on conflict (id) do nothing;

-- =========================================================
-- agent-kyc (private — KYC documents)
-- Path convention: {agent_id}/{filename}
-- =========================================================
create policy storage_agent_kyc_select_owner
  on storage.objects for select
  using (
    bucket_id = 'agent-kyc'
    and (storage.foldername(name))[1] in (
      select id::text from public.agents where profile_id = auth.uid()
    )
  );

create policy storage_agent_kyc_select_reviewer_admin
  on storage.objects for select
  using (
    bucket_id = 'agent-kyc'
    and public.has_role(array['reviewer','admin'])
  );

create policy storage_agent_kyc_insert_owner
  on storage.objects for insert
  with check (
    bucket_id = 'agent-kyc'
    and (storage.foldername(name))[1] in (
      select id::text from public.agents where profile_id = auth.uid()
    )
  );

-- No public policy exists for this bucket. Access requires an authenticated
-- session and a signed URL issued by the backend — never a permanent public link.

-- =========================================================
-- reforestation-evidence (private — admin/reviewer managed; verified subset
-- exposed only through backend-signed URLs, never directly from storage)
-- =========================================================
create policy storage_reforestation_evidence_select_admin
  on storage.objects for select
  using (
    bucket_id = 'reforestation-evidence'
    and public.has_role(array['admin','reviewer'])
  );

create policy storage_reforestation_evidence_write_admin
  on storage.objects for insert
  with check (
    bucket_id = 'reforestation-evidence'
    and public.has_role(array['admin','reviewer'])
  );

-- =========================================================
-- certificates (private — owner + admin; delivered via signed URL)
-- Path convention: {profile_id}/{filename}
-- =========================================================
create policy storage_certificates_select_owner
  on storage.objects for select
  using (
    bucket_id = 'certificates'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy storage_certificates_select_admin
  on storage.objects for select
  using (
    bucket_id = 'certificates'
    and public.has_role(array['admin'])
  );

-- Inserts happen only via the backend service role at certificate issuance time.

-- =========================================================
-- user-media (public — avatars and similar non-sensitive media)
-- Path convention: {profile_id}/{filename}
-- =========================================================
create policy storage_user_media_select_public
  on storage.objects for select
  using (bucket_id = 'user-media');

create policy storage_user_media_insert_owner
  on storage.objects for insert
  with check (
    bucket_id = 'user-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy storage_user_media_update_owner
  on storage.objects for update
  using (
    bucket_id = 'user-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

create policy storage_user_media_delete_owner
  on storage.objects for delete
  using (
    bucket_id = 'user-media'
    and (storage.foldername(name))[1] = auth.uid()::text
  );
