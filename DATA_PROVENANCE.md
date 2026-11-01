# Data Provenance

Blockchain state is authoritative for deployed contracts, transactions,
events, payment facts, registry state, and governance observations. The
indexer stores decoded projections with chain, block, transaction, contract,
log, timestamp, and confirmation provenance.

The backend is authoritative for profiles, verified wallet-link workflows,
KYC review, quiz grading, education progress, project catalog data,
physical-impact evidence, and administrative workflows. Planting evidence is
submitted separately and requires an append-only reviewer decision before it
is considered verified. A contribution never implies a planted tree.

When chain, indexer, and database disagree, the indexer records an
`indexer_reconciliation_issues` row. Orphaned chain observations remain for
diagnosis but are not treated as canonical. Rebuilds replay canonical chain
data from the deployment block and restore legitimate backend application data
from backup.