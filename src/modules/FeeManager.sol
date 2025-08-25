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
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {TimelockRegistry} from "@aleph-vault/libraries/TimelockRegistry.sol";
import {AlephVaultBase} from "@aleph-vault/AlephVaultBase.sol";
import {AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract FeeManager is IFeeManager, AlephVaultBase {
    using SafeERC20 for IERC20;
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
    function queueManagementFee(uint8 _classId, uint32 _managementFee) external {
        _queueManagementFee(_getStorage(), _classId, _managementFee);
    }

    /// @inheritdoc IFeeManager
    function queuePerformanceFee(uint8 _classId, uint32 _performanceFee) external {
        _queuePerformanceFee(_getStorage(), _classId, _performanceFee);
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
    function accumulateFees(
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint48 _currentBatchId,
        uint48 _lastFeePaidId,
        uint8 _classId,
        uint8 _seriesId
    ) external returns (uint256) {
        return _accumulateFees(
            _getStorage().shareClasses[_classId],
            _newTotalAssets,
            _totalShares,
            _currentBatchId,
            _lastFeePaidId,
            _classId,
            _seriesId
        );
    }

    ///@inheritdoc IFeeManager
    function getManagementFeeShares(
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint48 _batchesElapsed,
        uint32 _managementFeeRate
    ) external view returns (uint256 _managementFeeShares) {
        return ERC4626Math.previewDeposit(
            _calculateManagementFeeAmount(_newTotalAssets, _batchesElapsed, _managementFeeRate),
            _totalShares,
            _newTotalAssets
        );
    }

    ///@inheritdoc IFeeManager
    function getPerformanceFeeShares(
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint32 _performanceFeeRate,
        uint256 _highWaterMark
    ) external pure returns (uint256 _performanceFeeShares) {
        uint256 _pricePerShare = _getPricePerShare(_newTotalAssets, _totalShares);
        uint256 _performanceFeeAmount = _pricePerShare > _highWaterMark
            ? _calculatePerformanceFeeAmount(_pricePerShare, _highWaterMark, _totalShares, _performanceFeeRate)
            : 0;
        return ERC4626Math.previewDeposit(_performanceFeeAmount, _totalShares, _newTotalAssets);
    }

    ///@inheritdoc IFeeManager
    function collectFees() external {
        _collectFees(_getStorage());
    }

    /**
     * @dev Internal function to queue a new management fee.
     * @param _classId The ID of the share class to set the management fee for.
     * @param _managementFee The new management fee to be set.
     */
    function _queueManagementFee(AlephVaultStorageData storage _sd, uint8 _classId, uint32 _managementFee) internal {
        if (_managementFee > MAXIMUM_MANAGEMENT_FEE) {
            revert InvalidManagementFee();
        }
        _sd.timelocks[TimelockRegistry.MANAGEMENT_FEE] = TimelockRegistry.Timelock({
            unlockTimestamp: Time.timestamp() + MANAGEMENT_FEE_TIMELOCK,
            newValue: abi.encode(_classId, _managementFee)
        });
        emit NewManagementFeeQueued(_classId, _managementFee);
    }

    /**
     * @dev Internal function to queue a new performance fee.
     * @param _performanceFee The new performance fee to be set.
     */
    function _queuePerformanceFee(AlephVaultStorageData storage _sd, uint8 _classId, uint32 _performanceFee) internal {
        if (_performanceFee > MAXIMUM_PERFORMANCE_FEE) {
            revert InvalidPerformanceFee();
        }
        uint32 _oldPerformanceFee = _sd.shareClasses[_classId].performanceFee;
        if (_oldPerformanceFee == 0 || _performanceFee == 0) {
            revert InvalidShareClassConversion();
        }
        _sd.timelocks[TimelockRegistry.PERFORMANCE_FEE] = TimelockRegistry.Timelock({
            unlockTimestamp: Time.timestamp() + PERFORMANCE_FEE_TIMELOCK,
            newValue: abi.encode(_classId, _performanceFee)
        });
        emit NewPerformanceFeeQueued(_classId, _performanceFee);
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
        (uint8 _classId, uint32 _managementFee) =
            abi.decode(TimelockRegistry.setTimelock(_sd, TimelockRegistry.MANAGEMENT_FEE), (uint8, uint32));
        _sd.shareClasses[_classId].managementFee = _managementFee;
        emit NewManagementFeeSet(_classId, _managementFee);
    }

    /**
     * @dev Internal function to set the performance fee.
     */
    function _setPerformanceFee(AlephVaultStorageData storage _sd) internal {
        (uint8 _classId, uint32 _performanceFee) =
            abi.decode(TimelockRegistry.setTimelock(_sd, TimelockRegistry.PERFORMANCE_FEE), (uint8, uint32));
        _sd.shareClasses[_classId].performanceFee = _performanceFee;
        emit NewPerformanceFeeSet(_classId, _performanceFee);
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
        IAlephVault.ShareClass storage _shareClass,
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint48 _currentBatchId,
        uint48 _lastFeePaidId,
        uint8 _classId,
        uint8 _seriesId
    ) internal returns (uint256) {
        FeesAccumulatedParams memory _feesAccumulatedParams;
        _feesAccumulatedParams.managementFeeAmount =
            _calculateManagementFeeAmount(_newTotalAssets, _currentBatchId - _lastFeePaidId, _shareClass.managementFee);
        _feesAccumulatedParams.performanceFeeAmount = _checkPerformanceFeeAmount(
            _shareClass.performanceFee, _newTotalAssets, _totalShares, _shareClass.shareSeries[_seriesId].highWaterMark
        );
        _feesAccumulatedParams.managementFeeSharesToMint =
            ERC4626Math.previewDeposit(_feesAccumulatedParams.managementFeeAmount, _totalShares, _newTotalAssets);
        _feesAccumulatedParams.performanceFeeSharesToMint =
            ERC4626Math.previewDeposit(_feesAccumulatedParams.performanceFeeAmount, _totalShares, _newTotalAssets);
        uint256 _totalFeeSharesToMint =
            _feesAccumulatedParams.managementFeeSharesToMint + _feesAccumulatedParams.performanceFeeSharesToMint;
        _shareClass.shareSeries[_seriesId].sharesOf[MANAGEMENT_FEE_RECIPIENT] +=
            _feesAccumulatedParams.managementFeeSharesToMint;
        if (_feesAccumulatedParams.performanceFeeSharesToMint > 0) {
            _shareClass.shareSeries[_seriesId].sharesOf[PERFORMANCE_FEE_RECIPIENT] +=
                _feesAccumulatedParams.performanceFeeSharesToMint;
            uint256 _highWaterMark = _getPricePerShare(_newTotalAssets, _totalShares + _totalFeeSharesToMint);
            _shareClass.shareSeries[_seriesId].highWaterMark = _highWaterMark;
            emit NewHighWaterMarkSet(_classId, _seriesId, _highWaterMark, _currentBatchId);
        }
        emit FeesAccumulated(
            _lastFeePaidId,
            _currentBatchId,
            _classId,
            _seriesId,
            _newTotalAssets,
            _totalShares + _totalFeeSharesToMint,
            _feesAccumulatedParams
        );
        return _totalFeeSharesToMint;
    }

    /**
     * @dev Internal function to calculate the management fee amount.
     * @param _newTotalAssets The new total assets after collection.
     * @param _batchesElapsed The number of batches elapsed since the last fee was paid.
     * @param _managementFeeRate The management fee rate.
     * @return _managementFeeAmount The management fee to be collected.
     */
    function _calculateManagementFeeAmount(uint256 _newTotalAssets, uint48 _batchesElapsed, uint32 _managementFeeRate)
        internal
        view
        returns (uint256 _managementFeeAmount)
    {
        uint256 _annualFees =
            _newTotalAssets.mulDiv(uint256(_managementFeeRate), uint256(BPS_DENOMINATOR), Math.Rounding.Ceil);
        _managementFeeAmount =
            _annualFees.mulDiv(uint256(_batchesElapsed * BATCH_DURATION), uint256(ONE_YEAR), Math.Rounding.Ceil);
    }

    /**
     * @dev Internal function to calculate the performance fee amount.
     * @param _performanceFee The performance fee rate.
     * @param _newTotalAssets The new total assets after collection.
     * @param _totalShares The total shares in the vault.
     * @param _highWaterMark The high water mark.
     * @return _performanceFeeAmount The performance fee to be collected.
     */
    function _checkPerformanceFeeAmount(
        uint32 _performanceFee,
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint256 _highWaterMark
    ) internal view returns (uint256 _performanceFeeAmount) {
        uint256 _pricePerShare = _getPricePerShare(_newTotalAssets, _totalShares);
        if (_pricePerShare > _highWaterMark) {
            _performanceFeeAmount =
                _calculatePerformanceFeeAmount(_pricePerShare, _highWaterMark, _totalShares, _performanceFee);
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

    /**
     * @dev Internal function to collect all pending fees.
     */
    function _collectFees(AlephVaultStorageData storage _sd) internal {
        // uint256 _managementShares = _sharesOf(MANAGEMENT_FEE_RECIPIENT);
        // uint256 _performanceShares = _sharesOf(PERFORMANCE_FEE_RECIPIENT);
        // uint256 _totalShares = _totalShares();
        // uint256 _totalAssets = _totalAssets();
        // uint256 _managementFeesToCollect = ERC4626Math.previewRedeem(_managementShares, _totalAssets, _totalShares);
        // uint256 _performanceFeesToCollect = ERC4626Math.previewRedeem(_performanceShares, _totalAssets, _totalShares);
        // uint48 _timestamp = Time.timestamp();
        // _sd.sharesOf[MANAGEMENT_FEE_RECIPIENT].push(_timestamp, 0);
        // _sd.sharesOf[PERFORMANCE_FEE_RECIPIENT].push(_timestamp, 0);
        // _sd.shares.push(_timestamp, _totalShares - _managementShares - _performanceShares);
        // _sd.assets.push(_timestamp, _totalAssets - _managementFeesToCollect - _performanceFeesToCollect);
        // IERC20(_sd.underlyingToken).safeTransfer(_sd.feeRecipient, _managementFeesToCollect + _performanceFeesToCollect);
        // emit FeesCollected(_managementFeesToCollect, _performanceFeesToCollect);
    }
}
