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

import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */

interface IERC7540Deposit {
    struct RequestDepositParams {
        uint256 amount;
        AuthLibrary.AuthSignature authSignature;
    }

    event NewMinDepositAmountQueued(uint256 minDepositAmount);
    event NewMaxDepositCapQueued(uint256 maxDepositCap);
    event NewMinDepositAmountSet(uint256 minDepositAmount);
    event NewMaxDepositCapSet(uint256 maxDepositCap);
    event DepositRequest(address indexed user, uint256 amount, uint48 batchId);
    event SettleDeposit(
        uint48 indexed fromBatchId,
        uint48 indexed toBatchId,
        uint256 amountToSettle,
        uint256 totalAssets,
        uint256 totalShares,
        uint256 pricePerShare
    );
    event SettleDepositBatch(
        uint48 indexed batchId,
        uint256 totalAmountToDeposit,
        uint256 totalSharesToMint,
        uint256 totalAssets,
        uint256 totalShares,
        uint256 pricePerShare
    );

    error InsufficientDeposit();
    error DepositLessThanMinDepositAmount();
    error DepositExceedsMaxDepositCap();
    error NoBatchAvailableForDeposit();
    error OnlyOneRequestPerBatchAllowedForDeposit();
    error DepositRequestFailed();

    error BatchAlreadySettledForDeposit();
    error NoDepositsToSettle();

    /**
     * @notice Returns the minimum deposit amount.
     * @return The minimum deposit amount.
     */
    function minDepositAmount() external view returns (uint256);

    /**
     * @notice Returns the maximum deposit cap.
     * @return The maximum deposit cap.
     */
    function maxDepositCap() external view returns (uint256);

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
     * @notice Returns the total amount of unsettled deposit requests.
     * @return The total amount of unsettled deposit requests.
     * @dev Please note that this function will return the deposit amount for all batches including the current batch.
     * However, if these deposit requests are settled in this batch, the amount requested in this batch will NOT be settled.
     * It will be settled in the next settlement batch. So if you're using this function to check if the deposit request for settlement,
     * please be aware of this nuance.
     */
    function totalAmountToDeposit() external view returns (uint256);

    /**
     * @notice Returns the total amount of deposit requests at a specific batch ID.
     * @param _batchId The batch ID to query.
     * @return The total amount of deposit requests at the given batch ID.
     */
    function totalAmountToDepositAt(uint48 _batchId) external view returns (uint256);

    /**
     * @notice Returns the users that have requested to deposit at a specific batch ID.
     * @param _batchId The batch ID to query.
     * @return The users that have requested to deposit at the given batch ID.
     */
    function usersToDepositAt(uint48 _batchId) external view returns (address[] memory);

    /**
     * @notice Returns the deposit request of a user.
     * @param _user The user to query.
     * @return The deposit request of the user.
     */
    function depositRequestOf(address _user) external view returns (uint256);

    /**
     * @notice Returns the deposit request of a user at a specific batch ID.
     * @param _user The user to query.
     * @param _batchId The batch ID to query.
     * @return The deposit request of the user at the given batch ID.
     */
    function depositRequestOfAt(address _user, uint48 _batchId) external view returns (uint256);

    /**
     * @notice Queues a new minimum deposit amount.
     * @param _minDepositAmount The new minimum deposit amount.
     */
    function queueMinDepositAmount(uint256 _minDepositAmount) external;

    /**
     * @notice Queues a new maximum deposit cap.
     * @param _maxDepositCap The new maximum deposit cap.
     */
    function queueMaxDepositCap(uint256 _maxDepositCap) external;

    /**
     * @notice Sets the minimum deposit amount.
     */
    function setMinDepositAmount() external;

    /**
     * @notice Sets the maximum deposit cap.
     */
    function setMaxDepositCap() external;

    /**
     * @notice Requests a deposit of assets into the vault for the current batch.
     * @param _requestDepositParams The parameters for the deposit request.
     * @return _batchId The batch ID for the deposit.
     */
    function requestDeposit(RequestDepositParams calldata _requestDepositParams) external returns (uint48 _batchId);

    /**
     * @notice Settles all pending deposits up to the current batch.
     * @param _newTotalAssets The new total assets after settlement.
     */
    function settleDeposit(uint256 _newTotalAssets) external;
}
