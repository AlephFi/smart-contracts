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

    error OnlyOneRequestPerBatchAllowedForDeposit();
    error InsufficientDeposit();
    error BatchAlreadySettledForDeposit();
    error NoBatchAvailableForDeposit();
    error NoDepositsToSettle();

    // Transfers amount from msg.sender into the Vault and submits a request for asynchronous deposit.
    // This places the request in pending state, with a corresponding increase in pendingDepositRequest for the amount assets.
    function requestDeposit(uint256 _amount) external returns (uint48 _batchId);

    function pendingDepositRequest(uint48 _batchId) external view returns (uint256 _amount);

    function pendingTotalAmountToDeposit() external view returns (uint256 _totalAmountToDeposit);

    function pendingTotalSharesToDeposit() external view returns (uint256 _totalSharesToDeposit);

    function settleDeposit(uint256 _newTotalAssets) external;
}
