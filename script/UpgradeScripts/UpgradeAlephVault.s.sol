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
import {UpgradeableBeacon} from "openzeppelin-contracts/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {BaseScript} from "@aleph-script/BaseScript.s.sol";
import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {IAlephVaultFactory} from "@aleph-vault/interfaces/IAlephVaultFactory.sol";
import {ModulesLibrary} from "@aleph-vault/libraries/ModulesLibrary.sol";
import {AlephVault} from "@aleph-vault/AlephVault.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */

// Use only to upgrade AlephVault.
// forge script UpgradeAlephVault --sig="run()" --broadcast -vvvv --verify
contract UpgradeAlephVault is BaseScript {
    function setUp() public {}

    function run() public {
        string memory _chainId = _getChainId();
        vm.createSelectFork(_chainId);
        uint256 _privateKey = _getPrivateKey();
        vm.startBroadcast(_privateKey);
        string memory _environment = _getEnvironment();

        UpgradeableBeacon _beacon = UpgradeableBeacon(_getBeacon(_chainId, _environment));
        address _vaultImplementation = _getVaultImplementation(_chainId, _environment);

        _beacon.upgradeTo(_vaultImplementation);
        console.log("AlephVault upgraded to", _vaultImplementation);

        _updateModuleImplementations(_chainId, _environment);

        vm.stopBroadcast();
    }

    function _updateModuleImplementations(string memory _chainId, string memory _environment) internal {
        address _vaultFactory = _getFactoryProxy(_chainId, _environment);
        address _vaultDepositImplementation =
            _getModuleImplementation(_chainId, _environment, "vaultDepositImplementationAddress");
        address _vaultRedeemImplementation =
            _getModuleImplementation(_chainId, _environment, "vaultRedeemImplementationAddress");
        address _vaultSettlementImplementation =
            _getModuleImplementation(_chainId, _environment, "vaultSettlementImplementationAddress");
        address _feeManagerImplementation =
            _getModuleImplementation(_chainId, _environment, "feeManagerImplementationAddress");
        address _migrationManagerImplementation =
            _getModuleImplementation(_chainId, _environment, "migrationManagerImplementationAddress");

        IAlephVaultFactory(_vaultFactory)
            .setModuleImplementation(ModulesLibrary.ALEPH_VAULT_DEPOSIT, _vaultDepositImplementation);
        IAlephVaultFactory(_vaultFactory)
            .setModuleImplementation(ModulesLibrary.ALEPH_VAULT_REDEEM, _vaultRedeemImplementation);
        IAlephVaultFactory(_vaultFactory)
            .setModuleImplementation(ModulesLibrary.ALEPH_VAULT_SETTLEMENT, _vaultSettlementImplementation);
        IAlephVaultFactory(_vaultFactory).setModuleImplementation(ModulesLibrary.FEE_MANAGER, _feeManagerImplementation);
        IAlephVaultFactory(_vaultFactory)
            .setModuleImplementation(ModulesLibrary.MIGRATION_MANAGER, _migrationManagerImplementation);
    }
}
