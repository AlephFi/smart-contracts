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

import {IERC7540Redeem} from "./interfaces/IERC7540Redeem.sol";
import {AlephVaultStorage, AlephVaultStorageData} from "./AlephVaultStorage.sol";
import {IAlephVault} from "./interfaces/IAlephVault.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {Checkpoints} from "./libraries/Checkpoints.sol";
import {ERC4626Math} from "./libraries/ERC4626Math.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
abstract contract AlephVaultRedeem is IERC7540Redeem {
    using SafeERC20 for IERC20;
    using Checkpoints for Checkpoints.Trace256;

    /**
     * @notice Returns the current batch ID.
     */
    function currentBatch() public view virtual returns (uint48);

    /**
     * @notice Returns the number of shares owned by a user.
     * @param _user The address of the user.
     */
    function sharesOf(address _user) public view virtual returns (uint256);

    /**
     * @notice Returns the total assets in the vault.
     */
    function totalAssets() public view virtual returns (uint256);

    /**
     * @notice Returns the total shares issued by the vault.
     */
    function totalShares() public view virtual returns (uint256);

    /// @inheritdoc IERC7540Redeem
    function settleRedeem(uint256 _newTotalAssets) external virtual;

    /**
     * @dev Returns the storage struct for the vault.
     */
    function _getStorage() internal pure virtual returns (AlephVaultStorageData storage sd);

    /// @inheritdoc IERC7540Redeem
    function pendingTotalSharesToRedeem() public view returns (uint256 _totalSharesToRedeem) {
        AlephVaultStorageData storage _sd = _getStorage();
        uint48 _currentBatchId = currentBatch();
        for (uint48 _batchId = _sd.redeemSettleId; _batchId <= _currentBatchId; _batchId++) {
            _totalSharesToRedeem += _sd.batchs[_batchId].totalSharesToRedeem;
        }
    }

    /// @inheritdoc IERC7540Redeem
    function pendingTotalAssetsToRedeem() public view returns (uint256 _totalAssetsToRedeem) {
        uint256 _totalSharesToRedeem = pendingTotalSharesToRedeem();
        return ERC4626Math.previewRedeem(_totalSharesToRedeem, totalAssets(), totalShares());
    }

    /// @inheritdoc IERC7540Redeem
    function requestRedeem(uint256 _shares) external returns (uint48 _batchId) {
        return _requestRedeem(_shares);
    }

    /// @inheritdoc IERC7540Redeem
    function pendingRedeemRequest(uint48 _batchId) external view returns (uint256 _shares) {
        AlephVaultStorageData storage _sd = _getStorage();
        IAlephVault.BatchData storage _batch = _sd.batchs[_batchId];
        if (_batchId < _sd.redeemSettleId) {
            revert BatchAlreadyRedeemed();
        }
        return _batch.redeemRequest[msg.sender];
    }

    /**
     * @dev Internal function to settle all redeems for batches up to the current batch.
     * @param _newTotalAssets The new total assets after settlement.
     */
    function _settleRedeem(uint256 _newTotalAssets) internal {
        AlephVaultStorageData storage _sd = _getStorage();
        uint48 _redeemSettleId = _sd.redeemSettleId;
        uint48 _currentBatchId = currentBatch();
        if (_currentBatchId == _redeemSettleId) {
            revert NoRedeemsToSettle();
        }
        uint48 _timestamp = Time.timestamp();
        uint256 _sharesToSettle;
        for (_redeemSettleId; _redeemSettleId < _currentBatchId; _redeemSettleId++) {
            uint256 _totalAssets = _redeemSettleId == _sd.redeemSettleId ? _newTotalAssets : totalAssets(); // if the batch is the first batch, use the new total assets, otherwise use the old total assets
            _sharesToSettle += _settleRedeemForBatch(_sd, _redeemSettleId, _timestamp, _totalAssets);
        }
        emit SettleRedeem(_sd.redeemSettleId, _currentBatchId, _sharesToSettle, _newTotalAssets);
        _sd.redeemSettleId = _currentBatchId;
    }

    /**
     * @dev Internal function to settle redeems for a specific batch.
     * @param _sd The storage struct.
     * @param _batchId The batch ID to settle.
     * @param _timestamp The timestamp of settlement.
     * @param _totalAssets The total assets at settlement.
     * @return The total shares settled for the batch.
     */
    function _settleRedeemForBatch(
        AlephVaultStorageData storage _sd,
        uint48 _batchId,
        uint48 _timestamp,
        uint256 _totalAssets
    ) internal returns (uint256) {
        IAlephVault.BatchData storage _batch = _sd.batchs[_batchId];
        if (_batch.totalSharesToRedeem == 0) {
            return 0;
        }
        uint256 _totalShares = totalShares();
        uint256 _totalAassetsToRedeem;
        IERC20 _erc20 = IERC20(_sd.erc20);
        for (uint256 i = 0; i < _batch.usersToRedeem.length; i++) {
            address _user = _batch.usersToRedeem[i];
            uint256 _sharesToBurnPerUser = _batch.redeemRequest[_user];
            uint256 _assets = ERC4626Math.previewRedeem(_sharesToBurnPerUser, _totalAssets, _totalShares);
            _totalAassetsToRedeem += _assets;
            _erc20.safeTransfer(_user, _assets);
        }
        _sd.shares.push(_timestamp, _totalShares - _batch.totalSharesToRedeem);
        _sd.assets.push(_timestamp, _totalAssets - _totalAassetsToRedeem);
        emit SettleRedeemBatch(_batchId, _totalAassetsToRedeem, _batch.totalSharesToRedeem, _totalAssets, _totalShares);
        return _batch.totalSharesToRedeem;
    }

    /**
     * @dev Internal function to handle a redeem request.
     * @param _sharesToRedeem The number of shares to redeem.
     * @return _batchId The batch ID for the redeem request.
     */
    function _requestRedeem(uint256 _sharesToRedeem) internal returns (uint48 _batchId) {
        AlephVaultStorageData storage _sd = _getStorage();
        address _user = msg.sender;
        uint256 _shares = sharesOf(_user);
        if (_shares < _sharesToRedeem) {
            revert InsufficientSharesToRedeem();
        }
        uint48 _lastRedeemBatchId = _sd.lastRedeemBatchId[_user];
        uint48 _currentBatchId = currentBatch();
        if (_currentBatchId == 0) {
            revert NoBatchAvailableForRedeem(); // need to wait for the first batch to be available
        }
        if (_lastRedeemBatchId >= _currentBatchId) {
            revert OnlyOneRequestPerBatchAllowedForRedeem();
        }
        _sd.lastRedeemBatchId[_user] = _currentBatchId;
        IAlephVault.BatchData storage _batch = _sd.batchs[_currentBatchId];
        _batch.redeemRequest[_user] += _sharesToRedeem;
        _batch.totalSharesToRedeem += _sharesToRedeem;
        _batch.usersToRedeem.push(_user);
        _sd.sharesOf[_user].push(Time.timestamp(), sharesOf(_user) - _sharesToRedeem);
        // we will update the total shares and assets in the _settleRedeemForBatch function
        emit RedeemRequest(_user, _sharesToRedeem, _currentBatchId);
        return _currentBatchId;
    }
}
