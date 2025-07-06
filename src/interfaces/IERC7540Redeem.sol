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
    error InsufficientSharesToRedeem();
    error BatchAlreadyRedeemed();
    error NoRedeemsToSettle();
    error OnlyOneRequestPerBatchAllowedForRedeem();
    error NoBatchAvailableForRedeem();

    event SettleRedeem(uint48 indexed fromBatchId, uint48 indexed toBatchId, uint256 shares, uint256 assets);

    event SettleRedeemBatch(
        uint48 indexed batchId,
        uint256 totalAassetsToRedeem,
        uint256 totalSharesToRedeem,
        uint256 totalAssets,
        uint256 totalShares
    );

    event RedeemRequest(address indexed user, uint256 shares, uint48 batchId);

    function requestRedeem(uint256 _shares) external returns (uint48 _batchId);

    function pendingRedeemRequest(uint48 _batchId) external view returns (uint256 _shares);

    function pendingTotalAssetsToRedeem() external view returns (uint256 _totalAssetsToRedeem);

    function pendingTotalSharesToRedeem() external view returns (uint256 _totalSharesToRedeem);

    function settleRedeem(uint256 _newTotalAssets) external;
}
