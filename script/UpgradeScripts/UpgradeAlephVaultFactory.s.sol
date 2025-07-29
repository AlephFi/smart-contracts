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
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */

// Use only to upgrade AlephVaultFactory.
// forge script UpgradeAlephVaultFactory --sig="run()" --broadcast -vvvv --verify
contract UpgradeAlephVaultFactory is BaseScript {
    function setUp() public {}

    function run() public {
        string memory _chainId = _getChainId();
        vm.createSelectFork(_chainId);
        uint256 _privateKey = _getPrivateKey();
        vm.startBroadcast(_privateKey);
        string memory _environment = _getEnvironment();

        address _proxy = _getProxy(_chainId, _environment);
        AlephVaultFactory _factoryImpl = new AlephVaultFactory();

        ITransparentUpgradeableProxy(_proxy).upgradeToAndCall(address(_factoryImpl), "");
        console.log("AlephVaultFactory upgraded to", address(_factoryImpl));

        _writeDeploymentConfig(
            _chainId, _environment, ".factoryImplementationAddress", vm.toString(address(_factoryImpl))
        );
        vm.stopBroadcast();
    }
}
