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
import {TransparentUpgradeableProxy, ITransparentUpgradeableProxy} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {IAlephVaultFactory} from "../src/interfaces/IAlephVaultFactory.sol";
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */

// Use to Deploy only an AlephVaultFactory.
// forge script DeployAlephVaultFactory --sig="run(address, address)" <_proxyOwner> <_beacon> --rpc-url $RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast -vvvv --verify --etherscan-api-key $ETHERSCAN_API_KEY
contract DeployAlephVaultFactory is Script {

    function setUp() public {}

    function run(address _proxyOwner, address _beacon) public {
        bytes memory _initializeArgs;
        if(block.chainid == 560048) {
            _initializeArgs = abi.encodeWithSelector(AlephVaultFactory.initialize.selector, IAlephVaultFactory.InitializationParams({
                beacon: _beacon
            }));
        } else {
            revert("Unsupported chain");
        }

        vm.startBroadcast();
        AlephVaultFactory _factoryImpl = new AlephVaultFactory();

        ITransparentUpgradeableProxy _proxy = ITransparentUpgradeableProxy(
            address(new TransparentUpgradeableProxy(address(_factoryImpl), _proxyOwner, _initializeArgs))
        );

        console.log("Factory deployed at:", address(_proxy));

        vm.stopBroadcast();
    }
}
