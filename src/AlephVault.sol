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
    using SafeCast for uint256;

    modifier onlyValidShareClass(uint8 _classId) {
        if (_classId > _getStorage().shareClassesId || _classId == 0) {
            revert InvalidShareClass();
        }
        _;
    }

    modifier onlyValidShareClassAndSeries(uint8 _classId, uint8 _seriesId) {
        AlephVaultStorageData storage _sd = _getStorage();
        if (_classId > _sd.shareClassesId || _classId == 0) {
            revert InvalidShareClass();
        }
        if (
            _seriesId > _sd.shareClasses[_classId].shareSeriesId
                || (_seriesId > 0 && _seriesId <= _sd.shareClasses[_classId].lastConsolidatedSeriesId)
        ) {
            revert InvalidShareSeries();
        }
        _;
    }

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
                || _initalizationParams.operationsMultisig == address(0) || _initalizationParams.vaultFactory == address(0)
                || _initalizationParams.oracle == address(0) || _initalizationParams.guardian == address(0)
                || _initalizationParams.authSigner == address(0)
                || _initalizationParams.userInitializationParams.underlyingToken == address(0)
                || _initalizationParams.userInitializationParams.custodian == address(0)
                || _initalizationParams.feeRecipient == address(0)
                || _initalizationParams.moduleInitializationParams.alephVaultDepositImplementation == address(0)
                || _initalizationParams.moduleInitializationParams.alephVaultRedeemImplementation == address(0)
                || _initalizationParams.moduleInitializationParams.alephVaultSettlementImplementation == address(0)
                || _initalizationParams.moduleInitializationParams.feeManagerImplementation == address(0)
                || _initalizationParams.userInitializationParams.managementFee > MAXIMUM_MANAGEMENT_FEE
                || _initalizationParams.userInitializationParams.performanceFee > MAXIMUM_PERFORMANCE_FEE
        ) {
            revert InvalidInitializationParams();
        }
        _sd.oracle = _initalizationParams.oracle;
        _sd.guardian = _initalizationParams.guardian;
        _sd.authSigner = _initalizationParams.authSigner;
        _sd.feeRecipient = _initalizationParams.feeRecipient;
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
        _grantRole(RolesLibrary.VAULT_FACTORY, _initalizationParams.vaultFactory);
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
        _createShareClass(
            _sd,
            _initalizationParams.userInitializationParams.managementFee,
            _initalizationParams.userInitializationParams.performanceFee,
            _initalizationParams.userInitializationParams.minDepositAmount,
            _initalizationParams.userInitializationParams.maxDepositCap
        );
    }

    /// @inheritdoc IAlephVault
    function migrateModules(bytes4 _module, address _newImplementation) external onlyRole(RolesLibrary.VAULT_FACTORY) {
        _getStorage().moduleImplementations[_module] = _newImplementation;
    }

    /// @inheritdoc IAlephVault
    function currentBatch() public view returns (uint48) {
        return _currentBatch(_getStorage());
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
    function managementFee(uint8 _classId) external view onlyValidShareClass(_classId) returns (uint32) {
        return _getStorage().shareClasses[_classId].managementFee;
    }

    /// @inheritdoc IAlephVault
    function performanceFee(uint8 _classId) external view onlyValidShareClass(_classId) returns (uint32) {
        return _getStorage().shareClasses[_classId].performanceFee;
    }

    /// @inheritdoc IAlephVault
    function totalAssets() external view returns (uint256) {
        return _totalAssets(_getStorage());
    }

    /// @inheritdoc IAlephVault
    function totalShares() external view returns (uint256) {
        return _totalShares(_getStorage());
    }

    /// @inheritdoc IAlephVault
    function totalAssetsPerClass(uint8 _classId) external view onlyValidShareClass(_classId) returns (uint256) {
        return _totalAssetsPerClass(_getStorage(), _classId);
    }

    /// @inheritdoc IAlephVault
    function totalSharesPerClass(uint8 _classId) external view onlyValidShareClass(_classId) returns (uint256) {
        return _totalSharesPerClass(_getStorage(), _classId);
    }

    /// @inheritdoc IAlephVault
    function totalAssetsPerSeries(uint8 _classId, uint8 _seriesId)
        public
        view
        onlyValidShareClassAndSeries(_classId, _seriesId)
        returns (uint256)
    {
        return _totalAssetsPerSeries(_getStorage(), _classId, _seriesId);
    }

    /// @inheritdoc IAlephVault
    function totalSharesPerSeries(uint8 _classId, uint8 _seriesId)
        public
        view
        onlyValidShareClassAndSeries(_classId, _seriesId)
        returns (uint256)
    {
        return _totalSharesPerSeries(_getStorage(), _classId, _seriesId);
    }

    /// @inheritdoc IAlephVault
    function sharesOf(uint8 _classId, uint8 _seriesId, address _user)
        public
        view
        onlyValidShareClassAndSeries(_classId, _seriesId)
        returns (uint256)
    {
        return _sharesOf(_getStorage(), _classId, _seriesId, _user);
    }

    /// @inheritdoc IAlephVault
    function assetsOf(uint8 _classId, uint8 _seriesId, address _user)
        public
        view
        onlyValidShareClassAndSeries(_classId, _seriesId)
        returns (uint256)
    {
        return _assetsOf(_getStorage(), _classId, _seriesId, _user);
    }

    /// @inheritdoc IAlephVault
    function pricePerShare(uint8 _classId, uint8 _seriesId)
        public
        view
        onlyValidShareClassAndSeries(_classId, _seriesId)
        returns (uint256)
    {
        AlephVaultStorageData storage _sd = _getStorage();
        return _getPricePerShare(
            _totalAssetsPerSeries(_sd, _classId, _seriesId), _totalSharesPerSeries(_sd, _classId, _seriesId)
        );
    }

    /// @inheritdoc IAlephVault
    function highWaterMark(uint8 _classId, uint8 _seriesId)
        public
        view
        onlyValidShareClassAndSeries(_classId, _seriesId)
        returns (uint256)
    {
        return _getStorage().shareClasses[_classId].shareSeries[_seriesId].highWaterMark;
    }

    /// @inheritdoc IAlephVault
    function minDepositAmount(uint8 _classId) public view onlyValidShareClass(_classId) returns (uint256) {
        return _getStorage().shareClasses[_classId].minDepositAmount;
    }

    /// @inheritdoc IAlephVault
    function maxDepositCap(uint8 _classId) public view onlyValidShareClass(_classId) returns (uint256) {
        return _getStorage().shareClasses[_classId].maxDepositCap;
    }

    /// @inheritdoc IAlephVault
    function totalAmountToDeposit(uint8 _classId) public view onlyValidShareClass(_classId) returns (uint256) {
        return _totalAmountToDeposit(_getStorage(), _classId);
    }

    /// @inheritdoc IAlephVault
    function totalAmountToDepositAt(uint8 _classId, uint48 _batchId)
        public
        view
        onlyValidShareClass(_classId)
        returns (uint256)
    {
        return _getStorage().shareClasses[_classId].depositRequests[_batchId].totalAmountToDeposit;
    }

    /// @inheritdoc IAlephVault
    function totalAmountToRedeemOf(uint8 _classId, address _user) external view returns (uint256) {
        AlephVaultStorageData storage _sd = _getStorage();
        return _pendingAssetsOf(_sd, _classId, _currentBatch(_sd), _user, _assetsPerClassOf(_sd, _classId, _user));
    }

    /// @inheritdoc IAlephVault
    function depositRequestOf(uint8 _classId, address _user) external view returns (uint256 _totalAmountToDeposit) {
        AlephVaultStorageData storage _sd = _getStorage();
        uint48 _currentBatch = _currentBatch(_sd);
        if (_currentBatch > 0) {
            uint48 _depositSettleId = _sd.shareClasses[_classId].depositSettleId;
            for (_depositSettleId; _depositSettleId < _currentBatch; _depositSettleId++) {
                _totalAmountToDeposit +=
                    _sd.shareClasses[_classId].depositRequests[_depositSettleId].depositRequest[_user];
            }
        }
    }

    /// @inheritdoc IAlephVault
    function depositRequestOfAt(uint8 _classId, address _user, uint48 _batchId)
        external
        view
        returns (uint256 _amountToDeposit)
    {
        return _getStorage().shareClasses[_classId].depositRequests[_batchId].depositRequest[_user];
    }

    /// @inheritdoc IAlephVault
    function redeemRequestOf(uint8 _classId, address _user) external view returns (uint256 _totalAmountToRedeem) {
        AlephVaultStorageData storage _sd = _getStorage();
        uint48 _currentBatch = _currentBatch(_sd);
        if (_currentBatch > 0) {
            uint48 _redeemSettleId = _sd.shareClasses[_classId].redeemSettleId;
            for (_redeemSettleId; _redeemSettleId < _currentBatch; _redeemSettleId++) {
                _totalAmountToRedeem += _sd.shareClasses[_classId].redeemRequests[_redeemSettleId].redeemRequest[_user];
            }
        }
    }

    /// @inheritdoc IAlephVault
    function redeemRequestOfAt(uint8 _classId, address _user, uint48 _batchId)
        external
        view
        returns (uint256 _amountShareToRedeem)
    {
        return _getStorage().shareClasses[_classId].redeemRequests[_batchId].redeemRequest[_user];
    }

    /// @inheritdoc IAlephVault
    function usersToDepositAt(uint8 _classId, uint48 _batchId) external view returns (address[] memory) {
        return _getStorage().shareClasses[_classId].depositRequests[_batchId].usersToDeposit;
    }

    /// @inheritdoc IAlephVault
    function usersToRedeemAt(uint8 _classId, uint48 _batchId) external view returns (address[] memory) {
        return _getStorage().shareClasses[_classId].redeemRequests[_batchId].usersToRedeem;
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

    /// @inheritdoc IAlephVault
    function createShareClass(
        uint32 _managementFee,
        uint32 _performanceFee,
        uint256 _minDepositAmount,
        uint256 _maxDepositCap
    ) external onlyRole(RolesLibrary.MANAGER) returns (uint8 _classId) {
        if (_managementFee > MAXIMUM_MANAGEMENT_FEE || _performanceFee > MAXIMUM_PERFORMANCE_FEE) {
            revert InvalidVaultFee();
        }
        return _createShareClass(_getStorage(), _managementFee, _performanceFee, _minDepositAmount, _maxDepositCap);
    }

    /**
     * @notice Queues a new minimum deposit amount to be set after the timelock period
     * @param _classId The ID of the share class to set the minimum deposit amount for.
     * @param _minDepositAmount The new minimum deposit amount to be set.
     * @dev Only callable by the MANAGER role.
     */
    function queueMinDepositAmount(uint8 _classId, uint256 _minDepositAmount)
        external
        onlyValidShareClass(_classId)
        onlyRole(RolesLibrary.MANAGER)
    {
        _delegate(ModulesLibrary.ALEPH_VAULT_DEPOSIT);
    }

    /**
     * @notice Queues a new maximum deposit cap to be set after the timelock period.
     * @param _classId The ID of the share class to set the maximum deposit cap for.
     * @param _maxDepositCap The new maximum deposit cap to be set.
     * @dev Only callable by the MANAGER role.
     */
    function queueMaxDepositCap(uint8 _classId, uint256 _maxDepositCap)
        external
        onlyValidShareClass(_classId)
        onlyRole(RolesLibrary.MANAGER)
    {
        _delegate(ModulesLibrary.ALEPH_VAULT_DEPOSIT);
    }

    /**
     * @notice Queues a new management fee to be set after the timelock period.
     * @param _classId The ID of the share class to set the management fee for.
     * @param _managementFee The new management fee to be set.
     * @dev Only callable by the MANAGER role.
     */
    function queueManagementFee(uint8 _classId, uint32 _managementFee)
        external
        onlyValidShareClass(_classId)
        onlyRole(RolesLibrary.MANAGER)
    {
        _delegate(ModulesLibrary.FEE_MANAGER);
    }

    /**
     * @notice Queues a new performance fee to be set after the timelock period.
     * @param _classId The ID of the share class to set the performance fee for.
     * @param _performanceFee The new performance fee to be set.
     * @dev Only callable by the MANAGER role.
     */
    function queuePerformanceFee(uint8 _classId, uint32 _performanceFee)
        external
        onlyValidShareClass(_classId)
        onlyRole(RolesLibrary.MANAGER)
    {
        _delegate(ModulesLibrary.FEE_MANAGER);
    }

    /**
     * @notice Queues a new fee recipient to be set after the timelock period.
     * @param _feeRecipient The new fee recipient to be set.
     * @dev Only callable by the OPERATIONS_MULTISIG role.
     */
    function queueFeeRecipient(address _feeRecipient) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
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
     * @dev Only callable by the MANAGER role.
     */
    function setManagementFee() external onlyRole(RolesLibrary.MANAGER) {
        _delegate(ModulesLibrary.FEE_MANAGER);
    }

    /**
     * @notice Sets the performance fee to the queued value after the timelock period.
     * @dev Only callable by the MANAGER role.
     */
    function setPerformanceFee() external onlyRole(RolesLibrary.MANAGER) {
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
     * @param _requestDepositParams The parameters for the deposit request.
     * @return _batchId The batch ID of the deposit.
     * @dev Only callable when the deposit request flow is not paused.
     */
    function requestDeposit(IERC7540Deposit.RequestDepositParams calldata _requestDepositParams)
        external
        onlyValidShareClass(_requestDepositParams.classId)
        whenFlowNotPaused(PausableFlows.DEPOSIT_REQUEST_FLOW)
        returns (uint48 _batchId)
    {
        _delegate(ModulesLibrary.ALEPH_VAULT_DEPOSIT);
    }

    /**
     * @notice Settles all pending deposits up to the current batch.
     * @param _classId The ID of the share class to settle deposits for.
     * @param _newTotalAssets The new total assets after settlement for each series.
     * @dev Only callable by the ORACLE role.
     */
    function settleDeposit(uint8 _classId, uint256[] calldata _newTotalAssets)
        external
        onlyRole(RolesLibrary.ORACLE)
        onlyValidShareClass(_classId)
        whenFlowNotPaused(PausableFlows.SETTLE_DEPOSIT_FLOW)
    {
        _delegate(ModulesLibrary.ALEPH_VAULT_SETTLEMENT);
    }

    /**
     * @notice Requests a redeem of shares.
     * @param _classId The ID of the share class to redeem shares from.
     * @param _amount The amount to redeem.
     * @return _batchId The batch ID of the redeem.
     * @dev Only callable when the redeem request flow is not paused.
     */
    function requestRedeem(uint8 _classId, uint256 _amount)
        external
        onlyValidShareClass(_classId)
        whenFlowNotPaused(PausableFlows.REDEEM_REQUEST_FLOW)
        returns (uint48 _batchId)
    {
        _delegate(ModulesLibrary.ALEPH_VAULT_REDEEM);
    }

    /**
     * @notice Settles all pending redeems up to the current batch.
     * @param _classId The ID of the share class to settle redeems for.
     * @param _newTotalAssets The new total assets after settlement for each series.
     * @dev Only callable by the ORACLE role.
     */
    function settleRedeem(uint8 _classId, uint256[] calldata _newTotalAssets)
        external
        onlyRole(RolesLibrary.ORACLE)
        onlyValidShareClass(_classId)
        whenFlowNotPaused(PausableFlows.SETTLE_REDEEM_FLOW)
    {
        _delegate(ModulesLibrary.ALEPH_VAULT_SETTLEMENT);
    }

    /**
     * @dev Internal function to create a new share class.
     * @param _sd The storage struct.
     * @param _managementFee The management fee.
     * @param _performanceFee The performance fee.
     * @param _minDepositAmount The minimum deposit amount.
     * @param _maxDepositCap The maximum deposit cap.
     * @return _classId The ID of the new share class.
     */
    function _createShareClass(
        AlephVaultStorageData storage _sd,
        uint32 _managementFee,
        uint32 _performanceFee,
        uint256 _minDepositAmount,
        uint256 _maxDepositCap
    ) internal returns (uint8 _classId) {
        _classId = ++_sd.shareClassesId;
        _sd.shareClasses[_classId].managementFee = _managementFee;
        _sd.shareClasses[_classId].performanceFee = _performanceFee;
        _sd.shareClasses[_classId].minDepositAmount = _minDepositAmount;
        _sd.shareClasses[_classId].maxDepositCap = _maxDepositCap;
        _sd.shareClasses[_classId].shareSeries[0].highWaterMark = PRICE_DENOMINATOR;
        emit ShareClassCreated(_classId, _managementFee, _performanceFee, _minDepositAmount, _maxDepositCap);
        return _classId;
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
