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
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */

interface IAlephVaultSettlement {
    struct SettlementParams {
        uint8 classId;
        uint48 toBatchId;
        uint256[] newTotalAssets;
        AuthLibrary.AuthSignature authSignature;
    }

    struct SettleDepositDetails {
        bool createSeries;
        uint8 classId;
        uint8 seriesId;
        uint48 batchId;
        uint48 toBatchId;
        uint256 totalAssets;
        uint256 totalShares;
    }

    struct SettleRedeemBatchParams {
        uint48 batchId;
        uint8 classId;
        address underlyingToken;
    }

    struct UserConsolidationDetails {
        address user;
        uint8 classId;
        uint8 seriesId;
        uint48 toBatchId;
        uint256 shares;
        uint256 amountToTransfer;
        uint256 sharesToTransfer;
    }

    struct DepositRequestParams {
        address user;
        uint256 amount;
        uint256 sharesToMint;
    }

    event SettleDeposit(
        uint48 indexed fromBatchId,
        uint48 indexed toBatchId,
        uint8 classId,
        uint8 seriesId,
        uint256 amountToSettle,
        uint256 totalAssets,
        uint256 totalShares
    );

    event NewSeriesCreated(uint8 classId, uint8 seriesId, uint48 toBatchId);

    event SeriesConsolidated(
        uint8 classId, uint8 seriesId, uint48 toBatchId, uint256 amountToTransfer, uint256 sharesToTransfer
    );

    event AllSeriesConsolidated(
        uint8 classId,
        uint8 fromSeriesId,
        uint8 toSeriesId,
        uint48 toBatchId,
        uint256 totalAmountToTransfer,
        uint256 totalSharesToTransfer
    );

    event UserSharesConsolidated(UserConsolidationDetails userConsolidationDetails);

    event DepositRequestSettled(
        address indexed user, uint8 classId, uint8 seriesId, uint256 amount, uint256 sharesToMint, uint48 toBatchId
    );

    event SettleDepositBatch(
        uint48 indexed batchId, uint8 classId, uint8 seriesId, uint256 totalAmountToDeposit, uint256 totalSharesToMint
    );

    event SettleRedeem(uint48 indexed fromBatchId, uint48 indexed toBatchId, uint8 classId);

    event RedeemRequestSettled(uint48 indexed batchId, address indexed user, uint8 classId, uint256 amountToRedeem);

    event RedeemRequestSliceSettled(
        uint48 indexed batchId,
        address indexed user,
        uint8 classId,
        uint8 seriesId,
        uint256 amountToRedeem,
        uint256 sharesToBurn
    );

    event SettleRedeemBatch(uint48 indexed batchId, uint8 indexed classId, uint256 totalAmountToRedeem);

    error InvalidNewTotalAssets();
    error InvalidToBatchId();
    error NoDepositsToSettle();
    error NoRedeemsToSettle();

    error DelegateCallFailed(bytes _data);

    /**
     * @notice Settles all pending deposits up to the current batch.
     * @param _settlementParams The parameters for the settlement.
     */
    function settleDeposit(SettlementParams calldata _settlementParams) external;

    /**
     * @notice Settles all pending redeems up to the current batch.
     * @param _settlementParams The parameters for the settlement.
     */
    function settleRedeem(SettlementParams calldata _settlementParams) external;
}
