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
import {IFeeRecipient} from "@aleph-vault/interfaces/IFeeRecipient.sol";
import {FeeRecipient} from "@aleph-vault/FeeRecipient.sol";
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */

// Use to Deploy only an FeeRecipient.
// forge script DeployFeeRecipient --sig="run()" --broadcast -vvvv --verify
contract DeployFeeRecipient is BaseScript {
    function setUp() public {}

    function run() public {
        string memory _chainId = _getChainId();
        vm.createSelectFork(_chainId);
        string memory _environment = _getEnvironment();

        address _proxyOwner = _getFeeRecipientProxyOwner(_chainId, _environment);

        string memory _factoryConfig = _getFactoryConfig();
        string memory _feeRecipientConfig = _getFeeRecipientConfig();

        IFeeRecipient.InitializationParams memory _initializationParams =
            _getInitializationParams(_factoryConfig, _feeRecipientConfig, _chainId, _environment);

        console.log("operationsMultisig", _initializationParams.operationsMultisig);
        console.log("alephTreasury", _initializationParams.alephTreasury);

        bytes memory _initializeArgs = abi.encodeWithSelector(FeeRecipient.initialize.selector, _initializationParams);

        uint256 _privateKey = _getPrivateKey();
        vm.startBroadcast(_privateKey);
        FeeRecipient _feeRecipientImpl = new FeeRecipient();

        ITransparentUpgradeableProxy _proxy = ITransparentUpgradeableProxy(
            address(new TransparentUpgradeableProxy(address(_feeRecipientImpl), _proxyOwner, _initializeArgs))
        );

        console.log("FeeRecipient deployed at:", address(_proxy));

        _writeDeploymentConfig(
            _chainId, _environment, ".feeRecipientImplementationAddress", vm.toString(address(_feeRecipientImpl))
        );
        _writeDeploymentConfig(_chainId, _environment, ".feeRecipientProxyAddress", vm.toString(address(_proxy)));

        vm.stopBroadcast();
    }

    function _getInitializationParams(
        string memory _factoryConfig,
        string memory _feeRecipientConfig,
        string memory _chainId,
        string memory _environment
    ) internal view returns (IFeeRecipient.InitializationParams memory) {
        return IFeeRecipient.InitializationParams({
            operationsMultisig: vm.parseJsonAddress(
                _factoryConfig, string.concat(".", _chainId, ".", _environment, ".operationsMultisig")
            ),
            alephTreasury: vm.parseJsonAddress(
                _feeRecipientConfig, string.concat(".", _chainId, ".", _environment, ".alephTreasury")
            )
        });
    }
}
