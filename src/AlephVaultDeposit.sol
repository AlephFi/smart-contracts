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
import {Checkpoints} from "@aleph-vault/libraries/Checkpoints.sol";
import {AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
abstract contract AlephVaultDeposit is IERC7540Deposit {
    using SafeERC20 for IERC20;
    using Checkpoints for Checkpoints.Trace256;

    /**
     * @notice Returns the current batch ID.
     */
    function currentBatch() public view virtual returns (uint48);

    /**
     * @notice Returns the total assets in the vault.
     */
    function totalAssets() public view virtual returns (uint256);

    /**
     * @notice Returns the total shares issued by the vault.
     */
    function totalShares() public view virtual returns (uint256);

    /// @inheritdoc IERC7540Deposit
    function totalAmountToDeposit() external view returns (uint256 _totalAmountToDeposit) {
        uint48 _currentBatch = currentBatch();
        if (_currentBatch > 0) {
            AlephVaultStorageData storage _sd = _getStorage();
            uint48 _depositSettleId = _sd.depositSettleId;
            for (_depositSettleId; _depositSettleId < _currentBatch; _depositSettleId++) {
                _totalAmountToDeposit += _sd.batches[_depositSettleId].totalAmountToDeposit;
            }
        }
    }

    /// @inheritdoc IERC7540Deposit
    function totalAmountToDepositAt(uint48 _batchId) external view returns (uint256) {
        return _getStorage().batches[_batchId].totalAmountToDeposit;
    }

    /// @inheritdoc IERC7540Deposit
    function usersToDepositAt(uint48 _batchId) external view returns (address[] memory) {
        return _getStorage().batches[_batchId].usersToDeposit;
    }

    /// @inheritdoc IERC7540Deposit
    function depositRequestOf(address _user) external view returns (uint256 _totalAmountToDeposit) {
        uint48 _currentBatch = currentBatch();
        if (_currentBatch > 0) {
            AlephVaultStorageData storage _sd = _getStorage();
            uint48 _depositSettleId = _sd.depositSettleId;
            for (; _depositSettleId < _currentBatch; _depositSettleId++) {
                _totalAmountToDeposit += _sd.batches[_depositSettleId].depositRequest[_user];
            }
        }
    }

    /// @inheritdoc IERC7540Deposit
    function depositRequestOfAt(address _user, uint48 _batchId) external view returns (uint256) {
        return _getStorage().batches[_batchId].depositRequest[_user];
    }

    /**
     * @dev Returns the storage struct for the vault.
     */
    function _getStorage() internal pure virtual returns (AlephVaultStorageData storage sd);

    /// @inheritdoc IERC7540Deposit
    function pendingTotalAmountToDeposit() public view returns (uint256 _totalAmountToDeposit) {
        AlephVaultStorageData storage _sd = _getStorage();
        uint48 _currentBatchId = currentBatch();
        for (uint48 _batchId = _sd.depositSettleId; _batchId <= _currentBatchId; _batchId++) {
            _totalAmountToDeposit += _sd.batches[_batchId].totalAmountToDeposit;
        }
    }

    /// @inheritdoc IERC7540Deposit
    function pendingTotalSharesToDeposit() public view returns (uint256 _totalSharesToDeposit) {
        uint256 _totalAmountToDeposit = pendingTotalAmountToDeposit();
        return ERC4626Math.previewDeposit(_totalAmountToDeposit, totalShares(), totalAssets());
    }

    /// @inheritdoc IERC7540Deposit
    function pendingDepositRequest(uint48 _batchId) external view returns (uint256 _amount) {
        AlephVaultStorageData storage _sd = _getStorage();
        IAlephVault.BatchData storage _batch = _sd.batches[_batchId];
        if (_batchId < _sd.depositSettleId) {
            revert BatchAlreadySettledForDeposit();
        }
        return _batch.depositRequest[msg.sender];
    }

    /// @inheritdoc IERC7540Deposit
    function requestDeposit(uint256 _amount) external virtual returns (uint48 _batchId);

    /// @inheritdoc IERC7540Deposit
    function settleDeposit(uint256 _newTotalAssets) external virtual;

    /**
     * @dev Internal function to handle a deposit request.
     * @param _amount The amount to deposit.
     * @return _batchId The batch ID for the deposit.
     */
    function _requestDeposit(uint256 _amount) internal returns (uint48 _batchId) {
        AlephVaultStorageData storage _sd = _getStorage();
        if (_amount == 0) {
            revert InsufficientDeposit();
        }
        uint48 _lastDepositBatchId = _sd.lastDepositBatchId[msg.sender];
        uint48 _currentBatchId = currentBatch();
        if (_currentBatchId == 0) {
            revert NoBatchAvailableForDeposit(); // need to wait for the first batch to be available
        }
        if (_lastDepositBatchId >= _currentBatchId) {
            revert OnlyOneRequestPerBatchAllowedForDeposit();
        }
        _sd.lastDepositBatchId[msg.sender] = _currentBatchId;
        IAlephVault.BatchData storage _batch = _sd.batches[_currentBatchId];
        _batch.depositRequest[msg.sender] = _amount;
        _batch.totalAmountToDeposit += _amount;
        _batch.usersToDeposit.push(msg.sender);
        emit DepositRequest(msg.sender, _amount, _currentBatchId);

        IERC20 _underlyingToken = IERC20(_sd.underlyingToken);
        uint256 _balanceBefore = _underlyingToken.balanceOf(address(this));
        _underlyingToken.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 _depositedAmount = _underlyingToken.balanceOf(address(this)) - _balanceBefore;
        if (_depositedAmount != _amount) {
            revert DepositRequestFailed();
        }
        return _currentBatchId;
    }
}
