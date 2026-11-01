-- Disposable PostgreSQL/Supabase smoke and isolation tests.
-- The CI job runs this file as the database owner after applying all migrations.

create or replace function auth.uid()
returns uuid language sql stable
as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;

create or replace function auth.role()
returns text language sql stable
as $$ select coalesce(nullif(current_setting('request.jwt.claim.role', true), ''), 'anon') $$;

grant usage on schema public to authenticated;
alter table storage.objects enable row level security;
grant usage on schema storage to anon;
grant select on storage.objects to anon;
grant select on public.courses to anon;
grant select on public.agents to anon;
grant select, insert, update on public.profiles, public.course_progress,
  public.agent_profiles, public.agent_verifications, public.blockchain_events,
  public.administrative_actions
  to authenticated;

insert into auth.users (id) values
  ('00000000-0000-0000-0000-000000000001'),
  ('00000000-0000-0000-0000-000000000002')
on conflict (id) do nothing;

insert into public.profiles (id, wallet_address, role) values
  ('00000000-0000-0000-0000-000000000001', '0x0000000000000000000000000000000000000001', 'user'),
  ('00000000-0000-0000-0000-000000000002', '0x0000000000000000000000000000000000000002', 'user')
on conflict (id) do nothing;

insert into public.courses (id, title, status)
values ('10000000-0000-0000-0000-000000000001', 'Isolation test course', 'published')
on conflict (id) do nothing;
insert into public.course_modules (id, course_id, title, order_index)
values ('10000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000001', 'Module', 0)
on conflict (id) do nothing;
insert into public.lessons (id, module_id, title, order_index)
values ('10000000-0000-0000-0000-000000000003', '10000000-0000-0000-0000-000000000002', 'Lesson', 0)
on conflict (id) do nothing;
insert into public.quizzes (id, lesson_id, title, status)
values ('40000000-0000-0000-0000-000000000001', '10000000-0000-0000-0000-000000000003', 'Quiz isolation fixture', 'published')
on conflict (id) do nothing;
insert into public.quiz_questions (id, quiz_id, prompt, order_index)
values ('40000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000001', 'Question fixture', 0)
on conflict (id) do nothing;
insert into public.quiz_options (id, question_id, option_text, order_index) values
  ('40000000-0000-0000-0000-000000000003', '40000000-0000-0000-0000-000000000002', 'Option one', 0),
  ('40000000-0000-0000-0000-000000000004', '40000000-0000-0000-0000-000000000002', 'Option two', 1)
on conflict (id) do nothing;
insert into public.quiz_answer_keys (question_id, correct_option_id)
values ('40000000-0000-0000-0000-000000000002', '40000000-0000-0000-0000-000000000003')
on conflict (question_id) do nothing;
insert into public.quiz_attempts (id, quiz_id, profile_id) values
  ('40000000-0000-0000-0000-000000000005', '40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001'),
  ('40000000-0000-0000-0000-000000000006', '40000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000002')
on conflict (id) do nothing;

insert into public.wallet_identities (id, profile_id, address)
values ('50000000-0000-0000-0000-000000000001', '00000000-0000-0000-0000-000000000001', '0x0000000000000000000000000000000000000003')
on conflict (id) do nothing;

insert into public.reforestation_projects (id, title, status)
values ('60000000-0000-0000-0000-000000000001', 'Evidence isolation fixture', 'published')
on conflict (id) do nothing;
insert into public.reforestation_evidence (id, project_id, storage_path, submitted_by)
values
  ('60000000-0000-0000-0000-000000000002', '60000000-0000-0000-0000-000000000001', 'private/user-a/evidence-a', '00000000-0000-0000-0000-000000000001'),
  ('60000000-0000-0000-0000-000000000003', '60000000-0000-0000-0000-000000000001', 'private/user-b/evidence-b', '00000000-0000-0000-0000-000000000002')
on conflict (id) do nothing;

