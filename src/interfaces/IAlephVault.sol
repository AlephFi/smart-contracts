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
import {IERC7540Redeem} from "./IERC7540Redeem.sol";
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */

interface IAlephVault is IERC7540Deposit, IERC7540Redeem {
    error InvalidInitializationParams();

    struct InitializationParams {
        address admin;
        address operationsMultisig;
        address oracle;
        address erc20;
        address custodian;
        uint48 batchDuration;
    }

    struct BatchData {
        uint48 batchId;
        uint256 totalAmountToDeposit;
        uint256 totalSharesToRedeem;
        address[] usersToDeposit;
        address[] usersToRedeem;
        mapping(address => uint256) depositRequest;
        mapping(address => uint256) redeemRequest;
    }

    // View functions
    function totalAssets() external view returns (uint256);

    function totalShares() external view returns (uint256);

    function assetsAt(uint48 _timestamp) external view returns (uint256);

    function assetsOf(address _user) external view returns (uint256);

    function assetsOfAt(address _user, uint48 _timestamp) external view returns (uint256);

    function sharesAt(uint48 _timestamp) external view returns (uint256);

    function sharesOf(address _user) external view returns (uint256);

    function sharesOfAt(address _user, uint48 _timestamp) external view returns (uint256);

    function currentBatch() external view returns (uint48);

    function pendingTotalAmountToDeposit() external view returns (uint256);

    function pendingTotalSharesToDeposit() external view returns (uint256);

    function pendingTotalAssetsToRedeem() external view returns (uint256);

    function pendingTotalSharesToRedeem() external view returns (uint256);
}
