// SPDX-License-Identifier: BUSL-1.1
pragma solidity >=0.8.25;

import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {TimelockRegistry} from "@aleph-vault/libraries/TimelockRegistry.sol";
import {ModulesLibrary} from "@aleph-vault/libraries/ModulesLibrary.sol";
import {AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";
import {AlephVault} from "@aleph-vault/AlephVault.sol";

contract ExposedVault is AlephVault {
    using EnumerableSet for EnumerableSet.AddressSet;

    constructor(uint48 _b) AlephVault(_b) {}

    function PRICE_DENOMINATOR() external pure returns (uint256) {
        return 1e6;
    }

    function TOTAL_SHARE_UNITS() external pure returns (uint256) {
        return 1e18;
    }

    function accumulateFees(uint8, uint32, uint48, uint48, uint256, uint256) external returns (uint256) {
        _delegate(ModulesLibrary.FEE_MANAGER);
    }

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

    function timelocks(bytes4 _k) external view returns (TimelockRegistry.Timelock memory) {
        return _getStorage().timelocks[_k];
    }

    function lastConsolidatedSeriesId() external view returns (uint32) {
        return _getStorage().shareClasses[1].lastConsolidatedSeriesId;
    }

    function setLastFeePaidId(uint48 _i) external {
        _getStorage().shareClasses[1].lastFeePaidId = _i;
    }

    function setShareSeriesId(uint32 _i) external {
        _getStorage().shareClasses[1].shareSeriesId = _i;
    }

    function setLastConsolidatedSeriesId(uint32 _i) external {
        AlephVaultStorageData storage _s = _getStorage();
        _s.shareClasses[1].lastConsolidatedSeriesId = _i;
        _s.shareClasses[1].shareSeriesId = _i;
    }

    function setBatchDeposit(uint48 _b, address _u, uint256 _a) external {
        AlephVaultStorageData storage _s = _getStorage();
        _s.shareClasses[1].depositRequests[_b].usersToDeposit.add(_u);
        _s.shareClasses[1].depositRequests[_b].depositRequest[_u] = _a;
        _s.shareClasses[1].depositRequests[_b].totalAmountToDeposit += _a;
        _s.totalAmountToDeposit += _a;
    }

    function setBatchRedeem(uint48 _b, address _u, uint256 _a) external {
        AlephVaultStorageData storage _s = _getStorage();
        _s.shareClasses[1].redeemRequests[_b].usersToRedeem.add(_u);
        _s.shareClasses[1].redeemRequests[_b].redeemRequest[_u] = _a;
    }

    function setMinDepositAmount(uint8 _c, uint256 _a) external {
        _getStorage().shareClasses[_c].shareClassParams.minDepositAmount = _a;
    }

    function setMinUserBalance(uint8 _c, uint256 _b) external {
        _getStorage().shareClasses[_c].shareClassParams.minUserBalance = _b;
    }

    function setMaxDepositCap(uint8 _c, uint256 _cap) external {
        _getStorage().shareClasses[_c].shareClassParams.maxDepositCap = _cap;
    }

    function setNoticePeriod(uint8 _c, uint48 _p) external {
        _getStorage().shareClasses[_c].shareClassParams.noticePeriod = _p;
    }

    function setLockInPeriod(uint8 _c, uint48 _p) external {
        _getStorage().shareClasses[_c].shareClassParams.lockInPeriod = _p;
    }

    function setUserLockInPeriod(uint8 _c, uint48 _p, address _u) external {
        AlephVaultStorageData storage _s = _getStorage();
        _s.shareClasses[_c].shareClassParams.lockInPeriod = 1;
        _s.shareClasses[_c].userLockInPeriod[_u] = _p;
    }

    function setMinRedeemAmount(uint8 _c, uint256 _a) external {
        _getStorage().shareClasses[_c].shareClassParams.minRedeemAmount = _a;
    }

    function setRedeemableAmount(address _u, uint256 _a) external {
        AlephVaultStorageData storage _s = _getStorage();
        _s.redeemableAmount[_u] += _a;
        _s.totalAmountToWithdraw += _a;
    }

    function setTotalAmountToDeposit(uint256 _a) external {
        _getStorage().totalAmountToDeposit = _a;
    }

    function setTotalAmountToWithdraw(uint256 _a) external {
        _getStorage().totalAmountToWithdraw = _a;
    }

    function setTotalAssets(uint32 _s, uint256 _a) external {
        _getStorage().shareClasses[1].shareSeries[_s].totalAssets = _a;
    }

    function setTotalShares(uint32 _s, uint256 _sh) external {
        _getStorage().shareClasses[1].shareSeries[_s].totalShares = _sh;
    }

    function setSharesOf(uint32 _s, address _u, uint256 _sh) external {
        _getStorage().shareClasses[1].shareSeries[_s].sharesOf[_u] = _sh;
    }

    function setHighWaterMark(uint256 _h) external {
        _getStorage().shareClasses[1].shareSeries[0].highWaterMark = _h;
    }

    function setManagementFee(uint8 _c, uint32 _f) external {
        _getStorage().shareClasses[_c].shareClassParams.managementFee = _f;
    }

    function setPerformanceFee(uint8 _c, uint32 _f) external {
        _getStorage().shareClasses[_c].shareClassParams.performanceFee = _f;
    }

    function createNewSeries() external {
        AlephVaultStorageData storage _s = _getStorage();
        _s.shareClasses[1].shareSeries[++_s.shareClasses[1].shareSeriesId].highWaterMark = 1e6;
    }

    function getManagementFeeShares(uint256 _a, uint256 _sh, uint48 _b) external view returns (uint256) {
        if (_b == 0) return 0;
        AlephVaultStorageData storage _s = _getStorage();
        return IFeeManager(_s.moduleImplementations[ModulesLibrary.FEE_MANAGER])
            .getManagementFeeShares(_s.shareClasses[1].shareClassParams.managementFee, _b, _a, _sh);
    }

    function getPerformanceFeeShares(uint256 _a, uint256 _sh) external view returns (uint256) {
        AlephVaultStorageData storage _s = _getStorage();
        uint256 _h = _s.shareClasses[1].shareSeries[0].highWaterMark;
        if (_h == 0) return 0;
        return IFeeManager(_s.moduleImplementations[ModulesLibrary.FEE_MANAGER])
            .getPerformanceFeeShares(_s.shareClasses[1].shareClassParams.performanceFee, _a, _sh, _h);
    }

    function managementFeeRecipient() external pure returns (address) {
        return 0xF0a23D75A9e5dF0052261216441270569eDD5BEb;
    }

    function performanceFeeRecipient() external pure returns (address) {
        return 0x91f69C0184bF67632Da9B6c9Cea82BFf2A506925;
    }

    function _getTimelock(bytes4 _m, bytes4 _s) internal returns (uint48) {
        (bool _o, bytes memory _d) = _getStorage().moduleImplementations[_m].delegatecall(abi.encodePacked(_s));
        return _o ? abi.decode(_d, (uint48)) : 0;
    }

    function minDepositAmountTimelock() external returns (uint48) {
        return _getTimelock(ModulesLibrary.ALEPH_VAULT_DEPOSIT, 0xc24b4e6c);
    }

    function minUserBalanceTimelock() external returns (uint48) {
        return _getTimelock(ModulesLibrary.ALEPH_VAULT_DEPOSIT, 0x0a220052);
    }

    function maxDepositCapTimelock() external returns (uint48) {
        return _getTimelock(ModulesLibrary.ALEPH_VAULT_DEPOSIT, 0x3e05ec9d);
    }

    function noticePeriodTimelock() external returns (uint48) {
        return _getTimelock(ModulesLibrary.ALEPH_VAULT_REDEEM, 0xf20e464c);
    }

    function lockInPeriodTimelock() external returns (uint48) {
        return _getTimelock(ModulesLibrary.ALEPH_VAULT_REDEEM, 0xed46888d);
    }

    function minRedeemAmountTimelock() external returns (uint48) {
        return _getTimelock(ModulesLibrary.ALEPH_VAULT_REDEEM, 0x36dffe3b);
    }

    function managementFeeTimelock() external returns (uint48) {
        return _getTimelock(ModulesLibrary.FEE_MANAGER, 0xe7d7db61);
    }

    function performanceFeeTimelock() external returns (uint48) {
        return _getTimelock(ModulesLibrary.FEE_MANAGER, 0xa4362f78);
    }

    function accountantTimelock() external returns (uint48) {
        return _getTimelock(ModulesLibrary.FEE_MANAGER, 0x0e16c6c3);
    }
}
