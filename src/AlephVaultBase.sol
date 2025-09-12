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

import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {ReentrancyGuardUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {AlephVaultStorage, AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract AlephVaultBase is ReentrancyGuardUpgradeable {
    using Math for uint256;

    uint8 public constant LEAD_SERIES_ID = 0;
    uint32 public constant MAXIMUM_MANAGEMENT_FEE = 1000; // 10%
    uint32 public constant MAXIMUM_PERFORMANCE_FEE = 5000; // 50%
    uint48 public constant PRICE_DENOMINATOR = 1e6;
    address public constant MANAGEMENT_FEE_RECIPIENT = address(bytes20(keccak256("MANAGEMENT_FEE_RECIPIENT")));
    address public constant PERFORMANCE_FEE_RECIPIENT = address(bytes20(keccak256("PERFORMANCE_FEE_RECIPIENT")));

    uint48 public immutable BATCH_DURATION;

    error InvalidConstructorParams();

    constructor(uint48 _batchDuration) {
        if (_batchDuration == 0) {
            revert InvalidConstructorParams();
        }
        BATCH_DURATION = _batchDuration;
    }

    /**
     * @dev Returns the total assets in the vault.
     * @param _sd The storage struct.
     * @return The total assets in the vault.
     */
    function _totalAssets(AlephVaultStorageData storage _sd) internal view returns (uint256) {
        uint256 _totalAssets;
        uint8 _shareClassesId = _sd.shareClassesId;
        for (uint8 _classId = 1; _classId <= _shareClassesId; _classId++) {
            IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_classId];
            _totalAssets += _totalAssetsPerClass(_shareClass, _classId);
        }
        return _totalAssets;
    }

    /**
     * @dev Returns the total assets in the vault for a given class.
     * @param _shareClass The share class.
     * @param _classId The ID of the share class.
     * @return The total assets in the vault for the given class.
     */
    function _totalAssetsPerClass(IAlephVault.ShareClass storage _shareClass, uint8 _classId)
        internal
        view
        returns (uint256)
    {
        uint8 _lastConsolidatedSeriesId = _shareClass.lastConsolidatedSeriesId;
        uint256 _totalAssets;
        for (uint8 _seriesId; _seriesId <= _shareClass.shareSeriesId; _seriesId++) {
            if (_seriesId > LEAD_SERIES_ID) {
                _seriesId += _lastConsolidatedSeriesId;
            }
            // loop through all share series and sum up the total assets
            _totalAssets += _totalAssetsPerSeries(_shareClass, _classId, _seriesId);
        }
        return _totalAssets;
    }

    /**
     * @dev Returns the total assets in the vault.
     * @param _shareClass The share class.
     * @param _classId The ID of the share class.
     * @param _seriesId The ID of the share series.
     * @return The total assets in the vault.
     */
    function _totalAssetsPerSeries(IAlephVault.ShareClass storage _shareClass, uint8 _classId, uint8 _seriesId)
        internal
        view
        returns (uint256)
    {
        return _shareClass.shareSeries[_seriesId].totalAssets;
    }

    /**
     * @dev Returns the total shares in the vault.
     * @param _shareClass The share class.
     * @param _classId The ID of the share class.
     * @param _seriesId The ID of the share series.
     * @return The total shares in the vault.
     */
    function _totalSharesPerSeries(IAlephVault.ShareClass storage _shareClass, uint8 _classId, uint8 _seriesId)
        internal
        view
        returns (uint256)
    {
        return _shareClass.shareSeries[_seriesId].totalShares;
    }

    /**
     * @dev Returns the shares of a user.
     * @param _shareClass The share class.
     * @param _seriesId The ID of the share series.
     * @param _user The user to get the shares of.
     * @return The shares of the user.
     */
    function _sharesOf(IAlephVault.ShareClass storage _shareClass, uint8 _seriesId, address _user)
        internal
        view
        returns (uint256)
    {
        return _shareClass.shareSeries[_seriesId].sharesOf[_user];
    }

    /**
     * @dev Returns the assets of a user.
     * @param _shareClass The share class.
     * @param _classId The ID of the share class.
     * @param _seriesId The ID of the share series.
     * @param _user The user to get the assets of.
     * @return The assets of the user.
     */
    function _assetsOf(IAlephVault.ShareClass storage _shareClass, uint8 _classId, uint8 _seriesId, address _user)
        internal
        view
        returns (uint256)
    {
        return ERC4626Math.previewRedeem(
            _sharesOf(_shareClass, _seriesId, _user),
            _totalAssetsPerSeries(_shareClass, _classId, _seriesId),
            _totalSharesPerSeries(_shareClass, _classId, _seriesId)
        );
    }

    /**
     * @dev Returns the assets of a user per class.
     * @param _classId The ID of the share class.
     * @param _user The user to get the assets of.
     * @return The assets of the user per class.
     */
    function _assetsPerClassOf(uint8 _classId, address _user, IAlephVault.ShareClass storage _shareClass)
        internal
        view
        returns (uint256)
    {
        uint256 _assets;
        uint8 _lastConsolidatedSeriesId = _shareClass.lastConsolidatedSeriesId;
        uint8 _shareSeriesId = _shareClass.shareSeriesId;
        for (uint8 _seriesId; _seriesId <= _shareSeriesId; _seriesId++) {
            if (_seriesId > LEAD_SERIES_ID) {
                _seriesId += _lastConsolidatedSeriesId;
            }
            // loop through all share series and sum up the assets
            _assets += _assetsOf(_shareClass, _classId, _seriesId, _user);
        }
        return _assets;
    }

    /**
     * @dev Returns the current batch.
     * @param _sd The storage struct.
     * @return The current batch.
     */
    function _currentBatch(AlephVaultStorageData storage _sd) internal view returns (uint48) {
        return (Time.timestamp() - _sd.startTimeStamp) / BATCH_DURATION;
    }

    /**
     * @dev Returns the lead price per share.
     * @param _shareClass The share class.
     * @param _classId The ID of the share class.
     * @return The price per share of the lead series.
     */
    function _leadPricePerShare(IAlephVault.ShareClass storage _shareClass, uint8 _classId)
        internal
        view
        returns (uint256)
    {
        return _getPricePerShare(
            _totalAssetsPerSeries(_shareClass, _classId, LEAD_SERIES_ID),
            _totalSharesPerSeries(_shareClass, _classId, LEAD_SERIES_ID)
        );
    }

    /**
     * @dev Returns the total amount to deposit.
     * @param _sd The storage struct.
     * @param _classId The ID of the share class.
     * @return The total amount to deposit.
     */
    function _totalAmountToDeposit(AlephVaultStorageData storage _sd, uint8 _classId) internal view returns (uint256) {
        uint256 _amountToDeposit;
        IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_classId];
        uint48 _currentBatchId = _currentBatch(_sd);
        uint48 _depositSettleId = _shareClass.depositSettleId;
        for (_depositSettleId; _depositSettleId <= _currentBatchId; _depositSettleId++) {
            _amountToDeposit += _shareClass.depositRequests[_depositSettleId].totalAmountToDeposit;
        }
        return _amountToDeposit;
    }

    /**
     * @dev Returns the total amount to deposit.
     * @param _sd The storage struct.
     * @param _classId The ID of the share class.
     * @param _user The user to get the deposit request of.
     * @return The total amount to deposit.
     */
    function _depositRequestOf(AlephVaultStorageData storage _sd, uint8 _classId, address _user)
        internal
        view
        returns (uint256)
    {
        uint256 _totalDepositRequest;
        uint48 _currentBatch = _currentBatch(_sd);
        IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_classId];
        uint48 _depositSettleId = _shareClass.depositSettleId;
        for (_depositSettleId; _depositSettleId <= _currentBatch; _depositSettleId++) {
            _totalDepositRequest += _shareClass.depositRequests[_depositSettleId].depositRequest[_user];
        }
        return _totalDepositRequest;
    }

    /**
     * @dev Internal function to calculate the pending assets of a user.
     * @param _shareClass The share class.
     * @param _classId The class ID to redeem from.
     * @param _currentBatchId The current batch ID.
     * @param _user The user to calculate the pending assets for.
     * @param _totalUserAssets The total assets of the user.
     * @return _pendingAssets The pending assets of the user.
     */
    function _pendingAssetsOf(
        IAlephVault.ShareClass storage _shareClass,
        uint8 _classId,
        uint48 _currentBatchId,
        address _user,
        uint256 _totalUserAssets
    ) internal view returns (uint256 _pendingAssets) {
        uint48 _redeemSettleId = _shareClass.redeemSettleId;
        uint256 _remainingUserAssets = _totalUserAssets;
        // loop through all batches up to the current batch and sum up the pending assets for redemption
        for (uint48 _batchId = _redeemSettleId; _batchId <= _currentBatchId; _batchId++) {
            // redeem request sets the proportion of total user assets to redeem at the time of settlement
            uint256 _pendingUserAssetsInBatch = ERC4626Math.previewMintUnits(
                _shareClass.redeemRequests[_batchId].redeemRequest[_user], _remainingUserAssets
            );
            // redeem request is set calculated proportional to remaining user assets as if previous redeem requests were settled
            _remainingUserAssets -= _pendingUserAssetsInBatch;
            _pendingAssets += _pendingUserAssetsInBatch;
        }
    }

    /**
     * @dev Internal function to get the price per share.
     * @param _assets The total assets in the vault.
     * @param _shares The total shares in the vault.
     * @return The price per share.
     */
    function _getPricePerShare(uint256 _assets, uint256 _shares) public pure returns (uint256) {
        uint256 _pricePerShare = PRICE_DENOMINATOR;
        if (_shares > 0) {
            _pricePerShare = _assets.mulDiv(PRICE_DENOMINATOR, _shares, Math.Rounding.Ceil);
        }
        return _pricePerShare;
    }

    /**
     * @dev Returns the storage struct for the vault.
     * @return _sd The storage struct.
     */
    function _getStorage() internal pure returns (AlephVaultStorageData storage _sd) {
        _sd = AlephVaultStorage.load();
    }
}
