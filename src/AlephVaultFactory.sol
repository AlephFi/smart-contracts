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
import {AlephVaultFactoryStorage, AlephVaultFactoryStorageData} from "./AlephVaultFactoryStorage.sol";
import {IAlephVault} from "./interfaces/IAlephVault.sol";
import {IAlephVaultFactory} from "./interfaces/IAlephVaultFactory.sol";
import {Create2} from "openzeppelin-contracts/contracts/utils/Create2.sol";
import {AlephVault} from "./AlephVault.sol";
import {RolesLibrary} from "./libraries/RolesLibrary.sol";

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
        _getStorage().beacon = _initalizationParams.beacon;
    }

    /**
     * @notice Deploys a new vault.
     * @param _initalizationParams Struct containing all initialization parameters.
     * @return The address of the new vault.
     */
    function deployVault(IAlephVault.InitializationParams calldata _initalizationParams) external returns (address) {
        bytes32 _salt = keccak256(abi.encodePacked(_initalizationParams.manager, _initalizationParams.name));
        AlephVaultFactoryStorageData storage _sd = _getStorage();
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

    // Internal function to get the storage of the factory.
    function _getStorage() internal pure returns (AlephVaultFactoryStorageData storage sd) {
        return AlephVaultFactoryStorage.load();
    }
}
