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
    event SettleBatch(uint40 indexed batchId, uint256 totalAmount, uint256 totalShares);
    event SettleDeposit(uint40 indexed fromBatchId, uint40 indexed toBatchId, uint256 amount);

    error InvalidInitializationParams();

    struct InitializationParams {
        address manager;
        address operationsMultisig;
        address operator;
        address erc20;
        address custodian;
    }

    struct BatchData {
        uint40 batchId;
        uint256 totalAmount;
        bool isSettled;
        bool isRedeemed;
        mapping(address => uint256) depositRequest;
        address[] users;
    }
    //mapping(address => uint256) redeemRequest;

    struct SettleData {
        uint256 totalSupply;
        uint256 totalAssets;
        uint256 pendingAssets;
        uint256 pendingShares;
    }
}
