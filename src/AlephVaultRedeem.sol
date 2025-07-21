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
import {AlephVaultStorageData} from "./AlephVaultStorage.sol";
import {IAlephVault} from "./interfaces/IAlephVault.sol";
import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {Checkpoints} from "./libraries/Checkpoints.sol";
import {ERC4626Math} from "./libraries/ERC4626Math.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
abstract contract AlephVaultRedeem is IERC7540Redeem {
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
    function requestRedeem(uint256 _shares) external virtual returns (uint48 _batchId);

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
            _totalSharesToRedeem += _sd.batches[_batchId].totalSharesToRedeem;
        }
    }

    /// @inheritdoc IERC7540Redeem
    function pendingTotalAssetsToRedeem() public view returns (uint256 _totalAssetsToRedeem) {
        uint256 _totalSharesToRedeem = pendingTotalSharesToRedeem();
        return ERC4626Math.previewRedeem(_totalSharesToRedeem, totalAssets(), totalShares());
    }

    /// @inheritdoc IERC7540Redeem
    function pendingRedeemRequest(uint48 _batchId) external view returns (uint256 _shares) {
        AlephVaultStorageData storage _sd = _getStorage();
        IAlephVault.BatchData storage _batch = _sd.batches[_batchId];
        if (_batchId < _sd.redeemSettleId) {
            revert BatchAlreadyRedeemed();
        }
        return _batch.redeemRequest[msg.sender];
    }

    /**
     * @dev Internal function to handle a redeem request.
     * @param _sharesToRedeem The number of shares to redeem.
     * @return _batchId The batch ID for the redeem request.
     */
    function _requestRedeem(uint256 _sharesToRedeem) internal returns (uint48 _batchId) {
        AlephVaultStorageData storage _sd = _getStorage();
        uint48 _currentBatchId = currentBatch();
        if (_currentBatchId == 0) {
            revert NoBatchAvailableForRedeem(); // need to wait for the first batch to be available
        }
        uint48 _lastRedeemBatchId = _sd.lastRedeemBatchId[msg.sender];
        if (_lastRedeemBatchId >= _currentBatchId) {
            revert OnlyOneRequestPerBatchAllowedForRedeem();
        }
        uint256 _shares = sharesOf(msg.sender);
        if (_shares < _sharesToRedeem) {
            revert InsufficientSharesToRedeem();
        }
        _sd.lastRedeemBatchId[msg.sender] = _currentBatchId;
        IAlephVault.BatchData storage _batch = _sd.batches[_currentBatchId];
        _batch.redeemRequest[msg.sender] += _sharesToRedeem;
        _batch.totalSharesToRedeem += _sharesToRedeem;
        _batch.usersToRedeem.push(msg.sender);
        _sd.sharesOf[msg.sender].push(Time.timestamp(), _shares - _sharesToRedeem);
        // we will update the total shares and assets in the _settleRedeemForBatch function
        emit RedeemRequest(msg.sender, _sharesToRedeem, _currentBatchId);
        return _currentBatchId;
    }
}
