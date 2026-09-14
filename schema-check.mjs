import fs from 'node:fs';

const files = fs.readdirSync('.').filter((file) => /^\d+_.*\.sql$/.test(file)).sort();
const sql = files.map((file) => fs.readFileSync(file, 'utf8')).join('\n');

const requiredTables = [
  'profiles', 'wallet_identities', 'roles', 'permissions', 'profile_roles',
  'agent_profiles', 'agent_verifications', 'agent_activity', 'courses',
  'course_modules', 'lessons', 'enrollments', 'lesson_progress', 'certificates',
  'auth_challenges', 'reforestation_projects', 'donations', 'tree_records', 'impact_records',
  'blockchain_networks', 'contracts', 'indexed_blocks', 'indexed_transactions',
  'blockchain_events', 'indexer_sync_state', 'system_health', 'audit_logs',
  'administrative_actions', 'indexer_reconciliation_issues', 'security_events',
  'notification_preferences', 'announcements', 'notifications',
  'monitored_transactions', 'push_subscriptions', 'notification_delivery_attempts',
];

for (const table of requiredTables) {
  if (!sql.includes(`public.${table}`)) throw new Error(`missing table reference: ${table}`);
}

for (const table of requiredTables) {
  if (!sql.includes(`alter table public.${table} enable row level security`)) {
    throw new Error(`missing RLS enablement: ${table}`);
  }
}

if (!sql.includes('unique (chain_id, transaction_hash, log_index)')) {
  throw new Error('missing blockchain event idempotency constraint');
}
if (!sql.includes('public.auth_challenges')) {
  throw new Error('missing server-only auth_challenges table');
}
if (!sql.includes('auth_challenges_deny_all')) {
  throw new Error('missing deny-all auth_challenges policy');
}
if (!sql.includes("values ('education-materials', 'education-materials', false)")) {
  throw new Error('missing private education storage bucket');
}
if (!sql.includes("confirmation_status in ('canonical', 'orphaned', 'confirmed')")) {
  throw new Error('missing reorganization block state');
}
if (!sql.includes('indexed_blocks_one_canonical_per_height')) {
  throw new Error('missing canonical block uniqueness rule');
}
if (!sql.includes('trg_audit_logs_append_only')) {
  throw new Error('missing append-only audit trigger');
}
if (sql.includes('create policy') && sql.match(/on storage\.objects for select\s+using \(bucket_id = '(agent-kyc|reforestation-evidence)'\s+and auth\.role\(\) = 'anon'/)) {
  throw new Error('sensitive storage policy permits anonymous access');
}
if (!sql.includes('used_at') || !sql.includes('expires_at')) {
  throw new Error('missing auth challenge expiration/consumption fields');
}
if (!sql.includes('notifications_deduplication_unique')) {
  throw new Error('missing notification idempotency constraint');
}
if (!sql.includes('alter table public.notifications enable row level security')) {
  throw new Error('missing notification RLS enablement');
}
if (!sql.includes('last_processed_block') || !sql.includes('worker_identity')) {
  throw new Error('missing durable worker checkpoint metadata');
}
if (!sql.includes('notifications_source_event_idx')) {
  throw new Error('missing notification event lineage index');
}
if (sql.includes('raw_user_meta_data') || sql.includes('user_metadata')) {
  throw new Error('authorization must not depend on editable user metadata');
}
if (!sql.includes('grant usage on schema public to anon, authenticated')) {
  throw new Error('missing explicit public schema Data API grant');
}
if (!sql.includes('revoke all on table public.auth_challenges from anon, authenticated')) {
  throw new Error('auth_challenges must remain outside the Data API');
}
if (!files.includes('0019_client_privilege_hardening.sql')) {
  throw new Error('missing post-0018 client privilege hardening migration');
}
if (!files.includes('0020_indexer_contract_compatibility.sql')) {
  throw new Error('missing indexer compatibility migration');
}
if (!sql.includes('commit_indexer_checkpoint')) {
  throw new Error('missing atomic indexer checkpoint function');
}

console.log(`Validated ${files.length} SQL migrations and ${requiredTables.length} required tables.`);