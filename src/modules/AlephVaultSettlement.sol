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
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
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
    using Math for uint256;
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
     * @param _sd The storage struct.
     * @param _classId The ID of the share class to settle deposits for.
     * @param _newTotalAssets The new total assets after settlement for each series.
     */
    function _settleDeposit(AlephVaultStorageData storage _sd, uint8 _classId, uint256[] calldata _newTotalAssets)
        internal
    {
        IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_classId];
        uint48 _depositSettleId = _shareClass.depositSettleId;
        uint48 _currentBatchId = _currentBatch(_sd);
        if (_currentBatchId == _depositSettleId) {
            revert NoDepositsToSettle();
        }
        uint8 _shareSeriesId = _shareClass.shareSeriesId;
        uint8 _lastConsolidatedSeriesId = _shareClass.lastConsolidatedSeriesId;
        if (_newTotalAssets.length != _shareSeriesId - _lastConsolidatedSeriesId + 1) {
            revert InvalidNewTotalAssets();
        }
        _accumulateFees(_shareClass, _classId, _lastConsolidatedSeriesId, _currentBatchId, _newTotalAssets);
        uint8 _settlementSeriesId = _getSettlementSeriesId(_sd, _classId, _currentBatchId);
        SettleDepositParams memory _settleDepositParams = SettleDepositParams({
            classId: _classId,
            seriesId: _settlementSeriesId,
            batchId: _depositSettleId,
            totalAssets: _shareClass.shareSeries[_settlementSeriesId].totalAssets,
            totalShares: _shareClass.shareSeries[_settlementSeriesId].totalShares
        });
        uint256 _amountToSettle;
        for (
            _settleDepositParams.batchId; _settleDepositParams.batchId < _currentBatchId; _settleDepositParams.batchId++
        ) {
            (uint256 _amount, uint256 _sharesToMint) = _settleDepositForBatch(_shareClass, _settleDepositParams);
            _amountToSettle += _amount;
            _settleDepositParams.totalAssets += _amount;
            _settleDepositParams.totalShares += _sharesToMint;
        }
        _shareClass.depositSettleId = _currentBatchId;
        _shareClass.shareSeries[_settleDepositParams.seriesId].totalAssets = _settleDepositParams.totalAssets;
        _shareClass.shareSeries[_settleDepositParams.seriesId].totalShares = _settleDepositParams.totalShares;
        if (_amountToSettle > 0) {
            IERC20(_sd.underlyingToken).safeTransfer(_sd.custodian, _amountToSettle);
        }
        emit SettleDeposit(
            _depositSettleId,
            _currentBatchId,
            _classId,
            _settleDepositParams.seriesId,
            _amountToSettle,
            _settleDepositParams.totalAssets,
            _settleDepositParams.totalShares
        );
    }

    /**
     * @dev Internal function to settle deposits for a specific batch.
     * @param _shareClass The share class to settle.
     * @param _settleDepositParams The parameters for the settlement.
     * @return The total amount settled for the batch.
     * @return The total shares minted for the batch.
     */
    function _settleDepositForBatch(
        IAlephVault.ShareClass storage _shareClass,
        SettleDepositParams memory _settleDepositParams
    ) internal returns (uint256, uint256) {
        IAlephVault.DepositRequests storage _depositRequests = _shareClass.depositRequests[_settleDepositParams.batchId];
        uint256 _totalAmountToDeposit = _depositRequests.totalAmountToDeposit;
        if (_totalAmountToDeposit == 0) {
            return (0, 0);
        }
        uint256 _totalSharesToMint;
        uint256 _len = _depositRequests.usersToDeposit.length;
        for (uint256 _i; _i < _len; _i++) {
            DepositRequestParams memory _depositRequestParams;
            _depositRequestParams.user = _depositRequests.usersToDeposit[_i];
            _depositRequestParams.amount = _depositRequests.depositRequest[_depositRequestParams.user];
            _depositRequestParams.sharesToMint = ERC4626Math.previewDeposit(
                _depositRequestParams.amount, _settleDepositParams.totalShares, _settleDepositParams.totalAssets
            );
            _totalSharesToMint += _depositRequestParams.sharesToMint;
            _shareClass.shareSeries[_settleDepositParams.seriesId].sharesOf[_depositRequestParams.user] +=
                _depositRequestParams.sharesToMint;
            emit IERC7540Settlement.DepositRequestSettled(
                _depositRequestParams.user,
                _settleDepositParams.classId,
                _settleDepositParams.seriesId,
                _depositRequestParams.amount,
                _depositRequestParams.sharesToMint,
                _settleDepositParams.batchId
            );
        }
        emit SettleDepositBatch(
            _settleDepositParams.batchId,
            _settleDepositParams.classId,
            _settleDepositParams.seriesId,
            _totalAmountToDeposit,
            _totalSharesToMint
        );
        return (_totalAmountToDeposit, _totalSharesToMint);
    }

    /**
     * @dev Internal function to settle all redeems for batches up to the current batch.
     * @param _sd The storage struct.
     * @param _classId The ID of the share class to settle redeems for.
     * @param _newTotalAssets The new total assets after settlement.
     */
    function _settleRedeem(AlephVaultStorageData storage _sd, uint8 _classId, uint256[] calldata _newTotalAssets)
        internal
    {
        IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_classId];
        uint48 _redeemSettleId = _shareClass.redeemSettleId;
        uint48 _currentBatchId = _currentBatch(_sd);
        if (_currentBatchId == _redeemSettleId) {
            revert NoRedeemsToSettle();
        }
        uint8 _shareSeriesId = _shareClass.shareSeriesId;
        uint8 _lastConsolidatedSeriesId = _shareClass.lastConsolidatedSeriesId;
        if (_newTotalAssets.length != _shareSeriesId - _lastConsolidatedSeriesId + 1) {
            revert InvalidNewTotalAssets();
        }
        _accumulateFees(_shareClass, _classId, _lastConsolidatedSeriesId, _currentBatchId, _newTotalAssets);
        address _underlyingToken = _sd.underlyingToken;
        for (uint48 _id = _redeemSettleId; _id < _currentBatchId; _id++) {
            _settleRedeemForBatch(
                _sd,
                SettleRedeemBatchParams({
                    batchId: _id,
                    classId: _classId,
                    underlyingToken: _underlyingToken,
                    newTotalAssets: _newTotalAssets
                })
            );
        }
        _shareClass.redeemSettleId = _currentBatchId;
        emit SettleRedeem(_redeemSettleId, _currentBatchId, _classId);
    }

    /**
     * @dev Internal function to settle redeems for a specific batch.
     * @param _sd The storage struct.
     * @param _settleRedeemBatchParams The parameters for the settlement.
     */
    function _settleRedeemForBatch(
        AlephVaultStorageData storage _sd,
        SettleRedeemBatchParams memory _settleRedeemBatchParams
    ) internal {
        IAlephVault.RedeemRequests storage _redeemRequests =
            _sd.shareClasses[_settleRedeemBatchParams.classId].redeemRequests[_settleRedeemBatchParams.batchId];
        uint256 _totalAmountToRedeem;
        uint256 _len = _redeemRequests.usersToRedeem.length;
        for (uint256 _i; _i < _len; _i++) {
            address _user = _redeemRequests.usersToRedeem[_i];
            uint256 _amount = _redeemRequests.redeemRequest[_user].mulDiv(
                _assetsPerClassOf(_sd, _settleRedeemBatchParams.classId, _user), PRICE_DENOMINATOR, Math.Rounding.Floor
            );
            _settleRedeemForUser(
                _sd,
                _settleRedeemBatchParams.batchId,
                _user,
                _amount,
                _settleRedeemBatchParams.newTotalAssets,
                _settleRedeemBatchParams.classId
            );
            _totalAmountToRedeem += _amount;
            IERC20(_settleRedeemBatchParams.underlyingToken).safeTransfer(_user, _amount);
            emit RedeemRequestSettled(
                _settleRedeemBatchParams.batchId, _user, _settleRedeemBatchParams.classId, _amount
            );
        }
        emit SettleRedeemBatch(_settleRedeemBatchParams.batchId, _settleRedeemBatchParams.classId, _totalAmountToRedeem);
    }

    /**
     * @dev Internal function to settle a redeem for a user.
     * @param _sd The storage struct.
     * @param _user The user to settle the redeem for.
     * @param _amount The amount to settle.
     * @param _newTotalAssets The new total assets after settlement.
     * @param _classId The id of the class.
     * @return _remainingAmount The remaining amount to redeem.
     */
    function _settleRedeemForUser(
        AlephVaultStorageData storage _sd,
        uint48 _batchId,
        address _user,
        uint256 _amount,
        uint256[] memory _newTotalAssets,
        uint8 _classId
    ) internal returns (uint256 _remainingAmount) {
        _remainingAmount =
            _settleRedeemSlice(_sd, _batchId, _user, _amount, _newTotalAssets[LEAD_SERIES_ID], _classId, LEAD_SERIES_ID);
        uint256 _len = _newTotalAssets.length;
        uint8 _lastConsolidatedSeriesId = _sd.shareClasses[_classId].lastConsolidatedSeriesId;
        for (uint8 i = 1; i < _len; i++) {
            _remainingAmount = _settleRedeemSlice(
                _sd, _batchId, _user, _remainingAmount, _newTotalAssets[i], _classId, _lastConsolidatedSeriesId + i
            );
            if (_remainingAmount == 0) {
                break;
            }
        }
    }

    /**
     * @dev Internal function to settle a redeem slice.
     * @param _sd The storage struct.
     * @param _batchId The id of the batch.
     * @param _user The user to settle the redeem for.
     * @param _amount The amount to settle.
     * @param _newTotalAssets The new total assets after settlement.
     * @param _classId The id of the class.
     * @param _seriesId The id of the series.
     * @return _remainingAmount The remaining amount to redeem.
     */
    function _settleRedeemSlice(
        AlephVaultStorageData storage _sd,
        uint48 _batchId,
        address _user,
        uint256 _amount,
        uint256 _newTotalAssets,
        uint8 _classId,
        uint8 _seriesId
    ) internal returns (uint256 _remainingAmount) {
        _remainingAmount = _amount;
        IAlephVault.ShareSeries storage _shareSeries = _sd.shareClasses[_classId].shareSeries[_seriesId];
        uint256 _sharesInSeries = _sharesOf(_sd, _classId, _seriesId, _user);
        uint256 _amountInSeries =
            ERC4626Math.previewRedeem(_sharesInSeries, _newTotalAssets, _shareSeries.totalAssets);
        if (_amountInSeries < _remainingAmount) {
            _remainingAmount -= _amountInSeries;
            _shareSeries.totalAssets -= _amountInSeries;
            _shareSeries.totalShares -= _sharesInSeries;
            delete _shareSeries.sharesOf[_user];
            emit IERC7540Settlement.RedeemRequestSliceSettled(
                _batchId, _user, _classId, _seriesId, _amountInSeries, _sharesInSeries
            );
        } else {
            uint256 _userSharesToBurn =
                ERC4626Math.previewRedeem(_remainingAmount, _newTotalAssets, _shareSeries.totalAssets);
            _shareSeries.totalAssets -= _remainingAmount;
            _shareSeries.totalShares -= _userSharesToBurn;
            _shareSeries.sharesOf[_user] -= _userSharesToBurn;
            emit IERC7540Settlement.RedeemRequestSliceSettled(
                _batchId, _user, _classId, _seriesId, _remainingAmount, _userSharesToBurn
            );
            return 0;
        }
    }

    /**
     * @dev Internal function to get the settlement series id.
     * @param _sd The storage struct.
     * @param _classId The id of the class.
     * @param _currentBatchId The current batch id.
     * @return _seriesId The series id.
     */
    function _getSettlementSeriesId(AlephVaultStorageData storage _sd, uint8 _classId, uint48 _currentBatchId)
        internal
        returns (uint8 _seriesId)
    {
        IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_classId];
        if (_shareClass.performanceFee > 0) {
            uint8 _shareSeriesId = _shareClass.shareSeriesId;
            uint8 _lastConsolidatedSeriesId = _shareClass.lastConsolidatedSeriesId;
            if (_shareClass.shareSeries[LEAD_SERIES_ID].highWaterMark > _leadPricePerShare(_sd, _classId)) {
                _seriesId = _createNewSeries(_shareClass, _classId, _currentBatchId);
            } else if (_shareSeriesId > _lastConsolidatedSeriesId) {
                _consolidateSeries(_shareClass, _classId, _shareSeriesId, _lastConsolidatedSeriesId, _currentBatchId);
            }
        }
    }

    /**
     * @dev Internal function to create a new series.
     * @param _shareClass The share class to create the new series for.
     * @param _classId The id of the class.
     * @param _currentBatchId The current batch id.
     * @return _seriesId The series id.
     */
    function _createNewSeries(IAlephVault.ShareClass storage _shareClass, uint8 _classId, uint48 _currentBatchId)
        internal
        returns (uint8 _seriesId)
    {
        _seriesId = _shareClass.shareSeriesId++;
        _shareClass.shareSeries[_seriesId].highWaterMark = PRICE_DENOMINATOR;
        emit NewSeriesCreated(_classId, _seriesId, _currentBatchId);
    }

    /**
     * @dev Internal function to consolidate series.
     * @param _shareClass The share class to consolidate.
     * @param _classId The id of the class.
     * @param _shareSeriesId The id of the share series.
     * @param _lastConsolidatedSeriesId The id of the last consolidated series.
     * @param _currentBatchId The current batch id.
     */
    function _consolidateSeries(
        IAlephVault.ShareClass storage _shareClass,
        uint8 _classId,
        uint8 _shareSeriesId,
        uint8 _lastConsolidatedSeriesId,
        uint48 _currentBatchId
    ) internal {
        uint256 _totalAmountToTransfer;
        uint256 _totalSharesToTransfer;
        for (uint8 _seriesId = _lastConsolidatedSeriesId + 1; _seriesId <= _shareSeriesId; _seriesId++) {
            (uint256 _amountToTransfer, uint256 _sharesToTransfer) =
                _consolidateUserShares(_shareClass, _classId, _seriesId, _currentBatchId);
            _totalAmountToTransfer += _amountToTransfer;
            _totalSharesToTransfer += _sharesToTransfer;
            emit SeriesConsolidated(_classId, _seriesId, _currentBatchId, _amountToTransfer, _sharesToTransfer);
        }
        _shareClass.lastConsolidatedSeriesId = _shareSeriesId;
        _shareClass.shareSeries[LEAD_SERIES_ID].totalAssets += _totalAmountToTransfer;
        _shareClass.shareSeries[LEAD_SERIES_ID].totalShares += _totalSharesToTransfer;
        emit AllSeriesConsolidated(
            _classId,
            _lastConsolidatedSeriesId + 1,
            _shareSeriesId,
            _currentBatchId,
            _totalAmountToTransfer,
            _totalSharesToTransfer
        );
    }

    /**
     * @dev Internal function to consolidate user shares.
     * @param _shareClass The share class to consolidate.
     * @param _classId The id of the class.
     * @param _seriesId The id of the series.
     * @param _currentBatchId The current batch id.
     * @return _totalAmountToTransfer The total amount to transfer.
     * @return _totalSharesToTransfer The total shares to transfer.
     */
    function _consolidateUserShares(
        IAlephVault.ShareClass storage _shareClass,
        uint8 _classId,
        uint8 _seriesId,
        uint48 _currentBatchId
    ) internal returns (uint256 _totalAmountToTransfer, uint256 _totalSharesToTransfer) {
        IAlephVault.ShareSeries storage _leadSeries = _shareClass.shareSeries[LEAD_SERIES_ID];
        IAlephVault.ShareSeries storage _shareSeries = _shareClass.shareSeries[_seriesId];
        UserConsolidationDetails memory _userConsolidationDetails = UserConsolidationDetails({
            user: address(0),
            classId: _classId,
            seriesId: _seriesId,
            shares: 0,
            amountToTransfer: 0,
            sharesToTransfer: 0,
            currentBatchId: _currentBatchId
        });
        _shareSeries.users.add(MANAGEMENT_FEE_RECIPIENT);
        _shareSeries.users.add(PERFORMANCE_FEE_RECIPIENT);
        uint256 _len = _shareSeries.users.length();
        for (uint256 _i; _i < _len; _i++) {
            _userConsolidationDetails.user = _shareSeries.users.at(_i);
            _userConsolidationDetails.shares = _shareSeries.sharesOf[_userConsolidationDetails.user];
            _userConsolidationDetails.amountToTransfer = ERC4626Math.previewRedeem(
                _userConsolidationDetails.shares, _shareSeries.totalAssets, _shareSeries.totalShares
            );
            _userConsolidationDetails.sharesToTransfer = ERC4626Math.previewDeposit(
                _userConsolidationDetails.amountToTransfer, _leadSeries.totalShares, _leadSeries.totalAssets
            );
            _totalAmountToTransfer += _userConsolidationDetails.amountToTransfer;
            _totalSharesToTransfer += _userConsolidationDetails.sharesToTransfer;
            if (!_leadSeries.users.contains(_userConsolidationDetails.user)) {
                _leadSeries.users.add(_userConsolidationDetails.user);
            }
            emit UserSharesConsolidated(_userConsolidationDetails);
        }
    }

    /**
     * @dev Internal function to accumulate fees.
     * @param _shareClass The share class to accumulate fees for.
     * @param _classId The id of the class.
     * @param _lastConsolidatedSeriesId The id of the last consolidated series.
     * @param _currentBatchId The current batch id.
     * @param _newTotalAssets The new total assets after settlement.
     */
    function _accumulateFees(
        IAlephVault.ShareClass storage _shareClass,
        uint8 _classId,
        uint8 _lastConsolidatedSeriesId,
        uint48 _currentBatchId,
        uint256[] calldata _newTotalAssets
    ) internal {
        uint48 _lastFeePaidId = _shareClass.lastFeePaidId;
        if (_currentBatchId > _lastFeePaidId) {
            _shareClass.shareSeries[LEAD_SERIES_ID].totalAssets = _newTotalAssets[LEAD_SERIES_ID];
            _shareClass.shareSeries[LEAD_SERIES_ID].totalShares += _getAccumulatedFees(
                _newTotalAssets[LEAD_SERIES_ID],
                _shareClass.shareSeries[LEAD_SERIES_ID].totalShares,
                _currentBatchId,
                _lastFeePaidId,
                _classId,
                LEAD_SERIES_ID
            );
            for (uint8 _i = 1; _i < _newTotalAssets.length; _i++) {
                uint8 _seriesId = _lastConsolidatedSeriesId + _i;
                _shareClass.shareSeries[_seriesId].totalAssets = _newTotalAssets[_i];
                _shareClass.shareSeries[_seriesId].totalShares += _getAccumulatedFees(
                    _newTotalAssets[_i],
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

    /**
     * @dev Internal function to get the accumulated fees.
     * @param _newTotalAssets The new total assets after settlement.
     * @param _totalShares The total shares in the vault.
     * @param _currentBatchId The current batch id.
     * @param _lastFeePaidId The last fee paid id.
     * @param _classId The id of the class.
     * @param _seriesId The id of the series.
     * @return The accumulated fees shares to mint.
     */
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
