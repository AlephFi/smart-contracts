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
    event RedeemRequest(address indexed user, uint8 classId, uint256 amount, uint48 batchId);

    error InsufficientRedeem();
    error InsufficientAssetsToRedeem();
    error OnlyOneRequestPerBatchAllowedForRedeem();

    /**
     * @notice Requests to redeem shares from the vault for the current batch.
     * @param _classId The ID of the share class to redeem shares from.
     * @param _amount The amount to redeem.
     * @return _batchId The batch ID for the redeem request.
     */
    function requestRedeem(uint8 _classId, uint256 _amount) external returns (uint48 _batchId);
}
