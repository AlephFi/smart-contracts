// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;
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

import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephVaultRedeem} from "@aleph-vault/interfaces/IAlephVaultRedeem.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {SeriesAccounting} from "@aleph-vault/libraries/SeriesAccounting.sol";
import {TimelockRegistry} from "@aleph-vault/libraries/TimelockRegistry.sol";
import {AlephVaultBase} from "@aleph-vault/AlephVaultBase.sol";
import {AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract AlephVaultRedeem is IAlephVaultRedeem, AlephVaultBase {
    using SafeERC20 for IERC20;
    using TimelockRegistry for bytes4;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SeriesAccounting for IAlephVault.ShareClass;

    /**
     * @notice The timelock period for the notice period.
     */
    uint48 public immutable NOTICE_PERIOD_TIMELOCK;
    /**
     * @notice The timelock period for the lock in period.
     */
    uint48 public immutable LOCK_IN_PERIOD_TIMELOCK;
    /**
     * @notice The timelock period for the minimum redeem amount.
     */
    uint48 public immutable MIN_REDEEM_AMOUNT_TIMELOCK;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Constructor for AlephVaultRedeem module
     * @param _constructorParams The initialization parameters for redeem configuration
     * @param _batchDuration The duration of each batch cycle in seconds
     */
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

    /*//////////////////////////////////////////////////////////////
                            TIMELOCK FUNCTIONS
    //////////////////////////////////////////////////////////////*/
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

    /*//////////////////////////////////////////////////////////////
                            REDEEM FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IAlephVaultRedeem
    function requestRedeem(RedeemRequestParams calldata _redeemRequestParams) external returns (uint48 _batchId) {
        return _requestRedeem(_getStorage(), _redeemRequestParams);
    }

    /// @inheritdoc IAlephVaultRedeem
    function syncRedeem(RedeemRequestParams calldata _redeemRequestParams)
        external
        nonReentrant
        returns (uint256 _assets)
    {
        return _syncRedeem(_getStorage(), _redeemRequestParams);
    }

    /// @inheritdoc IAlephVaultRedeem
    function withdrawRedeemableAmount() external nonReentrant {
        _withdrawRedeemableAmount(_getStorage());
    }

    /// @inheritdoc IAlephVaultRedeem
    function withdrawExcessAssets() external nonReentrant {
        _withdrawExcessAssets(_getStorage());
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
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
        if (_minRedeemAmount == 0) {
            revert InvalidMinRedeemAmount();
        }
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
        uint48 _currentBatchId = _currentBatch(_sd);
        // get total user assets in the share class
        uint256 _totalUserAssets = _assetsPerClassOf(_shareClass, _redeemRequestParams.classId, msg.sender);
        // get pending assets of the user that will be settled in upcoming cycle
        uint256 _pendingUserAssets = _pendingAssetsOf(_shareClass, _currentBatchId, msg.sender, _totalUserAssets);

        // validate redeem request is valid
        _validateRedeem(_shareClass, _currentBatchId, _totalUserAssets, _pendingUserAssets, _redeemRequestParams, true);

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
        uint256 _shareUnits = ERC4626Math.previewWithdrawUnits(
            _redeemRequestParams.estAmountToRedeem, _totalUserAssets - _pendingUserAssets
        );

        // register redeem request
        IAlephVault.RedeemRequests storage _redeemRequests = _shareClass.redeemRequests[_currentBatchId];
        _redeemRequests.redeemRequest[msg.sender] = _shareUnits;
        _redeemRequests.usersToRedeem.add(msg.sender);
        emit RedeemRequest(
            _redeemRequestParams.classId, _currentBatchId, msg.sender, _redeemRequestParams.estAmountToRedeem
        );
        return _currentBatchId;
    }

    /**
     * @dev Internal function to validate a redeem request (shared between async and sync).
     * @param _shareClass The share class.
     * @param _currentBatchId The current batch ID.
     * @param _totalUserAssets The total user assets.
     * @param _pendingUserAssets The pending user assets (0 for sync, >0 for async).
     * @param _redeemRequestParams The redeem request parameters.
     * @param _checkDuplicate Whether to check for duplicate requests in batch (async only).
     */
    function _validateRedeem(
        IAlephVault.ShareClass storage _shareClass,
        uint48 _currentBatchId,
        uint256 _totalUserAssets,
        uint256 _pendingUserAssets,
        RedeemRequestParams calldata _redeemRequestParams,
        bool _checkDuplicate
    ) internal {
        uint256 _availableUserAssets = _totalUserAssets - _pendingUserAssets;
        if (
            _redeemRequestParams.estAmountToRedeem == 0 || _redeemRequestParams.estAmountToRedeem > _availableUserAssets
        ) {
            revert InsufficientAssetsToRedeem();
        }

        uint256 _previewRemainingAmount =
            _totalUserAssets - (_redeemRequestParams.estAmountToRedeem + _pendingUserAssets);

        IAlephVault.ShareClassParams memory _shareClassParams = _shareClass.shareClassParams;

        // Check min redeem amount (only if not redeeming all)
        if (_previewRemainingAmount > 0 && _redeemRequestParams.estAmountToRedeem < _shareClassParams.minRedeemAmount) {
            revert RedeemLessThanMinRedeemAmount(_shareClassParams.minRedeemAmount);
        }

        // Check lock-in period
        uint48 _userLockInPeriod = _shareClass.userLockInPeriod[msg.sender];
        if (_shareClassParams.lockInPeriod > 0 && _userLockInPeriod > _currentBatchId) {
            revert UserInLockInPeriodNotElapsed(_userLockInPeriod);
        }

        // Check min user balance (only if not redeeming all)
        if (
            _shareClassParams.minUserBalance > 0 && _previewRemainingAmount > 0
                && _previewRemainingAmount < _shareClassParams.minUserBalance
        ) {
            revert RedeemFallBelowMinUserBalance(_shareClassParams.minUserBalance);
        }

        // Clear lock-in period if redeeming all
        if (_shareClassParams.lockInPeriod > 0 && _previewRemainingAmount == 0) {
            delete _shareClass.userLockInPeriod[msg.sender];
        }

        // Check for duplicate requests in batch (async only)
        if (_checkDuplicate && _shareClass.redeemRequests[_currentBatchId].redeemRequest[msg.sender] > 0) {
            revert OnlyOneRequestPerBatchAllowedForRedeem();
        }
    }

    /**
     * @dev Internal function to withdraw the redeemable amount.
     * @param _sd The storage struct.
     */
    function _withdrawRedeemableAmount(AlephVaultStorageData storage _sd) internal {
        uint256 _redeemableAmount = _sd.redeemableAmount[msg.sender];
        delete _sd.redeemableAmount[msg.sender];
        _sd.totalAmountToWithdraw -= _redeemableAmount;
        IERC20(_sd.underlyingToken).safeTransfer(msg.sender, _redeemableAmount);
        emit RedeemableAmountWithdrawn(msg.sender, _redeemableAmount);
    }

    /**
     * @dev Internal function to preview the amount of assets that will be redeemed.
     * This uses the same FIFO logic as settleRedeemForUser but doesn't modify state.
     * @param _shareClass The share class.
     * @param _user The user to preview redeem for.
     * @param _amount The amount to preview redeem.
     * @return The previewed assets amount.
     */
    function _previewRedeemAmount(
        IAlephVault.ShareClass storage _shareClass,
        uint8,
        /* _classId */
        address _user,
        uint256 _amount
    ) internal view returns (uint256) {
        uint256 _remainingAmount = _amount;
        uint32 _shareSeriesId = _shareClass.shareSeriesId;
        uint256 _totalAssetsToRedeem = 0;

        // Iterate through all series in FIFO order (same as settleRedeemForUser)
        for (uint32 _seriesId; _seriesId <= _shareSeriesId; _seriesId++) {
            if (_remainingAmount == 0) {
                break;
            }
            IAlephVault.ShareSeries storage _shareSeries = _shareClass.shareSeries[_seriesId];
            uint256 _sharesInSeries = _shareSeries.sharesOf[_user];
            uint256 _amountInSeries =
                ERC4626Math.previewRedeem(_sharesInSeries, _shareSeries.totalAssets, _shareSeries.totalShares);

            if (_amountInSeries <= _remainingAmount) {
                _totalAssetsToRedeem += _amountInSeries;
                _remainingAmount -= _amountInSeries;
            } else {
                _totalAssetsToRedeem += _remainingAmount;
                _remainingAmount = 0;
            }

            if (_seriesId == SeriesAccounting.LEAD_SERIES_ID) {
                _seriesId = _shareClass.lastConsolidatedSeriesId;
            }
        }

        return _totalAssetsToRedeem;
    }

    /**
     * @dev Internal function to withdraw excess assets.
     * @param _sd The storage struct.
     */
    function _withdrawExcessAssets(AlephVaultStorageData storage _sd) internal {
        uint256 _requiredVaultBalance = _sd.totalAmountToDeposit + _sd.totalAmountToWithdraw;
        uint256 _vaultBalance = IERC20(_sd.underlyingToken).balanceOf(address(this));
        if (_vaultBalance <= _requiredVaultBalance) {
            revert InsufficientVaultBalance();
        }
        IERC20(_sd.underlyingToken).safeTransfer(_sd.custodian, _vaultBalance - _requiredVaultBalance);
        emit ExcessAssetsWithdrawn(_vaultBalance - _requiredVaultBalance);
    }

    /**
     * @dev Internal function to calculate and validate redeemed assets.
     * @param _shareClass The share class.
     * @param _classId The class ID.
     * @param _currentBatchId The current batch ID.
     * @param _user The user redeeming.
     * @param _estAmountToRedeem The estimated amount to redeem.
     * @param _previewAssets The previewed assets amount.
     * @param _vaultBalance The vault balance.
     * @return _assets The validated amount of assets redeemed.
     */
    function _calculateAndValidateRedeemedAssets(
        IAlephVault.ShareClass storage _shareClass,
        uint8 _classId,
        uint48 _currentBatchId,
        address _user,
        uint256 _estAmountToRedeem,
        uint256 _previewAssets,
        uint256 _vaultBalance
    ) internal returns (uint256 _assets) {
        uint256 _assetsBefore = _totalAssetsPerClass(_shareClass, _classId);
        _shareClass.settleRedeemForUser(_classId, _currentBatchId, _user, _estAmountToRedeem);
        uint256 _assetsAfter = _totalAssetsPerClass(_shareClass, _classId);

        // Prevent underflow and validate assets decreased
        if (_assetsAfter > _assetsBefore) {
            revert InsufficientVaultBalance(); // Assets increased unexpectedly
        }
        _assets = _assetsBefore - _assetsAfter;

        // Validate that actual assets match preview (within tolerance for rounding)
        // This ensures vault balance check was accurate and prevents incorrect transfers
        if (_assets > _previewAssets) {
            // Actual is more than preview - vault might not have enough
            if (_vaultBalance < _assets) {
                revert InsufficientVaultBalance();
            }
        }
    }

    /**
     * @dev Internal function to handle a synchronous redeem.
     * @param _sd The storage struct.
     * @param _redeemRequestParams The parameters for the redeem.
     * @return _assets The amount of assets transferred.
     */
    function _syncRedeem(AlephVaultStorageData storage _sd, RedeemRequestParams calldata _redeemRequestParams)
        internal
        returns (uint256 _assets)
    {
        if (!_isTotalAssetsValid(_sd, _redeemRequestParams.classId)) {
            revert OnlyAsyncRedeemAllowed();
        }

        IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_redeemRequestParams.classId];
        IAlephVault.ShareClassParams memory _shareClassParams = _shareClass.shareClassParams;

        // Sync redeem is only available if notice period is 0
        if (_shareClassParams.noticePeriod > 0) {
            revert OnlyAsyncRedeemAllowed();
        }

        uint48 _currentBatchId = _currentBatch(_sd);
        uint256 _totalUserAssets = _assetsPerClassOf(_shareClass, _redeemRequestParams.classId, msg.sender);

        // Calculate pending assets from async redeem requests to prevent double redemption
        // This ensures sync redeem accounts for any pending async redeem requests
        uint256 _pendingUserAssets = _pendingAssetsOf(_shareClass, _currentBatchId, msg.sender, _totalUserAssets);

        // Validate redeem request for sync (accounting for pending assets, no duplicate check)
        // This must happen before settleRedeemForUser to catch validation errors early
        _validateRedeem(_shareClass, _currentBatchId, _totalUserAssets, _pendingUserAssets, _redeemRequestParams, false);

        // Preview and validate vault balance before state modification
        // Note: Sync redeems use current state for pricing (may not include current batch fees).
        // This is acceptable as _isTotalAssetsValid ensures recent settlement.
        uint256 _previewAssets = _previewRedeemAmount(
            _shareClass, _redeemRequestParams.classId, msg.sender, _redeemRequestParams.estAmountToRedeem
        );
        uint256 _vaultBalance = IERC20(_sd.underlyingToken).balanceOf(address(this));
        if (_previewAssets == 0 || _vaultBalance < _previewAssets) {
            revert InsufficientVaultBalance();
        }

        // Use settleRedeemForUser for FIFO redemption across series
        // This burns shares and updates series accounting, but doesn't transfer tokens
        _assets = _calculateAndValidateRedeemedAssets(
            _shareClass,
            _redeemRequestParams.classId,
            _currentBatchId,
            msg.sender,
            _redeemRequestParams.estAmountToRedeem,
            _previewAssets,
            _vaultBalance
        );

        // Transfer assets from vault balance to user
        IERC20(_sd.underlyingToken).safeTransfer(msg.sender, _assets);

        emit SyncRedeem(_redeemRequestParams.classId, msg.sender, _redeemRequestParams.estAmountToRedeem, _assets);
    }
}
