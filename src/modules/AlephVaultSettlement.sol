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
import {IERC7540Settlement} from "@aleph-vault/interfaces/IERC7540Settlement.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {ModulesLibrary} from "@aleph-vault/libraries/ModulesLibrary.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {AlephVaultBase} from "@aleph-vault/AlephVaultBase.sol";
import {AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract AlephVaultSettlement is IERC7540Settlement, AlephVaultBase {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(uint48 _batchDuration) AlephVaultBase(_batchDuration) {}

    /// @inheritdoc IERC7540Settlement
    function settleDeposit(uint8 _classId, uint256[] calldata _newTotalAssets) external {
        _settleDeposit(_getStorage(), _classId, _newTotalAssets);
    }

    /// @inheritdoc IERC7540Settlement
    function settleRedeem(uint8 _classId, uint256[] calldata _newTotalAssets) external {
        _settleRedeem(_getStorage(), _classId, _newTotalAssets);
    }

    /**
     * @dev Internal function to settle all deposits for batches up to the current batch.
     * @param _classId The ID of the share class to settle deposits for.
     * @param _newTotalAssets The new total assets after settlement for each series.
     */
    function _settleDeposit(AlephVaultStorageData storage _sd, uint8 _classId, uint256[] calldata _newTotalAssets)
        internal
    {
        IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_classId];
        uint48 _depositSettleId = _shareClass.depositSettleId;
        uint48 _currentBatchId = _currentBatch();
        if (_currentBatchId == _depositSettleId) {
            revert NoDepositsToSettle();
        }
        uint8 _shareSeriesId = _shareClass.shareSeriesId;
        uint8 _lastConsolidatedSeriesId = _shareClass.lastConsolidatedSeriesId;
        if (_newTotalAssets.length != _shareSeriesId - _lastConsolidatedSeriesId + 1) {
            revert InvalidNewTotalAssets();
        }
        _accumulateFees(
            _shareClass, _classId, _shareSeriesId, _lastConsolidatedSeriesId, _currentBatchId, _newTotalAssets
        );
        uint8 _settlementSeriesId = _getSettlementSeriesId(_shareClass, _classId);
        uint256 _amountToSettle;
        uint256 _totalAssets = _shareClass.shareSeries[_settlementSeriesId].totalAssets;
        uint256 _totalShares = _shareClass.shareSeries[_settlementSeriesId].totalShares;
        for (uint48 _id = _depositSettleId; _id < _currentBatchId; _id++) {
            (uint256 _amount, uint256 _sharesToMint) = _settleDepositForBatch(
                _shareClass,
                SettleDepositBatchParams({
                    seriesId: _settlementSeriesId,
                    batchId: _id,
                    totalAssets: _totalAssets,
                    totalShares: _totalShares
                })
            );
            _amountToSettle += _amount;
            _totalAssets += _amount;
            _totalShares += _sharesToMint;
        }
        _shareClass.depositSettleId = _currentBatchId;
        _shareClass.shareSeries[_settlementSeriesId].totalAssets = _totalAssets;
        _shareClass.shareSeries[_settlementSeriesId].totalShares = _totalShares;
        if (_amountToSettle > 0) {
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
     * @param _shareClass The share class to settle.
     * @param _settleDepositBatchParams The parameters for the settlement.
     * @return The total amount settled for the batch.
     */
    function _settleDepositForBatch(
        IAlephVault.ShareClass storage _shareClass,
        SettleDepositBatchParams memory _settleDepositBatchParams
    ) internal returns (uint256, uint256) {
        IAlephVault.DepositRequests storage _depositRequests =
            _shareClass.depositRequests[_settleDepositBatchParams.batchId];
        uint256 _totalAmountToDeposit = _depositRequests.totalAmountToDeposit;
        if (_totalAmountToDeposit == 0) {
            return (0, 0);
        }
        uint256 _totalSharesToMint;
        uint256 _len = _depositRequests.usersToDeposit.length();
        for (uint256 _i; _i < _len; _i++) {
            address _user = _depositRequests.usersToDeposit.at(_i);
            uint256 _amount = _depositRequests.depositRequest[_user];
            uint256 _sharesToMintPerUser = ERC4626Math.previewDeposit(
                _amount, _settleDepositBatchParams.totalShares, _settleDepositBatchParams.totalAssets
            );
            _totalSharesToMint += _sharesToMintPerUser;
            _shareClass.shareSeries[_settleDepositBatchParams.seriesId].sharesOf[_user] += _sharesToMintPerUser;
            emit IERC7540Settlement.DepositRequestSettled(_user, _amount, _sharesToMintPerUser);
        }
        emit SettleDepositBatch(
            _settleDepositBatchParams.batchId,
            _totalAmountToDeposit,
            _totalSharesToMint,
            _settleDepositBatchParams.totalAssets,
            _settleDepositBatchParams.totalShares,
            _getPricePerShare(
                _settleDepositBatchParams.totalAssets + _totalAmountToDeposit,
                _settleDepositBatchParams.totalShares + _totalSharesToMint
            )
        );
        return (_totalAmountToDeposit, _totalSharesToMint);
    }

    /**
     * @dev Internal function to settle all redeems for batches up to the current batch.
     * @param _classId The ID of the share class to settle redeems for.
     * @param _newTotalAssets The new total assets after settlement.
     */
    function _settleRedeem(AlephVaultStorageData storage _sd, uint8 _classId, uint256[] calldata _newTotalAssets)
        internal
    {
        IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_classId];
        uint48 _redeemSettleId = _shareClass.redeemSettleId;
        uint48 _currentBatchId = _currentBatch();
        if (_currentBatchId == _redeemSettleId) {
            revert NoRedeemsToSettle();
        }
        uint8 _shareSeriesId = _shareClass.shareSeriesId;
        uint8 _lastConsolidatedSeriesId = _shareClass.lastConsolidatedSeriesId;
        if (_newTotalAssets.length != _shareSeriesId - _lastConsolidatedSeriesId + 1) {
            revert InvalidNewTotalAssets();
        }
        _accumulateFees(
            _shareClass, _classId, _shareSeriesId, _lastConsolidatedSeriesId, _currentBatchId, _newTotalAssets
        );
        address _underlyingToken = _sd.underlyingToken;
        for (uint48 _id = _redeemSettleId; _id < _currentBatchId; _id++) {
            _settleRedeemForBatch(
                _shareClass,
                SettleRedeemBatchParams({
                    batchId: _id,
                    classId: _classId,
                    underlyingToken: _underlyingToken,
                    newTotalAssets: _newTotalAssets
                })
            );
        }
        _shareClass.redeemSettleId = _currentBatchId;
        emit SettleRedeem(_redeemSettleId, _currentBatchId);
    }

    /**
     * @dev Internal function to settle redeems for a specific batch.
     * @param _shareClass The share class to settle.
     * @param _settleRedeemBatchParams The parameters for the settlement.
     */
    function _settleRedeemForBatch(
        IAlephVault.ShareClass storage _shareClass,
        SettleRedeemBatchParams memory _settleRedeemBatchParams
    ) internal {
        IAlephVault.RedeemRequests storage _redeemRequests =
            _shareClass.redeemRequests[_settleRedeemBatchParams.batchId];
        uint256 _len = _redeemRequests.usersToRedeem.length();
        for (uint256 _i; _i < _len; _i++) {
            address _user = _redeemRequests.usersToRedeem.at(_i);
            uint256 _shares = _redeemRequests.redeemRequest[_user];
            uint8 _seriesId = _redeemRequests.redeemSeries[_user];
            uint256 _amount = _settleRedeemForUser(
                _shareClass,
                _user,
                _shares,
                _settleRedeemBatchParams.newTotalAssets,
                _settleRedeemBatchParams.classId,
                _seriesId
            );
            IERC20(_settleRedeemBatchParams.underlyingToken).safeTransfer(_user, _amount);
            emit SettleRedeemBatch(_settleRedeemBatchParams.batchId, _user, _amount);
        }
    }

    function _settleRedeemForUser(
        IAlephVault.ShareClass storage _shareClass,
        address _user,
        uint256 _shares,
        uint256[] memory _newTotalAssets,
        uint8 _classId,
        uint8 _seriesId
    ) internal returns (uint256) {
        IAlephVault.ShareSeries storage _shareSeries = _shareClass.shareSeries[_seriesId];
        uint256 _amount = ERC4626Math.previewRedeem(_shares, _shareSeries.totalAssets, _shareSeries.totalShares);
        if (_seriesId > 0 && _seriesId <= _shareClass.lastConsolidatedSeriesId) {
            IAlephVault.ShareSeries storage _leadSeries = _shareClass.shareSeries[0];
            uint256 _sharesInLeadSeries =
                ERC4626Math.previewWithdraw(_amount, _leadSeries.totalShares, _leadSeries.totalAssets);
            _leadSeries.totalAssets -= _amount;
            _leadSeries.totalShares -= _sharesInLeadSeries;
            _leadSeries.sharesOf[_user] -= _sharesInLeadSeries;
        } else {
            _shareSeries.totalAssets -= _amount;
            _shareSeries.totalShares -= _shares;
            _shareSeries.sharesOf[_user] -= _shares;
        }
        return _amount;
    }

    function _getSettlementSeriesId(IAlephVault.ShareClass storage _shareClass, uint8 _classId)
        internal
        returns (uint8 _seriesId)
    {
        if (_shareClass.performanceFee > 0) {
            if (_leadHighWaterMark(_classId) > _leadPricePerShare(_classId)) {
                _seriesId = _createNewSeries(_shareClass);
            } else if (_shareClass.shareSeriesId > _shareClass.lastConsolidatedSeriesId) {
                _consolidateSeries(_shareClass, _shareClass.shareSeriesId, _shareClass.lastConsolidatedSeriesId);
            }
        }
    }

    function _createNewSeries(IAlephVault.ShareClass storage _shareClass) internal returns (uint8 _seriesId) {
        _seriesId = _shareClass.shareSeriesId++;
        _shareClass.shareSeries[_seriesId].highWaterMark = PRICE_DENOMINATOR;
    }

    function _consolidateSeries(
        IAlephVault.ShareClass storage _shareClass,
        uint8 _shareSeriesId,
        uint8 _lastConsolidatedSeriesId
    ) internal {
        uint256 _totalAmountToTransfer;
        uint256 _totalSharesToTransfer;
        for (uint8 _seriesId = _lastConsolidatedSeriesId + 1; _seriesId <= _shareSeriesId; _seriesId++) {
            IAlephVault.ShareSeries storage _shareSeries = _shareClass.shareSeries[_seriesId];
            (uint256 _amountToTransfer, uint256 _sharesToTransfer) = _transferUserShares(_shareClass, _shareSeries);
            _totalAmountToTransfer += _amountToTransfer;
            _totalSharesToTransfer += _sharesToTransfer;
        }
        _shareClass.lastConsolidatedSeriesId = _shareSeriesId;
        _shareClass.shareSeries[0].totalAssets += _totalAmountToTransfer;
        _shareClass.shareSeries[0].totalShares += _totalSharesToTransfer;
    }

    function _transferUserShares(
        IAlephVault.ShareClass storage _shareClass,
        IAlephVault.ShareSeries storage _shareSeries
    ) internal returns (uint256 _totalAmountToTransfer, uint256 _totalSharesToTransfer) {
        uint256 _len = _shareSeries.users.length();
        for (uint256 _i; _i < _len; _i++) {
            address _user = _shareSeries.users.at(_i);
            uint256 _shares = _shareSeries.sharesOf[_user];
            uint256 _amountToTransfer =
                ERC4626Math.previewRedeem(_shares, _shareSeries.totalAssets, _shareSeries.totalShares);
            uint256 _sharesToTransfer = ERC4626Math.previewDeposit(
                _amountToTransfer, _shareClass.shareSeries[0].totalShares, _shareClass.shareSeries[0].totalAssets
            );
            _totalAmountToTransfer += _amountToTransfer;
            _totalSharesToTransfer += _sharesToTransfer;
            if (!_shareClass.shareSeries[0].users.contains(_user)) {
                _shareClass.shareSeries[0].users.add(_user);
            }
        }
    }

    function _accumulateFees(
        IAlephVault.ShareClass storage _shareClass,
        uint8 _classId,
        uint8 _shareSeriesId,
        uint8 _lastConsolidatedSeriesId,
        uint48 _currentBatchId,
        uint256[] calldata _newTotalAssets
    ) internal {
        uint48 _lastFeePaidId = _shareClass.lastFeePaidId;
        if (_currentBatchId > _lastFeePaidId) {
            _shareClass.shareSeries[0].totalAssets = _newTotalAssets[0];
            _shareClass.shareSeries[0].totalShares += _getAccumulatedFees(
                _newTotalAssets[0], _shareClass.shareSeries[0].totalShares, _currentBatchId, _lastFeePaidId, _classId, 0
            );
            for (uint8 _seriesId = _lastConsolidatedSeriesId + 1; _seriesId <= _shareSeriesId; _seriesId++) {
                _shareClass.shareSeries[_seriesId].totalAssets = _newTotalAssets[_seriesId];
                _shareClass.shareSeries[_seriesId].totalShares += _getAccumulatedFees(
                    _newTotalAssets[_seriesId],
                    _shareClass.shareSeries[_seriesId].totalShares,
                    _currentBatchId,
                    _lastFeePaidId,
                    _classId,
                    _seriesId
                );
            }
            _shareClass.lastFeePaidId = _currentBatchId;
        }
    }

    function _getAccumulatedFees(
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint48 _currentBatchId,
        uint48 _lastFeePaidId,
        uint8 _classId,
        uint8 _seriesId
    ) internal returns (uint256) {
        if (_newTotalAssets == 0) {
            return 0;
        }
        (bool _success, bytes memory _data) = _getStorage().moduleImplementations[ModulesLibrary.FEE_MANAGER]
            .delegatecall(
            abi.encodeCall(
                IFeeManager.accumulateFees,
                (_newTotalAssets, _totalShares, _currentBatchId, _lastFeePaidId, _classId, _seriesId)
            )
        );
        if (!_success) {
            revert DelegateCallFailed(_data);
        }
        return abi.decode(_data, (uint256));
    }
}
