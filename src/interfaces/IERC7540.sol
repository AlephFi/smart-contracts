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

import {IERC7540Deposit} from "./IERC7540Deposit.sol";
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */

interface IERC7540 is IERC7540Deposit {
    event SettleBatch(uint48 indexed batchId, uint256 totalAmount, uint256 totalShares);
    event SettleDeposit(uint48 indexed fromBatchId, uint48 indexed toBatchId, uint256 amount);

    error InvalidInitializationParams();

    struct InitializationParams {
        address manager;
        address operationsMultisig;
        address operator;
        address erc20;
        address custodian;
        uint48 batchDuration;
    }

    struct BatchData {
        uint48 batchId;
        uint256 totalAmount;
        bool isSettled;
        //bool isRedeemed;
        mapping(address => uint256) depositRequest;
        address[] users;
    }

    // View functions
    function totalStake() external view returns (uint256);

    function totalShares() external view returns (uint256);

    function stakeAt(uint48 _timestamp) external view returns (uint256);

    function sharesAt(uint48 _timestamp) external view returns (uint256);

    function sharesOf(address _user) external view returns (uint256);

    function sharesOfAt(address _user, uint48 _timestamp) external view returns (uint256);

    function currentBatch() external view returns (uint48);
}
