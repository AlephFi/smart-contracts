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
import {AlephVaultFactory} from "@aleph-vault/AlephVaultFactory.sol";
import {IAlephVaultFactory} from "@aleph-vault/interfaces/IAlephVaultFactory.sol";
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */

// Use to Deploy only an AlephVaultFactory.
// forge script DeployAlephVaultFactory --sig="run()" --broadcast -vvvv --verify
contract DeployAlephVaultFactory is BaseScript {
    function setUp() public {}

    function run() public {
        string memory _chainId = _getChainId();
        vm.createSelectFork(_chainId);
        string memory _environment = _getEnvironment();

        address _beacon = _getBeacon(_chainId, _environment);
        address _proxyOwner = _getProxyOwner(_chainId, _environment);

        IAlephVaultFactory.InitializationParams memory _initializationParams;

        string memory _config = _getFactoryConfig();
        _initializationParams = IAlephVaultFactory.InitializationParams({
            beacon: _beacon,
            operationsMultisig: vm.parseJsonAddress(
                _config, string.concat(".", _chainId, ".", _environment, ".operationsMultisig")
            ),
            oracle: vm.parseJsonAddress(_config, string.concat(".", _chainId, ".", _environment, ".oracle")),
            guardian: vm.parseJsonAddress(_config, string.concat(".", _chainId, ".", _environment, ".guardian")),
            authSigner: vm.parseJsonAddress(_config, string.concat(".", _chainId, ".", _environment, ".authSigner")),
            feeRecipient: vm.parseJsonAddress(_config, string.concat(".", _chainId, ".", _environment, ".feeRecipient")),
            managementFee: uint32(
                vm.parseJsonUint(_config, string.concat(".", _chainId, ".", _environment, ".managementFee"))
            ),
            performanceFee: uint32(
                vm.parseJsonUint(_config, string.concat(".", _chainId, ".", _environment, ".performanceFee"))
            )
        });

        console.log("beacon", _beacon);
        console.log("operationsMultisig", _initializationParams.operationsMultisig);
        console.log("oracle", _initializationParams.oracle);
        console.log("guardian", _initializationParams.guardian);
        console.log("authSigner", _initializationParams.authSigner);
        console.log("feeRecipient", _initializationParams.feeRecipient);
        console.log("managementFee", _initializationParams.managementFee);
        console.log("performanceFee", _initializationParams.performanceFee);

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
}
