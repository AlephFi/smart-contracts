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

import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {IERC7540Redeem} from "@aleph-vault/interfaces/IERC7540Redeem.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {AlephVaultBase} from "@aleph-vault/AlephVaultBase.sol";
import {AlephVaultStorage, AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract AlephVaultRedeem is IERC7540Redeem, AlephVaultBase {
    using Math for uint256;

    constructor(uint48 _batchDuration) AlephVaultBase(_batchDuration) {}

    /// @inheritdoc IERC7540Redeem
    function requestRedeem(uint8 _classId, uint256 _amount) external returns (uint48 _batchId) {
        return _requestRedeem(_getStorage(), _classId, _amount);
    }

    /**
     * @dev Internal function to handle a redeem request.
     * @param _sd The storage struct.
     * @param _classId The class ID to redeem from.
     * @param _amount The amount to redeem.
     * @return _batchId The batch ID for the redeem request.
     */
    function _requestRedeem(AlephVaultStorageData storage _sd, uint8 _classId, uint256 _amount)
        internal
        returns (uint48 _batchId)
    {
        if (_amount == 0) {
            revert InsufficientRedeem();
        }
        uint48 _currentBatchId = _currentBatch(_sd);
        if (_currentBatchId == 0) {
            revert NoBatchAvailableForRedeem(); // need to wait for the first batch to be available
        }
        uint48 _lastRedeemBatchId = _sd.shareClasses[_classId].lastRedeemBatchId[msg.sender];
        if (_lastRedeemBatchId >= _currentBatchId) {
            revert OnlyOneRequestPerBatchAllowedForRedeem();
        }
        uint256 _totalUserAssets = _assetsPerClassOf(_sd, _classId, msg.sender);
        uint256 _pendingAssets = _pendingAssetsOf(_sd, _classId, _currentBatchId, msg.sender, _totalUserAssets);
        if (_pendingAssets + _amount > _totalUserAssets) {
            revert InsufficientAssetsToRedeem();
        }
        uint256 _amountSharesToRedeem =
            _amount.mulDiv(PRICE_DENOMINATOR, _totalUserAssets - _pendingAssets, Math.Rounding.Ceil);
        _sd.shareClasses[_classId].lastRedeemBatchId[msg.sender] = _currentBatchId;
        IAlephVault.RedeemRequests storage _redeemRequests = _sd.shareClasses[_classId].redeemRequests[_currentBatchId];
        _redeemRequests.redeemRequest[msg.sender] = _amountSharesToRedeem;
        _redeemRequests.usersToRedeem.push(msg.sender);
        emit RedeemRequest(msg.sender, _classId, _amount, _currentBatchId);
        return _currentBatchId;
    }
}
