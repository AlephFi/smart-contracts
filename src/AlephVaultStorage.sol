// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.25;
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

import {IAlephVault} from "./interfaces/IAlephVault.sol";
import {Checkpoints} from "./libraries/Checkpoints.sol";

struct AlephVaultStorageData {
    string metadataUrl;
    address admin;
    address operationsMultisig;
    address oracle;
    address guardian;
    address erc20;
    address custodian;
    //uint128 totalAssetsExpiration;
    //uint128 totalAssetsLifespan;
    uint48 batchDuration;
    uint48 startTimeStamp;
    uint48 depositSettleId;
    uint48 redeemSettleId;
    Checkpoints.Trace256 assets;
    Checkpoints.Trace256 shares;
    mapping(uint48 batchId => IAlephVault.BatchData) batchs;
    mapping(address user => uint48 batchId) lastDepositBatchId;
    mapping(address user => uint48 batchId) lastRedeemBatchId;
    mapping(address user => Checkpoints.Trace256 shares) sharesOf;
}
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */

library AlephVaultStorage {
    uint256 private constant STORAGE_POSITION = uint256(keccak256("storage.aleph.vault")) - 1;

    function load() internal pure returns (AlephVaultStorageData storage sd) {
        uint256 position = STORAGE_POSITION;
        assembly {
            sd.slot := position
        }
    }
}
