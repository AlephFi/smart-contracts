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
import {AlephVaultDeposit} from "@aleph-vault/modules/AlephVaultDeposit.sol";
import {AlephVaultRedeem} from "@aleph-vault/modules/AlephVaultRedeem.sol";
import {AlephVaultSettlement} from "@aleph-vault/modules/AlephVaultSettlement.sol";
import {FeeManager} from "@aleph-vault/modules/FeeManager.sol";
import {AlephVault} from "@aleph-vault/AlephVault.sol";
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */

struct ModuleImplementationAddresses {
    address alephVaultDepositImplementation;
    address alephVaultRedeemImplementation;
    address alephVaultSettlementImplementation;
    address feeManagerImplementation;
}

// Use to Deploy only an AlephVault implementation.
// forge script DeployAlephVaultImplementation --broadcast -vvvv --verify
contract DeployAlephVaultImplementation is BaseScript {
    function setUp() public {}

    function run() public {
        string memory _chainId = _getChainId();
        vm.createSelectFork(_chainId);
        uint256 _privateKey = _getPrivateKey();
        vm.startBroadcast(_privateKey);
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

        ModuleImplementationAddresses memory _moduleImplementationAddresses = _deployModules(
            _minDepositAmountTimelock,
            _maxDepositCapTimelock,
            _managementFeeTimelock,
            _performanceFeeTimelock,
            _feeRecipientTimelock,
            _batchDuration
        );
        AlephVault _vault = new AlephVault(_batchDuration);
        console.log("Vault implementation deployed at:", address(_vault));

        _writeConfig(_chainId, _environment, address(_vault), _moduleImplementationAddresses);
        vm.stopBroadcast();
    }

    function _deployModules(
        uint48 _minDepositAmountTimelock,
        uint48 _maxDepositCapTimelock,
        uint48 _managementFeeTimelock,
        uint48 _performanceFeeTimelock,
        uint48 _feeRecipientTimelock,
        uint48 _batchDuration
    ) internal returns (ModuleImplementationAddresses memory _moduleImplementationAddresses) {
        AlephVaultDeposit _alephVaultDeposit =
            new AlephVaultDeposit(_minDepositAmountTimelock, _maxDepositCapTimelock, _batchDuration);
        AlephVaultRedeem _alephVaultRedeem = new AlephVaultRedeem(_batchDuration);
        AlephVaultSettlement _alephVaultSettlement = new AlephVaultSettlement(_batchDuration);
        FeeManager _feeManager =
            new FeeManager(_managementFeeTimelock, _performanceFeeTimelock, _feeRecipientTimelock, _batchDuration);

        _moduleImplementationAddresses = ModuleImplementationAddresses({
            alephVaultDepositImplementation: address(_alephVaultDeposit),
            alephVaultRedeemImplementation: address(_alephVaultRedeem),
            alephVaultSettlementImplementation: address(_alephVaultSettlement),
            feeManagerImplementation: address(_feeManager)
        });
    }

    function _writeConfig(
        string memory _chainId,
        string memory _environment,
        address _vaultAddress,
        ModuleImplementationAddresses memory _moduleImplementationAddresses
    ) internal {
        _writeDeploymentConfig(_chainId, _environment, ".vaultImplementationAddress", vm.toString(_vaultAddress));
        _writeDeploymentConfig(
            _chainId,
            _environment,
            ".vaultDepositImplementationAddress",
            vm.toString(_moduleImplementationAddresses.alephVaultDepositImplementation)
        );
        _writeDeploymentConfig(
            _chainId,
            _environment,
            ".vaultRedeemImplementationAddress",
            vm.toString(_moduleImplementationAddresses.alephVaultRedeemImplementation)
        );
        _writeDeploymentConfig(
            _chainId,
            _environment,
            ".vaultSettlementImplementationAddress",
            vm.toString(_moduleImplementationAddresses.alephVaultSettlementImplementation)
        );
        _writeDeploymentConfig(
            _chainId,
            _environment,
            ".feeManagerImplementationAddress",
            vm.toString(_moduleImplementationAddresses.feeManagerImplementation)
        );
    }
}
