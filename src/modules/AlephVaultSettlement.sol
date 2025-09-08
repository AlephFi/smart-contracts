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
import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
import {ModulesLibrary} from "@aleph-vault/libraries/ModulesLibrary.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {AlephVaultBase} from "@aleph-vault/AlephVaultBase.sol";
import {AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract AlephVaultSettlement is IERC7540Settlement, AlephVaultBase {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(uint48 _batchDuration) AlephVaultBase(_batchDuration) {}

    /// @inheritdoc IERC7540Settlement
    function settleDeposit(SettlementParams calldata _settlementParams) external nonReentrant {
        _settleDeposit(_getStorage(), _settlementParams);
    }

    /// @inheritdoc IERC7540Settlement
    function settleRedeem(SettlementParams calldata _settlementParams) external nonReentrant {
        _settleRedeem(_getStorage(), _settlementParams);
    }

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
            _getSettlementSeriesId(_shareClass, _settlementParams.classId, _settlementParams.toBatchId);
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
            _createNewSeries(_shareClass, _settleDepositDetails.classId, _settleDepositDetails.toBatchId);
            _settleDepositDetails.createSeries = false;
        }
        uint256 _totalSharesToMint;
        uint256 _len = _depositRequests.usersToDeposit.length;
        // iterate through all requests in batch (one user can only make one request per batch)
        for (uint256 _i; _i < _len; _i++) {
            DepositRequestParams memory _depositRequestParams;
            _depositRequestParams.user = _depositRequests.usersToDeposit[_i];
            _depositRequestParams.amount = _depositRequests.depositRequest[_depositRequestParams.user];
            _depositRequestParams.sharesToMint = ERC4626Math.previewDeposit(
                _depositRequestParams.amount, _settleDepositDetails.totalShares, _settleDepositDetails.totalAssets
            );
            _totalSharesToMint += _depositRequestParams.sharesToMint;
            _shareClass.shareSeries[_settleDepositDetails.seriesId].sharesOf[_depositRequestParams.user] +=
                _depositRequestParams.sharesToMint;
            // add user into settlement series if they don't already exist there
            if (!_shareClass.shareSeries[_settleDepositDetails.seriesId].users.contains(_depositRequestParams.user)) {
                _shareClass.shareSeries[_settleDepositDetails.seriesId].users.add(_depositRequestParams.user);
            }
            emit IERC7540Settlement.DepositRequestSettled(
                _depositRequestParams.user,
                _settleDepositDetails.classId,
                _settleDepositDetails.seriesId,
                _depositRequestParams.amount,
                _depositRequestParams.sharesToMint,
                _settleDepositDetails.batchId
            );
        }
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
        if (_settlementParams.toBatchId > _currentBatch(_sd)) {
            revert InvalidToBatchId();
        }
        IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_settlementParams.classId];
        uint48 _redeemSettleId = _shareClass.redeemSettleId;
        if (_settlementParams.toBatchId <= _redeemSettleId) {
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
        address _underlyingToken = _sd.underlyingToken;
        for (uint48 _batchId = _redeemSettleId; _batchId < _settlementParams.toBatchId; _batchId++) {
            _settleRedeemForBatch(_sd, _batchId, _settlementParams.classId, _underlyingToken, _shareClass);
        }
        _shareClass.redeemSettleId = _settlementParams.toBatchId;
        emit SettleRedeem(_redeemSettleId, _settlementParams.toBatchId, _settlementParams.classId);
    }

    /**
     * @dev Internal function to settle redeems for a specific batch.
     * @param _sd The storage struct.
     * @param _batchId The id of the batch.
     * @param _classId The id of the class.
     * @param _underlyingToken The underlying token.
     */
    function _settleRedeemForBatch(
        AlephVaultStorageData storage _sd,
        uint48 _batchId,
        uint8 _classId,
        address _underlyingToken,
        IAlephVault.ShareClass storage _shareClass
    ) internal {
        IAlephVault.RedeemRequests storage _redeemRequests = _shareClass.redeemRequests[_batchId];
        uint256 _totalAmountToRedeem;
        uint256 _len = _redeemRequests.usersToRedeem.length;
        // iterate through all requests in batch (one user can only make one request per batch)
        for (uint256 _i; _i < _len; _i++) {
            address _user = _redeemRequests.usersToRedeem[_i];
            // calculate amount to redeem for the user
            // redeem request value is the proportional amount user requested to redeem
            // this amount can now be different from the original amount requested as the price per share
            // in this cycle may have changed since the request was made due to pnl of the vault and fees
            uint256 _amount = ERC4626Math.previewMintUnits(
                _redeemRequests.redeemRequest[_user], _assetsPerClassOf(_classId, _user, _shareClass)
            );
            _settleRedeemForUser(_sd, _batchId, _user, _amount, _classId, _shareClass);
            _totalAmountToRedeem += _amount;
            IERC20(_underlyingToken).safeTransfer(_user, _amount);
            emit RedeemRequestSettled(_batchId, _user, _classId, _amount);
        }
        emit SettleRedeemBatch(_batchId, _classId, _totalAmountToRedeem);
    }

    /**
     * @dev Internal function to settle a redeem for a user.
     * @param _sd The storage struct.
     * @param _user The user to settle the redeem for.
     * @param _amount The amount to settle.
     * @param _classId The id of the class.
     */
    function _settleRedeemForUser(
        AlephVaultStorageData storage _sd,
        uint48 _batchId,
        address _user,
        uint256 _amount,
        uint8 _classId,
        IAlephVault.ShareClass storage _shareClass
    ) internal {
        // the amount requested is redeemed from teh class in a first-in first-out basis
        // we first try to settle the redemption from the lead series
        // remaining amount is assets that were not settled in the lead series (this happens if user does not have
        // enough assets in the lead series to complete the redemption)
        uint256 _remainingAmount = _amount;
        uint8 _lastConsolidatedSeriesId = _shareClass.lastConsolidatedSeriesId;
        uint8 _shareSeriesId = _shareClass.shareSeriesId;

        // we now iterate through all series to settle the remaining user amount
        for (uint8 _seriesId; _seriesId <= _shareSeriesId; _seriesId++) {
            // if the user request amount is settled completely, we break out of the loop
            if (_remainingAmount == 0) {
                break;
            }
            if (_seriesId > LEAD_SERIES_ID) {
                _seriesId += _lastConsolidatedSeriesId;
            }
            // we attempt to settle the remaining amount from this series
            // this continues to happen for all outstanding series until the complete amount is settled
            _remainingAmount =
                _settleRedeemSlice(_sd, _batchId, _user, _remainingAmount, _classId, _seriesId, _shareClass);
        }
    }

    /**
     * @dev Internal function to settle a redeem slice.
     * @param _sd The storage struct.
     * @param _batchId The id of the batch.
     * @param _user The user to settle the redeem for.
     * @param _amount The amount to settle.
     * @param _classId The id of the class.
     * @param _seriesId The id of the series.
     * @return _remainingAmount The remaining amount to redeem.
     */
    function _settleRedeemSlice(
        AlephVaultStorageData storage _sd,
        uint48 _batchId,
        address _user,
        uint256 _amount,
        uint8 _classId,
        uint8 _seriesId,
        IAlephVault.ShareClass storage _shareClass
    ) internal returns (uint256 _remainingAmount) {
        _remainingAmount = _amount;
        IAlephVault.ShareSeries storage _shareSeries = _shareClass.shareSeries[_seriesId];
        // check total assets available in the series for the user
        uint256 _sharesInSeries = _sharesOf(_shareClass, _seriesId, _user);
        uint256 _amountInSeries =
            ERC4626Math.previewRedeem(_sharesInSeries, _shareSeries.totalAssets, _shareSeries.totalShares);
        // if the amount available in the series is less than the remaining amount, we settle the entire
        // amount in the series and move on to the next series by updating the remaining amount
        if (_amountInSeries < _remainingAmount) {
            _remainingAmount -= _amountInSeries;
            // redeem the entire amount in the series and update the series total assets and shares
            _shareSeries.totalAssets -= _amountInSeries;
            _shareSeries.totalShares -= _sharesInSeries;
            delete _shareSeries.sharesOf[_user];
            emit IERC7540Settlement.RedeemRequestSliceSettled(
                _batchId, _user, _classId, _seriesId, _amountInSeries, _sharesInSeries
            );
        } else {
            // if the amount available in the series is greater than or equal to the remaining amount,
            // we settle the remaining amount in the series and update the series total assets and shares
            uint256 _userSharesToBurn =
                ERC4626Math.previewWithdraw(_remainingAmount, _shareSeries.totalShares, _shareSeries.totalAssets);
            _shareSeries.totalAssets -= _remainingAmount;
            _shareSeries.totalShares -= _userSharesToBurn;
            _shareSeries.sharesOf[_user] -= _userSharesToBurn;
            emit IERC7540Settlement.RedeemRequestSliceSettled(
                _batchId, _user, _classId, _seriesId, _remainingAmount, _userSharesToBurn
            );
            // set the remaining amount to 0 as the entire amount has been settled and we break out of the loop
            _remainingAmount = 0;
        }
    }

    /**
     * @dev Internal function to get the settlement series id.
     * @param _shareClass The share class.
     * @param _classId The id of the class.
     * @param _toBatchId The batch id to settle deposits up to.
     * @return _seriesId The series id.
     */
    function _getSettlementSeriesId(IAlephVault.ShareClass storage _shareClass, uint8 _classId, uint48 _toBatchId)
        internal
        returns (uint8 _seriesId)
    {
        // for non-incentive classes, all settlements take place in the lead series
        if (_shareClass.performanceFee > 0) {
            uint8 _shareSeriesId = _shareClass.shareSeriesId;
            uint8 _lastConsolidatedSeriesId = _shareClass.lastConsolidatedSeriesId;
            // if new lead series highwatermark is not reached, settlements must take place in a new series
            // if a new highwater mark is reached in this cycle, it will be updated in _accumalateFees function
            // hence, after fee accumalation process, the lead highwater mark is either greater than or equal to the lead price per share
            if (_shareClass.shareSeries[LEAD_SERIES_ID].highWaterMark > _leadPricePerShare(_shareClass, _classId)) {
                // we don't create a new series just yet because there might not be any deposit request to settle in this cycle
                _seriesId = _shareSeriesId + 1;
            } else if (_shareSeriesId > _lastConsolidatedSeriesId) {
                // if new lead series highwatermark was reached in this cycle and their exists outstanding series, consolidate them into lead series
                _consolidateSeries(_shareClass, _classId, _shareSeriesId, _lastConsolidatedSeriesId, _toBatchId);
            }
        }
    }

    /**
     * @dev Internal function to create a new series.
     * @param _shareClass The share class to create the new series for.
     * @param _classId The id of the class.
     * @param _toBatchId The batch id to settle deposits up to.
     */
    function _createNewSeries(IAlephVault.ShareClass storage _shareClass, uint8 _classId, uint48 _toBatchId) internal {
        uint8 _newSeriesId = ++_shareClass.shareSeriesId;
        _shareClass.shareSeries[_newSeriesId].highWaterMark = PRICE_DENOMINATOR;
        emit NewSeriesCreated(_classId, _newSeriesId, _toBatchId);
    }

    /**
     * @dev Internal function to consolidate series.
     * @param _shareClass The share class to consolidate.
     * @param _classId The id of the class.
     * @param _shareSeriesId The id of the share series.
     * @param _lastConsolidatedSeriesId The id of the last consolidated series.
     * @param _toBatchId The batch id to settle deposits up to.
     */
    function _consolidateSeries(
        IAlephVault.ShareClass storage _shareClass,
        uint8 _classId,
        uint8 _shareSeriesId,
        uint8 _lastConsolidatedSeriesId,
        uint48 _toBatchId
    ) internal {
        uint256 _totalAmountToTransfer;
        uint256 _totalSharesToTransfer;
        // iterate through all outstanding series
        IAlephVault.ShareSeries storage _leadSeries = _shareClass.shareSeries[LEAD_SERIES_ID];
        for (uint8 _seriesId = _lastConsolidatedSeriesId + 1; _seriesId <= _shareSeriesId; _seriesId++) {
            IAlephVault.ShareSeries storage _shareSeries = _shareClass.shareSeries[_seriesId];
            (uint256 _amountToTransfer, uint256 _sharesToTransfer) =
                _consolidateUserShares(_leadSeries, _shareSeries, _classId, _seriesId, _toBatchId);
            // sum up the total amount and shares to transfer into the lead series
            _totalAmountToTransfer += _amountToTransfer;
            _totalSharesToTransfer += _sharesToTransfer;
            // delete series
            _shareSeries.users.clear();
            delete _shareClass.shareSeries[_seriesId];
            emit SeriesConsolidated(_classId, _seriesId, _toBatchId, _amountToTransfer, _sharesToTransfer);
        }
        // update the last consolidated series id and add the total amount and shares to transfer into the lead series
        _shareClass.lastConsolidatedSeriesId = _shareSeriesId;
        _shareClass.shareSeries[LEAD_SERIES_ID].totalAssets += _totalAmountToTransfer;
        _shareClass.shareSeries[LEAD_SERIES_ID].totalShares += _totalSharesToTransfer;
        emit AllSeriesConsolidated(
            _classId,
            _lastConsolidatedSeriesId + 1,
            _shareSeriesId,
            _toBatchId,
            _totalAmountToTransfer,
            _totalSharesToTransfer
        );
    }

    /**
     * @dev Internal function to consolidate user shares.
     * @param _leadSeries The lead series to consolidate.
     * @param _shareSeries The share series to consolidate.
     * @param _classId The id of the class.
     * @param _seriesId The id of the series.
     * @param _toBatchId The batch id to settle deposits up to.
     * @return _totalAmountToTransfer The total amount to transfer.
     * @return _totalSharesToTransfer The total shares to transfer.
     */
    function _consolidateUserShares(
        IAlephVault.ShareSeries storage _leadSeries,
        IAlephVault.ShareSeries storage _shareSeries,
        uint8 _classId,
        uint8 _seriesId,
        uint48 _toBatchId
    ) internal returns (uint256 _totalAmountToTransfer, uint256 _totalSharesToTransfer) {
        UserConsolidationDetails memory _userConsolidationDetails = UserConsolidationDetails({
            user: address(0),
            classId: _classId,
            seriesId: _seriesId,
            shares: 0,
            amountToTransfer: 0,
            sharesToTransfer: 0,
            toBatchId: _toBatchId
        });
        // add virtual users into user list
        _shareSeries.users.add(MANAGEMENT_FEE_RECIPIENT);
        _shareSeries.users.add(PERFORMANCE_FEE_RECIPIENT);
        uint256 _len = _shareSeries.users.length();
        // iterate through all users in the series and transfer their shares to the lead series
        for (uint256 _i; _i < _len; _i++) {
            _userConsolidationDetails.user = _shareSeries.users.at(_i);
            _userConsolidationDetails.shares = _shareSeries.sharesOf[_userConsolidationDetails.user];
            // calculate amount to transfer from outstanding series to lead series
            _userConsolidationDetails.amountToTransfer = ERC4626Math.previewMint(
                _userConsolidationDetails.shares, _shareSeries.totalAssets, _shareSeries.totalShares
            );
            // calculate corresponding shares to deposit in lead series
            _userConsolidationDetails.sharesToTransfer = ERC4626Math.previewWithdraw(
                _userConsolidationDetails.amountToTransfer, _leadSeries.totalShares, _leadSeries.totalAssets
            );
            // sum up the total amount and shares to transfer into the lead series
            _totalAmountToTransfer += _userConsolidationDetails.amountToTransfer;
            _totalSharesToTransfer += _userConsolidationDetails.sharesToTransfer;
            // add the user's shares to the lead series
            _leadSeries.sharesOf[_userConsolidationDetails.user] += _userConsolidationDetails.sharesToTransfer;
            // if user does not exist in lead series, add them in lead series (except for virtual users)
            if (
                !_leadSeries.users.contains(_userConsolidationDetails.user)
                    && (
                        _userConsolidationDetails.user != MANAGEMENT_FEE_RECIPIENT
                            || _userConsolidationDetails.user != PERFORMANCE_FEE_RECIPIENT
                    )
            ) {
                _leadSeries.users.add(_userConsolidationDetails.user);
            }
            // remove user shares from the series
            delete _shareSeries.sharesOf[_userConsolidationDetails.user];
            emit UserSharesConsolidated(_userConsolidationDetails);
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
                uint8 _seriesId = _i > LEAD_SERIES_ID ? _lastConsolidatedSeriesId + _i : LEAD_SERIES_ID;
                // update the series total assets and shares
                _shareClass.shareSeries[_seriesId].totalAssets = _newTotalAssets[_i];
                _shareClass.shareSeries[_seriesId].totalShares += _getAccumulatedFees(
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
     * @dev Internal function to get the accumulated fees.
     * @param _newTotalAssets The new total assets after settlement.
     * @param _totalShares The total shares in the vault.
     * @param _toBatchId The batch id to settle deposits up to.
     * @param _lastFeePaidId The last fee paid id.
     * @param _classId The id of the class.
     * @param _seriesId The id of the series.
     * @return The accumulated fees shares to mint.
     */
    function _getAccumulatedFees(
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
