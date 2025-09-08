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
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IERC7540Redeem} from "@aleph-vault/interfaces/IERC7540Redeem.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {TimelockRegistry} from "@aleph-vault/libraries/TimelockRegistry.sol";
import {AlephVaultBase} from "@aleph-vault/AlephVaultBase.sol";
import {AlephVaultStorage, AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract AlephVaultRedeem is IERC7540Redeem, AlephVaultBase {
    using Math for uint256;

    uint48 public immutable NOTICE_PERIOD_TIMELOCK;

    constructor(uint48 _noticePeriodTimelock, uint48 _batchDuration) AlephVaultBase(_batchDuration) {
        if (_noticePeriodTimelock == 0) {
            revert InvalidConstructorParams();
        }
        NOTICE_PERIOD_TIMELOCK = _noticePeriodTimelock;
    }

    /// @inheritdoc IERC7540Redeem
    function queueNoticePeriod(uint8 _classId, uint48 _noticePeriod) external {
        _queueNoticePeriod(_getStorage(), _classId, _noticePeriod);
    }

    /// @inheritdoc IERC7540Redeem
    function setNoticePeriod() external {
        _setNoticePeriod(_getStorage());
    }

    /// @inheritdoc IERC7540Redeem
    function requestRedeem(uint8 _classId, uint256 _estAmount) external returns (uint48 _batchId) {
        return _requestRedeem(_getStorage(), _classId, _estAmount);
    }

    /**
     * @dev Internal function to queue a new notice period.
     * @param _sd The storage struct.
     * @param _classId The id of the class.
     * @param _noticePeriod The new notice period.
     */
    function _queueNoticePeriod(AlephVaultStorageData storage _sd, uint8 _classId, uint48 _noticePeriod) internal {
        _sd.timelocks[TimelockRegistry.NOTICE_PERIOD] = TimelockRegistry.Timelock({
            unlockTimestamp: Time.timestamp() + NOTICE_PERIOD_TIMELOCK,
            newValue: abi.encode(_classId, _noticePeriod)
        });
        emit NewNoticePeriodQueued(_classId, _noticePeriod);
    }

    /**
     * @dev Internal function to set the notice period.
     * @param _sd The storage struct.
     */
    function _setNoticePeriod(AlephVaultStorageData storage _sd) internal {
        (uint8 _classId, uint48 _noticePeriod) =
            abi.decode(TimelockRegistry.setTimelock(_sd, TimelockRegistry.NOTICE_PERIOD), (uint8, uint48));
        _sd.shareClasses[_classId].noticePeriod = _noticePeriod;
        emit NewNoticePeriodSet(_classId, _noticePeriod);
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
        uint256 _pendingAssets = _pendingAssetsOf(_sd, _classId, _currentBatchId, msg.sender, _totalUserAssets);
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
