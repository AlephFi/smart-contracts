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
import {IAccountant} from "@aleph-vault/interfaces/IAccountant.sol";

// Use to set the vault factory in the accountant.
// forge script SetVaultFactory --sig="run()" --broadcast -vvvv --verify
contract SetVaultFactory is BaseScript {
    function setUp() public {}

    function run() public {
        string memory _chainId = _getChainId();
        vm.createSelectFork(_chainId);
        uint256 _privateKey = _getPrivateKey();
        vm.startBroadcast(_privateKey);
        string memory _environment = _getEnvironment();

        address _accountant = _getAccountantProxy(_chainId, _environment);
        address _vaultFactory = _getFactoryProxy(_chainId, _environment);

        IAccountant(_accountant).setVaultFactory(_vaultFactory);
        console.log("VaultFactory set to", _vaultFactory);

        vm.stopBroadcast();
    }
}
