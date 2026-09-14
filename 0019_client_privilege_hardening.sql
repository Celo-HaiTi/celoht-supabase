-- Remove unnecessary Data API write privileges left by the broad compatibility
-- grants in 0018. RLS remains the row-level control; these revokes also keep
-- server-owned tables unreachable for client writes if a future policy changes.

revoke insert, update, delete on table
  public.blockchain_transactions,
  public.agent_transactions,
  public.reforestation_contributions,
  public.governance_proposals,
  public.governance_activity,
  public.indexer_state,
  public.indexed_blocks,
  public.indexed_transactions,
  public.blockchain_events,
  public.indexer_sync_state,
  public.donations,
  public.audit_logs,
  public.system_health,
  public.administrative_actions,
  public.indexer_reconciliation_issues,
  public.security_events,
  public.notification_delivery_attempts,
  public.certificates
from anon, authenticated;

revoke insert, update, delete on table public.auth_challenges
from anon, authenticated;

comment on schema public is
  'Client write privileges are explicitly limited; server-owned tables require trusted service-role workflows.';