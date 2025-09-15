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
    struct RedeemConstructorParams {
        uint48 noticePeriodTimelock;
        uint48 lockInPeriodTimelock;
        uint48 minRedeemAmountTimelock;
    }

    struct RedeemRequestParams {
        uint8 classId;
        ShareRedeemRequest[] shareRequests;
    }

    struct ShareRedeemRequest {
        uint8 seriesId;
        uint256 shares;
    }

    event NewNoticePeriodQueued(uint8 classId, uint48 noticePeriod);
    event NewLockInPeriodQueued(uint8 classId, uint48 lockInPeriod);
    event NewMinRedeemAmountQueued(uint8 classId, uint256 minRedeemAmount);
    event NewNoticePeriodSet(uint8 classId, uint48 noticePeriod);
    event NewLockInPeriodSet(uint8 classId, uint48 lockInPeriod);
    event NewMinRedeemAmountSet(uint8 classId, uint256 minRedeemAmount);
    event RedeemRequest(address indexed user, uint48 batchId, RedeemRequestParams redeemRequestParams);

    error InvalidMinRedeemAmount();
    error InvalidSeriesId(uint8 seriesId);
    error InsufficientRedeem();
    error RedeemLessThanMinRedeemAmount(uint256 minRedeemAmount);
    error UserInLockInPeriodNotElapsed(uint48 userLockInPeriod);
    error InsufficientAssetsToRedeem();
    error RedeemFallBelowMinUserBalance(uint256 minUserBalance);
    error OnlyOneRequestPerBatchAllowedForRedeem();

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

    /**
     * @notice Requests to redeem shares from the vault for the current batch.
     * @param _redeemRequestParams The parameters for the redeem request.
     * @return _batchId The batch ID for the redeem request.
     */
    function requestRedeem(RedeemRequestParams calldata _redeemRequestParams) external returns (uint48 _batchId);
}
