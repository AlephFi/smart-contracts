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
import {MigrationManager} from "@aleph-vault/modules/MigrationManager.sol";
import {AlephVault} from "@aleph-vault/AlephVault.sol";
/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */

// Use to Deploy only an AlephVault implementation.
// forge script DeployAlephVaultImplementation --broadcast -vvvv --verify
contract DeployAlephVaultImplementation is BaseScript {
    struct ConfigParams {
        uint48 minDepositAmountTimelock;
        uint48 minUserBalanceTimelock;
        uint48 maxDepositCapTimelock;
        uint48 noticePeriodTimelock;
        uint48 lockInPeriodTimelock;
        uint48 minRedeemAmountTimelock;
        uint48 managementFeeTimelock;
        uint48 performanceFeeTimelock;
        uint48 feeRecipientTimelock;
        uint48 batchDuration;
    }

    function setUp() public {}

    function run() public {
        string memory _chainId = _getChainId();
        vm.createSelectFork(_chainId);
        uint256 _privateKey = _getPrivateKey();
        vm.startBroadcast(_privateKey);
        string memory _environment = _getEnvironment();

        string memory _config = _getConfigFile();
        ConfigParams memory _configParams = _getConfigParams(_config, _chainId, _environment);

        console.log("chainId", _chainId);
        console.log("environment", _environment);
        console.log("minDepositAmountTimelock", _configParams.minDepositAmountTimelock);
        console.log("minUserBalanceTimelock", _configParams.minUserBalanceTimelock);
        console.log("maxDepositCapTimelock", _configParams.maxDepositCapTimelock);
        console.log("noticePeriodTimelock", _configParams.noticePeriodTimelock);
        console.log("lockInPeriodTimelock", _configParams.lockInPeriodTimelock);
        console.log("minRedeemAmountTimelock", _configParams.minRedeemAmountTimelock);
        console.log("managementFeeTimelock", _configParams.managementFeeTimelock);
        console.log("performanceFeeTimelock", _configParams.performanceFeeTimelock);
        console.log("feeRecipientTimelock", _configParams.feeRecipientTimelock);
        console.log("batchDuration", _configParams.batchDuration);

        IAlephVault.ModuleInitializationParams memory _moduleImplementationAddresses = _deployModules(_configParams);
        AlephVault _vault = new AlephVault(_configParams.batchDuration);
        console.log("Vault implementation deployed at:", address(_vault));

        _writeConfig(_chainId, _environment, address(_vault), _moduleImplementationAddresses);
        vm.stopBroadcast();
    }

    function _deployModules(ConfigParams memory _configParams)
        internal
        returns (IAlephVault.ModuleInitializationParams memory _moduleImplementationAddresses)
    {
        AlephVaultDeposit _alephVaultDeposit = new AlephVaultDeposit(
            _configParams.minDepositAmountTimelock,
            _configParams.minUserBalanceTimelock,
            _configParams.maxDepositCapTimelock,
            _configParams.batchDuration
        );
        AlephVaultRedeem _alephVaultRedeem = new AlephVaultRedeem(
            _configParams.noticePeriodTimelock,
            _configParams.lockInPeriodTimelock,
            _configParams.minRedeemAmountTimelock,
            _configParams.batchDuration
        );
        AlephVaultSettlement _alephVaultSettlement = new AlephVaultSettlement(_configParams.batchDuration);
        FeeManager _feeManager = new FeeManager(
            _configParams.managementFeeTimelock,
            _configParams.performanceFeeTimelock,
            _configParams.feeRecipientTimelock,
            _configParams.batchDuration
        );
        MigrationManager _migrationManager = new MigrationManager(_configParams.batchDuration);

        _moduleImplementationAddresses = IAlephVault.ModuleInitializationParams({
            alephVaultDepositImplementation: address(_alephVaultDeposit),
            alephVaultRedeemImplementation: address(_alephVaultRedeem),
            alephVaultSettlementImplementation: address(_alephVaultSettlement),
            feeManagerImplementation: address(_feeManager),
            migrationManagerImplementation: address(_migrationManager)
        });
    }

    function _getConfigParams(string memory _config, string memory _chainId, string memory _environment)
        internal
        view
        returns (ConfigParams memory _configParams)
    {
        _configParams = ConfigParams({
            minDepositAmountTimelock: uint48(
                vm.parseJsonUint(_config, string.concat(".", _chainId, ".", _environment, ".minDepositAmountTimelock"))
            ),
            minUserBalanceTimelock: uint48(
                vm.parseJsonUint(_config, string.concat(".", _chainId, ".", _environment, ".minUserBalanceTimelock"))
            ),
            maxDepositCapTimelock: uint48(
                vm.parseJsonUint(_config, string.concat(".", _chainId, ".", _environment, ".maxDepositCapTimelock"))
            ),
            noticePeriodTimelock: uint48(
                vm.parseJsonUint(_config, string.concat(".", _chainId, ".", _environment, ".noticePeriodTimelock"))
            ),
            lockInPeriodTimelock: uint48(
                vm.parseJsonUint(_config, string.concat(".", _chainId, ".", _environment, ".lockInPeriodTimelock"))
            ),
            minRedeemAmountTimelock: uint48(
                vm.parseJsonUint(_config, string.concat(".", _chainId, ".", _environment, ".minRedeemAmountTimelock"))
            ),
            managementFeeTimelock: uint48(
                vm.parseJsonUint(_config, string.concat(".", _chainId, ".", _environment, ".managementFeeTimelock"))
            ),
            performanceFeeTimelock: uint48(
                vm.parseJsonUint(_config, string.concat(".", _chainId, ".", _environment, ".performanceFeeTimelock"))
            ),
            feeRecipientTimelock: uint48(
                vm.parseJsonUint(_config, string.concat(".", _chainId, ".", _environment, ".feeRecipientTimelock"))
            ),
            batchDuration: uint48(
                vm.parseJsonUint(_config, string.concat(".", _chainId, ".", _environment, ".batchDuration"))
            )
        });
    }

    function _writeConfig(
        string memory _chainId,
        string memory _environment,
        address _vaultAddress,
        IAlephVault.ModuleInitializationParams memory _moduleImplementationAddresses
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
        _writeDeploymentConfig(
            _chainId,
            _environment,
            ".migrationManagerImplementationAddress",
            vm.toString(_moduleImplementationAddresses.migrationManagerImplementation)
        );
    }
}
