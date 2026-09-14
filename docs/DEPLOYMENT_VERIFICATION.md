# Deployment and ABI Verification

## Status

- Celo Sepolia: PARTIALLY VERIFIED
- Mainnet: FAIL-CLOSED / NOT VERIFIED
- ABI verification: PARTIALLY VERIFIED

## Network matrix

| Network | Chain ID | RPC | Contract source | ABI source | Verification | Status |
| --- | ---: | --- | --- | --- | --- | --- |
| Celo Sepolia | 11142220 | `https://forno.celo-sepolia.celo-testnet.org` | Official `celoSepolia.json` | Indexer artifacts, including verified USDm hash | RPC returned `0xaa044c`; bytecode was present at the official AgentRegistry address | PARTIALLY VERIFIED |
| Celo Mainnet | 42220 | Not supplied | No official manifest available | No verified ABI available | Activation is rejected by indexer configuration | FAIL-CLOSED / NOT VERIFIED |

## Source provenance

- `celoht-smart-contracts` shallow clone: commit
  `6c3786c6fd6433734cf46e110846a51d072fe812`.
- `celoht-indexer` shallow clone: commit
  `7391f251a6f242a30dc2a9560a7a47802a1403db`.
- Official Sepolia deployment manifest: `deployments/celoSepolia.json`.
- USDm ABI SHA-256:
  `c9a8c29a950e13c1ef27291f65d7bbc7475247af36f97bb6df1af9f3cfbc2031`.
- The manifest identifies Celo Sepolia chain ID `11142220` and the USDm
  settlement asset. CELO remains gas; this schema does not create a CeloHT
  token.

## Current evidence

- Repository static validation passes for 20 migrations.
- Disposable PostgreSQL migration and smoke tests pass.
- Public Celo Sepolia RPC chain ID and deployed bytecode checks pass.
- Full ABI-to-bytecode verification and live indexer runtime verification were
  not completed.

## Fail-closed requirement

Missing or unverified Mainnet metadata must result in no Mainnet activation, no
fabricated balances or transfers, no indexing, and no readiness claim.
