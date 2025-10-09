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

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
interface IAlephVaultRedeem {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Emitted when a new notice period is queued.
     * @param classId The ID of the share class.
     * @param noticePeriod The new notice period in batches.
     */
    event NewNoticePeriodQueued(uint8 classId, uint48 noticePeriod);

    /**
     * @notice Emitted when a new lock in period is queued.
     * @param classId The ID of the share class.
     * @param lockInPeriod The new lock in period in batches.
     */
    event NewLockInPeriodQueued(uint8 classId, uint48 lockInPeriod);

    /**
     * @notice Emitted when a new minimum redeem amount is queued.
     * @param classId The ID of the share class.
     * @param minRedeemAmount The new minimum redeem amount.
     */
    event NewMinRedeemAmountQueued(uint8 classId, uint256 minRedeemAmount);

    /**
     * @notice Emitted when a new notice period is set.
     * @param classId The ID of the share class.
     * @param noticePeriod The new notice period in batches.
     */
    event NewNoticePeriodSet(uint8 classId, uint48 noticePeriod);

    /**
     * @notice Emitted when a new lock in period is set.
     * @param classId The ID of the share class.
     * @param lockInPeriod The new lock in period in batches.
     */
    event NewLockInPeriodSet(uint8 classId, uint48 lockInPeriod);

    /**
     * @notice Emitted when a new minimum redeem amount is set.
     * @param classId The ID of the share class.
     * @param minRedeemAmount The new minimum redeem amount.
     */
    event NewMinRedeemAmountSet(uint8 classId, uint256 minRedeemAmount);

    /**
     * @notice Emitted when a redeem request is made.
     * @param classId The ID of the share class.
     * @param batchId The batch ID of the redeem request.
     * @param user The user making the redeem request.
     * @param estAmountToRedeem The estimated amount to redeem.
     */
    event RedeemRequest(uint8 classId, uint48 batchId, address indexed user, uint256 estAmountToRedeem);

    /**
     * @notice Emitted when the redeemable amount is withdrawn.
     * @param user The user withdrawing the redeemable amount.
     * @param redeemableAmount The redeemable amount.
     */
    event RedeemableAmountWithdrawn(address indexed user, uint256 redeemableAmount);

    /**
     * @notice Emitted when the excess assets are withdrawn.
     * @param excessAssets The excess assets.
     */
    event ExcessAssetsWithdrawn(uint256 excessAssets);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Emitted when the minimum redeem amount is invalid.
     */
    error InvalidMinRedeemAmount();

    /**
     * @notice Emitted when the redeem is less than the minimum redeem amount.
     * @param minRedeemAmount The minimum redeem amount.
     */
    error RedeemLessThanMinRedeemAmount(uint256 minRedeemAmount);

    /**
     * @notice Emitted when the user is in the lock in period.
     * @param userLockInPeriod The user lock in period.
     */
    error UserInLockInPeriodNotElapsed(uint48 userLockInPeriod);

    /**
     * @notice Emitted when the assets to redeem are insufficient.
     */
    error InsufficientAssetsToRedeem();

    /**
     * @notice Emitted when the redeem falls below the minimum user balance.
     * @param minUserBalance The minimum user balance.
     */
    error RedeemFallBelowMinUserBalance(uint256 minUserBalance);

    /**
     * @notice Emitted when only one request per batch is allowed for redeem.
     */
    error OnlyOneRequestPerBatchAllowedForRedeem();

    /**
     * @notice Emitted when the vault balance is insufficient.
     */
    error InsufficientVaultBalance();

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Constructor params.
     * @param noticePeriodTimelock The timelock period for the notice period.
     * @param lockInPeriodTimelock The timelock period for the lock in period.
     * @param minRedeemAmountTimelock The timelock period for the minimum redeem amount.
     */
    struct RedeemConstructorParams {
        uint48 noticePeriodTimelock;
        uint48 lockInPeriodTimelock;
        uint48 minRedeemAmountTimelock;
    }

    /**
     * @notice Parameters for a redeem request.
     * @param classId The ID of the share class.
     * @param estAmountToRedeem The estimated amount to redeem.
     * @dev pleas note that the amount mentioned here is used to calculate the share units based on the
     * PPS at the moment of request. The actual amount the users can withdraw after settlement may be
     * different from the amount specified here due to change in PPS based on the pnl of the vault and fees.
     */
    struct RedeemRequestParams {
        uint8 classId;
        uint256 estAmountToRedeem;
    }

    /*//////////////////////////////////////////////////////////////
                            TIMELOCK FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Queues a new notice period.
     * @param _classId The ID of the share class to set the notice period for.
     * @param _noticePeriod The new notice period in batches.
     */
    function queueNoticePeriod(uint8 _classId, uint48 _noticePeriod) external;

    /**
     * @notice Queues a new lock in period.
     * @param _classId The ID of the share class to set the lock in period for.
     * @param _lockInPeriod The new lock in period in batches.
     */
    function queueLockInPeriod(uint8 _classId, uint48 _lockInPeriod) external;

    /**
     * @notice Queues a new minimum redeem amount.
     * @param _classId The ID of the share class to set the minimum redeem amount for.
     * @param _minRedeemAmount The new minimum redeem amount.
     */
    function queueMinRedeemAmount(uint8 _classId, uint256 _minRedeemAmount) external;

    /**
     * @notice Sets the notice period in batches
     * @param _classId The ID of the share class to set the notice period for.
     */
    function setNoticePeriod(uint8 _classId) external;

    /**
     * @notice Sets the lock in period in batches
     * @param _classId The ID of the share class to set the lock in period for.
     */
    function setLockInPeriod(uint8 _classId) external;

    /**
     * @notice Sets the minimum redeem amount.
     * @param _classId The ID of the share class to set the minimum redeem amount for.
     */
    function setMinRedeemAmount(uint8 _classId) external;

    /*//////////////////////////////////////////////////////////////
                            REDEEM FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Requests to redeem shares from the vault for the current batch.
     * @param _redeemRequestParams The parameters for the redeem request.
     * @return _batchId The batch ID for the redeem request.
     */
    function requestRedeem(RedeemRequestParams calldata _redeemRequestParams) external returns (uint48 _batchId);

    /**
     * @notice Withdraws the redeemable amount for the user.
     */
    function withdrawRedeemableAmount() external;

    /**
     * @notice Withdraws excess assets from the vault and sends back to custodian.
     */
    function withdrawExcessAssets() external;
}
