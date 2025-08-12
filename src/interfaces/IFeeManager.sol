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
    event NewManagementFeeQueued(uint32 managementFee);
    event NewPerformanceFeeQueued(uint32 performanceFee);
    event NewFeeRecipientQueued(address feeRecipient);
    event NewManagementFeeSet(uint32 managementFee);
    event NewPerformanceFeeSet(uint32 performanceFee);
    event NewFeeRecipientSet(address feeRecipient);
    event FeesAccumulated(uint48 lastFeePaidId, uint48 currentBatchId, uint256 managementFee, uint256 performanceFee);
    event NewHighWaterMarkSet(uint256 highWaterMark);
    event FeesCollected(uint256 managementFeesCollected, uint256 performanceFeesCollected);

    error InvalidConstructorParams();
    error InvalidManagementFee();
    error InvalidPerformanceFee();

    /**
     * @notice Queues a new management fee to be set after the timelock period.
     * @param _managementFee The new management fee to be set.
     */
    function queueManagementFee(uint32 _managementFee) external;

    /**
     * @notice Queues a new performance fee to be set after the timelock period.
     * @param _performanceFee The new performance fee to be set.
     */
    function queuePerformanceFee(uint32 _performanceFee) external;

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
     * @param _currentBatchId The current batch ID.
     * @param _lastFeePaidId The last fee paid ID.
     * @param _timestamp The timestamp of the current batch.
     * @return The accumulated fees.
     */
    function accumulateFees(uint256 _newTotalAssets, uint48 _currentBatchId, uint48 _lastFeePaidId, uint48 _timestamp)
        external
        returns (uint256);

    /**
     * @notice Initializes the high water mark.
     * @param _totalAssets The total assets in the vault.
     * @param _totalShares The total shares in the vault.
     * @param _timestamp The timestamp of the current batch.
     */
    function initializeHighWaterMark(uint256 _totalAssets, uint256 _totalShares, uint48 _timestamp) external;

    /**
     * @notice Gets the management fee shares.
     * @param _newTotalAssets The new total assets in the vault.
     * @param _totalShares The total shares in the vault.
     * @param _batchesElapsed The number of batches elapsed since the last fee was paid.
     * @return _managementFeeShares The management fee shares.
     */
    function getManagementFeeShares(uint256 _newTotalAssets, uint256 _totalShares, uint48 _batchesElapsed)
        external
        view
        returns (uint256 _managementFeeShares);

    /**
     * @notice Gets the performance fee shares.
     * @param _newTotalAssets The new total assets in the vault.
     * @param _totalShares The total shares in the vault.
     * @return _performanceFeeShares The performance fee shares.
     */
    function getPerformanceFeeShares(uint256 _newTotalAssets, uint256 _totalShares)
        external
        view
        returns (uint256 _performanceFeeShares);

    /**
     * @notice Collects all pending fees.
     */
    function collectFees() external;
}
