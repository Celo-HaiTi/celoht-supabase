-- 0015_notifications_rls.sql
-- Client access for the durable notification data layer.
-- No policy in this migration trusts client metadata or auth.role().

insert into public.permissions (name, description)
values ('announcements.manage', 'Create, publish, update, and deactivate announcements')
on conflict (name) do nothing;

insert into public.role_permissions (role_id, permission_id)
select r.id, p.id
from public.roles r
cross join public.permissions p
where r.name = 'admin' and p.name = 'announcements.manage'
on conflict do nothing;

alter table public.notification_preferences enable row level security;
alter table public.announcements enable row level security;
alter table public.notifications enable row level security;
alter table public.monitored_transactions enable row level security;
alter table public.push_subscriptions enable row level security;
alter table public.notification_delivery_attempts enable row level security;

revoke all on table public.notification_preferences from public;
revoke all on table public.announcements from public;
revoke all on table public.notifications from public;
revoke all on table public.monitored_transactions from public;
revoke all on table public.push_subscriptions from public;
revoke all on table public.notification_delivery_attempts from public;

grant select, insert, update on public.notification_preferences to authenticated;
grant select on public.announcements to authenticated;
grant select, insert, update, delete on public.announcements to authenticated;
grant select on public.notifications to authenticated;
grant update (read_at) on public.notifications to authenticated;
grant select, insert on public.monitored_transactions to authenticated;
grant select, insert, update, delete on public.push_subscriptions to authenticated;

create policy notification_preferences_select_own
  on public.notification_preferences for select
  using (profile_id = auth.uid());
create policy notification_preferences_insert_own
  on public.notification_preferences for insert
  with check (profile_id = auth.uid());
create policy notification_preferences_update_own
  on public.notification_preferences for update
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

create policy announcements_select_published
  on public.announcements for select
  using (
    (status = 'published' and publish_at <= now()
      and (expires_at is null or expires_at > now()))
    or public.has_permission('announcements.manage')
  );
create policy announcements_insert_admin
  on public.announcements for insert
  with check (
    public.has_permission('announcements.manage')
    and created_by = auth.uid()
  );
create policy announcements_update_admin
  on public.announcements for update
  using (public.has_permission('announcements.manage'))
  with check (public.has_permission('announcements.manage'));
create policy announcements_delete_admin
  on public.announcements for delete
  using (public.has_permission('announcements.manage'));

create policy notifications_select_own
  on public.notifications for select
  using (profile_id = auth.uid());
create policy notifications_update_read_state_own
  on public.notifications for update
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());

create policy monitored_transactions_select_own
  on public.monitored_transactions for select
  using (profile_id = auth.uid());
create policy monitored_transactions_insert_own
  on public.monitored_transactions for insert
  with check (
    profile_id = auth.uid()
    and exists (
      select 1
      from public.wallet_identities wi
      where wi.profile_id = auth.uid()
        and lower(wi.address) = sender_wallet
        and wi.verified_at is not null
    )
  );

create policy push_subscriptions_select_own
  on public.push_subscriptions for select
  using (profile_id = auth.uid());
create policy push_subscriptions_insert_own
  on public.push_subscriptions for insert
  with check (profile_id = auth.uid());
create policy push_subscriptions_update_own
  on public.push_subscriptions for update
  using (profile_id = auth.uid())
  with check (profile_id = auth.uid());
create policy push_subscriptions_delete_own
  on public.push_subscriptions for delete
  using (profile_id = auth.uid());

-- Delivery attempts are worker-owned and intentionally have no client policy.
comment on table public.notification_delivery_attempts is
  'WORKER OWNED. Client roles cannot inspect or mutate push delivery diagnostics.';