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
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
interface IERC7540Redeem {
    event NewNoticePeriodQueued(uint8 classId, uint48 noticePeriod);
    event NewMinRedeemAmountQueued(uint8 classId, uint256 minRedeemAmount);
    event NewNoticePeriodSet(uint8 classId, uint48 noticePeriod);
    event NewMinRedeemAmountSet(uint8 classId, uint256 minRedeemAmount);
    event RedeemRequest(address indexed user, uint8 classId, uint256 amount, uint48 batchId);

    error InsufficientRedeem();
    error RedeemLessThanMinRedeemAmount(uint256 minRedeemAmount);
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
     * @notice Sets the minimum redeem amount.
     * @param _classId The ID of the share class to set the minimum redeem amount for.
     */
    function setMinRedeemAmount(uint8 _classId) external;

    /**
     * @notice Requests to redeem shares from the vault for the current batch.
     * @param _classId The ID of the share class to redeem shares from.
     * @param _estAmount The estimated amount to redeem.
     * @return _batchId The batch ID for the redeem request.
     */
    function requestRedeem(uint8 _classId, uint256 _estAmount) external returns (uint48 _batchId);
}
