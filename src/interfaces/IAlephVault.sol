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
interface IAlephVault {
    error InvalidInitializationParams();

    struct InitializationParams {
        string name;
        address admin;
        address operationsMultisig;
        address oracle;
        address guardian;
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

    function currentBatch() external view returns (uint48);

    function totalAssets() external view returns (uint256);

    function totalShares() external view returns (uint256);

    function assetsAt(uint48 _timestamp) external view returns (uint256);

    function assetsOf(address _user) external view returns (uint256);

    function assetsOfAt(address _user, uint48 _timestamp) external view returns (uint256);

    function sharesAt(uint48 _timestamp) external view returns (uint256);

    function sharesOf(address _user) external view returns (uint256);

    function sharesOfAt(address _user, uint48 _timestamp) external view returns (uint256);
}
