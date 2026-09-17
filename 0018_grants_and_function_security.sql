-- Explicit Data API privileges and SECURITY DEFINER execution boundaries.
-- RLS decides which rows are visible; grants decide which roles can reach a
-- table or function at all. Keep both layers explicit for fresh projects.

grant usage on schema public to anon, authenticated;

grant select on public.courses, public.course_modules, public.lessons,
  public.blockchain_transactions, public.agent_transactions,
  public.reforestation_contributions, public.governance_proposals,
  public.governance_activity, public.reforestation_evidence, public.system_health
  to anon;

grant select on all tables in schema public to authenticated;
grant insert, update, delete on all tables in schema public to authenticated;

revoke all on table public.auth_challenges from anon, authenticated;
revoke insert, update, delete on table public.notifications from authenticated;
grant update (read_at) on public.notifications to authenticated;
revoke update on table public.profiles from authenticated;
grant update (display_name, avatar_url) on public.profiles to authenticated;

grant usage on schema storage to anon, authenticated;
grant select on storage.objects to anon, authenticated;
grant insert, update, delete on storage.objects to authenticated;

grant execute on function public.has_role(text[]) to anon, authenticated;
grant execute on function public.has_permission(text) to anon, authenticated;
grant execute on function public.current_profile_role() to anon, authenticated;

revoke execute on function public.set_updated_at() from public, anon, authenticated;
revoke execute on function public.assign_default_user_role() from public, anon, authenticated;
revoke execute on function public.sync_profile_role() from public, anon, authenticated;
revoke execute on function public.reject_audit_mutation() from public, anon, authenticated;

comment on schema public is
  'Data API table access is explicitly granted in 0018; row access remains controlled by RLS.';