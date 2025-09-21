// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;
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
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephVaultSettlement} from "@aleph-vault/interfaces/IAlephVaultSettlement.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {ModulesLibrary} from "@aleph-vault/libraries/ModulesLibrary.sol";
import {SeriesAccounting} from "@aleph-vault/libraries/SeriesAccounting.sol";
import {AlephVaultBase} from "@aleph-vault/AlephVaultBase.sol";
import {AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract AlephVaultSettlement is IAlephVaultSettlement, AlephVaultBase {
    using SafeERC20 for IERC20;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SeriesAccounting for IAlephVault.ShareClass;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Constructor for AlephVaultSettlement module
     * @param _batchDuration The duration of each batch cycle in seconds
     */
    constructor(uint48 _batchDuration) AlephVaultBase(_batchDuration) {}

    /*//////////////////////////////////////////////////////////////
                            SETTLEMENT FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IAlephVaultSettlement
    function settleDeposit(SettlementParams calldata _settlementParams) external nonReentrant {
        _settleDeposit(_getStorage(), _settlementParams);
    }

    /// @inheritdoc IAlephVaultSettlement
    function settleRedeem(SettlementParams calldata _settlementParams) external nonReentrant {
        _settleRedeem(_getStorage(), _settlementParams);
    }

    /// @inheritdoc IAlephVaultSettlement
    function forceRedeem(address _user) external nonReentrant {
        _forceRedeem(_getStorage(), _user);
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Internal function to settle all deposits for batches up to the current batch.
     * @param _sd The storage struct.
     * @param _settlementParams The parameters for the settlement.
     */
    function _settleDeposit(AlephVaultStorageData storage _sd, SettlementParams calldata _settlementParams) internal {
        // verify all conditions are satisfied to settle deposits
        if (_settlementParams.toBatchId > _currentBatch(_sd)) {
            revert InvalidToBatchId();
        }
        IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_settlementParams.classId];
        uint48 _depositSettleId = _shareClass.depositSettleId;
        if (_settlementParams.toBatchId <= _depositSettleId) {
            revert NoDepositsToSettle();
        }
        uint8 _lastConsolidatedSeriesId = _shareClass.lastConsolidatedSeriesId;
        _validateNewTotalAssets(_shareClass.shareSeriesId, _lastConsolidatedSeriesId, _settlementParams.newTotalAssets);
        if (_sd.isSettlementAuthEnabled) {
            AuthLibrary.verifySettlementAuthSignature(
                AuthLibrary.SETTLE_DEPOSIT,
                _settlementParams.classId,
                _settlementParams.toBatchId,
                _sd.manager,
                _settlementParams.newTotalAssets,
                _sd.authSigner,
                _settlementParams.authSignature
            );
        }
        // accumalate fees if applicable
        _accumulateFees(
            _shareClass,
            _settlementParams.classId,
            _lastConsolidatedSeriesId,
            _settlementParams.toBatchId,
            _settlementParams.newTotalAssets
        );
        uint8 _settlementSeriesId =
            _handleSeriesAccounting(_shareClass, _settlementParams.classId, _settlementParams.toBatchId);
        IAlephVault.ShareSeries storage _shareSeries = _shareClass.shareSeries[_settlementSeriesId];
        SettleDepositDetails memory _settleDepositDetails = SettleDepositDetails({
            // check if a new series needs to be created
            createSeries: _settlementSeriesId > 0,
            classId: _settlementParams.classId,
            seriesId: _settlementSeriesId,
            batchId: _depositSettleId,
            toBatchId: _settlementParams.toBatchId,
            totalAssets: _shareSeries.totalAssets,
            totalShares: _shareSeries.totalShares
        });
        uint256 _amountToSettle;
        for (
            _settleDepositDetails.batchId;
            _settleDepositDetails.batchId < _settlementParams.toBatchId;
            _settleDepositDetails.batchId++
        ) {
            // settle deposits for each unsettled batch
            (uint256 _amount, uint256 _sharesToMint) = _settleDepositForBatch(_shareClass, _settleDepositDetails);
            _amountToSettle += _amount;
            _settleDepositDetails.totalAssets += _amount;
            _settleDepositDetails.totalShares += _sharesToMint;
        }
        _shareClass.depositSettleId = _settlementParams.toBatchId;
        _shareSeries.totalAssets = _settleDepositDetails.totalAssets;
        _shareSeries.totalShares = _settleDepositDetails.totalShares;
        _sd.totalAmountToDeposit -= _amountToSettle;
        uint256 _requiredVaultBalance = _amountToSettle + _sd.totalAmountToDeposit + _sd.totalAmountToWithdraw;
        if (IERC20(_sd.underlyingToken).balanceOf(address(this)) < _requiredVaultBalance) {
            revert InsufficientAssetsToSettle(_requiredVaultBalance);
        }
        if (_amountToSettle > 0) {
            IERC20(_sd.underlyingToken).safeTransfer(_sd.custodian, _amountToSettle);
        }
        emit SettleDeposit(
            _depositSettleId,
            _settlementParams.toBatchId,
            _settlementParams.classId,
            _settleDepositDetails.seriesId,
            _amountToSettle,
            _settleDepositDetails.totalAssets,
            _settleDepositDetails.totalShares
        );
    }

    /**
     * @dev Internal function to settle deposits for a specific batch.
     * @param _shareClass The share class to settle.
     * @param _settleDepositDetails The parameters for the settlement.
     * @return The total amount settled for the batch.
     * @return The total shares minted for the batch.
     */
    function _settleDepositForBatch(
        IAlephVault.ShareClass storage _shareClass,
        SettleDepositDetails memory _settleDepositDetails
    ) internal returns (uint256, uint256) {
        IAlephVault.DepositRequests storage _depositRequests =
            _shareClass.depositRequests[_settleDepositDetails.batchId];
        uint256 _totalAmountToDeposit = _depositRequests.totalAmountToDeposit;
        // if there are no deposits to settle, return 0
        if (_totalAmountToDeposit == 0) {
            return (0, 0);
        }
        // create a new series only if there are deposits to settle (and createSeries flag is true)
        if (_settleDepositDetails.createSeries) {
            _shareClass.createNewSeries(_settleDepositDetails.classId, _settleDepositDetails.toBatchId);
            _settleDepositDetails.createSeries = false;
        }
        uint256 _totalSharesToMint;
        uint256 _len = _depositRequests.usersToDeposit.length();
        // iterate through all requests in batch (one user can only make one request per batch)
        for (uint256 _i; _i < _len; _i++) {
            DepositRequestDetails memory _depositRequestDetails;
            _depositRequestDetails.user = _depositRequests.usersToDeposit.at(_i);
            _depositRequestDetails.amount = _depositRequests.depositRequest[_depositRequestDetails.user];
            _depositRequestDetails.sharesToMint = ERC4626Math.previewDeposit(
                _depositRequestDetails.amount, _settleDepositDetails.totalShares, _settleDepositDetails.totalAssets
            );
            _totalSharesToMint += _depositRequestDetails.sharesToMint;
            _shareClass.shareSeries[_settleDepositDetails.seriesId].sharesOf[_depositRequestDetails.user] +=
                _depositRequestDetails.sharesToMint;
            // add user into settlement series if they don't already exist there
            if (!_shareClass.shareSeries[_settleDepositDetails.seriesId].users.contains(_depositRequestDetails.user)) {
                _shareClass.shareSeries[_settleDepositDetails.seriesId].users.add(_depositRequestDetails.user);
            }
            // delete user deposit request
            delete _depositRequests.depositRequest[_depositRequestDetails.user];
            emit IAlephVaultSettlement.DepositRequestSettled(
                _depositRequestDetails.user,
                _settleDepositDetails.classId,
                _settleDepositDetails.seriesId,
                _depositRequestDetails.amount,
                _depositRequestDetails.sharesToMint,
                _settleDepositDetails.batchId
            );
        }
        // delete deposit requests
        _depositRequests.usersToDeposit.clear();
        delete _shareClass.depositRequests[_settleDepositDetails.batchId];
        emit SettleDepositBatch(
            _settleDepositDetails.batchId,
            _settleDepositDetails.classId,
            _settleDepositDetails.seriesId,
            _totalAmountToDeposit,
            _totalSharesToMint
        );
        return (_totalAmountToDeposit, _totalSharesToMint);
    }

    /**
     * @dev Internal function to settle all redeems for batches up to the current batch.
     * @param _sd The storage struct.
     * @param _settlementParams The parameters for the settlement.
     */
    function _settleRedeem(AlephVaultStorageData storage _sd, SettlementParams calldata _settlementParams) internal {
        // verify all conditions are satisfied to settle redeems
        IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_settlementParams.classId];
        uint48 _currentBatchId = _currentBatch(_sd);
        uint48 _noticePeriod = _shareClass.shareClassParams.noticePeriod;
        if (_settlementParams.toBatchId > _currentBatchId || _settlementParams.toBatchId < _noticePeriod) {
            revert InvalidToBatchId();
        }
        uint48 _redeemSettleId = _shareClass.redeemSettleId;
        uint48 _settleUptoBatchId = _settlementParams.toBatchId - _noticePeriod;
        if (_settleUptoBatchId <= _redeemSettleId) {
            revert NoRedeemsToSettle();
        }
        uint8 _lastConsolidatedSeriesId = _shareClass.lastConsolidatedSeriesId;
        _validateNewTotalAssets(_shareClass.shareSeriesId, _lastConsolidatedSeriesId, _settlementParams.newTotalAssets);
        if (_sd.isSettlementAuthEnabled) {
            AuthLibrary.verifySettlementAuthSignature(
                AuthLibrary.SETTLE_REDEEM,
                _settlementParams.classId,
                _settlementParams.toBatchId,
                _sd.manager,
                _settlementParams.newTotalAssets,
                _sd.authSigner,
                _settlementParams.authSignature
            );
        }
        // accumalate fees if applicable
        _accumulateFees(
            _shareClass,
            _settlementParams.classId,
            _lastConsolidatedSeriesId,
            _settlementParams.toBatchId,
            _settlementParams.newTotalAssets
        );
        // consolidate series if required
        _handleSeriesAccounting(_shareClass, _settlementParams.classId, _settlementParams.toBatchId);
        // settle redeems for each batch
        uint256 _totalAmountToRedeem;
        for (uint48 _batchId = _redeemSettleId; _batchId < _settleUptoBatchId; _batchId++) {
            _totalAmountToRedeem += _settleRedeemForBatch(_sd, _shareClass, _settlementParams.classId, _batchId);
        }
        // revert if manager didnt fund the vault before settling redeems
        uint256 _requiredVaultBalance = _totalAmountToRedeem + _sd.totalAmountToDeposit + _sd.totalAmountToWithdraw;
        if (IERC20(_sd.underlyingToken).balanceOf(address(this)) < _requiredVaultBalance) {
            revert InsufficientAssetsToSettle(_requiredVaultBalance);
        }
        _shareClass.redeemSettleId = _settleUptoBatchId;
        _sd.totalAmountToWithdraw += _totalAmountToRedeem;
        emit SettleRedeem(_redeemSettleId, _settlementParams.toBatchId, _settlementParams.classId);
    }

    /**
     * @dev Internal function to settle redeems for a specific batch.
     * @param _sd The storage struct.
     * @param _shareClass The share class storage reference.
     * @param _classId The id of the class.
     * @param _batchId The id of the batch.
     * @return _totalAmountToRedeem The total amount to redeem in this batch.
     */
    function _settleRedeemForBatch(
        AlephVaultStorageData storage _sd,
        IAlephVault.ShareClass storage _shareClass,
        uint8 _classId,
        uint48 _batchId
    ) internal returns (uint256 _totalAmountToRedeem) {
        IAlephVault.RedeemRequests storage _redeemRequests = _shareClass.redeemRequests[_batchId];
        uint256 _len = _redeemRequests.usersToRedeem.length();
        // iterate through all requests in batch (one user can only make one request per batch)
        for (uint256 _i; _i < _len; _i++) {
            address _user = _redeemRequests.usersToRedeem.at(_i);
            // calculate amount to redeem for the user
            // redeem request value is the proportional amount user requested to redeem
            // this amount can now be different from the original amount requested as the price per share
            // in this cycle may have changed since the request was made due to pnl of the vault and fees
            uint256 _amount = ERC4626Math.previewMintUnits(
                _redeemRequests.redeemRequest[_user], _assetsPerClassOf(_classId, _user, _shareClass)
            );
            _shareClass.settleRedeemForUser(_classId, _batchId, _user, _amount);
            _totalAmountToRedeem += _amount;
            _sd.redeemableAmount[_user] += _amount;
            // delete redeem request
            delete _redeemRequests.redeemRequest[_user];
            emit RedeemRequestSettled(_batchId, _user, _classId, _amount);
        }
        // delete redeem requests
        _redeemRequests.usersToRedeem.clear();
        delete _shareClass.redeemRequests[_batchId];
        emit SettleRedeemBatch(_batchId, _classId, _totalAmountToRedeem);
    }

    /**
     * @dev Internal function to force a redeem for a user.
     * @param _sd The storage struct.
     * @param _user The user to force a redeem for.
     */
    function _forceRedeem(AlephVaultStorageData storage _sd, address _user) internal {
        uint8 _shareClasses = _sd.shareClassesId;
        uint48 _currentBatchId = _currentBatch(_sd);
        uint256 _totalUserAssets;
        uint256 _totalDepositRequests;
        for (uint8 _classId = 1; _classId <= _shareClasses; _classId++) {
            IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_classId];
            uint48 _depositSettleId = _shareClass.depositSettleId;
            uint48 _redeemSettleId = _shareClass.redeemSettleId;
            uint256 _newDepositsToRedeem;
            for (
                uint48 _batchId = _depositSettleId > _redeemSettleId ? _redeemSettleId : _depositSettleId;
                _batchId <= _currentBatchId;
                _batchId++
            ) {
                if (_batchId >= _depositSettleId) {
                    IAlephVault.DepositRequests storage _depositRequest = _shareClass.depositRequests[_batchId];
                    uint256 _amount = _depositRequest.depositRequest[_user];
                    _newDepositsToRedeem += _amount;
                    _totalDepositRequests += _depositRequest.totalAmountToDeposit;
                    _depositRequest.totalAmountToDeposit -= _amount;
                    _depositRequest.usersToDeposit.remove(_user);
                    delete _depositRequest.depositRequest[_user];
                }
                if (_batchId >= _redeemSettleId) {
                    IAlephVault.RedeemRequests storage _redeemRequest = _shareClass.redeemRequests[_batchId];
                    _redeemRequest.usersToRedeem.remove(_user);
                    delete _redeemRequest.redeemRequest[_user];
                }
            }
            uint256 _userAssets = _assetsPerClassOf(_classId, _user, _shareClass);
            _shareClass.settleRedeemForUser(_classId, _currentBatchId, _user, _userAssets);
            _totalUserAssets += _userAssets;
        }
        uint256 _totalAssetsToSettle = _totalUserAssets + _totalDepositRequests;
        _sd.totalAmountToWithdraw += _totalAssetsToSettle;
        _sd.totalAmountToDeposit -= _totalDepositRequests;
        _sd.redeemableAmount[_user] += _totalAssetsToSettle;
        uint256 _requiredVaultBalance = _sd.totalAmountToWithdraw + _sd.totalAmountToDeposit;
        if (IERC20(_sd.underlyingToken).balanceOf(address(this)) < _requiredVaultBalance) {
            revert InsufficientAssetsToSettle(_requiredVaultBalance);
        }
        emit ForceRedeem(_currentBatchId, _user, _totalAssetsToSettle);
    }

    /**
     * @dev Internal function to handle the series accounting.
     * @param _shareClass The share class.
     * @param _classId The id of the class.
     * @param _toBatchId The batch id in which to consolidate/create new series.
     * @return _seriesId The series id in which to settle pending deposits.
     * @dev this function is called before settling deposits/redeems to handle the series accounting.
     * it consolidates outstanding series into the lead series if required. The retrn param is only
     * used in settle deposits to get the series id in which to settle pending deposits.
     * for redeems, this function is called to handle consolidation if required.
     */
    function _handleSeriesAccounting(IAlephVault.ShareClass storage _shareClass, uint8 _classId, uint48 _toBatchId)
        internal
        returns (uint8 _seriesId)
    {
        // for non-incentive classes, all settlements take place in the lead series
        if (_shareClass.shareClassParams.performanceFee > 0) {
            uint8 _shareSeriesId = _shareClass.shareSeriesId;
            uint8 _lastConsolidatedSeriesId = _shareClass.lastConsolidatedSeriesId;
            // if new lead series highwatermark is not reached, deposit settlements must take place in a new series
            // if a new highwater mark is reached in this cycle, it will be updated in _accumalateFees function
            // hence, after fee accumalation process, the lead highwater mark is either greater than or equal to the lead price per share
            if (
                _shareClass.shareSeries[SeriesAccounting.LEAD_SERIES_ID].highWaterMark
                    > _leadPricePerShare(_shareClass, _classId)
            ) {
                // we don't create a new series just yet because there might not be any deposit request to settle in this cycle
                _seriesId = _shareSeriesId + 1;
            } else if (_shareSeriesId > _lastConsolidatedSeriesId) {
                // if new lead series highwatermark was reached in this cycle and their exists outstanding series, consolidate them into lead series
                _shareClass.consolidateSeries(_classId, _shareSeriesId, _lastConsolidatedSeriesId, _toBatchId);
            }
        }
    }

    /**
     * @dev Internal function to validate the new total assets.
     * @param _shareSeriesId The id of the share series.
     * @param _lastConsolidatedSeriesId The id of the last consolidated series.
     * @param _newTotalAssets The new total assets after settlement.
     */
    function _validateNewTotalAssets(
        uint8 _shareSeriesId,
        uint8 _lastConsolidatedSeriesId,
        uint256[] calldata _newTotalAssets
    ) internal pure {
        if (_newTotalAssets.length != _shareSeriesId - _lastConsolidatedSeriesId + 1) {
            revert InvalidNewTotalAssets();
        }
    }

    /**
     * @dev Internal function to accumulate fees.
     * @param _shareClass The share class to accumulate fees for.
     * @param _classId The id of the class.
     * @param _lastConsolidatedSeriesId The id of the last consolidated series.
     * @param _toBatchId The batch id to settle deposits up to.
     * @param _newTotalAssets The new total assets after settlement.
     */
    function _accumulateFees(
        IAlephVault.ShareClass storage _shareClass,
        uint8 _classId,
        uint8 _lastConsolidatedSeriesId,
        uint48 _toBatchId,
        uint256[] calldata _newTotalAssets
    ) internal {
        uint48 _lastFeePaidId = _shareClass.lastFeePaidId;
        if (_toBatchId > _lastFeePaidId) {
            for (uint8 _i = 0; _i < _newTotalAssets.length; _i++) {
                uint8 _seriesId = _i > SeriesAccounting.LEAD_SERIES_ID
                    ? _lastConsolidatedSeriesId + _i
                    : SeriesAccounting.LEAD_SERIES_ID;
                // update the series total assets and shares
                _shareClass.shareSeries[_seriesId].totalAssets = _newTotalAssets[_i];
                _shareClass.shareSeries[_seriesId].totalShares += _accumulateFeeShares(
                    _newTotalAssets[_i],
                    _shareClass.shareSeries[_seriesId].totalShares,
                    _toBatchId,
                    _lastFeePaidId,
                    _classId,
                    _seriesId
                );
            }
            _shareClass.lastFeePaidId = _toBatchId;
        }
    }

    /**
     * @dev Internal function to get the accumulated fee shares.
     * @param _newTotalAssets The new total assets after settlement.
     * @param _totalShares The total shares in the vault.
     * @param _toBatchId The batch id to settle deposits up to.
     * @param _lastFeePaidId The last fee paid id.
     * @param _classId The id of the class.
     * @param _seriesId The id of the series.
     * @return The accumulated fee shares to mint.
     */
    function _accumulateFeeShares(
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint48 _toBatchId,
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
                (_newTotalAssets, _totalShares, _toBatchId, _lastFeePaidId, _classId, _seriesId)
            )
        );
        if (!_success) {
            revert DelegateCallFailed(_data);
        }
        return abi.decode(_data, (uint256));
    }
}
