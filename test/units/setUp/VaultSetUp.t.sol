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

import {IAlephVault} from "@aleph-vault/interfaces/IAlephVault.sol";
import {RolesLibrary} from "@aleph-vault/libraries/RolesLibrary.sol";
import {PausableFlows} from "@aleph-vault/libraries/PausableFlows.sol";
import {AlephVaultDeposit} from "@aleph-vault/modules/AlephVaultDeposit.sol";
import {FeeManager} from "@aleph-vault/modules/FeeManager.sol";
import {AlephVaultBase} from "@aleph-vault/AlephVaultBase.sol";
import {ExposedVault} from "@aleph-test/exposes/ExposedVault.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://www.othentic.xyz/terms-of-service
 */
contract VaultSetUpTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/
    function test_constructor_when_minDepositAmountTimelock_passed_is_0() public {
        vm.expectRevert(AlephVaultBase.InvalidConstructorParams.selector);
        new AlephVaultDeposit(0, defaultConfigParams.maxDepositCapTimelock, defaultConfigParams.batchDuration);
    }

    function test_constructor_when_maxDepositCapTimelock_passed_is_0() public {
        vm.expectRevert(AlephVaultBase.InvalidConstructorParams.selector);
        new AlephVaultDeposit(defaultConfigParams.minDepositAmountTimelock, 0, defaultConfigParams.batchDuration);
    }

    function test_constructor_when_managementFeeTimelock_passed_is_0() public {
        vm.expectRevert(AlephVaultBase.InvalidConstructorParams.selector);
        new FeeManager(
            0,
            defaultConfigParams.performanceFeeTimelock,
            defaultConfigParams.feeRecipientTimelock,
            defaultConfigParams.batchDuration
        );
    }

    function test_constructor_when_performanceFeeTimelock_passed_is_0() public {
        vm.expectRevert(AlephVaultBase.InvalidConstructorParams.selector);
        new FeeManager(
            defaultConfigParams.managementFeeTimelock,
            0,
            defaultConfigParams.feeRecipientTimelock,
            defaultConfigParams.batchDuration
        );
    }

    function test_constructor_when_feeRecipientTimelock_passed_is_0() public {
        vm.expectRevert(AlephVaultBase.InvalidConstructorParams.selector);
        new FeeManager(
            defaultConfigParams.managementFeeTimelock,
            defaultConfigParams.performanceFeeTimelock,
            0,
            defaultConfigParams.batchDuration
        );
    }

    function test_constructor_when_batchDuration_passed_is_0() public {
        vm.expectRevert(AlephVaultBase.InvalidConstructorParams.selector);
        new ExposedVault(0);
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/
    function test_initialize_when_operationsMultisig_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            operationsMultisig: address(0),
            vaultFactory: defaultInitializationParams.vaultFactory,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            feeRecipient: defaultInitializationParams.feeRecipient,
            managementFee: defaultInitializationParams.managementFee,
            performanceFee: defaultInitializationParams.performanceFee,
            userInitializationParams: defaultInitializationParams.userInitializationParams,
            moduleInitializationParams: defaultInitializationParams.moduleInitializationParams
        });

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_vaultFactory_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            vaultFactory: address(0),
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            feeRecipient: defaultInitializationParams.feeRecipient,
            managementFee: defaultInitializationParams.managementFee,
            performanceFee: defaultInitializationParams.performanceFee,
            userInitializationParams: defaultInitializationParams.userInitializationParams,
            moduleInitializationParams: defaultInitializationParams.moduleInitializationParams
        });

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_oracle_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            vaultFactory: defaultInitializationParams.vaultFactory,
            oracle: address(0),
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            feeRecipient: defaultInitializationParams.feeRecipient,
            managementFee: defaultInitializationParams.managementFee,
            performanceFee: defaultInitializationParams.performanceFee,
            userInitializationParams: defaultInitializationParams.userInitializationParams,
            moduleInitializationParams: defaultInitializationParams.moduleInitializationParams
        });

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_guardian_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            vaultFactory: defaultInitializationParams.vaultFactory,
            oracle: defaultInitializationParams.oracle,
            guardian: address(0),
            authSigner: defaultInitializationParams.authSigner,
            feeRecipient: defaultInitializationParams.feeRecipient,
            managementFee: defaultInitializationParams.managementFee,
            performanceFee: defaultInitializationParams.performanceFee,
            userInitializationParams: defaultInitializationParams.userInitializationParams,
            moduleInitializationParams: defaultInitializationParams.moduleInitializationParams
        });

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_authSigner_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            vaultFactory: defaultInitializationParams.vaultFactory,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: address(0),
            feeRecipient: defaultInitializationParams.feeRecipient,
            managementFee: defaultInitializationParams.managementFee,
            performanceFee: defaultInitializationParams.performanceFee,
            userInitializationParams: defaultInitializationParams.userInitializationParams,
            moduleInitializationParams: defaultInitializationParams.moduleInitializationParams
        });

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_feeRecipient_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            vaultFactory: defaultInitializationParams.vaultFactory,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            feeRecipient: address(0),
            managementFee: defaultInitializationParams.managementFee,
            performanceFee: defaultInitializationParams.performanceFee,
            userInitializationParams: defaultInitializationParams.userInitializationParams,
            moduleInitializationParams: defaultInitializationParams.moduleInitializationParams
        });

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_managementFee_is_greater_than_maxManagementFee() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            vaultFactory: defaultInitializationParams.vaultFactory,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            feeRecipient: defaultInitializationParams.feeRecipient,
            managementFee: 10_001,
            performanceFee: defaultInitializationParams.performanceFee,
            userInitializationParams: defaultInitializationParams.userInitializationParams,
            moduleInitializationParams: defaultInitializationParams.moduleInitializationParams
        });

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_performanceFee_is_greater_than_maxPerformanceFee() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            vaultFactory: defaultInitializationParams.vaultFactory,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            feeRecipient: defaultInitializationParams.feeRecipient,
            managementFee: defaultInitializationParams.managementFee,
            performanceFee: 10_001,
            userInitializationParams: defaultInitializationParams.userInitializationParams,
            moduleInitializationParams: defaultInitializationParams.moduleInitializationParams
        });

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_manager_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            vaultFactory: defaultInitializationParams.vaultFactory,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            feeRecipient: defaultInitializationParams.feeRecipient,
            managementFee: defaultInitializationParams.managementFee,
            performanceFee: defaultInitializationParams.performanceFee,
            userInitializationParams: IAlephVault.UserInitializationParams({
                name: defaultInitializationParams.userInitializationParams.name,
                configId: defaultInitializationParams.userInitializationParams.configId,
                manager: address(0),
                underlyingToken: defaultInitializationParams.userInitializationParams.underlyingToken,
                custodian: defaultInitializationParams.userInitializationParams.custodian
            }),
            moduleInitializationParams: defaultInitializationParams.moduleInitializationParams
        });

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_underlyingToken_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            vaultFactory: defaultInitializationParams.vaultFactory,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            feeRecipient: defaultInitializationParams.feeRecipient,
            managementFee: defaultInitializationParams.managementFee,
            performanceFee: defaultInitializationParams.performanceFee,
            userInitializationParams: IAlephVault.UserInitializationParams({
                name: defaultInitializationParams.userInitializationParams.name,
                configId: defaultInitializationParams.userInitializationParams.configId,
                manager: defaultInitializationParams.userInitializationParams.manager,
                underlyingToken: address(0),
                custodian: defaultInitializationParams.userInitializationParams.custodian
            }),
            moduleInitializationParams: defaultInitializationParams.moduleInitializationParams
        });

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_custodian_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            vaultFactory: defaultInitializationParams.vaultFactory,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            feeRecipient: defaultInitializationParams.feeRecipient,
            managementFee: defaultInitializationParams.managementFee,
            performanceFee: defaultInitializationParams.performanceFee,
            userInitializationParams: IAlephVault.UserInitializationParams({
                name: defaultInitializationParams.userInitializationParams.name,
                configId: defaultInitializationParams.userInitializationParams.configId,
                manager: defaultInitializationParams.userInitializationParams.manager,
                underlyingToken: defaultInitializationParams.userInitializationParams.underlyingToken,
                custodian: address(0)
            }),
            moduleInitializationParams: defaultInitializationParams.moduleInitializationParams
        });

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_all_params_are_valid() public {
        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vault.initialize(defaultInitializationParams);

        assertEq(vault.name(), defaultInitializationParams.userInitializationParams.name);
        assertEq(vault.manager(), defaultInitializationParams.userInitializationParams.manager);
        assertEq(vault.oracle(), defaultInitializationParams.oracle);
        assertEq(vault.guardian(), defaultInitializationParams.guardian);
        assertEq(vault.authSigner(), defaultInitializationParams.authSigner);
        assertEq(vault.underlyingToken(), defaultInitializationParams.userInitializationParams.underlyingToken);
        assertEq(vault.custodian(), defaultInitializationParams.userInitializationParams.custodian);
        assertEq(vault.feeRecipient(), defaultInitializationParams.feeRecipient);
        assertEq(vault.managementFee(), defaultInitializationParams.managementFee);
        assertEq(vault.performanceFee(), defaultInitializationParams.performanceFee);

        assertTrue(vault.hasRole(RolesLibrary.OPERATIONS_MULTISIG, defaultInitializationParams.operationsMultisig));
        assertTrue(vault.hasRole(RolesLibrary.VAULT_FACTORY, defaultInitializationParams.vaultFactory));
        assertTrue(vault.hasRole(RolesLibrary.MANAGER, defaultInitializationParams.userInitializationParams.manager));
        assertTrue(vault.hasRole(RolesLibrary.ORACLE, defaultInitializationParams.oracle));
        assertTrue(vault.hasRole(RolesLibrary.GUARDIAN, defaultInitializationParams.guardian));

        assertTrue(
            vault.hasRole(
                PausableFlows.DEPOSIT_REQUEST_FLOW, defaultInitializationParams.userInitializationParams.manager
            )
        );
        assertTrue(vault.hasRole(PausableFlows.DEPOSIT_REQUEST_FLOW, defaultInitializationParams.guardian));
        assertTrue(vault.hasRole(PausableFlows.DEPOSIT_REQUEST_FLOW, defaultInitializationParams.operationsMultisig));
        assertTrue(
            vault.hasRole(
                PausableFlows.SETTLE_DEPOSIT_FLOW, defaultInitializationParams.userInitializationParams.manager
            )
        );
        assertTrue(vault.hasRole(PausableFlows.SETTLE_DEPOSIT_FLOW, defaultInitializationParams.guardian));
        assertTrue(vault.hasRole(PausableFlows.SETTLE_DEPOSIT_FLOW, defaultInitializationParams.operationsMultisig));
        assertTrue(
            vault.hasRole(
                PausableFlows.REDEEM_REQUEST_FLOW, defaultInitializationParams.userInitializationParams.manager
            )
        );
        assertTrue(vault.hasRole(PausableFlows.REDEEM_REQUEST_FLOW, defaultInitializationParams.guardian));
        assertTrue(vault.hasRole(PausableFlows.REDEEM_REQUEST_FLOW, defaultInitializationParams.operationsMultisig));
        assertTrue(
            vault.hasRole(
                PausableFlows.SETTLE_REDEEM_FLOW, defaultInitializationParams.userInitializationParams.manager
            )
        );
        assertTrue(vault.hasRole(PausableFlows.SETTLE_REDEEM_FLOW, defaultInitializationParams.guardian));
        assertTrue(vault.hasRole(PausableFlows.SETTLE_REDEEM_FLOW, defaultInitializationParams.operationsMultisig));

        assertTrue(vault.isFlowPaused(PausableFlows.DEPOSIT_REQUEST_FLOW));
        assertTrue(vault.isFlowPaused(PausableFlows.SETTLE_DEPOSIT_FLOW));
        assertTrue(vault.isFlowPaused(PausableFlows.REDEEM_REQUEST_FLOW));
        assertTrue(vault.isFlowPaused(PausableFlows.SETTLE_REDEEM_FLOW));
    }
}
