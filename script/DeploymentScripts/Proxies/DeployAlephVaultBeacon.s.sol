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
import {BaseScript} from "@aleph-script/BaseScript.s.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */

// Use to Deploy only an AlephVault beacon.
// forge script DeployAlephVaultBeacon --sig="run()" --broadcast -vvvv --verify
contract DeployAlephVaultBeacon is BaseScript {
    function setUp() public {}

    function run() public {
        string memory _chainId = _getChainId();
        vm.createSelectFork(_chainId);
        uint256 _privateKey = _getPrivateKey();
        vm.startBroadcast(_privateKey);
        string memory _environment = _getEnvironment();

        address _vaultImplementation = _getVaultImplementation(_chainId, _environment);
        address _beaconOwner = _getBeaconOwner(_chainId, _environment);

        UpgradeableBeacon _beacon = new UpgradeableBeacon(_vaultImplementation, _beaconOwner);
        console.log("UpgradeableBeacon deployed at:", address(_beacon));

        _writeDeploymentConfig(_chainId, _environment, ".vaultBeaconAddress", vm.toString(address(_beacon)));

        vm.stopBroadcast();
    }
}