insert into public.course_progress (id, profile_id, lesson_id, completed)
values ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000003', false)
on conflict (id) do nothing;

insert into public.wallet_identities (profile_id, address, verified_at)
select id, wallet_address, now() from public.profiles
where id in (
  '00000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000002'
)
on conflict (address) do nothing;

insert into public.agent_profiles (id, profile_id, wallet_identity_id)
select '20000000-0000-0000-0000-000000000001', p.id, w.id
from public.profiles p
join public.wallet_identities w on w.profile_id = p.id and w.address = p.wallet_address
where p.id = '00000000-0000-0000-0000-000000000002'
on conflict (id) do nothing;
insert into public.agent_verifications (id, agent_profile_id, document_type, document_path)
values ('20000000-0000-0000-0000-000000000002', '20000000-0000-0000-0000-000000000001', 'passport', 'private/test-document')
on conflict (id) do nothing;

insert into public.notification_preferences (profile_id)
values ('00000000-0000-0000-0000-000000000001')
on conflict (profile_id) do nothing;

insert into public.notifications (
  id, profile_id, recipient_wallet, notification_type, title, message,
  deduplication_key, creation_source
)
values (
  '30000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  '0x0000000000000000000000000000000000000001',
  'wallet_security_alert', 'Isolation notification', 'Private notification fixture',
  'test:notification:one', 'security'
)
on conflict (deduplication_key) do nothing;

set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', false);
select set_config('request.jwt.claim.role', 'authenticated', false);

do $$
declare
  visible_rows integer;
begin
  select count(*) into visible_rows from public.course_progress;
  if visible_rows <> 0 then
    raise exception 'cross-user course progress is readable';
  end if;

  select count(*) into visible_rows from public.agent_verifications;
  if visible_rows <> 0 then
    raise exception 'cross-user KYC is readable';
  end if;

  select count(*) into visible_rows from public.administrative_actions;
  if visible_rows <> 0 then
    raise exception 'administrative data is readable by a normal user';
  end if;

  select count(*) into visible_rows from public.notifications;
  if visible_rows <> 1 then
    raise exception 'own notification is not readable';
  end if;

  select count(*) into visible_rows from public.quiz_attempts;
  if visible_rows <> 1 then
    raise exception 'quiz attempts are not isolated by profile';
  end if;

  select count(*) into visible_rows from public.reforestation_evidence;
  if visible_rows <> 1 then
    raise exception 'unverified planting evidence is not isolated by submitter';
  end if;

  insert into public.quiz_responses (attempt_id, quiz_id, question_id, selected_option_id)
  values (
    '40000000-0000-0000-0000-000000000005',
    '40000000-0000-0000-0000-000000000001',
    '40000000-0000-0000-0000-000000000002',
    '40000000-0000-0000-0000-000000000003'
  );

  begin
    perform count(*) from public.quiz_answer_keys;
    raise exception 'authenticated users can read quiz answer keys';
  exception when insufficient_privilege then
    null;
  end;

  begin
    update public.quiz_attempts set score = 100, passed = true, submitted_at = now(), graded_at = now()
    where id = '40000000-0000-0000-0000-000000000005';
    raise exception 'authenticated user can grade a quiz attempt';
  exception when insufficient_privilege then
    null;
  end;

  begin
    insert into public.wallet_identities (profile_id, address, verified_at)
    values ('00000000-0000-0000-0000-000000000001', '0x0000000000000000000000000000000000000004', now());
    raise exception 'authenticated user can self-assert wallet verification';
  exception when insufficient_privilege then
    null;
  end;

  begin
    update public.wallet_identities set verified_at = now()
    where id = '50000000-0000-0000-0000-000000000001';
    raise exception 'authenticated user can verify a wallet';
  exception when insufficient_privilege then
    null;
  end;

  begin
    insert into public.agent_profiles (profile_id, wallet_identity_id)
    values ('00000000-0000-0000-0000-000000000001', '50000000-0000-0000-0000-000000000001');
    raise exception 'agent application accepted an unverified wallet';
  exception when check_violation then
    null;
  end;

  update public.notifications
  set read_at = now()
  where id = '30000000-0000-0000-0000-000000000001';
