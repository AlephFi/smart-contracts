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

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {IERC7540Deposit} from "@aleph-vault/interfaces/IERC7540Deposit.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
import {TimelockRegistry} from "@aleph-vault/libraries/TimelockRegistry.sol";
import {AlephVaultBase} from "@aleph-vault/AlephVaultBase.sol";
import {AlephVaultStorage, AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract AlephVaultDeposit is IERC7540Deposit, AlephVaultBase {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint48 public immutable MIN_DEPOSIT_AMOUNT_TIMELOCK;
    uint48 public immutable MAX_DEPOSIT_CAP_TIMELOCK;

    constructor(uint48 _minDepositAmountTimelock, uint48 _maxDepositCapTimelock, uint48 _batchDuration)
        AlephVaultBase(_batchDuration)
    {
        if (_minDepositAmountTimelock == 0 || _maxDepositCapTimelock == 0) {
            revert InvalidConstructorParams();
        }
        MIN_DEPOSIT_AMOUNT_TIMELOCK = _minDepositAmountTimelock;
        MAX_DEPOSIT_CAP_TIMELOCK = _maxDepositCapTimelock;
    }

    /// @inheritdoc IERC7540Deposit
    function queueMinDepositAmount(uint8 _classId, uint256 _minDepositAmount) external {
        _queueMinDepositAmount(_getStorage(), _classId, _minDepositAmount);
    }

    /// @inheritdoc IERC7540Deposit
    function queueMaxDepositCap(uint8 _classId, uint256 _maxDepositCap) external {
        _queueMaxDepositCap(_getStorage(), _classId, _maxDepositCap);
    }

    /// @inheritdoc IERC7540Deposit
    function setMinDepositAmount() external {
        _setMinDepositAmount(_getStorage());
    }

    /// @inheritdoc IERC7540Deposit
    function setMaxDepositCap() external {
        _setMaxDepositCap(_getStorage());
    }

    /// @inheritdoc IERC7540Deposit
    function requestDeposit(RequestDepositParams calldata _requestDepositParams) external returns (uint48 _batchId) {
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
        _sd.timelocks[TimelockRegistry.MIN_DEPOSIT_AMOUNT] = TimelockRegistry.Timelock({
            unlockTimestamp: Time.timestamp() + MIN_DEPOSIT_AMOUNT_TIMELOCK,
            newValue: abi.encode(_classId, _minDepositAmount)
        });
        emit NewMinDepositAmountQueued(_classId, _minDepositAmount);
    }

    /**
     * @dev Internal function to queue a new max deposit cap.
     * @param _sd The storage struct.
     * @param _classId The id of the class.
     * @param _maxDepositCap The new max deposit cap.
     */
    function _queueMaxDepositCap(AlephVaultStorageData storage _sd, uint8 _classId, uint256 _maxDepositCap) internal {
        _sd.timelocks[TimelockRegistry.MAX_DEPOSIT_CAP] = TimelockRegistry.Timelock({
            unlockTimestamp: Time.timestamp() + MAX_DEPOSIT_CAP_TIMELOCK,
            newValue: abi.encode(_classId, _maxDepositCap)
        });
        emit NewMaxDepositCapQueued(_classId, _maxDepositCap);
    }

    /**
     * @dev Internal function to set a new min deposit amount.
     * @param _sd The storage struct.
     */
    function _setMinDepositAmount(AlephVaultStorageData storage _sd) internal {
        (uint8 _classId, uint256 _minDepositAmount) =
            abi.decode(TimelockRegistry.setTimelock(_sd, TimelockRegistry.MIN_DEPOSIT_AMOUNT), (uint8, uint256));
        _sd.shareClasses[_classId].minDepositAmount = _minDepositAmount;
        emit NewMinDepositAmountSet(_classId, _minDepositAmount);
    }

    /**
     * @dev Internal function to set a new max deposit cap.
     * @param _sd The storage struct.
     */
    function _setMaxDepositCap(AlephVaultStorageData storage _sd) internal {
        (uint8 _classId, uint256 _maxDepositCap) =
            abi.decode(TimelockRegistry.setTimelock(_sd, TimelockRegistry.MAX_DEPOSIT_CAP), (uint8, uint256));
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
        uint256 _minDepositAmount = _sd.shareClasses[_requestDepositParams.classId].minDepositAmount;
        if (_minDepositAmount > 0 && _requestDepositParams.amount < _minDepositAmount) {
            revert DepositLessThanMinDepositAmount();
        }
        uint256 _maxDepositCap = _sd.shareClasses[_requestDepositParams.classId].maxDepositCap;
        if (
            _maxDepositCap > 0
                && _totalAssetsPerClass(_sd, _requestDepositParams.classId)
                    + _totalAmountToDeposit(_sd, _requestDepositParams.classId) + _requestDepositParams.amount > _maxDepositCap
        ) {
            revert DepositExceedsMaxDepositCap();
        }
        if (_sd.isAuthEnabled) {
            AuthLibrary.verifyDepositRequestAuthSignature(
                _requestDepositParams.classId, _sd.authSigner, _requestDepositParams.authSignature
            );
        }
        uint48 _lastDepositBatchId = _sd.shareClasses[_requestDepositParams.classId].lastDepositBatchId[msg.sender];
        uint48 _currentBatchId = _currentBatch(_sd);
        if (_currentBatchId == 0) {
            revert NoBatchAvailableForDeposit(); // need to wait for the first batch to be available
        }
        if (_lastDepositBatchId >= _currentBatchId) {
            revert OnlyOneRequestPerBatchAllowedForDeposit();
        }

        // update last deposit batch id and register deposit request
        _sd.shareClasses[_requestDepositParams.classId].lastDepositBatchId[msg.sender] = _currentBatchId;
        IAlephVault.DepositRequests storage _depositRequests =
            _sd.shareClasses[_requestDepositParams.classId].depositRequests[_currentBatchId];
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
