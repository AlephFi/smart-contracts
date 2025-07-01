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

import {IERC7540} from "./interfaces/IERC7540.sol";
import {Checkpoints} from "./libraries/Checkpoints.sol";

struct VaultStorageData {
    address manager;
    address operationsMultisig;
    address oracle;
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
    mapping(uint48 batchId => IERC7540.BatchData) batchs;
    mapping(address user => uint48 batchId) lastDepositBatchId;
    mapping(address user => uint48 batchId) lastRedeemBatchId;
    mapping(address user => Checkpoints.Trace256 shares) sharesOf;
}
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */

library VaultStorage {
    uint256 private constant STORAGE_POSITION = uint256(keccak256("storage.vault")) - 1;

    function load() internal pure returns (VaultStorageData storage sd) {
        uint256 position = STORAGE_POSITION;
        assembly {
            sd.slot := position
        }
    }
}
