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

import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {IAlephVault} from "../../src/interfaces/IAlephVault.sol";
import {Checkpoints} from "../../src/libraries/Checkpoints.sol";
import {AlephVaultStorageData} from "../../src/AlephVaultStorage.sol";
import {AlephVault} from "../../src/AlephVault.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract ExposedVault is AlephVault {
    using Checkpoints for Checkpoints.Trace256;

    constructor(IAlephVault.ConstructorParams memory _initalizationParams) AlephVault(_initalizationParams) {}

    function depositSettleId() external view returns (uint48) {
        return _getStorage().depositSettleId;
    }

    function lastFeePaidId() external view returns (uint48) {
        return _getStorage().lastFeePaidId;
    }

    function setLastDepositBatchId(address _user, uint48 _lastDepositBatchId) external {
        _getStorage().lastDepositBatchId[_user] = _lastDepositBatchId;
    }

    function setLastRedeemBatchId(address _user, uint48 _lastRedeemBatchId) external {
        _getStorage().lastRedeemBatchId[_user] = _lastRedeemBatchId;
    }

    function setCurrentDepositBatchId(uint48 _currentDepositBatchId) external {
        _getStorage().depositSettleId = _currentDepositBatchId;
    }

    function setBatchDepositRequest(uint48 _batchId, address _user, uint256 _amount) external {
        _getStorage().batches[_batchId].depositRequest[_user] = _amount;
    }

    function setBatchDeposit(uint48 _batchId, address _user, uint256 _amount) external {
        AlephVaultStorageData storage _sd = _getStorage();
        _sd.batches[_batchId].usersToDeposit.push(_user);
        _sd.batches[_batchId].depositRequest[_user] = _amount;
        _sd.batches[_batchId].totalAmountToDeposit += _amount;
    }

    function setSharesOf(address _user, uint256 _shares) external {
        _getStorage().sharesOf[_user].push(Time.timestamp(), _shares);
    }
}
