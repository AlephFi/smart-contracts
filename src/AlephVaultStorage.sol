// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;
/*
  ______   __                      __
 /      \ /  |                    /  |
/$$$$$$  |$$ |  ______    ______  $$ |____
$$ |__$$ |$$ | /      \  /      \ $$      \
$$    $$ |$$ |/$$$$$$  |/$$$$$$  |$$$$$$$  |
$$$$$$$$ |$$ |$$    $$ |$$ |  $$ |$$ |  $$ |
$$ |  $$ |$$ |$$$$$$$$/ $$ |__$$ |$$ |  $$ |
$$ |  $$ |$$ |$$       |$$    $$/ $$ |  $$ |
$$/   $$/ $$/  $$$$$$$/ $$$$$$$/  $$/   $$/
                        $$ |
                        $$ |
                        $$/
*/

import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {TimelockRegistry} from "@aleph-vault/libraries/TimelockRegistry.sol";

/**
 * @notice Data layout for the aleph vault storage.
 * @param name The name of the vault.
 * @param isDepositAuthEnabled Whether the deposit authentication is enabled.
 * @param isSettlementAuthEnabled Whether the settlement authentication is enabled.
 * @param shareClassesId The number of share classes.
 * @param startTimeStamp The start timestamp of the vault.
 * @param operationsMultisig The operations multisig address.
 * @param manager The manager address.
 * @param oracle The oracle address.
 * @param guardian The guardian address.
 * @param authSigner The auth signer address.
 * @param underlyingToken The underlying token address.
 * @param custodian The custodian address.
 * @param accountant The accountant address.
 * @param totalAmountToDeposit The total amount to deposit.
 * @param totalAmountToWithdraw The total amount to withdraw.
 * @param shareClasses The share classes.
 * @param timelocks The timelocks.
 * @param moduleImplementations The module implementations.
 * @param redeemableAmount The redeemable amount for each user.
 */
struct AlephVaultStorageData {
    string name;
    bool isDepositAuthEnabled;
    bool isSettlementAuthEnabled;
    uint8 shareClassesId;
    uint48 startTimeStamp;
    address operationsMultisig;
    address manager;
    address oracle;
    address guardian;
    address authSigner;
    address underlyingToken;
    address custodian;
    address accountant;
    uint256 totalAmountToDeposit;
    uint256 totalAmountToWithdraw;
    mapping(uint8 classId => IAlephVault.ShareClass) shareClasses;
    mapping(bytes4 => TimelockRegistry.Timelock) timelocks;
    mapping(bytes4 => address) moduleImplementations;
    mapping(address user => uint256) redeemableAmount;
    uint48 syncExpirationBatches;
}

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
library AlephVaultStorage {
    uint256 private constant STORAGE_POSITION = uint256(keccak256("storage.aleph.vault")) - 1;

    function load() internal pure returns (AlephVaultStorageData storage sd) {
        uint256 _position = STORAGE_POSITION;
        assembly {
            sd.slot := _position
        }
    }
}
