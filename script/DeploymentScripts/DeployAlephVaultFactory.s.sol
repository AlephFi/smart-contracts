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
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {BaseScript} from "@aleph-script/BaseScript.s.sol";
import {IAlephVaultFactory} from "@aleph-vault/interfaces/IAlephVaultFactory.sol";
import {AlephVaultFactory} from "@aleph-vault/factory/AlephVaultFactory.sol";
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */

// Use to Deploy only an AlephVaultFactory.
// forge script DeployAlephVaultFactory --sig="run()" --broadcast -vvvv --verify
contract DeployAlephVaultFactory is BaseScript {
    function setUp() public {}

    function run() public {
        string memory _chainId = _getChainId();
        vm.createSelectFork(_chainId);
        string memory _environment = _getEnvironment();

        address _proxyOwner = _getProxyOwner(_chainId, _environment);

        IAlephVaultFactory.InitializationParams memory _initializationParams;

        string memory _factoryConfig = _getFactoryConfig();
        string memory _deploymentConfig = _getDeploymentConfig();
        _initializationParams = _getInitializationParams(_factoryConfig, _deploymentConfig, _chainId, _environment);

        console.log("operationsMultisig", _initializationParams.operationsMultisig);
        console.log("oracle", _initializationParams.oracle);
        console.log("guardian", _initializationParams.guardian);
        console.log("authSigner", _initializationParams.authSigner);
        console.log("feeRecipient", _initializationParams.feeRecipient);

        bytes memory _initializeArgs =
            abi.encodeWithSelector(AlephVaultFactory.initialize.selector, _initializationParams);

        uint256 _privateKey = _getPrivateKey();
        vm.startBroadcast(_privateKey);
        AlephVaultFactory _factoryImpl = new AlephVaultFactory();

        ITransparentUpgradeableProxy _proxy = ITransparentUpgradeableProxy(
            address(new TransparentUpgradeableProxy(address(_factoryImpl), _proxyOwner, _initializeArgs))
        );

        console.log("Factory deployed at:", address(_proxy));

        _writeDeploymentConfig(
            _chainId, _environment, ".factoryImplementationAddress", vm.toString(address(_factoryImpl))
        );
        _writeDeploymentConfig(_chainId, _environment, ".factoryProxyAddress", vm.toString(address(_proxy)));

        vm.stopBroadcast();
    }

    function _getInitializationParams(
        string memory _factoryConfig,
        string memory _deploymentConfig,
        string memory _chainId,
        string memory _environment
    ) internal view returns (IAlephVaultFactory.InitializationParams memory) {
        return IAlephVaultFactory.InitializationParams({
            beacon: _getBeacon(_chainId, _environment),
            operationsMultisig: vm.parseJsonAddress(
                _factoryConfig, string.concat(".", _chainId, ".", _environment, ".operationsMultisig")
            ),
            oracle: vm.parseJsonAddress(_factoryConfig, string.concat(".", _chainId, ".", _environment, ".oracle")),
            guardian: vm.parseJsonAddress(_factoryConfig, string.concat(".", _chainId, ".", _environment, ".guardian")),
            authSigner: vm.parseJsonAddress(_factoryConfig, string.concat(".", _chainId, ".", _environment, ".authSigner")),
            feeRecipient: vm.parseJsonAddress(
                _factoryConfig, string.concat(".", _chainId, ".", _environment, ".feeRecipient")
            ),
            alephVaultDepositImplementation: vm.parseJsonAddress(
                _deploymentConfig, string.concat(".", _chainId, ".", _environment, ".vaultDepositImplementationAddress")
            ),
            alephVaultRedeemImplementation: vm.parseJsonAddress(
                _deploymentConfig, string.concat(".", _chainId, ".", _environment, ".vaultRedeemImplementationAddress")
            ),
            alephVaultSettlementImplementation: vm.parseJsonAddress(
                _deploymentConfig, string.concat(".", _chainId, ".", _environment, ".vaultSettlementImplementationAddress")
            ),
            feeManagerImplementation: vm.parseJsonAddress(
                _deploymentConfig, string.concat(".", _chainId, ".", _environment, ".feeManagerImplementationAddress")
            ),
            migrationManagerImplementation: vm.parseJsonAddress(
                _deploymentConfig, string.concat(".", _chainId, ".", _environment, ".migrationManagerImplementationAddress")
            )
        });
    }
}
