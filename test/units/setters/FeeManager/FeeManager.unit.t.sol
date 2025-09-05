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

import {Time} from "openzeppelin-contracts/contracts/utils/types/Time.sol";
import {IAccessControl} from "openzeppelin-contracts/contracts/access/IAccessControl.sol";
import {RolesLibrary} from "@aleph-vault/libraries/RolesLibrary.sol";
import {IFeeManager} from "@aleph-vault/interfaces/IFeeManager.sol";
import {TimelockRegistry} from "@aleph-vault/libraries/TimelockRegistry.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

contract FeeManager_Unit_Test is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
    }

    /*//////////////////////////////////////////////////////////////
                        QUEUE MANAGEMENT FEE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_queueManagementFee_revertsWhenCallerIsNotOperationsMultisig() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // queue management fee
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.MANAGER
            )
        );
        vault.queueManagementFee(1, 500);
    }

    function test_queueManagementFee_revertsWhenManagementFeeIsGreaterThanMaximuManagementFee() public {
        // queue management fee
        vm.prank(manager);
        vm.expectRevert(IFeeManager.InvalidManagementFee.selector);
        vault.queueManagementFee(1, 10_001);
    }

    function test_queueManagementFee_whenManagementFeeIsLessThanMaximuManagementFee_shouldSucceed() public {
        // queue management fee
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit IFeeManager.NewManagementFeeQueued(1, 500);
        vault.queueManagementFee(1, 500);

        // check management fee is queued
        bytes4 _key = TimelockRegistry.MANAGEMENT_FEE;
        uint48 _unlockTimestamp = Time.timestamp() + vault.managementFeeTimelock();
        TimelockRegistry.Timelock memory _timelock = vault.timelocks(_key);
        assertEq(_timelock.unlockTimestamp, _unlockTimestamp);
        assertEq(_timelock.newValue, abi.encode(1, 500));
    }

    /*//////////////////////////////////////////////////////////////
                        SET MANAGEMENT FEE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_setManagementFee_revertsWhenCallerIsNotOperationsMultisig() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // set management fee
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.MANAGER
            )
        );
        vault.setManagementFee();
    }

    function test_setManagementFee_revertsWhenUnlockTimestampIsGreaterThanCurrentTimestamp() public {
        // queue management fee
        vm.prank(manager);
        vault.queueManagementFee(1, 500);

        // get management fee timelock params
        bytes4 _key = TimelockRegistry.MANAGEMENT_FEE;
        uint48 _unlockTimestamp = Time.timestamp() + vault.managementFeeTimelock();

        // set management fee
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(TimelockRegistry.TimelockNotExpired.selector, _key, _unlockTimestamp));
        vault.setManagementFee();
    }

    function test_setManagementFee_whenUnlockTimestampIsNotGreaterThanCurrentTimestamp_shouldSucceed() public {
        // queue management fee
        vm.prank(manager);
        vault.queueManagementFee(1, 500);

        // roll the block forward to make timelock expired
        vm.warp(Time.timestamp() + vault.managementFeeTimelock() + 1);

        // check management fee is not set
        assertEq(vault.managementFee(1), defaultInitializationParams.userInitializationParams.managementFee);

        // set management fee
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit IFeeManager.NewManagementFeeSet(1, 500);
        vault.setManagementFee();

        // check management fee is set
        assertEq(vault.managementFee(1), 500);
    }

    /*//////////////////////////////////////////////////////////////
                        QUEUE PERFORMANCE FEE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_queuePerformanceFee_revertsWhenCallerIsNotOperationsMultisig() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // queue performance fee
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.MANAGER
            )
        );
        vault.queuePerformanceFee(1, 5000);
    }

    function test_queuePerformanceFee_revertsWhenPerformanceFeeIsGreaterThanMaximuPerformanceFee() public {
        // queue performance fee
        vm.prank(manager);
        vm.expectRevert(IFeeManager.InvalidPerformanceFee.selector);
        vault.queuePerformanceFee(1, 10_001);
    }

    function test_queuePerformanceFee_revertsWhenOldPerformanceFeeIsZero() public {
        vault.setPerformanceFee(0);

        // queue performance fee
        vm.prank(manager);
        vm.expectRevert(IFeeManager.InvalidShareClassConversion.selector);
        vault.queuePerformanceFee(1, 5000);
    }

    function test_queuePerformanceFee_revertsWhenNewPerformanceFeeIsZero() public {
        // queue performance fee
        vm.prank(manager);
        vm.expectRevert(IFeeManager.InvalidShareClassConversion.selector);
        vault.queuePerformanceFee(1, 0);
    }

    function test_queuePerformanceFee_whenPerformanceFeeIsLessThanMaximuPerformanceFee_shouldSucceed() public {
        // queue performance fee
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit IFeeManager.NewPerformanceFeeQueued(1, 5000);
        vault.queuePerformanceFee(1, 5000);

        // check performance fee is queued
        bytes4 _key = TimelockRegistry.PERFORMANCE_FEE;
        uint48 _unlockTimestamp = Time.timestamp() + vault.performanceFeeTimelock();
        TimelockRegistry.Timelock memory _timelock = vault.timelocks(_key);
        assertEq(_timelock.unlockTimestamp, _unlockTimestamp);
        assertEq(_timelock.newValue, abi.encode(1, 5000));
    }

    /*//////////////////////////////////////////////////////////////
                        SET PERFORMANCE FEE TESTS
    //////////////////////////////////////////////////////////////*/
    function test_setPerformanceFee_revertsWhenCallerIsNotOperationsMultisig() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // set performance fee
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.MANAGER
            )
        );
        vault.setPerformanceFee();
    }

    function test_setPerformanceFee_revertsWhenUnlockTimestampIsGreaterThanCurrentTimestamp() public {
        // queue performance fee
        vm.prank(manager);
        vault.queuePerformanceFee(1, 5000);

        // get performance fee timelock params
        bytes4 _key = TimelockRegistry.PERFORMANCE_FEE;
        uint48 _unlockTimestamp = Time.timestamp() + vault.performanceFeeTimelock();

        // set performance fee
        vm.prank(manager);
        vm.expectRevert(abi.encodeWithSelector(TimelockRegistry.TimelockNotExpired.selector, _key, _unlockTimestamp));
        vault.setPerformanceFee();
    }

    function test_setPerformanceFee_whenUnlockTimestampIsNotGreaterThanCurrentTimestamp_shouldSucceed() public {
        // queue performance fee
        vm.prank(manager);
        vault.queuePerformanceFee(1, 5000);

        // roll the block forward to make timelock expired
        vm.warp(Time.timestamp() + vault.performanceFeeTimelock() + 1);

        // check performance fee is not set
        assertEq(vault.performanceFee(1), defaultInitializationParams.userInitializationParams.performanceFee);

        // set performance fee
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit IFeeManager.NewPerformanceFeeSet(1, 5000);
        vault.setPerformanceFee();

        // check performance fee is set
        assertEq(vault.performanceFee(1), 5000);
    }

    /*//////////////////////////////////////////////////////////////
                        QUEUE FEE RECIPIENT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_queueFeeRecipient_revertsWhenCallerIsNotOperationsMultisig() public {
        address _feeRecipient = makeAddr("newFeeRecipient");

        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // queue fee recipient
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                nonAuthorizedUser,
                RolesLibrary.OPERATIONS_MULTISIG
            )
        );
        vault.queueFeeRecipient(_feeRecipient);
    }

    function test_queueFeeRecipient_whenCallerIsOperationsMultisig_shouldSucceed() public {
        address _feeRecipient = makeAddr("newFeeRecipient");

        // queue fee recipient
        vm.prank(operationsMultisig);
        vm.expectEmit(true, true, true, true);
        emit IFeeManager.NewFeeRecipientQueued(_feeRecipient);
        vault.queueFeeRecipient(_feeRecipient);

        // check fee recipient is queued
        bytes4 _key = TimelockRegistry.FEE_RECIPIENT;
        uint48 _unlockTimestamp = Time.timestamp() + vault.feeRecipientTimelock();
        TimelockRegistry.Timelock memory _timelock = vault.timelocks(_key);
        assertEq(_timelock.unlockTimestamp, _unlockTimestamp);
        assertEq(_timelock.newValue, abi.encode(_feeRecipient));
    }

    /*//////////////////////////////////////////////////////////////
                        SET FEE RECIPIENT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_setFeeRecipient_revertsWhenCallerIsNotOperationsMultisig() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // set fee recipient
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                nonAuthorizedUser,
                RolesLibrary.OPERATIONS_MULTISIG
            )
        );
        vault.setFeeRecipient();
    }

    function test_setFeeRecipient_revertsWhenUnlockTimestampIsGreaterThanCurrentTimestamp() public {
        address _feeRecipient = makeAddr("newFeeRecipient");

        // queue fee recipient
        vm.prank(operationsMultisig);
        vault.queueFeeRecipient(_feeRecipient);

        // check fee recipient timelock params
        bytes4 _key = TimelockRegistry.FEE_RECIPIENT;
        uint48 _unlockTimestamp = Time.timestamp() + vault.feeRecipientTimelock();

        // set fee recipient
        vm.prank(operationsMultisig);
        vm.expectRevert(abi.encodeWithSelector(TimelockRegistry.TimelockNotExpired.selector, _key, _unlockTimestamp));
        vault.setFeeRecipient();
    }

    function test_setFeeRecipient_whenUnlockTimestampIsNotGreaterThanCurrentTimestamp_shouldSucceed() public {
        address _feeRecipient = makeAddr("newFeeRecipient");

        // queue fee recipient
        vm.prank(operationsMultisig);
        vault.queueFeeRecipient(_feeRecipient);

        // roll the block forward to make timelock expired
        vm.warp(Time.timestamp() + vault.feeRecipientTimelock() + 1);

        // check fee recipient is not set
        assertEq(vault.feeRecipient(), defaultInitializationParams.feeRecipient);

        // set fee recipient
        vm.prank(operationsMultisig);
        vm.expectEmit(true, true, true, true);
        emit IFeeManager.NewFeeRecipientSet(_feeRecipient);
        vault.setFeeRecipient();

        // check fee recipient is set
        assertEq(vault.feeRecipient(), _feeRecipient);
    }
}
