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
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(uint48 _batchDuration) AlephVaultBase(_batchDuration) {}

    /// @inheritdoc IERC7540Redeem
    function requestRedeem(uint8 _classId, uint256 _amount) external returns (uint48 _batchId) {
        return _requestRedeem(_getStorage(), _classId, _amount);
    }

    /**
     * @dev Internal function to handle a redeem request.
     * @param _amountToRedeem The amount of assets to redeem.
     * @return _batchId The batch ID for the redeem request.
     */
    function _requestRedeem(AlephVaultStorageData storage _sd, uint8 _classId, uint256 _amountToRedeem)
        internal
        returns (uint48 _batchId)
    {
        if (_amountToRedeem == 0) {
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
        if (_assetsPerClassOf(_classId, msg.sender) < _amountToRedeem) {
            revert InsufficientAssetsToRedeem();
        }
        _sd.lastRedeemBatchId[msg.sender] = _currentBatchId;
        IAlephVault.RedeemRequests storage _redeemRequests = _sd.shareClasses[_classId].redeemRequests[_currentBatchId];
        _redeemRequests.redeemRequest[msg.sender] = _amountToRedeem;
        _redeemRequests.totalAmountToRedeem += _amountToRedeem;
        _redeemRequests.usersToRedeem.add(msg.sender);
        emit RedeemRequest(msg.sender, _amountToRedeem, _currentBatchId);
        return _currentBatchId;
    }
}
