// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.25;

import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {ModulesLibrary} from "@aleph-vault/libraries/ModulesLibrary.sol";
import {AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";
import {AlephVaultBase} from "@aleph-vault/AlephVaultBase.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
abstract contract ExposedVaultSetters is AlephVaultBase {
    using EnumerableSet for EnumerableSet.AddressSet;

    function setCurrentDepositBatchId(uint48 _currentDepositBatchId) external {
        _getStorage().shareClasses[1].depositSettleId = _currentDepositBatchId;
    }

    function setBatchDepositRequest(uint48 _batchId, address _user, uint256 _amount) external {
        _getStorage().shareClasses[1].depositRequests[_batchId].depositRequest[_user] = _amount;
    }

    function setLastFeePaidId(uint48 _lastFeePaidId) external {
        _getStorage().shareClasses[1].lastFeePaidId = _lastFeePaidId;
    }

    function setLastConsolidatedSeriesId(uint32 _lastConsolidatedSeriesId) external {
        AlephVaultStorageData storage _sd = _getStorage();
        _sd.shareClasses[1].lastConsolidatedSeriesId = _lastConsolidatedSeriesId;
        _sd.shareClasses[1].shareSeriesId = _lastConsolidatedSeriesId;
    }

    function setBatchDeposit(uint48 _batchId, address _user, uint256 _amount) external {
        AlephVaultStorageData storage _sd = _getStorage();
        _sd.shareClasses[1].depositRequests[_batchId].usersToDeposit.add(_user);
        _sd.shareClasses[1].depositRequests[_batchId].depositRequest[_user] = _amount;
        _sd.shareClasses[1].depositRequests[_batchId].totalAmountToDeposit += _amount;
        _sd.totalAmountToDeposit += _amount;
    }

    function setBatchRedeem(uint48 _batchId, address _user, uint256 _amount) external {
        AlephVaultStorageData storage _sd = _getStorage();
        _sd.shareClasses[1].redeemRequests[_batchId].usersToRedeem.add(_user);
        _sd.shareClasses[1].redeemRequests[_batchId].redeemRequest[_user] = _amount;
    }

    function setMinDepositAmount(uint8 _classId, uint256 _minDepositAmount) external {
        _getStorage().shareClasses[_classId].shareClassParams.minDepositAmount = _minDepositAmount;
    }

    function setMinUserBalance(uint8 _classId, uint256 _minUserBalance) external {
        _getStorage().shareClasses[_classId].shareClassParams.minUserBalance = _minUserBalance;
    }

    function setMaxDepositCap(uint8 _classId, uint256 _maxDepositCap) external {
        _getStorage().shareClasses[_classId].shareClassParams.maxDepositCap = _maxDepositCap;
    }

    function setNoticePeriod(uint8 _classId, uint48 _noticePeriod) external {
        _getStorage().shareClasses[_classId].shareClassParams.noticePeriod = _noticePeriod;
    }

    function setLockInPeriod(uint8 _classId, uint48 _lockInPeriod) external {
        _getStorage().shareClasses[_classId].shareClassParams.lockInPeriod = _lockInPeriod;
    }

    function setUserLockInPeriod(uint8 _classId, uint48 _userLockInPeriod, address _user) external {
        AlephVaultStorageData storage _sd = _getStorage();
        _sd.shareClasses[_classId].shareClassParams.lockInPeriod = 1;
        _sd.shareClasses[_classId].userLockInPeriod[_user] = _userLockInPeriod;
    }

    function setMinRedeemAmount(uint8 _classId, uint256 _minRedeemAmount) external {
        _getStorage().shareClasses[_classId].shareClassParams.minRedeemAmount = _minRedeemAmount;
    }

    function setRedeemableAmount(address _user, uint256 _redeemableAmount) external {
        _getStorage().redeemableAmount[_user] += _redeemableAmount;
        _getStorage().totalAmountToWithdraw += _redeemableAmount;
    }

    function setTotalAmountToDeposit(uint256 _totalAmountToDeposit) external {
        _getStorage().totalAmountToDeposit = _totalAmountToDeposit;
    }

    function setTotalAmountToWithdraw(uint256 _totalAmountToWithdraw) external {
        _getStorage().totalAmountToWithdraw = _totalAmountToWithdraw;
    }

    function setTotalAssets(uint32 _seriesId, uint256 _totalAssets) external {
        _getStorage().shareClasses[1].shareSeries[_seriesId].totalAssets = _totalAssets;
    }

    function setTotalShares(uint32 _seriesId, uint256 _totalShares) external {
        _getStorage().shareClasses[1].shareSeries[_seriesId].totalShares = _totalShares;
    }

    function setSharesOf(uint32 _seriesId, address _user, uint256 _shares) external {
        _getStorage().shareClasses[1].shareSeries[_seriesId].sharesOf[_user] = _shares;
    }

    function setHighWaterMark(uint256 _highWaterMark) external {
        _getStorage().shareClasses[1].shareSeries[0].highWaterMark = _highWaterMark;
    }

    function setManagementFee(uint8 _classId, uint32 _managementFee) external {
        _getStorage().shareClasses[_classId].shareClassParams.managementFee = _managementFee;
    }

    function setPerformanceFee(uint8 _classId, uint32 _performanceFee) external {
        _getStorage().shareClasses[_classId].shareClassParams.performanceFee = _performanceFee;
    }

    function createNewSeries() external {
        AlephVaultStorageData storage _sd = _getStorage();
        _sd.shareClasses[1].shareSeriesId++;
        _sd.shareClasses[1].shareSeries[_sd.shareClasses[1].shareSeriesId].highWaterMark = 1e6;
    }

    function getManagementFeeShares(uint256 _newTotalAssets, uint256 _totalShares, uint48 _batchesElapsed)
        external
        view
        returns (uint256)
    {
        if (_batchesElapsed == 0) {
            return 0;
        }
        return IFeeManager(_getStorage().moduleImplementations[ModulesLibrary.FEE_MANAGER])
            .getManagementFeeShares(
                _getStorage().shareClasses[1].shareClassParams.managementFee,
                _batchesElapsed,
                _newTotalAssets,
                _totalShares
            );
    }

    function getPerformanceFeeShares(uint256 _newTotalAssets, uint256 _totalShares) external view returns (uint256) {
        AlephVaultStorageData storage _sd = _getStorage();
        uint256 _highWaterMark = _sd.shareClasses[1].shareSeries[0].highWaterMark;
        if (_highWaterMark == 0) {
            return 0;
        }
        return IFeeManager(_sd.moduleImplementations[ModulesLibrary.FEE_MANAGER])
            .getPerformanceFeeShares(
                _sd.shareClasses[1].shareClassParams.performanceFee, _newTotalAssets, _totalShares, _highWaterMark
            );
    }

    function managementFeeRecipient() external pure returns (address) {
        return address(bytes20(keccak256("MANAGEMENT_FEE_RECIPIENT")));
    }

    function performanceFeeRecipient() external pure returns (address) {
        return address(bytes20(keccak256("PERFORMANCE_FEE_RECIPIENT")));
    }
}

