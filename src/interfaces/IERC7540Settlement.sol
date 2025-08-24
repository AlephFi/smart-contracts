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

import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */

interface IERC7540Settlement {
    struct SettleDepositBatchParams {
        uint8 seriesId;
        uint48 batchId;
        uint256 totalAssets;
        uint256 totalShares;
    }

    struct SettleRedeemBatchParams {
        uint48 batchId;
        uint8 classId;
        address underlyingToken;
        uint256[] newTotalAssets;
    }

    event SettleDeposit(
        uint48 indexed fromBatchId,
        uint48 indexed toBatchId,
        uint256 amountToSettle,
        uint256 totalAssets,
        uint256 totalShares,
        uint256 pricePerShare
    );

    event DepositRequestSettled(address indexed user, uint256 amount, uint256 sharesToMint);

    event SettleDepositBatch(
        uint48 indexed batchId,
        uint256 totalAmountToDeposit,
        uint256 totalSharesToMint,
        uint256 totalAssets,
        uint256 totalShares,
        uint256 pricePerShare
    );

    event SettleRedeem(uint48 indexed fromBatchId, uint48 indexed toBatchId);

    event RedeemRequestSettled(
        address indexed user, uint8 indexed classId, uint8 indexed seriesId, uint256 sharesToBurn, uint256 assets
    );

    event SettleRedeemBatch(uint48 indexed batchId, address indexed user, uint256 totalAmountToRedeem);

    error InvalidNewTotalAssets();
    error NoDepositsToSettle();
    error NoRedeemsToSettle();

    error DelegateCallFailed(bytes _data);

    /**
     * @notice Settles all pending deposits up to the current batch.
     * @param _classId The ID of the share class to settle deposits for.
     * @param _newTotalAssets The new total assets after settlement for each series.
     */
    function settleDeposit(uint8 _classId, uint256[] calldata _newTotalAssets) external;

    /**
     * @notice Settles all pending redeems up to the current batch.
     * @param _classId The ID of the share class to settle redeems for.
     * @param _newTotalAssets The new total assets after settlement for each series.
     */
    function settleRedeem(uint8 _classId, uint256[] calldata _newTotalAssets) external;
}
