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
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephVaultFactory} from "@aleph-vault/interfaces/IAlephVaultFactory.sol";
import {RolesLibrary} from "@aleph-vault/libraries/RolesLibrary.sol";
import {AlephVault} from "@aleph-vault/AlephVault.sol";
import {AlephVaultFactoryStorage, AlephVaultFactoryStorageData} from "@aleph-vault/AlephVaultFactoryStorage.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract AlephVaultFactory is IAlephVaultFactory, AccessControlUpgradeable {
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
        IAlephVault.InitializationParams memory _initalizationParams = IAlephVault.InitializationParams({
            name: _userInitializationParams.name,
            operationsMultisig: _sd.operationsMultisig,
            manager: _userInitializationParams.manager,
            oracle: _sd.oracle,
            guardian: _sd.guardian,
            authSigner: _sd.authSigner,
            underlyingToken: _userInitializationParams.underlyingToken,
            custodian: _userInitializationParams.custodian,
            feeRecipient: _sd.feeRecipient,
            managementFee: _sd.managementFee,
            performanceFee: _sd.performanceFee
        });
        bytes memory _bytecode = abi.encodePacked(
            type(BeaconProxy).creationCode,
            abi.encode(_sd.beacon, abi.encodeCall(AlephVault.initialize, (_initalizationParams)))
        );

        address _vault = Create2.deploy(0, _salt, _bytecode);
        _sd.vaults[_vault] = true;
        emit VaultDeployed(
            _vault, _initalizationParams.manager, _initalizationParams.name, _userInitializationParams.configId
        );
        return _vault;
    }

    function isValidVault(address _vault) external view returns (bool) {
        return _getStorage().vaults[_vault];
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

    // Internal function to get the storage of the factory.
    function _getStorage() internal pure returns (AlephVaultFactoryStorageData storage sd) {
        return AlephVaultFactoryStorage.load();
    }
}