end;
$$;

update public.course_progress
set completed = true, completed_at = now()
where profile_id = '00000000-0000-0000-0000-000000000002';

reset role;

insert into public.profile_roles (profile_id, role_id)
select '00000000-0000-0000-0000-000000000001', id
from public.roles where name = 'reviewer'
on conflict do nothing;

set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', false);
do $$
declare
  visible_rows integer;
begin
  select count(*) into visible_rows from public.reforestation_evidence;
  if visible_rows <> 2 then
    raise exception 'authorized reviewer cannot read evidence submissions';
  end if;

  insert into public.reforestation_evidence_reviews (
    evidence_id, reviewer_id, decision, trees_verified, notes
  ) values (
    '60000000-0000-0000-0000-000000000003', '00000000-0000-0000-0000-000000000001', 'approved', 3, 'Reviewed fixture'
  );

  begin
    insert into public.reforestation_evidence_reviews (evidence_id, reviewer_id, decision)
    values ('60000000-0000-0000-0000-000000000002', '00000000-0000-0000-0000-000000000001', 'approved');
    raise exception 'reviewer can approve their own evidence';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;
reset role;

delete from public.profile_roles pr
using public.roles r
where pr.role_id = r.id
  and pr.profile_id = '00000000-0000-0000-0000-000000000001'
  and r.name = 'reviewer';

do $$
begin
  if (select read_at is null from public.notifications where id = '30000000-0000-0000-0000-000000000001') then
    raise exception 'own notification read state was not updated';
  end if;

  if (select completed from public.course_progress where id = '10000000-0000-0000-0000-000000000004') then
    raise exception 'cross-user course progress was modified';
  end if;

  if not exists (
    select 1 from public.reforestation_evidence
    where id = '60000000-0000-0000-0000-000000000003'
      and status = 'verified' and trees_verified = 3
      and verified_by = '00000000-0000-0000-0000-000000000001'
  ) then
    raise exception 'review decision did not update the verified evidence summary';
  end if;

  if not exists (
    select 1 from public.audit_logs
    where actor_id = '00000000-0000-0000-0000-000000000001'
      and action = 'evidence_verification'
      and target_table = 'reforestation_evidence'
      and target_id = '60000000-0000-0000-0000-000000000003'
  ) then
    raise exception 'evidence review did not create its privileged-action audit log';
  end if;

  if exists (
    select 1 from public.agent_profiles
    where profile_id = '00000000-0000-0000-0000-000000000001'
  ) then
    raise exception 'unverified wallet created an agent application';
  end if;
end;
$$;

set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000002', false);
do $$
declare
  visible_rows integer;
begin
  select count(*) into visible_rows from public.quiz_attempts;
  if visible_rows <> 1 then
    raise exception 'user cannot read their own quiz attempt';
  end if;

  select count(*) into visible_rows from public.quiz_responses;
  if visible_rows <> 0 then
    raise exception 'quiz responses are not isolated by attempt owner';
  end if;

  select count(*) into visible_rows from public.reforestation_evidence;
  if visible_rows <> 1 then
    raise exception 'unverified planting evidence is not isolated by submitter';
  end if;

  select count(*) into visible_rows from public.reforestation_evidence_reviews;
  if visible_rows <> 1 then
    raise exception 'evidence submitter cannot read their own review';
  end if;
end;
$$;
reset role;

insert into public.blockchain_networks (chain_id, network, native_symbol, is_enabled)
values (11142220, 'celo-sepolia-test', 'CELO', true)
on conflict (chain_id) do nothing;
insert into public.contracts (chain_id, contract_name, contract_address, metadata_ref)
values (11142220, 'TestContract', '0x0000000000000000000000000000000000000010', 'test-fixture')
on conflict (chain_id, contract_address) do nothing;
insert into public.indexed_transactions (chain_id, transaction_hash, block_number, block_hash)
values (11142220, '0x0000000000000000000000000000000000000000000000000000000000000011', 1, '0x0000000000000000000000000000000000000000000000000000000000000012')
on conflict (chain_id, transaction_hash) do nothing;

