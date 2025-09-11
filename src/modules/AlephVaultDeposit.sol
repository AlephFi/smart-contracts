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

import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephVaultDeposit} from "@aleph-vault/interfaces/IAlephVaultDeposit.sol";
import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
import {TimelockRegistry} from "@aleph-vault/libraries/TimelockRegistry.sol";
import {AlephVaultBase} from "@aleph-vault/AlephVaultBase.sol";
import {AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract AlephVaultDeposit is IAlephVaultDeposit, AlephVaultBase {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using TimelockRegistry for bytes4;

    uint48 public immutable MIN_DEPOSIT_AMOUNT_TIMELOCK;
    uint48 public immutable MIN_USER_BALANCE_TIMELOCK;
    uint48 public immutable MAX_DEPOSIT_CAP_TIMELOCK;

    constructor(
        uint48 _minDepositAmountTimelock,
        uint48 _minUserBalanceTimelock,
        uint48 _maxDepositCapTimelock,
        uint48 _batchDuration
    ) AlephVaultBase(_batchDuration) {
        if (_minDepositAmountTimelock == 0 || _minUserBalanceTimelock == 0 || _maxDepositCapTimelock == 0) {
            revert InvalidConstructorParams();
        }
        MIN_DEPOSIT_AMOUNT_TIMELOCK = _minDepositAmountTimelock;
        MIN_USER_BALANCE_TIMELOCK = _minUserBalanceTimelock;
        MAX_DEPOSIT_CAP_TIMELOCK = _maxDepositCapTimelock;
    }

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

    /// @inheritdoc IAlephVaultDeposit
    function requestDeposit(RequestDepositParams calldata _requestDepositParams)
        external
        nonReentrant
        returns (uint48 _batchId)
    {
        return _requestDeposit(_getStorage(), _requestDepositParams);
    }

    /**
     * @dev Internal function to queue a new min deposit amount.
     * @param _sd The storage struct.
     * @param _classId The id of the class.
     * @param _minDepositAmount The new min deposit amount.
     */
    function _queueMinDepositAmount(AlephVaultStorageData storage _sd, uint8 _classId, uint256 _minDepositAmount)
        internal
    {
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
    function _queueMinUserBalance(AlephVaultStorageData storage _sd, uint8 _classId, uint256 _minUserBalance)
        internal
    {
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
        _sd.shareClasses[_classId].minDepositAmount = _minDepositAmount;
        emit NewMinDepositAmountSet(_classId, _minDepositAmount);
    }

    /**
     * @dev Internal function to set a new min user balance.
     * @param _sd The storage struct.
     * @param _classId The id of the class.
     */
    function _setMinUserBalance(AlephVaultStorageData storage _sd, uint8 _classId) internal {
        uint256 _minUserBalance = abi.decode(TimelockRegistry.MIN_USER_BALANCE.setTimelock(_classId, _sd), (uint256));
        _sd.shareClasses[_classId].minUserBalance = _minUserBalance;
        emit NewMinUserBalanceSet(_classId, _minUserBalance);
    }

    /**
     * @dev Internal function to set a new max deposit cap.
     * @param _sd The storage struct.
     * @param _classId The id of the class.
     */
    function _setMaxDepositCap(AlephVaultStorageData storage _sd, uint8 _classId) internal {
        uint256 _maxDepositCap = abi.decode(TimelockRegistry.MAX_DEPOSIT_CAP.setTimelock(_classId, _sd), (uint256));
        _sd.shareClasses[_classId].maxDepositCap = _maxDepositCap;
        emit NewMaxDepositCapSet(_classId, _maxDepositCap);
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
        // verify all conditions are satisfied to make deposit request
        if (_requestDepositParams.amount == 0) {
            revert InsufficientDeposit();
        }
        IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_requestDepositParams.classId];
        uint256 _minDepositAmount = _shareClass.minDepositAmount;
        if (_minDepositAmount > 0 && _requestDepositParams.amount < _minDepositAmount) {
            revert DepositLessThanMinDepositAmount(_minDepositAmount);
        }
        uint256 _minUserBalance = _shareClass.minUserBalance;
        if (
            _minUserBalance > 0
                && _assetsPerClassOf(_requestDepositParams.classId, msg.sender, _shareClass)
                    + _depositRequestOf(_sd, _requestDepositParams.classId, msg.sender) + _requestDepositParams.amount
                    < _minUserBalance
        ) {
            revert DepositLessThanMinUserBalance(_minUserBalance);
        }
        uint256 _maxDepositCap = _shareClass.maxDepositCap;
        if (
            _maxDepositCap > 0
                && _totalAssetsPerClass(_shareClass, _requestDepositParams.classId)
                    + _totalAmountToDeposit(_sd, _requestDepositParams.classId) + _requestDepositParams.amount > _maxDepositCap
        ) {
            revert DepositExceedsMaxDepositCap(_maxDepositCap);
        }
        if (_sd.isDepositAuthEnabled) {
            AuthLibrary.verifyDepositRequestAuthSignature(
                _requestDepositParams.classId, _sd.authSigner, _requestDepositParams.authSignature
            );
        }
        uint48 _currentBatchId = _currentBatch(_sd);
        uint48 _lockInPeriod = _shareClass.lockInPeriod;
        if (_lockInPeriod > 0 && _shareClass.userLockInPeriod[msg.sender] == 0) {
            _shareClass.userLockInPeriod[msg.sender] = _currentBatchId + _lockInPeriod;
        }
        IAlephVault.DepositRequests storage _depositRequests = _shareClass.depositRequests[_currentBatchId];
        if (_depositRequests.depositRequest[msg.sender] > 0) {
            revert OnlyOneRequestPerBatchAllowedForDeposit();
        }

        // register deposit request
        _depositRequests.depositRequest[msg.sender] = _requestDepositParams.amount;
        _depositRequests.totalAmountToDeposit += _requestDepositParams.amount;
        _depositRequests.usersToDeposit.push(msg.sender);
        emit DepositRequest(msg.sender, _requestDepositParams.classId, _requestDepositParams.amount, _currentBatchId);

        // transfer underlying token from user to vault
        IERC20 _underlyingToken = IERC20(_sd.underlyingToken);
        uint256 _balanceBefore = _underlyingToken.balanceOf(address(this));
        _underlyingToken.safeTransferFrom(msg.sender, address(this), _requestDepositParams.amount);
        uint256 _depositedAmount = _underlyingToken.balanceOf(address(this)) - _balanceBefore;
        if (_depositedAmount != _requestDepositParams.amount) {
            revert DepositRequestFailed();
        }
        return _currentBatchId;
    }
}
