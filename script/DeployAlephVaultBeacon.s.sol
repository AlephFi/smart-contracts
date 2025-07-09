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
import {UpgradeableBeacon} from "lib/openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */

// Use to Deploy only an AlephVault beacon.
// forge script DeployAlephVaultBeacon --sig="run(address, address)" <_vaultImplementation> <_beaconOwner>  --rpc-url $RPC_URL --private-key $DEPLOYER_PRIVATE_KEY --broadcast -vvvv --verify --etherscan-api-key $ETHERSCAN_API_KEY
contract DeployAlephVaultBeacon is Script {
    UpgradeableBeacon public beacon;

    function setUp() public {}

    function run(address _vaultImplementation, address _beaconOwner) public {
        vm.startBroadcast();

        beacon = new UpgradeableBeacon(_vaultImplementation, _beaconOwner);
        console.log("UpgradeableBeacon deployed at:", address(beacon));

        vm.stopBroadcast();
    }
}
