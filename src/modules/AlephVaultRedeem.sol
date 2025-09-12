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
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephVaultRedeem} from "@aleph-vault/interfaces/IAlephVaultRedeem.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {TimelockRegistry} from "@aleph-vault/libraries/TimelockRegistry.sol";
import {AlephVaultBase} from "@aleph-vault/AlephVaultBase.sol";
import {AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract AlephVaultRedeem is IAlephVaultRedeem, AlephVaultBase {
    using TimelockRegistry for bytes4;

    uint48 public immutable NOTICE_PERIOD_TIMELOCK;
    uint48 public immutable LOCK_IN_PERIOD_TIMELOCK;
    uint48 public immutable MIN_REDEEM_AMOUNT_TIMELOCK;

    constructor(RedeemConstructorParams memory _constructorParams, uint48 _batchDuration)
        AlephVaultBase(_batchDuration)
    {
        if (
            _constructorParams.noticePeriodTimelock == 0 || _constructorParams.lockInPeriodTimelock == 0
                || _constructorParams.minRedeemAmountTimelock == 0
        ) {
            revert InvalidConstructorParams();
        }
        NOTICE_PERIOD_TIMELOCK = _constructorParams.noticePeriodTimelock;
        LOCK_IN_PERIOD_TIMELOCK = _constructorParams.lockInPeriodTimelock;
        MIN_REDEEM_AMOUNT_TIMELOCK = _constructorParams.minRedeemAmountTimelock;
    }

    /// @inheritdoc IAlephVaultRedeem
    function queueNoticePeriod(uint8 _classId, uint48 _noticePeriod) external {
        _queueNoticePeriod(_getStorage(), _classId, _noticePeriod);
    }

    /// @inheritdoc IAlephVaultRedeem
    function queueLockInPeriod(uint8 _classId, uint48 _lockInPeriod) external {
        _queueLockInPeriod(_getStorage(), _classId, _lockInPeriod);
    }

    /// @inheritdoc IAlephVaultRedeem
    function queueMinRedeemAmount(uint8 _classId, uint256 _minRedeemAmount) external {
        _queueMinRedeemAmount(_getStorage(), _classId, _minRedeemAmount);
    }

    /// @inheritdoc IAlephVaultRedeem
    function setNoticePeriod(uint8 _classId) external {
        _setNoticePeriod(_getStorage(), _classId);
    }

    /// @inheritdoc IAlephVaultRedeem
    function setLockInPeriod(uint8 _classId) external {
        _setLockInPeriod(_getStorage(), _classId);
    }

    /// @inheritdoc IAlephVaultRedeem
    function setMinRedeemAmount(uint8 _classId) external {
        _setMinRedeemAmount(_getStorage(), _classId);
    }

    /// @inheritdoc IAlephVaultRedeem
    function requestRedeem(RedeemRequestParams calldata _redeemRequestParams) external returns (uint48 _batchId) {
        return _requestRedeem(_getStorage(), _redeemRequestParams);
    }

    /**
     * @dev Internal function to queue a new notice period.
     * @param _sd The storage struct.
     * @param _classId The id of the class.
     * @param _noticePeriod The new notice period in batches
     */
    function _queueNoticePeriod(AlephVaultStorageData storage _sd, uint8 _classId, uint48 _noticePeriod) internal {
        _sd.timelocks[TimelockRegistry.NOTICE_PERIOD.getKey(_classId)] = TimelockRegistry.Timelock({
            isQueued: true,
            unlockTimestamp: Time.timestamp() + NOTICE_PERIOD_TIMELOCK,
            newValue: abi.encode(_noticePeriod)
        });
        emit NewNoticePeriodQueued(_classId, _noticePeriod);
    }

    /**
     * @dev Internal function to queue a new lock in period.
     * @param _sd The storage struct.
     * @param _classId The id of the class.
     * @param _lockInPeriod The new lock in period in batches.
     */
    function _queueLockInPeriod(AlephVaultStorageData storage _sd, uint8 _classId, uint48 _lockInPeriod) internal {
        _sd.timelocks[TimelockRegistry.LOCK_IN_PERIOD.getKey(_classId)] = TimelockRegistry.Timelock({
            isQueued: true,
            unlockTimestamp: Time.timestamp() + LOCK_IN_PERIOD_TIMELOCK,
            newValue: abi.encode(_lockInPeriod)
        });
        emit NewLockInPeriodQueued(_classId, _lockInPeriod);
    }

    /**
     * @dev Internal function to queue a new minimum redeem amount.
     * @param _sd The storage struct.
     * @param _classId The id of the class.
     * @param _minRedeemAmount The new minimum redeem amount.
     */
    function _queueMinRedeemAmount(AlephVaultStorageData storage _sd, uint8 _classId, uint256 _minRedeemAmount)
        internal
    {
        _sd.timelocks[TimelockRegistry.MIN_REDEEM_AMOUNT.getKey(_classId)] = TimelockRegistry.Timelock({
            isQueued: true,
            unlockTimestamp: Time.timestamp() + MIN_REDEEM_AMOUNT_TIMELOCK,
            newValue: abi.encode(_minRedeemAmount)
        });
        emit NewMinRedeemAmountQueued(_classId, _minRedeemAmount);
    }

    /**
     * @dev Internal function to set the notice period.
     * @param _sd The storage struct.
     * @param _classId The id of the class.
     */
    function _setNoticePeriod(AlephVaultStorageData storage _sd, uint8 _classId) internal {
        uint48 _noticePeriod = abi.decode(TimelockRegistry.NOTICE_PERIOD.setTimelock(_classId, _sd), (uint48));
        _sd.shareClasses[_classId].shareClassParams.noticePeriod = _noticePeriod;
        emit NewNoticePeriodSet(_classId, _noticePeriod);
    }

    /**
     * @dev Internal function to set the lock in period.
     * @param _sd The storage struct.
     * @param _classId The id of the class.
     */
    function _setLockInPeriod(AlephVaultStorageData storage _sd, uint8 _classId) internal {
        uint48 _lockInPeriod = abi.decode(TimelockRegistry.LOCK_IN_PERIOD.setTimelock(_classId, _sd), (uint48));
        _sd.shareClasses[_classId].shareClassParams.lockInPeriod = _lockInPeriod;
        emit NewLockInPeriodSet(_classId, _lockInPeriod);
    }

    /**
     * @dev Internal function to set a new minimum redeem amount.
     * @param _sd The storage struct.
     */
    function _setMinRedeemAmount(AlephVaultStorageData storage _sd, uint8 _classId) internal {
        uint256 _minRedeemAmount = abi.decode(TimelockRegistry.MIN_REDEEM_AMOUNT.setTimelock(_classId, _sd), (uint256));
        _sd.shareClasses[_classId].shareClassParams.minRedeemAmount = _minRedeemAmount;
        emit NewMinRedeemAmountSet(_classId, _minRedeemAmount);
    }

    /**
     * @dev Internal function to handle a redeem request.
     * @param _sd The storage struct.
     * @param _redeemRequestParams The parameters for the redeem request.
     * @return _batchId The batch ID for the redeem request.
     */
    function _requestRedeem(AlephVaultStorageData storage _sd, RedeemRequestParams calldata _redeemRequestParams)
        internal
        returns (uint48 _batchId)
    {
        // verify all conditions are satisfied to make redeem request
        IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_redeemRequestParams.classId];
        uint8 _shareSeries = _shareClass.shareSeriesId;
        uint8 _lastConsolidatedSeriesId = _shareClass.lastConsolidatedSeriesId;
        uint256 _amount;
        for (uint256 _i; _i < _redeemRequestParams.shareRequests.length; _i++) {
            if (_redeemRequestParams.shareRequests[_i].shares == 0) {
                revert InsufficientRedeem();
            }
            uint8 _seriesId = _redeemRequestParams.shareRequests[_i].seriesId;
            if (_seriesId > LEAD_SERIES_ID && (_seriesId + _lastConsolidatedSeriesId) > _shareSeries) {
                revert InvalidSeriesId(_seriesId);
            }
            IAlephVault.ShareSeries storage _shareSeries = _shareClass.shareSeries[_seriesId];
            _amount += ERC4626Math.previewRedeem(
                _redeemRequestParams.shareRequests[_i].shares, _shareSeries.totalAssets, _shareSeries.totalShares
            );
        }
        IAlephVault.ShareClassParams memory _shareClassParams = _shareClass.shareClassParams;
        uint48 _currentBatchId = _currentBatch(_sd);
        // get total user assets in the share class
        uint256 _totalUserAssets = _assetsPerClassOf(_redeemRequestParams.classId, msg.sender, _shareClass);
        // get pending assets of the user that will be settled in upcoming cycle
        uint256 _pendingUserAssets =
            _pendingAssetsOf(_shareClass, _redeemRequestParams.classId, _currentBatchId, msg.sender, _totalUserAssets);

        // Share units are a proportion of user's available assets
        // Formula: shares = amount * TOTAL_SHARE_UNITS / (totalUserAssets - pendingAssets)
        // This calculation is crucial because:
        // 1. This approach handles dynamic asset values during settlement, as the vault's
        //    total value may change due to PnL between request and settlement
        // 2. Pending assets are excluded in this calculation as they're already being processed
        //    in other batches at the time of settlement
        // 2. During redemption, redeem requests are settled by iterating over past unsettled batches.
        //    Using available assets (total - pending) as denominator ensures redemption requests
        //    are correctly sized relative to user's redeemable position at that particular batch
        if (_amount == 0 || _amount > _totalUserAssets - _pendingUserAssets) {
            revert InsufficientAssetsToRedeem();
        }
        if (_shareClassParams.minRedeemAmount > 0 && _amount < _shareClassParams.minRedeemAmount) {
            revert RedeemLessThanMinRedeemAmount(_shareClassParams.minRedeemAmount);
        }
        uint48 _userLockInPeriod = _shareClass.userLockInPeriod[msg.sender];
        if (_shareClassParams.lockInPeriod > 0 && _userLockInPeriod > _currentBatchId) {
            revert UserInLockInPeriodNotElapsed(_userLockInPeriod);
        }
        uint256 _remainingAmount = _totalUserAssets - (_amount + _pendingUserAssets);
        if (
            _shareClassParams.minUserBalance > 0 && _remainingAmount > 0
                && _remainingAmount < _shareClassParams.minUserBalance
        ) {
            revert RedeemFallBelowMinUserBalance(_shareClassParams.minUserBalance);
        }
        if (_shareClassParams.lockInPeriod > 0 && _remainingAmount == 0) {
            delete _shareClass.userLockInPeriod[msg.sender];
        }
        IAlephVault.RedeemRequests storage _redeemRequests = _shareClass.redeemRequests[_currentBatchId];
        if (_redeemRequests.redeemRequest[msg.sender] > 0) {
            revert OnlyOneRequestPerBatchAllowedForRedeem();
        }

        // register redeem request
        uint256 _shareUnits = ERC4626Math.previewWithdrawUnits(_amount, _totalUserAssets - _pendingUserAssets);
        _redeemRequests.redeemRequest[msg.sender] = _shareUnits;
        _redeemRequests.usersToRedeem.push(msg.sender);
        emit RedeemRequest(msg.sender, _redeemRequestParams.classId, _shareUnits, _currentBatchId);
        return _currentBatchId;
    }
}
