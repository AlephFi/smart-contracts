// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;
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
import {BeaconProxy} from "openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";
import {Create2} from "openzeppelin-contracts/contracts/utils/Create2.sol";
import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {IAccountant} from "@aleph-vault/interfaces/IAccountant.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephVaultFactory} from "@aleph-vault/interfaces/IAlephVaultFactory.sol";
import {IMigrationManager} from "@aleph-vault/interfaces/IMigrationManager.sol";
import {AuthLibrary} from "@aleph-vault/libraries/AuthLibrary.sol";
import {ModulesLibrary} from "@aleph-vault/libraries/ModulesLibrary.sol";
import {RolesLibrary} from "@aleph-vault/libraries/RolesLibrary.sol";
import {AlephVault} from "@aleph-vault/AlephVault.sol";
import {
    AlephVaultFactoryStorage, AlephVaultFactoryStorageData
} from "@aleph-vault/factory/AlephVaultFactoryStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract AlephVaultFactory is IAlephVaultFactory, AccessControlUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    /*//////////////////////////////////////////////////////////////
                            INITIALIZER
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Initializes the factory.
     */
    function initialize(IAlephVaultFactory.InitializationParams calldata _initializationParams) public initializer {
        _initialize(_initializationParams);
    }

    /**
     * @notice Internal function to initialize the factory.
     */
    function _initialize(IAlephVaultFactory.InitializationParams calldata _initializationParams)
        internal
        onlyInitializing
    {
        if (
            _initializationParams.beacon == address(0) || _initializationParams.operationsMultisig == address(0)
                || _initializationParams.oracle == address(0) || _initializationParams.guardian == address(0)
                || _initializationParams.authSigner == address(0) || _initializationParams.accountant == address(0)
                || _initializationParams.alephVaultDepositImplementation == address(0)
                || _initializationParams.alephVaultRedeemImplementation == address(0)
                || _initializationParams.alephVaultSettlementImplementation == address(0)
                || _initializationParams.feeManagerImplementation == address(0)
                || _initializationParams.migrationManagerImplementation == address(0)
        ) {
            revert InvalidInitializationParams();
        }
        __AccessControl_init();
        AlephVaultFactoryStorageData storage _sd = _getStorage();
        _sd.beacon = _initializationParams.beacon;
        _sd.operationsMultisig = _initializationParams.operationsMultisig;
        _sd.oracle = _initializationParams.oracle;
        _sd.guardian = _initializationParams.guardian;
        _sd.authSigner = _initializationParams.authSigner;
        _sd.accountant = _initializationParams.accountant;
        _sd.moduleImplementations[ModulesLibrary.ALEPH_VAULT_DEPOSIT] =
            _initializationParams.alephVaultDepositImplementation;
        _sd.moduleImplementations[ModulesLibrary.ALEPH_VAULT_REDEEM] =
            _initializationParams.alephVaultRedeemImplementation;
        _sd.moduleImplementations[ModulesLibrary.ALEPH_VAULT_SETTLEMENT] =
            _initializationParams.alephVaultSettlementImplementation;
        _sd.moduleImplementations[ModulesLibrary.FEE_MANAGER] = _initializationParams.feeManagerImplementation;
        _sd.moduleImplementations[ModulesLibrary.MIGRATION_MANAGER] =
            _initializationParams.migrationManagerImplementation;
        _grantRole(RolesLibrary.OPERATIONS_MULTISIG, _initializationParams.operationsMultisig);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IAlephVaultFactory
    function isValidVault(address _vault) external view returns (bool) {
        return _getStorage().vaults.contains(_vault);
    }

    /*//////////////////////////////////////////////////////////////
                            SETTER FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /// @inheritdoc IAlephVaultFactory
    function setOperationsMultisig(address _operationsMultisig) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        if (_operationsMultisig == address(0)) {
            revert InvalidParam();
        }
        AlephVaultFactoryStorageData storage _sd = _getStorage();
        _revokeRole(RolesLibrary.OPERATIONS_MULTISIG, _sd.operationsMultisig);
        _grantRole(RolesLibrary.OPERATIONS_MULTISIG, _operationsMultisig);
        _sd.operationsMultisig = _operationsMultisig;
        uint256 _len = _sd.vaults.length();
        for (uint256 i = 0; i < _len; i++) {
            address _vault = _sd.vaults.at(i);
            IMigrationManager(_vault).migrateOperationsMultisig(_operationsMultisig);
        }
        emit OperationsMultisigSet(_operationsMultisig);
    }

    /// @inheritdoc IAlephVaultFactory
    function setOracle(address _oracle) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        if (_oracle == address(0)) {
            revert InvalidParam();
        }
        AlephVaultFactoryStorageData storage _sd = _getStorage();
        _sd.oracle = _oracle;
        uint256 _len = _sd.vaults.length();
        for (uint256 i = 0; i < _len; i++) {
            address _vault = _sd.vaults.at(i);
            IMigrationManager(_vault).migrateOracle(_oracle);
        }
        emit OracleSet(_oracle);
    }

    /// @inheritdoc IAlephVaultFactory
    function setGuardian(address _guardian) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        if (_guardian == address(0)) {
            revert InvalidParam();
        }
        AlephVaultFactoryStorageData storage _sd = _getStorage();
        _sd.guardian = _guardian;
        uint256 _len = _sd.vaults.length();
        for (uint256 i = 0; i < _len; i++) {
            address _vault = _sd.vaults.at(i);
            IMigrationManager(_vault).migrateGuardian(_guardian);
        }
        emit GuardianSet(_guardian);
    }

    /// @inheritdoc IAlephVaultFactory
    function setAuthSigner(address _authSigner) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        if (_authSigner == address(0)) {
            revert InvalidParam();
        }
        AlephVaultFactoryStorageData storage _sd = _getStorage();
        _sd.authSigner = _authSigner;
        uint256 _len = _sd.vaults.length();
        for (uint256 i = 0; i < _len; i++) {
            address _vault = _sd.vaults.at(i);
            IMigrationManager(_vault).migrateAuthSigner(_authSigner);
        }
        emit AuthSignerSet(_authSigner);
    }

    /// @inheritdoc IAlephVaultFactory
    function setModuleImplementation(bytes4 _module, address _implementation)
        external
        onlyRole(RolesLibrary.OPERATIONS_MULTISIG)
    {
        if (_implementation == address(0)) {
            revert InvalidParam();
        }
        AlephVaultFactoryStorageData storage _sd = _getStorage();
        _sd.moduleImplementations[_module] = _implementation;
        uint256 _len = _sd.vaults.length();
        for (uint256 i = 0; i < _len; i++) {
            address _vault = _sd.vaults.at(i);
            IMigrationManager(_vault).migrateModules(_module, _implementation);
        }
        emit ModuleImplementationSet(_module, _implementation);
    }

    /*//////////////////////////////////////////////////////////////
                            DEPLOY FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Deploys a new vault.
     * @param _userInitializationParams Struct containing all user initialization parameters.
     * @return The address of the new vault.
     */
    function deployVault(IAlephVault.UserInitializationParams calldata _userInitializationParams)
        external
        returns (address)
    {
        bytes32 _salt = keccak256(abi.encodePacked(msg.sender, _userInitializationParams.name));
        AlephVaultFactoryStorageData storage _sd = _getStorage();
            AuthLibrary.verifyVaultDeploymentAuthSignature(
            address(this),
            _userInitializationParams.name,
            _userInitializationParams.configId,
            _sd.authSigner,
            _userInitializationParams.authSignature
        );
        IAlephVault.ModuleInitializationParams memory _moduleInitializationParams = IAlephVault
            .ModuleInitializationParams({
            alephVaultDepositImplementation: _sd.moduleImplementations[ModulesLibrary.ALEPH_VAULT_DEPOSIT],
            alephVaultRedeemImplementation: _sd.moduleImplementations[ModulesLibrary.ALEPH_VAULT_REDEEM],
            alephVaultSettlementImplementation: _sd.moduleImplementations[ModulesLibrary.ALEPH_VAULT_SETTLEMENT],
            feeManagerImplementation: _sd.moduleImplementations[ModulesLibrary.FEE_MANAGER],
            migrationManagerImplementation: _sd.moduleImplementations[ModulesLibrary.MIGRATION_MANAGER]
        });
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            operationsMultisig: _sd.operationsMultisig,
            vaultFactory: address(this),
            manager: msg.sender,
            oracle: _sd.oracle,
            guardian: _sd.guardian,
            authSigner: _sd.authSigner,
            accountant: _sd.accountant,
            userInitializationParams: _userInitializationParams,
            moduleInitializationParams: _moduleInitializationParams
        });
        bytes memory _bytecode = abi.encodePacked(
            type(BeaconProxy).creationCode,
            abi.encode(_sd.beacon, abi.encodeCall(AlephVault.initialize, (_initializationParams)))
        );

        address _vault = Create2.deploy(0, _salt, _bytecode);
        _sd.vaults.add(_vault);
        IAccountant(_sd.accountant).initializeVaultTreasury(_vault, _userInitializationParams.vaultTreasury);
        emit VaultDeployed(_vault, msg.sender, _userInitializationParams.name, _userInitializationParams.configId);
        return _vault;
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/
    // Internal function to get the storage of the factory.
    function _getStorage() internal pure returns (AlephVaultFactoryStorageData storage sd) {
        return AlephVaultFactoryStorage.load();
    }
}
