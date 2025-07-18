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
interface IERC7540Deposit {
    event DepositRequest(address indexed user, uint256 amount, uint48 batchId);
    event SettleDeposit(uint48 indexed fromBatchId, uint48 indexed toBatchId, uint256 amount, uint256 assets);
    event SettleDepositBatch(
        uint48 indexed batchId,
        uint256 totalAmountToDeposit,
        uint256 totalSharesToMint,
        uint256 totalAssets,
        uint256 totalShares
    );

    error InsufficientDeposit();
    error NoBatchAvailableForDeposit();
    error OnlyOneRequestPerBatchAllowedForDeposit();
    error DepositRequestFailed();

    error BatchAlreadySettledForDeposit();
    error NoDepositsToSettle();

    /**
     * @notice Requests a deposit of assets into the vault for the current batch.
     * @param _amount The amount of assets to deposit.
     * @return _batchId The batch ID for the deposit.
     */
    function requestDeposit(uint256 _amount) external returns (uint48 _batchId);

    /**
     * @notice Returns the pending deposit amount for the caller in a specific batch.
     * @param _batchId The batch ID to query.
     * @return _amount The pending deposit amount.
     */
    function pendingDepositRequest(uint48 _batchId) external view returns (uint256 _amount);

    /**
     * @notice Returns the total amount pending to be deposited across all batches.
     */
    function pendingTotalAmountToDeposit() external view returns (uint256 _totalAmountToDeposit);

    /**
     * @notice Returns the total shares that would be minted for all pending deposits.
     */
    function pendingTotalSharesToDeposit() external view returns (uint256 _totalSharesToDeposit);

    /**
     * @notice Settles all pending deposits up to the current batch.
     * @param _newTotalAssets The new total assets after settlement.
     */
    function settleDeposit(uint256 _newTotalAssets) external;
}
