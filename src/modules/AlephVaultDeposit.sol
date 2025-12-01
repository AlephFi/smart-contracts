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
import {IAlephVaultDeposit} from "@aleph-vault/interfaces/IAlephVaultDeposit.sol";
import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
import {TimelockRegistry} from "@aleph-vault/libraries/TimelockRegistry.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {SeriesAccounting} from "@aleph-vault/libraries/SeriesAccounting.sol";
import {IAlephVaultSettlement} from "@aleph-vault/interfaces/IAlephVaultSettlement.sol";
import {AlephVaultBase} from "@aleph-vault/AlephVaultBase.sol";
import {AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract AlephVaultDeposit is IAlephVaultDeposit, AlephVaultBase {
    using SafeERC20 for IERC20;
    using TimelockRegistry for bytes4;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SeriesAccounting for IAlephVault.ShareClass;

    /**
     * @notice The timelock period for the minimum deposit amount.
     */
    uint48 public immutable MIN_DEPOSIT_AMOUNT_TIMELOCK;
    /**
     * @notice The timelock period for the minimum user balance.
     */
    uint48 public immutable MIN_USER_BALANCE_TIMELOCK;
    /**
     * @notice The timelock period for the maximum deposit cap.
     */
    uint48 public immutable MAX_DEPOSIT_CAP_TIMELOCK;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Constructor for AlephVaultDeposit module
     * @param _constructorParams The initialization parameters for deposit configuration
     * @param _batchDuration The duration of each batch cycle in seconds
     */
    constructor(DepositConstructorParams memory _constructorParams, uint48 _batchDuration)
        AlephVaultBase(_batchDuration)
    {
        if (
            _constructorParams.minDepositAmountTimelock == 0 || _constructorParams.minUserBalanceTimelock == 0
                || _constructorParams.maxDepositCapTimelock == 0
        ) {
            revert InvalidConstructorParams();
        }
        MIN_DEPOSIT_AMOUNT_TIMELOCK = _constructorParams.minDepositAmountTimelock;
        MIN_USER_BALANCE_TIMELOCK = _constructorParams.minUserBalanceTimelock;
        MAX_DEPOSIT_CAP_TIMELOCK = _constructorParams.maxDepositCapTimelock;
    }

    /*//////////////////////////////////////////////////////////////
                            TIMELOCK FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IAlephVaultDeposit
    function queueMinDepositAmount(uint8 _classId, uint256 _minDepositAmount) external {
        _queueMinDepositAmount(_getStorage(), _classId, _minDepositAmount);
    }

    /// @inheritdoc IAlephVaultDeposit
    function queueMinUserBalance(uint8 _classId, uint256 _minUserBalance) external {
        _queueMinUserBalance(_getStorage(), _classId, _minUserBalance);
    }

    /// @inheritdoc IAlephVaultDeposit
    function queueMaxDepositCap(uint8 _classId, uint256 _maxDepositCap) external {
        _queueMaxDepositCap(_getStorage(), _classId, _maxDepositCap);
    }

    /// @inheritdoc IAlephVaultDeposit
    function setMinDepositAmount(uint8 _classId) external {
        _setMinDepositAmount(_getStorage(), _classId);
    }

    /// @inheritdoc IAlephVaultDeposit
    function setMinUserBalance(uint8 _classId) external {
        _setMinUserBalance(_getStorage(), _classId);
    }

    /// @inheritdoc IAlephVaultDeposit
    function setMaxDepositCap(uint8 _classId) external {
        _setMaxDepositCap(_getStorage(), _classId);
    }

    /*//////////////////////////////////////////////////////////////
                            DEPOSIT FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IAlephVaultDeposit
    function requestDeposit(RequestDepositParams calldata _requestDepositParams)
        external
        nonReentrant
        returns (uint48 _batchId)
    {
        return _requestDeposit(_getStorage(), _requestDepositParams);
    }

    /// @inheritdoc IAlephVaultDeposit
    function syncDeposit(RequestDepositParams calldata _requestDepositParams)
        external
        nonReentrant
        returns (uint256 _shares)
    {
        return _syncDeposit(_getStorage(), _requestDepositParams);
    }

    /**
     * @notice Checks if total assets are valid for synchronous operations for a specific class.
     * @param _classId The share class ID to check.
     * @return true if sync flows are allowed, false otherwise.
     */
    function isTotalAssetsValid(uint8 _classId) external view returns (bool) {
        return _isTotalAssetsValid(_getStorage(), _classId);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Internal function to queue a new min deposit amount.
     * @param _sd The storage struct.
     * @param _classId The id of the class.
     * @param _minDepositAmount The new min deposit amount.
     */
    function _queueMinDepositAmount(AlephVaultStorageData storage _sd, uint8 _classId, uint256 _minDepositAmount)
        internal
    {
        if (_minDepositAmount == 0) {
            revert InvalidMinDepositAmount();
        }
        _sd.timelocks[TimelockRegistry.MIN_DEPOSIT_AMOUNT.getKey(_classId)] = TimelockRegistry.Timelock({
            isQueued: true,
            unlockTimestamp: Time.timestamp() + MIN_DEPOSIT_AMOUNT_TIMELOCK,
            newValue: abi.encode(_minDepositAmount)
        });
        emit NewMinDepositAmountQueued(_classId, _minDepositAmount);
    }

    /**
     * @dev Internal function to queue a new min user balance.
     * @param _sd The storage struct.
     * @param _classId The id of the class.
     * @param _minUserBalance The new min user balance.
     */
    function _queueMinUserBalance(AlephVaultStorageData storage _sd, uint8 _classId, uint256 _minUserBalance) internal {
        _sd.timelocks[TimelockRegistry.MIN_USER_BALANCE.getKey(_classId)] = TimelockRegistry.Timelock({
            isQueued: true,
            unlockTimestamp: Time.timestamp() + MIN_USER_BALANCE_TIMELOCK,
            newValue: abi.encode(_minUserBalance)
        });
        emit NewMinUserBalanceQueued(_classId, _minUserBalance);
    }

    /**
     * @dev Internal function to queue a new max deposit cap.
     * @param _sd The storage struct.
     * @param _classId The id of the class.
     * @param _maxDepositCap The new max deposit cap.
     */
    function _queueMaxDepositCap(AlephVaultStorageData storage _sd, uint8 _classId, uint256 _maxDepositCap) internal {
        _sd.timelocks[TimelockRegistry.MAX_DEPOSIT_CAP.getKey(_classId)] = TimelockRegistry.Timelock({
            isQueued: true,
            unlockTimestamp: Time.timestamp() + MAX_DEPOSIT_CAP_TIMELOCK,
            newValue: abi.encode(_maxDepositCap)
        });
        emit NewMaxDepositCapQueued(_classId, _maxDepositCap);
    }

    /**
     * @dev Internal function to set a new min deposit amount.
     * @param _sd The storage struct.
     * @param _classId The id of the class.
     */
    function _setMinDepositAmount(AlephVaultStorageData storage _sd, uint8 _classId) internal {
        uint256 _minDepositAmount =
            abi.decode(TimelockRegistry.MIN_DEPOSIT_AMOUNT.setTimelock(_classId, _sd), (uint256));
        _sd.shareClasses[_classId].shareClassParams.minDepositAmount = _minDepositAmount;
        emit NewMinDepositAmountSet(_classId, _minDepositAmount);
    }

    /**
     * @dev Internal function to set a new min user balance.
     * @param _sd The storage struct.
     * @param _classId The id of the class.
     */
    function _setMinUserBalance(AlephVaultStorageData storage _sd, uint8 _classId) internal {
        uint256 _minUserBalance = abi.decode(TimelockRegistry.MIN_USER_BALANCE.setTimelock(_classId, _sd), (uint256));
        _sd.shareClasses[_classId].shareClassParams.minUserBalance = _minUserBalance;
        emit NewMinUserBalanceSet(_classId, _minUserBalance);
    }

    /**
     * @dev Internal function to set a new max deposit cap.
     * @param _sd The storage struct.
     * @param _classId The id of the class.
     */
    function _setMaxDepositCap(AlephVaultStorageData storage _sd, uint8 _classId) internal {
        uint256 _maxDepositCap = abi.decode(TimelockRegistry.MAX_DEPOSIT_CAP.setTimelock(_classId, _sd), (uint256));
        _sd.shareClasses[_classId].shareClassParams.maxDepositCap = _maxDepositCap;
        emit NewMaxDepositCapSet(_classId, _maxDepositCap);
    }

    /**
     * @dev Internal function to validate deposit parameters.
     * @param _sd The storage struct.
     * @param _shareClass The share class.
     * @param _requestDepositParams The parameters for the deposit.
     */
    function _validateDeposit(
        AlephVaultStorageData storage _sd,
        IAlephVault.ShareClass storage _shareClass,
        RequestDepositParams calldata _requestDepositParams
    ) internal view {
        if (_requestDepositParams.amount == 0) {
            revert InsufficientDeposit();
        }
        IAlephVault.ShareClassParams memory _shareClassParams = _shareClass.shareClassParams;
        if (_requestDepositParams.amount < _shareClassParams.minDepositAmount) {
            revert DepositLessThanMinDepositAmount(_shareClassParams.minDepositAmount);
        }
        if (
            _shareClassParams.minUserBalance > 0
                && _assetsPerClassOf(_shareClass, _requestDepositParams.classId, msg.sender)
                        + _depositRequestOf(_sd, _requestDepositParams.classId, msg.sender)
                        + _requestDepositParams.amount < _shareClassParams.minUserBalance
        ) {
            revert DepositLessThanMinUserBalance(_shareClassParams.minUserBalance);
        }
        if (
            _shareClassParams.maxDepositCap > 0
                && _totalAssetsPerClass(_shareClass, _requestDepositParams.classId)
                        + _totalAmountToDeposit(_sd, _requestDepositParams.classId) + _requestDepositParams.amount
                    > _shareClassParams.maxDepositCap
        ) {
            revert DepositExceedsMaxDepositCap(_shareClassParams.maxDepositCap);
        }
        if (_sd.isDepositAuthEnabled) {
            AuthLibrary.verifyDepositRequestAuthSignature(
                _requestDepositParams.classId, _sd.authSigner, _requestDepositParams.authSignature
            );
        }
    }

    /**
     * @dev Internal function to transfer assets from user to vault.
     * @param _sd The storage struct.
     * @param _amount The amount to transfer.
     */
    function _transferAssetsFromUserToVault(AlephVaultStorageData storage _sd, uint256 _amount) internal {
        IERC20 _underlyingToken = IERC20(_sd.underlyingToken);
        uint256 _balanceBefore = _underlyingToken.balanceOf(address(this));
        _underlyingToken.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 _depositedAmount = _underlyingToken.balanceOf(address(this)) - _balanceBefore;
        if (_depositedAmount != _amount) {
            revert DepositRequestFailed();
        }
    }

    /**
     * @dev Internal function to update lock-in period for a user if applicable.
     * @param _shareClass The share class.
     * @param _currentBatchId The current batch ID.
     */
    function _updateLockInPeriod(IAlephVault.ShareClass storage _shareClass, uint48 _currentBatchId) internal {
        IAlephVault.ShareClassParams memory _shareClassParams = _shareClass.shareClassParams;
        if (_shareClassParams.lockInPeriod > 0 && _shareClass.userLockInPeriod[msg.sender] == 0) {
            _shareClass.userLockInPeriod[msg.sender] = _currentBatchId + _shareClassParams.lockInPeriod;
        }
    }

    /**
     * @dev Internal function to handle a deposit request.
     * @param _sd The storage struct.
     * @param _requestDepositParams The parameters for the deposit request.
     * @return _batchId The batch ID for the deposit.
     */
    function _requestDeposit(AlephVaultStorageData storage _sd, RequestDepositParams calldata _requestDepositParams)
        internal
        returns (uint48 _batchId)
    {
        IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_requestDepositParams.classId];
        _validateDeposit(_sd, _shareClass, _requestDepositParams);
        uint48 _currentBatchId = _currentBatch(_sd);
        IAlephVault.DepositRequests storage _depositRequests = _shareClass.depositRequests[_currentBatchId];
        if (_depositRequests.depositRequest[msg.sender] > 0) {
            revert OnlyOneRequestPerBatchAllowedForDeposit();
        }

        _updateLockInPeriod(_shareClass, _currentBatchId);

        // register deposit request
        _sd.totalAmountToDeposit += _requestDepositParams.amount;
        _depositRequests.depositRequest[msg.sender] = _requestDepositParams.amount;
        _depositRequests.totalAmountToDeposit += _requestDepositParams.amount;
        _depositRequests.usersToDeposit.add(msg.sender);
        emit DepositRequest(_requestDepositParams.classId, _currentBatchId, msg.sender, _requestDepositParams.amount);

        // transfer underlying token from user to vault
        _transferAssetsFromUserToVault(_sd, _requestDepositParams.amount);
        return _currentBatchId;
    }

    /**
     * @dev Internal function to determine the series ID for a sync deposit.
     * Uses the same logic as settlement to ensure consistent series accounting.
     * @param _shareClass The share class.
     * @param _classId The class ID.
     * @param _currentBatchId The current batch ID.
     * @return _seriesId The series ID to use for the deposit.
     */
    function _determineSeriesIdForSyncDeposit(
        IAlephVault.ShareClass storage _shareClass,
        uint8 _classId,
        uint48 _currentBatchId
    ) internal returns (uint32 _seriesId) {
        _seriesId = SeriesAccounting.LEAD_SERIES_ID;
        if (_shareClass.shareClassParams.performanceFee > 0) {
            uint32 _shareSeriesId = _shareClass.shareSeriesId;
            uint32 _lastConsolidatedSeriesId = _shareClass.lastConsolidatedSeriesId;
            
            // If lead series high water mark is above current price, deposits should go to a new series
            // This ensures new deposits don't pay performance fees on gains they didn't participate in
            if (
                _shareClass.shareSeries[SeriesAccounting.LEAD_SERIES_ID].highWaterMark
                    > _leadPricePerShare(_shareClass, _classId)
            ) {
                // Check if there's already an active series (same logic as async settlement)
                // If an active series exists, reuse it instead of creating a duplicate
                if (_shareSeriesId > _lastConsolidatedSeriesId) {
                    // Use the existing active series
                    _seriesId = _shareSeriesId;
                } else {
                    // No active series exists, create a new one
                    // Read shareSeriesId after creation to avoid race conditions
                    _shareClass.createNewSeries(_classId, _currentBatchId);
                    _seriesId = _shareClass.shareSeriesId; // Use the actual created series ID
                }
            } else if (_shareSeriesId > _lastConsolidatedSeriesId) {
                // If high water mark was reached and outstanding series exist, consolidate them first
                // This ensures all deposits go to lead series when HWM is reached
                _shareClass.consolidateSeries(_classId, _shareSeriesId, _lastConsolidatedSeriesId, _currentBatchId);
                _seriesId = SeriesAccounting.LEAD_SERIES_ID;
            }
        }
    }

    /**
     * @dev Internal function to handle a synchronous deposit.
     * @param _sd The storage struct.
     * @param _requestDepositParams The parameters for the deposit.
     * @return _shares The number of shares minted.
     */
    function _syncDeposit(AlephVaultStorageData storage _sd, RequestDepositParams calldata _requestDepositParams)
        internal
        returns (uint256 _shares)
    {
        if (!_isTotalAssetsValid(_sd, _requestDepositParams.classId)) {
            revert OnlyAsyncDepositAllowed();
        }

        IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_requestDepositParams.classId];
        _validateDeposit(_sd, _shareClass, _requestDepositParams);
        uint48 _currentBatchId = _currentBatch(_sd);

        // Determine series BEFORE state changes to prevent stuck assets if series operations fail
        uint32 _seriesId = _determineSeriesIdForSyncDeposit(
            _shareClass, _requestDepositParams.classId, _currentBatchId
        );

        IAlephVault.ShareSeries storage _shareSeries = _shareClass.shareSeries[_seriesId];
        _shares =
            ERC4626Math.previewDeposit(_requestDepositParams.amount, _shareSeries.totalShares, _shareSeries.totalAssets);

        // CEI Pattern: Effects first (mint shares, update state)
        // Mint shares immediately to msg.sender in the determined series
        _shareSeries.sharesOf[msg.sender] += _shares;
        _shareSeries.totalShares += _shares;
        _shareSeries.totalAssets += _requestDepositParams.amount;

        // Add user to series if they don't already exist
        if (!_shareSeries.users.contains(msg.sender)) {
            _shareSeries.users.add(msg.sender);
        }

        // Update lock-in period if applicable
        _updateLockInPeriod(_shareClass, _currentBatchId);

        emit SyncDeposit(_requestDepositParams.classId, msg.sender, _requestDepositParams.amount, _shares);

        // CEI Pattern: Interactions last (transfer assets)
        // Transfer assets from user to vault, then to custodian
        // This allows users to only approve the vault contract
        _transferAssetsFromUserToVault(_sd, _requestDepositParams.amount);

        // Transfer from vault to custodian
        IERC20(_sd.underlyingToken).safeTransfer(_sd.custodian, _requestDepositParams.amount);
    }
}
