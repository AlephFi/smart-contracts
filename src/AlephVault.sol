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
import {ERC4626Math} from "@aleph-vault/libraries/ERC4626Math.sol";
import {Checkpoints} from "@aleph-vault/libraries/Checkpoints.sol";
import {RolesLibrary} from "@aleph-vault/libraries/RolesLibrary.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {AlephVaultDeposit} from "@aleph-vault/AlephVaultDeposit.sol";
import {AlephVaultRedeem} from "@aleph-vault/AlephVaultRedeem.sol";
import {AlephVaultSettlement} from "@aleph-vault/AlephVaultSettlement.sol";
import {FeeManager} from "@aleph-vault/FeeManager.sol";
import {AlephPausable} from "@aleph-vault/AlephPausable.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract AlephVault is IAlephVault, AlephVaultDeposit, AlephVaultRedeem, AlephPausable, AlephVaultSettlement {
    using SafeERC20 for IERC20;
    using Checkpoints for Checkpoints.Trace256;
    using SafeCast for uint256;

    address public immutable OPERATIONS_MULTISIG;

    /**
     * @notice Constructor.
     * @param _constructorParams Struct containing all initialization parameters.
     */
    constructor(IAlephVault.ConstructorParams memory _constructorParams) {
        if (
            _constructorParams.operationsMultisig == address(0) || _constructorParams.maxManagementFee == 0
                || _constructorParams.maxPerformanceFee == 0 || _constructorParams.managementFeeTimelock == 0
                || _constructorParams.performanceFeeTimelock == 0 || _constructorParams.feeRecipientTimelock == 0
                || _constructorParams.maxManagementFee >= 10_000 || _constructorParams.maxPerformanceFee >= 10_000
        ) {
            revert InvalidConstructorParams();
        }
        OPERATIONS_MULTISIG = _constructorParams.operationsMultisig;
        MAXIMUM_MANAGEMENT_FEE = _constructorParams.maxManagementFee;
        MAXIMUM_PERFORMANCE_FEE = _constructorParams.maxPerformanceFee;
        MANAGEMENT_FEE_TIMELOCK = _constructorParams.managementFeeTimelock;
        PERFORMANCE_FEE_TIMELOCK = _constructorParams.performanceFeeTimelock;
        FEE_RECIPIENT_TIMELOCK = _constructorParams.feeRecipientTimelock;
    }

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
            _initalizationParams.manager == address(0) || _initalizationParams.oracle == address(0)
                || _initalizationParams.guardian == address(0) || _initalizationParams.underlyingToken == address(0)
                || _initalizationParams.custodian == address(0) || _initalizationParams.feeRecipient == address(0)
                || _initalizationParams.managementFee > MAXIMUM_MANAGEMENT_FEE
                || _initalizationParams.performanceFee > MAXIMUM_PERFORMANCE_FEE
        ) {
            revert InvalidInitializationParams();
        }
        _sd.manager = _initalizationParams.manager;
        _sd.oracle = _initalizationParams.oracle;
        _sd.guardian = _initalizationParams.guardian;
        _sd.underlyingToken = _initalizationParams.underlyingToken;
        _sd.custodian = _initalizationParams.custodian;
        _sd.feeRecipient = _initalizationParams.feeRecipient;
        _sd.managementFee = _initalizationParams.managementFee;
        _sd.performanceFee = _initalizationParams.performanceFee;
        _sd.batchDuration = 1 days;
        _sd.name = _initalizationParams.name;
        _sd.startTimeStamp = Time.timestamp();
        _grantRole(RolesLibrary.OPERATIONS_MULTISIG, OPERATIONS_MULTISIG);
        _grantRole(RolesLibrary.MANAGER, _initalizationParams.manager);
        _grantRole(RolesLibrary.ORACLE, _initalizationParams.oracle);
        _grantRole(RolesLibrary.GUARDIAN, _initalizationParams.guardian);
        __AlephVaultDeposit_init(_initalizationParams.manager, _initalizationParams.guardian, OPERATIONS_MULTISIG);
        __AlephVaultRedeem_init(_initalizationParams.manager, _initalizationParams.guardian, OPERATIONS_MULTISIG);
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
    function currentBatch()
        public
        view
        override(AlephVaultDeposit, AlephVaultRedeem, AlephVaultSettlement, IAlephVault)
        returns (uint48)
    {
        AlephVaultStorageData storage _sd = _getStorage();
        return (Time.timestamp() - _sd.startTimeStamp) / _sd.batchDuration;
    }

    /// @inheritdoc IAlephVault
    function totalAssets()
        public
        view
        override(AlephVaultDeposit, AlephVaultRedeem, FeeManager, IAlephVault)
        returns (uint256)
    {
        return _getStorage().assets.latest();
    }

    /// @inheritdoc IAlephVault
    function totalShares()
        public
        view
        override(AlephVaultDeposit, AlephVaultRedeem, FeeManager, IAlephVault)
        returns (uint256)
    {
        return _getStorage().shares.latest();
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
    function sharesOf(address _user)
        public
        view
        override(AlephVaultRedeem, FeeManager, IAlephVault)
        returns (uint256)
    {
        return _getStorage().sharesOf[_user].latest();
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
    function totalDepositRequests() external view returns (uint256) {
        return _getStorage().batches[currentBatch()].totalAmountToDeposit;
    }

    /// @inheritdoc IAlephVault
    function totalRedeemRequests() external view returns (uint256) {
        return _getStorage().batches[currentBatch()].totalSharesToRedeem;
    }

    /// @inheritdoc IAlephVault
    function totalDepositRequestsAt(uint48 _batchId) external view returns (uint256) {
        return _getStorage().batches[_batchId].totalAmountToDeposit;
    }

    /// @inheritdoc IAlephVault
    function totalRedeemRequestsAt(uint48 _batchId) external view returns (uint256) {
        return _getStorage().batches[_batchId].totalSharesToRedeem;
    }

    /// @inheritdoc IAlephVault
    function usersToDeposit() external view returns (address[] memory) {
        return _getStorage().batches[currentBatch()].usersToDeposit;
    }

    /// @inheritdoc IAlephVault
    function usersToRedeem() external view returns (address[] memory) {
        return _getStorage().batches[currentBatch()].usersToRedeem;
    }

    /// @inheritdoc IAlephVault
    function usersToDepositAt(uint48 _batchId) external view returns (address[] memory) {
        return _getStorage().batches[_batchId].usersToDeposit;
    }

    /// @inheritdoc IAlephVault
    function usersToRedeemAt(uint48 _batchId) external view returns (address[] memory) {
        return _getStorage().batches[_batchId].usersToRedeem;
    }

    /// @inheritdoc IAlephVault
    function depositRequestOf(address _user) external view returns (uint256) {
        return _getStorage().batches[currentBatch()].depositRequest[_user];
    }

    /// @inheritdoc IAlephVault
    function redeemRequestOf(address _user) external view returns (uint256) {
        return _getStorage().batches[currentBatch()].redeemRequest[_user];
    }

    /// @inheritdoc IAlephVault
    function depositRequestOfAt(address _user, uint48 _batchId) external view returns (uint256) {
        return _getStorage().batches[_batchId].depositRequest[_user];
    }

    /// @inheritdoc IAlephVault
    function redeemRequestOfAt(address _user, uint48 _batchId) external view returns (uint256) {
        return _getStorage().batches[_batchId].redeemRequest[_user];
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
    function highWaterMark() public view override(AlephVaultSettlement, IAlephVault) returns (uint256) {
        return _getStorage().highWaterMark.latest();
    }

    /// @inheritdoc IAlephVault
    function highWaterMarkAt(uint48 _timestamp) public view returns (uint256) {
        return _getStorage().highWaterMark.upperLookupRecent(_timestamp);
    }

    /// @inheritdoc IAlephVault
    function metadataUri() external view returns (string memory) {
        return _getStorage().metadataUri;
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

    /**
     * @notice Queues a new management fee to be set after the timelock period.
     * @param _managementFee The new management fee to be set.
     * @dev Only callable by the MANAGER role.
     */
    function queueManagementFee(uint32 _managementFee) external override(FeeManager) onlyRole(RolesLibrary.MANAGER) {
        _queueManagementFee(_getStorage(), _managementFee);
    }

    /**
     * @notice Queues a new performance fee to be set after the timelock period.
     * @param _performanceFee The new performance fee to be set.
     * @dev Only callable by the MANAGER role.
     */
    function queuePerformanceFee(uint32 _performanceFee) external override(FeeManager) onlyRole(RolesLibrary.MANAGER) {
        _queuePerformanceFee(_getStorage(), _performanceFee);
    }

    /**
     * @notice Queues a new fee recipient to be set after the timelock period.
     * @param _feeRecipient The new fee recipient to be set.
     * @dev Only callable by the OPERATIONS_MULTISIG role.
     */
    function queueFeeRecipient(address _feeRecipient)
        external
        override(FeeManager)
        onlyRole(RolesLibrary.OPERATIONS_MULTISIG)
    {
        _queueFeeRecipient(_getStorage(), _feeRecipient);
    }

    /**
     * @notice Sets the management fee to the queued value after the timelock period.
     * @dev Only callable by the MANAGER role.
     */
    function setManagementFee() external override(FeeManager) onlyRole(RolesLibrary.MANAGER) {
        _setManagementFee(_getStorage());
    }

    /**
     * @notice Sets the performance fee to the queued value after the timelock period.
     * @dev Only callable by the MANAGER role.
     */
    function setPerformanceFee() external override(FeeManager) onlyRole(RolesLibrary.MANAGER) {
        _setPerformanceFee(_getStorage());
    }

    /**
     * @notice Sets the fee recipient to the queued value after the timelock period.
     * @dev Only callable by the OPERATIONS_MULTISIG role.
     */
    function setFeeRecipient() external override(FeeManager) onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        _setFeeRecipient(_getStorage());
    }

    /**
     * @notice Collects all pending fees.
     * @dev Only callable by the MANAGER role.
     */
    function collectFees()
        external
        override(FeeManager)
        onlyRole(RolesLibrary.MANAGER)
        returns (uint256 _managementFeesToCollect, uint256 _performanceFeesToCollect)
    {
        return _collectFees(_getStorage());
    }

    /**
     * @notice Requests a deposit of assets.
     * @param _amount The amount of assets to deposit.
     * @return _batchId The batch ID of the deposit.
     * @dev Only callable when the deposit request flow is not paused.
     */
    function requestDeposit(uint256 _amount)
        external
        override(AlephVaultDeposit)
        whenFlowNotPaused(PausableFlows.DEPOSIT_REQUEST_FLOW)
        returns (uint48 _batchId)
    {
        return _requestDeposit(_amount);
    }

    /**
     * @notice Settles all pending deposits up to the current batch.
     * @param _newTotalAssets The new total assets after settlement.
     * @dev Only callable by the ORACLE role.
     */
    function settleDeposit(uint256 _newTotalAssets)
        external
        override(AlephVaultDeposit)
        onlyRole(RolesLibrary.ORACLE)
        whenFlowNotPaused(PausableFlows.SETTLE_DEPOSIT_FLOW)
    {
        _settleDeposit(_getStorage(), _newTotalAssets);
    }

    /**
     * @notice Requests a redeem of shares.
     * @param _shares The number of shares to redeem.
     * @return _batchId The batch ID of the redeem.
     * @dev Only callable when the redeem request flow is not paused.
     */
    function requestRedeem(uint256 _shares)
        external
        override(AlephVaultRedeem)
        whenFlowNotPaused(PausableFlows.REDEEM_REQUEST_FLOW)
        returns (uint48 _batchId)
    {
        return _requestRedeem(_shares);
    }

    /**
     * @notice Settles all pending redeems up to the current batch.
     * @param _newTotalAssets The new total assets after settlement.
     * @dev Only callable by the ORACLE role.
     */
    function settleRedeem(uint256 _newTotalAssets)
        external
        override(AlephVaultRedeem)
        onlyRole(RolesLibrary.ORACLE)
        whenFlowNotPaused(PausableFlows.SETTLE_REDEEM_FLOW)
    {
        _settleRedeem(_getStorage(), _newTotalAssets);
    }

    /**
     * @dev Returns the storage struct for the vault.
     * @return sd The storage struct.
     */
    function _getStorage()
        internal
        pure
        override(AlephVaultDeposit, AlephVaultRedeem)
        returns (AlephVaultStorageData storage sd)
    {
        return AlephVaultStorage.load();
    }
}
