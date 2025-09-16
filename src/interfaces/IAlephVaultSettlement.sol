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

import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */

interface IAlephVaultSettlement {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Emitted when a deposit cycle is settled.
     * @param fromBatchId The batch ID from which the deposits are settled.
     * @param toBatchId The batch ID up to which the deposits are settled.
     * @param classId The ID of the share class for which the deposits are settled.
     * @param seriesId The ID of the share series in which the deposits are settled.
     * @param amountToSettle The total amount of deposits that are settled.
     * @param totalAssets The total assets of the share series after settlement.
     * @param totalShares The total shares of the share series after settlement.
     */
    event SettleDeposit(
        uint48 indexed fromBatchId,
        uint48 indexed toBatchId,
        uint8 classId,
        uint8 seriesId,
        uint256 amountToSettle,
        uint256 totalAssets,
        uint256 totalShares
    );

    /**
     * @notice Emitted when a new series is created.
     * @param classId The ID of the share class for which the new series is created.
     * @param seriesId The ID of the new share series.
     * @param toBatchId The batch ID in which the new series is created.
     * @dev the new series is marked as created in the batch ID up to which the deposits are settled,
     * which may not be the current batch ID.
     */
    event NewSeriesCreated(uint8 classId, uint8 seriesId, uint48 toBatchId);

    /**
     * @notice Emitted when a series is consolidated.
     * @param classId The ID of the share class for which the series is consolidated.
     * @param seriesId The ID of the share series that is consolidated.
     * @param toBatchId The batch ID in which the series is consolidated.
     * @param amountToTransfer The total amount of the shares that are transferred.
     * @param sharesToTransfer The total shares that are transferred.
     * @dev the series is marked as consolidated in the batch ID up to which the deposits are settled,
     * which may not be the current batch ID.
     */
    event SeriesConsolidated(
        uint8 classId, uint8 seriesId, uint48 toBatchId, uint256 amountToTransfer, uint256 sharesToTransfer
    );

    /**
     * @notice Emitted when all series are consolidated.
     * @param classId The ID of the share class for which the series are consolidated.
     * @param fromSeriesId The ID of the first share series that is consolidated.
     * @param toSeriesId The ID of the last share series that is consolidated.
     * @param toBatchId The batch ID in which the series are consolidated.
     * @param totalAmountToTransfer The total amount of the shares that are transferred.
     * @param totalSharesToTransfer The total shares that are transferred.
     * @dev the series are marked as consolidated in the batch ID up to which the deposits are settled,
     * which may not be the current batch ID.
     */
    event AllSeriesConsolidated(
        uint8 classId,
        uint8 fromSeriesId,
        uint8 toSeriesId,
        uint48 toBatchId,
        uint256 totalAmountToTransfer,
        uint256 totalSharesToTransfer
    );

    /**
     * @notice Emitted when a user's shares are consolidated.
     * @param userConsolidationDetails The details of the user's shares consolidation.
     */
    event UserSharesConsolidated(UserConsolidationDetails userConsolidationDetails);

    /**
     * @notice Emitted when a deposit request is settled.
     * @param user The user that made the deposit request.
     * @param classId The ID of the share class for which the deposit request is settled.
     * @param seriesId The ID of the share series in which the deposit request is settled.
     * @param amount The amount of the deposit request.
     * @param sharesToMint The shares to mint for the deposit request.
     * @param toBatchId The batch ID up to which the deposit request is settled.
     */
    event DepositRequestSettled(
        address indexed user, uint8 classId, uint8 seriesId, uint256 amount, uint256 sharesToMint, uint48 toBatchId
    );

    /**
     * @notice Emitted when a deposit batch is settled.
     * @param batchId The batch ID that is settled.
     * @param classId The ID of the share class for which the deposit batch is settled.
     * @param seriesId The ID of the share series in which the deposit batch is settled.
     * @param totalAmountToDeposit The total amount of the deposits that are settled in the batch.
     * @param totalSharesToMint The total shares to mint for the deposit requests in the batch.
     */
    event SettleDepositBatch(
        uint48 indexed batchId, uint8 classId, uint8 seriesId, uint256 totalAmountToDeposit, uint256 totalSharesToMint
    );

    /**
     * @notice Emitted when a redeem request is settled.
     * @param fromBatchId The batch ID from which the redeem request is settled.
     * @param toBatchId The batch ID up to which the redeem request is settled.
     * @param classId The ID of the share class for which the redeem request is settled.
     */
    event SettleRedeem(uint48 indexed fromBatchId, uint48 indexed toBatchId, uint8 classId);

    /**
     * @notice Emitted when a redeem request is settled.
     * @param batchId The batch ID in which redeem request is settled.
     * @param user The user that made the redeem request.
     * @param classId The ID of the share class for which the redeem request is settled.
     * @param amountToRedeem The amount of the redeem request.
     */
    event RedeemRequestSettled(uint48 indexed batchId, address indexed user, uint8 classId, uint256 amountToRedeem);

