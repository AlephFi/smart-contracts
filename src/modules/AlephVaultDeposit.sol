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
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract AlephVaultDeposit is IERC7540Deposit, AlephVaultBase {
    using SafeERC20 for IERC20;

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
    function queueMinDepositAmount(uint256 _minDepositAmount) external {
        _queueMinDepositAmount(_getStorage(), _minDepositAmount);
    }

    /// @inheritdoc IERC7540Deposit
    function queueMaxDepositCap(uint256 _maxDepositCap) external {
        _queueMaxDepositCap(_getStorage(), _maxDepositCap);
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

    function _queueMinDepositAmount(AlephVaultStorageData storage _sd, uint256 _minDepositAmount) internal {
        _sd.timelocks[TimelockRegistry.MIN_DEPOSIT_AMOUNT] = TimelockRegistry.Timelock({
            unlockTimestamp: Time.timestamp() + MIN_DEPOSIT_AMOUNT_TIMELOCK,
            newValue: abi.encode(_minDepositAmount)
        });
        emit NewMinDepositAmountQueued(_minDepositAmount);
    }

    function _queueMaxDepositCap(AlephVaultStorageData storage _sd, uint256 _maxDepositCap) internal {
        _sd.timelocks[TimelockRegistry.MAX_DEPOSIT_CAP] = TimelockRegistry.Timelock({
            unlockTimestamp: Time.timestamp() + MAX_DEPOSIT_CAP_TIMELOCK,
            newValue: abi.encode(_maxDepositCap)
        });
        emit NewMaxDepositCapQueued(_maxDepositCap);
    }

    function _setMinDepositAmount(AlephVaultStorageData storage _sd) internal {
        uint256 _minDepositAmount =
            abi.decode(TimelockRegistry.setTimelock(_sd, TimelockRegistry.MIN_DEPOSIT_AMOUNT), (uint256));
        _sd.minDepositAmount = _minDepositAmount;
        emit NewMinDepositAmountSet(_minDepositAmount);
    }

    function _setMaxDepositCap(AlephVaultStorageData storage _sd) internal {
        uint256 _maxDepositCap =
            abi.decode(TimelockRegistry.setTimelock(_sd, TimelockRegistry.MAX_DEPOSIT_CAP), (uint256));
        _sd.maxDepositCap = _maxDepositCap;
        emit NewMaxDepositCapSet(_maxDepositCap);
    }

    /**
     * @dev Internal function to handle a deposit request.
     * @param _requestDepositParams The parameters for the deposit request.
     * @return _batchId The batch ID for the deposit.
     */
    function _requestDeposit(AlephVaultStorageData storage _sd, RequestDepositParams calldata _requestDepositParams)
        internal
        returns (uint48 _batchId)
    {
        if (_requestDepositParams.amount == 0) {
            revert InsufficientDeposit();
        }
        uint256 _minDepositAmount = _sd.minDepositAmount;
        if (_minDepositAmount > 0 && _requestDepositParams.amount < _minDepositAmount) {
            revert DepositLessThanMinDepositAmount();
        }
        uint256 _maxDepositCap = _sd.maxDepositCap;
        if (
            _maxDepositCap > 0
                && _totalAssets() + _totalAmountToDeposit() + _requestDepositParams.amount > _maxDepositCap
        ) {
            revert DepositExceedsMaxDepositCap();
        }
        if (_sd.isAuthEnabled) {
            AuthLibrary.verifyAuthSignature(_sd, _requestDepositParams.authSignature);
        }
        uint48 _lastDepositBatchId = _sd.lastDepositBatchId[msg.sender];
        uint48 _currentBatchId = _currentBatch();
        if (_currentBatchId == 0) {
            revert NoBatchAvailableForDeposit(); // need to wait for the first batch to be available
        }
        if (_lastDepositBatchId >= _currentBatchId) {
            revert OnlyOneRequestPerBatchAllowedForDeposit();
        }
        _sd.lastDepositBatchId[msg.sender] = _currentBatchId;
        IAlephVault.BatchData storage _batch = _sd.batches[_currentBatchId];
        _batch.depositRequest[msg.sender] = _requestDepositParams.amount;
        _batch.totalAmountToDeposit += _requestDepositParams.amount;
        _batch.usersToDeposit.push(msg.sender);
        emit DepositRequest(msg.sender, _requestDepositParams.amount, _currentBatchId);

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
