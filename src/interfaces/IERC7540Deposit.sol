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
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */

interface IERC7540Deposit {
    struct RequestDepositParams {
        uint8 classId;
        uint256 amount;
        AuthLibrary.AuthSignature authSignature;
    }

    event NewMinDepositAmountQueued(uint8 classId, uint256 minDepositAmount);
    event NewMaxDepositCapQueued(uint8 classId, uint256 maxDepositCap);
    event NewMinDepositAmountSet(uint8 classId, uint256 minDepositAmount);
    event NewMaxDepositCapSet(uint8 classId, uint256 maxDepositCap);
    event DepositRequest(address indexed user, uint8 classId, uint256 amount, uint48 batchId);

    error InsufficientDeposit();
    error DepositLessThanMinDepositAmount();
    error DepositExceedsMaxDepositCap();
    error OnlyOneRequestPerBatchAllowedForDeposit();
    error DepositRequestFailed();

    /**
     * @notice Queues a new minimum deposit amount.
     * @param _classId The ID of the share class to set the minimum deposit amount for.
     * @param _minDepositAmount The new minimum deposit amount.
     */
    function queueMinDepositAmount(uint8 _classId, uint256 _minDepositAmount) external;

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
     * @notice Sets the maximum deposit cap.
     * @param _classId The ID of the share class to set the maximum deposit cap for.
     */
    function setMaxDepositCap(uint8 _classId) external;

    /**
     * @notice Requests a deposit of assets into the vault for the current batch.
     * @param _requestDepositParams The parameters for the deposit request.
     * @return _batchId The batch ID for the deposit.
     */
    function requestDeposit(RequestDepositParams calldata _requestDepositParams) external returns (uint48 _batchId);
}
