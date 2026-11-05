-- A checkpoint must advance both canonical and compatibility state or neither.
create or replace function public.commit_indexer_checkpoint(
  p_chain_id integer,
  p_contract_address text,
  p_block_number bigint,
  p_block_hash text,
  p_parent_hash text,
  p_block_time timestamptz,
  p_latest_confirmed_block bigint
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_contract_id uuid;
begin
  select id into v_contract_id
  from public.contracts
  where chain_id = p_chain_id
    and contract_address = p_contract_address;

  if v_contract_id is null then
    raise exception 'Unknown indexer contract % on chain %', p_contract_address, p_chain_id;
  end if;

  insert into public.indexed_blocks (
    chain_id, block_number, block_hash, parent_hash, block_time,
    confirmed_at, confirmation_status
  ) values (
    p_chain_id, p_block_number, p_block_hash, p_parent_hash, p_block_time,
    now(), 'canonical'
  )
  on conflict (chain_id, block_number, block_hash) do update set
    parent_hash = excluded.parent_hash,
    block_time = excluded.block_time,
    confirmed_at = excluded.confirmed_at,
    confirmation_status = 'canonical';

  update public.indexer_state
  set last_processed_block = p_block_number,
      latest_confirmed_block = p_latest_confirmed_block,
      sync_status = 'syncing',
      last_successful_sync_at = now(),
      last_error = null
  where chain_id = p_chain_id
    and contract_address = p_contract_address;

  if not found then
    raise exception 'Missing compatibility indexer state for contract % on chain %',
      p_contract_address, p_chain_id;
  end if;

  update public.indexer_sync_state
  set next_block = p_block_number + 1,
      latest_confirmed_block = p_latest_confirmed_block,
      last_processed_block = p_block_number,
      last_processed_block_hash = p_block_hash,
      last_processed_parent_hash = p_parent_hash,
      status = 'idle',
      last_success_at = now(),
      last_error = null
  where chain_id = p_chain_id
    and contract_id = v_contract_id;

  if not found then
    raise exception 'Missing canonical sync state for contract % on chain %', p_contract_address, p_chain_id;
  end if;
end;
$$;

comment on function public.commit_indexer_checkpoint(integer, text, bigint, text, text, timestamptz, bigint) is
  'INDEXER SERVICE-ROLE ONLY. Commits a canonical block anchor and both checkpoint ledgers atomically; fails and rolls back if either ledger is missing.';