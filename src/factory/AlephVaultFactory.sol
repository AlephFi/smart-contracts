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
import {Initializable} from "openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import {BeaconProxy} from "openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";
import {Create2} from "openzeppelin-contracts/contracts/utils/Create2.sol";
import {EnumerableSet} from "openzeppelin-contracts/contracts/utils/structs/EnumerableSet.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephVaultFactory} from "@aleph-vault/interfaces/IAlephVaultFactory.sol";
import {ModulesLibrary} from "@aleph-vault/libraries/ModulesLibrary.sol";
import {RolesLibrary} from "@aleph-vault/libraries/RolesLibrary.sol";
import {AlephVault} from "@aleph-vault/AlephVault.sol";
import {
    AlephVaultFactoryStorage, AlephVaultFactoryStorageData
} from "@aleph-vault/factory/AlephVaultFactoryStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract AlephVaultFactory is IAlephVaultFactory, AccessControlUpgradeable {
    using EnumerableSet for EnumerableSet.AddressSet;

    uint32 public constant MAX_MANAGEMENT_FEE = 1000; // 10%
    uint32 public constant MAX_PERFORMANCE_FEE = 5000; // 50%

    /**
     * @notice Initializes the factory.
     */
    function initialize(IAlephVaultFactory.InitializationParams calldata _initalizationParams) public initializer {
        _initialize(_initalizationParams);
    }

    /**
     * @notice Internal function to initialize the factory.
     */
    function _initialize(IAlephVaultFactory.InitializationParams calldata _initalizationParams)
        internal
        onlyInitializing
    {
        if (
            _initalizationParams.beacon == address(0) || _initalizationParams.operationsMultisig == address(0)
                || _initalizationParams.oracle == address(0) || _initalizationParams.guardian == address(0)
                || _initalizationParams.authSigner == address(0) || _initalizationParams.feeRecipient == address(0)
                || _initalizationParams.alephVaultDepositImplementation == address(0)
                || _initalizationParams.alephVaultRedeemImplementation == address(0)
                || _initalizationParams.alephVaultSettlementImplementation == address(0)
                || _initalizationParams.feeManagerImplementation == address(0)
                || _initalizationParams.managementFee > MAX_MANAGEMENT_FEE
                || _initalizationParams.performanceFee > MAX_PERFORMANCE_FEE
        ) {
            revert InvalidInitializationParams();
        }
        __AccessControl_init();
        AlephVaultFactoryStorageData storage _sd = _getStorage();
        _sd.beacon = _initalizationParams.beacon;
        _sd.operationsMultisig = _initalizationParams.operationsMultisig;
        _sd.oracle = _initalizationParams.oracle;
        _sd.guardian = _initalizationParams.guardian;
        _sd.authSigner = _initalizationParams.authSigner;
        _sd.feeRecipient = _initalizationParams.feeRecipient;
        _sd.managementFee = _initalizationParams.managementFee;
        _sd.performanceFee = _initalizationParams.performanceFee;
        _sd.moduleImplementations[ModulesLibrary.ALEPH_VAULT_DEPOSIT] =
            _initalizationParams.alephVaultDepositImplementation;
        _sd.moduleImplementations[ModulesLibrary.ALEPH_VAULT_REDEEM] =
            _initalizationParams.alephVaultRedeemImplementation;
        _sd.moduleImplementations[ModulesLibrary.ALEPH_VAULT_SETTLEMENT] =
            _initalizationParams.alephVaultSettlementImplementation;
        _sd.moduleImplementations[ModulesLibrary.FEE_MANAGER] = _initalizationParams.feeManagerImplementation;
        _grantRole(RolesLibrary.OPERATIONS_MULTISIG, _initalizationParams.operationsMultisig);
    }

    /**
     * @notice Deploys a new vault.
     * @param _userInitializationParams Struct containing all user initialization parameters.
     * @return The address of the new vault.
     */
    function deployVault(IAlephVault.UserInitializationParams calldata _userInitializationParams)
        external
        returns (address)
    {
        bytes32 _salt = keccak256(abi.encodePacked(_userInitializationParams.manager, _userInitializationParams.name));
        AlephVaultFactoryStorageData storage _sd = _getStorage();
        IAlephVault.ModuleInitializationParams memory _moduleInitializationParams = IAlephVault
            .ModuleInitializationParams({
            alephVaultDepositImplementation: _sd.moduleImplementations[ModulesLibrary.ALEPH_VAULT_DEPOSIT],
            alephVaultRedeemImplementation: _sd.moduleImplementations[ModulesLibrary.ALEPH_VAULT_REDEEM],
            alephVaultSettlementImplementation: _sd.moduleImplementations[ModulesLibrary.ALEPH_VAULT_SETTLEMENT],
            feeManagerImplementation: _sd.moduleImplementations[ModulesLibrary.FEE_MANAGER]
        });
        IAlephVault.InitializationParams memory _initalizationParams = IAlephVault.InitializationParams({
            operationsMultisig: _sd.operationsMultisig,
            vaultFactory: address(this),
            oracle: _sd.oracle,
            guardian: _sd.guardian,
            authSigner: _sd.authSigner,
            feeRecipient: _sd.feeRecipient,
            managementFee: _sd.managementFee,
            performanceFee: _sd.performanceFee,
            userInitializationParams: _userInitializationParams,
            moduleInitializationParams: _moduleInitializationParams
        });
        bytes memory _bytecode = abi.encodePacked(
            type(BeaconProxy).creationCode,
            abi.encode(_sd.beacon, abi.encodeCall(AlephVault.initialize, (_initalizationParams)))
        );

        address _vault = Create2.deploy(0, _salt, _bytecode);
        _sd.vaults.add(_vault);
        emit VaultDeployed(
            _vault,
            _userInitializationParams.manager,
            _userInitializationParams.name,
            _userInitializationParams.configId
        );
        return _vault;
    }

    function isValidVault(address _vault) external view returns (bool) {
        return _getStorage().vaults.contains(_vault);
    }

    function setOperationsMultisig(address _operationsMultisig) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        if (_operationsMultisig == address(0)) {
            revert InvalidParam();
        }
        AlephVaultFactoryStorageData storage _sd = _getStorage();
        _revokeRole(RolesLibrary.OPERATIONS_MULTISIG, _sd.operationsMultisig);
        _grantRole(RolesLibrary.OPERATIONS_MULTISIG, _operationsMultisig);
        _sd.operationsMultisig = _operationsMultisig;
        emit OperationsMultisigSet(_operationsMultisig);
    }

    function setOracle(address _oracle) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        if (_oracle == address(0)) {
            revert InvalidParam();
        }
        _getStorage().oracle = _oracle;
        emit OracleSet(_oracle);
    }

    function setGuardian(address _guardian) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        if (_guardian == address(0)) {
            revert InvalidParam();
        }
        _getStorage().guardian = _guardian;
        emit GuardianSet(_guardian);
    }

    function setAuthSigner(address _authSigner) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        if (_authSigner == address(0)) {
            revert InvalidParam();
        }
        _getStorage().authSigner = _authSigner;
        emit AuthSignerSet(_authSigner);
    }

    function setFeeRecipient(address _feeRecipient) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        if (_feeRecipient == address(0)) {
            revert InvalidParam();
        }
        _getStorage().feeRecipient = _feeRecipient;
        emit FeeRecipientSet(_feeRecipient);
    }

    function setManagementFee(uint32 _managementFee) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        if (_managementFee > MAX_MANAGEMENT_FEE) {
            revert InvalidParam();
        }
        _getStorage().managementFee = _managementFee;
        emit ManagementFeeSet(_managementFee);
    }

    function setPerformanceFee(uint32 _performanceFee) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        if (_performanceFee > MAX_PERFORMANCE_FEE) {
            revert InvalidParam();
        }
        _getStorage().performanceFee = _performanceFee;
        emit PerformanceFeeSet(_performanceFee);
    }

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
            IAlephVault(_vault).migrateModules(_module, _implementation);
        }
        emit ModuleImplementationSet(_module, _implementation);
    }

    // Internal function to get the storage of the factory.
    function _getStorage() internal pure returns (AlephVaultFactoryStorageData storage sd) {
        return AlephVaultFactoryStorage.load();
    }
}
