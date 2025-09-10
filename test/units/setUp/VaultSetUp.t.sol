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
import {AlephVaultRedeem} from "@aleph-vault/modules/AlephVaultRedeem.sol";
import {FeeManager} from "@aleph-vault/modules/FeeManager.sol";
import {AlephVaultBase} from "@aleph-vault/AlephVaultBase.sol";
import {ExposedVault} from "@aleph-test/exposes/ExposedVault.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

/**
 * @author Othentic Labs LTD.
 * @notice Terms of Service: https://aleph.finance/terms-of-service
 */
contract VaultSetUpTest is BaseTest {
    /*//////////////////////////////////////////////////////////////
                           CONSTRUCTOR TESTS
    //////////////////////////////////////////////////////////////*/
    function test_constructor_when_minDepositAmountTimelock_passed_is_0() public {
        vm.expectRevert(AlephVaultBase.InvalidConstructorParams.selector);
        new AlephVaultDeposit(
            0,
            defaultConfigParams.minUserBalanceTimelock,
            defaultConfigParams.maxDepositCapTimelock,
            defaultConfigParams.batchDuration
        );
    }

    function test_constructor_when_minUserBalanceTimelock_passed_is_0() public {
        vm.expectRevert(AlephVaultBase.InvalidConstructorParams.selector);
        new AlephVaultDeposit(
            defaultConfigParams.minDepositAmountTimelock,
            0,
            defaultConfigParams.maxDepositCapTimelock,
            defaultConfigParams.batchDuration
        );
    }

    function test_constructor_when_maxDepositCapTimelock_passed_is_0() public {
        vm.expectRevert(AlephVaultBase.InvalidConstructorParams.selector);
        new AlephVaultDeposit(
            defaultConfigParams.minDepositAmountTimelock,
            defaultConfigParams.minUserBalanceTimelock,
            0,
            defaultConfigParams.batchDuration
        );
    }

    function test_constructor_when_noticePeriodTimelock_passed_is_0() public {
        vm.expectRevert(AlephVaultBase.InvalidConstructorParams.selector);
        new AlephVaultRedeem(
            0,
            defaultConfigParams.lockInPeriodTimelock,
            defaultConfigParams.minRedeemAmountTimelock,
            defaultConfigParams.batchDuration
        );
    }

    function test_constructor_when_lockInPeriodTimelock_passed_is_0() public {
        vm.expectRevert(AlephVaultBase.InvalidConstructorParams.selector);
        new AlephVaultRedeem(
            defaultConfigParams.noticePeriodTimelock,
            0,
            defaultConfigParams.minRedeemAmountTimelock,
            defaultConfigParams.batchDuration
        );
    }

    function test_constructor_when_minRedeemAmountTimelock_passed_is_0() public {
        vm.expectRevert(AlephVaultBase.InvalidConstructorParams.selector);
        new AlephVaultRedeem(
            defaultConfigParams.noticePeriodTimelock,
            defaultConfigParams.lockInPeriodTimelock,
            0,
            defaultConfigParams.batchDuration
        );
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
            userInitializationParams: IAlephVault.UserInitializationParams({
                name: defaultInitializationParams.userInitializationParams.name,
                configId: defaultInitializationParams.userInitializationParams.configId,
                manager: address(0),
                underlyingToken: defaultInitializationParams.userInitializationParams.underlyingToken,
                custodian: defaultInitializationParams.userInitializationParams.custodian,
                managementFee: defaultInitializationParams.userInitializationParams.managementFee,
                performanceFee: defaultInitializationParams.userInitializationParams.performanceFee,
                noticePeriod: defaultInitializationParams.userInitializationParams.noticePeriod,
                lockInPeriod: defaultInitializationParams.userInitializationParams.lockInPeriod,
                minDepositAmount: defaultInitializationParams.userInitializationParams.minDepositAmount,
                maxDepositCap: defaultInitializationParams.userInitializationParams.maxDepositCap,
                minRedeemAmount: defaultInitializationParams.userInitializationParams.minRedeemAmount,
                minUserBalance: defaultInitializationParams.userInitializationParams.minUserBalance,
                authSignature: defaultInitializationParams.userInitializationParams.authSignature
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
            userInitializationParams: IAlephVault.UserInitializationParams({
                name: defaultInitializationParams.userInitializationParams.name,
                configId: defaultInitializationParams.userInitializationParams.configId,
                manager: defaultInitializationParams.userInitializationParams.manager,
                underlyingToken: address(0),
                custodian: defaultInitializationParams.userInitializationParams.custodian,
                managementFee: defaultInitializationParams.userInitializationParams.managementFee,
                performanceFee: defaultInitializationParams.userInitializationParams.performanceFee,
                noticePeriod: defaultInitializationParams.userInitializationParams.noticePeriod,
                lockInPeriod: defaultInitializationParams.userInitializationParams.lockInPeriod,
                minDepositAmount: defaultInitializationParams.userInitializationParams.minDepositAmount,
                maxDepositCap: defaultInitializationParams.userInitializationParams.maxDepositCap,
                minRedeemAmount: defaultInitializationParams.userInitializationParams.minRedeemAmount,
                minUserBalance: defaultInitializationParams.userInitializationParams.minUserBalance,
                authSignature: defaultInitializationParams.userInitializationParams.authSignature
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
            userInitializationParams: IAlephVault.UserInitializationParams({
                name: defaultInitializationParams.userInitializationParams.name,
                configId: defaultInitializationParams.userInitializationParams.configId,
                manager: defaultInitializationParams.userInitializationParams.manager,
                underlyingToken: defaultInitializationParams.userInitializationParams.underlyingToken,
                custodian: address(0),
                managementFee: defaultInitializationParams.userInitializationParams.managementFee,
                performanceFee: defaultInitializationParams.userInitializationParams.performanceFee,
                noticePeriod: defaultInitializationParams.userInitializationParams.noticePeriod,
                lockInPeriod: defaultInitializationParams.userInitializationParams.lockInPeriod,
                minDepositAmount: defaultInitializationParams.userInitializationParams.minDepositAmount,
                maxDepositCap: defaultInitializationParams.userInitializationParams.maxDepositCap,
                minRedeemAmount: defaultInitializationParams.userInitializationParams.minRedeemAmount,
                minUserBalance: defaultInitializationParams.userInitializationParams.minUserBalance,
                authSignature: defaultInitializationParams.userInitializationParams.authSignature
            }),
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
            userInitializationParams: IAlephVault.UserInitializationParams({
                name: defaultInitializationParams.userInitializationParams.name,
                configId: defaultInitializationParams.userInitializationParams.configId,
                manager: defaultInitializationParams.userInitializationParams.manager,
                underlyingToken: defaultInitializationParams.userInitializationParams.underlyingToken,
                custodian: defaultInitializationParams.userInitializationParams.custodian,
                managementFee: 10_001,
                performanceFee: defaultInitializationParams.userInitializationParams.performanceFee,
                noticePeriod: defaultInitializationParams.userInitializationParams.noticePeriod,
                lockInPeriod: defaultInitializationParams.userInitializationParams.lockInPeriod,
                minDepositAmount: defaultInitializationParams.userInitializationParams.minDepositAmount,
                maxDepositCap: defaultInitializationParams.userInitializationParams.maxDepositCap,
                minRedeemAmount: defaultInitializationParams.userInitializationParams.minRedeemAmount,
                minUserBalance: defaultInitializationParams.userInitializationParams.minUserBalance,
                authSignature: defaultInitializationParams.userInitializationParams.authSignature
            }),
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
            userInitializationParams: IAlephVault.UserInitializationParams({
                name: defaultInitializationParams.userInitializationParams.name,
                configId: defaultInitializationParams.userInitializationParams.configId,
                manager: defaultInitializationParams.userInitializationParams.manager,
                underlyingToken: defaultInitializationParams.userInitializationParams.underlyingToken,
                custodian: defaultInitializationParams.userInitializationParams.custodian,
                managementFee: defaultInitializationParams.userInitializationParams.managementFee,
                performanceFee: 10_001,
                noticePeriod: defaultInitializationParams.userInitializationParams.noticePeriod,
                lockInPeriod: defaultInitializationParams.userInitializationParams.lockInPeriod,
                minDepositAmount: defaultInitializationParams.userInitializationParams.minDepositAmount,
                maxDepositCap: defaultInitializationParams.userInitializationParams.maxDepositCap,
                minRedeemAmount: defaultInitializationParams.userInitializationParams.minRedeemAmount,
                minUserBalance: defaultInitializationParams.userInitializationParams.minUserBalance,
                authSignature: defaultInitializationParams.userInitializationParams.authSignature
            }),
            moduleInitializationParams: defaultInitializationParams.moduleInitializationParams
        });

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_alephVaultDepositImplementation_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            vaultFactory: defaultInitializationParams.vaultFactory,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            feeRecipient: defaultInitializationParams.feeRecipient,
            userInitializationParams: defaultInitializationParams.userInitializationParams,
            moduleInitializationParams: IAlephVault.ModuleInitializationParams({
                alephVaultDepositImplementation: address(0),
                alephVaultRedeemImplementation: defaultInitializationParams
                    .moduleInitializationParams
                    .alephVaultRedeemImplementation,
                alephVaultSettlementImplementation: defaultInitializationParams
                    .moduleInitializationParams
                    .alephVaultSettlementImplementation,
                feeManagerImplementation: defaultInitializationParams.moduleInitializationParams.feeManagerImplementation,
                migrationManagerImplementation: defaultInitializationParams
                    .moduleInitializationParams
                    .migrationManagerImplementation
            })
        });

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_alephVaultRedeemImplementation_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            vaultFactory: defaultInitializationParams.vaultFactory,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            feeRecipient: defaultInitializationParams.feeRecipient,
            userInitializationParams: defaultInitializationParams.userInitializationParams,
            moduleInitializationParams: IAlephVault.ModuleInitializationParams({
                alephVaultDepositImplementation: defaultInitializationParams
                    .moduleInitializationParams
                    .alephVaultDepositImplementation,
                alephVaultRedeemImplementation: address(0),
                alephVaultSettlementImplementation: defaultInitializationParams
                    .moduleInitializationParams
                    .alephVaultSettlementImplementation,
                feeManagerImplementation: defaultInitializationParams.moduleInitializationParams.feeManagerImplementation,
                migrationManagerImplementation: defaultInitializationParams
                    .moduleInitializationParams
                    .migrationManagerImplementation
            })
        });

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_alephVaultSettlementImplementation_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            vaultFactory: defaultInitializationParams.vaultFactory,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            feeRecipient: defaultInitializationParams.feeRecipient,
            userInitializationParams: defaultInitializationParams.userInitializationParams,
            moduleInitializationParams: IAlephVault.ModuleInitializationParams({
                alephVaultDepositImplementation: defaultInitializationParams
                    .moduleInitializationParams
                    .alephVaultDepositImplementation,
                alephVaultRedeemImplementation: defaultInitializationParams
                    .moduleInitializationParams
                    .alephVaultRedeemImplementation,
                alephVaultSettlementImplementation: address(0),
                feeManagerImplementation: defaultInitializationParams.moduleInitializationParams.feeManagerImplementation,
                migrationManagerImplementation: defaultInitializationParams
                    .moduleInitializationParams
                    .migrationManagerImplementation
            })
        });

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_feeManagerImplementation_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            vaultFactory: defaultInitializationParams.vaultFactory,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            feeRecipient: defaultInitializationParams.feeRecipient,
            userInitializationParams: defaultInitializationParams.userInitializationParams,
            moduleInitializationParams: IAlephVault.ModuleInitializationParams({
                alephVaultDepositImplementation: defaultInitializationParams
                    .moduleInitializationParams
                    .alephVaultDepositImplementation,
                alephVaultRedeemImplementation: defaultInitializationParams
                    .moduleInitializationParams
                    .alephVaultRedeemImplementation,
                alephVaultSettlementImplementation: defaultInitializationParams
                    .moduleInitializationParams
                    .alephVaultSettlementImplementation,
                feeManagerImplementation: address(0),
                migrationManagerImplementation: defaultInitializationParams
                    .moduleInitializationParams
                    .migrationManagerImplementation
            })
        });

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_migrationManagerImplementation_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = IAlephVault.InitializationParams({
            operationsMultisig: defaultInitializationParams.operationsMultisig,
            vaultFactory: defaultInitializationParams.vaultFactory,
            oracle: defaultInitializationParams.oracle,
            guardian: defaultInitializationParams.guardian,
            authSigner: defaultInitializationParams.authSigner,
            feeRecipient: defaultInitializationParams.feeRecipient,
            userInitializationParams: defaultInitializationParams.userInitializationParams,
            moduleInitializationParams: IAlephVault.ModuleInitializationParams({
                alephVaultDepositImplementation: defaultInitializationParams
                    .moduleInitializationParams
                    .alephVaultDepositImplementation,
                alephVaultRedeemImplementation: defaultInitializationParams
                    .moduleInitializationParams
                    .alephVaultRedeemImplementation,
                alephVaultSettlementImplementation: defaultInitializationParams
                    .moduleInitializationParams
                    .alephVaultSettlementImplementation,
                feeManagerImplementation: defaultInitializationParams.moduleInitializationParams.feeManagerImplementation,
                migrationManagerImplementation: address(0)
            })
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
        assertEq(vault.managementFee(1), defaultInitializationParams.userInitializationParams.managementFee);
        assertEq(vault.performanceFee(1), defaultInitializationParams.userInitializationParams.performanceFee);
        assertEq(vault.noticePeriod(1), defaultInitializationParams.userInitializationParams.noticePeriod);
        assertEq(vault.lockInPeriod(1), defaultInitializationParams.userInitializationParams.lockInPeriod);
        assertEq(vault.minDepositAmount(1), defaultInitializationParams.userInitializationParams.minDepositAmount);
        assertEq(vault.maxDepositCap(1), defaultInitializationParams.userInitializationParams.maxDepositCap);
        assertEq(vault.minRedeemAmount(1), defaultInitializationParams.userInitializationParams.minRedeemAmount);
        assertEq(vault.minUserBalance(1), defaultInitializationParams.userInitializationParams.minUserBalance);

        assertTrue(vault.hasRole(RolesLibrary.OPERATIONS_MULTISIG, defaultInitializationParams.operationsMultisig));
        assertTrue(vault.hasRole(RolesLibrary.VAULT_FACTORY, defaultInitializationParams.vaultFactory));
        assertTrue(vault.hasRole(RolesLibrary.MANAGER, defaultInitializationParams.userInitializationParams.manager));
        assertTrue(vault.hasRole(RolesLibrary.ORACLE, defaultInitializationParams.oracle));
        assertTrue(vault.hasRole(RolesLibrary.GUARDIAN, defaultInitializationParams.guardian));
        assertTrue(vault.hasRole(RolesLibrary.FEE_RECIPIENT, defaultInitializationParams.feeRecipient));

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
