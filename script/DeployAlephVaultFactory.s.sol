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
// forge script DeployAlephVaultFactory --sig="run(address, address)" <_proxyOwner> <_beacon> --broadcast -vvvv --verify --etherscan-api-key $ETHERSCAN_API_KEY
contract DeployAlephVaultFactory is BaseScript {
    function setUp() public {}

    function run(address _proxyOwner, address _beacon) public {
        string memory _chainId = _getChainId();
        vm.createSelectFork(_chainId);
        bytes memory _initializeArgs;
        if (block.chainid == 560_048) {
            _initializeArgs = abi.encodeWithSelector(
                AlephVaultFactory.initialize.selector, IAlephVaultFactory.InitializationParams({beacon: _beacon})
            );
        } else {
            revert("Unsupported chain");
        }

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
