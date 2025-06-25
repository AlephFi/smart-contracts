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
import {AccessControlUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/AccessControlUpgradeable.sol";
import {IERC7540} from "./interfaces/IERC7540.sol";
import {ERC7540Storage, ERC7540StorageData} from "./ERC7540Storage.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract ERC7540 is IERC7540, AccessControlUpgradeable {
    using SafeERC20 for IERC20;

    function initialize(InitializationParams calldata _initalizationParams) public initializer {
        _initialize(_initalizationParams);
    }

    function _initialize(InitializationParams calldata _initalizationParams) internal onlyInitializing {
        ERC7540StorageData storage _sd = _getStorage();
        __AccessControl_init();
        if (_initalizationParams.manager == address(0) ||
         _initalizationParams.operationsMultisig == address(0) || 
         _initalizationParams.operator == address(0) ||
         _initalizationParams.erc20 == address(0) || 
         _initalizationParams.custodian == address(0)) {
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


    // Transfers amount from msg.sender into the Vault and submits a Request for asynchronous deposit.
    // This places the Request in Pending state, with a corresponding increase in pendingDepositRequest for the amount assets.
    function requestDeposit(uint256 _amount) external returns (uint40 _batchId){
        return _requestDeposit(_amount);
    }

    function pendingDepositRequest(uint40 _batchId) external view returns (uint256 _amount){
        ERC7540StorageData storage _sd = _getStorage();
        return _sd.batchs[_batchId].depositRequest[msg.sender];
    }

    function _requestDeposit(uint256 _amount) internal returns (uint40) {
        ERC7540StorageData storage _sd = _getStorage();
        uint40 _lastDepositBatchId = _sd.lastDepositBatchId[msg.sender];    
        uint40 _currentDepositBatchId = _sd.currentDepositBatchId;
        if (_lastDepositBatchId >= _currentDepositBatchId) {
            revert OnlyOneRequestPerBatchAllowed();
        }
        _sd.lastDepositBatchId[msg.sender] = _currentDepositBatchId;
        IERC20(_sd.erc20).safeTransferFrom(msg.sender, address(this), _amount);
        BatchData storage _batch = _sd.batchs[_currentDepositBatchId];
        _batch.depositRequest[msg.sender] += _amount;
        _batch.totalAmount += _amount;     
        _batch.users.push(msg.sender);
        emit DepositRequest(msg.sender, _amount, _currentDepositBatchId);
        return _currentDepositBatchId;
    }

    function _settleDeposit() internal {
        ERC7540StorageData storage _sd = _getStorage();

        uint40 _currentDepositSettleId = _sd.currentDepositSettleId;
        uint40 _currentDepositBatchId = _sd.currentDepositBatchId;

        if (_currentDepositBatchId >= _currentDepositSettleId) {
            revert("No deposits to settle");
        }
        uint256 _pendingAmount = 0;
        for (uint40 _depositSettleId = _currentDepositSettleId; _depositSettleId < _currentDepositBatchId; _depositSettleId++) {
            _pendingAmount += _settleDepositForBatch(_sd, _depositSettleId);
        }

        uint256 _shares = _convertToShares(_pendingAmount);
        IERC20(_sd.erc20).safeTransferFrom(address(this), _sd.custodian, _pendingAmount);
        _sd.currentDepositSettleId = _currentDepositBatchId;
    }

    function _settleDepositForBatch(ERC7540StorageData storage _sd, uint40 _batchId) internal returns (uint256) {
        BatchData storage _batch = _sd.batchs[_batchId];
        for (uint256 i = 0; i < _batch.users.length; i++) {
            address _user = _batch.users[i];
            uint256 _amount = _batch.depositRequest[_user];
            uint256 _shares = _convertToShares(_amount);
            // TODO: trnasfer shares to user
        }
        _batch.isSettled = true;
        return _batch.totalAmount;
    }   

    function _convertToShares(uint256 _amount) private view returns (uint256) {
        // TODO: implement
        return _amount;
    }    

    function _getStorage() internal pure returns (ERC7540StorageData storage sd) {
        return ERC7540Storage.load();
    }
}