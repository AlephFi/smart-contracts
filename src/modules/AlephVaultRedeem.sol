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

import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {IERC7540Redeem} from "@aleph-vault/interfaces/IERC7540Redeem.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {Checkpoints} from "@aleph-vault/libraries/Checkpoints.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {AlephVaultBase} from "@aleph-vault/AlephVaultBase.sol";
import {AlephVaultStorage, AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract AlephVaultRedeem is IERC7540Redeem, AlephVaultBase {
    using Checkpoints for Checkpoints.Trace256;

    constructor(uint48 _batchDuration) AlephVaultBase(_batchDuration) {}

    /// @inheritdoc IERC7540Redeem
    function requestRedeem(uint256 _shares) external returns (uint48 _batchId) {
        return _requestRedeem(_getStorage(), _shares);
    }

    /**
     * @dev Internal function to handle a redeem request.
     * @param _sharesToRedeem The number of shares to redeem.
     * @return _batchId The batch ID for the redeem request.
     */
    function _requestRedeem(AlephVaultStorageData storage _sd, uint256 _sharesToRedeem)
        internal
        returns (uint48 _batchId)
    {
        if (_sharesToRedeem == 0) {
            revert InsufficientRedeem();
        }
        uint48 _currentBatchId = _currentBatch();
        if (_currentBatchId == 0) {
            revert NoBatchAvailableForRedeem(); // need to wait for the first batch to be available
        }
        uint48 _lastRedeemBatchId = _sd.lastRedeemBatchId[msg.sender];
        if (_lastRedeemBatchId >= _currentBatchId) {
            revert OnlyOneRequestPerBatchAllowedForRedeem();
        }
        uint256 _shares = _sharesOf(msg.sender);
        if (_shares < _sharesToRedeem) {
            revert InsufficientSharesToRedeem();
        }
        _sd.lastRedeemBatchId[msg.sender] = _currentBatchId;
        IAlephVault.BatchData storage _batch = _sd.batches[_currentBatchId];
        _batch.redeemRequest[msg.sender] = _sharesToRedeem;
        _batch.totalSharesToRedeem += _sharesToRedeem;
        _batch.usersToRedeem.push(msg.sender);
        _sd.sharesOf[msg.sender].push(Time.timestamp(), _shares - _sharesToRedeem);
        // we will update the total shares and assets in the _settleRedeemForBatch function
        emit RedeemRequest(msg.sender, _sharesToRedeem, _currentBatchId);
        return _currentBatchId;
    }
}
