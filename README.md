# Aleph Protocol
Aleph is a financial infrastructure that connects digital asset allocators with sophisticated money managers.

This repository contains the core smart contracts for Aleph Protocol. 

[![Tests](https://github.com/Othentic-Labs/Aleph/actions/workflows/test.yml/badge.svg)](https://github.com/Othentic-Labs/Aleph//actions/workflows/test.yml)


## Architecture
At the core of the system are Aleph Vaults which are ERC-7540 compliant smart contracts that support asynchronous deposits and redemptions of ERC-20 tokens. Vault shares are minted or burned during batch-based settlements, triggered by oracle with latest NAV (Net Asset Value) inputs. All vaults are upgradeable and deployed deterministically using the Beacon Proxy pattern via a factory.

**Key Features**
- ERC-7540 compliant Vaults
- Asynchronous deposit/redeem/settlement flows
- Protocol-level fee logic
- Role-based governance and upgradeability
- Off-chain yield support via custodian address

<img width="1868" height="755" alt="image" src="https://github.com/user-attachments/assets/159f0d2a-e47c-4afb-b4f6-7eb32636dce2" />


## Smart Contracts
## Vault Factory Contract

The [AlephVaultFactory](https://github.com/Othentic-Labs/Aleph/blob/main/src/AlephVaultFactory.sol) is responsible for deploying Aleph vaults. 

**Key features:**
- Deploy vaults with deterministic addresses (CREATE2)
- Manages default protocol-level parameters (oracle, fees, guardian, etc.)
- Access-controlled via Operations Multisig

## Vault Contract
[AlephVault](https://github.com/Othentic-Labs/Aleph/blob/main/src/AlephVault.sol) are upgradeable contracts that manage user deposit, share issuance, redemption, and NAV settlement flows.

### Interfaces Implemented

The Vault contract implements the following interfaces:

**IAlephVault**

- Vault configuration including manager, oracle, custodian addresses 
- View methods for Asset & Share information (totalAssets, sharesOf, assetsOf, pricePerShare), Roles & Config (custodian, oracle, guardian, etc.), highWaterMark, and other vault-level configurations.
- AuthSigner support for KYC and Allocator whitelisting by Manager

**IERC7540Deposit**

- Handles async deposit using `requestDeposit` and `settleDeposit`
- Tracks per-user deposits per batch
- Exposes pending and estimated shares

**IERC7540Redeem**

- Handles async redeem using `requestRedeem` and `settleRedeem`
- Tracks per-user redeem requests

An Oracle contract calls settleDeposit or settleRedeem to settle pending deposits and withdrawals.

## Fee Manager Contract
The [FeeManager](https://github.com/Othentic-Labs/Aleph/blob/main/src/FeeManager.sol) module calculates and handles Platform fees using:

- Continuous management fee accumulation for each batch settlement
- Aleph Fee shares are minted to MANAGEMENT_FEE_RECIPIENT and PERFORMANCE_FEE_RECIPIENT address
- Upon fee collection, the amount is transfered to the fee recipient address

## Getting Started
### Prerequisites

- [Foundry](https://getfoundry.sh/) for smart contract development

### Installation
```
git clone https://github.com/Othentic-Labs/Aleph.git
cd Aleph
forge install
forge build
forge test
```

## Licensing

## Resources

- [ERC-7540 Standard](https://eips.ethereum.org/EIPS/eip-7540)
- [Foundry Documentation](https://book.getfoundry.sh/)
- Aleph Protocol Documentation
