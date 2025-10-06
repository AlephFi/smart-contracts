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

import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {SeriesAccounting} from "@aleph-vault/libraries/SeriesAccounting.sol";
import {TimelockRegistry} from "@aleph-vault/libraries/TimelockRegistry.sol";
import {AlephVaultBase} from "@aleph-vault/AlephVaultBase.sol";
import {AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract FeeManager is IFeeManager, AlephVaultBase {
    using SafeERC20 for IERC20;
    using Math for uint256;
    using TimelockRegistry for bytes4;

    /**
     * @notice The timelock period for the management fee.
     */
    uint48 public immutable MANAGEMENT_FEE_TIMELOCK;
    /**
     * @notice The timelock period for the performance fee.
     */
    uint48 public immutable PERFORMANCE_FEE_TIMELOCK;

    /**
     * @notice The number of batches in a year.
     */
    uint48 public constant ONE_YEAR = 365 days;
    /**
     * @notice The denominator for the fee rates (basis points).
     */
    uint48 public constant BPS_DENOMINATOR = 10_000;

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Constructor for FeeManager module
     * @param _constructorParams The initialization parameters for fee configuration
     * @param _batchDuration The duration of each batch cycle in seconds
     */
    constructor(FeeConstructorParams memory _constructorParams, uint48 _batchDuration) AlephVaultBase(_batchDuration) {
        if (_constructorParams.managementFeeTimelock == 0 || _constructorParams.performanceFeeTimelock == 0) {
            revert InvalidConstructorParams();
        }
        MANAGEMENT_FEE_TIMELOCK = _constructorParams.managementFeeTimelock;
        PERFORMANCE_FEE_TIMELOCK = _constructorParams.performanceFeeTimelock;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    ///@inheritdoc IFeeManager
    function getManagementFeeShares(
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint48 _batchesElapsed,
        uint32 _managementFee
    ) external view returns (uint256 _managementFeeShares) {
        uint256 _managementFeeAmount = _calculateManagementFeeAmount(_newTotalAssets, _batchesElapsed, _managementFee);
        return ERC4626Math.previewDeposit(_managementFeeAmount, _totalShares, _newTotalAssets - _managementFeeAmount);
    }

    ///@inheritdoc IFeeManager
    function getPerformanceFeeShares(
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint32 _performanceFee,
        uint256 _highWaterMark
    ) external pure returns (uint256 _performanceFeeShares) {
        uint256 _performanceFeeAmount =
            _calculatePerformanceFeeAmount(_performanceFee, _newTotalAssets, _totalShares, _highWaterMark);
        return ERC4626Math.previewDeposit(_performanceFeeAmount, _totalShares, _newTotalAssets - _performanceFeeAmount);
    }

    /*//////////////////////////////////////////////////////////////
                            TIMELOCK FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IFeeManager
    function queueManagementFee(uint8 _classId, uint32 _managementFee) external {
        _queueManagementFee(_getStorage(), _classId, _managementFee);
    }

    /// @inheritdoc IFeeManager
    function queuePerformanceFee(uint8 _classId, uint32 _performanceFee) external {
        _queuePerformanceFee(_getStorage(), _classId, _performanceFee);
    }

    /// @inheritdoc IFeeManager
    function setManagementFee(uint8 _classId) external {
        _setManagementFee(_getStorage(), _classId);
    }

    /// @inheritdoc IFeeManager
    function setPerformanceFee(uint8 _classId) external {
        _setPerformanceFee(_getStorage(), _classId);
    }

    /*//////////////////////////////////////////////////////////////
                            FEE FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    ///@inheritdoc IFeeManager
    function accumulateFees(
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint48 _currentBatchId,
        uint48 _lastFeePaidId,
        uint8 _classId,
        uint32 _seriesId
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
    function collectFees()
        external
        nonReentrant
        returns (uint256 _managementFeesToCollect, uint256 _performanceFeesToCollect)
    {
        return _collectFees(_getStorage());
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @dev Internal function to queue a new management fee.
     * @param _sd The storage struct.
     * @param _classId The ID of the share class to set the management fee for.
     * @param _managementFee The new management fee to be set.
     */
    function _queueManagementFee(AlephVaultStorageData storage _sd, uint8 _classId, uint32 _managementFee) internal {
        if (_managementFee > MAXIMUM_MANAGEMENT_FEE) {
            revert InvalidManagementFee();
        }
        _sd.timelocks[TimelockRegistry.MANAGEMENT_FEE.getKey(_classId)] = TimelockRegistry.Timelock({
            isQueued: true,
            unlockTimestamp: Time.timestamp() + MANAGEMENT_FEE_TIMELOCK,
            newValue: abi.encode(_managementFee)
        });
        emit NewManagementFeeQueued(_classId, _managementFee);
    }

    /**
     * @dev Internal function to queue a new performance fee.
     * @param _sd The storage struct.
     * @param _performanceFee The new performance fee to be set.
     */
    function _queuePerformanceFee(AlephVaultStorageData storage _sd, uint8 _classId, uint32 _performanceFee) internal {
        if (_performanceFee > MAXIMUM_PERFORMANCE_FEE) {
            revert InvalidPerformanceFee();
        }
        uint32 _oldPerformanceFee = _sd.shareClasses[_classId].shareClassParams.performanceFee;
        if (_oldPerformanceFee == 0 || _performanceFee == 0) {
            revert InvalidShareClassConversion();
        }
        _sd.timelocks[TimelockRegistry.PERFORMANCE_FEE.getKey(_classId)] = TimelockRegistry.Timelock({
            isQueued: true,
            unlockTimestamp: Time.timestamp() + PERFORMANCE_FEE_TIMELOCK,
            newValue: abi.encode(_performanceFee)
        });
        emit NewPerformanceFeeQueued(_classId, _performanceFee);
    }

    /**
     * @dev Internal function to set the management fee.
     * @param _sd The storage struct.
     * @param _classId The id of the class.
     */
    function _setManagementFee(AlephVaultStorageData storage _sd, uint8 _classId) internal {
        uint32 _managementFee = abi.decode(TimelockRegistry.MANAGEMENT_FEE.setTimelock(_classId, _sd), (uint32));
        _sd.shareClasses[_classId].shareClassParams.managementFee = _managementFee;
        emit NewManagementFeeSet(_classId, _managementFee);
    }

    /**
     * @dev Internal function to set the performance fee.
     * @param _sd The storage struct.
     * @param _classId The id of the class.
     */
    function _setPerformanceFee(AlephVaultStorageData storage _sd, uint8 _classId) internal {
        uint32 _performanceFee = abi.decode(TimelockRegistry.PERFORMANCE_FEE.setTimelock(_classId, _sd), (uint32));
        _sd.shareClasses[_classId].shareClassParams.performanceFee = _performanceFee;
        emit NewPerformanceFeeSet(_classId, _performanceFee);
    }

    /**
     * @dev Internal function to accumulate fees.
     * @param _shareClass The share class.
     * @param _newTotalAssets The new total assets after collection.
     * @param _totalShares The total shares in the vault.
     * @param _currentBatchId The current batch id.
     * @param _lastFeePaidId The last fee paid id.
     * @param _classId The id of the class.
     * @param _seriesId The id of the series.
     * @return _totalFeeSharesToMint The total fee shares to mint.
     */
    function _accumulateFees(
        IAlephVault.ShareClass storage _shareClass,
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint48 _currentBatchId,
        uint48 _lastFeePaidId,
        uint8 _classId,
        uint32 _seriesId
    ) internal returns (uint256) {
        FeesAccumulatedParams memory _feesAccumulatedParams;
        IAlephVault.ShareClassParams memory _shareClassParams = _shareClass.shareClassParams;
        // calculate management fee amount
        _feesAccumulatedParams.managementFeeAmount = _calculateManagementFeeAmount(
            _newTotalAssets, _currentBatchId - _lastFeePaidId, _shareClassParams.managementFee
        );
        // calculate management fee shares to mint
        _feesAccumulatedParams.managementFeeSharesToMint = ERC4626Math.previewDeposit(
            _feesAccumulatedParams.managementFeeAmount,
            _totalShares,
            _newTotalAssets - _feesAccumulatedParams.managementFeeAmount
        );
        // calculate performance fee amount
        _feesAccumulatedParams.performanceFeeAmount = _calculatePerformanceFeeAmount(
            _shareClassParams.performanceFee,
            _newTotalAssets,
            _totalShares + _feesAccumulatedParams.managementFeeSharesToMint,
            _shareClass.shareSeries[_seriesId].highWaterMark
        );
        // calculate performance fee shares to mint
        _feesAccumulatedParams.performanceFeeSharesToMint = ERC4626Math.previewDeposit(
            _feesAccumulatedParams.performanceFeeAmount,
            _totalShares + _feesAccumulatedParams.managementFeeSharesToMint,
            _newTotalAssets - _feesAccumulatedParams.performanceFeeAmount
        );
        // calculate total fee shares to mint
        uint256 _totalFeeSharesToMint =
            _feesAccumulatedParams.managementFeeSharesToMint + _feesAccumulatedParams.performanceFeeSharesToMint;
        // update management fee shares of the series
        _shareClass.shareSeries[_seriesId].sharesOf[SeriesAccounting.MANAGEMENT_FEE_RECIPIENT] +=
            _feesAccumulatedParams.managementFeeSharesToMint;
        if (_feesAccumulatedParams.performanceFeeSharesToMint > 0) {
            // update performance fee shares of the series
            _shareClass.shareSeries[_seriesId].sharesOf[SeriesAccounting.PERFORMANCE_FEE_RECIPIENT] +=
                _feesAccumulatedParams.performanceFeeSharesToMint;
            // update high water mark of the series
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
     * @param _managementFee The management fee rate.
     * @return _managementFeeAmount The management fee to be collected.
     */
    function _calculateManagementFeeAmount(uint256 _newTotalAssets, uint48 _batchesElapsed, uint32 _managementFee)
        internal
        view
        returns (uint256 _managementFeeAmount)
    {
        // management fee amount formula:
        // (new total assets) * (management fee rate) * (time elapsed / ONE YEAR)
        uint256 _annualFees =
            _newTotalAssets.mulDiv(uint256(_managementFee), uint256(BPS_DENOMINATOR), Math.Rounding.Ceil);
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
    function _calculatePerformanceFeeAmount(
        uint32 _performanceFee,
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint256 _highWaterMark
    ) internal pure returns (uint256 _performanceFeeAmount) {
        // calculate price per share with new total assets
        uint256 _pricePerShare = _getPricePerShare(_newTotalAssets, _totalShares);
        // if price per share is greater than high water mark, calculate performance fee amount
        if (_pricePerShare > _highWaterMark) {
            // performance fee amount formula:
            // (price per share - high water mark) * total shares * performance fee rate
            uint256 _profitPerShare = _pricePerShare - _highWaterMark;
            uint256 _profit =
                _profitPerShare.mulDiv(_totalShares, SeriesAccounting.PRICE_DENOMINATOR, Math.Rounding.Ceil);
            _performanceFeeAmount =
                _profit.mulDiv(uint256(_performanceFee), uint256(BPS_DENOMINATOR), Math.Rounding.Ceil);
        }
    }

    /**
     * @dev Internal function to collect all pending fees.
     */
    function _collectFees(AlephVaultStorageData storage _sd)
        internal
        returns (uint256 _managementFeesToCollect, uint256 _performanceFeesToCollect)
    {
        uint8 _shareClasses = _sd.shareClassesId;
        for (uint8 _classId = 1; _classId <= _shareClasses; _classId++) {
            IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_classId];
            uint32 _shareSeriesId = _shareClass.shareSeriesId;
            uint32 _lastConsolidatedSeriesId = _shareClass.lastConsolidatedSeriesId;
            for (uint32 _seriesId; _seriesId <= _shareSeriesId; _seriesId++) {
                if (_seriesId > SeriesAccounting.LEAD_SERIES_ID) {
                    _seriesId += _lastConsolidatedSeriesId;
                }
                IAlephVault.ShareSeries storage _shareSeries = _shareClass.shareSeries[_seriesId];
                uint256 _managementFeeShares = _shareSeries.sharesOf[SeriesAccounting.MANAGEMENT_FEE_RECIPIENT];
                uint256 _performanceFeeShares = _shareSeries.sharesOf[SeriesAccounting.PERFORMANCE_FEE_RECIPIENT];
                uint256 _totalShares = _shareSeries.totalShares;
                uint256 _totalAssets = _shareSeries.totalAssets;
                uint256 _managementFeeAmount =
                    ERC4626Math.previewRedeem(_managementFeeShares, _totalAssets, _totalShares);
                uint256 _performanceFeeAmount =
                    ERC4626Math.previewRedeem(_performanceFeeShares, _totalAssets, _totalShares);
                delete _shareSeries.sharesOf[SeriesAccounting.MANAGEMENT_FEE_RECIPIENT];
                delete _shareSeries.sharesOf[SeriesAccounting.PERFORMANCE_FEE_RECIPIENT];
                _shareSeries.totalShares -= (_managementFeeShares + _performanceFeeShares);
                _shareSeries.totalAssets -= (_managementFeeAmount + _performanceFeeAmount);
                _managementFeesToCollect += _managementFeeAmount;
                _performanceFeesToCollect += _performanceFeeAmount;
                emit SeriesFeeCollected(_classId, _seriesId, _managementFeeAmount, _performanceFeeAmount);
            }
        }
        uint256 _totalFeesToCollect = _managementFeesToCollect + _performanceFeesToCollect;
        uint256 _requiredVaultBalance = _totalFeesToCollect + _sd.totalAmountToDeposit + _sd.totalAmountToWithdraw;
        if (IERC20(_sd.underlyingToken).balanceOf(address(this)) < _requiredVaultBalance) {
            revert InsufficientAssetsToCollectFees(_requiredVaultBalance);
        }
        IERC20(_sd.underlyingToken).safeTransfer(_sd.accountant, _totalFeesToCollect);
        emit FeesCollected(_currentBatch(_sd), _managementFeesToCollect, _performanceFeesToCollect);
    }
}
