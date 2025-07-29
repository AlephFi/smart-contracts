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
import {BaseScript} from "./BaseScript.s.sol";
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */

// Use to Deploy only an AlephVault implementation.
// forge script DeployAlephVaultImplementation --broadcast -vvvv --verify
contract DeployAlephVaultImplementation is BaseScript {
    function setUp() public {}

    function run() public {
        string memory _chainId = _getChainId();
        vm.createSelectFork(_chainId);
        uint256 _privateKey = _getPrivateKey();
        vm.startBroadcast(_privateKey);
        IAlephVault.ConstructorParams memory _constructorParams;
        string memory _environment = _getEnvironment();

        string memory _config = _getConfigFile();
        uint48 _minDepositAmountTimelock = uint48(
            vm.parseJsonUint(_config, string.concat(".", _chainId, ".", _environment, ".minDepositAmountTimelock"))
        );
        uint48 _maxDepositCapTimelock =
            uint48(vm.parseJsonUint(_config, string.concat(".", _chainId, ".", _environment, ".maxDepositCapTimelock")));
        uint48 _managementFeeTimelock =
            uint48(vm.parseJsonUint(_config, string.concat(".", _chainId, ".", _environment, ".managementFeeTimelock")));
        uint48 _performanceFeeTimelock = uint48(
            vm.parseJsonUint(_config, string.concat(".", _chainId, ".", _environment, ".performanceFeeTimelock"))
        );
        uint48 _feeRecipientTimelock =
            uint48(vm.parseJsonUint(_config, string.concat(".", _chainId, ".", _environment, ".feeRecipientTimelock")));
        uint48 _batchDuration =
            uint48(vm.parseJsonUint(_config, string.concat(".", _chainId, ".", _environment, ".batchDuration")));

        console.log("chainId", _chainId);
        console.log("environment", _environment);
        console.log("minDepositAmountTimelock", _minDepositAmountTimelock);
        console.log("maxDepositCapTimelock", _maxDepositCapTimelock);
        console.log("managementFeeTimelock", _managementFeeTimelock);
        console.log("performanceFeeTimelock", _performanceFeeTimelock);
        console.log("feeRecipientTimelock", _feeRecipientTimelock);
        console.log("batchDuration", _batchDuration);

        _constructorParams = IAlephVault.ConstructorParams({
            minDepositAmountTimelock: _minDepositAmountTimelock,
            maxDepositCapTimelock: _maxDepositCapTimelock,
            managementFeeTimelock: _managementFeeTimelock,
            performanceFeeTimelock: _performanceFeeTimelock,
            feeRecipientTimelock: _feeRecipientTimelock,
            batchDuration: _batchDuration
        });

        AlephVault _vault = new AlephVault(_constructorParams);
        console.log("Vault implementation deployed at:", address(_vault));

        vm.stopBroadcast();
    }
}
