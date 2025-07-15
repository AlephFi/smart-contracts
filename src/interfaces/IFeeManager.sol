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
    event FeesAccumulated(uint256 managementFee, uint256 performanceFee, uint48 timestamp);
    event NewHighWaterMarkSet(uint256 highWaterMark);
    event FeesCollected(uint256 feesCollected);

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
     * @notice Collects all pending fees.
     */
    function collectFees() external;
}
