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

import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {AlephVaultStorage, AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract AlephVaultBase {
    using Math for uint256;

    uint32 public constant MAXIMUM_MANAGEMENT_FEE = 1000; // 10%
    uint32 public constant MAXIMUM_PERFORMANCE_FEE = 5000; // 50%
    uint48 public constant PRICE_DENOMINATOR = 1e6;

    uint48 public immutable BATCH_DURATION;

    error InvalidConstructorParams();

    constructor(uint48 _batchDuration) {
        if (_batchDuration == 0) {
            revert InvalidConstructorParams();
        }
        BATCH_DURATION = _batchDuration;
    }

    function _totalAssets() internal view returns (uint256) {
        uint256 _totalAssets;
        uint8 _shareClassesId = _getStorage().shareClassesId;
        if (_shareClassesId > 0) {
            for (uint8 _classId = 1; _classId <= _shareClassesId; _classId++) {
                _totalAssets += _totalAssetsPerClass(_classId);
            }
        }
        return _totalAssets;
    }

    function _totalShares() internal view returns (uint256) {
        uint256 _totalShares;
        uint8 _shareClassesId = _getStorage().shareClassesId;
        if (_shareClassesId > 0) {
            for (uint8 _classId = 1; _classId <= _shareClassesId; _classId++) {
                _totalShares += _totalSharesPerClass(_classId);
            }
        }
        return _totalShares;
    }

    /**
     * @dev Returns the total assets in the vault for a given class.
     * @param _classId The ID of the share class.
     * @return The total assets in the vault for the given class.
     */
    function _totalAssetsPerClass(uint8 _classId) internal view returns (uint256) {
        uint256 _totalAssets;
        for (uint8 _seriesId; _seriesId <= _getStorage().shareClasses[_classId].activeSeries; _seriesId++) {
            _totalAssets += _totalAssetsPerSeries(_classId, _seriesId);
        }
        return _totalAssets;
    }

    /**
     * @dev Returns the total shares in the vault for a given class.
     * @param _classId The ID of the share class.
     * @return The total shares in the vault for the given class.
     */
    function _totalSharesPerClass(uint8 _classId) internal view returns (uint256) {
        uint256 _totalShares;
        for (uint8 _seriesId; _seriesId <= _getStorage().shareClasses[_classId].activeSeries; _seriesId++) {
            _totalShares += _totalSharesPerSeries(_classId, _seriesId);
        }
        return _totalShares;
    }

    /**
     * @dev Returns the total assets in the vault.
     * @param _classId The ID of the share class.
     * @param _seriesId The ID of the share series.
     * @return The total assets in the vault.
     */
    function _totalAssetsPerSeries(uint8 _classId, uint8 _seriesId) internal view returns (uint256) {
        return _getStorage().shareClasses[_classId].shareSeries[_seriesId].totalAssets;
    }

    /**
     * @dev Returns the total shares in the vault.
     * @param _classId The ID of the share class.
     * @param _seriesId The ID of the share series.
     * @return The total shares in the vault.
     */
    function _totalSharesPerSeries(uint8 _classId, uint8 _seriesId) internal view returns (uint256) {
        return _getStorage().shareClasses[_classId].shareSeries[_seriesId].totalShares;
    }

    /**
     * @dev Returns the shares of a user.
     * @param _classId The ID of the share class.
     * @param _seriesId The ID of the share series.
     * @param _user The user to get the shares of.
     * @return The shares of the user.
     */
    function _sharesOf(uint8 _classId, uint8 _seriesId, address _user) internal view returns (uint256) {
        return _getStorage().shareClasses[_classId].shareSeries[_seriesId].sharesOf[_user];
    }

    /**
     * @dev Returns the current batch.
     * @return The current batch.
     */
    function _currentBatch() internal view returns (uint48) {
        AlephVaultStorageData storage _sd = _getStorage();
        return (Time.timestamp() - _sd.startTimeStamp) / BATCH_DURATION;
    }

    /**
     * @dev Returns the high water mark.
     * @param _classId The ID of the share class.
     * @param _seriesId The ID of the share series.
     * @return The high water mark.
     */
    function _highWaterMark(uint8 _classId, uint8 _seriesId) internal view returns (uint256) {
        return _getStorage().shareClasses[_classId].shareSeries[_seriesId].highWaterMark;
    }

    /**
     * @dev Returns the lead high water mark.
     * @param _classId The ID of the share class.
     * @return The high water mark of the lead series.
     */
    function _leadHighWaterMark(uint8 _classId) internal view returns (uint256) {
        return _highWaterMark(_classId, 0);
    }

    /**
     * @dev Returns the lead price per share.
     * @param _classId The ID of the share class.
     * @return The price per share of the lead series.
     */
    function _leadPricePerShare(uint8 _classId) internal view returns (uint256) {
        return _getPricePerShare(_totalAssetsPerSeries(_classId, 0), _totalSharesPerSeries(_classId, 0));
    }

    /**
     * @dev Returns the total amount to deposit.
     * @param _classId The ID of the share class.
     * @return The total amount to deposit.
     */
    function _totalAmountToDepositPerClass(uint8 _classId) internal view returns (uint256) {
        uint256 _amountToDeposit;
        uint48 _currentBatchId = _currentBatch();
        if (_currentBatchId > 0) {
            AlephVaultStorageData storage _sd = _getStorage();
            uint48 _depositSettleId = _sd.shareClasses[_classId].depositSettleId;
            for (_depositSettleId; _depositSettleId <= _currentBatchId; _depositSettleId++) {
                _amountToDeposit += _sd.shareClasses[_classId].depositRequests[_depositSettleId].totalAmountToDeposit;
            }
        }
        return _amountToDeposit;
    }

    /**
     * @dev Internal function to get the price per share.
     * @param _assets The total assets in the vault.
     * @param _shares The total shares in the vault.
     * @return The price per share.
     */
    function _getPricePerShare(uint256 _assets, uint256 _shares) public pure returns (uint256) {
        uint256 _pricePerShare;
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
