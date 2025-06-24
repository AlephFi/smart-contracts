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

    error OnlyOneRequestPerBatchAllowed();

    event DepositRequest(address indexed user, uint256 amount, uint40 batchId);
    // Transfers amount from msg.sender into the Vault and submits a Request for asynchronous deposit.
    // This places the Request in Pending state, with a corresponding increase in pendingDepositRequest for the amount assets.
    function requestDeposit(uint256 _amount) external returns (uint40 _batchId);

    function pendingDepositRequest(uint40 _batchId) external view returns (uint256 _amount);
}