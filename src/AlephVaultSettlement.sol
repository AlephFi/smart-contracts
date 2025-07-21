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

import {Checkpoints} from "./libraries/Checkpoints.sol";
import {ERC4626Math} from "./libraries/ERC4626Math.sol";
import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {FeeManager} from "./FeeManager.sol";
import {AlephVaultStorageData} from "./AlephVaultStorage.sol";
import {IERC7540Deposit} from "./interfaces/IERC7540Deposit.sol";
import {IERC7540Redeem} from "./interfaces/IERC7540Redeem.sol";
import {IAlephVault} from "./interfaces/IAlephVault.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
abstract contract AlephVaultSettlement is FeeManager {
    using SafeERC20 for IERC20;
    using Checkpoints for Checkpoints.Trace256;

    /**
     * @notice Returns the current batch ID.
     */
    function currentBatch() public view virtual returns (uint48);

    /**
     * @dev Internal function to settle all deposits for batches up to the current batch.
     * @param _newTotalAssets The new total assets after settlement.
     */
    function _settleDeposit(AlephVaultStorageData storage _sd, uint256 _newTotalAssets) internal {
        uint48 _depositSettleId = _sd.depositSettleId;
        uint48 _currentBatchId = currentBatch();
        if (_currentBatchId == _depositSettleId) {
            revert IERC7540Deposit.NoDepositsToSettle();
        }
        uint48 _timestamp = Time.timestamp();
        uint48 _lastFeePaidId = _sd.lastFeePaidId;
        if (_currentBatchId > _lastFeePaidId) {
            _accumulateFees(_sd, _newTotalAssets, _currentBatchId, _lastFeePaidId, _timestamp);
        }
        uint256 _amountToSettle;
        uint256 _totalAssets = _newTotalAssets;
        uint256 _totalShares = totalShares();
        for (_depositSettleId; _depositSettleId < _currentBatchId; _depositSettleId++) {
            (uint256 _amount, uint256 _sharesToMint) =
                _settleDepositForBatch(_sd, _depositSettleId, _timestamp, _totalAssets, _totalShares);
            _amountToSettle += _amount;
            _totalAssets += _amount;
            _totalShares += _sharesToMint;
        }
        _sd.shares.push(_timestamp, _totalShares);
        _sd.assets.push(_timestamp, _totalAssets);
        if (_sd.highWaterMark == 0) {
            _initializeHighWaterMark(_sd);
        }
        IERC20(_sd.underlyingToken).safeTransfer(_sd.custodian, _amountToSettle);
        emit IERC7540Deposit.SettleDeposit(_sd.depositSettleId, _currentBatchId, _amountToSettle, _newTotalAssets);
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
        uint256 _totalAssets,
        uint256 _totalShares
    ) internal returns (uint256, uint256) {
        IAlephVault.BatchData storage _batch = _sd.batches[_batchId];
        if (_batch.totalAmountToDeposit == 0) {
            return (0, 0);
        }
        uint256 _totalSharesToMint;
        for (uint256 i = 0; i < _batch.usersToDeposit.length; i++) {
            address _user = _batch.usersToDeposit[i];
            uint256 _amount = _batch.depositRequest[_user];
            uint256 _sharesToMintPerUser = ERC4626Math.previewDeposit(_amount, _totalShares, _totalAssets);
            _sd.sharesOf[_user].push(_timestamp, sharesOf(_user) + _sharesToMintPerUser);
            _totalSharesToMint += _sharesToMintPerUser;
        }
        emit IERC7540Deposit.SettleDepositBatch(
            _batchId, _batch.totalAmountToDeposit, _totalSharesToMint, _totalAssets, _totalShares
        );
        return (_batch.totalAmountToDeposit, _totalSharesToMint);
    }

    /**
     * @dev Internal function to settle all redeems for batches up to the current batch.
     * @param _newTotalAssets The new total assets after settlement.
     */
    function _settleRedeem(AlephVaultStorageData storage _sd, uint256 _newTotalAssets) internal {
        uint48 _redeemSettleId = _sd.redeemSettleId;
        uint48 _currentBatchId = currentBatch();
        if (_currentBatchId == _redeemSettleId) {
            revert IERC7540Redeem.NoRedeemsToSettle();
        }
        uint48 _timestamp = Time.timestamp();
        uint48 _lastFeePaidId = _sd.lastFeePaidId;
        if (_currentBatchId > _lastFeePaidId) {
            _accumulateFees(_sd, _newTotalAssets, _currentBatchId, _lastFeePaidId, _timestamp);
        }
        uint256 _sharesToSettle;
        uint256 _totalAssets = _newTotalAssets;
        uint256 _totalShares = totalShares();
        for (_redeemSettleId; _redeemSettleId < _currentBatchId; _redeemSettleId++) {
            (uint256 _assets, uint256 _sharesToRedeem) =
                _settleRedeemForBatch(_sd, _redeemSettleId, _timestamp, _totalAssets, _totalShares);
            _sharesToSettle += _sharesToRedeem;
            _totalAssets -= _assets;
            _totalShares -= _sharesToRedeem;
        }
        _sd.shares.push(_timestamp, _totalShares);
        _sd.assets.push(_timestamp, _totalAssets);
        emit IERC7540Redeem.SettleRedeem(_sd.redeemSettleId, _currentBatchId, _sharesToSettle, _newTotalAssets);
        _sd.redeemSettleId = _currentBatchId;
    }

    /**
     * @dev Internal function to settle redeems for a specific batch.
     * @param _sd The storage struct.
     * @param _batchId The batch ID to settle.
     * @param _timestamp The timestamp of settlement.
     * @param _totalAssets The total assets at settlement.
     * @return _totalSharesToRedeem The total shares settled for the batch.
     */
    function _settleRedeemForBatch(
        AlephVaultStorageData storage _sd,
        uint48 _batchId,
        uint48 _timestamp,
        uint256 _totalAssets,
        uint256 _totalShares
    ) internal returns (uint256, uint256) {
        IAlephVault.BatchData storage _batch = _sd.batches[_batchId];
        if (_batch.totalSharesToRedeem == 0) {
            return (0, 0);
        }
        uint256 _totalAssetsToRedeem;
        IERC20 _underlyingToken = IERC20(_sd.underlyingToken);
        for (uint256 i = 0; i < _batch.usersToRedeem.length; i++) {
            address _user = _batch.usersToRedeem[i];
            uint256 _sharesToBurnPerUser = _batch.redeemRequest[_user];
            uint256 _assets = ERC4626Math.previewRedeem(_sharesToBurnPerUser, _totalAssets, _totalShares);
            _totalAssetsToRedeem += _assets;
            _underlyingToken.safeTransfer(_user, _assets);
        }
        emit IERC7540Redeem.SettleRedeemBatch(
            _batchId, _totalAssetsToRedeem, _batch.totalSharesToRedeem, _totalAssets, _totalShares
        );
        return (_totalAssetsToRedeem, _batch.totalSharesToRedeem);
    }
}
