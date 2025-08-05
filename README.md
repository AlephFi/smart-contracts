# Aleph Protocol
This repository contains the core smart contracts for Aleph Protocol. 


[![Tests](https://github.com/Othentic-Labs/Aleph/actions/workflows/test.yml/badge.svg)](https://github.com/Othentic-Labs/Aleph//actions/workflows/test.yml)


Aleph is an Infrastructure-as-a-Service platform, enabling fund managers to launch and manage on-chain financial vehicles at scale. 

At the core of the system are Aleph Vaults which are ERC-7540 compliant smart contracts that support asynchronous deposits and redemptions of ERC-20 tokens. Vault shares are minted or burned during batch-based settlements, triggered by oracle with latest NAV (Net Asset Value) inputs. All vaults are upgradeable and deployed deterministically using the Beacon Proxy pattern via a factory.

**Key Features**
- ERC-7540 compliant Vaults
- Asynchronous deposit/redeem/settlement flows
- Protocol-level fee logic
- Role-based governance and upgradeability
- Off-chain yield support via custodian address

<img width="1868" height="755" alt="image" src="https://github.com/user-attachments/assets/159f0d2a-e47c-4afb-b4f6-7eb32636dce2" />


# Smart Contracts
## Vault Factory Contract

The AlephVaultFactory is responsible for deploying Aleph vaults. 

**Key features:**
- Uses CREATE2 for deterministic vault addresses
- Manages protocol-level parameters (oracle, fees, guardian, etc.)
- Enforces caps on performance and management fees
- Access-controlled via Operations Multisig

## Vault Contract
Aleph Vaults are upgradeable contracts that manage deposit, share issuance, redemption, and NAV settlement flows.

### Interfaces Implemented

The Vault contract implements the following interfaces:

**IAlephVault**

- Vault configuration including manager, oracle, custodian addresses 
- View methods for `totalAssets`, `sharesOf`, `assetsOf`
- KYC authSigner support

**IERC7540Deposit**

- Handles async deposit using `requestDeposit(uint256 amount)` and `settleDeposit(uint256 newNAV)` - called by the Oracle
- Tracks per-user deposits per batch
- Exposes pending and estimated shares

**IERC7540Redeem**

- Handles async redeem using `requestRedeem(uint256 shares)` and `settleRedeem(uint256 newNAV)`
- Tracks per-user redeem requests

**IERC20**
- Standard ERC-20 transfer, approve, balanceOf methods
- Vault Shares are issued as ERC-20 tokens

  
## Fee Manager Contract
The FeeManager module calculates and handles:

- Continuous management fee accumulation for each batch settlement
- NAV-triggered performance fees
- Aleph Fee shares minted to feeRecipient

## Usage
```
forge build
forge test
```

## Licensing