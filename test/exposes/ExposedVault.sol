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

import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {ModulesLibrary} from "@aleph-vault/libraries/ModulesLibrary.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {TimelockRegistry} from "@aleph-vault/libraries/TimelockRegistry.sol";
import {AlephVaultDeposit} from "@aleph-vault/modules/AlephVaultDeposit.sol";
import {AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";
import {AlephVault} from "@aleph-vault/AlephVault.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract ExposedVault is AlephVault {
    using Math for uint256;

    uint256 public constant TOTAL_SHARE_UNITS = 1e18;

    constructor(uint48 _batchDuration) AlephVault(_batchDuration) {}

    function depositSettleId() external view returns (uint48) {
        return _getStorage().shareClasses[1].depositSettleId;
    }

    function redeemSettleId() external view returns (uint48) {
        return _getStorage().shareClasses[1].redeemSettleId;
    }

    function lastFeePaidId() external view returns (uint48) {
        return _getStorage().shareClasses[1].lastFeePaidId;
    }

    function shareSeriesId() external view returns (uint8) {
        return _getStorage().shareClasses[1].shareSeriesId;
    }

    function lastConsolidatedSeriesId() external view returns (uint8) {
        return _getStorage().shareClasses[1].lastConsolidatedSeriesId;
    }

    function timelocks(bytes4 _key) external view returns (TimelockRegistry.Timelock memory) {
        return _getStorage().timelocks[_key];
    }

    function setCurrentDepositBatchId(uint48 _currentDepositBatchId) external {
        _getStorage().shareClasses[1].depositSettleId = _currentDepositBatchId;
    }

    function setBatchDepositRequest(uint48 _batchId, address _user, uint256 _amount) external {
        _getStorage().shareClasses[1].depositRequests[_batchId].depositRequest[_user] = _amount;
    }

    function setLastFeePaidId(uint48 _lastFeePaidId) external {
        _getStorage().shareClasses[1].lastFeePaidId = _lastFeePaidId;
    }

    function setBatchDeposit(uint48 _batchId, address _user, uint256 _amount) external {
        AlephVaultStorageData storage _sd = _getStorage();
        _sd.shareClasses[1].depositRequests[_batchId].usersToDeposit.push(_user);
        _sd.shareClasses[1].depositRequests[_batchId].depositRequest[_user] = _amount;
        _sd.shareClasses[1].depositRequests[_batchId].totalAmountToDeposit += _amount;
    }

    function setBatchRedeem(uint48 _batchId, address _user, uint256 _amount) external {
        AlephVaultStorageData storage _sd = _getStorage();
        _sd.shareClasses[1].redeemRequests[_batchId].usersToRedeem.push(_user);
        _sd.shareClasses[1].redeemRequests[_batchId].redeemRequest[_user] = _amount;
    }

    function setNoticePeriod(uint8 _classId, uint48 _noticePeriod) external {
        _getStorage().shareClasses[_classId].noticePeriod = _noticePeriod;
    }

    function setMinDepositAmount(uint8 _classId, uint256 _minDepositAmount) external {
        _getStorage().shareClasses[_classId].minDepositAmount = _minDepositAmount;
    }

    function setMaxDepositCap(uint8 _classId, uint256 _maxDepositCap) external {
        _getStorage().shareClasses[_classId].maxDepositCap = _maxDepositCap;
    }

    function setTotalAssets(uint8 _seriesId, uint256 _totalAssets) external {
        _getStorage().shareClasses[1].shareSeries[_seriesId].totalAssets = _totalAssets;
    }

    function setTotalShares(uint8 _seriesId, uint256 _totalShares) external {
        _getStorage().shareClasses[1].shareSeries[_seriesId].totalShares = _totalShares;
    }

    function setSharesOf(uint8 _seriesId, address _user, uint256 _shares) external {
        _getStorage().shareClasses[1].shareSeries[_seriesId].sharesOf[_user] = _shares;
    }

    function setHighWaterMark(uint256 _highWaterMark) external {
        _getStorage().shareClasses[1].shareSeries[0].highWaterMark = _highWaterMark;
    }

    function setManagementFee(uint8 _classId, uint32 _managementFee) external {
        _getStorage().shareClasses[_classId].managementFee = _managementFee;
    }

    function setPerformanceFee(uint8 _classId, uint32 _performanceFee) external {
        _getStorage().shareClasses[_classId].performanceFee = _performanceFee;
    }

    function accumulateFees(uint256, uint256, uint48, uint48, uint8, uint8) external returns (uint256) {
        _delegate(ModulesLibrary.FEE_MANAGER);
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
        return IFeeManager(_getStorage().moduleImplementations[ModulesLibrary.FEE_MANAGER]).getManagementFeeShares(
            _newTotalAssets, _totalShares, _batchesElapsed, _getStorage().shareClasses[1].managementFee
        );
    }

    function getPerformanceFeeShares(uint256 _newTotalAssets, uint256 _totalShares) external view returns (uint256) {
        AlephVaultStorageData storage _sd = _getStorage();
        uint256 _highWaterMark = _sd.shareClasses[1].shareSeries[0].highWaterMark;
        if (_highWaterMark == 0) {
            return 0;
        }
        return IFeeManager(_sd.moduleImplementations[ModulesLibrary.FEE_MANAGER]).getPerformanceFeeShares(
            _newTotalAssets, _totalShares, _sd.shareClasses[1].performanceFee, _highWaterMark
        );
    }

    function managementFeeRecipient() external pure returns (address) {
        return address(bytes20(keccak256("MANAGEMENT_FEE_RECIPIENT")));
    }

    function performanceFeeRecipient() external pure returns (address) {
        return address(bytes20(keccak256("PERFORMANCE_FEE_RECIPIENT")));
    }

    function minDepositAmountTimelock() external returns (uint48) {
        (bool _success, bytes memory _data) = _getStorage().moduleImplementations[ModulesLibrary.ALEPH_VAULT_DEPOSIT]
            .delegatecall(abi.encodeWithSignature("MIN_DEPOSIT_AMOUNT_TIMELOCK()"));
        if (_success) {
            return abi.decode(_data, (uint48));
        }
        return 0;
    }

    function maxDepositCapTimelock() external returns (uint48) {
        (bool _success, bytes memory _data) = _getStorage().moduleImplementations[ModulesLibrary.ALEPH_VAULT_DEPOSIT]
            .delegatecall(abi.encodeWithSignature("MAX_DEPOSIT_CAP_TIMELOCK()"));
        if (_success) {
            return abi.decode(_data, (uint48));
        }
        return 0;
    }

    function noticePeriodTimelock() external returns (uint48) {
        (bool _success, bytes memory _data) = _getStorage().moduleImplementations[ModulesLibrary.ALEPH_VAULT_REDEEM]
            .delegatecall(abi.encodeWithSignature("NOTICE_PERIOD_TIMELOCK()"));
        if (_success) {
            return abi.decode(_data, (uint48));
        }
        return 0;
    }

    function managementFeeTimelock() external returns (uint48) {
        (bool _success, bytes memory _data) = _getStorage().moduleImplementations[ModulesLibrary.FEE_MANAGER]
            .delegatecall(abi.encodeWithSignature("MANAGEMENT_FEE_TIMELOCK()"));
        if (_success) {
            return abi.decode(_data, (uint48));
        }
        return 0;
    }

    function performanceFeeTimelock() external returns (uint48) {
        (bool _success, bytes memory _data) = _getStorage().moduleImplementations[ModulesLibrary.FEE_MANAGER]
            .delegatecall(abi.encodeWithSignature("PERFORMANCE_FEE_TIMELOCK()"));
        if (_success) {
            return abi.decode(_data, (uint48));
        }
        return 0;
    }

    function feeRecipientTimelock() external returns (uint48) {
        (bool _success, bytes memory _data) = _getStorage().moduleImplementations[ModulesLibrary.FEE_MANAGER]
            .delegatecall(abi.encodeWithSignature("FEE_RECIPIENT_TIMELOCK()"));
        if (_success) {
            return abi.decode(_data, (uint48));
        }
        return 0;
    }
}
