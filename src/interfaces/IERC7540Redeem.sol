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
interface IERC7540Redeem {
    event RedeemRequest(address indexed user, uint8 classId, uint8 seriesId, uint256 shares, uint48 batchId);

    error InsufficientRedeem();
    error InsufficientAssetsToRedeem();
    error OnlyOneRequestPerBatchAllowedForRedeem();
    error NoBatchAvailableForRedeem();

    /**
     * @notice Requests to redeem shares from the vault for the current batch.
     * @param _classId The ID of the share class to redeem shares from.
     * @param _seriesId The ID of the share series to redeem shares from.
     * @param _shares The number of shares to redeem.
     * @return _batchId The batch ID for the redeem request.
     */
    function requestRedeem(uint8 _classId, uint8 _seriesId, uint256 _shares) external returns (uint48 _batchId);
}
