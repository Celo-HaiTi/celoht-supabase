# Backup and Recovery

Use Supabase point-in-time recovery or encrypted PostgreSQL backups according
to the project retention policy. Test restoration into a disposable project
before relying on a backup for production recovery.

Recovery order:

1. Restore the database and verify migration state, RLS, private buckets, and
   service secrets.
2. Keep backend and indexer consumers stopped until schema and ownership checks
   pass.
3. Restart the backend, then bootstrap the indexer from official deployment
   metadata and its durable checkpoint.
4. Reconcile from the deployment block. Resolve open reconciliation issues;
   never delete orphaned history to hide a discrepancy.

Migrations are immutable after shared deployment. Recovery from a failed DDL
change uses the backup/PITR path and a new numbered migration, not dashboard
edits.