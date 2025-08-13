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

import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {Math} from "openzeppelin-contracts/contracts/utils/math/Math.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {Checkpoints} from "@aleph-vault/libraries/Checkpoints.sol";
import {ModulesLibrary} from "@aleph-vault/libraries/ModulesLibrary.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {TimelockRegistry} from "@aleph-vault/libraries/TimelockRegistry.sol";
import {AlephVaultDeposit} from "@aleph-vault/modules/AlephVaultDeposit.sol";
import {AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";
import {AlephVault} from "@aleph-vault/AlephVault.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract ExposedVault is AlephVault {
    using Math for uint256;
    using Checkpoints for Checkpoints.Trace256;

    constructor(uint48 _batchDuration) AlephVault(_batchDuration) {}

    function depositSettleId() external view returns (uint48) {
        return _getStorage().depositSettleId;
    }

    function redeemSettleId() external view returns (uint48) {
        return _getStorage().redeemSettleId;
    }

    function lastFeePaidId() external view returns (uint48) {
        return _getStorage().lastFeePaidId;
    }

    function timelocks(bytes4 _key) external view returns (TimelockRegistry.Timelock memory) {
        return _getStorage().timelocks[_key];
    }

    function setLastDepositBatchId(address _user, uint48 _lastDepositBatchId) external {
        _getStorage().lastDepositBatchId[_user] = _lastDepositBatchId;
    }

    function setLastRedeemBatchId(address _user, uint48 _lastRedeemBatchId) external {
        _getStorage().lastRedeemBatchId[_user] = _lastRedeemBatchId;
    }

    function setCurrentDepositBatchId(uint48 _currentDepositBatchId) external {
        _getStorage().depositSettleId = _currentDepositBatchId;
    }

    function setBatchDepositRequest(uint48 _batchId, address _user, uint256 _amount) external {
        _getStorage().batches[_batchId].depositRequest[_user] = _amount;
    }

    function setLastFeePaidId(uint48 _lastFeePaidId) external {
        _getStorage().lastFeePaidId = _lastFeePaidId;
    }

    function setBatchDeposit(uint48 _batchId, address _user, uint256 _amount) external {
        AlephVaultStorageData storage _sd = _getStorage();
        _sd.batches[_batchId].usersToDeposit.push(_user);
        _sd.batches[_batchId].depositRequest[_user] = _amount;
        _sd.batches[_batchId].totalAmountToDeposit += _amount;
    }

    function setBatchRedeem(uint48 _batchId, address _user, uint256 _shares) external {
        AlephVaultStorageData storage _sd = _getStorage();
        _sd.batches[_batchId].usersToRedeem.push(_user);
        _sd.batches[_batchId].redeemRequest[_user] = _shares;
        _sd.batches[_batchId].totalSharesToRedeem += _shares;
    }

    function setMinDepositAmount(uint256 _minDepositAmount) external {
        _getStorage().minDepositAmount = _minDepositAmount;
    }

    function setMaxDepositCap(uint256 _maxDepositCap) external {
        _getStorage().maxDepositCap = _maxDepositCap;
    }

    function setTotalAssets(uint256 _totalAssets) external {
        _getStorage().assets.push(Time.timestamp(), _totalAssets);
    }

    function setTotalShares(uint256 _totalShares) external {
        _getStorage().shares.push(Time.timestamp(), _totalShares);
    }

    function setSharesOf(address _user, uint256 _shares) external {
        _getStorage().sharesOf[_user].push(Time.timestamp(), _shares);
    }

    function setHighWaterMark(uint256 _highWaterMark) external {
        _getStorage().highWaterMark.push(Time.timestamp(), _highWaterMark);
    }

    function setManagementFee(uint32 _managementFee) external {
        _getStorage().managementFee = _managementFee;
    }

    function setPerformanceFee(uint32 _performanceFee) external {
        _getStorage().performanceFee = _performanceFee;
    }

    function accumulateFees(uint256 _newTotalAssets, uint48 _currentBatchId, uint48 _lastFeePaidId, uint48 _timestamp)
        external
        returns (uint256)
    {
        _delegate(ModulesLibrary.FEE_MANAGER);
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
            _newTotalAssets, _totalShares, _batchesElapsed, _getStorage().managementFee
        );
    }

    function getPerformanceFeeShares(uint256 _newTotalAssets, uint256 _totalShares) external view returns (uint256) {
        uint256 _highWaterMark = _highWaterMark();
        if (_highWaterMark == 0) {
            return 0;
        }
        return IFeeManager(_getStorage().moduleImplementations[ModulesLibrary.FEE_MANAGER]).getPerformanceFeeShares(
            _newTotalAssets, _totalShares, _getStorage().performanceFee, _highWaterMark
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
