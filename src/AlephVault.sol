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
import {AlephVaultDeposit} from "./AlephVaultDeposit.sol";
import {AlephVaultRedeem} from "./AlephVaultRedeem.sol";
import {IAlephVaultFactory} from "./interfaces/IAlephVaultFactory.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract AlephVault is IAlephVault, AlephVaultDeposit, AlephVaultRedeem, AccessControlUpgradeable {
    using SafeERC20 for IERC20;
    using Checkpoints for Checkpoints.Trace256;
    using SafeCast for uint256;

    address public immutable OPERATIONS_MULTISIG;
    address public immutable ORACLE;
    address public immutable GUARDIAN;

    /**
     * @notice Constructor.
     * @param _constructorParams Struct containing all initialization parameters.
     */
    constructor(IAlephVault.ConstructorParams memory _constructorParams) {
        OPERATIONS_MULTISIG = _constructorParams.operationsMultisig;
        ORACLE = _constructorParams.oracle;
        GUARDIAN = _constructorParams.guardian;
        _grantRole(RolesLibrary.OPERATIONS_MULTISIG, _constructorParams.operationsMultisig);
        _grantRole(RolesLibrary.ORACLE, _constructorParams.oracle);
        _grantRole(RolesLibrary.GUARDIAN, _constructorParams.guardian);
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
            _initalizationParams.manager == address(0) || _initalizationParams.underlyingToken == address(0)
                || _initalizationParams.custodian == address(0)
        ) {
            revert InvalidInitializationParams();
        }
        _sd.manager = _initalizationParams.manager;
        _sd.underlyingToken = _initalizationParams.underlyingToken;
        _sd.custodian = _initalizationParams.custodian;
        _sd.batchDuration = 1 days;
        _sd.name = _initalizationParams.name;
        _sd.startTimeStamp = Time.timestamp();
        _grantRole(RolesLibrary.MANAGER, _initalizationParams.manager);
    }

    /// @inheritdoc IAlephVault
    function underlyingToken() external view override(IAlephVault) returns (address) {
        return _getStorage().underlyingToken;
    }

    /// @inheritdoc IAlephVault
    function currentBatch() public view override(AlephVaultDeposit, AlephVaultRedeem, IAlephVault) returns (uint48) {
        AlephVaultStorageData storage _sd = _getStorage();
        return (Time.timestamp() - _sd.startTimeStamp) / _sd.batchDuration;
    }

    /// @inheritdoc IAlephVault
    function totalAssets() public view override(AlephVaultDeposit, AlephVaultRedeem, IAlephVault) returns (uint256) {
        return _getStorage().assets.latest();
    }

    /// @inheritdoc IAlephVault
    function totalShares() public view override(AlephVaultDeposit, AlephVaultRedeem, IAlephVault) returns (uint256) {
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
        override(AlephVaultRedeem, AlephVaultDeposit, IAlephVault)
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
    function metadataUrl() external view returns (string memory) {
        return _getStorage().metadataUrl;
    }

    /// @inheritdoc IAlephVault
    function name() external view returns (string memory) {
        return _getStorage().name;
    }

    /// @inheritdoc IAlephVault
    function setMetadataUrl(string calldata _metadataUrl)
        external
        override(IAlephVault)
        onlyRole(RolesLibrary.MANAGER)
    {
        _getStorage().metadataUrl = _metadataUrl;
        emit MetadataUrlSet(_metadataUrl);
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
    {
        _settleDeposit(_newTotalAssets);
    }

    /**
     * @notice Settles all pending redeems up to the current batch.
     * @param _newTotalAssets The new total assets after settlement.
     * @dev Only callable by the ORACLE role.
     */
    function settleRedeem(uint256 _newTotalAssets) external override(AlephVaultRedeem) onlyRole(RolesLibrary.ORACLE) {
        _settleRedeem(_newTotalAssets);
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
