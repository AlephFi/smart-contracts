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
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IFeeManager} from "./interfaces/IFeeManager.sol";
import {ERC4626Math} from "./libraries/ERC4626Math.sol";
import {TimelockRegistry} from "./libraries/TimelockRegistry.sol";
import {Checkpoints} from "./libraries/Checkpoints.sol";
import {AlephVaultStorageData} from "./AlephVaultStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
abstract contract FeeManager is IFeeManager {
    using SafeERC20 for IERC20;
    using Checkpoints for Checkpoints.Trace256;
    using Math for uint256;

    uint32 public immutable MAXIMUM_MANAGEMENT_FEE;
    uint32 public immutable MAXIMUM_PERFORMANCE_FEE;
    uint48 public immutable MANAGEMENT_FEE_TIMELOCK;
    uint48 public immutable PERFORMANCE_FEE_TIMELOCK;
    uint48 public immutable FEE_RECIPIENT_TIMELOCK;

    uint48 public constant ONE_YEAR = 365 days;
    uint48 public constant BPS_DENOMINATOR = 10_000;
    uint48 public constant PRICE_DENOMINATOR = 1e6;

    /**
     * @dev Returns the storage struct for the vault.
     */
    function _getStorage() internal pure virtual returns (AlephVaultStorageData storage sd);

    /**
     * @notice Returns the total assets in the vault.
     */
    function totalAssets() public view virtual returns (uint256);

    /**
     * @notice Returns the total shares issued by the vault.
     */
    function totalShares() public view virtual returns (uint256);

    /**
     * @notice Returns the number of shares owned by a user.
     * @param _user The address of the user.
     */
    function sharesOf(address _user) public view virtual returns (uint256);

    /// @inheritdoc IFeeManager
    function queueManagementFee(uint32 _managementFee) external virtual;

    /// @inheritdoc IFeeManager
    function queuePerformanceFee(uint32 _performanceFee) external virtual;

    /// @inheritdoc IFeeManager
    function queueFeeRecipient(address _feeRecipient) external virtual;

    /// @inheritdoc IFeeManager
    function setManagementFee() external virtual;

    /// @inheritdoc IFeeManager
    function setPerformanceFee() external virtual;

    /// @inheritdoc IFeeManager
    function setFeeRecipient() external virtual;

    ///@inheritdoc IFeeManager
    function collectFees() external virtual;

    /**
     * @dev Internal function to queue a new management fee.
     * @param _managementFee The new management fee to be set.
     */
    function _queueManagementFee(uint32 _managementFee) internal {
        if (_managementFee > MAXIMUM_MANAGEMENT_FEE) {
            revert InvalidManagementFee();
        }
        _getStorage().timelocks[TimelockRegistry.MANAGEMENT_FEE] = TimelockRegistry.Timelock({
            unlockTimestamp: Time.timestamp() + MANAGEMENT_FEE_TIMELOCK,
            newValue: abi.encode(_managementFee)
        });
        emit NewManagementFeeQueued(_managementFee);
    }

    /**
     * @dev Internal function to queue a new performance fee.
     * @param _performanceFee The new performance fee to be set.
     */
    function _queuePerformanceFee(uint32 _performanceFee) internal {
        if (_performanceFee > MAXIMUM_PERFORMANCE_FEE) {
            revert InvalidPerformanceFee();
        }
        _getStorage().timelocks[TimelockRegistry.PERFORMANCE_FEE] = TimelockRegistry.Timelock({
            unlockTimestamp: Time.timestamp() + PERFORMANCE_FEE_TIMELOCK,
            newValue: abi.encode(_performanceFee)
        });
        emit NewPerformanceFeeQueued(_performanceFee);
    }

    /**
     * @dev Internal function to queue a new fee recipient.
     * @param _feeRecipient The new fee recipient to be set.
     */
    function _queueFeeRecipient(address _feeRecipient) internal {
        _getStorage().timelocks[TimelockRegistry.FEE_RECIPIENT] = TimelockRegistry.Timelock({
            unlockTimestamp: Time.timestamp() + FEE_RECIPIENT_TIMELOCK,
            newValue: abi.encode(_feeRecipient)
        });
        emit NewFeeRecipientQueued(_feeRecipient);
    }

    /**
     * @dev Internal function to set the management fee.
     */
    function _setManagementFee() internal {
        AlephVaultStorageData storage _sd = _getStorage();
        uint32 _managementFee = abi.decode(TimelockRegistry.setTimelock(_sd, TimelockRegistry.MANAGEMENT_FEE), (uint32));
        _sd.managementFee = _managementFee;
        emit NewManagementFeeSet(_managementFee);
    }

    /**
     * @dev Internal function to set the performance fee.
     */
    function _setPerformanceFee() internal {
        AlephVaultStorageData storage _sd = _getStorage();
        uint32 _performanceFee =
            abi.decode(TimelockRegistry.setTimelock(_sd, TimelockRegistry.PERFORMANCE_FEE), (uint32));
        _sd.performanceFee = _performanceFee;
        emit NewPerformanceFeeSet(_performanceFee);
    }

    /**
     * @dev Internal function to set the fee recipient.
     */
    function _setFeeRecipient() internal {
        AlephVaultStorageData storage _sd = _getStorage();
        address _feeRecipient = abi.decode(TimelockRegistry.setTimelock(_sd, TimelockRegistry.FEE_RECIPIENT), (address));
        _sd.feeRecipient = _feeRecipient;
        emit NewFeeRecipientSet(_feeRecipient);
    }

    function _accumulateFees(
        AlephVaultStorageData storage _sd,
        uint256 _newTotalAssets,
        uint48 _currentBatchId,
        uint48 _timestamp
    ) internal returns (uint256 _managementFee, uint256 _performanceFee) {
        if (_newTotalAssets > 0) {
            uint256 _totalShares = totalShares();
            _managementFee = _calculateManagementFee(_sd, _newTotalAssets, _currentBatchId - _sd.lastFeePaidId);
            _performanceFee = _calculatePerformanceFee(_sd, _newTotalAssets, _totalShares);
            uint256 _feesToCollect = _managementFee + _performanceFee;
            uint256 _sharesToMint = ERC4626Math.previewDeposit(_feesToCollect, _totalShares, _newTotalAssets);
            address _feeRecipient = _sd.feeRecipient;
            _sd.sharesOf[_feeRecipient].push(_timestamp, sharesOf(_feeRecipient) + _sharesToMint);
            _sd.shares.push(_timestamp, _totalShares + _sharesToMint);
            emit FeesAccumulated(_managementFee, _performanceFee, _timestamp);
        }
        _sd.lastFeePaidId = _currentBatchId;
    }

    /**
     * @dev Internal function to calculate the management fee.
     * @param _sd The storage struct for the vault.
     * @param _newTotalAssets The new total assets after collection.
     * @return _managementFee The management fee to be collected.
     */
    function _calculateManagementFee(AlephVaultStorageData storage _sd, uint256 _newTotalAssets, uint48 _batchesElapsed)
        internal
        view
        returns (uint256 _managementFee)
    {
        uint256 _annualFees =
            _newTotalAssets.mulDiv(uint256(_sd.managementFee), uint256(BPS_DENOMINATOR), Math.Rounding.Ceil);
        _managementFee =
            _annualFees.mulDiv(uint256(_batchesElapsed * _sd.batchDuration), uint256(ONE_YEAR), Math.Rounding.Ceil);
    }

    /**
     * @dev Internal function to calculate the performance fee.
     * @param _sd The storage struct for the vault.
     * @param _newTotalAssets The new total assets after collection.
     * @return _performanceFee The performance fee to be collected.
     */
    function _calculatePerformanceFee(AlephVaultStorageData storage _sd, uint256 _newTotalAssets, uint256 _totalShares)
        internal
        returns (uint256 _performanceFee)
    {
        uint256 _pricePerShare = _newTotalAssets.mulDiv(PRICE_DENOMINATOR, _totalShares, Math.Rounding.Ceil);
        uint256 _highWaterMark = _sd.highWaterMark;
        if (_pricePerShare > _highWaterMark) {
            uint256 _profitPerShare = _pricePerShare - _highWaterMark;
            uint256 _profit = _profitPerShare.mulDiv(_totalShares, PRICE_DENOMINATOR, Math.Rounding.Ceil);
            _performanceFee = _profit.mulDiv(uint256(_sd.performanceFee), uint256(BPS_DENOMINATOR), Math.Rounding.Ceil);
            _sd.highWaterMark = _pricePerShare;
            emit NewHighWaterMarkSet(_pricePerShare);
        }
    }

    /**
     * @dev Internal function to collect all pending fees.
     */
    function _collectFees() internal {
        AlephVaultStorageData storage _sd = _getStorage();
        address _feeRecipient = _sd.feeRecipient;
        uint256 _shares = sharesOf(_feeRecipient);
        uint256 _totalShares = totalShares();
        uint256 _totalAssets = totalAssets();
        uint256 _feesToCollect = ERC4626Math.previewRedeem(_shares, _totalAssets, _totalShares);
        uint48 _timestamp = Time.timestamp();
        _sd.sharesOf[_feeRecipient].push(_timestamp, 0);
        _sd.shares.push(_timestamp, _totalShares - _shares);
        _sd.assets.push(_timestamp, _totalAssets - _feesToCollect);
        IERC20(_sd.underlyingToken).safeTransfer(_feeRecipient, _feesToCollect);
        emit FeesCollected(_feesToCollect);
    }
}
