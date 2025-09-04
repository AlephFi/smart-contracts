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
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephVaultFactory} from "@aleph-vault/interfaces/IAlephVaultFactory.sol";
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */

// Use to deploy a new AlephVault.
// forge script DeployAlephVault --sig="run()" --broadcast -vvvv --verify
contract DeployAlephVault is BaseScript {
    function setUp() public {}

    function run() public {
        string memory _chainId = _getChainId();
        vm.createSelectFork(_chainId);
        uint256 _privateKey = _getPrivateKey();
        vm.startBroadcast(_privateKey);

        string memory _environment = _getEnvironment();
        address _factory = _getFactoryProxy(_chainId, _environment);

        IAlephVault.UserInitializationParams memory _userInitializationParams = IAlephVault.UserInitializationParams({
            name: vm.envString("VAULT_NAME"),
            configId: vm.envString("VAULT_CONFIG_ID"),
            manager: vm.envAddress("VAULT_MANAGER"),
            underlyingToken: vm.envAddress("VAULT_UNDERLYING_TOKEN"),
            custodian: vm.envAddress("VAULT_CUSTODIAN"),
            managementFee: uint32(vm.envUint("VAULT_MANAGEMENT_FEE")),
            performanceFee: uint32(vm.envUint("VAULT_PERFORMANCE_FEE")),
            minDepositAmount: vm.envUint("VAULT_MIN_DEPOSIT_AMOUNT"),
            maxDepositCap: vm.envUint("VAULT_MAX_DEPOSIT_CAP")
        });
        address _vault = IAlephVaultFactory(_factory).deployVault(_userInitializationParams);
        console.log("================================================");
        console.log("Vault deployed at", _vault);
        console.log("================================================");

        vm.stopBroadcast();
    }
}
