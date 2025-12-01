// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;
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
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephVaultSettlement} from "@aleph-vault/interfaces/IAlephVaultSettlement.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
library SeriesAccounting {
    using EnumerableSet for EnumerableSet.AddressSet;

    /**
     * @notice The ID of the lead series.
     */
    uint32 internal constant LEAD_SERIES_ID = 0;
    /**
     * @notice The denominator for the price per share.
     */
    uint256 internal constant PRICE_DENOMINATOR = 1e6;
    /**
     * @notice The address of the virtual management fee recipient.
     */
    address internal constant MANAGEMENT_FEE_RECIPIENT = address(bytes20(keccak256("MANAGEMENT_FEE_RECIPIENT")));
    /**
     * @notice The address of the virtual performance fee recipient.
     */
    address internal constant PERFORMANCE_FEE_RECIPIENT = address(bytes20(keccak256("PERFORMANCE_FEE_RECIPIENT")));

    /*//////////////////////////////////////////////////////////////
                                STRUCTS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Details for the consolidation of a user's shares.
     * @param user The user that is to be consolidated.
     * @param classId The ID of the share class for which the consolidation should be done.
     * @param seriesId The ID of the share series which is to be consolidated.
     * @param toBatchId The batch ID in which consolidation should be logged as done.
     * @param shares The shares of the user which is to be consolidated.
     * @param amountToTransfer The amount of the user's shares to be transferred to the lead series.
     * @param sharesToTransfer The shares of the user's shares to be transferred to the lead series.
     */
    struct UserConsolidationDetails {
        address user;
        uint8 classId;
        uint32 seriesId;
        uint48 toBatchId;
        uint256 shares;
        uint256 amountToTransfer;
        uint256 sharesToTransfer;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Internal function to create a new series.
     * @param _shareClass The share class storage reference.
     * @param _classId The id of the class.
     * @param _toBatchId The batch id to settle deposits up to.
     */
    function createNewSeries(IAlephVault.ShareClass storage _shareClass, uint8 _classId, uint48 _toBatchId) internal {
        uint32 _newSeriesId = ++_shareClass.shareSeriesId;
        _shareClass.shareSeries[_newSeriesId].highWaterMark = PRICE_DENOMINATOR;
        emit IAlephVaultSettlement.NewSeriesCreated(_classId, _newSeriesId, _toBatchId);
    }

    /**
     * @dev Internal function to consolidate series.
     * @param _shareClass The share class storage reference.
     * @param _classId The id of the class.
     * @param _shareSeriesId The id of the share series.
     * @param _lastConsolidatedSeriesId The id of the last consolidated series.
     * @param _toBatchId The batch id to settle deposits up to.
     */
    function consolidateSeries(
        IAlephVault.ShareClass storage _shareClass,
        uint8 _classId,
        uint32 _shareSeriesId,
        uint32 _lastConsolidatedSeriesId,
        uint48 _toBatchId
    ) internal {
        uint256 _totalAmountToTransfer;
        uint256 _totalSharesToTransfer;
        // iterate through all outstanding series
        IAlephVault.ShareSeries storage _leadSeries = _shareClass.shareSeries[LEAD_SERIES_ID];
        for (uint32 _seriesId = _lastConsolidatedSeriesId + 1; _seriesId <= _shareSeriesId; _seriesId++) {
            IAlephVault.ShareSeries storage _shareSeries = _shareClass.shareSeries[_seriesId];
            (uint256 _amountToTransfer, uint256 _sharesToTransfer) =
                _consolidateUserShares(_leadSeries, _shareSeries, _classId, _seriesId, _toBatchId);
            // sum up the total amount and shares to transfer into the lead series
            _totalAmountToTransfer += _amountToTransfer;
            _totalSharesToTransfer += _sharesToTransfer;
            // delete series
            _shareSeries.users.clear();
            delete _shareClass.shareSeries[_seriesId];
            emit IAlephVaultSettlement.SeriesConsolidated(
                _classId, _seriesId, _toBatchId, _amountToTransfer, _sharesToTransfer
            );
        }
        // If all series have been consolidated, reset both to 0 (lead series only)
        // This ensures shareSeriesId always represents the highest active series ID
        if (_shareSeriesId > LEAD_SERIES_ID) {
            _shareClass.shareSeriesId = LEAD_SERIES_ID;
            _shareClass.lastConsolidatedSeriesId = LEAD_SERIES_ID;
        } else {
            // Update the last consolidated series id (only needed when shareSeriesId == 0, which shouldn't happen in practice)
            _shareClass.lastConsolidatedSeriesId = _shareSeriesId;
        }
        _shareClass.shareSeries[LEAD_SERIES_ID].totalAssets += _totalAmountToTransfer;
        _shareClass.shareSeries[LEAD_SERIES_ID].totalShares += _totalSharesToTransfer;
        emit IAlephVaultSettlement.AllSeriesConsolidated(
            _classId,
            _lastConsolidatedSeriesId + 1,
            _shareSeriesId,
            _toBatchId,
            _totalAmountToTransfer,
            _totalSharesToTransfer
        );
    }

    /**
     * @dev Internal function to settle a redeem for a user using FIFO method.
     * @param _shareClass The share class storage reference.
     * @param _classId The id of the class.
     * @param _batchId The id of the batch.
     * @param _user The user to settle the redeem for.
     * @param _amount The amount to settle.
     * @dev redemptions are settled based on first-in first out basis. This means amount is attempted to be
     * redeemed from lead series, and then outstanding series in order until the total requested amount is
     * completely redeemed. The redemption of shares from each constituent series is called a redemption slice
     */
    function settleRedeemForUser(
        IAlephVault.ShareClass storage _shareClass,
        uint8 _classId,
        uint48 _batchId,
        address _user,
        uint256 _amount
    ) internal {
        // the amount requested is redeemed from the class in a first-in first-out basis
        // we first try to settle the redemption from the lead series
        // remaining amount is assets that were not settled in the lead series (this happens if user does not have
        // enough assets in the lead series to complete the redemption)
        uint256 _remainingAmount = _amount;
        uint32 _shareSeriesId = _shareClass.shareSeriesId;

        // we now iterate through all series to settle the remaining user amount
        for (uint32 _seriesId; _seriesId <= _shareSeriesId; _seriesId++) {
            // if the user request amount is settled completely, we break out of the loop
            if (_remainingAmount == 0) {
                break;
            }
            // we attempt to settle the remaining amount from this series
            // this continues to happen for all outstanding series until the complete amount is settled
            _remainingAmount = _settleRedeemSlice(_shareClass, _classId, _seriesId, _batchId, _user, _remainingAmount);
            if (_seriesId == SeriesAccounting.LEAD_SERIES_ID) {
                _seriesId = _shareClass.lastConsolidatedSeriesId;
            }
        }
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
     * @dev user shares are consolidated by preview minting the series shares and getting user assets
     * in that series. These assets are then minted shares in lead series based on the lead series PPS.
     */
    function _consolidateUserShares(
        IAlephVault.ShareSeries storage _leadSeries,
        IAlephVault.ShareSeries storage _shareSeries,
        uint8 _classId,
        uint32 _seriesId,
        uint48 _toBatchId
    ) private returns (uint256 _totalAmountToTransfer, uint256 _totalSharesToTransfer) {
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
            _userConsolidationDetails.amountToTransfer = ERC4626Math.previewRedeem(
                _userConsolidationDetails.shares, _shareSeries.totalAssets, _shareSeries.totalShares
            );
            // calculate corresponding shares to deposit in lead series
            _userConsolidationDetails.sharesToTransfer = ERC4626Math.previewDeposit(
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
                    && (_userConsolidationDetails.user != MANAGEMENT_FEE_RECIPIENT
                        && _userConsolidationDetails.user != PERFORMANCE_FEE_RECIPIENT)
            ) {
                _leadSeries.users.add(_userConsolidationDetails.user);
            }
            // remove user shares from the series
            delete _shareSeries.sharesOf[_userConsolidationDetails.user];
            emit IAlephVaultSettlement.UserSharesConsolidated(_userConsolidationDetails);
        }
    }

    /**
     * @dev Internal function to settle a redeem slice.
     * @param _shareClass The share class storage reference.
     * @param _classId The id of the class.
     * @param _seriesId The id of the series.
     * @param _batchId The id of the batch.
     * @param _user The user to settle the redeem for.
     * @param _amount The amount to settle.
     * @return _remainingAmount The remaining amount to redeem.
     */
    function _settleRedeemSlice(
        IAlephVault.ShareClass storage _shareClass,
        uint8 _classId,
        uint32 _seriesId,
        uint48 _batchId,
        address _user,
        uint256 _amount
    ) private returns (uint256 _remainingAmount) {
        _remainingAmount = _amount;
        IAlephVault.ShareSeries storage _shareSeries = _shareClass.shareSeries[_seriesId];
        // check total assets available in the series for the user
        uint256 _sharesInSeries = _shareSeries.sharesOf[_user];
        uint256 _amountInSeries =
            ERC4626Math.previewRedeem(_sharesInSeries, _shareSeries.totalAssets, _shareSeries.totalShares);
        // if the amount available in the series is less than or equal to the remaining amount, we settle the entire
        // amount in the series and move on to the next series by updating the remaining amount
        if (_amountInSeries <= _remainingAmount) {
            _remainingAmount -= _amountInSeries;
            // redeem the entire amount in the series and update the series total assets and shares
            _shareSeries.totalAssets -= _amountInSeries;
            _shareSeries.totalShares -= _sharesInSeries;
            _shareSeries.users.remove(_user);
            delete _shareSeries.sharesOf[_user];
            emit IAlephVaultSettlement.RedeemRequestSliceSettled(
                _classId, _seriesId, _batchId, _user, _amountInSeries, _sharesInSeries
            );
        } else {
            // if the amount available in the series is greater than or equal to the remaining amount,
            // we settle the remaining amount in the series and update the series total assets and shares
            uint256 _userSharesToBurn =
                ERC4626Math.previewWithdraw(_remainingAmount, _shareSeries.totalShares, _shareSeries.totalAssets);
            _shareSeries.totalAssets -= _remainingAmount;
            _shareSeries.totalShares -= _userSharesToBurn;
            _shareSeries.sharesOf[_user] -= _userSharesToBurn;
            emit IAlephVaultSettlement.RedeemRequestSliceSettled(
                _classId, _seriesId, _batchId, _user, _remainingAmount, _userSharesToBurn
            );
            // set the remaining amount to 0 as the entire amount has been settled and we break out of the loop
            _remainingAmount = 0;
        }
    }
}
