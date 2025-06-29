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
                || _initalizationParams.operator == address(0) || _initalizationParams.erc20 == address(0)
                || _initalizationParams.custodian == address(0)
        ) {
            revert InvalidInitializationParams();
        }
        _sd.manager = _initalizationParams.manager;
        _sd.operationsMultisig = _initalizationParams.operationsMultisig;
        _sd.operator = _initalizationParams.operator;
        _sd.erc20 = _initalizationParams.erc20;
        _sd.custodian = _initalizationParams.custodian;
        _sd.currentDepositBatchId = 1;
        _sd.currentDepositSettleId = 0;
    }

    function totalStake() public view returns (uint256) {
        return _getStorage().stake.latest();
    }

    function totalShares() public view returns (uint256) {
        return _getStorage().shares.latest();
    }

    function stakeAt(uint48 _timestamp) public view returns (uint256) {
        return _getStorage().stake.upperLookupRecent(_timestamp);
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

    // Transfers amount from msg.sender into the Vault and submits a Request for asynchronous deposit.
    // This places the Request in Pending state, with a corresponding increase in pendingDepositRequest for the amount assets.
    function requestDeposit(uint256 _amount) external returns (uint40 _batchId) {
        return _requestDeposit(_amount);
    }

    function pendingDepositRequest(uint40 _batchId) external view returns (uint256 _amount) {
        ERC7540StorageData storage _sd = _getStorage();
        BatchData storage _batch = _sd.batchs[_batchId];
        if (_batch.isSettled) {
            revert BatchAlreadySettled();
        }
        return _batch.depositRequest[msg.sender];
    }

    function _requestDeposit(uint256 _amount) internal returns (uint40) {
        ERC7540StorageData storage _sd = _getStorage();
        uint40 _lastDepositBatchId = _sd.lastDepositBatchId[msg.sender];
        uint40 _currentDepositBatchId = _sd.currentDepositBatchId;
        if (_lastDepositBatchId >= _currentDepositBatchId) {
            revert OnlyOneRequestPerBatchAllowed();
        }
        _sd.lastDepositBatchId[msg.sender] = _currentDepositBatchId;
        IERC20 _erc20 = IERC20(_sd.erc20);
        uint256 _balanceBefore = _erc20.balanceOf(address(this));
        _erc20.safeTransferFrom(msg.sender, address(this), _amount);
        uint256 _depositedAmount = _erc20.balanceOf(address(this)) - _balanceBefore;
        if (_depositedAmount == 0) {
            revert InsufficientDeposit();
        }
        BatchData storage _batch = _sd.batchs[_currentDepositBatchId];
        _batch.depositRequest[msg.sender] += _depositedAmount;
        _batch.totalAmount += _depositedAmount;
        _batch.users.push(msg.sender);
        emit DepositRequest(msg.sender, _depositedAmount, _currentDepositBatchId);
        return _currentDepositBatchId;
    }

    function _settleDeposit() internal {
        ERC7540StorageData storage _sd = _getStorage();

        uint40 _currentDepositSettleId = _sd.currentDepositSettleId;
        uint40 _currentDepositBatchId = _sd.currentDepositBatchId;

        if (_currentDepositBatchId == _currentDepositSettleId) {
            revert("No deposits to settle");
        }
        uint256 _pendingAmount = 0;
        for (_currentDepositSettleId; _currentDepositSettleId < _currentDepositBatchId; _currentDepositSettleId++) {
            _pendingAmount += _settleDepositForBatch(_sd, _currentDepositSettleId);
        }

        IERC20(_sd.erc20).safeTransfer(_sd.custodian, _pendingAmount);
        emit SettleDeposit(_sd.currentDepositSettleId, _currentDepositBatchId, _pendingAmount);
        _sd.currentDepositSettleId = _currentDepositBatchId;
    }

    function _settleDepositForBatch(ERC7540StorageData storage _sd, uint40 _batchId) internal returns (uint256) {
        BatchData storage _batch = _sd.batchs[_batchId];
        if (_batch.isSettled) {
            return 0;
        }
        uint48 _timestamp = Time.timestamp();
        uint256 _totalStake = totalStake();
        uint256 _totalShares = totalShares();
        uint256 _totalSharesToMint = 0;
        for (uint256 i = 0; i < _batch.users.length; i++) {
            address _user = _batch.users[i];
            uint256 _amount = _batch.depositRequest[_user];
            uint256 _sharesToMintPerUser = ERC4626Math.previewDeposit(_amount, _totalShares, _totalStake);
            _sd.sharesOf[_user].push(_timestamp, sharesOf(_user) + _sharesToMintPerUser);
            _totalSharesToMint += _sharesToMintPerUser;
        }
        _sd.shares.push(_timestamp, _totalShares + _totalSharesToMint);
        _sd.stake.push(_timestamp, _totalStake + _batch.totalAmount);
        _batch.isSettled = true;
        emit SettleBatch(_batchId, _batch.totalAmount, _totalSharesToMint);
        return _batch.totalAmount;
    }

    function _getStorage() internal pure returns (ERC7540StorageData storage sd) {
        return ERC7540Storage.load();
    }
}
