-- Private education materials. Path convention: {course_id}/{filename}.
insert into storage.buckets (id, name, public)
values ('education-materials', 'education-materials', false)
on conflict (id) do nothing;

create policy storage_education_materials_select_published
  on storage.objects for select
  using (
    bucket_id = 'education-materials'
    and exists (
      select 1 from public.courses c
      where c.id::text = (storage.foldername(name))[1]
        and c.status = 'published'
        and auth.role() = 'authenticated'
    )
  );

create policy storage_education_materials_select_admin
  on storage.objects for select
  using (bucket_id = 'education-materials' and public.has_role(array['admin']));

create policy storage_education_materials_write_admin
  on storage.objects for insert
  with check (bucket_id = 'education-materials' and public.has_role(array['admin']));

create policy storage_education_materials_update_admin
  on storage.objects for update
  using (bucket_id = 'education-materials' and public.has_role(array['admin']))
  with check (bucket_id = 'education-materials' and public.has_role(array['admin']));

create policy storage_education_materials_delete_admin
  on storage.objects for delete
  using (bucket_id = 'education-materials' and public.has_role(array['admin']));