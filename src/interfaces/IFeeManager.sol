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

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
interface IFeeManager {
    struct FeesAccumulatedParams {
        uint256 managementFeeAmount;
        uint256 managementFeeSharesToMint;
        uint256 performanceFeeAmount;
        uint256 performanceFeeSharesToMint;
    }

    event NewManagementFeeQueued(uint8 classId, uint32 managementFee);
    event NewPerformanceFeeQueued(uint8 classId, uint32 performanceFee);
    event NewFeeRecipientQueued(address feeRecipient);
    event NewManagementFeeSet(uint8 classId, uint32 managementFee);
    event NewPerformanceFeeSet(uint8 classId, uint32 performanceFee);
    event NewFeeRecipientSet(address feeRecipient);
    event FeesAccumulated(
        uint48 lastFeePaidId,
        uint48 currentBatchId,
        uint8 classId,
        uint8 seriesId,
        uint256 newTotalAssets,
        uint256 newTotalShares,
        FeesAccumulatedParams feesAccumulatedParams
    );
    event NewHighWaterMarkSet(uint8 classId, uint8 seriesId, uint256 highWaterMark, uint48 currentBatchId);
    event FeesCollected(uint256 managementFeesCollected, uint256 performanceFeesCollected);

    error InvalidManagementFee();
    error InvalidPerformanceFee();
    error InvalidShareClassConversion();

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
     * @notice Queues a new fee recipient to be set after the timelock period.
     * @param _feeRecipient The new fee recipient to be set.
     */
    function queueFeeRecipient(address _feeRecipient) external;

    /**
     * @notice Sets the management fee to the queued value after the timelock period.
     */
    function setManagementFee() external;

    /**
     * @notice Sets the performance fee to the queued value after the timelock period.
     */
    function setPerformanceFee() external;

    /**
     * @notice Sets the fee recipient to the queued value after the timelock period.
     */
    function setFeeRecipient() external;

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
     * @notice Gets the management fee shares.
     * @param _newTotalAssets The new total assets in the vault.
     * @param _totalShares The total shares in the vault.
     * @param _batchesElapsed The number of batches elapsed since the last fee was paid.
     * @param _managementFeeRate The management fee rate.
     * @return _managementFeeShares The management fee shares.
     */
    function getManagementFeeShares(
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint48 _batchesElapsed,
        uint32 _managementFeeRate
    ) external view returns (uint256 _managementFeeShares);

    /**
     * @notice Gets the performance fee shares.
     * @param _newTotalAssets The new total assets in the vault.
     * @param _totalShares The total shares in the vault.
     * @return _performanceFeeShares The performance fee shares.
     */
    function getPerformanceFeeShares(
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint32 _performanceFeeRate,
        uint256 _highWaterMark
    ) external pure returns (uint256 _performanceFeeShares);

    /**
     * @notice Collects all pending fees.
     */
    function collectFees() external;
}
