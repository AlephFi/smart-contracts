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
import {BaseScript} from "@aleph-script/BaseScript.s.sol";
import {AlephVaultFactory} from "@aleph-vault/factory/AlephVaultFactory.sol";
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */

// Use to Deploy only an AlephVaultFactory Implementation.
// forge script DeployAlephVaultFactoryImplementation --sig="run()" --broadcast -vvvv --verify
contract DeployAlephVaultFactoryImplementation is BaseScript {
    function setUp() public {}

    function run() public {
        string memory _chainId = _getChainId();
        vm.createSelectFork(_chainId);
        string memory _environment = _getEnvironment();

        uint256 _privateKey = _getPrivateKey();
        vm.startBroadcast(_privateKey);
        AlephVaultFactory _factoryImpl = new AlephVaultFactory();

        console.log("Factory Implementation deployed at:", address(_factoryImpl));

        _writeDeploymentConfig(
            _chainId, _environment, ".factoryImplementationAddress", vm.toString(address(_factoryImpl))
        );

        vm.stopBroadcast();
    }
}
