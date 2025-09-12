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

import {SafeCast} from "openzeppelin-contracts/contracts/utils/math/SafeCast.sol";
import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {IAccountant} from "@aleph-vault/interfaces/IAccountant.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephVaultDeposit} from "@aleph-vault/interfaces/IAlephVaultDeposit.sol";
import {IAlephVaultSettlement} from "@aleph-vault/interfaces/IAlephVaultSettlement.sol";
import {ModulesLibrary} from "@aleph-vault/libraries/ModulesLibrary.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {RolesLibrary} from "@aleph-vault/libraries/RolesLibrary.sol";
import {AlephPausable} from "@aleph-vault/AlephPausable.sol";
import {AlephVaultBase} from "@aleph-vault/AlephVaultBase.sol";
import {AlephVaultStorageData} from "@aleph-vault/AlephVaultStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract AlephVault is IAlephVault, AlephVaultBase, AlephPausable {
    using SafeCast for uint256;

    modifier onlyValidShareClass(uint8 _classId) {
        // check if share class id is valid or not
        if (_classId > _getStorage().shareClassesId || _classId == 0) {
            revert InvalidShareClass();
        }
        _;
    }

    modifier onlyValidShareClassAndSeries(uint8 _classId, uint8 _seriesId) {
        AlephVaultStorageData storage _sd = _getStorage();
        // check if share class id is valid or not
        if (_classId > _sd.shareClassesId || _classId == 0) {
            revert InvalidShareClass();
        }
        // check if share series id is valid or not
        // series that haven't been created yet or that have been consolidated are considered invalid
        IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_classId];

        if (
            _seriesId > _shareClass.shareSeriesId
                || (_seriesId > LEAD_SERIES_ID && _seriesId <= _shareClass.lastConsolidatedSeriesId)
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
     * @param _initializationParams Struct containing all initialization parameters.
     */
    function initialize(InitializationParams calldata _initializationParams) public initializer {
        _initialize(_initializationParams);
    }

    /**
     * @dev Internal function to set up vault storage and roles.
     * @param _initializationParams Struct containing all initialization parameters.
     */
    function _initialize(InitializationParams calldata _initializationParams) internal onlyInitializing {
        AlephVaultStorageData storage _sd = _getStorage();
        __AccessControl_init();
        if (
            _initializationParams.userInitializationParams.manager == address(0)
                || _initializationParams.operationsMultisig == address(0)
                || _initializationParams.vaultFactory == address(0) || _initializationParams.oracle == address(0)
                || _initializationParams.guardian == address(0) || _initializationParams.authSigner == address(0)
                || _initializationParams.userInitializationParams.underlyingToken == address(0)
                || _initializationParams.userInitializationParams.custodian == address(0)
                || _initializationParams.userInitializationParams.vaultTreasury == address(0)
                || _initializationParams.accountant == address(0)
                || _initializationParams.moduleInitializationParams.alephVaultDepositImplementation == address(0)
                || _initializationParams.moduleInitializationParams.alephVaultRedeemImplementation == address(0)
                || _initializationParams.moduleInitializationParams.alephVaultSettlementImplementation == address(0)
                || _initializationParams.moduleInitializationParams.feeManagerImplementation == address(0)
                || _initializationParams.moduleInitializationParams.migrationManagerImplementation == address(0)
                || _initializationParams.userInitializationParams.shareClassParams.managementFee > MAXIMUM_MANAGEMENT_FEE
                || _initializationParams.userInitializationParams.shareClassParams.performanceFee > MAXIMUM_PERFORMANCE_FEE
        ) {
            revert InvalidInitializationParams();
        }
        // set up storage variables
        _sd.operationsMultisig = _initializationParams.operationsMultisig;
        _sd.oracle = _initializationParams.oracle;
        _sd.guardian = _initializationParams.guardian;
        _sd.authSigner = _initializationParams.authSigner;
        _sd.accountant = _initializationParams.accountant;
        _sd.name = _initializationParams.userInitializationParams.name;
        _sd.manager = _initializationParams.userInitializationParams.manager;
        _sd.underlyingToken = _initializationParams.userInitializationParams.underlyingToken;
        _sd.custodian = _initializationParams.userInitializationParams.custodian;
        _sd.isDepositAuthEnabled = true;
        _sd.isSettlementAuthEnabled = true;
        _sd.startTimeStamp = Time.timestamp();

        // set up module implementations
        _sd.moduleImplementations[ModulesLibrary.ALEPH_VAULT_DEPOSIT] =
            _initializationParams.moduleInitializationParams.alephVaultDepositImplementation;
        _sd.moduleImplementations[ModulesLibrary.ALEPH_VAULT_REDEEM] =
            _initializationParams.moduleInitializationParams.alephVaultRedeemImplementation;
        _sd.moduleImplementations[ModulesLibrary.ALEPH_VAULT_SETTLEMENT] =
            _initializationParams.moduleInitializationParams.alephVaultSettlementImplementation;
        _sd.moduleImplementations[ModulesLibrary.FEE_MANAGER] =
            _initializationParams.moduleInitializationParams.feeManagerImplementation;
        _sd.moduleImplementations[ModulesLibrary.MIGRATION_MANAGER] =
            _initializationParams.moduleInitializationParams.migrationManagerImplementation;

        // grant roles
        _grantRole(RolesLibrary.OPERATIONS_MULTISIG, _initializationParams.operationsMultisig);
        _grantRole(RolesLibrary.VAULT_FACTORY, _initializationParams.vaultFactory);
        _grantRole(RolesLibrary.MANAGER, _initializationParams.userInitializationParams.manager);
        _grantRole(RolesLibrary.ORACLE, _initializationParams.oracle);
        _grantRole(RolesLibrary.GUARDIAN, _initializationParams.guardian);
        _grantRole(RolesLibrary.ACCOUNTANT, _initializationParams.accountant);

        // initialize pausable modules
        __AlephVaultDeposit_init(
            _initializationParams.userInitializationParams.manager,
            _initializationParams.guardian,
            _initializationParams.operationsMultisig
        );
        __AlephVaultRedeem_init(
            _initializationParams.userInitializationParams.manager,
            _initializationParams.guardian,
            _initializationParams.operationsMultisig
        );
        // initialize reentrancy guard
        __ReentrancyGuard_init();

        // create default share class
        _createShareClass(_sd, _initializationParams.userInitializationParams.shareClassParams);

        // set vault treasury
        IAccountant(_initializationParams.accountant).setVaultTreasury(
            _initializationParams.userInitializationParams.vaultTreasury
        );
    }

    /// @inheritdoc IAlephVault
    function currentBatch() public view returns (uint48) {
        return _currentBatch(_getStorage());
    }

    /// @inheritdoc IAlephVault
    function shareClasses() external view returns (uint8) {
        return _getStorage().shareClassesId;
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
    function operationsMultisig() external view returns (address) {
        return _getStorage().operationsMultisig;
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
    function vaultTreasury() external view returns (address) {
        return IAccountant(_getStorage().accountant).vaultTreasury();
    }

    /// @inheritdoc IAlephVault
    function accountant() external view returns (address) {
        return _getStorage().accountant;
    }

    /// @inheritdoc IAlephVault
    function managementFee(uint8 _classId) external view onlyValidShareClass(_classId) returns (uint32) {
        return _getStorage().shareClasses[_classId].shareClassParams.managementFee;
    }

    /// @inheritdoc IAlephVault
    function performanceFee(uint8 _classId) external view onlyValidShareClass(_classId) returns (uint32) {
        return _getStorage().shareClasses[_classId].shareClassParams.performanceFee;
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
    function totalAssetsOfClass(uint8 _classId)
        external
        view
        onlyValidShareClass(_classId)
        returns (uint256[] memory)
    {
        IAlephVault.ShareClass storage _shareClass = _getStorage().shareClasses[_classId];
        uint8 _shareSeriesId = _shareClass.shareSeriesId;
        uint8 _lastConsolidatedSeriesId = _shareClass.lastConsolidatedSeriesId;
        uint8 _len = _shareSeriesId - _lastConsolidatedSeriesId + 1;
        uint256[] memory _totalAssets = new uint256[](_len);
        for (uint8 _i; _i < _len; _i++) {
            uint8 _seriesId = _i > LEAD_SERIES_ID ? _lastConsolidatedSeriesId + _i : LEAD_SERIES_ID;
            _totalAssets[_i] = _totalAssetsPerSeries(_shareClass, _classId, _seriesId);
        }
        return _totalAssets;
    }

    /// @inheritdoc IAlephVault
    function totalSharesOfClass(uint8 _classId)
        external
        view
        onlyValidShareClass(_classId)
        returns (uint256[] memory)
    {
        IAlephVault.ShareClass storage _shareClass = _getStorage().shareClasses[_classId];
        uint8 _shareSeriesId = _shareClass.shareSeriesId;
        uint8 _lastConsolidatedSeriesId = _shareClass.lastConsolidatedSeriesId;
        uint8 _len = _shareSeriesId - _lastConsolidatedSeriesId + 1;
        uint256[] memory _totalShares = new uint256[](_len);
        for (uint8 _i; _i < _len; _i++) {
            uint8 _seriesId = _i > LEAD_SERIES_ID ? _lastConsolidatedSeriesId + _i : LEAD_SERIES_ID;
            _totalShares[_i] = _totalSharesPerSeries(_shareClass, _classId, _seriesId);
        }
        return _totalShares;
    }

    /// @inheritdoc IAlephVault
    function totalAssetsPerClass(uint8 _classId) external view onlyValidShareClass(_classId) returns (uint256) {
        return _totalAssetsPerClass(_getStorage().shareClasses[_classId], _classId);
    }

    /// @inheritdoc IAlephVault
    function totalSharesPerClass(uint8 _classId) external view onlyValidShareClass(_classId) returns (uint256) {
        return _totalSharesPerClass(_getStorage().shareClasses[_classId], _classId);
    }

    /// @inheritdoc IAlephVault
    function totalAssetsPerSeries(uint8 _classId, uint8 _seriesId)
        public
        view
        onlyValidShareClassAndSeries(_classId, _seriesId)
        returns (uint256)
    {
        return _totalAssetsPerSeries(_getStorage().shareClasses[_classId], _classId, _seriesId);
    }

    /// @inheritdoc IAlephVault
    function totalSharesPerSeries(uint8 _classId, uint8 _seriesId)
        public
        view
        onlyValidShareClassAndSeries(_classId, _seriesId)
        returns (uint256)
    {
        return _totalSharesPerSeries(_getStorage().shareClasses[_classId], _classId, _seriesId);
    }

    /// @inheritdoc IAlephVault
    function sharesOf(uint8 _classId, uint8 _seriesId, address _user)
        public
        view
        onlyValidShareClassAndSeries(_classId, _seriesId)
        returns (uint256)
    {
        return _sharesOf(_getStorage().shareClasses[_classId], _seriesId, _user);
    }

    /// @inheritdoc IAlephVault
    function assetsOf(uint8 _classId, uint8 _seriesId, address _user)
        public
        view
        onlyValidShareClassAndSeries(_classId, _seriesId)
        returns (uint256)
    {
        return _assetsOf(_getStorage().shareClasses[_classId], _classId, _seriesId, _user);
    }

    /// @inheritdoc IAlephVault
    function pricePerShare(uint8 _classId, uint8 _seriesId)
        public
        view
        onlyValidShareClassAndSeries(_classId, _seriesId)
        returns (uint256)
    {
        IAlephVault.ShareClass storage _shareClass = _getStorage().shareClasses[_classId];
        return _getPricePerShare(
            _totalAssetsPerSeries(_shareClass, _classId, _seriesId),
            _totalSharesPerSeries(_shareClass, _classId, _seriesId)
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
    function noticePeriod(uint8 _classId) public view onlyValidShareClass(_classId) returns (uint48) {
        return _getStorage().shareClasses[_classId].shareClassParams.noticePeriod;
    }

    /// @inheritdoc IAlephVault
    function lockInPeriod(uint8 _classId) public view onlyValidShareClass(_classId) returns (uint48) {
        return _getStorage().shareClasses[_classId].shareClassParams.lockInPeriod;
    }

    /// @inheritdoc IAlephVault
    function minDepositAmount(uint8 _classId) public view onlyValidShareClass(_classId) returns (uint256) {
        return _getStorage().shareClasses[_classId].shareClassParams.minDepositAmount;
    }

    /// @inheritdoc IAlephVault
    function minUserBalance(uint8 _classId) public view onlyValidShareClass(_classId) returns (uint256) {
        return _getStorage().shareClasses[_classId].shareClassParams.minUserBalance;
    }

    /// @inheritdoc IAlephVault
    function maxDepositCap(uint8 _classId) public view onlyValidShareClass(_classId) returns (uint256) {
        return _getStorage().shareClasses[_classId].shareClassParams.maxDepositCap;
    }

    /// @inheritdoc IAlephVault
    function minRedeemAmount(uint8 _classId) public view onlyValidShareClass(_classId) returns (uint256) {
        return _getStorage().shareClasses[_classId].shareClassParams.minRedeemAmount;
    }

    /// @inheritdoc IAlephVault
    function userLockInPeriod(uint8 _classId, address _user)
        public
        view
        onlyValidShareClass(_classId)
        returns (uint48)
    {
        return _getStorage().shareClasses[_classId].userLockInPeriod[_user];
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
    function depositRequestOf(uint8 _classId, address _user) external view returns (uint256 _totalAmountToDeposit) {
        return _depositRequestOf(_getStorage(), _classId, _user);
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
        IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_classId];
        return _pendingAssetsOf(
            _shareClass, _classId, _currentBatch(_sd), _user, _assetsPerClassOf(_classId, _user, _shareClass)
        );
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
    function totalFeeAmountToCollect() external view returns (uint256 _totalFeeAmountToCollect) {
        AlephVaultStorageData storage _sd = _getStorage();
        uint8 _shareClasses = _sd.shareClassesId;
        for (uint8 _classId = 1; _classId <= _shareClasses; _classId++) {
            IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_classId];
            _totalFeeAmountToCollect += _assetsPerClassOf(_classId, MANAGEMENT_FEE_RECIPIENT, _shareClass);
            _totalFeeAmountToCollect += _assetsPerClassOf(_classId, PERFORMANCE_FEE_RECIPIENT, _shareClass);
        }
    }

    /// @inheritdoc IAlephVault
    function isDepositAuthEnabled() external view returns (bool) {
        return _getStorage().isDepositAuthEnabled;
    }

    /// @inheritdoc IAlephVault
    function isSettlementAuthEnabled() external view returns (bool) {
        return _getStorage().isSettlementAuthEnabled;
    }

    /// @inheritdoc IAlephVault
    function setIsDepositAuthEnabled(bool _isDepositAuthEnabled)
        external
        override(IAlephVault)
        onlyRole(RolesLibrary.MANAGER)
    {
        _getStorage().isDepositAuthEnabled = _isDepositAuthEnabled;
        emit IsDepositAuthEnabledSet(_isDepositAuthEnabled);
    }

    /// @inheritdoc IAlephVault
    function setIsSettlementAuthEnabled(bool _isSettlementAuthEnabled)
        external
        override(IAlephVault)
        onlyRole(RolesLibrary.MANAGER)
    {
        _getStorage().isSettlementAuthEnabled = _isSettlementAuthEnabled;
        emit IsSettlementAuthEnabledSet(_isSettlementAuthEnabled);
    }

    /// @inheritdoc IAlephVault
    function setVaultTreasury(address _vaultTreasury) external override(IAlephVault) onlyRole(RolesLibrary.MANAGER) {
        IAccountant(_getStorage().accountant).setVaultTreasury(_vaultTreasury);
        emit VaultTreasurySet(_vaultTreasury);
    }

    /// @inheritdoc IAlephVault
    function createShareClass(ShareClassParams memory _shareClassParams)
        external
        onlyRole(RolesLibrary.MANAGER)
        returns (uint8 _classId)
    {
        if (
            _shareClassParams.managementFee > MAXIMUM_MANAGEMENT_FEE
                || _shareClassParams.performanceFee > MAXIMUM_PERFORMANCE_FEE
        ) {
            revert InvalidVaultFee();
        }
        return _createShareClass(_getStorage(), _shareClassParams);
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
     * @notice Queues a new minimum user balance to be set after the timelock period.
     * @param _classId The ID of the share class to set the minimum user balance for.
     * @param _minUserBalance The new minimum user balance to be set.
     * @dev Only callable by the MANAGER role.
     */
    function queueMinUserBalance(uint8 _classId, uint256 _minUserBalance)
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
     * @notice Queues a new notice period to be set after the timelock period.
     * @param _classId The ID of the share class to set the notice period for.
     * @param _noticePeriod The new notice period to be set.
     * @dev Only callable by the MANAGER role.
     */
    function queueNoticePeriod(uint8 _classId, uint48 _noticePeriod)
        external
        onlyValidShareClass(_classId)
        onlyRole(RolesLibrary.MANAGER)
    {
        _delegate(ModulesLibrary.ALEPH_VAULT_REDEEM);
    }

    /**
     * @notice Queues a new lock in period to be set after the timelock period.
     * @param _classId The ID of the share class to set the lock in period for.
     * @param _lockInPeriod The new lock in period to be set.
     * @dev Only callable by the MANAGER role.
     */
    function queueLockInPeriod(uint8 _classId, uint48 _lockInPeriod)
        external
        onlyValidShareClass(_classId)
        onlyRole(RolesLibrary.MANAGER)
    {
        _delegate(ModulesLibrary.ALEPH_VAULT_REDEEM);
    }

    /**
     * @notice Queues a new minimum redeem amount to be set after the timelock period.
     * @param _classId The ID of the share class to set the minimum redeem amount for.
     * @param _minRedeemAmount The new minimum redeem amount to be set.
     * @dev Only callable by the MANAGER role.
     */
    function queueMinRedeemAmount(uint8 _classId, uint256 _minRedeemAmount)
        external
        onlyValidShareClass(_classId)
        onlyRole(RolesLibrary.MANAGER)
    {
        _delegate(ModulesLibrary.ALEPH_VAULT_REDEEM);
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
     * @notice Sets the minimum deposit amount to the queued value after the timelock period.
     * @param _classId The ID of the share class to set the minimum deposit amount for.
     * @dev Only callable by the MANAGER role.
     */
    function setMinDepositAmount(uint8 _classId)
        external
        onlyValidShareClass(_classId)
        onlyRole(RolesLibrary.MANAGER)
    {
        _delegate(ModulesLibrary.ALEPH_VAULT_DEPOSIT);
    }

    /**
     * @notice Sets the minimum user balance to the queued value after the timelock period.
     * @param _classId The ID of the share class to set the minimum user balance for.
     * @dev Only callable by the MANAGER role.
     */
    function setMinUserBalance(uint8 _classId) external onlyValidShareClass(_classId) onlyRole(RolesLibrary.MANAGER) {
        _delegate(ModulesLibrary.ALEPH_VAULT_DEPOSIT);
    }

    /**
     * @notice Sets the maximum deposit cap to the queued value after the timelock period.
     * @param _classId The ID of the share class to set the maximum deposit cap for.
     * @dev Only callable by the MANAGER role.
     */
    function setMaxDepositCap(uint8 _classId) external onlyValidShareClass(_classId) onlyRole(RolesLibrary.MANAGER) {
        _delegate(ModulesLibrary.ALEPH_VAULT_DEPOSIT);
    }

    /**
     * @notice Sets the notice period to the queued value after the timelock period.
     * @param _classId The ID of the share class to set the notice period for.
     * @dev Only callable by the MANAGER role.
     */
    function setNoticePeriod(uint8 _classId) external onlyValidShareClass(_classId) onlyRole(RolesLibrary.MANAGER) {
        _delegate(ModulesLibrary.ALEPH_VAULT_REDEEM);
    }

    /**
     * @notice Sets the lock in period to the queued value after the timelock period.
     * @param _classId The ID of the share class to set the lock in period for.
     * @dev Only callable by the MANAGER role.
     */
    function setLockInPeriod(uint8 _classId) external onlyValidShareClass(_classId) onlyRole(RolesLibrary.MANAGER) {
        _delegate(ModulesLibrary.ALEPH_VAULT_REDEEM);
    }

    /**
     * @notice Sets the minimum redeem amount to the queued value after the timelock period.
     * @param _classId The ID of the share class to set the minimum redeem amount for.
     * @dev Only callable by the MANAGER role.
     */
    function setMinRedeemAmount(uint8 _classId) external onlyValidShareClass(_classId) onlyRole(RolesLibrary.MANAGER) {
        _delegate(ModulesLibrary.ALEPH_VAULT_REDEEM);
    }

    /**
     * @notice Sets the management fee to the queued value after the timelock period.
     * @param _classId The ID of the share class to set the management fee for.
     * @dev Only callable by the MANAGER role.
     */
    function setManagementFee(uint8 _classId) external onlyValidShareClass(_classId) onlyRole(RolesLibrary.MANAGER) {
        _delegate(ModulesLibrary.FEE_MANAGER);
    }

    /**
     * @notice Sets the performance fee to the queued value after the timelock period.
     * @param _classId The ID of the share class to set the performance fee for.
     * @dev Only callable by the MANAGER role.
     */
    function setPerformanceFee(uint8 _classId) external onlyValidShareClass(_classId) onlyRole(RolesLibrary.MANAGER) {
        _delegate(ModulesLibrary.FEE_MANAGER);
    }

    /**
     * @notice Collects all pending fees.
     * @dev Only callable by the OPERATIONS_MULTISIG role.
     */
    function collectFees()
        external
        onlyRole(RolesLibrary.ACCOUNTANT)
        returns (uint256 _managementFeesToCollect, uint256 _performanceFeesToCollect)
    {
        _delegate(ModulesLibrary.FEE_MANAGER);
    }

    /**
     * @notice Requests a deposit of assets.
     * @param _requestDepositParams The parameters for the deposit request.
     * @return _batchId The batch ID of the deposit.
     * @dev Only callable when the deposit request flow is not paused.
     */
    function requestDeposit(IAlephVaultDeposit.RequestDepositParams calldata _requestDepositParams)
        external
        onlyValidShareClass(_requestDepositParams.classId)
        whenFlowNotPaused(PausableFlows.DEPOSIT_REQUEST_FLOW)
        returns (uint48 _batchId)
    {
        _delegate(ModulesLibrary.ALEPH_VAULT_DEPOSIT);
    }

    /**
     * @notice Settles all pending deposits up to the current batch.
     * @param _settlementParams The parameters for the settlement.
     * @dev Only callable by the ORACLE role.
     */
    function settleDeposit(IAlephVaultSettlement.SettlementParams calldata _settlementParams)
        external
        onlyRole(RolesLibrary.ORACLE)
        onlyValidShareClass(_settlementParams.classId)
        whenFlowNotPaused(PausableFlows.SETTLE_DEPOSIT_FLOW)
    {
        _delegate(ModulesLibrary.ALEPH_VAULT_SETTLEMENT);
    }

    /**
     * @notice Requests a redeem of shares.
     * @param _classId The ID of the share class to redeem shares from.
     * @param _shareUnits The share units to redeem from remaing assets.
     * @return _batchId The batch ID of the redeem.
     * @dev Only callable when the redeem request flow is not paused.
     */
    function requestRedeem(uint8 _classId, uint256 _shareUnits)
        external
        onlyValidShareClass(_classId)
        whenFlowNotPaused(PausableFlows.REDEEM_REQUEST_FLOW)
        returns (uint48 _batchId)
    {
        _delegate(ModulesLibrary.ALEPH_VAULT_REDEEM);
    }

    /**
     * @notice Settles all pending redeems up to the current batch.
     * @param _settlementParams The parameters for the settlement.
     * @dev Only callable by the ORACLE role.
     */
    function settleRedeem(IAlephVaultSettlement.SettlementParams calldata _settlementParams)
        external
        onlyRole(RolesLibrary.ORACLE)
        onlyValidShareClass(_settlementParams.classId)
        whenFlowNotPaused(PausableFlows.SETTLE_REDEEM_FLOW)
    {
        _delegate(ModulesLibrary.ALEPH_VAULT_SETTLEMENT);
    }

    /**
     * @notice Migrates the operations multisig.
     * @param _newOperationsMultisig The new operations multisig.
     * @dev Only callable by the VAULT_FACTORY role.
     */
    function migrateOperationsMultisig(address _newOperationsMultisig) external onlyRole(RolesLibrary.VAULT_FACTORY) {
        _delegate(ModulesLibrary.MIGRATION_MANAGER);
    }

    /**
     * @notice Migrates the oracle.
     * @param _newOracle The new oracle.
     * @dev Only callable by the VAULT_FACTORY role.
     */
    function migrateOracle(address _newOracle) external onlyRole(RolesLibrary.VAULT_FACTORY) {
        _delegate(ModulesLibrary.MIGRATION_MANAGER);
    }

    /**
     * @notice Migrates the guardian.
     * @param _newGuardian The new guardian.
     * @dev Only callable by the VAULT_FACTORY role.
     */
    function migrateGuardian(address _newGuardian) external onlyRole(RolesLibrary.VAULT_FACTORY) {
        _delegate(ModulesLibrary.MIGRATION_MANAGER);
    }

    /**
     * @notice Migrates the authentication signer.
     * @param _newAuthSigner The new authentication signer.
     * @dev Only callable by the VAULT_FACTORY role.
     */
    function migrateAuthSigner(address _newAuthSigner) external onlyRole(RolesLibrary.VAULT_FACTORY) {
        _delegate(ModulesLibrary.MIGRATION_MANAGER);
    }

    /**
     * @notice Migrates the accountant.
     * @param _newAccountant The new accountant.
     * @dev Only callable by the VAULT_FACTORY role.
     */
    function migrateAccountant(address _newAccountant) external onlyRole(RolesLibrary.VAULT_FACTORY) {
        _delegate(ModulesLibrary.MIGRATION_MANAGER);
    }

    /**
     * @notice Migrates the module implementation.
     * @param _module The module.
     * @param _newImplementation The new implementation.
     * @dev Only callable by the VAULT_FACTORY role.
     */
    function migrateModules(bytes4 _module, address _newImplementation) external onlyRole(RolesLibrary.VAULT_FACTORY) {
        _delegate(ModulesLibrary.MIGRATION_MANAGER);
    }

    /**
     * @dev Internal function to create a new share class.
     * @param _sd The storage struct.
     * @param _shareClassParams The parameters for the share class.
     * @return _classId The ID of the new share class.
     */
    function _createShareClass(AlephVaultStorageData storage _sd, ShareClassParams memory _shareClassParams)
        internal
        returns (uint8 _classId)
    {
        // increment share classes id
        _classId = ++_sd.shareClassesId;
        // set up share class parameters
        IAlephVault.ShareClass storage _shareClass = _sd.shareClasses[_classId];
        _shareClass.shareClassParams = _shareClassParams;
        // set up lead series for new share class
        _shareClass.shareSeries[LEAD_SERIES_ID].highWaterMark = PRICE_DENOMINATOR;
        emit ShareClassCreated(_classId, _shareClassParams);
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
