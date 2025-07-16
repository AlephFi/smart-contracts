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

import {IERC7540Deposit} from "./interfaces/IERC7540Deposit.sol";
import {AlephVaultStorage, AlephVaultStorageData} from "./AlephVaultStorage.sol";
import {FeeManager} from "./FeeManager.sol";
import {IAlephVault} from "./interfaces/IAlephVault.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC4626Math} from "./libraries/ERC4626Math.sol";
import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {Checkpoints} from "./libraries/Checkpoints.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
abstract contract AlephVaultDeposit is IERC7540Deposit, FeeManager {
    using SafeERC20 for IERC20;
    using Checkpoints for Checkpoints.Trace256;

    /**
     * @notice Returns the current batch ID.
     */
    function currentBatch() public view virtual returns (uint48);

    /**
     * @notice Returns the total assets in the vault.
     */
    function totalAssets() public view virtual override returns (uint256);

    /**
     * @notice Returns the total shares issued by the vault.
     */
    function totalShares() public view virtual override returns (uint256);

    /**
     * @notice Returns the number of shares owned by a user.
     * @param _user The address of the user.
     */
    function sharesOf(address _user) public view virtual override returns (uint256);

    /// @inheritdoc IERC7540Deposit
    function settleDeposit(uint256 _newTotalAssets) external virtual;

    /**
     * @dev Returns the storage struct for the vault.
     */
    function _getStorage() internal pure virtual override returns (AlephVaultStorageData storage sd);

    /// @inheritdoc IERC7540Deposit
    function pendingTotalAmountToDeposit() public view returns (uint256 _totalAmountToDeposit) {
        AlephVaultStorageData storage _sd = _getStorage();
        uint48 _currentBatchId = currentBatch();
        for (uint48 _batchId = _sd.depositSettleId; _batchId <= _currentBatchId; _batchId++) {
            _totalAmountToDeposit += _sd.batchs[_batchId].totalAmountToDeposit;
        }
    }

    /// @inheritdoc IERC7540Deposit
    function pendingTotalSharesToDeposit() public view returns (uint256 _totalSharesToDeposit) {
        uint256 _totalAmountToDeposit = pendingTotalAmountToDeposit();
        return ERC4626Math.previewDeposit(_totalAmountToDeposit, totalShares(), totalAssets());
    }

    /// @inheritdoc IERC7540Deposit
    function requestDeposit(uint256 _amount) external returns (uint48 _batchId) {
        return _requestDeposit(_amount);
    }

    /// @inheritdoc IERC7540Deposit
    function pendingDepositRequest(uint48 _batchId) external view returns (uint256 _amount) {
        AlephVaultStorageData storage _sd = _getStorage();
        IAlephVault.BatchData storage _batch = _sd.batchs[_batchId];
        if (_batchId < _sd.depositSettleId) {
            revert BatchAlreadySettledForDeposit();
        }
        return _batch.depositRequest[msg.sender];
    }

    /**
     * @dev Internal function to settle all deposits for batches up to the current batch.
     * @param _newTotalAssets The new total assets after settlement.
     */
    function _settleDeposit(uint256 _newTotalAssets) internal {
        AlephVaultStorageData storage _sd = _getStorage();
        uint48 _depositSettleId = _sd.depositSettleId;
        uint48 _currentBatchId = currentBatch();
        if (_currentBatchId == _depositSettleId) {
            revert NoDepositsToSettle();
        }
        uint48 _timestamp = Time.timestamp();
        _accumulateFees(_sd, _newTotalAssets, _currentBatchId, _timestamp);
        uint256 _amountToSettle;
        for (_depositSettleId; _depositSettleId < _currentBatchId; _depositSettleId++) {
            //@perf: repeated storage access in loop
            uint256 _totalAssets = _depositSettleId == _sd.depositSettleId ? _newTotalAssets : totalAssets(); // if the batch is the first batch, use the new total assets, otherwise use the old total assets
            _amountToSettle += _settleDepositForBatch(_sd, _depositSettleId, _timestamp, _totalAssets);
        }
        IERC20(_sd.underlyingToken).safeTransfer(_sd.custodian, _amountToSettle);
        emit SettleDeposit(_sd.depositSettleId, _currentBatchId, _amountToSettle, _newTotalAssets);
        _sd.depositSettleId = _currentBatchId;
    }

    /**
     * @dev Internal function to settle deposits for a specific batch.
     * @param _sd The storage struct.
     * @param _batchId The batch ID to settle.
     * @param _timestamp The timestamp of settlement.
     * @param _totalAssets The total assets at settlement.
     * @return The total amount settled for the batch.
     */
    function _settleDepositForBatch(
        AlephVaultStorageData storage _sd,
        uint48 _batchId,
        uint48 _timestamp,
        uint256 _totalAssets
    ) internal returns (uint256) {
        //@perf: storage -> memory
        IAlephVault.BatchData storage _batch = _sd.batchs[_batchId];
        if (_batch.totalAmountToDeposit == 0) {
            return 0;
        }
        uint256 _totalShares = totalShares();
        uint256 _totalSharesToMint;
        for (uint256 i = 0; i < _batch.usersToDeposit.length; i++) {
            address _user = _batch.usersToDeposit[i];
            uint256 _amount = _batch.depositRequest[_user];
            uint256 _sharesToMintPerUser = ERC4626Math.previewDeposit(_amount, _totalShares, _totalAssets);
            _sd.sharesOf[_user].push(_timestamp, sharesOf(_user) + _sharesToMintPerUser);
            _totalSharesToMint += _sharesToMintPerUser;
        }
        _sd.shares.push(_timestamp, _totalShares + _totalSharesToMint);
        _sd.assets.push(_timestamp, _totalAssets + _batch.totalAmountToDeposit);
        emit SettleDepositBatch(_batchId, _batch.totalAmountToDeposit, _totalSharesToMint, _totalAssets, _totalShares);
        return _batch.totalAmountToDeposit;
    }

    /**
     * @dev Internal function to handle a deposit request.
     * @param _amount The amount to deposit.
     * @return _batchId The batch ID for the deposit.
     */
    function _requestDeposit(uint256 _amount) internal returns (uint48 _batchId) {
        AlephVaultStorageData storage _sd = _getStorage();
        address _user = msg.sender;
        uint48 _lastDepositBatchId = _sd.lastDepositBatchId[_user];
        uint48 _currentBatchId = currentBatch();
        if (_currentBatchId == 0) {
            revert NoBatchAvailableForDeposit(); // need to wait for the first batch to be available
        }
        if (_lastDepositBatchId >= _currentBatchId) {
            revert OnlyOneRequestPerBatchAllowedForDeposit();
        }
        _sd.lastDepositBatchId[_user] = _currentBatchId;
        IERC20 _underlyingToken = IERC20(_sd.underlyingToken);
        uint256 _balanceBefore = _underlyingToken.balanceOf(address(this));
        _underlyingToken.safeTransferFrom(_user, address(this), _amount);
        uint256 _depositedAmount = _underlyingToken.balanceOf(address(this)) - _balanceBefore;
        if (_depositedAmount == 0) {
            revert InsufficientDeposit();
        }
        IAlephVault.BatchData storage _batch = _sd.batchs[_currentBatchId];
        _batch.depositRequest[_user] += _depositedAmount;
        _batch.totalAmountToDeposit += _depositedAmount;
        _batch.usersToDeposit.push(_user);
        emit DepositRequest(_user, _depositedAmount, _currentBatchId);
        return _currentBatchId;
    }
}
