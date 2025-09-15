// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.27;
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
import {IAlephVaultDeposit} from "@aleph-vault/interfaces/IAlephVaultDeposit.sol";
import {IAlephVaultRedeem} from "@aleph-vault/interfaces/IAlephVaultRedeem.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
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
            IAlephVaultDeposit.DepositConstructorParams({
                minDepositAmountTimelock: 0,
                minUserBalanceTimelock: defaultConfigParams.minUserBalanceTimelock,
                maxDepositCapTimelock: defaultConfigParams.maxDepositCapTimelock
            }),
            defaultConfigParams.batchDuration
        );
    }

    function test_constructor_when_minUserBalanceTimelock_passed_is_0() public {
        vm.expectRevert(AlephVaultBase.InvalidConstructorParams.selector);
        new AlephVaultDeposit(
            IAlephVaultDeposit.DepositConstructorParams({
                minDepositAmountTimelock: defaultConfigParams.minDepositAmountTimelock,
                minUserBalanceTimelock: 0,
                maxDepositCapTimelock: defaultConfigParams.maxDepositCapTimelock
            }),
            defaultConfigParams.batchDuration
        );
    }

    function test_constructor_when_maxDepositCapTimelock_passed_is_0() public {
        vm.expectRevert(AlephVaultBase.InvalidConstructorParams.selector);
        new AlephVaultDeposit(
            IAlephVaultDeposit.DepositConstructorParams({
                minDepositAmountTimelock: defaultConfigParams.minDepositAmountTimelock,
                minUserBalanceTimelock: defaultConfigParams.minUserBalanceTimelock,
                maxDepositCapTimelock: 0
            }),
            defaultConfigParams.batchDuration
        );
    }

    function test_constructor_when_noticePeriodTimelock_passed_is_0() public {
        vm.expectRevert(AlephVaultBase.InvalidConstructorParams.selector);
        new AlephVaultRedeem(
            IAlephVaultRedeem.RedeemConstructorParams({
                noticePeriodTimelock: 0,
                lockInPeriodTimelock: defaultConfigParams.lockInPeriodTimelock,
                minRedeemAmountTimelock: defaultConfigParams.minRedeemAmountTimelock
            }),
            defaultConfigParams.batchDuration
        );
    }

    function test_constructor_when_lockInPeriodTimelock_passed_is_0() public {
        vm.expectRevert(AlephVaultBase.InvalidConstructorParams.selector);
        new AlephVaultRedeem(
            IAlephVaultRedeem.RedeemConstructorParams({
                noticePeriodTimelock: defaultConfigParams.noticePeriodTimelock,
                lockInPeriodTimelock: 0,
                minRedeemAmountTimelock: defaultConfigParams.minRedeemAmountTimelock
            }),
            defaultConfigParams.batchDuration
        );
    }

    function test_constructor_when_minRedeemAmountTimelock_passed_is_0() public {
        vm.expectRevert(AlephVaultBase.InvalidConstructorParams.selector);
        new AlephVaultRedeem(
            IAlephVaultRedeem.RedeemConstructorParams({
                noticePeriodTimelock: defaultConfigParams.noticePeriodTimelock,
                lockInPeriodTimelock: defaultConfigParams.lockInPeriodTimelock,
                minRedeemAmountTimelock: 0
            }),
            defaultConfigParams.batchDuration
        );
    }

    function test_constructor_when_managementFeeTimelock_passed_is_0() public {
        vm.expectRevert(AlephVaultBase.InvalidConstructorParams.selector);
        new FeeManager(
            IFeeManager.FeeConstructorParams({
                managementFeeTimelock: 0,
                performanceFeeTimelock: defaultConfigParams.performanceFeeTimelock
            }),
            defaultConfigParams.batchDuration
        );
    }

    function test_constructor_when_performanceFeeTimelock_passed_is_0() public {
        vm.expectRevert(AlephVaultBase.InvalidConstructorParams.selector);
        new FeeManager(
            IFeeManager.FeeConstructorParams({
                managementFeeTimelock: defaultConfigParams.managementFeeTimelock,
                performanceFeeTimelock: 0
            }),
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
        IAlephVault.InitializationParams memory _initializationParams = defaultInitializationParams;
        _initializationParams.operationsMultisig = address(0);

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_vaultFactory_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = defaultInitializationParams;
        _initializationParams.vaultFactory = address(0);

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_oracle_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = defaultInitializationParams;
        _initializationParams.oracle = address(0);

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_guardian_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = defaultInitializationParams;
        _initializationParams.guardian = address(0);

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_authSigner_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = defaultInitializationParams;
        _initializationParams.authSigner = address(0);

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_accountant_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = defaultInitializationParams;
        _initializationParams.accountant = address(0);

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_manager_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = defaultInitializationParams;
        _initializationParams.userInitializationParams.manager = address(0);

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_underlyingToken_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = defaultInitializationParams;
        _initializationParams.userInitializationParams.underlyingToken = address(0);

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_custodian_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = defaultInitializationParams;
        _initializationParams.userInitializationParams.custodian = address(0);

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_managementFee_is_greater_than_maxManagementFee() public {
        IAlephVault.InitializationParams memory _initializationParams = defaultInitializationParams;
        _initializationParams.userInitializationParams.shareClassParams.managementFee = 10_001;

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_performanceFee_is_greater_than_maxPerformanceFee() public {
        IAlephVault.InitializationParams memory _initializationParams = defaultInitializationParams;
        _initializationParams.userInitializationParams.shareClassParams.performanceFee = 10_001;

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_minDepositAmount_is_0() public {
        IAlephVault.InitializationParams memory _initializationParams = defaultInitializationParams;
        _initializationParams.userInitializationParams.shareClassParams.minDepositAmount = 0;

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_minRedeemAmount_is_0() public {
        IAlephVault.InitializationParams memory _initializationParams = defaultInitializationParams;
        _initializationParams.userInitializationParams.shareClassParams.minRedeemAmount = 0;

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_alephVaultDepositImplementation_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = defaultInitializationParams;
        _initializationParams.moduleInitializationParams.alephVaultDepositImplementation = address(0);

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_alephVaultRedeemImplementation_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = defaultInitializationParams;
        _initializationParams.moduleInitializationParams.alephVaultRedeemImplementation = address(0);

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_alephVaultSettlementImplementation_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = defaultInitializationParams;
        _initializationParams.moduleInitializationParams.alephVaultSettlementImplementation = address(0);

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_feeManagerImplementation_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = defaultInitializationParams;
        _initializationParams.moduleInitializationParams.feeManagerImplementation = address(0);

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_migrationManagerImplementation_passed_is_address_0() public {
        IAlephVault.InitializationParams memory _initializationParams = defaultInitializationParams;
        _initializationParams.moduleInitializationParams.migrationManagerImplementation = address(0);

        vault = new ExposedVault(defaultConfigParams.batchDuration);
        vm.expectRevert(IAlephVault.InvalidInitializationParams.selector);
        vault.initialize(_initializationParams);
    }

    function test_initialize_when_all_params_are_valid() public {
        vault = new ExposedVault(defaultConfigParams.batchDuration);
        mocks.mockSetVaultTreasury(
            defaultInitializationParams.accountant, defaultInitializationParams.userInitializationParams.vaultTreasury
        );
        vault.initialize(defaultInitializationParams);

        assertEq(vault.name(), defaultInitializationParams.userInitializationParams.name);
        assertEq(vault.manager(), defaultInitializationParams.userInitializationParams.manager);
        assertEq(vault.oracle(), defaultInitializationParams.oracle);
        assertEq(vault.guardian(), defaultInitializationParams.guardian);
        assertEq(vault.authSigner(), defaultInitializationParams.authSigner);
        assertEq(vault.underlyingToken(), defaultInitializationParams.userInitializationParams.underlyingToken);
        assertEq(vault.custodian(), defaultInitializationParams.userInitializationParams.custodian);
        assertEq(vault.accountant(), defaultInitializationParams.accountant);
        assertEq(
            vault.managementFee(1), defaultInitializationParams.userInitializationParams.shareClassParams.managementFee
        );
        assertEq(
            vault.performanceFee(1),
            defaultInitializationParams.userInitializationParams.shareClassParams.performanceFee
        );
        assertEq(
            vault.noticePeriod(1), defaultInitializationParams.userInitializationParams.shareClassParams.noticePeriod
        );
        assertEq(
            vault.lockInPeriod(1), defaultInitializationParams.userInitializationParams.shareClassParams.lockInPeriod
        );
        assertEq(
            vault.minDepositAmount(1),
            defaultInitializationParams.userInitializationParams.shareClassParams.minDepositAmount
        );
        assertEq(
            vault.maxDepositCap(1), defaultInitializationParams.userInitializationParams.shareClassParams.maxDepositCap
        );
        assertEq(
            vault.minRedeemAmount(1),
            defaultInitializationParams.userInitializationParams.shareClassParams.minRedeemAmount
        );
        assertEq(
            vault.minUserBalance(1),
            defaultInitializationParams.userInitializationParams.shareClassParams.minUserBalance
        );

        assertTrue(vault.hasRole(RolesLibrary.OPERATIONS_MULTISIG, defaultInitializationParams.operationsMultisig));
        assertTrue(vault.hasRole(RolesLibrary.VAULT_FACTORY, defaultInitializationParams.vaultFactory));
        assertTrue(vault.hasRole(RolesLibrary.MANAGER, defaultInitializationParams.userInitializationParams.manager));
        assertTrue(vault.hasRole(RolesLibrary.ORACLE, defaultInitializationParams.oracle));
        assertTrue(vault.hasRole(RolesLibrary.GUARDIAN, defaultInitializationParams.guardian));
        assertTrue(vault.hasRole(RolesLibrary.ACCOUNTANT, defaultInitializationParams.accountant));

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
        assertTrue(vault.hasRole(PausableFlows.WITHDRAW_FLOW, defaultInitializationParams.guardian));

        assertTrue(vault.isFlowPaused(PausableFlows.DEPOSIT_REQUEST_FLOW));
        assertTrue(vault.isFlowPaused(PausableFlows.SETTLE_DEPOSIT_FLOW));
        assertTrue(vault.isFlowPaused(PausableFlows.REDEEM_REQUEST_FLOW));
        assertTrue(vault.isFlowPaused(PausableFlows.SETTLE_REDEEM_FLOW));
    }
}