    /**
     * @notice Emitted when a redeem request slice is settled.
     * @param batchId The batch ID in which redeem slice is settled.
     * @param user The user that made the redeem request.
     * @param classId The ID of the share class for which the redeem request is settled.
     * @param seriesId The ID of the share series in which the redeem request is settled.
     * @param amountToRedeem The amount of the redeem request.
     */
    event RedeemRequestSliceSettled(
        uint48 indexed batchId,
        address indexed user,
        uint8 classId,
        uint8 seriesId,
        uint256 amountToRedeem,
        uint256 sharesToBurn
    );

    /**
     * @notice Emitted when a redeem batch is settled.
     * @param batchId The batch ID that is settled.
     * @param classId The ID of the share class for which the redeem batch is settled.
     * @param totalAmountToRedeem The total amount of the redeem requests that are settled in the batch.
     */
    event SettleRedeemBatch(uint48 indexed batchId, uint8 indexed classId, uint256 totalAmountToRedeem);

    /**
     * @notice Emitted when a redeem is forced by the manager.
     * @param batchId The batch ID in which redeem is forced.
     * @param user The user that made the redeem request.
     */
    event ForceRedeem(uint48 indexed batchId, address indexed user);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Emitted when the new total assets are invalid.
     */
    error InvalidNewTotalAssets();

    /**
     * @notice Emitted when the to batch ID is invalid.
     */
    error InvalidToBatchId();

    /**
     * @notice Emitted when there are no deposits to settle.
     */
    error NoDepositsToSettle();

    /**
     * @notice Emitted when there are no redeems to settle.
     */
    error NoRedeemsToSettle();

    /**
     * @notice Emitted when the delegate call fails.
     * @param _data The data of the delegate call.
     */
    error DelegateCallFailed(bytes _data);

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Parameters for the settlement.
     * @param classId The ID of the share class.
     * @param toBatchId The batch ID up to which the settlement is done.
     * @param newTotalAssets The new total assets before settlement.
     * @param authSignature The auth signature for the settlement.
     */
    struct SettlementParams {
        uint8 classId;
        uint48 toBatchId;
        uint256[] newTotalAssets;
        AuthLibrary.AuthSignature authSignature;
    }

    /**
     * @notice Details for the settlement of a deposit.
     * @param createSeries Whether a new series is to be created.
     * @param classId The ID of the share class for which the settlement should be done.
     * @param seriesId The ID of the share series in which the settlement should be done.
     * @param batchId The batch ID for which the settlement is to be done.
     * @param toBatchId The batch ID in which settlement should be logged as done.
     * @param totalAssets The total assets before settlement of the batch.
     * @param totalShares The total shares before settlement of the batch.
     */
    struct SettleDepositDetails {
        bool createSeries;
        uint8 classId;
        uint8 seriesId;
        uint48 batchId;
        uint48 toBatchId;
        uint256 totalAssets;
        uint256 totalShares;
    }

    /**
     * @notice Parameters for the settlement of a redeem batch.
     * @param batchId The batch ID for which the settlement is to be done.
     * @param classId The ID of the share class for which the settlement should be done.
     * @param underlyingToken The underlying token of the share class.
     */
    struct SettleRedeemBatchParams {
        uint48 batchId;
        uint8 classId;
        address underlyingToken;
    }

    /**
     * @notice Details for the consolidation of a user's shares.
     * @param user The user that is to be consolidated.
     * @param classId The ID of the share class for which the consolidation should be done.
     * @param seriesId The ID of the share series which is to be consolidated.
     * @param toBatchId The batch ID in which consolidation should be logged as done.
     * @param shares The shares of the user which is to be consolidated.
     * @param amountToTransfer The amount of the user's shares to be transferred to the lead series.
     * @param sharesToTransfer The shares of the user's shares to be transferred to the lead series.
     */
    struct UserConsolidationDetails {
        address user;
        uint8 classId;
        uint8 seriesId;
        uint48 toBatchId;
        uint256 shares;
        uint256 amountToTransfer;
        uint256 sharesToTransfer;
    }

    /**
     * @notice Details for the settlement of a deposit request.
     * @param user The user that made the deposit request which is to be settled.
     * @param amount The amount of the deposit request which is to be settled.
     * @param sharesToMint The shares to mint for the deposit request which is to be settled.
     */
    struct DepositRequestParams {
        address user;
        uint256 amount;
        uint256 sharesToMint;
    }

    /*//////////////////////////////////////////////////////////////
                            SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/
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

    /**
     * @notice Forces a redeem for a user.
     * @param _user The user to force a redeem for.
     */
    function forceRedeem(address _user) external;
}
