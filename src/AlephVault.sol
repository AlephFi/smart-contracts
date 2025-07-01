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

import {AccessControlUpgradeable} from
    "openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {IAlephVault} from "./interfaces/IAlephVault.sol";
import {AlephVaultStorage, AlephVaultStorageData} from "./AlephVaultStorage.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {ERC4626Math} from "./libraries/ERC4626Math.sol";
import {Checkpoints} from "./libraries/Checkpoints.sol";
import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {RolesLibrary} from "./RolesLibrary.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract AlephVault is IAlephVault, AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using Checkpoints for Checkpoints.Trace256;
    using SafeCast for uint256;

    function initialize(InitializationParams calldata _initalizationParams) public initializer {
        _initialize(_initalizationParams);
    }

    function _initialize(InitializationParams calldata _initalizationParams) internal onlyInitializing {
        AlephVaultStorageData storage _sd = _getStorage();
        __AccessControl_init();
        if (
            _initalizationParams.admin == address(0) || _initalizationParams.operationsMultisig == address(0)
                || _initalizationParams.oracle == address(0) || _initalizationParams.erc20 == address(0)
                || _initalizationParams.custodian == address(0) || _initalizationParams.batchDuration == 0
        ) {
            revert InvalidInitializationParams();
        }
        _sd.admin = _initalizationParams.admin;
        _sd.operationsMultisig = _initalizationParams.operationsMultisig;
        _sd.oracle = _initalizationParams.oracle;
        _sd.erc20 = _initalizationParams.erc20;
        _sd.custodian = _initalizationParams.custodian;
        _sd.batchDuration = _initalizationParams.batchDuration;
        _sd.startTimeStamp = Time.timestamp();
        _grantRole(RolesLibrary.ORACLE, _initalizationParams.oracle);
    }

    function totalAssets() public view returns (uint256) {
        return _getStorage().assets.latest();
    }

    function totalShares() public view returns (uint256) {
        return _getStorage().shares.latest();
    }

    function assetsAt(uint48 _timestamp) public view returns (uint256) {
        return _getStorage().assets.upperLookupRecent(_timestamp);
    }

    function sharesAt(uint48 _timestamp) public view returns (uint256) {
        return _getStorage().shares.upperLookupRecent(_timestamp);
    }

    function sharesOf(address _user) public view returns (uint256) {
        return _getStorage().sharesOf[_user].latest();
    }

    function sharesOfAt(address _user, uint48 _timestamp) public view returns (uint256) {
        return _getStorage().sharesOf[_user].upperLookupRecent(_timestamp);
    }

    function currentBatch() public view returns (uint48) {
        AlephVaultStorageData storage _sd = _getStorage();
        return (Time.timestamp() - _sd.startTimeStamp) / _sd.batchDuration;
    }

    function pendingTotalSharesToRedeem() public view returns (uint256 _totalSharesToRedeem) {
        AlephVaultStorageData storage _sd = _getStorage();
        uint48 _currentBatchId = currentBatch();
        for (uint48 _batchId = _sd.redeemSettleId; _batchId <= _currentBatchId; _batchId++) {
            _totalSharesToRedeem += _sd.batchs[_batchId].totalSharesToRedeem;
        }
    }

    function pendingTotalAssetsToRedeem() public view returns (uint256 _totalAssetsToRedeem) {
        uint256 _totalSharesToRedeem = pendingTotalSharesToRedeem();
        return ERC4626Math.previewRedeem(_totalSharesToRedeem, totalAssets(), totalShares());
    }

    function pendingTotalAmountToDeposit() public view returns (uint256 _totalAmountToDeposit) {
        AlephVaultStorageData storage _sd = _getStorage();
        uint48 _currentBatchId = currentBatch();
        for (uint48 _batchId = _sd.depositSettleId; _batchId <= _currentBatchId; _batchId++) {
            _totalAmountToDeposit += _sd.batchs[_batchId].totalAmountToDeposit;
        }
    }

    function pendingTotalSharesToDeposit() public view returns (uint256 _totalSharesToDeposit) {
        uint256 _totalAmountToDeposit = pendingTotalAmountToDeposit();
        return ERC4626Math.previewDeposit(_totalAmountToDeposit, totalShares(), totalAssets());
    }

    function pendingDepositRequest(uint48 _batchId) external view returns (uint256 _amount) {
        AlephVaultStorageData storage _sd = _getStorage();
        BatchData storage _batch = _sd.batchs[_batchId];
        if (_batchId < _sd.depositSettleId) {
            revert BatchAlreadySettled();
        }
        return _batch.depositRequest[msg.sender];
    }

    function pendingRedeemRequest(uint48 _batchId) external view returns (uint256 _shares) {
        AlephVaultStorageData storage _sd = _getStorage();
        BatchData storage _batch = _sd.batchs[_batchId];
        if (_batchId < _sd.redeemSettleId) {
            revert BatchAlreadyRedeemed();
        }
        return _batch.redeemRequest[msg.sender];
    }

    function settleDeposit(uint256 _newTotalAssets) external onlyRole(RolesLibrary.ORACLE) {
        _settleDeposit(_newTotalAssets);
    }

    function settleRedeem(uint256 _newTotalAssets) external onlyRole(RolesLibrary.ORACLE) {
        _settleRedeem(_newTotalAssets);
    }

    // Submit a request to redeem shares and send funds to user after the batch is redeemed.
    function requestRedeem(uint256 _shares) external returns (uint48 _batchId) {
        return _requestRedeem(_shares);
    }

    // Transfers amount from msg.sender into the Vault and submits a Request for asynchronous deposit.
    // This places the Request in Pending state, with a corresponding increase in pendingDepositRequest for the amount assets.
    function requestDeposit(uint256 _amount) external returns (uint48 _batchId) {
        return _requestDeposit(_amount);
    }

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
            revert NoBatchAvailable(); // need to wait for the first batch to be available
        }
        if (_lastRedeemBatchId >= _currentBatchId) {
            revert OnlyOneRequestPerBatchAllowed();
        }
        _sd.lastRedeemBatchId[_user] = _currentBatchId;
        BatchData storage _batch = _sd.batchs[_currentBatchId];
        _batch.redeemRequest[_user] += _sharesToRedeem;
        _batch.totalSharesToRedeem += _sharesToRedeem;
        _batch.usersToRedeem.push(_user);
        _sd.sharesOf[_user].push(Time.timestamp(), sharesOf(_user) - _sharesToRedeem);
        // we will update the total shares and assets in the _settleRedeemForBatch function
        emit RedeemRequest(_user, _sharesToRedeem, _currentBatchId);
        return _currentBatchId;
    }

    function _requestDeposit(uint256 _amount) internal returns (uint48 _batchId) {
        AlephVaultStorageData storage _sd = _getStorage();
        address _user = msg.sender;
        uint48 _lastDepositBatchId = _sd.lastDepositBatchId[_user];
        uint48 _currentBatchId = currentBatch();
        if (_currentBatchId == 0) {
            revert NoBatchAvailable(); // need to wait for the first batch to be available
        }
        if (_lastDepositBatchId >= _currentBatchId) {
            revert OnlyOneRequestPerBatchAllowed();
        }
        _sd.lastDepositBatchId[_user] = _currentBatchId;
        IERC20 _erc20 = IERC20(_sd.erc20);
        uint256 _balanceBefore = _erc20.balanceOf(address(this));
        _erc20.safeTransferFrom(_user, address(this), _amount);
        uint256 _depositedAmount = _erc20.balanceOf(address(this)) - _balanceBefore;
        if (_depositedAmount == 0) {
            revert InsufficientDeposit();
        }
        BatchData storage _batch = _sd.batchs[_currentBatchId];
        _batch.depositRequest[_user] += _depositedAmount;
        _batch.totalAmountToDeposit += _depositedAmount;
        _batch.usersToDeposit.push(_user);
        emit DepositRequest(_user, _depositedAmount, _currentBatchId);
        return _currentBatchId;
    }

    function _settleDeposit(uint256 _newTotalAssets) internal {
        AlephVaultStorageData storage _sd = _getStorage();
        uint48 _depositSettleId = _sd.depositSettleId;
        uint48 _currentBatchId = currentBatch();
        if (_currentBatchId == _depositSettleId) {
            revert NoDepositsToSettle();
        }
        uint48 _timestamp = Time.timestamp();
        uint256 _amountToSettle;
        for (_depositSettleId; _depositSettleId < _currentBatchId; _depositSettleId++) {
            uint256 _totalAssets = _depositSettleId == _sd.depositSettleId ? _newTotalAssets : totalAssets(); // if the batch is the first batch, use the new total assets, otherwise use the old total assets
            _amountToSettle += _settleDepositForBatch(_sd, _depositSettleId, _timestamp, _totalAssets);
        }
        IERC20(_sd.erc20).safeTransfer(_sd.custodian, _amountToSettle);
        emit SettleDeposit(_sd.depositSettleId, _currentBatchId, _amountToSettle, _newTotalAssets);
        _sd.depositSettleId = _currentBatchId;
    }

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

    function _settleDepositForBatch(
        AlephVaultStorageData storage _sd,
        uint48 _batchId,
        uint48 _timestamp,
        uint256 _totalAssets
    ) internal returns (uint256) {
        BatchData storage _batch = _sd.batchs[_batchId];
        if (_batch.totalAmountToDeposit == 0) {
            return 0;
        }
        uint256 _totalShares = totalShares();
        uint256 _totalSharesToMint;
        for (uint256 i = 0; i < _batch.usersToDeposit.length; i++) {
            address _user = _batch.usersToDeposit[i];
            uint256 _amount = _batch.depositRequest[_user];
            uint256 _sharesToMintPerUser = ERC4626Math.previewDeposit(_amount, _totalShares, _totalAssets);
            _sd.sharesOf[_user].push(_timestamp, sharesOf(_user) + _sharesToMintPerUser);
            _totalSharesToMint += _sharesToMintPerUser;
        }
        _sd.shares.push(_timestamp, _totalShares + _totalSharesToMint);
        _sd.assets.push(_timestamp, _totalAssets + _batch.totalAmountToDeposit);
        emit SettleDepositBatch(_batchId, _batch.totalAmountToDeposit, _totalSharesToMint, _totalAssets, _totalShares);
        return _batch.totalAmountToDeposit;
    }

    function _settleRedeemForBatch(
        AlephVaultStorageData storage _sd,
        uint48 _batchId,
        uint48 _timestamp,
        uint256 _totalAssets
    ) internal returns (uint256 _totalSharesToRedeem) {
        BatchData storage _batch = _sd.batchs[_batchId];
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

    function _getStorage() internal pure returns (AlephVaultStorageData storage sd) {
        return AlephVaultStorage.load();
    }
}
