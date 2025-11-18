// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;
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
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */

interface IAlephVaultDeposit {
    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Emitted when a new minimum deposit amount is queued.
     * @param classId The ID of the share class.
     * @param minDepositAmount The new minimum deposit amount.
     */
    event NewMinDepositAmountQueued(uint8 classId, uint256 minDepositAmount);

    /**
     * @notice Emitted when a new minimum user balance is queued.
     * @param classId The ID of the share class.
     * @param minUserBalance The new minimum user balance.
     */
    event NewMinUserBalanceQueued(uint8 classId, uint256 minUserBalance);

    /**
     * @notice Emitted when a new maximum deposit cap is queued.
     * @param classId The ID of the share class.
     * @param maxDepositCap The new maximum deposit cap.
     */
    event NewMaxDepositCapQueued(uint8 classId, uint256 maxDepositCap);

    /**
     * @notice Emitted when a new minimum deposit amount is set.
     * @param classId The ID of the share class.
     * @param minDepositAmount The new minimum deposit amount.
     */
    event NewMinDepositAmountSet(uint8 classId, uint256 minDepositAmount);

    /**
     * @notice Emitted when a new minimum user balance is set.
     * @param classId The ID of the share class.
     * @param minUserBalance The new minimum user balance.
     */
    event NewMinUserBalanceSet(uint8 classId, uint256 minUserBalance);

    /**
     * @notice Emitted when a new maximum deposit cap is set.
     * @param classId The ID of the share class.
     * @param maxDepositCap The new maximum deposit cap.
     */
    event NewMaxDepositCapSet(uint8 classId, uint256 maxDepositCap);

    /**
     * @notice Emitted when a deposit request is made.
     * @param classId The ID of the share class.
     * @param batchId The batch ID of the deposit request.
     * @param user The user making the deposit request.
     * @param amount The amount of the deposit request.
     */
    event DepositRequest(uint8 classId, uint48 batchId, address indexed user, uint256 amount);

    /**
     * @notice Emitted when a synchronous deposit is made.
     * @param classId The ID of the share class.
     * @param depositor The address making the deposit.
     * @param amount The amount deposited.
     * @param shares The number of shares minted.
     */
    event SyncDeposit(uint8 indexed classId, address indexed depositor, uint256 amount, uint256 shares);

    /*//////////////////////////////////////////////////////////////
                                ERRORS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Emitted when the minimum deposit amount is invalid.
     */
    error InvalidMinDepositAmount();

    /**
     * @notice Emitted when the deposit is insufficient.
     */
    error InsufficientDeposit();

    /**
     * @notice Emitted when the deposit is less than the minimum deposit amount.
     */
    error DepositLessThanMinDepositAmount(uint256 minDepositAmount);

    /**
     * @notice Emitted when the deposit is less than the minimum user balance.
     */
    error DepositLessThanMinUserBalance(uint256 minUserBalance);

    /**
     * @notice Emitted when the deposit exceeds the maximum deposit cap.
     */
    error DepositExceedsMaxDepositCap(uint256 maxDepositCap);

    /**
     * @notice Emitted when only one request per batch is allowed for deposit.
     */
    error OnlyOneRequestPerBatchAllowedForDeposit();

    /**
     * @notice Emitted when the deposit request fails.
     */
    error DepositRequestFailed();

    /**
     * @notice Emitted when only async deposit is allowed (sync is not valid).
     */
    error OnlyAsyncDepositAllowed();

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Constructor params.
     * @param minDepositAmountTimelock The timelock period for the minimum deposit amount.
     * @param minUserBalanceTimelock The timelock period for the minimum user balance.
     * @param maxDepositCapTimelock The timelock period for the maximum deposit cap.
     */
    struct DepositConstructorParams {
        uint48 minDepositAmountTimelock;
        uint48 minUserBalanceTimelock;
        uint48 maxDepositCapTimelock;
    }

    /**
     * @notice Parameters for a deposit request.
     * @param classId The ID of the share class.
     * @param amount The amount of the deposit request.
     * @param _authSignature The auth signature for the deposit request.
     */
    struct RequestDepositParams {
        uint8 classId;
        uint256 amount;
        AuthLibrary.AuthSignature authSignature;
    }

    /*//////////////////////////////////////////////////////////////
                            TIMELOCK FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Queues a new minimum deposit amount.
     * @param _classId The ID of the share class to set the minimum deposit amount for.
     * @param _minDepositAmount The new minimum deposit amount.
     */
    function queueMinDepositAmount(uint8 _classId, uint256 _minDepositAmount) external;

    /**
     * @notice Queues a new minimum user balance.
     * @param _classId The ID of the share class to set the minimum user balance for.
     * @param _minUserBalance The new minimum user balance.
     */
    function queueMinUserBalance(uint8 _classId, uint256 _minUserBalance) external;

    /**
     * @notice Queues a new maximum deposit cap.
     * @param _classId The ID of the share class to set the maximum deposit cap for.
     * @param _maxDepositCap The new maximum deposit cap.
     */
    function queueMaxDepositCap(uint8 _classId, uint256 _maxDepositCap) external;

    /**
     * @notice Sets the minimum deposit amount.
     * @param _classId The ID of the share class to set the minimum deposit amount for.
     */
    function setMinDepositAmount(uint8 _classId) external;

    /**
     * @notice Sets the minimum user balance.
     * @param _classId The ID of the share class to set the minimum user balance for.
     */
    function setMinUserBalance(uint8 _classId) external;

    /**
     * @notice Sets the maximum deposit cap.
     * @param _classId The ID of the share class to set the maximum deposit cap for.
     */
    function setMaxDepositCap(uint8 _classId) external;

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Requests a deposit of assets into the vault for the current batch.
     * @param _requestDepositParams The parameters for the deposit request.
     * @return _batchId The batch ID for the deposit.
     */
    function requestDeposit(RequestDepositParams calldata _requestDepositParams) external returns (uint48 _batchId);

    /**
     * @notice Deposits assets synchronously into the vault, minting shares immediately.
     * @param _requestDepositParams The parameters for the deposit (same as requestDeposit).
     * @return _shares The number of shares minted to the caller.
     * @dev Only callable when totalAssets is valid for the specified class.
     */
    function syncDeposit(RequestDepositParams calldata _requestDepositParams) external returns (uint256 _shares);

}
