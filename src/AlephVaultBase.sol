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
import {Checkpoints} from "@aleph-vault/libraries/Checkpoints.sol";
import {AlephVaultStorage, AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";

abstract contract AlephVaultBase {
    using Checkpoints for Checkpoints.Trace256;
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

    /**
     * @dev Returns the total assets in the vault.
     * @return The total assets in the vault.
     */
    function _totalAssets() internal view returns (uint256) {
        return _getStorage().assets.latest();
    }

    /**
     * @dev Returns the total shares in the vault.
     * @return The total shares in the vault.
     */
    function _totalShares() internal view returns (uint256) {
        return _getStorage().shares.latest();
    }

    /**
     * @dev Returns the shares of a user.
     * @param _user The user to get the shares of.
     * @return The shares of the user.
     */
    function _sharesOf(address _user) internal view returns (uint256) {
        return _getStorage().sharesOf[_user].latest();
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
     * @return The high water mark.
     */
    function _highWaterMark() internal view returns (uint256) {
        return _getStorage().highWaterMark.latest();
    }

    /**
     * @dev Returns the total amount to deposit.
     * @return The total amount to deposit.
     */
    function _totalAmountToDeposit() internal view returns (uint256) {
        uint256 _amountToDeposit;
        uint48 _currentBatchId = _currentBatch();
        if (_currentBatchId > 0) {
            AlephVaultStorageData storage _sd = _getStorage();
            uint48 _depositSettleId = _sd.depositSettleId;
            for (_depositSettleId; _depositSettleId <= _currentBatchId; _depositSettleId++) {
                _amountToDeposit += _sd.batches[_depositSettleId].totalAmountToDeposit;
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
