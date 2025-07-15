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
// forge script DeployAlephVaultImplementation --broadcast -vvvv --verify --etherscan-api-key $ETHERSCAN_API_KEY
contract DeployAlephVaultImplementation is BaseScript {
    function setUp() public {}

    function run() public {
        string memory _chainId = _getChainId();
        vm.createSelectFork(_chainId);
        uint256 _privateKey = _getPrivateKey();
        vm.startBroadcast(_privateKey);
        IAlephVault.ConstructorParams memory _constructorParams;
        string memory _config = _getConfigFile();
        address _operationsMultisig = vm.parseJsonAddress(_config, string.concat(".", _chainId, ".operationsMultisig"));
        address _oracle = vm.parseJsonAddress(_config, string.concat(".", _chainId, ".oracle"));
        address _guardian = vm.parseJsonAddress(_config, string.concat(".", _chainId, ".guardian"));
        uint32 _maxManagementFee = uint32(vm.parseJsonUint(_config, string.concat(".", _chainId, ".maxManagementFee")));
        uint32 _maxPerformanceFee =
            uint32(vm.parseJsonUint(_config, string.concat(".", _chainId, ".maxPerformanceFee")));
        uint48 _managementFeeTimelock =
            uint48(vm.parseJsonUint(_config, string.concat(".", _chainId, ".managementFeeTimelock")));
        uint48 _performanceFeeTimelock =
            uint48(vm.parseJsonUint(_config, string.concat(".", _chainId, ".performanceFeeTimelock")));
        uint48 _feeRecipientTimelock =
            uint48(vm.parseJsonUint(_config, string.concat(".", _chainId, ".feeRecipientTimelock")));
        console.log("operationsMultisig", _operationsMultisig);
        console.log("oracle", _oracle);
        console.log("guardian", _guardian);
        console.log("maxManagementFee", _maxManagementFee);
        console.log("maxPerformanceFee", _maxPerformanceFee);
        console.log("managementFeeTimelock", _managementFeeTimelock);
        console.log("performanceFeeTimelock", _performanceFeeTimelock);
        console.log("feeRecipientTimelock", _feeRecipientTimelock);
        _constructorParams = IAlephVault.ConstructorParams({
            operationsMultisig: _operationsMultisig,
            oracle: _oracle,
            guardian: _guardian,
            maxManagementFee: _maxManagementFee,
            maxPerformanceFee: _maxPerformanceFee,
            managementFeeTimelock: _managementFeeTimelock,
            performanceFeeTimelock: _performanceFeeTimelock,
            feeRecipientTimelock: _feeRecipientTimelock
        });

        AlephVault _vault = new AlephVault(_constructorParams);
        console.log("Vault implementation deployed at:", address(_vault));

        vm.stopBroadcast();
    }
}
