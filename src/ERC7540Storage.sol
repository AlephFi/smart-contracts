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

struct ERC7540StorageData {
    address manager;
    address operationsMultisig;
    address communityMultisig;
    address operator;
    address erc20;
    address custodian;

    uint256 totalAssets;
    uint256 newTotalAssets;
    uint128 totalAssetsExpiration;
    uint128 totalAssetsLifespan;

    uint40 currentDepositBatchId;
    uint40 currentDepositSettleId;
    uint40 lastDepositBatchIdSettled;
    uint40 redeemBatchId;
    uint40 redeemSettleId;
    uint40 lastRedeemBatchIdSettled;

    mapping(uint40 batchId => IERC7540.BatchData) batchs;
    mapping(uint40 settleId => IERC7540.SettleData) settles;
    mapping(address user => uint40 batchId) lastDepositBatchId;
    mapping(address user => uint40 batchId) lastRedeemBatchId;
}
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
library ERC7540Storage {
    uint256 private constant STORAGE_POSITION = uint256(keccak256("storage.erc7540")) - 1;

    function load() internal pure returns (ERC7540StorageData storage sd) {
        uint256 position = STORAGE_POSITION;
        assembly {
            sd.slot := position
        }
    }
}
