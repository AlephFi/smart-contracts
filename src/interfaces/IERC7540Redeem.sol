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
    event NewNoticePeriodSet(uint8 classId, uint48 noticePeriod);
    event RedeemRequest(address indexed user, uint8 classId, uint256 amount, uint48 batchId);

    error InsufficientRedeem();
    error InsufficientAssetsToRedeem();
    error OnlyOneRequestPerBatchAllowedForRedeem();

    /**
     * @notice Queues a new notice period.
     * @param _classId The ID of the share class to set the notice period for.
     * @param _noticePeriod The new notice period.
     */
    function queueNoticePeriod(uint8 _classId, uint48 _noticePeriod) external;

    /**
     * @notice Sets the notice period.
     */
    function setNoticePeriod() external;

    /**
     * @notice Requests to redeem shares from the vault for the current batch.
     * @param _classId The ID of the share class to redeem shares from.
     * @param _estAmount The estimated amount to redeem.
     * @return _batchId The batch ID for the redeem request.
     */
    function requestRedeem(uint8 _classId, uint256 _estAmount) external returns (uint48 _batchId);
}
