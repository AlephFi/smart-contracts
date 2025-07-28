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
import {AlephVaultFactory} from "../src/AlephVaultFactory.sol";
import {console} from "forge-std/console.sol";
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IAlephVaultFactory} from "../src/interfaces/IAlephVaultFactory.sol";
import {BaseScript} from "./BaseScript.s.sol";
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */

// Use to Deploy only an AlephVaultFactory.
// forge script DeployAlephVaultFactory --sig="run(address, address)" <_proxyOwner> <_beacon> --broadcast -vvvv --verify
contract DeployAlephVaultFactory is BaseScript {
    function setUp() public {}

    function run(address _proxyOwner, address _beacon) public {
        string memory _chainId = _getChainId();
        vm.createSelectFork(_chainId);
        IAlephVaultFactory.InitializationParams memory _initializationParams;

        string memory _config = _getFactoryConfig();
        address _oracle = vm.parseJsonAddress(_config, string.concat(".", _chainId, ".oracle"));
        address _guardian = vm.parseJsonAddress(_config, string.concat(".", _chainId, ".guardian"));
        address _feeRecipient = vm.parseJsonAddress(_config, string.concat(".", _chainId, ".feeRecipient"));
        uint32 _managementFee = uint32(vm.parseJsonUint(_config, string.concat(".", _chainId, ".managementFee")));
        uint32 _performanceFee = uint32(vm.parseJsonUint(_config, string.concat(".", _chainId, ".performanceFee")));

        console.log("proxyOwner", _proxyOwner);
        console.log("beacon", _beacon);
        console.log("oracle", _oracle);
        console.log("guardian", _guardian);
        console.log("feeRecipient", _feeRecipient);
        console.log("managementFee", _managementFee);
        console.log("performanceFee", _performanceFee);

        _initializationParams = IAlephVaultFactory.InitializationParams({
            beacon: _beacon,
            oracle: _oracle,
            guardian: _guardian,
            feeRecipient: _feeRecipient,
            managementFee: _managementFee,
            performanceFee: _performanceFee
        });

        bytes memory _initializeArgs =
            abi.encodeWithSelector(AlephVaultFactory.initialize.selector, _initializationParams);

        uint256 _privateKey = _getPrivateKey();
        vm.startBroadcast(_privateKey);
        AlephVaultFactory _factoryImpl = new AlephVaultFactory();

        ITransparentUpgradeableProxy _proxy = ITransparentUpgradeableProxy(
            address(new TransparentUpgradeableProxy(address(_factoryImpl), _proxyOwner, _initializeArgs))
        );

        console.log("Factory deployed at:", address(_proxy));

        vm.stopBroadcast();
    }
}
