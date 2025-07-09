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
import {AlephVault} from "../src/AlephVault.sol";
import {console} from "forge-std/console.sol";
import {IAlephVault} from "../src/interfaces/IAlephVault.sol";
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */

// Use to Deploy only an AlephVault implementation.
// forge script DeployAlephVaultImplementation --rpc-url $RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast -vvvv --verify --etherscan-api-key $ETHERSCAN_API_KEY
contract DeployAlephVaultImplementation is Script {
    AlephVault public vault;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();
        IAlephVault.ConstructorParams memory _constructorParams;
        
        if(block.chainid == 560048) {
            _constructorParams = IAlephVault.ConstructorParams({
                operationsMultisig: 0x7f7eb0b9aC4f796fb96912A7184603EB2633f584,
                oracle: 0x7f7eb0b9aC4f796fb96912A7184603EB2633f584,
                guardian: 0x7f7eb0b9aC4f796fb96912A7184603EB2633f584
            });
        } else {
            revert("Unsupported chain");
        }

        vault = new AlephVault(_constructorParams);
        console.log("Vault implementation deployed at:", address(vault));

        vm.stopBroadcast();
    }
}
