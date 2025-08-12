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
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {TimelockRegistry} from "@aleph-vault/libraries/TimelockRegistry.sol";
import {Checkpoints} from "@aleph-vault/libraries/Checkpoints.sol";
import {AlephVaultBase} from "@aleph-vault/AlephVaultBase.sol";
import {AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract FeeManager is IFeeManager, AlephVaultBase {
    using SafeERC20 for IERC20;
    using Checkpoints for Checkpoints.Trace256;
    using Math for uint256;

    uint48 public immutable MANAGEMENT_FEE_TIMELOCK;
    uint48 public immutable PERFORMANCE_FEE_TIMELOCK;
    uint48 public immutable FEE_RECIPIENT_TIMELOCK;

    uint48 public constant ONE_YEAR = 365 days;
    uint48 public constant BPS_DENOMINATOR = 10_000;
    address public constant MANAGEMENT_FEE_RECIPIENT = address(bytes20(keccak256("MANAGEMENT_FEE_RECIPIENT")));
    address public constant PERFORMANCE_FEE_RECIPIENT = address(bytes20(keccak256("PERFORMANCE_FEE_RECIPIENT")));

    constructor(
        uint48 _managementFeeTimelock,
        uint48 _performanceFeeTimelock,
        uint48 _feeRecipientTimelock,
        uint48 _batchDuration
    ) AlephVaultBase(_batchDuration) {
        if (_managementFeeTimelock == 0 || _performanceFeeTimelock == 0 || _feeRecipientTimelock == 0) {
            revert InvalidConstructorParams();
        }
        MANAGEMENT_FEE_TIMELOCK = _managementFeeTimelock;
        PERFORMANCE_FEE_TIMELOCK = _performanceFeeTimelock;
        FEE_RECIPIENT_TIMELOCK = _feeRecipientTimelock;
    }

    /// @inheritdoc IFeeManager
    function queueManagementFee(uint32 _managementFee) external {
        _queueManagementFee(_getStorage(), _managementFee);
    }

    /// @inheritdoc IFeeManager
    function queuePerformanceFee(uint32 _performanceFee) external {
        _queuePerformanceFee(_getStorage(), _performanceFee);
    }

    /// @inheritdoc IFeeManager
    function queueFeeRecipient(address _feeRecipient) external {
        _queueFeeRecipient(_getStorage(), _feeRecipient);
    }

    /// @inheritdoc IFeeManager
    function setManagementFee() external {
        _setManagementFee(_getStorage());
    }

    /// @inheritdoc IFeeManager
    function setPerformanceFee() external {
        _setPerformanceFee(_getStorage());
    }

    /// @inheritdoc IFeeManager
    function setFeeRecipient() external {
        _setFeeRecipient(_getStorage());
    }

    ///@inheritdoc IFeeManager
    function accumulateFees(uint256 _newTotalAssets, uint48 _currentBatchId, uint48 _lastFeePaidId, uint48 _timestamp)
        external
        returns (uint256)
    {
        return _accumulateFees(_getStorage(), _newTotalAssets, _currentBatchId, _lastFeePaidId, _timestamp);
    }

    ///@inheritdoc IFeeManager
    function initializeHighWaterMark(uint256 _totalAssets, uint256 _totalShares, uint48 _timestamp) external {
        _initializeHighWaterMark(_getStorage(), _totalAssets, _totalShares, _timestamp);
    }

    ///@inheritdoc IFeeManager
    function getManagementFeeShares(uint256 _newTotalAssets, uint256 _totalShares, uint48 _batchesElapsed)
        external
        view
        returns (uint256 _managementFeeShares)
    {
        return ERC4626Math.previewDeposit(
            _calculateManagementFeeAmount(_getStorage(), _newTotalAssets, _batchesElapsed),
            _totalShares,
            _newTotalAssets
        );
    }

    ///@inheritdoc IFeeManager
    function getPerformanceFeeShares(uint256 _newTotalAssets, uint256 _totalShares)
        external
        view
        returns (uint256 _performanceFeeShares)
    {
        uint256 _pricePerShare = _getPricePerShare(_newTotalAssets, _totalShares);
        uint256 _highWaterMark = _highWaterMark();
        if (_highWaterMark == 0) {
            return 0;
        }
        uint256 _performanceFeeAmount = _pricePerShare > _highWaterMark
            ? _calculatePerformanceFeeAmount(_pricePerShare, _highWaterMark, _totalShares, _getStorage().performanceFee)
            : 0;
        return ERC4626Math.previewDeposit(_performanceFeeAmount, _totalShares, _newTotalAssets);
    }

    ///@inheritdoc IFeeManager
    function collectFees() external {
        _collectFees(_getStorage());
    }

    /**
     * @dev Internal function to queue a new management fee.
     * @param _managementFee The new management fee to be set.
     */
    function _queueManagementFee(AlephVaultStorageData storage _sd, uint32 _managementFee) internal {
        if (_managementFee > MAXIMUM_MANAGEMENT_FEE) {
            revert InvalidManagementFee();
        }
        _sd.timelocks[TimelockRegistry.MANAGEMENT_FEE] = TimelockRegistry.Timelock({
            unlockTimestamp: Time.timestamp() + MANAGEMENT_FEE_TIMELOCK,
            newValue: abi.encode(_managementFee)
        });
        emit NewManagementFeeQueued(_managementFee);
    }

    /**
     * @dev Internal function to queue a new performance fee.
     * @param _performanceFee The new performance fee to be set.
     */
    function _queuePerformanceFee(AlephVaultStorageData storage _sd, uint32 _performanceFee) internal {
        if (_performanceFee > MAXIMUM_PERFORMANCE_FEE) {
            revert InvalidPerformanceFee();
        }
        _sd.timelocks[TimelockRegistry.PERFORMANCE_FEE] = TimelockRegistry.Timelock({
            unlockTimestamp: Time.timestamp() + PERFORMANCE_FEE_TIMELOCK,
            newValue: abi.encode(_performanceFee)
        });
        emit NewPerformanceFeeQueued(_performanceFee);
    }

    /**
     * @dev Internal function to queue a new fee recipient.
     * @param _feeRecipient The new fee recipient to be set.
     */
    function _queueFeeRecipient(AlephVaultStorageData storage _sd, address _feeRecipient) internal {
        _sd.timelocks[TimelockRegistry.FEE_RECIPIENT] = TimelockRegistry.Timelock({
            unlockTimestamp: Time.timestamp() + FEE_RECIPIENT_TIMELOCK,
            newValue: abi.encode(_feeRecipient)
        });
        emit NewFeeRecipientQueued(_feeRecipient);
    }

    /**
     * @dev Internal function to set the management fee.
     */
    function _setManagementFee(AlephVaultStorageData storage _sd) internal {
        uint32 _managementFee = abi.decode(TimelockRegistry.setTimelock(_sd, TimelockRegistry.MANAGEMENT_FEE), (uint32));
        _sd.managementFee = _managementFee;
        emit NewManagementFeeSet(_managementFee);
    }

    /**
     * @dev Internal function to set the performance fee.
     */
    function _setPerformanceFee(AlephVaultStorageData storage _sd) internal {
        uint32 _performanceFee =
            abi.decode(TimelockRegistry.setTimelock(_sd, TimelockRegistry.PERFORMANCE_FEE), (uint32));
        _sd.performanceFee = _performanceFee;
        emit NewPerformanceFeeSet(_performanceFee);
    }

    /**
     * @dev Internal function to set the fee recipient.
     */
    function _setFeeRecipient(AlephVaultStorageData storage _sd) internal {
        address _feeRecipient = abi.decode(TimelockRegistry.setTimelock(_sd, TimelockRegistry.FEE_RECIPIENT), (address));
        _sd.feeRecipient = _feeRecipient;
        emit NewFeeRecipientSet(_feeRecipient);
    }

    function _accumulateFees(
        AlephVaultStorageData storage _sd,
        uint256 _newTotalAssets,
        uint48 _currentBatchId,
        uint48 _lastFeePaidId,
        uint48 _timestamp
    ) internal returns (uint256) {
        _sd.lastFeePaidId = _currentBatchId;
        if (_newTotalAssets > 0) {
            uint256 _totalShares = _totalShares();
            uint256 _managementFeeAmount =
                _calculateManagementFeeAmount(_sd, _newTotalAssets, _currentBatchId - _lastFeePaidId);
            uint256 _performanceFeeAmount = _checkPerformanceFeeAmount(_sd, _newTotalAssets, _totalShares, _timestamp);
            uint256 _managementSharesToMint =
                ERC4626Math.previewDeposit(_managementFeeAmount, _totalShares, _newTotalAssets);
            uint256 _performanceSharesToMint =
                ERC4626Math.previewDeposit(_performanceFeeAmount, _totalShares, _newTotalAssets);
            _sd.sharesOf[MANAGEMENT_FEE_RECIPIENT].push(
                _timestamp, _sharesOf(MANAGEMENT_FEE_RECIPIENT) + _managementSharesToMint
            );
            if (_performanceSharesToMint > 0) {
                _sd.sharesOf[PERFORMANCE_FEE_RECIPIENT].push(
                    _timestamp, _sharesOf(PERFORMANCE_FEE_RECIPIENT) + _performanceSharesToMint
                );
            }
            emit FeesAccumulated(_lastFeePaidId, _currentBatchId, _managementFeeAmount, _performanceFeeAmount);
            return _managementSharesToMint + _performanceSharesToMint;
        }
        return 0;
    }

    /**
     * @dev Internal function to calculate the management fee amount.
     * @param _sd The storage struct for the vault.
     * @param _newTotalAssets The new total assets after collection.
     * @return _managementFeeAmount The management fee to be collected.
     */
    function _calculateManagementFeeAmount(
        AlephVaultStorageData storage _sd,
        uint256 _newTotalAssets,
        uint48 _batchesElapsed
    ) internal view returns (uint256 _managementFeeAmount) {
        uint48 _managementFeeRate = _sd.managementFee;
        uint256 _annualFees =
            _newTotalAssets.mulDiv(uint256(_managementFeeRate), uint256(BPS_DENOMINATOR), Math.Rounding.Ceil);
        _managementFeeAmount =
            _annualFees.mulDiv(uint256(_batchesElapsed * BATCH_DURATION), uint256(ONE_YEAR), Math.Rounding.Ceil);
    }

    /**
     * @dev Internal function to calculate the performance fee amount.
     * @param _sd The storage struct for the vault.
     * @param _newTotalAssets The new total assets after collection.
     * @return _performanceFeeAmount The performance fee to be collected.
     */
    function _checkPerformanceFeeAmount(
        AlephVaultStorageData storage _sd,
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint48 _timestamp
    ) internal returns (uint256 _performanceFeeAmount) {
        uint256 _pricePerShare = _getPricePerShare(_newTotalAssets, _totalShares);
        uint256 _highWaterMark = _highWaterMark();
        if (_pricePerShare > _highWaterMark) {
            _performanceFeeAmount =
                _calculatePerformanceFeeAmount(_pricePerShare, _highWaterMark, _totalShares, _sd.performanceFee);
            _sd.highWaterMark.push(_timestamp, _pricePerShare);
            emit NewHighWaterMarkSet(_pricePerShare);
        }
    }

    function _calculatePerformanceFeeAmount(
        uint256 _pricePerShare,
        uint256 _highWaterMark,
        uint256 _totalShares,
        uint48 _performanceFeeRate
    ) internal pure returns (uint256 _performanceFeeAmount) {
        uint256 _profitPerShare = _pricePerShare - _highWaterMark;
        uint256 _profit = _profitPerShare.mulDiv(_totalShares, PRICE_DENOMINATOR, Math.Rounding.Ceil);
        _performanceFeeAmount = _profit.mulDiv(
            uint256(_performanceFeeRate), uint256(BPS_DENOMINATOR - _performanceFeeRate), Math.Rounding.Ceil
        );
    }

    function _initializeHighWaterMark(
        AlephVaultStorageData storage _sd,
        uint256 _totalAssets,
        uint256 _totalShares,
        uint48 _timestamp
    ) internal {
        uint256 _pricePerShare = _getPricePerShare(_totalAssets, _totalShares);
        _sd.highWaterMark.push(_timestamp, _pricePerShare);
        emit NewHighWaterMarkSet(_pricePerShare);
    }

    /**
     * @dev Internal function to collect all pending fees.
     */
    function _collectFees(AlephVaultStorageData storage _sd) internal {
        uint256 _managementShares = _sharesOf(MANAGEMENT_FEE_RECIPIENT);
        uint256 _performanceShares = _sharesOf(PERFORMANCE_FEE_RECIPIENT);
        uint256 _totalShares = _totalShares();
        uint256 _totalAssets = _totalAssets();
        uint256 _managementFeesToCollect = ERC4626Math.previewRedeem(_managementShares, _totalAssets, _totalShares);
        uint256 _performanceFeesToCollect = ERC4626Math.previewRedeem(_performanceShares, _totalAssets, _totalShares);
        uint48 _timestamp = Time.timestamp();
        _sd.sharesOf[MANAGEMENT_FEE_RECIPIENT].push(_timestamp, 0);
        _sd.sharesOf[PERFORMANCE_FEE_RECIPIENT].push(_timestamp, 0);
        _sd.shares.push(_timestamp, _totalShares - _managementShares - _performanceShares);
        _sd.assets.push(_timestamp, _totalAssets - _managementFeesToCollect - _performanceFeesToCollect);
        IERC20(_sd.underlyingToken).safeTransfer(_sd.feeRecipient, _managementFeesToCollect + _performanceFeesToCollect);
        emit FeesCollected(_managementFeesToCollect, _performanceFeesToCollect);
    }
}
