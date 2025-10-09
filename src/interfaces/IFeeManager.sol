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
interface IFeeManager {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Emitted when a new management fee is queued.
     * @param classId The ID of the share class.
     * @param managementFee The new management fee.
     */
    event NewManagementFeeQueued(uint8 classId, uint32 managementFee);

    /**
     * @notice Emitted when a new performance fee is queued.
     * @param classId The ID of the share class.
     * @param performanceFee The new performance fee.
     */
    event NewPerformanceFeeQueued(uint8 classId, uint32 performanceFee);

    /**
     * @notice Emitted when a new management fee is set.
     * @param classId The ID of the share class.
     * @param managementFee The new management fee.
     */
    event NewManagementFeeSet(uint8 classId, uint32 managementFee);

    /**
     * @notice Emitted when a new performance fee is set.
     * @param classId The ID of the share class.
     * @param performanceFee The new performance fee.
     */
    event NewPerformanceFeeSet(uint8 classId, uint32 performanceFee);

    /**
     * @notice Emitted when fees are accumulated.
     * @param lastFeePaidId The batch ID in which fees were last accumulated.
     * @param toBatchId The batch ID up to which fees were accumulated.
     * @param classId The ID of the share class for which fees were accumulated.
     * @param seriesId The ID of the share series in which fees were accumulated.
     * @param newTotalAssets The new total assets upon which fees were accumulated.
     * @param newTotalShares The new total shares after fees were accumulated.
     * @param feesAccumulatedParams The parameters for the accumulated fees.
     */
    event FeesAccumulated(
        uint48 lastFeePaidId,
        uint48 toBatchId,
        uint8 classId,
        uint8 seriesId,
        uint256 newTotalAssets,
        uint256 newTotalShares,
        FeesAccumulatedParams feesAccumulatedParams
    );

    /**
     * @notice Emitted when a new high water mark is set.
     * @param classId The ID of the share class for which the high water mark was set.
     * @param seriesId The ID of the share series in which the high water mark was set.
     * @param highWaterMark The new high water mark set.
     * @param toBatchId The batch ID in which the high water mark was set.
     * @dev the high water mark is set in the batch ID up to which the fees were accumulated,
     * which may not be the current batch ID.
     */
    event NewHighWaterMarkSet(uint8 classId, uint8 seriesId, uint256 highWaterMark, uint48 toBatchId);

    /**
     * @notice Emitted when fees are collected.
     * @param classId The ID of the share class for which fees were collected.
     * @param seriesId The ID of the share series in which fees were collected.
     * @param managementFeesCollected The management fees collected for the series.
     * @param performanceFeesCollected The performance fees collected for the series.
     */
    event SeriesFeeCollected(
        uint8 classId, uint8 seriesId, uint256 managementFeesCollected, uint256 performanceFeesCollected
    );

    /**
     * @notice Emitted when fees are collected.
     * @param currentBatchId The batch ID in which fees were collected.
     * @param managementFeesCollected The total management fees collected.
     * @param performanceFeesCollected The total performance fees collected.
     */
    event FeesCollected(uint48 currentBatchId, uint256 managementFeesCollected, uint256 performanceFeesCollected);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Emitted when the management fee is invalid.
     */
    error InvalidManagementFee();

    /**
     * @notice Emitted when the performance fee is invalid.
     */
    error InvalidPerformanceFee();

    /**
     * @notice Emitted when the share class conversion is invalid.
     */
    error InvalidShareClassConversion();

    /**
     * @notice Emitted when there are insufficient assets to collect fees.
     * @param requiredVaultBalance The required vault balance.
     */
    error InsufficientAssetsToCollectFees(uint256 requiredVaultBalance);

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Constructor params.
     * @param managementFeeTimelock The timelock period for the management fee.
     * @param performanceFeeTimelock The timelock period for the performance fee.
     */
    struct FeeConstructorParams {
        uint48 managementFeeTimelock;
        uint48 performanceFeeTimelock;
    }

    /**
     * @notice Parameters for the accumulated fees.
     * @param managementFeeAmount The management fee amount to be accumulated.
     * @param managementFeeSharesToMint The management fee shares to be minted.
     * @param performanceFeeAmount The performance fee amount to be accumulated.
     * @param performanceFeeSharesToMint The performance fee shares to be minted.
     */
    struct FeesAccumulatedParams {
        uint256 managementFeeAmount;
        uint256 managementFeeSharesToMint;
        uint256 performanceFeeAmount;
        uint256 performanceFeeSharesToMint;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Gets the management fee shares.
     * @param _newTotalAssets The new total assets in the vault.
     * @param _totalShares The total shares in the vault.
     * @param _batchesElapsed The number of batches elapsed since the last fee was paid.
     * @param _managementFee The management fee rate.
     * @return _managementFeeShares The management fee shares.
     */
    function getManagementFeeShares(
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint48 _batchesElapsed,
        uint32 _managementFee
    ) external view returns (uint256 _managementFeeShares);

    /**
     * @notice Gets the performance fee shares.
     * @param _newTotalAssets The new total assets in the vault.
     * @param _totalShares The total shares in the vault.
     * @param _performanceFee The performance fee.
     * @param _highWaterMark The high water mark.
     * @return _performanceFeeShares The performance fee shares.
     * @dev the total shares used to calculate the performance fee shares is the total shares
     * plus the management fee shares to mint. Make sure to account for that in any calculation
     * for which this view function is used.
     */
    function getPerformanceFeeShares(
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint32 _performanceFee,
        uint256 _highWaterMark
    ) external pure returns (uint256 _performanceFeeShares);

    /*//////////////////////////////////////////////////////////////
                            TIMELOCK FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Queues a new management fee to be set after the timelock period.
     * @param _classId The ID of the share class to set the management fee for.
     * @param _managementFee The new management fee to be set.
     */
    function queueManagementFee(uint8 _classId, uint32 _managementFee) external;

    /**
     * @notice Queues a new performance fee to be set after the timelock period.
     * @param _classId The ID of the share class to set the performance fee for.
     * @param _performanceFee The new performance fee to be set.
     */
    function queuePerformanceFee(uint8 _classId, uint32 _performanceFee) external;

    /**
     * @notice Sets the management fee to the queued value after the timelock period.
     * @param _classId The ID of the share class to set the management fee for.
     */
    function setManagementFee(uint8 _classId) external;

    /**
     * @notice Sets the performance fee to the queued value after the timelock period.
     * @param _classId The ID of the share class to set the performance fee for.
     */
    function setPerformanceFee(uint8 _classId) external;

    /*//////////////////////////////////////////////////////////////
                            FEE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Accumulates fees for a given batch.
     * @param _newTotalAssets The new total assets in the vault.
     * @param _totalShares The total shares in the vault.
     * @param _currentBatchId The current batch ID.
     * @param _lastFeePaidId The last fee paid ID.
     * @param _classId The ID of the share class.
     * @param _seriesId The ID of the share series.
     * @return The accumulated fees.
     */
    function accumulateFees(
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint48 _currentBatchId,
        uint48 _lastFeePaidId,
        uint8 _classId,
        uint8 _seriesId
    ) external returns (uint256);

    /**
     * @notice Collects all pending fees.
     * @return _managementFeesToCollect The management fees to collect.
     * @return _performanceFeesToCollect The performance fees to collect.
     */
    function collectFees() external returns (uint256 _managementFeesToCollect, uint256 _performanceFeesToCollect);
}
