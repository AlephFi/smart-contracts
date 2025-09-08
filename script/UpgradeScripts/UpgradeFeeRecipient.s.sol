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
import {
    TransparentUpgradeableProxy,
    ITransparentUpgradeableProxy
} from "openzeppelin-contracts/contracts/proxy/transparent/TransparentUpgradeableProxy.sol";
import {ProxyAdmin} from "openzeppelin-contracts/contracts/proxy/transparent/ProxyAdmin.sol";
import {BaseScript} from "@aleph-script/BaseScript.s.sol";
import {FeeRecipient} from "@aleph-vault/FeeRecipient.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
// Use only to upgrade FeeRecipient.
// forge script UpgradeFeeRecipient --sig="run()" --broadcast -vvvv
contract UpgradeFeeRecipient is BaseScript {
    bytes32 constant ADMIN_SLOT = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;

    function setUp() public {}

    function run() public {
        string memory _chainId = _getChainId();
        vm.createSelectFork(_chainId);
        uint256 _privateKey = _getPrivateKey();
        vm.startBroadcast(_privateKey);
        string memory _environment = _getEnvironment();

        address _proxy = _getFeeRecipientProxy(_chainId, _environment);
        FeeRecipient _feeRecipientImpl = new FeeRecipient();

        address _proxyAdmin = address(uint160(uint256(vm.load(_proxy, ADMIN_SLOT))));

        ProxyAdmin(_proxyAdmin).upgradeAndCall(
            ITransparentUpgradeableProxy(payable(_proxy)), address(_feeRecipientImpl), ""
        );
        console.log("FeeRecipient upgraded to", address(_feeRecipientImpl));

        _writeDeploymentConfig(
            _chainId, _environment, ".feeRecipientImplementationAddress", vm.toString(address(_feeRecipientImpl))
        );
        vm.stopBroadcast();
    }
}
