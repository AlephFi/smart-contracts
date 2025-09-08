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
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract AlephVaultRedeem is IERC7540Redeem, AlephVaultBase {
    using Math for uint256;

    constructor(uint48 _batchDuration) AlephVaultBase(_batchDuration) {}

    /// @inheritdoc IERC7540Redeem
    function requestRedeem(uint8 _classId, uint256 _estAmount) external returns (uint48 _batchId) {
        return _requestRedeem(_getStorage(), _classId, _estAmount);
    }

    /**
     * @dev Internal function to handle a redeem request.
     * @param _sd The storage struct.
     * @param _classId The class ID to redeem from.
     * @param _estAmount The estimated amount to redeem.
     * @return _batchId The batch ID for the redeem request.
     */
    function _requestRedeem(AlephVaultStorageData storage _sd, uint8 _classId, uint256 _estAmount)
        internal
        returns (uint48 _batchId)
    {
        // verify all conditions are satisfied to make redeem request
        if (_estAmount == 0) {
            revert InsufficientRedeem();
        }
        uint48 _currentBatchId = _currentBatch(_sd);
        IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_classId];
        // get total user assets in the share class
        uint256 _totalUserAssets = _assetsPerClassOf(_classId, msg.sender, _shareClass);
        // get pending assets of the user that will be settled in upcoming cycle
        uint256 _pendingAssets = _pendingAssetsOf(_shareClass, _classId, _currentBatchId, msg.sender, _totalUserAssets);
        if (_pendingAssets + _estAmount > _totalUserAssets) {
            revert InsufficientAssetsToRedeem();
        }

        // Calculate redeemable share units as a proportion of user's available assets
        // Formula: shares = amount * TOTAL_SHARE_UNITS / (totalUserAssets - pendingAssets)
        // This calculation is crucial because:
        // 1. This approach handles dynamic asset values during settlement, as the vault's
        //    total value may change due to PnL between request and settlement
        // 2. Pending assets are excluded in this calculation as they're already being processed
        //    in other batches at the time of settlement
        // 2. During redemption, redeem requests are settled by iterating over past unsettled batches.
        //    Using available assets (total - pending) as denominator ensures redemption requests
        //    are correctly sized relative to user's redeemable position at that particular batch
        uint256 _shareUnitsToRedeem = ERC4626Math.previewWithdrawUnits(_estAmount, _totalUserAssets - _pendingAssets);

        IAlephVault.RedeemRequests storage _redeemRequests = _shareClass.redeemRequests[_currentBatchId];
        if (_redeemRequests.redeemRequest[msg.sender] > 0) {
            revert OnlyOneRequestPerBatchAllowedForRedeem();
        }

        // register redeem request
        _redeemRequests.redeemRequest[msg.sender] = _shareUnitsToRedeem;
        _redeemRequests.usersToRedeem.push(msg.sender);
        emit RedeemRequest(msg.sender, _classId, _estAmount, _currentBatchId);
        return _currentBatchId;
    }
}
