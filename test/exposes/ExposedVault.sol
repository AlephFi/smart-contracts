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

import {AlephVault} from "../../src/AlephVault.sol";
import {IAlephVault} from "../../src/interfaces/IAlephVault.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract ExposedVault is AlephVault {
    constructor(IAlephVault.ConstructorParams memory _initalizationParams) AlephVault(_initalizationParams) {}

    function setLastDepositBatchId(address _user, uint48 _lastDepositBatchId) external {
        _getStorage().lastDepositBatchId[_user] = _lastDepositBatchId;
    }

    function setCurrentDepositBatchId(uint48 _currentDepositBatchId) external {
        _getStorage().depositSettleId = _currentDepositBatchId;
    }

    function setBatchDepositRequest(uint48 _batchId, address _user, uint256 _amount) external {
        _getStorage().batches[_batchId].depositRequest[_user] = _amount;
    }
}
