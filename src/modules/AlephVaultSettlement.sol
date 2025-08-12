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
import {IERC7540Settlement} from "@aleph-vault/interfaces/IERC7540Settlement.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {ModulesLibrary} from "@aleph-vault/libraries/ModulesLibrary.sol";
import {Checkpoints} from "@aleph-vault/libraries/Checkpoints.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {AlephVaultBase} from "@aleph-vault/AlephVaultBase.sol";
import {AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract AlephVaultSettlement is IERC7540Settlement, AlephVaultBase {
    using SafeERC20 for IERC20;
    using Checkpoints for Checkpoints.Trace256;

    constructor(uint48 _batchDuration) AlephVaultBase(_batchDuration) {}

    /// @inheritdoc IERC7540Settlement
    function settleDeposit(uint256 _newTotalAssets) external {
        _settleDeposit(_getStorage(), _newTotalAssets);
    }

    /// @inheritdoc IERC7540Settlement
    function settleRedeem(uint256 _newTotalAssets) external {
        _settleRedeem(_getStorage(), _newTotalAssets);
    }

    /**
     * @dev Internal function to settle all deposits for batches up to the current batch.
     * @param _newTotalAssets The new total assets after settlement.
     */
    function _settleDeposit(AlephVaultStorageData storage _sd, uint256 _newTotalAssets) internal {
        uint48 _depositSettleId = _sd.depositSettleId;
        uint48 _currentBatchId = _currentBatch();
        if (_currentBatchId == _depositSettleId) {
            revert NoDepositsToSettle();
        }
        uint48 _timestamp = Time.timestamp();
        uint48 _lastFeePaidId = _sd.lastFeePaidId;
        uint256 _totalShares = _totalShares();
        if (_currentBatchId > _lastFeePaidId) {
            _totalShares += _getAccumulatedFees(_sd, _newTotalAssets, _currentBatchId, _lastFeePaidId, _timestamp);
        }
        uint256 _amountToSettle;
        uint256 _totalAssets = _newTotalAssets;
        for (uint48 _id = _depositSettleId; _id < _currentBatchId; _id++) {
            (uint256 _amount, uint256 _sharesToMint) =
                _settleDepositForBatch(_sd, _id, _timestamp, _totalAssets, _totalShares);
            _amountToSettle += _amount;
            _totalAssets += _amount;
            _totalShares += _sharesToMint;
        }
        _sd.depositSettleId = _currentBatchId;
        _sd.shares.push(_timestamp, _totalShares);
        _sd.assets.push(_timestamp, _totalAssets);
        if (_amountToSettle > 0) {
            if (_highWaterMark() == 0) {
                _initializeHighWaterMark(_sd, _totalAssets, _totalShares, _timestamp);
            }
            IERC20(_sd.underlyingToken).safeTransfer(_sd.custodian, _amountToSettle);
        }
        emit SettleDeposit(
            _depositSettleId,
            _currentBatchId,
            _amountToSettle,
            _totalAssets,
            _totalShares,
            _getPricePerShare(_totalAssets, _totalShares)
        );
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
            _totalSharesToMint += _sharesToMintPerUser;
            _sd.sharesOf[_user].push(_timestamp, _sharesOf(_user) + _sharesToMintPerUser);
            emit IERC7540Settlement.DepositRequestSettled(_user, _amount, _sharesToMintPerUser);
        }
        emit SettleDepositBatch(
            _batchId,
            _batch.totalAmountToDeposit,
            _totalSharesToMint,
            _totalAssets,
            _totalShares,
            _getPricePerShare(_totalAssets + _batch.totalAmountToDeposit, _totalShares + _totalSharesToMint)
        );
        return (_batch.totalAmountToDeposit, _totalSharesToMint);
    }

    /**
     * @dev Internal function to settle all redeems for batches up to the current batch.
     * @param _newTotalAssets The new total assets after settlement.
     */
    function _settleRedeem(AlephVaultStorageData storage _sd, uint256 _newTotalAssets) internal {
        uint48 _redeemSettleId = _sd.redeemSettleId;
        uint48 _currentBatchId = _currentBatch();
        if (_currentBatchId == _redeemSettleId) {
            revert NoRedeemsToSettle();
        }
        uint48 _timestamp = Time.timestamp();
        uint48 _lastFeePaidId = _sd.lastFeePaidId;
        uint256 _totalShares = _totalShares();
        if (_currentBatchId > _lastFeePaidId) {
            _totalShares += _getAccumulatedFees(_sd, _newTotalAssets, _currentBatchId, _lastFeePaidId, _timestamp);
        }
        uint256 _sharesToSettle;
        uint256 _totalAssets = _newTotalAssets;
        for (uint48 _id = _redeemSettleId; _id < _currentBatchId; _id++) {
            (uint256 _assets, uint256 _sharesToRedeem) = _settleRedeemForBatch(_sd, _id, _totalAssets, _totalShares);
            _sharesToSettle += _sharesToRedeem;
            _totalAssets -= _assets;
            _totalShares -= _sharesToRedeem;
        }
        _sd.redeemSettleId = _currentBatchId;
        _sd.shares.push(_timestamp, _totalShares);
        _sd.assets.push(_timestamp, _totalAssets);
        emit SettleRedeem(
            _redeemSettleId,
            _currentBatchId,
            _sharesToSettle,
            _totalAssets,
            _totalShares,
            _getPricePerShare(_totalAssets, _totalShares)
        );
    }

    /**
     * @dev Internal function to settle redeems for a specific batch.
     * @param _sd The storage struct.
     * @param _batchId The batch ID to settle.
     * @param _totalAssets The total assets at settlement.
     * @return _totalSharesToRedeem The total shares settled for the batch.
     */
    function _settleRedeemForBatch(
        AlephVaultStorageData storage _sd,
        uint48 _batchId,
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
            emit IERC7540Settlement.RedeemRequestSettled(_user, _sharesToBurnPerUser, _assets);
        }
        emit SettleRedeemBatch(
            _batchId,
            _totalAssetsToRedeem,
            _batch.totalSharesToRedeem,
            _totalAssets,
            _totalShares,
            _getPricePerShare(_totalAssets - _totalAssetsToRedeem, _totalShares - _batch.totalSharesToRedeem)
        );
        return (_totalAssetsToRedeem, _batch.totalSharesToRedeem);
    }

    function _getAccumulatedFees(
        AlephVaultStorageData storage _sd,
        uint256 _newTotalAssets,
        uint48 _currentBatchId,
        uint48 _lastFeePaidId,
        uint48 _timestamp
    ) internal returns (uint256) {
        (bool _success, bytes memory _data) = _sd.moduleImplementations[ModulesLibrary.FEE_MANAGER].delegatecall(
            abi.encodeCall(IFeeManager.accumulateFees, (_newTotalAssets, _currentBatchId, _lastFeePaidId, _timestamp))
        );
        if (!_success) {
            revert();
        }
        return abi.decode(_data, (uint256));
    }

    function _initializeHighWaterMark(
        AlephVaultStorageData storage _sd,
        uint256 _totalAssets,
        uint256 _totalShares,
        uint48 _timestamp
    ) internal {
        _sd.moduleImplementations[ModulesLibrary.FEE_MANAGER].delegatecall(
            abi.encodeCall(IFeeManager.initializeHighWaterMark, (_totalAssets, _totalShares, _timestamp))
        );
    }
}
