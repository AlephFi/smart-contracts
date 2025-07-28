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
        __AccessControl_init();
        AlephVaultFactoryStorageData storage _sd = _getStorage();
        _sd.beacon = _initalizationParams.beacon;
        _sd.oracle = _initalizationParams.oracle;
        _sd.guardian = _initalizationParams.guardian;
        _sd.feeRecipient = _initalizationParams.feeRecipient;
        _sd.managementFee = _initalizationParams.managementFee;
        _sd.performanceFee = _initalizationParams.performanceFee;
        _grantRole(RolesLibrary.OPERATIONS_MULTISIG, msg.sender);
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
            manager: _userInitializationParams.manager,
            oracle: _sd.oracle,
            guardian: _sd.guardian,
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
        emit VaultDeployed(_vault, _initalizationParams.manager, _initalizationParams.name);
        return _vault;
    }

    function isValidVault(address _vault) external view returns (bool) {
        return _getStorage().vaults[_vault];
    }

    function setOracle(address _oracle) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        _getStorage().oracle = _oracle;
    }

    function setGuardian(address _guardian) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        _getStorage().guardian = _guardian;
    }

    function setFeeRecipient(address _feeRecipient) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        _getStorage().feeRecipient = _feeRecipient;
    }

    function setManagementFee(uint32 _managementFee) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        _getStorage().managementFee = _managementFee;
    }

    function setPerformanceFee(uint32 _performanceFee) external onlyRole(RolesLibrary.OPERATIONS_MULTISIG) {
        _getStorage().performanceFee = _performanceFee;
    }

    // Internal function to get the storage of the factory.
    function _getStorage() internal pure returns (AlephVaultFactoryStorageData storage sd) {
        return AlephVaultFactoryStorage.load();
    }
}
