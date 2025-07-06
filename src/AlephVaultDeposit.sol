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
abstract contract AlephVaultDeposit is IERC7540Deposit {
    using SafeERC20 for IERC20;
    using Checkpoints for Checkpoints.Trace256;

    function currentBatch() public view virtual returns (uint48);

    function totalAssets() public view virtual returns (uint256);

    function totalShares() public view virtual returns (uint256);

    function sharesOf(address _user) public view virtual returns (uint256);

    function settleDeposit(uint256 _newTotalAssets) external virtual;

    function _getStorage() internal pure virtual returns (AlephVaultStorageData storage sd);

    function pendingTotalAmountToDeposit() public view returns (uint256 _totalAmountToDeposit) {
        AlephVaultStorageData storage _sd = _getStorage();
        uint48 _currentBatchId = currentBatch();
        for (uint48 _batchId = _sd.depositSettleId; _batchId <= _currentBatchId; _batchId++) {
            _totalAmountToDeposit += _sd.batchs[_batchId].totalAmountToDeposit;
        }
    }

    function pendingTotalSharesToDeposit() public view returns (uint256 _totalSharesToDeposit) {
        uint256 _totalAmountToDeposit = pendingTotalAmountToDeposit();
        return ERC4626Math.previewDeposit(_totalAmountToDeposit, totalShares(), totalAssets());
    }    
  
    // Transfers amount from msg.sender into the Vault and submits a Request for asynchronous deposit.
    // This places the Request in Pending state, with a corresponding increase in pendingDepositRequest for the amount assets.
    function requestDeposit(uint256 _amount) external returns (uint48 _batchId) {
        return _requestDeposit(_amount);
    } 

    function pendingDepositRequest(uint48 _batchId) external view returns (uint256 _amount) {
        AlephVaultStorageData storage _sd = _getStorage();
        IAlephVault.BatchData storage _batch = _sd.batchs[_batchId];
        if (_batchId < _sd.depositSettleId) {
            revert BatchAlreadySettledForDeposit();
        }
        return _batch.depositRequest[msg.sender];
    } 

    function _settleDeposit(uint256 _newTotalAssets) internal {
        AlephVaultStorageData storage _sd = _getStorage();
        uint48 _depositSettleId = _sd.depositSettleId;
        uint48 _currentBatchId = currentBatch();
        if (_currentBatchId == _depositSettleId) {
            revert NoDepositsToSettle();
        }
        uint48 _timestamp = Time.timestamp();
        uint256 _amountToSettle;
        for (_depositSettleId; _depositSettleId < _currentBatchId; _depositSettleId++) {
            uint256 _totalAssets = _depositSettleId == _sd.depositSettleId ? _newTotalAssets : totalAssets(); // if the batch is the first batch, use the new total assets, otherwise use the old total assets
            _amountToSettle += _settleDepositForBatch(_sd, _depositSettleId, _timestamp, _totalAssets);
        }
        IERC20(_sd.erc20).safeTransfer(_sd.custodian, _amountToSettle);
        emit SettleDeposit(_sd.depositSettleId, _currentBatchId, _amountToSettle, _newTotalAssets);
        _sd.depositSettleId = _currentBatchId;
    }   

    function _settleDepositForBatch(
        AlephVaultStorageData storage _sd,
        uint48 _batchId,
        uint48 _timestamp,
        uint256 _totalAssets
    ) internal returns (uint256) {
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
        IERC20 _erc20 = IERC20(_sd.erc20);
        uint256 _balanceBefore = _erc20.balanceOf(address(this));
        _erc20.safeTransferFrom(_user, address(this), _amount);
        uint256 _depositedAmount = _erc20.balanceOf(address(this)) - _balanceBefore;
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