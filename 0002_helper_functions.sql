-- 0002_helper_functions.sql
-- Shared helper functions used across the schema.

-- Generic updated_at maintenance
create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Returns true if the calling JWT belongs to a profile with one of the given roles.
-- Roles are stored server-side in profiles.role and are NEVER trusted from the client.
create or replace function public.has_role(required_roles text[])
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    where p.id = auth.uid()
      and p.role = any(required_roles)
  );
$$;

comment on function public.has_role(text[]) is
  'Server-side role check used by RLS policies. Never derive authorization from client-sent data.';
