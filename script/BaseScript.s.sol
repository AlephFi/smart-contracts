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

import {Script, console} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
abstract contract BaseScript is Script {
    function _getPrivateKey() internal view returns (uint256) {
        string memory privateKey = vm.envString("PRIVATE_KEY");
        return vm.parseUint(privateKey);
    }

    function _getChainId() internal view returns (string memory) {
        return vm.envString("CHAIN_ID");
    }

    function _getEnvironment() internal view returns (string memory) {
        return vm.envString("ENVIRONMENT");
    }

    function _getConfigFile() internal view returns (string memory) {
        string memory _config = vm.readFile("config.json");
        return _config;
    }

    function _getFactoryConfig() internal view returns (string memory) {
        string memory _config = vm.readFile("factoryConfig.json");
        return _config;
    }

    function _getVaultImplementation(string memory _chainId, string memory _environment)
        internal
        view
        returns (address)
    {
        string memory _deploymentConfig = vm.readFile(_getDeploymentConfigFilePath());
        string memory _implementationKey =
            string.concat(".", _chainId, ".", _environment, ".vaultImplementationAddress");
        address _vaultImplementation = vm.parseJsonAddress(_deploymentConfig, _implementationKey);
        return _vaultImplementation;
    }

    function _getBeaconOwner(string memory _chainId, string memory _environment) internal view returns (address) {
        string memory _deploymentConfig = vm.readFile(_getDeploymentConfigFilePath());
        string memory _beaconOwnerKey = string.concat(".", _chainId, ".", _environment, ".vaultBeaconOwner");
        address _beaconOwner = vm.parseJsonAddress(_deploymentConfig, _beaconOwnerKey);
        return _beaconOwner;
    }

    function _getBeacon(string memory _chainId, string memory _environment) internal view returns (address) {
        string memory _deploymentConfig = vm.readFile(_getDeploymentConfigFilePath());
        string memory _beaconKey = string.concat(".", _chainId, ".", _environment, ".vaultBeaconAddress");
        address _beacon = vm.parseJsonAddress(_deploymentConfig, _beaconKey);
        return _beacon;
    }

    function _getProxyOwner(string memory _chainId, string memory _environment) internal view returns (address) {
        string memory _deploymentConfig = vm.readFile(_getDeploymentConfigFilePath());
        string memory _proxyOwnerKey = string.concat(".", _chainId, ".", _environment, ".factoryProxyOwner");
        address _proxyOwner = vm.parseJsonAddress(_deploymentConfig, _proxyOwnerKey);
        return _proxyOwner;
    }

    function _getProxy(string memory _chainId, string memory _environment) internal view returns (address) {
        string memory _deploymentConfig = vm.readFile(_getDeploymentConfigFilePath());
        string memory _proxyKey = string.concat(".", _chainId, ".", _environment, ".factoryProxyAddress");
        address _proxy = vm.parseJsonAddress(_deploymentConfig, _proxyKey);
        return _proxy;
    }

    function _getFactoryImplementation(string memory _chainId, string memory _environment)
        internal
        view
        returns (address)
    {
        string memory _deploymentConfig = vm.readFile(_getDeploymentConfigFilePath());
        string memory _implementationKey =
            string.concat(".", _chainId, ".", _environment, ".factoryImplementationAddress");
        address _implementation = vm.parseJsonAddress(_deploymentConfig, _implementationKey);
        return _implementation;
    }

    function _getDeploymentConfigFilePath() internal pure returns (string memory) {
        return "deploymentConfig.json";
    }

    function _writeDeploymentConfig(
        string memory _chainId,
        string memory _environment,
        string memory _valueKey,
        string memory _value
    ) internal {
        string memory _deploymentConfig = _getDeploymentConfigFilePath();
        string memory _key = string.concat(".", _chainId, ".", _environment, _valueKey);
        vm.writeJson(_value, _deploymentConfig, _key);
    }
}
