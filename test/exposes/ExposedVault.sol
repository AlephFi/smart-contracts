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
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {Checkpoints} from "@aleph-vault/libraries/Checkpoints.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {TimelockRegistry} from "@aleph-vault/libraries/TimelockRegistry.sol";
import {AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";
import {AlephVault} from "@aleph-vault/AlephVault.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract ExposedVault is AlephVault {
    using Math for uint256;
    using Checkpoints for Checkpoints.Trace256;

    constructor(IAlephVault.ConstructorParams memory _initalizationParams) AlephVault(_initalizationParams) {}

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

    function accumalateFees(uint256 _newTotalAssets, uint48 _currentBatchId, uint48 _lastFeePaidId, uint48 _timestamp)
        external
        returns (uint256)
    {
        return _accumulateFees(_getStorage(), _newTotalAssets, _currentBatchId, _lastFeePaidId, _timestamp);
    }

    function getManagementFeeSharesAccumulated(uint256 _newTotalAssets, uint256 _totalShares, uint48 _batchesElapsed)
        external
        view
        returns (uint256)
    {
        uint256 _managementFeeAmount = _calculateManagementFeeAmount(_getStorage(), _newTotalAssets, _batchesElapsed);
        return ERC4626Math.previewDeposit(_managementFeeAmount, _totalShares, _newTotalAssets);
    }

    function getPerformanceFeeSharesAccumulated(
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint256 _highWaterMark,
        uint48 _timestamp
    ) external returns (uint256) {
        AlephVaultStorageData storage _sd = _getStorage();
        uint256 _profitPerShare = _getPricePerShare(_newTotalAssets, _totalShares) - _highWaterMark;
        uint48 _performanceFeeRate = _sd.performanceFee;
        uint256 _performanceFeeAmount = (_profitPerShare.mulDiv(_totalShares, PRICE_DENOMINATOR, Math.Rounding.Ceil))
            .mulDiv(uint256(_performanceFeeRate), uint256(BPS_DENOMINATOR - _performanceFeeRate), Math.Rounding.Ceil);
        return ERC4626Math.previewDeposit(_performanceFeeAmount, _totalShares, _newTotalAssets);
    }
}
