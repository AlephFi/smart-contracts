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
import {BaseScript} from "@aleph-script/BaseScript.s.sol";
import {IAccountant} from "@aleph-vault/interfaces/IAccountant.sol";
import {Accountant} from "@aleph-vault/Accountant.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */

// Use to Deploy only an Accountant Proxy.
// forge script DeployAccountantProxy --sig="run()" --broadcast -vvvv
contract DeployAccountantProxy is BaseScript {
    function setUp() public {}

    function run() public {
        string memory _chainId = _getChainId();
        vm.createSelectFork(_chainId);
        string memory _environment = _getEnvironment();

        address _proxyOwner = _getAccountantProxyOwner(_chainId, _environment);

        string memory _deploymentConfig = _getDeploymentConfig();
        string memory _accountantConfig = _getAccountantConfig();

        IAccountant.InitializationParams memory _initializationParams =
            _getInitializationParams(_deploymentConfig, _accountantConfig, _chainId, _environment);

        console.log("operationsMultisig", _initializationParams.operationsMultisig);
        console.log("alephTreasury", _initializationParams.alephTreasury);

        bytes memory _initializeArgs = abi.encodeWithSelector(Accountant.initialize.selector, _initializationParams);
        address _accountantImpl = _getAccountantImplementation(_chainId, _environment);

        uint256 _privateKey = _getPrivateKey();
        vm.startBroadcast(_privateKey);

        ITransparentUpgradeableProxy _proxy = ITransparentUpgradeableProxy(
            address(new TransparentUpgradeableProxy(address(_accountantImpl), _proxyOwner, _initializeArgs))
        );

        console.log("Accountant Proxy deployed at:", address(_proxy));

        _writeDeploymentConfig(_chainId, _environment, ".accountantProxyAddress", vm.toString(address(_proxy)));

        vm.stopBroadcast();
    }

    function _getInitializationParams(
        string memory _deploymentConfig,
        string memory _accountantConfig,
        string memory _chainId,
        string memory _environment
    ) internal pure returns (IAccountant.InitializationParams memory) {
        return IAccountant.InitializationParams({
            operationsMultisig: vm.parseJsonAddress(
                _deploymentConfig, string.concat(".", _chainId, ".", _environment, ".operationsMultisig")
            ),
            alephTreasury: vm.parseJsonAddress(
                _accountantConfig, string.concat(".", _chainId, ".", _environment, ".alephTreasury")
            )
        });
    }
}
