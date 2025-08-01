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
        IAlephVault.ConstructorParams memory _constructorParams = IAlephVault.ConstructorParams({
            minDepositAmountTimelock: 0,
            maxDepositCapTimelock: defaultConstructorParams.maxDepositCapTimelock,
            managementFeeTimelock: defaultConstructorParams.managementFeeTimelock,
            performanceFeeTimelock: defaultConstructorParams.performanceFeeTimelock,
            feeRecipientTimelock: defaultConstructorParams.feeRecipientTimelock,
            batchDuration: defaultConstructorParams.batchDuration
        });

        vm.expectRevert(IAlephVault.InvalidConstructorParams.selector);
        new ExposedVault(_constructorParams);
    }

    function test_constructor_when_maxDepositCapTimelock_passed_is_0() public {
        IAlephVault.ConstructorParams memory _constructorParams = IAlephVault.ConstructorParams({
            minDepositAmountTimelock: defaultConstructorParams.minDepositAmountTimelock,
            maxDepositCapTimelock: 0,
            managementFeeTimelock: defaultConstructorParams.managementFeeTimelock,
            performanceFeeTimelock: defaultConstructorParams.performanceFeeTimelock,
            feeRecipientTimelock: defaultConstructorParams.feeRecipientTimelock,
            batchDuration: defaultConstructorParams.batchDuration
        });

        vm.expectRevert(IAlephVault.InvalidConstructorParams.selector);
        new ExposedVault(_constructorParams);
    }

    function test_constructor_when_managementFeeTimelock_passed_is_0() public {
        IAlephVault.ConstructorParams memory _constructorParams = IAlephVault.ConstructorParams({
            minDepositAmountTimelock: defaultConstructorParams.minDepositAmountTimelock,
            maxDepositCapTimelock: defaultConstructorParams.maxDepositCapTimelock,
            managementFeeTimelock: 0,
            performanceFeeTimelock: defaultConstructorParams.performanceFeeTimelock,
            feeRecipientTimelock: defaultConstructorParams.feeRecipientTimelock,
            batchDuration: defaultConstructorParams.batchDuration
        });

        vm.expectRevert(IAlephVault.InvalidConstructorParams.selector);
        new ExposedVault(_constructorParams);
    }

    function test_constructor_when_performanceFeeTimelock_passed_is_0() public {
        IAlephVault.ConstructorParams memory _constructorParams = IAlephVault.ConstructorParams({
            minDepositAmountTimelock: defaultConstructorParams.minDepositAmountTimelock,
            maxDepositCapTimelock: defaultConstructorParams.maxDepositCapTimelock,
            managementFeeTimelock: defaultConstructorParams.managementFeeTimelock,
            performanceFeeTimelock: 0,
            feeRecipientTimelock: defaultConstructorParams.feeRecipientTimelock,
            batchDuration: defaultConstructorParams.batchDuration
        });

        vm.expectRevert(IAlephVault.InvalidConstructorParams.selector);
        new ExposedVault(_constructorParams);
    }

    function test_constructor_when_feeRecipientTimelock_passed_is_0() public {
        IAlephVault.ConstructorParams memory _constructorParams = IAlephVault.ConstructorParams({
            minDepositAmountTimelock: defaultConstructorParams.minDepositAmountTimelock,
            maxDepositCapTimelock: defaultConstructorParams.maxDepositCapTimelock,
            managementFeeTimelock: defaultConstructorParams.managementFeeTimelock,
            performanceFeeTimelock: defaultConstructorParams.performanceFeeTimelock,
            feeRecipientTimelock: 0,
            batchDuration: defaultConstructorParams.batchDuration
        });

        vm.expectRevert(IAlephVault.InvalidConstructorParams.selector);
        new ExposedVault(_constructorParams);
    }

    function test_constructor_when_batchDuration_passed_is_0() public {
        IAlephVault.ConstructorParams memory _constructorParams = IAlephVault.ConstructorParams({
            minDepositAmountTimelock: defaultConstructorParams.minDepositAmountTimelock,
            maxDepositCapTimelock: defaultConstructorParams.maxDepositCapTimelock,
            managementFeeTimelock: defaultConstructorParams.managementFeeTimelock,
            performanceFeeTimelock: defaultConstructorParams.performanceFeeTimelock,
            feeRecipientTimelock: defaultConstructorParams.feeRecipientTimelock,
            batchDuration: 0
        });

        vm.expectRevert(IAlephVault.InvalidConstructorParams.selector);
        new ExposedVault(_constructorParams);
    }

    function test_constructor_when_all_params_are_valid() public {
        vault = new ExposedVault(defaultConstructorParams);

        assertEq(vault.MIN_DEPOSIT_AMOUNT_TIMELOCK(), defaultConstructorParams.minDepositAmountTimelock);
        assertEq(vault.MAX_DEPOSIT_CAP_TIMELOCK(), defaultConstructorParams.maxDepositCapTimelock);
        assertEq(vault.MANAGEMENT_FEE_TIMELOCK(), defaultConstructorParams.managementFeeTimelock);
        assertEq(vault.PERFORMANCE_FEE_TIMELOCK(), defaultConstructorParams.performanceFeeTimelock);
        assertEq(vault.FEE_RECIPIENT_TIMELOCK(), defaultConstructorParams.feeRecipientTimelock);
        assertEq(vault.BATCH_DURATION(), defaultConstructorParams.batchDuration);
    }

    /*//////////////////////////////////////////////////////////////
                        INITIALIZATION TESTS
    //////////////////////////////////////////////////////////////*/
    function test_initialize_when_manager_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            name: defaultInitializationParams.name,
            manager: address(0),
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            underlyingToken: defaultInitializationParams.underlyingToken,
            custodian: defaultInitializationParams.custodian,
            feeRecipient: defaultInitializationParams.feeRecipient,
            managementFee: defaultInitializationParams.managementFee,
            performanceFee: defaultInitializationParams.performanceFee
        });

        vault = new ExposedVault(defaultConstructorParams);

        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_operationsMultisig_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            name: defaultInitializationParams.name,
            manager: defaultInitializationParams.manager,
            operationsMultisig: address(0),
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            underlyingToken: defaultInitializationParams.underlyingToken,
            custodian: defaultInitializationParams.custodian,
            feeRecipient: defaultInitializationParams.feeRecipient,
            managementFee: defaultInitializationParams.managementFee,
            performanceFee: defaultInitializationParams.performanceFee
        });

        vault = new ExposedVault(defaultConstructorParams);

        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_oracle_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            name: defaultInitializationParams.name,
            manager: defaultInitializationParams.manager,
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            oracle: address(0),
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            underlyingToken: defaultInitializationParams.underlyingToken,
            custodian: defaultInitializationParams.custodian,
            feeRecipient: defaultInitializationParams.feeRecipient,
            managementFee: defaultInitializationParams.managementFee,
            performanceFee: defaultInitializationParams.performanceFee
        });

        vault = new ExposedVault(defaultConstructorParams);

        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_guardian_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            name: defaultInitializationParams.name,
            manager: defaultInitializationParams.manager,
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            oracle: defaultInitializationParams.oracle,
            guardian: address(0),
            authSigner: defaultInitializationParams.authSigner,
            underlyingToken: defaultInitializationParams.underlyingToken,
            custodian: defaultInitializationParams.custodian,
            feeRecipient: defaultInitializationParams.feeRecipient,
            managementFee: defaultInitializationParams.managementFee,
            performanceFee: defaultInitializationParams.performanceFee
        });

        vault = new ExposedVault(defaultConstructorParams);

        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_authSigner_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            name: defaultInitializationParams.name,
            manager: defaultInitializationParams.manager,
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: address(0),
            underlyingToken: defaultInitializationParams.underlyingToken,
            custodian: defaultInitializationParams.custodian,
            feeRecipient: defaultInitializationParams.feeRecipient,
            managementFee: defaultInitializationParams.managementFee,
            performanceFee: defaultInitializationParams.performanceFee
        });

        vault = new ExposedVault(defaultConstructorParams);

        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_underlyingToken_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            name: defaultInitializationParams.name,
            manager: defaultInitializationParams.manager,
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            underlyingToken: address(0),
            custodian: defaultInitializationParams.custodian,
            feeRecipient: defaultInitializationParams.feeRecipient,
            managementFee: defaultInitializationParams.managementFee,
            performanceFee: defaultInitializationParams.performanceFee
        });

        vault = new ExposedVault(defaultConstructorParams);

        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_custodian_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            name: defaultInitializationParams.name,
            manager: defaultInitializationParams.manager,
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            underlyingToken: defaultInitializationParams.underlyingToken,
            custodian: address(0),
            feeRecipient: defaultInitializationParams.feeRecipient,
            managementFee: defaultInitializationParams.managementFee,
            performanceFee: defaultInitializationParams.performanceFee
        });

        vault = new ExposedVault(defaultConstructorParams);

        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_feeRecipient_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            name: defaultInitializationParams.name,
            manager: defaultInitializationParams.manager,
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            underlyingToken: defaultInitializationParams.underlyingToken,
            custodian: defaultInitializationParams.custodian,
            feeRecipient: address(0),
            managementFee: defaultInitializationParams.managementFee,
            performanceFee: defaultInitializationParams.performanceFee
        });

        vault = new ExposedVault(defaultConstructorParams);

        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_managementFee_is_greater_than_maxManagementFee() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            name: defaultInitializationParams.name,
            manager: defaultInitializationParams.manager,
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            underlyingToken: defaultInitializationParams.underlyingToken,
            custodian: defaultInitializationParams.custodian,
            feeRecipient: defaultInitializationParams.feeRecipient,
            managementFee: 10_001,
            performanceFee: defaultInitializationParams.performanceFee
        });

        vault = new ExposedVault(defaultConstructorParams);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_performanceFee_is_greater_than_maxPerformanceFee() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            name: defaultInitializationParams.name,
            manager: defaultInitializationParams.manager,
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            underlyingToken: defaultInitializationParams.underlyingToken,
            custodian: defaultInitializationParams.custodian,
            feeRecipient: defaultInitializationParams.feeRecipient,
            managementFee: defaultInitializationParams.managementFee,
            performanceFee: 10_001
        });

        vault = new ExposedVault(defaultConstructorParams);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_all_params_are_valid() public {
        vault = new ExposedVault(defaultConstructorParams);
        vault.initialize(defaultInitializationParams);

        assertEq(vault.name(), defaultInitializationParams.name);
        assertEq(vault.manager(), defaultInitializationParams.manager);
        assertEq(vault.oracle(), defaultInitializationParams.oracle);
        assertEq(vault.guardian(), defaultInitializationParams.guardian);
        assertEq(vault.authSigner(), defaultInitializationParams.authSigner);
        assertEq(vault.underlyingToken(), defaultInitializationParams.underlyingToken);
        assertEq(vault.custodian(), defaultInitializationParams.custodian);
        assertEq(vault.feeRecipient(), defaultInitializationParams.feeRecipient);
        assertEq(vault.managementFee(), defaultInitializationParams.managementFee);
        assertEq(vault.performanceFee(), defaultInitializationParams.performanceFee);

        assertTrue(vault.hasRole(RolesLibrary.OPERATIONS_MULTISIG, defaultInitializationParams.operationsMultisig));
        assertTrue(vault.hasRole(RolesLibrary.MANAGER, defaultInitializationParams.manager));
        assertTrue(vault.hasRole(RolesLibrary.ORACLE, defaultInitializationParams.oracle));
        assertTrue(vault.hasRole(RolesLibrary.GUARDIAN, defaultInitializationParams.guardian));

        assertTrue(vault.hasRole(PausableFlows.DEPOSIT_REQUEST_FLOW, defaultInitializationParams.manager));
        assertTrue(vault.hasRole(PausableFlows.DEPOSIT_REQUEST_FLOW, defaultInitializationParams.guardian));
        assertTrue(vault.hasRole(PausableFlows.DEPOSIT_REQUEST_FLOW, defaultInitializationParams.operationsMultisig));
        assertTrue(vault.hasRole(PausableFlows.SETTLE_DEPOSIT_FLOW, defaultInitializationParams.manager));
        assertTrue(vault.hasRole(PausableFlows.SETTLE_DEPOSIT_FLOW, defaultInitializationParams.guardian));
        assertTrue(vault.hasRole(PausableFlows.SETTLE_DEPOSIT_FLOW, defaultInitializationParams.operationsMultisig));
        assertTrue(vault.hasRole(PausableFlows.REDEEM_REQUEST_FLOW, defaultInitializationParams.manager));
        assertTrue(vault.hasRole(PausableFlows.REDEEM_REQUEST_FLOW, defaultInitializationParams.guardian));
        assertTrue(vault.hasRole(PausableFlows.REDEEM_REQUEST_FLOW, defaultInitializationParams.operationsMultisig));
        assertTrue(vault.hasRole(PausableFlows.SETTLE_REDEEM_FLOW, defaultInitializationParams.manager));
        assertTrue(vault.hasRole(PausableFlows.SETTLE_REDEEM_FLOW, defaultInitializationParams.guardian));
        assertTrue(vault.hasRole(PausableFlows.SETTLE_REDEEM_FLOW, defaultInitializationParams.operationsMultisig));

        assertTrue(vault.isFlowPaused(PausableFlows.DEPOSIT_REQUEST_FLOW));
        assertTrue(vault.isFlowPaused(PausableFlows.SETTLE_DEPOSIT_FLOW));
        assertTrue(vault.isFlowPaused(PausableFlows.REDEEM_REQUEST_FLOW));
        assertTrue(vault.isFlowPaused(PausableFlows.SETTLE_REDEEM_FLOW));
    }
}
