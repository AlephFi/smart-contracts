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
    event SettleRedeem(uint48 indexed fromBatchId, uint48 indexed toBatchId, uint256 shares, uint256 assets);

    event SettleRedeemBatch(
        uint48 indexed batchId,
        uint256 totalAassetsToRedeem,
        uint256 totalSharesToRedeem,
        uint256 totalAssets,
        uint256 totalShares
    );

    event RedeemRequest(address indexed user, uint256 shares, uint48 batchId);

    error InsufficientRedeem();
    error InsufficientSharesToRedeem();
    error BatchAlreadyRedeemed();
    error NoRedeemsToSettle();
    error OnlyOneRequestPerBatchAllowedForRedeem();
    error NoBatchAvailableForRedeem();

    /**
     * @notice Returns the pending redeem shares for the caller in a specific batch.
     * @param _batchId The batch ID to query.
     * @return _shares The pending redeem shares.
     */
    function pendingRedeemRequest(uint48 _batchId) external view returns (uint256 _shares);

    /**
     * @notice Returns the total assets that would be redeemed for all pending shares.
     */
    function pendingTotalAssetsToRedeem() external view returns (uint256 _totalAssetsToRedeem);

    /**
     * @notice Returns the total shares pending to be redeemed across all batches.
     */
    function pendingTotalSharesToRedeem() external view returns (uint256 _totalSharesToRedeem);

    /**
     * @notice Returns the total shares to redeem at the current batch.
     * @return The total shares to redeem at the current batch.
     */
    function totalSharesToRedeem() external view returns (uint256);

    /**
     * @notice Returns the total shares to redeem at a specific batch ID.
     * @param _batchId The batch ID to query.
     * @return The total shares to redeem at the given batch ID.
     */
    function totalSharesToRedeemAt(uint48 _batchId) external view returns (uint256);

    /**
     * @notice Returns the users that have requested to redeem at a specific batch ID.
     * @param _batchId The batch ID to query.
     * @return The users that have requested to redeem at the given batch ID.
     */
    function usersToRedeemAt(uint48 _batchId) external view returns (address[] memory);

    /**
     * @notice Returns the redeem request of a user.
     * @param _user The user to query.
     * @return The redeem request of the user.
     */
    function redeemRequestOf(address _user) external view returns (uint256);

    /**
     * @notice Returns the redeem request of a user at a specific batch ID.
     * @param _user The user to query.
     * @param _batchId The batch ID to query.
     * @return The redeem request of the user at the given batch ID.
     */
    function redeemRequestOfAt(address _user, uint48 _batchId) external view returns (uint256);

    /**
     * @notice Requests to redeem shares from the vault for the current batch.
     * @param _shares The number of shares to redeem.
     * @return _batchId The batch ID for the redeem request.
     */
    function requestRedeem(uint256 _shares) external returns (uint48 _batchId);

    /**
     * @notice Settles all pending redeems up to the current batch.
     * @param _newTotalAssets The new total assets after settlement.
     */
    function settleRedeem(uint256 _newTotalAssets) external;
}
