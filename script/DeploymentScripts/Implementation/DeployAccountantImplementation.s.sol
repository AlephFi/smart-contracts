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
import {Accountant} from "@aleph-vault/Accountant.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */

// Use to Deploy only an Accountant Implementation.
// forge script DeployAccountantImplementation --sig="run()" --broadcast -vvvv
contract DeployAccountantImplementation is BaseScript {
    function setUp() public {}

    function run() public {
        string memory _chainId = _getChainId();
        vm.createSelectFork(_chainId);
        string memory _environment = _getEnvironment();

        uint256 _privateKey = _getPrivateKey();
        vm.startBroadcast(_privateKey);
        Accountant _accountantImpl = new Accountant();

        console.log("Accountant Implementation deployed at:", address(_accountantImpl));

        _writeDeploymentConfig(
            _chainId, _environment, ".accountantImplementationAddress", vm.toString(address(_accountantImpl))
        );

        vm.stopBroadcast();
    }
}