do $$
declare
  contract_uuid uuid;
  transaction_uuid uuid;
begin
  select id into contract_uuid from public.contracts where chain_id = 11142220 and contract_name = 'TestContract';
  select id into transaction_uuid from public.indexed_transactions where chain_id = 11142220 and transaction_hash = '0x0000000000000000000000000000000000000000000000000000000000000011';
  insert into public.blockchain_events (chain_id, contract_id, transaction_id, block_number, block_hash, transaction_hash, log_index, event_name)
  values (11142220, contract_uuid, transaction_uuid, 1, '0x0000000000000000000000000000000000000000000000000000000000000012', '0x0000000000000000000000000000000000000000000000000000000000000011', 0, 'TestEvent');
  begin
    insert into public.blockchain_events (chain_id, contract_id, transaction_id, block_number, block_hash, transaction_hash, log_index, event_name)
    values (11142220, contract_uuid, transaction_uuid, 1, '0x0000000000000000000000000000000000000000000000000000000000000012', '0x0000000000000000000000000000000000000000000000000000000000000011', 0, 'TestEvent');
    raise exception 'duplicate blockchain event was accepted';
  exception when unique_violation then
    null;
  end;
end;
$$;

insert into public.indexer_sync_state (chain_id, contract_id, next_block, status)
select 11142220, id, 2, 'idle' from public.contracts
where chain_id = 11142220 and contract_name = 'TestContract'
on conflict (chain_id, contract_id) do update set next_block = excluded.next_block;

do $$
begin
  if not exists (select 1 from storage.buckets where id = 'agent-kyc' and public = false)
    or not exists (select 1 from storage.buckets where id = 'reforestation-evidence' and public = false)
    or not exists (select 1 from storage.buckets where id = 'certificates' and public = false) then
    raise exception 'sensitive storage bucket is public or missing';
  end if;
end;
$$;

set role anon;
do $$
declare
  visible_rows integer;
begin
  select count(*) into visible_rows
  from storage.objects
  where bucket_id in ('agent-kyc', 'reforestation-evidence', 'certificates');
  if visible_rows <> 0 then
    raise exception 'anonymous storage access to sensitive buckets is allowed';
  end if;
end;
$$;
reset role;

-- auth_challenges must be server-only and deny direct browser access
insert into public.auth_challenges (wallet_address, nonce, expires_at)
values ('0x0000000000000000000000000000000000000001', '1111111111111111111111111111111111111111111111111111111111111111', now() + interval '5 minutes')
on conflict (nonce) do nothing;

set role authenticated;
do $$
begin
  begin
    perform count(*) from public.auth_challenges;
    raise exception 'authenticated users can read auth challenge rows';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;
reset role;

-- Structural checks complement the behavioral isolation checks above.
do $$
declare
  missing_rls text[];
begin
  select array_agg(required_table order by required_table)
    into missing_rls
  from unnest(array[
    'profiles', 'wallet_identities', 'roles', 'permissions', 'profile_roles',
    'role_permissions', 'agents', 'agent_kyc', 'agent_profiles',
    'agent_verifications', 'agent_activity', 'courses', 'course_modules',
    'lessons', 'quizzes', 'quiz_questions', 'quiz_options', 'quiz_answer_keys',
    'quiz_attempts', 'quiz_responses', 'course_progress', 'certificates', 'enrollments',
    'lesson_progress', 'blockchain_networks', 'contracts', 'indexed_blocks',
    'indexed_transactions', 'blockchain_events', 'indexer_sync_state',
    'donations', 'tree_records', 'impact_records', 'administrative_actions',
    'audit_logs', 'system_health', 'indexer_reconciliation_issues',
    'security_events', 'notification_preferences', 'announcements',
    'notifications', 'monitored_transactions', 'push_subscriptions',
    'notification_delivery_attempts', 'auth_challenges',
    'reforestation_evidence_reviews'
  ]) as required_table
  left join pg_class c on c.relname = required_table
  left join pg_namespace n on n.oid = c.relnamespace and n.nspname = 'public'
  where c.oid is null or not c.relrowsecurity;

  if missing_rls is not null then
    raise exception 'tables without RLS: %', missing_rls;
  end if;
