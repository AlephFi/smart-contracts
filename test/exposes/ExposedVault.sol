// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.25;
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
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {TimelockRegistry} from "@aleph-vault/libraries/TimelockRegistry.sol";
import {ModulesLibrary} from "@aleph-vault/libraries/ModulesLibrary.sol";
import {AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";
import {AlephVault} from "@aleph-vault/AlephVault.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract ExposedVault is AlephVault {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 public constant PRICE_DENOMINATOR = 1e6;
    uint256 public constant TOTAL_SHARE_UNITS = 1e18;

    constructor(uint48 _batchDuration) AlephVault(_batchDuration) {}

    function accumulateFees(uint8, uint32, uint48, uint48, uint256, uint256) external returns (uint256) {
        _delegate(ModulesLibrary.FEE_MANAGER);
    }

    // View functions
    function depositSettleId() external view returns (uint48) {
        return _getStorage().shareClasses[1].depositSettleId;
    }

    function redeemSettleId() external view returns (uint48) {
        return _getStorage().shareClasses[1].redeemSettleId;
    }

    function lastFeePaidId() external view returns (uint48) {
        return _getStorage().shareClasses[1].lastFeePaidId;
    }

    function shareSeriesId() external view returns (uint32) {
        return _getStorage().shareClasses[1].shareSeriesId;
    }

    function timelocks(bytes4 _key) external view returns (TimelockRegistry.Timelock memory) {
        return _getStorage().timelocks[_key];
    }

    // Setters
    function setCurrentDepositBatchId(uint48 _currentDepositBatchId) external {
        _getStorage().shareClasses[1].depositSettleId = _currentDepositBatchId;
    }

    function setBatchDepositRequest(uint48 _batchId, address _user, uint256 _amount) external {
        _getStorage().shareClasses[1].depositRequests[_batchId].depositRequest[_user] = _amount;
    }

    function setLastFeePaidId(uint48 _lastFeePaidId) external {
        _getStorage().shareClasses[1].lastFeePaidId = _lastFeePaidId;
    }

    function lastConsolidatedSeriesId() external view returns (uint32) {
        return _getStorage().shareClasses[1].lastConsolidatedSeriesId;
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
        _sd.shareClasses[1].shareSeries[_sd.shareClasses[1].shareSeriesId].highWaterMark = PRICE_DENOMINATOR;
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

    // Timelock getters
    function _getTimelock(bytes4 _module, bytes4 _selector) internal returns (uint48) {
        (bool _success, bytes memory _data) =
            _getStorage().moduleImplementations[_module].delegatecall(abi.encodeWithSelector(_selector));
        return _success ? abi.decode(_data, (uint48)) : 0;
    }

    function minDepositAmountTimelock() external returns (uint48) {
        return _getTimelock(ModulesLibrary.ALEPH_VAULT_DEPOSIT, bytes4(keccak256("MIN_DEPOSIT_AMOUNT_TIMELOCK()")));
    }

    function minUserBalanceTimelock() external returns (uint48) {
        return _getTimelock(ModulesLibrary.ALEPH_VAULT_DEPOSIT, bytes4(keccak256("MIN_USER_BALANCE_TIMELOCK()")));
    }

    function maxDepositCapTimelock() external returns (uint48) {
        return _getTimelock(ModulesLibrary.ALEPH_VAULT_DEPOSIT, bytes4(keccak256("MAX_DEPOSIT_CAP_TIMELOCK()")));
    }

    function noticePeriodTimelock() external returns (uint48) {
        return _getTimelock(ModulesLibrary.ALEPH_VAULT_REDEEM, bytes4(keccak256("NOTICE_PERIOD_TIMELOCK()")));
    }

    function lockInPeriodTimelock() external returns (uint48) {
        return _getTimelock(ModulesLibrary.ALEPH_VAULT_REDEEM, bytes4(keccak256("LOCK_IN_PERIOD_TIMELOCK()")));
    }

    function minRedeemAmountTimelock() external returns (uint48) {
        return _getTimelock(ModulesLibrary.ALEPH_VAULT_REDEEM, bytes4(keccak256("MIN_REDEEM_AMOUNT_TIMELOCK()")));
    }

    function managementFeeTimelock() external returns (uint48) {
        return _getTimelock(ModulesLibrary.FEE_MANAGER, bytes4(keccak256("MANAGEMENT_FEE_TIMELOCK()")));
    }

    function performanceFeeTimelock() external returns (uint48) {
        return _getTimelock(ModulesLibrary.FEE_MANAGER, bytes4(keccak256("PERFORMANCE_FEE_TIMELOCK()")));
    }

    function accountantTimelock() external returns (uint48) {
        return _getTimelock(ModulesLibrary.FEE_MANAGER, bytes4(keccak256("ACCOUNTANT_TIMELOCK()")));
    }
}
