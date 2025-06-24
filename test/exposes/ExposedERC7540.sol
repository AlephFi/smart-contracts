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

    function setCurrentDepositBatchId(uint40 _currentDepositBatchId) external {
        _getStorage().currentDepositBatchId = _currentDepositBatchId;
    }

    function setLastDepositBatchId(address _user, uint40 _lastDepositBatchId) external {
        _getStorage().lastDepositBatchId[_user] = _lastDepositBatchId;
    }

    function setBatchDepositRequest(uint40 _batchId, address _user, uint256 _amount) external {
        _getStorage().batchs[_batchId].depositRequest[_user] = _amount;
    }

    function setBatchRedeemRequest(uint40 _batchId, address _user, uint256 _amount) external {
        _getStorage().batchs[_batchId].redeemRequest[_user] = _amount;
    }

    function setLastDepositBatchIdSettled(uint40 _lastDepositBatchIdSettled) external {
        _getStorage().lastDepositBatchIdSettled = _lastDepositBatchIdSettled;
    }

    function setLastRedeemBatchIdSettled(uint40 _lastRedeemBatchIdSettled) external {
        _getStorage().lastRedeemBatchIdSettled = _lastRedeemBatchIdSettled;
    }

}