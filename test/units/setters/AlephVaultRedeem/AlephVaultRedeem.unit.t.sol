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
import {IAlephVaultRedeem} from "@aleph-vault/interfaces/IAlephVaultRedeem.sol";
import {TimelockRegistry} from "@aleph-vault/libraries/TimelockRegistry.sol";
import {BaseTest} from "@aleph-test/utils/BaseTest.t.sol";

contract AlephVaultRedeem_Unit_Test is BaseTest {
    function setUp() public override {
        super.setUp();
        _setUpNewAlephVault(defaultConfigParams, defaultInitializationParams);
    }

    /*//////////////////////////////////////////////////////////////
                        QUEUE NOTICE PERIOD TESTS
    //////////////////////////////////////////////////////////////*/
    function test_queueNoticePeriod_revertsWhenCallerIsNotManager() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // queue notice period
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.MANAGER
            )
        );
        vault.queueNoticePeriod(1, 30);
    }

    function test_queueNoticePeriod_whenCallerIsManager_shouldSucceed() public {
        // queue notice period
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultRedeem.NewNoticePeriodQueued(1, 100);
        vault.queueNoticePeriod(1, 100);

        // check notice period is queued
        bytes4 _key = TimelockRegistry.getKey(TimelockRegistry.NOTICE_PERIOD, 1);
        uint48 _unlockTimestamp = Time.timestamp() + vault.noticePeriodTimelock();
        TimelockRegistry.Timelock memory _timelock = vault.timelocks(_key);
        assertEq(_timelock.isQueued, true);
        assertEq(_timelock.unlockTimestamp, _unlockTimestamp);
        assertEq(_timelock.newValue, abi.encode(100));
    }

    /*//////////////////////////////////////////////////////////////
                        SET NOTICE PERIOD TESTS
    //////////////////////////////////////////////////////////////*/
    function test_setNoticePeriod_revertsWhenCallerIsNotManager() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // set notice period
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.MANAGER
            )
        );
        vault.setNoticePeriod(1);
    }

    function test_setNoticePeriod_revertsWhenTimelockIsNotQueued() public {
        // set notice period
        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(TimelockRegistry.TimelockNotQueued.selector, TimelockRegistry.NOTICE_PERIOD, 1)
        );
        vault.setNoticePeriod(1);
    }

    function test_setNoticePeriod_revertsWhenUnlockTimestampIsGreaterThanCurrentTimestamp() public {
        // queue notice period
        vm.prank(manager);
        vault.queueNoticePeriod(1, 30);

        // get notice period timelock params
        bytes4 _key = TimelockRegistry.getKey(TimelockRegistry.NOTICE_PERIOD, 1);
        uint48 _unlockTimestamp = Time.timestamp() + vault.noticePeriodTimelock();

        // set notice period
        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(
                TimelockRegistry.TimelockNotExpired.selector, TimelockRegistry.NOTICE_PERIOD, 1, _unlockTimestamp
            )
        );
        vault.setNoticePeriod(1);
    }

    function test_setNoticePeriod_whenUnlockTimestampIsNotGreaterThanCurrentTimestamp_shouldSucceed() public {
        // queue notice period
        vm.prank(manager);
        vault.queueNoticePeriod(1, 30);

        // roll the block forward to make timelock expired
        vm.warp(Time.timestamp() + vault.noticePeriodTimelock() + 1);

        // set notice period
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultRedeem.NewNoticePeriodSet(1, 30);
        vault.setNoticePeriod(1);

        // check notice period is set
        assertEq(vault.noticePeriod(1), 30);
    }

    /*//////////////////////////////////////////////////////////////
                        QUEUE LOCK IN PERIOD TESTS
    //////////////////////////////////////////////////////////////*/
    function test_queueLockInPeriod_revertsWhenCallerIsNotManager() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // queue lock in period
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.MANAGER
            )
        );
        vault.queueLockInPeriod(1, 30);
    }

    function test_queueLockInPeriod_whenCallerIsManager_shouldSucceed() public {
        // queue lock in period
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultRedeem.NewLockInPeriodQueued(1, 100);
        vault.queueLockInPeriod(1, 100);

        // check lock in period is queued
        bytes4 _key = TimelockRegistry.getKey(TimelockRegistry.LOCK_IN_PERIOD, 1);
        uint48 _unlockTimestamp = Time.timestamp() + vault.lockInPeriodTimelock();
        TimelockRegistry.Timelock memory _timelock = vault.timelocks(_key);
        assertEq(_timelock.isQueued, true);
        assertEq(_timelock.unlockTimestamp, _unlockTimestamp);
        assertEq(_timelock.newValue, abi.encode(100));
    }

    /*//////////////////////////////////////////////////////////////
                        SET LOCK IN PERIOD TESTS
    //////////////////////////////////////////////////////////////*/
    function test_setLockInPeriod_revertsWhenCallerIsNotManager() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // set lock in period
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.MANAGER
            )
        );
        vault.setLockInPeriod(1);
    }

    function test_setLockInPeriod_revertsWhenTimelockIsNotQueued() public {
        // set lock in period
        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(TimelockRegistry.TimelockNotQueued.selector, TimelockRegistry.LOCK_IN_PERIOD, 1)
        );
        vault.setLockInPeriod(1);
    }

    function test_setLockInPeriod_revertsWhenUnlockTimestampIsGreaterThanCurrentTimestamp() public {
        // queue lock in period
        vm.prank(manager);
        vault.queueLockInPeriod(1, 30);

        // get lock in period timelock params
        bytes4 _key = TimelockRegistry.getKey(TimelockRegistry.LOCK_IN_PERIOD, 1);
        uint48 _unlockTimestamp = Time.timestamp() + vault.lockInPeriodTimelock();

        // set lock in period
        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(
                TimelockRegistry.TimelockNotExpired.selector, TimelockRegistry.LOCK_IN_PERIOD, 1, _unlockTimestamp
            )
        );
        vault.setLockInPeriod(1);
    }

    function test_setLockInPeriod_whenUnlockTimestampIsNotGreaterThanCurrentTimestamp_shouldSucceed() public {
        // queue lock in period
        vm.prank(manager);
        vault.queueLockInPeriod(1, 30);

        // roll the block forward to make timelock expired
        vm.warp(Time.timestamp() + vault.lockInPeriodTimelock() + 1);

        // set lock in period
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultRedeem.NewLockInPeriodSet(1, 30);
        vault.setLockInPeriod(1);

        // check lock in period is set
        assertEq(vault.lockInPeriod(1), 30);
    }

    /*//////////////////////////////////////////////////////////////
                        QUEUE MIN REDEEM AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_queueMinRedeemAmount_revertsWhenCallerIsNotManager() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // queue min redeem amount
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.MANAGER
            )
        );
        vault.queueMinRedeemAmount(1, 100);
    }

    function test_queueMinRedeemAmount_whenCallerIsManager_shouldSucceed() public {
        // queue min redeem amount
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultRedeem.NewMinRedeemAmountQueued(1, 100);
        vault.queueMinRedeemAmount(1, 100);

        // check min redeem amount is queued
        bytes4 _key = TimelockRegistry.getKey(TimelockRegistry.MIN_REDEEM_AMOUNT, 1);
        uint48 _unlockTimestamp = Time.timestamp() + vault.minRedeemAmountTimelock();
        TimelockRegistry.Timelock memory _timelock = vault.timelocks(_key);
        assertEq(_timelock.isQueued, true);
        assertEq(_timelock.unlockTimestamp, _unlockTimestamp);
        assertEq(_timelock.newValue, abi.encode(100));
    }

    /*//////////////////////////////////////////////////////////////
                        SET MIN REDEEM AMOUNT TESTS
    //////////////////////////////////////////////////////////////*/
    function test_setMinRedeemAmount_revertsWhenCallerIsNotManager() public {
        // Setup a non-authorized user
        address nonAuthorizedUser = makeAddr("nonAuthorizedUser");

        // set min redeem amount
        vm.prank(nonAuthorizedUser);
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, nonAuthorizedUser, RolesLibrary.MANAGER
            )
        );
        vault.setMinRedeemAmount(1);
    }

    function test_setMinRedeemAmount_revertsWhenTimelockIsNotQueued() public {
        // set min redeem amount
        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(TimelockRegistry.TimelockNotQueued.selector, TimelockRegistry.MIN_REDEEM_AMOUNT, 1)
        );
        vault.setMinRedeemAmount(1);
    }

    function test_setMinRedeemAmount_revertsWhenUnlockTimestampIsGreaterThanCurrentTimestamp() public {
        // queue min redeem amount
        vm.prank(manager);
        vault.queueMinRedeemAmount(1, 100);

        // get min redeem amount timelock params
        bytes4 _key = TimelockRegistry.getKey(TimelockRegistry.MIN_REDEEM_AMOUNT, 1);
        uint48 _unlockTimestamp = Time.timestamp() + vault.minRedeemAmountTimelock();

        // set min redeem amount
        vm.prank(manager);
        vm.expectRevert(
            abi.encodeWithSelector(
                TimelockRegistry.TimelockNotExpired.selector, TimelockRegistry.MIN_REDEEM_AMOUNT, 1, _unlockTimestamp
            )
        );
        vault.setMinRedeemAmount(1);
    }

    function test_setMinRedeemAmount_whenUnlockTimestampIsNotGreaterThanCurrentTimestamp_shouldSucceed() public {
        // queue min redeem amount
        vm.prank(manager);
        vault.queueMinRedeemAmount(1, 100);

        // roll the block forward to make timelock expired
        vm.warp(Time.timestamp() + vault.minRedeemAmountTimelock() + 1);

        // set min redeem amount
        vm.prank(manager);
        vm.expectEmit(true, true, true, true);
        emit IAlephVaultRedeem.NewMinRedeemAmountSet(1, 100);
        vault.setMinRedeemAmount(1);

        // check min redeem amount is set
        assertEq(vault.minRedeemAmount(1), 100);
    }
}
