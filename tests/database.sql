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
insert into public.course_progress (id, profile_id, lesson_id, completed)
values ('10000000-0000-0000-0000-000000000004', '00000000-0000-0000-0000-000000000002', '10000000-0000-0000-0000-000000000003', false)
on conflict (id) do nothing;

insert into public.wallet_identities (profile_id, address)
select id, wallet_address from public.profiles
where id = '00000000-0000-0000-0000-000000000002'
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
end;
$$;

update public.course_progress
set completed = true, completed_at = now()
where profile_id = '00000000-0000-0000-0000-000000000002';

reset role;
do $$
begin
  if (select completed from public.course_progress where id = '10000000-0000-0000-0000-000000000004') then
    raise exception 'cross-user course progress was modified';
  end if;
end;
$$;

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

-- duplicate nonce is not allowed
begin
  insert into public.auth_challenges (wallet_address, nonce, expires_at)
  values ('0x0000000000000000000000000000000000000001', '1111111111111111111111111111111111111111111111111111111111111111', now() + interval '10 minutes');
  raise exception 'duplicate auth_challenge nonce was accepted';
exception when unique_violation then
  null;
end;

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
insert into public.auth_challenges (wallet_address, nonce, expires_at, used_at)
values ('0x0000000000000000000000000000000000000002', '2222222222222222222222222222222222222222222222222222222222222222', now() - interval '1 minute', now() - interval '2 minutes')
on conflict (nonce) do nothing;

select 'database tests passed' as result;