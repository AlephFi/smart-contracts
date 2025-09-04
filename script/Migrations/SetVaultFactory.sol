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
import {IFeeRecipient} from "@aleph-vault/interfaces/IFeeRecipient.sol";

// Use to set the vault factory in the fee recipient.
// forge script SetVaultFactory --sig="run()" --broadcast -vvvv --verify
contract SetVaultFactory is BaseScript {
    function setUp() public {}

    function run() public {
        string memory _chainId = _getChainId();
        vm.createSelectFork(_chainId);
        uint256 _privateKey = _getPrivateKey();
        vm.startBroadcast(_privateKey);
        string memory _environment = _getEnvironment();

        address _feeRecipient = _getFeeRecipientProxy(_chainId, _environment);
        address _vaultFactory = _getFactoryProxy(_chainId, _environment);

        IFeeRecipient(_feeRecipient).setVaultFactory(_vaultFactory);
        console.log("VaultFactory set to", _vaultFactory);

        vm.stopBroadcast();
    }
}
