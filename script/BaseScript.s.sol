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

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
abstract contract BaseScript is Script {
    function _getPrivateKey() internal returns (uint256) {
        string memory _privateKeyFromPrompt = vm.promptSecret("Enter deployer private key");
        uint256 _privateKey = vm.parseUint(_privateKeyFromPrompt);
        return _privateKey;
    }

    function _getChainId() internal returns (string memory) {
        string memory _chainIdFromPrompt = vm.prompt("Enter chain id");
        return _chainIdFromPrompt;
    }

    function _getConfigFile() internal returns (string memory) {
        string memory _config = vm.readFile("config.json");
        return _config;
    }
}
