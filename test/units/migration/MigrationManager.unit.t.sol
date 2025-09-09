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

import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {RolesLibrary} from "@aleph-vault/libraries/RolesLibrary.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {ModulesLibrary} from "@aleph-vault/libraries/ModulesLibrary.sol";
import {IMigrationManager} from "@aleph-vault/interfaces/IMigrationManager.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

contract MigrationManagerTest is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
        _unpauseVaultFlows();
    }

    /*//////////////////////////////////////////////////////////////
                        OPERATIONS MULTISIG MIGRATION TESTS
    //////////////////////////////////////////////////////////////*/
    function test_migrateOperationsMultisig_whenCallerIsNotVAULT_FACTORY_revertsWithAccessControlUnauthorizedAccount()
        public
    {
        // setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // set up operations multisig
        address newOperationsMultisig = makeAddr("newOperationsMultisig");

        // migrate operations multisig
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.VAULT_FACTORY
            )
        );
        vault.migrateOperationsMultisig(newOperationsMultisig);
    }

    function test_migrateOperationsMultisig_whenNewOperationsMultisigIsAddress0_revertsWithInvalidOperationsMultisigAddress(
    ) public {
        // migrate operations multisig
        vm.prank(vaultFactory);
        vm.expectRevert(IMigrationManager.InvalidOperationsMultisigAddress.selector);
        vault.migrateOperationsMultisig(address(0));
    }

    function test_migrateOperationsMultisig_shouldSetNewOperationsMultisig() public {
        // set up operations multisig
        address newOperationsMultisig = makeAddr("newOperationsMultisig");
        address oldOperationsMultisig = vault.operationsMultisig();

        // migrate operations multisig
        vm.prank(vaultFactory);
        vm.expectEmit(true, true, true, true);
        emit IMigrationManager.OperationsMultisigMigrated(newOperationsMultisig);
        vault.migrateOperationsMultisig(newOperationsMultisig);

        // check operations multisig is set
        assertEq(vault.operationsMultisig(), newOperationsMultisig);

        // check roles are revoked
        assertFalse(vault.hasRole(RolesLibrary.OPERATIONS_MULTISIG, oldOperationsMultisig));
        assertFalse(vault.hasRole(PausableFlows.DEPOSIT_REQUEST_FLOW, oldOperationsMultisig));
        assertFalse(vault.hasRole(PausableFlows.SETTLE_DEPOSIT_FLOW, oldOperationsMultisig));
        assertFalse(vault.hasRole(PausableFlows.REDEEM_REQUEST_FLOW, oldOperationsMultisig));
        assertFalse(vault.hasRole(PausableFlows.SETTLE_REDEEM_FLOW, oldOperationsMultisig));

        // check roles are granted
        assertTrue(vault.hasRole(RolesLibrary.OPERATIONS_MULTISIG, newOperationsMultisig));
        assertTrue(vault.hasRole(PausableFlows.DEPOSIT_REQUEST_FLOW, newOperationsMultisig));
        assertTrue(vault.hasRole(PausableFlows.SETTLE_DEPOSIT_FLOW, newOperationsMultisig));
        assertTrue(vault.hasRole(PausableFlows.REDEEM_REQUEST_FLOW, newOperationsMultisig));
        assertTrue(vault.hasRole(PausableFlows.SETTLE_REDEEM_FLOW, newOperationsMultisig));
    }

    /*//////////////////////////////////////////////////////////////
                        ORACLE MIGRATION TESTS
    //////////////////////////////////////////////////////////////*/
    function test_migrateOracle_whenCallerIsNotVAULT_FACTORY_revertsWithAccessControlUnauthorizedAccount() public {
        // setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // set up oracle
        address newOracle = makeAddr("newOracle");

        // migrate oracle
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.VAULT_FACTORY
            )
        );
        vault.migrateOracle(newOracle);
    }

    function test_migrateOracle_whenNewOracleIsAddress0_revertsWithInvalidOracleAddress() public {
        // migrate oracle
        vm.prank(vaultFactory);
        vm.expectRevert(IMigrationManager.InvalidOracleAddress.selector);
        vault.migrateOracle(address(0));
    }

    function test_migrateOracle_shouldSetNewOracle() public {
        // set up oracle
        address newOracle = makeAddr("newOracle");
        address oldOracle = vault.oracle();

        // migrate oracle
        vm.prank(vaultFactory);
        vm.expectEmit(true, true, true, true);
        emit IMigrationManager.OracleMigrated(newOracle);
        vault.migrateOracle(newOracle);

        // check oracle is set
        assertEq(vault.oracle(), newOracle);

        // check roles are revoked
        assertFalse(vault.hasRole(RolesLibrary.ORACLE, oldOracle));

        // check roles are granted
        assertTrue(vault.hasRole(RolesLibrary.ORACLE, newOracle));
    }

    /*//////////////////////////////////////////////////////////////
                        GUARDIAN MIGRATION TESTS
    //////////////////////////////////////////////////////////////*/
    function test_migrateGuardian_whenCallerIsNotVAULT_FACTORY_revertsWithAccessControlUnauthorizedAccount() public {
        // setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // set up guardian
        address newGuardian = makeAddr("newGuardian");

        // migrate guardian
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.VAULT_FACTORY
            )
        );
        vault.migrateGuardian(newGuardian);
    }

    function test_migrateGuardian_whenNewGuardianIsAddress0_revertsWithInvalidGuardianAddress() public {
        // migrate guardian
        vm.prank(vaultFactory);
        vm.expectRevert(IMigrationManager.InvalidGuardianAddress.selector);
        vault.migrateGuardian(address(0));
    }

    function test_migrateGuardian_shouldSetNewGuardian() public {
        // set up guardian
        address newGuardian = makeAddr("newGuardian");
        address oldGuardian = vault.guardian();

        // migrate guardian
        vm.prank(vaultFactory);
        vm.expectEmit(true, true, true, true);
        emit IMigrationManager.GuardianMigrated(newGuardian);
        vault.migrateGuardian(newGuardian);

        // check guardian is set
        assertEq(vault.guardian(), newGuardian);

        // check roles are revoked
        assertFalse(vault.hasRole(RolesLibrary.GUARDIAN, oldGuardian));
        assertFalse(vault.hasRole(PausableFlows.DEPOSIT_REQUEST_FLOW, oldGuardian));
        assertFalse(vault.hasRole(PausableFlows.SETTLE_DEPOSIT_FLOW, oldGuardian));
        assertFalse(vault.hasRole(PausableFlows.REDEEM_REQUEST_FLOW, oldGuardian));
        assertFalse(vault.hasRole(PausableFlows.SETTLE_REDEEM_FLOW, oldGuardian));

        // check roles are granted
        assertTrue(vault.hasRole(RolesLibrary.GUARDIAN, newGuardian));
        assertTrue(vault.hasRole(PausableFlows.DEPOSIT_REQUEST_FLOW, newGuardian));
        assertTrue(vault.hasRole(PausableFlows.SETTLE_DEPOSIT_FLOW, newGuardian));
        assertTrue(vault.hasRole(PausableFlows.REDEEM_REQUEST_FLOW, newGuardian));
        assertTrue(vault.hasRole(PausableFlows.SETTLE_REDEEM_FLOW, newGuardian));
    }

    /*//////////////////////////////////////////////////////////////
                        AUTH SIGNER MIGRATION TESTS
    //////////////////////////////////////////////////////////////*/
    function test_migrateAuthSigner_whenCallerIsNotVAULT_FACTORY_revertsWithAccessControlUnauthorizedAccount() public {
        // setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // set up auth signer
        address newAuthSigner = makeAddr("newAuthSigner");

        // migrate auth signer
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.VAULT_FACTORY
            )
        );
        vault.migrateAuthSigner(newAuthSigner);
    }

    function test_migrateAuthSigner_whenNewAuthSignerIsAddress0_revertsWithInvalidAuthSignerAddress() public {
        // migrate auth signer
        vm.prank(vaultFactory);
        vm.expectRevert(IMigrationManager.InvalidAuthSignerAddress.selector);
        vault.migrateAuthSigner(address(0));
    }

    function test_migrateAuthSigner_shouldSetNewAuthSigner() public {
        // set up auth signer
        address newAuthSigner = makeAddr("newAuthSigner");

        // migrate auth signer
        vm.prank(vaultFactory);
        vm.expectEmit(true, true, true, true);
        emit IMigrationManager.AuthSignerMigrated(newAuthSigner);
        vault.migrateAuthSigner(newAuthSigner);

        // check auth signer is set
        assertEq(vault.authSigner(), newAuthSigner);
    }

    /*//////////////////////////////////////////////////////////////
                        MODULE MIGRATION TESTS
    //////////////////////////////////////////////////////////////*/
    function test_migrateModules_whenCallerIsNotVAULT_FACTORY_revertsWithAccessControlUnauthorizedAccount() public {
        // setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // set up module
        bytes4 module = ModulesLibrary.MIGRATION_MANAGER;
        address newImplementation = makeAddr("newImplementation");

        // migrate module
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.VAULT_FACTORY
            )
        );
        vault.migrateModules(module, newImplementation);
    }

    function test_migrateModules_whenNewImplementationIsAddress0_revertsWithInvalidModuleAddress() public {
        // migrate module
        vm.prank(vaultFactory);
        vm.expectRevert(IMigrationManager.InvalidModuleAddress.selector);
        vault.migrateModules(ModulesLibrary.MIGRATION_MANAGER, address(0));
    }

    function test_migrateModules_shouldSetNewImplementation() public {
        // set up module
        bytes4 module = ModulesLibrary.MIGRATION_MANAGER;
        address newImplementation = makeAddr("newImplementation");

        // migrate module
        vm.prank(vaultFactory);
        vm.expectEmit(true, true, true, true);
        emit IMigrationManager.ModulesMigrated(module, newImplementation);
        vault.migrateModules(module, newImplementation);
    }
}
