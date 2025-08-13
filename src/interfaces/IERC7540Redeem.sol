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
    event RedeemRequest(address indexed user, uint256 shares, uint48 batchId);

    error InsufficientRedeem();
    error InsufficientSharesToRedeem();
    error BatchAlreadyRedeemed();
    error NoRedeemsToSettle();
    error OnlyOneRequestPerBatchAllowedForRedeem();
    error NoBatchAvailableForRedeem();

    /**
     * @notice Requests to redeem shares from the vault for the current batch.
     * @param _shares The number of shares to redeem.
     * @return _batchId The batch ID for the redeem request.
     */
    function requestRedeem(uint256 _shares) external returns (uint48 _batchId);
}