end;
$$;

do $$
begin
  if has_table_privilege('anon', 'public.auth_challenges', 'select')
    or has_table_privilege('authenticated', 'public.auth_challenges', 'select')
    or has_table_privilege('anon', 'public.auth_challenges', 'insert')
    or has_table_privilege('authenticated', 'public.auth_challenges', 'insert') then
    raise exception 'auth_challenges has direct Data API privileges';
  end if;
end;
$$;

-- duplicate nonce is not allowed
do $$
begin
  begin
    insert into public.auth_challenges (wallet_address, nonce, expires_at)
    values ('0x0000000000000000000000000000000000000001', '1111111111111111111111111111111111111111111111111111111111111111', now() + interval '10 minutes');
    raise exception 'duplicate auth_challenge nonce was accepted';
  exception when unique_violation then
    null;
  end;
end;
$$;

set role anon;
do $$
begin
  begin
    perform count(*) from public.auth_challenges;
    raise exception 'anonymous users can read auth challenge rows';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;
reset role;

-- expired and consumed challenge states remain invalid for replay
insert into public.auth_challenges (wallet_address, nonce, expires_at, used_at, created_at)
values ('0x0000000000000000000000000000000000000002', '2222222222222222222222222222222222222222222222222222222222222222', now() - interval '1 minute', now() - interval '2 minutes', now() - interval '3 minutes')
  on conflict (nonce) do nothing;

-- Additional ownership and client privilege assertions.
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-000000000001', false);

do $$
declare
  visible_rows integer;
begin
  select count(*) into visible_rows from public.profiles;
  if visible_rows <> 1 then
    raise exception 'profile cross-user isolation failed';
  end if;

  begin
    update public.profiles set role = 'admin'
    where id = '00000000-0000-0000-0000-000000000001';
    raise exception 'profile role escalation was accepted';
  exception when insufficient_privilege or check_violation then
    null;
  end;

  begin
    insert into public.indexed_blocks (chain_id, block_number, block_hash)
    values (11142220, 900, '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa');
    raise exception 'authenticated client wrote an indexer-owned table';
  exception when insufficient_privilege then
    null;
  end;
end;
$$;
reset role;

do $$
begin
  begin
    insert into public.notifications (
      profile_id, recipient_wallet, notification_type, title, message,
      deduplication_key, creation_source
    ) values (
      '00000000-0000-0000-0000-000000000001',
      '0x0000000000000000000000000000000000000001',
      'wallet_security_alert', 'Duplicate notification', 'Duplicate fixture',
      'test:notification:one', 'security'
    );
    raise exception 'duplicate notification was accepted';
  exception when unique_violation then
    null;
  end;
end;
$$;

insert into public.indexed_blocks (chain_id, block_number, block_hash, confirmation_status)
values (11142220, 900, '0xaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa', 'canonical');
insert into public.indexed_blocks (chain_id, block_number, block_hash, confirmation_status)
values (11142220, 900, '0xbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb', 'orphaned');

do $$
begin
  begin
    insert into public.indexed_blocks (chain_id, block_number, block_hash, confirmation_status)
    values (11142220, 900, '0xcccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc', 'confirmed');
    raise exception 'multiple canonical blocks at one height were accepted';
  exception when unique_violation then
    null;
  end;
end;
$$;

select 'database tests passed' as result;