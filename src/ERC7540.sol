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
import {IERC7540} from "./interfaces/IERC7540.sol";
import {ERC7540Storage, ERC7540StorageData} from "./ERC7540Storage.sol";
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
contract ERC7540 is IERC7540, AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using Checkpoints for Checkpoints.Trace256;
    using SafeCast for uint256;

    function initialize(InitializationParams calldata _initalizationParams) public initializer {
        _initialize(_initalizationParams);
    }

    function _initialize(InitializationParams calldata _initalizationParams) internal onlyInitializing {
        ERC7540StorageData storage _sd = _getStorage();
        __AccessControl_init();
        if (
            _initalizationParams.manager == address(0) || _initalizationParams.operationsMultisig == address(0)
                || _initalizationParams.oracle == address(0) || _initalizationParams.erc20 == address(0)
                || _initalizationParams.custodian == address(0) || _initalizationParams.batchDuration == 0
        ) {
            revert InvalidInitializationParams();
        }
        _sd.manager = _initalizationParams.manager;
        _sd.operationsMultisig = _initalizationParams.operationsMultisig;
        _sd.oracle = _initalizationParams.oracle;
        _sd.erc20 = _initalizationParams.erc20;
        _sd.custodian = _initalizationParams.custodian;
        _sd.batchDuration = _initalizationParams.batchDuration;
        _sd.startTimeStamp = Time.timestamp();
        _grantRole(RolesLibrary.ORACLE, _initalizationParams.oracle);
        _grantRole(RolesLibrary.OPERATIONS_MULTISIG, _initalizationParams.operationsMultisig);
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
        ERC7540StorageData storage _sd = _getStorage();
        return (Time.timestamp() - _sd.startTimeStamp) / _sd.batchDuration;
    }

    function pendingDepositRequest(uint48 _batchId) external view returns (uint256 _amount) {
        ERC7540StorageData storage _sd = _getStorage();
        BatchData storage _batch = _sd.batchs[_batchId];
        if (_batch.isSettled) {
            revert BatchAlreadySettled();
        }
        return _batch.depositRequest[msg.sender];
    }

    function settleDeposit(uint256 _newTotalAssets) external onlyRole(RolesLibrary.ORACLE) {
        _settleDeposit(_newTotalAssets);        
    }

    // Transfers amount from msg.sender into the Vault and submits a Request for asynchronous deposit.
    // This places the Request in Pending state, with a corresponding increase in pendingDepositRequest for the amount assets.
    function requestDeposit(uint256 _amount) external returns (uint48 _batchId) {
        return _requestDeposit(_amount);
    }

    function _requestDeposit(uint256 _amount) internal returns (uint48 _batchId) {
        ERC7540StorageData storage _sd = _getStorage();
        address _user = msg.sender;
        uint48 _lastDepositBatchId = _sd.lastDepositBatchId[_user];
        uint48 _currentDepositBatchId = currentBatch();
        if (_currentDepositBatchId == 0) {
            revert NoBatchAvailable(); // need to wait for the first batch to be available
        }
        if (_lastDepositBatchId >= _currentDepositBatchId) {
            revert OnlyOneRequestPerBatchAllowed();
        }
        _sd.lastDepositBatchId[_user] = _currentDepositBatchId;
        IERC20 _erc20 = IERC20(_sd.erc20);
        uint256 _balanceBefore = _erc20.balanceOf(address(this));
        _erc20.safeTransferFrom(_user, address(this), _amount);
        uint256 _depositedAmount = _erc20.balanceOf(address(this)) - _balanceBefore;
        if (_depositedAmount == 0) {
            revert InsufficientDeposit();
        }
        BatchData storage _batch = _sd.batchs[_currentDepositBatchId];
        _batch.depositRequest[_user] += _depositedAmount;
        _batch.totalAmount += _depositedAmount;
        _batch.users.push(_user);
        emit DepositRequest(_user, _depositedAmount, _currentDepositBatchId);
        return _currentDepositBatchId;
    }

    function _settleDeposit(uint256 _newTotalAssets) internal {
        ERC7540StorageData storage _sd = _getStorage();
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
        emit SettleDeposit(_sd.depositSettleId, _currentBatchId, _amountToSettle);
        _sd.depositSettleId = _currentBatchId;
    }

    function _settleDepositForBatch(ERC7540StorageData storage _sd, uint48 _batchId, uint48 _timestamp, uint256 _totalAssets)
        internal
        returns (uint256)
    {
        BatchData storage _batch = _sd.batchs[_batchId];
        if (_batch.isSettled || _batch.totalAmount == 0) {
            return 0;
        }
        uint256 _totalShares = totalShares();
        uint256 _totalSharesToMint;
        for (uint256 i = 0; i < _batch.users.length; i++) {
            address _user = _batch.users[i];
            uint256 _amount = _batch.depositRequest[_user];
            uint256 _sharesToMintPerUser = ERC4626Math.previewDeposit(_amount, _totalShares, _totalAssets);
            _sd.sharesOf[_user].push(_timestamp, sharesOf(_user) + _sharesToMintPerUser);
            _totalSharesToMint += _sharesToMintPerUser;
        }
        _sd.shares.push(_timestamp, _totalShares + _totalSharesToMint);
        _sd.assets.push(_timestamp, _totalAssets + _batch.totalAmount);
        _batch.isSettled = true;
        emit SettleBatch(_batchId, _batch.totalAmount, _totalSharesToMint);
        return _batch.totalAmount;
    }

    function _getStorage() internal pure returns (ERC7540StorageData storage sd) {
        return ERC7540Storage.load();
    }
}
