// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.25;
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

import {ERC7540} from "../../src/ERC7540.sol";
import {IERC7540} from "../../src/interfaces/IERC7540.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract ExposedERC7540 is ERC7540 {
    function settleDeposit() external {
        _settleDeposit();
    }

    function setCurrentDepositBatchId(uint48 _currentDepositBatchId) external {
        _getStorage().depositSettleId = _currentDepositBatchId;
    }

    function setBatchDepositRequest(uint48 _batchId, address _user, uint256 _amount) external {
        _getStorage().batchs[_batchId].depositRequest[_user] = _amount;
    }
}
