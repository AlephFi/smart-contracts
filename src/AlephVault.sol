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
import {AlephVaultStorage, AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IERC7540Deposit} from "@aleph-vault/interfaces/IERC7540Deposit.sol";
import {IERC7540Redeem} from "@aleph-vault/interfaces/IERC7540Redeem.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {Checkpoints} from "@aleph-vault/libraries/Checkpoints.sol";
import {ModulesLibrary} from "@aleph-vault/libraries/ModulesLibrary.sol";
import {RolesLibrary} from "@aleph-vault/libraries/RolesLibrary.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {AlephVaultBase} from "@aleph-vault/AlephVaultBase.sol";
import {AlephPausable} from "@aleph-vault/AlephPausable.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract AlephVault is IAlephVault, AlephVaultBase, AlephPausable {
    using SafeERC20 for IERC20;
    using Checkpoints for Checkpoints.Trace256;
    using SafeCast for uint256;

    /**
     * @notice Constructor.
     * @param _batchDuration The duration of a batch.
     */
    constructor(uint48 _batchDuration) AlephVaultBase(_batchDuration) {}

    /**
     * @notice Initializes the vault with the given parameters.
     * @param _initalizationParams Struct containing all initialization parameters.
     */
    function initialize(InitializationParams calldata _initalizationParams) public initializer {
        _initialize(_initalizationParams);
    }

    /**
     * @dev Internal function to set up vault storage and roles.
     * @param _initalizationParams Struct containing all initialization parameters.
     */
    function _initialize(InitializationParams calldata _initalizationParams) internal onlyInitializing {
        AlephVaultStorageData storage _sd = _getStorage();
        __AccessControl_init();
        if (
            _initalizationParams.userInitializationParams.manager == address(0)
                || _initalizationParams.operationsMultisig == address(0) || _initalizationParams.oracle == address(0)
                || _initalizationParams.guardian == address(0) || _initalizationParams.authSigner == address(0)
                || _initalizationParams.userInitializationParams.underlyingToken == address(0)
                || _initalizationParams.userInitializationParams.custodian == address(0)
                || _initalizationParams.feeRecipient == address(0)
                || _initalizationParams.moduleInitializationParams.alephVaultDepositImplementation == address(0)
                || _initalizationParams.moduleInitializationParams.alephVaultRedeemImplementation == address(0)
                || _initalizationParams.moduleInitializationParams.alephVaultSettlementImplementation == address(0)
                || _initalizationParams.moduleInitializationParams.feeManagerImplementation == address(0)
                || _initalizationParams.managementFee > MAXIMUM_MANAGEMENT_FEE
                || _initalizationParams.performanceFee > MAXIMUM_PERFORMANCE_FEE
        ) {
            revert InvalidInitializationParams();
        }
        _sd.oracle = _initalizationParams.oracle;
        _sd.guardian = _initalizationParams.guardian;
        _sd.authSigner = _initalizationParams.authSigner;
        _sd.feeRecipient = _initalizationParams.feeRecipient;
        _sd.managementFee = _initalizationParams.managementFee;
        _sd.performanceFee = _initalizationParams.performanceFee;
        _sd.name = _initalizationParams.userInitializationParams.name;
        _sd.manager = _initalizationParams.userInitializationParams.manager;
        _sd.underlyingToken = _initalizationParams.userInitializationParams.underlyingToken;
        _sd.custodian = _initalizationParams.userInitializationParams.custodian;
        _sd.isAuthEnabled = true;
        _sd.startTimeStamp = Time.timestamp();
        _sd.moduleImplementations[ModulesLibrary.ALEPH_VAULT_DEPOSIT] =
            _initalizationParams.moduleInitializationParams.alephVaultDepositImplementation;
        _sd.moduleImplementations[ModulesLibrary.ALEPH_VAULT_REDEEM] =
            _initalizationParams.moduleInitializationParams.alephVaultRedeemImplementation;
        _sd.moduleImplementations[ModulesLibrary.ALEPH_VAULT_SETTLEMENT] =
            _initalizationParams.moduleInitializationParams.alephVaultSettlementImplementation;
        _sd.moduleImplementations[ModulesLibrary.FEE_MANAGER] =
            _initalizationParams.moduleInitializationParams.feeManagerImplementation;
        _grantRole(RolesLibrary.OPERATIONS_MULTISIG, _initalizationParams.operationsMultisig);
        _grantRole(RolesLibrary.MANAGER, _initalizationParams.userInitializationParams.manager);
        _grantRole(RolesLibrary.ORACLE, _initalizationParams.oracle);
        _grantRole(RolesLibrary.GUARDIAN, _initalizationParams.guardian);
        __AlephVaultDeposit_init(
            _initalizationParams.userInitializationParams.manager,
            _initalizationParams.guardian,
            _initalizationParams.operationsMultisig
        );
        __AlephVaultRedeem_init(
            _initalizationParams.userInitializationParams.manager,
            _initalizationParams.guardian,
            _initalizationParams.operationsMultisig
        );
    }

    /// @inheritdoc IAlephVault
    function currentBatch() public view returns (uint48) {
        return _currentBatch();
    }

    /// @inheritdoc IAlephVault
    function name() external view returns (string memory) {
        return _getStorage().name;
    }

    /// @inheritdoc IAlephVault
    function manager() external view returns (address) {
        return _getStorage().manager;
    }

    /// @inheritdoc IAlephVault
    function oracle() external view returns (address) {
        return _getStorage().oracle;
    }

    /// @inheritdoc IAlephVault
    function guardian() external view returns (address) {
        return _getStorage().guardian;
    }

    /// @inheritdoc IAlephVault
    function authSigner() external view returns (address) {
        return _getStorage().authSigner;
    }

    function underlyingToken() external view returns (address) {
        return _getStorage().underlyingToken;
    }

    /// @inheritdoc IAlephVault
    function custodian() external view returns (address) {
        return _getStorage().custodian;
    }

    /// @inheritdoc IAlephVault
    function feeRecipient() external view returns (address) {
        return _getStorage().feeRecipient;
    }

    /// @inheritdoc IAlephVault
    function managementFee() external view returns (uint32) {
        return _getStorage().managementFee;
    }

    /// @inheritdoc IAlephVault
    function performanceFee() external view returns (uint32) {
        return _getStorage().performanceFee;
    }

    /// @inheritdoc IAlephVault
    function totalAssets() public view override(IAlephVault) returns (uint256) {
        return _totalAssets();
    }

    /// @inheritdoc IAlephVault
    function totalShares() public view override(IAlephVault) returns (uint256) {
        return _totalShares();
    }

    /// @inheritdoc IAlephVault
    function assetsAt(uint48 _timestamp) public view returns (uint256) {
        return _getStorage().assets.upperLookupRecent(_timestamp);
    }

    /// @inheritdoc IAlephVault
    function sharesAt(uint48 _timestamp) public view returns (uint256) {
        return _getStorage().shares.upperLookupRecent(_timestamp);
    }

    /// @inheritdoc IAlephVault
    function sharesOf(address _user) public view override(IAlephVault) returns (uint256) {
        return _sharesOf(_user);
    }

    /// @inheritdoc IAlephVault
    function assetsOf(address _user) public view returns (uint256) {
        return ERC4626Math.previewRedeem(sharesOf(_user), totalAssets(), totalShares());
    }

    /// @inheritdoc IAlephVault
    function assetsOfAt(address _user, uint48 _timestamp) public view returns (uint256) {
        return ERC4626Math.previewRedeem(sharesOfAt(_user, _timestamp), assetsAt(_timestamp), sharesAt(_timestamp));
    }

    /// @inheritdoc IAlephVault
    function sharesOfAt(address _user, uint48 _timestamp) public view returns (uint256) {
        return _getStorage().sharesOf[_user].upperLookupRecent(_timestamp);
    }

    /// @inheritdoc IAlephVault
    function pricePerShare() public view returns (uint256) {
        return _getPricePerShare(totalAssets(), totalShares());
    }

    /// @inheritdoc IAlephVault
    function pricePerShareAt(uint48 _timestamp) public view returns (uint256) {
        return _getPricePerShare(assetsAt(_timestamp), sharesAt(_timestamp));
    }

    /// @inheritdoc IAlephVault
    function highWaterMark() public view returns (uint256) {
        return _highWaterMark();
    }

    /// @inheritdoc IAlephVault
    function highWaterMarkAt(uint48 _timestamp) public view returns (uint256) {
        return _getStorage().highWaterMark.upperLookupRecent(_timestamp);
    }

    /// @inheritdoc IAlephVault
    function minDepositAmount() public view returns (uint256) {
        return _getStorage().minDepositAmount;
    }

    /// @inheritdoc IAlephVault
    function maxDepositCap() public view returns (uint256) {
        return _getStorage().maxDepositCap;
    }

    /// @inheritdoc IAlephVault
    function totalAmountToDeposit() public view returns (uint256) {
        return _totalAmountToDeposit();
    }

    /// @inheritdoc IAlephVault
    function totalAmountToDepositAt(uint48 _batchId) external view returns (uint256) {
        return _getStorage().batches[_batchId].totalAmountToDeposit;
    }

    /// @inheritdoc IAlephVault
    function usersToDepositAt(uint48 _batchId) external view returns (address[] memory) {
        return _getStorage().batches[_batchId].usersToDeposit;
    }

    /// @inheritdoc IAlephVault
    function depositRequestOf(address _user) external view returns (uint256 _totalAmountToDeposit) {
        uint48 _currentBatch = currentBatch();
        if (_currentBatch > 0) {
            AlephVaultStorageData storage _sd = _getStorage();
            uint48 _depositSettleId = _sd.depositSettleId;
            for (_depositSettleId; _depositSettleId < _currentBatch; _depositSettleId++) {
                _totalAmountToDeposit += _sd.batches[_depositSettleId].depositRequest[_user];
            }
        }
    }

    /// @inheritdoc IAlephVault
    function depositRequestOfAt(address _user, uint48 _batchId) external view returns (uint256) {
        return _getStorage().batches[_batchId].depositRequest[_user];
    }

    /// @inheritdoc IAlephVault
    function totalSharesToRedeem() public view returns (uint256 _totalSharesToRedeem) {
        uint48 _currentBatch = currentBatch();
        if (_currentBatch > 0) {
            AlephVaultStorageData storage _sd = _getStorage();
            uint48 _redeemSettleId = _sd.redeemSettleId;
            for (_redeemSettleId; _redeemSettleId <= _currentBatch; _redeemSettleId++) {
                _totalSharesToRedeem += _sd.batches[_redeemSettleId].totalSharesToRedeem;
            }
        }
    }

    /// @inheritdoc IAlephVault
    function totalSharesToRedeemAt(uint48 _batchId) external view returns (uint256) {
        return _getStorage().batches[_batchId].totalSharesToRedeem;
    }

    /// @inheritdoc IAlephVault
    function usersToRedeemAt(uint48 _batchId) external view returns (address[] memory) {
        return _getStorage().batches[_batchId].usersToRedeem;
    }

    /// @inheritdoc IAlephVault
    function redeemRequestOf(address _user) external view returns (uint256 _totalSharesToRedeem) {
        uint48 _currentBatch = currentBatch();
        if (_currentBatch > 0) {
            AlephVaultStorageData storage _sd = _getStorage();
            uint48 _redeemSettleId = _sd.redeemSettleId;
            for (_redeemSettleId; _redeemSettleId < _currentBatch; _redeemSettleId++) {
                _totalSharesToRedeem += _sd.batches[_redeemSettleId].redeemRequest[_user];
            }
        }
    }

    /// @inheritdoc IAlephVault
    function redeemRequestOfAt(address _user, uint48 _batchId) external view returns (uint256) {
        return _getStorage().batches[_batchId].redeemRequest[_user];
    }

    /// @inheritdoc IAlephVault
    function totalAmountForRedemption(uint256 _newTotalAssets) external view returns (uint256) {
        AlephVaultStorageData storage _sd = _getStorage();
        uint256 _totalShares = totalShares();
        _totalShares += _getManagementFeeShares(_sd, _newTotalAssets, _totalShares, currentBatch() - _sd.lastFeePaidId)
            + _getPerformanceFeeShares(_sd, _newTotalAssets, _totalShares);
        return ERC4626Math.previewRedeem(totalSharesToRedeem(), _newTotalAssets, _totalShares);
    }

    /// @inheritdoc IAlephVault
    function metadataUri() external view returns (string memory) {
        return _getStorage().metadataUri;
    }

    /// @inheritdoc IAlephVault
    function isAuthEnabled() external view returns (bool) {
        return _getStorage().isAuthEnabled;
    }

    /// @inheritdoc IAlephVault
    function setMetadataUri(string calldata _metadataUri)
        external
        override(IAlephVault)
        onlyRole(RolesLibrary.MANAGER)
    {
        _getStorage().metadataUri = _metadataUri;
        emit MetadataUriSet(_metadataUri);
    }

    /// @inheritdoc IAlephVault
    function setIsAuthEnabled(bool _isAuthEnabled) external override(IAlephVault) onlyRole(RolesLibrary.MANAGER) {
        _getStorage().isAuthEnabled = _isAuthEnabled;
        emit IsAuthEnabledSet(_isAuthEnabled);
    }

    /// @inheritdoc IAlephVault
    function setAuthSigner(address _authSigner)
        external
        override(IAlephVault)
        onlyRole(RolesLibrary.OPERATIONS_MULTISIG)
    {
        if (_authSigner == address(0)) {
            revert InvalidAuthSigner();
        }
        _getStorage().authSigner = _authSigner;
        emit AuthSignerSet(_authSigner);
    }

    /**
     * @notice Queues a new minimum deposit amount to be set after the timelock period.
     * @dev Only callable by the MANAGER role.
     */
    function queueMinDepositAmount(uint256) external onlyRole(RolesLibrary.MANAGER) {
        _delegate(ModulesLibrary.ALEPH_VAULT_DEPOSIT);
    }

    /**
     * @notice Queues a new maximum deposit cap to be set after the timelock period.
     * @dev Only callable by the MANAGER role.
     */
    function queueMaxDepositCap(uint256) external onlyRole(RolesLibrary.MANAGER) {
        _delegate(ModulesLibrary.ALEPH_VAULT_DEPOSIT);
    }

    /**
     * @notice Queues a new management fee to be set after the timelock period.
     * @dev Only callable by the OPERATIONS_MULTISIG role.
     */
    function queueManagementFee(uint32) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        _delegate(ModulesLibrary.FEE_MANAGER);
    }

    /**
     * @notice Queues a new performance fee to be set after the timelock period.
     * @dev Only callable by the OPERATIONS_MULTISIG role.
     */
    function queuePerformanceFee(uint32) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        _delegate(ModulesLibrary.FEE_MANAGER);
    }

    /**
     * @notice Queues a new fee recipient to be set after the timelock period.
     * @dev Only callable by the OPERATIONS_MULTISIG role.
     */
    function queueFeeRecipient(address) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        _delegate(ModulesLibrary.FEE_MANAGER);
    }

    /**
     * @notice Sets the minimum deposit amount to the queued value after the timelock period.
     * @dev Only callable by the MANAGER role.
     */
    function setMinDepositAmount() external onlyRole(RolesLibrary.MANAGER) {
        _delegate(ModulesLibrary.ALEPH_VAULT_DEPOSIT);
    }

    /**
     * @notice Sets the maximum deposit cap to the queued value after the timelock period.
     * @dev Only callable by the MANAGER role.
     */
    function setMaxDepositCap() external onlyRole(RolesLibrary.MANAGER) {
        _delegate(ModulesLibrary.ALEPH_VAULT_DEPOSIT);
    }

    /**
     * @notice Sets the management fee to the queued value after the timelock period.
     * @dev Only callable by the OPERATIONS_MULTISIG role.
     */
    function setManagementFee() external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        _delegate(ModulesLibrary.FEE_MANAGER);
    }

    /**
     * @notice Sets the performance fee to the queued value after the timelock period.
     * @dev Only callable by the OPERATIONS_MULTISIG role.
     */
    function setPerformanceFee() external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        _delegate(ModulesLibrary.FEE_MANAGER);
    }

    /**
     * @notice Sets the fee recipient to the queued value after the timelock period.
     * @dev Only callable by the OPERATIONS_MULTISIG role.
     */
    function setFeeRecipient() external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        _delegate(ModulesLibrary.FEE_MANAGER);
    }

    /**
     * @notice Collects all pending fees.
     * @dev Only callable by the OPERATIONS_MULTISIG role.
     */
    function collectFees() external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        _delegate(ModulesLibrary.FEE_MANAGER);
    }

    /**
     * @notice Requests a deposit of assets.
     * @dev Only callable when the deposit request flow is not paused.
     */
    function requestDeposit(IERC7540Deposit.RequestDepositParams calldata)
        external
        whenFlowNotPaused(PausableFlows.DEPOSIT_REQUEST_FLOW)
        returns (uint48)
    {
        _delegate(ModulesLibrary.ALEPH_VAULT_DEPOSIT);
    }

    /**
     * @notice Settles all pending deposits up to the current batch.
     * @dev Only callable by the ORACLE role.
     */
    function settleDeposit(uint256)
        external
        onlyRole(RolesLibrary.ORACLE)
        whenFlowNotPaused(PausableFlows.SETTLE_DEPOSIT_FLOW)
    {
        _delegate(ModulesLibrary.ALEPH_VAULT_SETTLEMENT);
    }

    /**
     * @notice Requests a redeem of shares.
     * @dev Only callable when the redeem request flow is not paused.
     */
    function requestRedeem(uint256) external whenFlowNotPaused(PausableFlows.REDEEM_REQUEST_FLOW) returns (uint48) {
        _delegate(ModulesLibrary.ALEPH_VAULT_REDEEM);
    }

    /**
     * @notice Settles all pending redeems up to the current batch.
     * @dev Only callable by the ORACLE role.
     */
    function settleRedeem(uint256)
        external
        onlyRole(RolesLibrary.ORACLE)
        whenFlowNotPaused(PausableFlows.SETTLE_REDEEM_FLOW)
    {
        _delegate(ModulesLibrary.ALEPH_VAULT_SETTLEMENT);
    }

    function _getManagementFeeShares(
        AlephVaultStorageData storage _sd,
        uint256 _newTotalAssets,
        uint256 _totalShares,
        uint48 _batchesElapsed
    ) internal view returns (uint256 _managementFeeShares) {
        return IFeeManager(_sd.moduleImplementations[ModulesLibrary.FEE_MANAGER]).getManagementFeeShares(
            _newTotalAssets, _totalShares, _batchesElapsed, _sd.managementFee
        );
    }

    function _getPerformanceFeeShares(AlephVaultStorageData storage _sd, uint256 _newTotalAssets, uint256 _totalShares)
        internal
        view
        returns (uint256 _performanceFeeShares)
    {
        return IFeeManager(_sd.moduleImplementations[ModulesLibrary.FEE_MANAGER]).getPerformanceFeeShares(
            _newTotalAssets, _totalShares, _sd.performanceFee, _highWaterMark()
        );
    }

    /**
     * @dev Delegates a call to the implementation of the given module.
     * @param _module The module to delegate to.
     */
    function _delegate(bytes4 _module) internal {
        address _implementation = _getStorage().moduleImplementations[_module];
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), _implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}
